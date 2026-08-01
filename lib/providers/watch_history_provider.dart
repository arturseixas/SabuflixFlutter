import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../models/watch_history_item.dart';
import '../services/watch_history_service.dart';

class WatchHistoryProvider extends ChangeNotifier {
  final WatchHistoryService _historyService = WatchHistoryService();

  List<WatchHistoryItem> _history = [];
  List<WatchHistoryItem> get history => _history;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _currentProfileId;

  WatchHistoryProvider() {
    loadHistory(null);
  }

  Future<void> loadHistory(String? profileId) async {
    _currentProfileId = profileId;
    _isLoading = true;
    notifyListeners();

    _history = await _historyService.getHistory(_currentProfileId);

    _isLoading = false;
    notifyListeners();
  }

  WatchHistoryItem? entryFor(int mediaId) {
    try {
      return _history.firstWhere((item) => item.media.id == mediaId);
    } catch (_) {
      return null;
    }
  }

  /// Posição (em segundos) de onde retomar [mediaId], ou null se nunca foi
  /// assistido ou se já foi finalizado (nesse caso começa do zero de novo).
  double? resumePositionFor(int mediaId) {
    final entry = entryFor(mediaId);
    if (entry == null || entry.isFinished) return null;
    return entry.positionSeconds;
  }

  /// Salva/atualiza o progresso de reprodução, alimentando o "Continuar assistindo".
  Future<void> updateProgress(
    MediaItem media, {
    required double positionSeconds,
    required double durationSeconds,
    int? season,
    int? episode,
  }) async {
    if (durationSeconds <= 0) return;
    _history = await _historyService.updateProgress(
      media: media,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
      season: season,
      episode: episode,
      profileId: _currentProfileId,
    );
    notifyListeners();
  }

  /// Remove um único título do histórico.
  Future<void> removeFromHistory(int mediaId) async {
    _history = await _historyService.removeFromHistory(mediaId, _currentProfileId);
    notifyListeners();
  }

  /// Apaga todo o histórico de reprodução do perfil atual.
  Future<void> clearHistory() async {
    await _historyService.clearHistory(_currentProfileId);
    _history = [];
    notifyListeners();
  }
}
