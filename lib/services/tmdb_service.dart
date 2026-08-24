import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';
import '../models/cast_member.dart';

class TMDBService {
  /// TMDB offers a free developer API. A build-time key keeps local and CI
  /// builds configurable while the current public client key remains a
  /// backwards-compatible fallback.
  static const String apiKey = String.fromEnvironment(
    'TMDB_API_KEY',
    defaultValue: 'ee0794f59f93b7a056bb76ef52dc28d0',
  );
  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String defaultLang = 'pt-BR';

  static final Map<int, String> genreMap = {
    28: 'Ação',
    12: 'Aventura',
    16: 'Animação',
    35: 'Comédia',
    80: 'Crime',
    99: 'Documentário',
    18: 'Drama',
    10751: 'Família',
    14: 'Fantasia',
    36: 'História',
    27: 'Terror',
    10402: 'Música',
    9648: 'Mistério',
    10749: 'Romance',
    878: 'Ficção Científica',
    10770: 'Cinema TV',
    53: 'Thriller',
    10752: 'Guerra',
    37: 'Faroeste',
    10759: 'Ação e Aventura TV',
    10762: 'Kids TV',
    10763: 'Notícias TV',
    10764: 'Reality TV',
    10765: 'Sci-Fi & Fantasia TV',
    10766: 'Soap TV',
    10767: 'Talk Show',
    10768: 'Guerra e Política TV',
  };

  static String getGenreName(int id) {
    return genreMap[id] ?? 'Entretenimento';
  }

  Future<List<MediaItem>> fetchTrending(
      {String mediaType = 'all', String timeWindow = 'week'}) async {
    final url = Uri.parse(
        '$baseUrl/trending/$mediaType/$timeWindow?api_key=$apiKey&language=$defaultLang');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => MediaItem.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching trending: $e');
    }
    return [];
  }

  Future<List<MediaItem>> fetchPopularMovies() async {
    final url = Uri.parse(
        '$baseUrl/movie/popular?api_key=$apiKey&language=$defaultLang&page=1');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results
            .map((item) => MediaItem.fromJson(item, defaultMediaType: 'movie'))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching popular movies: $e');
    }
    return [];
  }

  Future<List<MediaItem>> fetchPopularTV() async {
    final url = Uri.parse(
        '$baseUrl/tv/popular?api_key=$apiKey&language=$defaultLang&page=1');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results
            .map((item) => MediaItem.fromJson(item, defaultMediaType: 'tv'))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching popular tv: $e');
    }
    return [];
  }

  Future<List<MediaItem>> fetchTopRatedMovies() async {
    final url = Uri.parse(
        '$baseUrl/movie/top_rated?api_key=$apiKey&language=$defaultLang&page=1');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results
            .map((item) => MediaItem.fromJson(item, defaultMediaType: 'movie'))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching top rated: $e');
    }
    return [];
  }

  Future<List<MediaItem>> fetchByGenre(int genreId,
      {String mediaType = 'movie'}) async {
    final endpoint = mediaType == 'movie' ? 'discover/movie' : 'discover/tv';
    final url = Uri.parse(
        '$baseUrl/$endpoint?api_key=$apiKey&language=$defaultLang&with_genres=$genreId&sort_by=popularity.desc');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results
            .map(
                (item) => MediaItem.fromJson(item, defaultMediaType: mediaType))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching by genre $genreId: $e');
    }
    return [];
  }

  Future<MediaItem?> fetchMediaDetails(int id, String mediaType) async {
    final append =
        mediaType == 'tv' ? 'external_ids,content_ratings' : 'release_dates';
    final endpoint = mediaType == 'tv'
        ? 'tv/$id?append_to_response=$append&'
        : 'movie/$id?append_to_response=$append&';
    final url =
        Uri.parse('$baseUrl/${endpoint}api_key=$apiKey&language=$defaultLang');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract age rating for Brazil (BR)
        String? ageRating;
        if (mediaType == 'movie') {
          final releaseDates = data['release_dates']?['results'] as List?;
          if (releaseDates != null) {
            final brRelease = releaseDates
                .firstWhere((r) => r['iso_3166_1'] == 'BR', orElse: () => null);
            if (brRelease != null) {
              final dates = brRelease['release_dates'] as List?;
              if (dates != null && dates.isNotEmpty) {
                ageRating = dates.first['certification'];
                if (ageRating != null && ageRating.isEmpty) ageRating = null;
              }
            }
          }
        } else {
          final contentRatings = data['content_ratings']?['results'] as List?;
          if (contentRatings != null) {
            final brRating = contentRatings
                .firstWhere((r) => r['iso_3166_1'] == 'BR', orElse: () => null);
            if (brRating != null) {
              ageRating = brRating['rating'];
              if (ageRating != null && ageRating.isEmpty) ageRating = null;
            }
          }
        }

        // Normalize L to Livre or 10, 12, etc.
        if (ageRating == 'L') ageRating = 'Livre';

        data['ageRating'] = ageRating;

        final media = MediaItem.fromJson(data, defaultMediaType: mediaType);

        // Fetch trailer key & logo path in parallel
        final results = await Future.wait<String?>([
          fetchTrailerKey(id, mediaType),
          fetchLogoPath(id, mediaType),
        ]);

        return media.copyWith(
          trailerKey: results[0],
          logoPath: results[1],
        );
      }
    } catch (e) {
      debugPrint('Error fetching media details: $e');
    }
    return null;
  }

  Future<List<dynamic>> fetchSeasonEpisodes(int tvId, int seasonNumber) async {
    final url = Uri.parse(
        '$baseUrl/tv/$tvId/season/$seasonNumber?api_key=$apiKey&language=$defaultLang');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['episodes'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching season episodes: $e');
    }
    return [];
  }

  Future<String?> fetchLogoPath(int id, String mediaType) async {
    final endpoint = mediaType == 'tv' ? 'tv' : 'movie';
    final url = Uri.parse(
        '$baseUrl/$endpoint/$id/images?api_key=$apiKey&include_image_language=pt,en,null');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List logos = data['logos'] ?? [];
        if (logos.isNotEmpty) {
          final ptLogo = logos.firstWhere((l) => l['iso_639_1'] == 'pt',
              orElse: () => null);
          if (ptLogo != null && ptLogo['file_path'] != null) {
            return ptLogo['file_path'];
          }

          final enLogo = logos.firstWhere((l) => l['iso_639_1'] == 'en',
              orElse: () => null);
          if (enLogo != null && enLogo['file_path'] != null) {
            return enLogo['file_path'];
          }

          final anyLogo = logos.firstWhere((l) => l['file_path'] != null,
              orElse: () => null);
          if (anyLogo != null) return anyLogo['file_path'];
        }
      }
    } catch (e) {
      debugPrint('Error fetching logo path: $e');
    }
    return null;
  }

  Future<List<CastMember>> fetchCast(int id, String mediaType) async {
    final endpoint = mediaType == 'tv' ? 'tv' : 'movie';
    final url = Uri.parse(
        '$baseUrl/$endpoint/$id/credits?api_key=$apiKey&language=$defaultLang');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List castList = data['cast'] ?? [];
        return castList
            .map((item) => CastMember.fromJson(item))
            .take(10)
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching cast: $e');
    }
    return [];
  }

  Future<String?> fetchTrailerKey(int id, String mediaType) async {
    final endpoint = mediaType == 'tv' ? 'tv' : 'movie';
    final url = Uri.parse(
        '$baseUrl/$endpoint/$id/videos?api_key=$apiKey&language=$defaultLang');
    try {
      var response = await http.get(url);
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        List results = data['results'] ?? [];

        // If empty in pt-BR, try en-US
        if (results.isEmpty) {
          final fallbackUrl = Uri.parse(
              '$baseUrl/$endpoint/$id/videos?api_key=$apiKey&language=en-US');
          response = await http.get(fallbackUrl);
          if (response.statusCode == 200) {
            data = json.decode(response.body);
            results = data['results'] ?? [];
          }
        }

        final trailer = results.firstWhere(
          (v) =>
              (v['type'] == 'Trailer' || v['type'] == 'Teaser') &&
              v['site'] == 'YouTube',
          orElse: () => results.isNotEmpty ? results.first : null,
        );

        if (trailer != null) {
          return trailer['key'];
        }
      }
    } catch (e) {
      debugPrint('Error fetching trailer: $e');
    }
    return null;
  }

  Future<List<MediaItem>> fetchSimilar(int id, String mediaType) async {
    final endpoint = mediaType == 'tv' ? 'tv' : 'movie';
    final url = Uri.parse(
        '$baseUrl/$endpoint/$id/recommendations?api_key=$apiKey&language=$defaultLang');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results
            .map(
                (item) => MediaItem.fromJson(item, defaultMediaType: mediaType))
            .take(10)
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching recommendations: $e');
    }
    return [];
  }

  Future<List<MediaItem>> searchMedia(String query) async {
    if (query.trim().isEmpty) return [];
    final url = Uri.parse(
        '$baseUrl/search/multi?api_key=$apiKey&language=$defaultLang&query=${Uri.encodeComponent(query)}&page=1');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results
            .where((item) =>
                item['media_type'] == 'movie' || item['media_type'] == 'tv')
            .map((item) => MediaItem.fromJson(item))
            .toList();
      }
    } catch (e) {
      debugPrint('Error searching media: $e');
    }
    return [];
  }
}
