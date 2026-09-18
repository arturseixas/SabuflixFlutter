import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';
import '../services/cast/cast_device.dart';
import '../services/cast/cast_manager.dart';
import '../services/cast/cast_session.dart';
import '../services/network_service.dart';
import '../utils/formatters.dart';

/// What is currently being sent to the TV, so every screen can describe it.
class CastNowPlaying {
  final MediaItem media;
  final String url;
  final int? season;
  final int? episode;
  final String? episodeTitle;

  const CastNowPlaying({
    required this.media,
    required this.url,
    this.season,
    this.episode,
    this.episodeTitle,
  });

  bool get isEpisode => season != null && episode != null;

  String get subtitle {
    if (!isEpisode) return media.formattedYear;
    final tag = formatEpisodeTag(season, episode);
    final name = episodeTitle;
    if (name == null || name.trim().isEmpty) return tag;
    return '$tag · ${name.trim()}';
  }
}

/// Reported back so "Continuar assistindo" keeps up while the TV plays.
typedef CastProgressSink = void Function(
    CastNowPlaying nowPlaying, Duration position, Duration duration);

/// Owns discovery, the active TV connection and the remote playback state.
class CastProvider extends ChangeNotifier {
  CastProvider({CastDiscovery? discovery})
      : _discovery = discovery ?? CastDiscovery() {
    _restoreSaved();
  }

  static const String _savedKey = 'sabuflix_cast_saved_devices';

  final CastDiscovery _discovery;
  final List<CastDevice> _discovered = [];
  List<CastDevice> _saved = [];
  bool _discovering = false;
  StreamSubscription<CastDevice>? _discoverySubscription;

  CastSession? _session;
  CastDevice? _connecting;
  CastPlaybackStatus _status = const CastPlaybackStatus();
  CastNowPlaying? _nowPlaying;
  StreamSubscription<CastPlaybackStatus>? _statusSubscription;
  StreamSubscription<String>? _errorSubscription;
  String? _lastError;
  bool _disposed = false;
  int _lastProgressReportMs = 0;

  /// Wired by the app so casting feeds the same shelf as local playback.
  CastProgressSink? progressSink;

  bool get isSupported => CastDiscovery.isSupported;
  bool get isDiscovering => _discovering;
  bool get isConnected => _session != null;
  bool get isConnecting => _connecting != null;
  CastDevice? get connectingDevice => _connecting;
  CastDevice? get device => _session?.device;
  CastPlaybackStatus get status => _status;
  CastNowPlaying? get nowPlaying => _nowPlaying;
  String? get lastError => _lastError;
  bool get hasActiveMedia => _nowPlaying != null && _status.isActive;

  /// Discovered first, then remembered devices that did not answer this time.
  List<CastDevice> get devices {
    final ids = _discovered.map((d) => d.id).toSet();
    return [
      ..._discovered,
      ..._saved.where((device) => !ids.contains(device.id)),
    ];
  }

  List<CastDevice> get savedDevices => List.unmodifiable(_saved);

  // --- Discovery ----------------------------------------------------------

  Future<void> discover({Duration timeout = const Duration(seconds: 4)}) async {
    if (!isSupported || _discovering) return;
    _discovering = true;
    _discovered.clear();
    _lastError = null;
    notifyListeners();
    await NetworkService.instance.acquireMulticastLock();
    final done = Completer<void>();
    _discoverySubscription = _discovery.discover(timeout: timeout).listen(
      (device) {
        final index = _discovered.indexWhere((d) => d.id == device.id);
        if (index == -1) {
          _discovered.add(device);
        } else {
          _discovered[index] = device;
        }
        // Refresh the remembered copy so a TV that changed IP still connects.
        final savedIndex = _saved.indexWhere((d) => d.id == device.id);
        if (savedIndex != -1) {
          _saved[savedIndex] =
              device.copyWith(manual: _saved[savedIndex].manual);
          unawaited(_persistSaved());
        }
        notifyListeners();
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      onError: (Object error) {
        debugPrint('Cast discovery error: $error');
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future;
    _discoverySubscription = null;
    _discovering = false;
    await NetworkService.instance.releaseMulticastLock();
    notifyListeners();
  }

  void stopDiscovery() {
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    if (_discovering) {
      _discovering = false;
      notifyListeners();
    }
  }

  /// Adds a TV by IP address. Returns the device or `null` when nothing that
  /// speaks Cast or DLNA answers there.
  Future<CastDevice?> addManual(String host) async {
    final device = await CastDiscovery.probe(host);
    if (device == null) return null;
    await remember(device);
    return device;
  }

  Future<void> remember(CastDevice device) async {
    _saved.removeWhere((d) => d.id == device.id);
    _saved.insert(0, device);
    if (_saved.length > 10) _saved = _saved.sublist(0, 10);
    await _persistSaved();
    notifyListeners();
  }

  Future<void> forget(CastDevice device) async {
    _saved.removeWhere((d) => d.id == device.id);
    await _persistSaved();
    notifyListeners();
  }

  Future<void> _restoreSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = json.decode(raw);
      if (decoded is List) {
        _saved = decoded
            .whereType<Map>()
            .map((e) => CastDevice.fromJson(Map<String, dynamic>.from(e)))
            .where((d) => d.id.isNotEmpty && d.host.isNotEmpty)
            .toList();
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Ignoring unreadable saved cast devices: $error');
    }
  }

  Future<void> _persistSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _savedKey, json.encode(_saved.map((d) => d.toJson()).toList()));
    } catch (error) {
      debugPrint('Could not save cast devices: $error');
    }
  }

  // --- Session ------------------------------------------------------------

  Future<void> connect(CastDevice device) async {
    if (_session?.device.id == device.id) return;
    await disconnect();
    _connecting = device;
    _lastError = null;
    notifyListeners();
    try {
      final session = await CastSession.open(device);
      if (_disposed) {
        await session.disconnect();
        return;
      }
      _session = session;
      _status = session.lastStatus;
      _statusSubscription = session.status.listen(_onStatus);
      _errorSubscription = session.errors.listen((message) {
        _lastError = message;
        notifyListeners();
      });
      unawaited(session.closed.then((_) {
        if (_session == session) {
          _session = null;
          _nowPlaying = null;
          _status = const CastPlaybackStatus();
          _statusSubscription?.cancel();
          _errorSubscription?.cancel();
          notifyListeners();
        }
      }));
      await remember(device);
    } on CastException catch (error) {
      _lastError = error.message;
      rethrow;
    } catch (error) {
      _lastError = 'Não foi possível conectar a ${device.name}.';
      throw CastException(_lastError!);
    } finally {
      _connecting = null;
      notifyListeners();
    }
  }

  /// Sends a title to the connected TV (connecting first when [device] is
  /// given) and remembers what is playing.
  Future<void> cast({
    required MediaItem media,
    required String url,
    CastDevice? device,
    int? season,
    int? episode,
    String? episodeTitle,
    Duration startAt = Duration.zero,
    String? subtitleUrl,
    String? subtitleLanguage,
  }) async {
    if (device != null) await connect(device);
    final session = _session;
    if (session == null) throw const CastException('Nenhuma TV conectada.');
    final nowPlaying = CastNowPlaying(
      media: media,
      url: url,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle,
    );
    _nowPlaying = nowPlaying;
    _lastError = null;
    _status = CastPlaybackStatus(
        state: CastPlayerState.buffering,
        position: startAt,
        volume: _status.volume,
        muted: _status.muted);
    notifyListeners();
    try {
      await session.load(CastMediaRequest(
        url: url,
        title: media.title,
        subtitle: nowPlaying.isEpisode ? nowPlaying.subtitle : null,
        imageUrl:
            media.fullBackdropPath.isNotEmpty ? media.fullBackdropPath : null,
        startAt: startAt,
        subtitleUrl: subtitleUrl,
        subtitleLanguage: subtitleLanguage,
      ));
    } on CastException catch (error) {
      _lastError = error.message;
      _status = _status.copyWith(state: CastPlayerState.idle);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> play() => _guard(() => _session!.play());
  Future<void> pause() => _guard(() => _session!.pause());
  Future<void> togglePlayPause() => _status.isPlaying ? pause() : play();

  Future<void> seek(Duration position) => _guard(() async {
        final clamped = position < Duration.zero
            ? Duration.zero
            : (_status.duration > Duration.zero && position > _status.duration
                ? _status.duration
                : position);
        await _session!.seek(clamped);
        _status = _status.copyWith(position: clamped);
        notifyListeners();
      });

  Future<void> seekBy(Duration delta) => seek(_status.position + delta);

  Future<void> setVolume(double level) =>
      _guard(() => _session!.setVolume(level));
  Future<void> setMuted(bool muted) => _guard(() => _session!.setMuted(muted));

  Future<void> stop() => _guard(() async {
        await _session!.stop();
        _reportProgress(force: true);
        _nowPlaying = null;
        notifyListeners();
      });

  Future<void> disconnect() async {
    final session = _session;
    _session = null;
    await _statusSubscription?.cancel();
    await _errorSubscription?.cancel();
    _statusSubscription = null;
    _errorSubscription = null;
    if (session != null) {
      _reportProgress(force: true);
      try {
        await session.disconnect();
      } catch (error) {
        debugPrint('Cast disconnect failed: $error');
      }
    }
    _nowPlaying = null;
    _status = const CastPlaybackStatus();
    notifyListeners();
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_session == null) throw const CastException('Nenhuma TV conectada.');
    try {
      await action();
    } on CastException catch (error) {
      _lastError = error.message;
      notifyListeners();
      rethrow;
    }
  }

  void _onStatus(CastPlaybackStatus status) {
    final wasActive = _status.isActive;
    _status = status;
    _reportProgress();
    if (wasActive &&
        _nowPlaying != null &&
        (status.state == CastPlayerState.idle ||
            status.state == CastPlayerState.stopped) &&
        status.duration > Duration.zero &&
        status.position >= status.duration - const Duration(seconds: 5)) {
      // The title finished on the TV: report the final position so it drops
      // off the shelf, then clear what is playing.
      progressSink?.call(_nowPlaying!, status.duration, status.duration);
      _nowPlaying = null;
    }
    notifyListeners();
  }

  void _reportProgress({bool force = false}) {
    final nowPlaying = _nowPlaying;
    if (nowPlaying == null || progressSink == null) return;
    if (_status.duration <= Duration.zero) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _lastProgressReportMs < 10000) return;
    _lastProgressReportMs = now;
    progressSink!(nowPlaying, _status.position, _status.duration);
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _discoverySubscription?.cancel();
    _statusSubscription?.cancel();
    _errorSubscription?.cancel();
    _session?.disconnect();
    super.dispose();
  }
}
