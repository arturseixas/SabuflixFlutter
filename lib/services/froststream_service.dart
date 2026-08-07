import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stream_source.dart';

class FrostStreamService {
  static const String _baseUrl = 'https://froststream.cloutteam.com/stream';

  /// Returns sources already normalised into [StreamSource], so nothing the
  /// provider names itself is ever handed to the UI.
  static Future<List<StreamSource>> fetchStreams({
    required String imdbId,
    required String type, // 'movie' or 'tv'
    int? season,
    int? episode,
  }) async {
    if (imdbId.isEmpty) return [];

    String url;
    if (type == 'movie') {
      url = '$_baseUrl/movie/$imdbId.json';
    } else {
      if (season == null || episode == null) return [];
      url = '$_baseUrl/series/$imdbId:$season:$episode.json';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List streams = data['streams'] ?? [];
        final sources = streams
            .whereType<Map>()
            .map((s) => StreamSource.tryParse(Map<String, dynamic>.from(s)))
            .whereType<StreamSource>()
            .toList();
        sources.sort(StreamSource.compareByQuality);
        return sources;
      }
    } catch (e) {
      print('Error fetching FrostStream: $e');
    }
    return [];
  }
}
