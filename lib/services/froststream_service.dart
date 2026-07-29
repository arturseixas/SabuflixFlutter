import 'dart:convert';
import 'package:http/http.dart' as http;

class FrostStreamService {
  static const String _baseUrl = 'https://froststream.cloutteam.com/stream';

  static Future<List<Map<String, dynamic>>> fetchStreams({
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
        return streams.map((s) => s as Map<String, dynamic>).toList();
      }
    } catch (e) {
      print('Error fetching FrostStream: $e');
    }
    return [];
  }
}
