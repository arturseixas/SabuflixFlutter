import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'addon_service.dart';

typedef StreamProvider = ({String name, String brand, String baseUrl});

class FrostStreamService {
  static const _penguPlayManifestUrl = String.fromEnvironment(
    'PENGUPLAY_MANIFEST_URL',
  );

  /// Stremio add-ons queried for playable links, in no particular order:
  /// [StreamScanner] ranks what they return.
  static final List<StreamProvider> providers = [
    (name: 'Nebula', brand: 'Nebula', baseUrl: AddonService.fenixBase),
    (
      name: 'FrostStream',
      brand: 'FrostStream',
      baseUrl: 'https://froststream.cloutteam.com',
    ),
    (
      name: 'Wali',
      brand: 'Wali',
      baseUrl: 'https://bestcine.dpdns.org',
    ),
    if (_penguPlayManifestUrl.isNotEmpty)
      (
        name: 'PenguPlay',
        brand: 'Sabuflix Pengu',
        baseUrl: addonBaseUrl(_penguPlayManifestUrl),
      ),
  ];

  /// Returns an add-on base URL from its Stremio manifest URL.
  ///
  /// Keeping the manifest, including any access token, in a `dart-define`
  /// avoids committing credentials to the repository.
  static String addonBaseUrl(String manifestUrl) {
    const manifestSuffix = '/manifest.json';
    final baseUrl = manifestUrl.endsWith(manifestSuffix)
        ? manifestUrl.substring(0, manifestUrl.length - manifestSuffix.length)
        : manifestUrl;
    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  static Future<List<Map<String, dynamic>>> fetchStreams({
    required String imdbId,
    required String type, // 'movie' or 'tv'
    int? season,
    int? episode,
  }) async {
    if (imdbId.isEmpty) return [];

    if (type != 'movie' && (season == null || episode == null)) return [];

    final results = await Future.wait(
      providers.map(
        (source) => fetchProvider(
          source: source,
          imdbId: imdbId,
          type: type,
          season: season,
          episode: episode,
        ),
      ),
    );

    final seenUrls = <String>{};
    return results.expand((items) => items).where((stream) {
      final url = stream['url']?.toString();
      final uri = Uri.tryParse(url ?? '');
      return uri != null &&
          ['http', 'https'].contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          seenUrls.add(url!);
    }).toList();
  }

  /// Streams from a single add-on; an unreachable add-on yields none.
  static Future<List<Map<String, dynamic>>> fetchProvider({
    required StreamProvider source,
    required String imdbId,
    required String type,
    int? season,
    int? episode,
    http.Client? client,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final path = type == 'movie'
        ? '/stream/movie/$imdbId.json'
        : '/stream/series/$imdbId:$season:$episode.json';

    try {
      final uri = Uri.parse('${source.baseUrl}$path');
      final response =
          await (client?.get(uri) ?? http.get(uri)).timeout(timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List streams = data['streams'] ?? [];
        return streams.whereType<Map>().toList().asMap().entries.where((entry) {
          final hints = entry.value['behaviorHints'];
          return !kIsWeb || hints is! Map || hints['notWebReady'] != true;
        }).map((entry) {
          final stream = Map<String, dynamic>.from(entry.value);
          if (stream['name'] is String) {
            stream['name'] = stream['name'].toString().replaceAll(
                RegExp(r'fenixflix', caseSensitive: false), 'Nebula');
          }
          if (stream['title'] is String) {
            stream['title'] = stream['title'].toString().replaceAll(
                RegExp(r'fenixflix', caseSensitive: false), 'Nebula');
          }
          final rawLabel = '${stream['name'] ?? ''} ${stream['title'] ?? ''}';
          final quality = _qualityFrom(rawLabel);
          final audio = _audioFrom(rawLabel);
          stream['displayName'] = source.brand;
          stream['displayDescription'] = [
            quality,
            if (audio != null) audio,
            'Opção ${(entry.key + 1).toString().padLeft(2, '0')}',
          ].join('  •  ');
          stream['displayQuality'] = quality;
          stream['displayAudio'] = audio;
          stream['sourceName'] = source.name;
          stream['sourceOrder'] = entry.key;
          stream['headers'] = requestHeadersOf(stream);
          return stream;
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching ${source.name}: $e');
    }
    return [];
  }

  /// Request headers a Stremio stream declares it needs
  /// (`behaviorHints.proxyHeaders.request`) — typically Referer, Origin or
  /// User-Agent. Hosts that check them answer 403 without them.
  static Map<String, String> requestHeadersOf(Map stream) {
    final hints = stream['behaviorHints'];
    if (hints is! Map) return const {};
    final proxy = hints['proxyHeaders'];
    if (proxy is! Map) return const {};
    final request = proxy['request'];
    if (request is! Map) return const {};
    return {
      for (final entry in request.entries)
        if (entry.key is String && entry.value != null)
          entry.key as String: entry.value.toString(),
    };
  }

  static String _qualityFrom(String label) {
    final match = RegExp(
      r'\b(4K|2160p|1440p|1080p|720p|480p|CAM)\b',
      caseSensitive: false,
    ).firstMatch(label);
    if (match == null) return 'Qualidade automática';
    final value = match.group(1)!.toLowerCase();
    if (value == '2160p' || value == '4k') return '4K';
    return value == 'cam' ? 'CAM' : value;
  }

  static String? _audioFrom(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('dublado')) return 'Dublado';
    if (normalized.contains('legendado')) return 'Legendado';
    if (normalized.contains('dual')) return 'Áudio dual';
    return null;
  }
}
