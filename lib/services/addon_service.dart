import 'dart:convert';
import 'package:http/http.dart' as http;

/// Public Stremio endpoints. Keep configuration encoded exactly once.
class AddonService {
  static const fenixBase =
      'https://fenixflix.fenixhub.online/qualities=4k,1080p,720p,sd%7Caudio=dublado,legendado%7Ccatalogs=populares_movie,populares_series,recentes_movie,recentes_series';
  static const subtitlesBase = 'https://opensubtitles-v3.strem.io';
  final http.Client? client;
  const AddonService({this.client});

  /// HTML video tracks require WebVTT; native players also accept SRT.
  Future<String> webSubtitle(String url) async {
    final response =
        await (client?.get(Uri.parse(url)) ?? http.get(Uri.parse(url)))
            .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw StateError('Legenda indisponível');
    final text =
        utf8.decode(response.bodyBytes).replaceFirst('\uFEFF', '').trim();
    if (text.startsWith('WEBVTT')) return text;
    if (!text.contains('-->')) {
      throw FormatException('Formato de legenda inválido');
    }
    return 'WEBVTT\n\n${text.replaceAllMapped(RegExp(r'(\d{2}:\d{2}:\d{2}),(\d{3})'), (m) => '${m[1]}.${m[2]}')}\n';
  }

  Future<List<Map<String, dynamic>>> _fetch(String url, String key) async {
    try {
      final response =
          await (client?.get(Uri.parse(url)) ?? http.get(Uri.parse(url)))
              .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data is! Map || data[key] is! List) return [];
      return (data[key] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> catalog(String type, String id) =>
      _fetch('$fenixBase/catalog/$type/$id.json', 'metas');

  Future<List<Map<String, dynamic>>> subtitles({
    required String imdbId,
    required String type,
    int? season,
    int? episode,
  }) async {
    if (!RegExp(r'^tt\d+$').hasMatch(imdbId) ||
        (type != 'movie' && (season == null || episode == null))) {
      return [];
    }
    final id = type == 'movie' ? imdbId : '$imdbId:$season:$episode';
    final items = await _fetch(
      '$subtitlesBase/subtitles/${type == 'movie' ? 'movie' : 'series'}/$id.json',
      'subtitles',
    );
    final seen = <String>{};
    final valid = items.where((item) {
      final url = item['url']?.toString() ?? '';
      final uri = Uri.tryParse(url);
      return uri != null &&
          ['https', 'http'].contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          seen.add(url);
    }).toList();
    bool portuguese(Map item) =>
        ['por', 'pob', 'pt', 'pt-BR'].contains(item['lang']);
    valid.sort(
      (a, b) => (portuguese(a) ? 0 : 1).compareTo(portuguese(b) ? 0 : 1),
    );
    return valid;
  }
}
