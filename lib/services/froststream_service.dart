import 'dart:convert';
import 'package:http/http.dart' as http;

class FrostStreamService {
  static const String _baseUrl = 'https://froststream.cloutteam.com/stream';

  /// Reused across calls so repeat lookups skip a fresh TLS handshake.
  static final http.Client _client = http.Client();

  /// A source that hasn't answered by now is treated as unavailable rather
  /// than left to hang on the socket's own (multi-minute) timeout.
  static const Duration _timeout = Duration(seconds: 10);

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
      final response = await _client.get(Uri.parse(url)).timeout(_timeout);
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
