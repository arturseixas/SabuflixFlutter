import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FrostStreamService {
  static const List<({String name, String brand, String baseUrl})> _sources = [
    (
      name: 'FrostStream',
      brand: 'Sabuflix Direct',
      baseUrl: 'https://froststream.cloutteam.com/stream',
    ),
    (
      name: 'BestCine',
      brand: 'Sabuflix Cinema',
      baseUrl: 'https://bestcine.alwaysdata.net',
    ),
  ];

  static Future<List<Map<String, dynamic>>> fetchStreams({
    required String imdbId,
    required String type, // 'movie' or 'tv'
    int? season,
    int? episode,
  }) async {
    if (imdbId.isEmpty) return [];

    if (type != 'movie' && (season == null || episode == null)) return [];

    final results = await Future.wait(
      _sources.map(
        (source) => _fetchSource(
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
      return url == null || url.isEmpty || seenUrls.add(url);
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> _fetchSource({
    required ({String name, String brand, String baseUrl}) source,
    required String imdbId,
    required String type,
    int? season,
    int? episode,
  }) async {
    final path = type == 'movie'
        ? '/stream/movie/$imdbId.json'
        : '/stream/series/$imdbId:$season:$episode.json';

    try {
      final response = await http
          .get(Uri.parse('${source.baseUrl}$path'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List streams = data['streams'] ?? [];
        return streams.whereType<Map>().toList().asMap().entries.where((entry) {
          final hints = entry.value['behaviorHints'];
          return !kIsWeb || hints is! Map || hints['notWebReady'] != true;
        }).map((entry) {
          final stream = Map<String, dynamic>.from(entry.value);
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
          stream['sourceName'] = source.name;
          return stream;
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching ${source.name}: $e');
    }
    return [];
  }

  static String _qualityFrom(String label) {
    final match = RegExp(
      r'\b(4K|2160p|1440p|1080p|720p|480p|CAM)\b',
      caseSensitive: false,
    ).firstMatch(label);
    if (match == null) return 'Qualidade automática';
    final value = match.group(1)!;
    return value.toLowerCase() == '2160p' ? '4K' : value.toUpperCase();
  }

  static String? _audioFrom(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('dublado')) return 'Dublado';
    if (normalized.contains('legendado')) return 'Legendado';
    if (normalized.contains('dual')) return 'Áudio dual';
    return null;
  }
}
