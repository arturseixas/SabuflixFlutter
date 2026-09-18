import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/cast_member.dart';
import '../models/media_details.dart';
import '../models/media_item.dart';
import 'addon_service.dart';

class TMDBService {
  Future<List<MediaItem>> fetchFenixCatalog(
    String type,
    String catalogId,
  ) async {
    final metas = await AddonService(client: _client).catalog(type, catalogId);
    final mediaType = type == 'series' ? 'tv' : 'movie';
    final items = await Future.wait(
      metas.take(12).map((meta) async {
        try {
          final id = meta['id']?.toString() ?? '';
          if (id.startsWith('tmdb:')) {
            final tmdbId = int.tryParse(id.substring(5));
            return tmdbId == null
                ? null
                : await fetchMediaDetails(tmdbId, mediaType);
          }
          if (!RegExp(r'^tt\d+$').hasMatch(id)) return null;
          final response = await _get(
            Uri.parse(
              '$baseUrl/find/$id?api_key=$apiKey&external_source=imdb_id&language=$defaultLang',
            ),
          );
          final results = jsonDecode(
            response.body,
          )[type == 'series' ? 'tv_results' : 'movie_results'];
          if (results is! List || results.isEmpty) return null;
          return MediaItem.fromJson(
            Map<String, dynamic>.from(results.first),
            defaultMediaType: mediaType,
          ).copyWith(imdbId: id);
        } catch (_) {
          return null;
        }
      }),
    );
    return items.whereType<MediaItem>().toList();
  }

  final http.Client? _client;
  final Duration timeout;
  TMDBService({http.Client? client, this.timeout = const Duration(seconds: 15)})
      : _client = client;
  Future<http.Response> _get(Uri uri) async {
    final response = await (_client?.get(uri) ?? http.get(uri)).timeout(
      timeout,
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Serviço de catálogo indisponível (${response.statusCode}).',
      );
    }
    return response;
  }

  /// TMDB offers a free developer API. A build-time key keeps local and CI
  /// builds configurable while the current public client key remains a
  /// backwards-compatible fallback.
  static const String apiKey = String.fromEnvironment(
    'TMDB_API_KEY',
    defaultValue: 'ee0794f59f93b7a056bb76ef52dc28d0',
  );
  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String defaultLang = 'pt-BR';
  static const String region = 'BR';

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

  /// Genres exposed to the viewer as filters (the TV-only ones are folded in).
  static const List<(int, String)> browseGenres = [
    (28, 'Ação'),
    (12, 'Aventura'),
    (16, 'Animação'),
    (35, 'Comédia'),
    (80, 'Crime'),
    (99, 'Documentário'),
    (18, 'Drama'),
    (10751, 'Família'),
    (14, 'Fantasia'),
    (36, 'História'),
    (27, 'Terror'),
    (10402, 'Música'),
    (9648, 'Mistério'),
    (10749, 'Romance'),
    (878, 'Ficção científica'),
    (53, 'Suspense'),
    (10752, 'Guerra'),
    (37, 'Faroeste'),
  ];

  /// Movie genre ids that have a TV counterpart under a different id.
  static int tvGenreFor(int movieGenreId) => switch (movieGenreId) {
        28 || 12 => 10759,
        878 || 14 => 10765,
        10752 => 10768,
        _ => movieGenreId,
      };

  Future<List<MediaItem>> _list(Uri url, {String? defaultMediaType}) async {
    final response = await _get(url);
    final data = json.decode(response.body);
    final List results = data['results'] ?? [];
    return results
        .whereType<Map>()
        .map((item) => MediaItem.fromJson(Map<String, dynamic>.from(item),
            defaultMediaType: defaultMediaType ?? 'movie'))
        .where((item) => item.posterPath != null || item.backdropPath != null)
        .toList();
  }

  Future<List<MediaItem>> _safeList(Uri url,
      {String? defaultMediaType, String label = 'list'}) async {
    try {
      return await _list(url, defaultMediaType: defaultMediaType);
    } catch (e) {
      debugPrint('Error fetching $label: $e');
      return [];
    }
  }

  Future<List<MediaItem>> fetchTrending({
    String mediaType = 'all',
    String timeWindow = 'week',
  }) =>
      _safeList(
        Uri.parse(
            '$baseUrl/trending/$mediaType/$timeWindow?api_key=$apiKey&language=$defaultLang'),
        defaultMediaType: mediaType == 'tv' ? 'tv' : 'movie',
        label: 'trending',
      );

  Future<List<MediaItem>> fetchPopularMovies({int page = 1}) => _safeList(
        Uri.parse(
            '$baseUrl/movie/popular?api_key=$apiKey&language=$defaultLang&region=$region&page=$page'),
        defaultMediaType: 'movie',
        label: 'popular movies',
      );

  Future<List<MediaItem>> fetchPopularTV({int page = 1}) => _safeList(
        Uri.parse(
            '$baseUrl/tv/popular?api_key=$apiKey&language=$defaultLang&page=$page'),
        defaultMediaType: 'tv',
        label: 'popular tv',
      );

  Future<List<MediaItem>> fetchTopRatedMovies({int page = 1}) => _safeList(
        Uri.parse(
            '$baseUrl/movie/top_rated?api_key=$apiKey&language=$defaultLang&region=$region&page=$page'),
        defaultMediaType: 'movie',
        label: 'top rated',
      );

  Future<List<MediaItem>> fetchTopRatedTV({int page = 1}) => _safeList(
        Uri.parse(
            '$baseUrl/tv/top_rated?api_key=$apiKey&language=$defaultLang&page=$page'),
        defaultMediaType: 'tv',
        label: 'top rated tv',
      );

  /// Films that reach Brazilian cinemas in the coming weeks.
  Future<List<MediaItem>> fetchUpcomingMovies() => _safeList(
        Uri.parse(
            '$baseUrl/movie/upcoming?api_key=$apiKey&language=$defaultLang&region=$region'),
        defaultMediaType: 'movie',
        label: 'upcoming',
      );

  Future<List<MediaItem>> fetchNowPlayingMovies() => _safeList(
        Uri.parse(
            '$baseUrl/movie/now_playing?api_key=$apiKey&language=$defaultLang&region=$region'),
        defaultMediaType: 'movie',
        label: 'now playing',
      );

  /// Series with a new episode this week.
  Future<List<MediaItem>> fetchOnTheAirTV() => _safeList(
        Uri.parse(
            '$baseUrl/tv/on_the_air?api_key=$apiKey&language=$defaultLang'),
        defaultMediaType: 'tv',
        label: 'on the air',
      );

  /// Brazilian productions, movies and series mixed.
  Future<List<MediaItem>> fetchBrazilian() async {
    final results = await Future.wait([
      _safeList(
        Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&language=$defaultLang&with_origin_country=BR&sort_by=popularity.desc&vote_count.gte=20'),
        defaultMediaType: 'movie',
        label: 'brazilian movies',
      ),
      _safeList(
        Uri.parse(
            '$baseUrl/discover/tv?api_key=$apiKey&language=$defaultLang&with_origin_country=BR&sort_by=popularity.desc&vote_count.gte=10'),
        defaultMediaType: 'tv',
        label: 'brazilian tv',
      ),
    ]);
    final merged = <MediaItem>[];
    final movies = results[0];
    final series = results[1];
    for (var i = 0; i < movies.length || i < series.length; i++) {
      if (i < movies.length) merged.add(movies[i]);
      if (i < series.length) merged.add(series[i]);
    }
    return merged;
  }

  Future<List<MediaItem>> fetchByGenre(
    int genreId, {
    String mediaType = 'movie',
    int page = 1,
  }) async {
    final endpoint = mediaType == 'movie' ? 'discover/movie' : 'discover/tv';
    final id = mediaType == 'movie' ? genreId : tvGenreFor(genreId);
    final url = Uri.parse(
      '$baseUrl/$endpoint?api_key=$apiKey&language=$defaultLang&with_genres=$id&sort_by=popularity.desc&vote_count.gte=${mediaType == 'movie' ? 50 : 20}&page=$page',
    );
    // Deliberately not swallowed: the search screen tells the viewer apart a
    // network failure from an empty genre.
    return _list(url, defaultMediaType: mediaType);
  }

  /// Flexible discovery for the search filters.
  Future<List<MediaItem>> discover({
    required String mediaType,
    int? genreId,
    int? year,
    String sortBy = 'popularity.desc',
    int page = 1,
  }) {
    final endpoint = mediaType == 'movie' ? 'discover/movie' : 'discover/tv';
    final buffer = StringBuffer(
        '$baseUrl/$endpoint?api_key=$apiKey&language=$defaultLang&sort_by=$sortBy&page=$page&vote_count.gte=${sortBy.startsWith('vote_average') ? 200 : 20}');
    if (genreId != null) {
      buffer.write(
          '&with_genres=${mediaType == 'movie' ? genreId : tvGenreFor(genreId)}');
    }
    if (year != null) {
      buffer.write(mediaType == 'movie'
          ? '&primary_release_year=$year'
          : '&first_air_date_year=$year');
    }
    return _list(Uri.parse(buffer.toString()), defaultMediaType: mediaType);
  }

  Future<MediaItem?> fetchMediaDetails(int id, String mediaType) async {
    final append =
        mediaType == 'tv' ? 'external_ids,content_ratings' : 'release_dates';
    final endpoint = mediaType == 'tv'
        ? 'tv/$id?append_to_response=$append&'
        : 'movie/$id?append_to_response=$append&';
    final url = Uri.parse(
      '$baseUrl/${endpoint}api_key=$apiKey&language=$defaultLang',
    );
    try {
      final response = await _get(url);
      final data = json.decode(response.body);
      data['ageRating'] = _ageRatingFrom(data, mediaType);
      final media = MediaItem.fromJson(data, defaultMediaType: mediaType);

      // Fetch trailer key & logo path in parallel
      final results = await Future.wait<String?>([
        fetchTrailerKey(id, mediaType),
        fetchLogoPath(id, mediaType),
      ]);

      return media.copyWith(trailerKey: results[0], logoPath: results[1]);
    } catch (e) {
      debugPrint('Error fetching media details: $e');
    }
    return null;
  }

  /// One round trip with everything the details screen needs.
  Future<MediaDetails?> fetchFullDetails(int id, String mediaType) async {
    final isTv = mediaType == 'tv';
    final append = [
      if (isTv) 'external_ids' else 'release_dates',
      if (isTv) 'content_ratings',
      'videos',
      'images',
      'credits',
      'recommendations',
      'similar',
      'watch/providers',
    ].join(',');
    final url = Uri.parse(
      '$baseUrl/${isTv ? 'tv' : 'movie'}/$id?api_key=$apiKey&language=$defaultLang'
      '&append_to_response=$append&include_image_language=pt,en,null',
    );
    try {
      final response = await _get(url);
      final data = Map<String, dynamic>.from(json.decode(response.body) as Map);
      data['ageRating'] = _ageRatingFrom(data, mediaType);
      var media = MediaItem.fromJson(data, defaultMediaType: mediaType);
      media = media.copyWith(
        trailerKey: _trailerFrom(data['videos']),
        logoPath: _logoFrom(data['images']),
      );

      final credits = data['credits'];
      final cast = <CastMember>[];
      final crew = <CrewMember>[];
      if (credits is Map) {
        for (final entry in (credits['cast'] as List? ?? const []).take(20)) {
          if (entry is Map) {
            cast.add(CastMember.fromJson(Map<String, dynamic>.from(entry)));
          }
        }
        for (final entry in credits['crew'] as List? ?? const []) {
          if (entry is! Map) continue;
          final job = entry['job']?.toString() ?? '';
          if (job == 'Director' || job == 'Writer' || job == 'Screenplay') {
            crew.add(CrewMember(
              id: (entry['id'] as num?)?.toInt() ?? 0,
              name: entry['name']?.toString() ?? '',
              job: job,
            ));
          }
        }
      }
      for (final creator in data['created_by'] as List? ?? const []) {
        if (creator is Map) {
          crew.add(CrewMember(
            id: (creator['id'] as num?)?.toInt() ?? 0,
            name: creator['name']?.toString() ?? '',
            job: 'Creator',
          ));
        }
      }

      List<MediaItem> items(dynamic block) {
        if (block is! Map) return const [];
        final list = block['results'];
        if (list is! List) return const [];
        return list
            .whereType<Map>()
            .map((item) => MediaItem.fromJson(Map<String, dynamic>.from(item),
                defaultMediaType: mediaType))
            .where((item) => item.posterPath != null)
            .take(20)
            .toList();
      }

      final providers = <WatchProvider>[];
      String? providersLink;
      final providerBlock = data['watch/providers'];
      if (providerBlock is Map) {
        final br = (providerBlock['results'] as Map?)?[region];
        if (br is Map) {
          providersLink = br['link']?.toString();
          final seen = <int>{};
          for (final kind in const ['flatrate', 'free', 'ads', 'rent', 'buy']) {
            for (final entry in br[kind] as List? ?? const []) {
              if (entry is! Map) continue;
              final providerId = (entry['provider_id'] as num?)?.toInt() ?? 0;
              if (!seen.add(providerId)) continue;
              providers.add(WatchProvider(
                id: providerId,
                name: entry['provider_name']?.toString() ?? '',
                kind: kind,
                logoPath: entry['logo_path']?.toString(),
              ));
            }
          }
        }
      }

      EpisodeSummary? summary(dynamic raw) {
        if (raw is! Map) return null;
        final season = (raw['season_number'] as num?)?.toInt();
        final episode = (raw['episode_number'] as num?)?.toInt();
        if (season == null || episode == null) return null;
        return EpisodeSummary(
          season: season,
          episode: episode,
          name: raw['name']?.toString(),
          airDate: raw['air_date']?.toString(),
        );
      }

      final networks = <String>[
        for (final network in data['networks'] as List? ?? const [])
          if (network is Map && network['name'] != null)
            network['name'].toString(),
      ];
      if (networks.isEmpty) {
        for (final company
            in (data['production_companies'] as List? ?? const []).take(2)) {
          if (company is Map && company['name'] != null) {
            networks.add(company['name'].toString());
          }
        }
      }

      var details = MediaDetails(
        media: media,
        cast: cast,
        crew: crew,
        recommendations: items(data['recommendations']),
        similar: items(data['similar']),
        providers: providers,
        providersLink: providersLink,
        networks: networks,
        nextEpisode: summary(data['next_episode_to_air']),
        lastEpisode: summary(data['last_episode_to_air']),
      );

      final collectionRaw = data['belongs_to_collection'];
      if (collectionRaw is Map && collectionRaw['id'] is num) {
        final collection =
            await fetchCollection((collectionRaw['id'] as num).toInt());
        if (collection != null) {
          details = details.copyWith(collection: collection);
        }
      }
      return details;
    } catch (e) {
      debugPrint('Error fetching full details: $e');
      return null;
    }
  }

  Future<MediaCollection?> fetchCollection(int id) async {
    try {
      final response = await _get(Uri.parse(
          '$baseUrl/collection/$id?api_key=$apiKey&language=$defaultLang'));
      final data = Map<String, dynamic>.from(json.decode(response.body) as Map);
      final parts = (data['parts'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => MediaItem.fromJson(Map<String, dynamic>.from(item),
              defaultMediaType: 'movie'))
          .where((item) => item.posterPath != null)
          .toList()
        ..sort((a, b) =>
            (a.releaseDate ?? '9999').compareTo(b.releaseDate ?? '9999'));
      if (parts.length < 2) return null;
      return MediaCollection(
        id: id,
        name: data['name']?.toString() ?? 'Coleção',
        backdropPath: data['backdrop_path']?.toString(),
        parts: parts,
      );
    } catch (e) {
      debugPrint('Error fetching collection: $e');
      return null;
    }
  }

  static String? _ageRatingFrom(Map<dynamic, dynamic> data, String mediaType) {
    String? ageRating;
    if (mediaType == 'movie') {
      final releaseDates = data['release_dates']?['results'] as List?;
      if (releaseDates != null) {
        final brRelease = releaseDates.firstWhere(
          (r) => r['iso_3166_1'] == region,
          orElse: () => null,
        );
        if (brRelease != null) {
          final dates = brRelease['release_dates'] as List?;
          if (dates != null && dates.isNotEmpty) {
            for (final entry in dates) {
              final certification = entry['certification']?.toString();
              if (certification != null && certification.isNotEmpty) {
                ageRating = certification;
                break;
              }
            }
          }
        }
      }
    } else {
      final contentRatings = data['content_ratings']?['results'] as List?;
      if (contentRatings != null) {
        final brRating = contentRatings.firstWhere(
          (r) => r['iso_3166_1'] == region,
          orElse: () => null,
        );
        if (brRating != null) {
          ageRating = brRating['rating']?.toString();
          if (ageRating != null && ageRating.isEmpty) ageRating = null;
        }
      }
    }
    if (ageRating == 'L') ageRating = 'Livre';
    return ageRating;
  }

  static String? _trailerFrom(dynamic videos) {
    if (videos is! Map) return null;
    final results = videos['results'];
    if (results is! List || results.isEmpty) return null;
    for (final type in const ['Trailer', 'Teaser']) {
      for (final video in results) {
        if (video is Map &&
            video['type'] == type &&
            video['site'] == 'YouTube') {
          return video['key']?.toString();
        }
      }
    }
    final first = results.first;
    return first is Map ? first['key']?.toString() : null;
  }

  static String? _logoFrom(dynamic images) {
    if (images is! Map) return null;
    final logos = images['logos'];
    if (logos is! List || logos.isEmpty) return null;
    for (final language in const ['pt', 'en']) {
      for (final logo in logos) {
        if (logo is Map &&
            logo['iso_639_1'] == language &&
            logo['file_path'] != null) {
          return logo['file_path'].toString();
        }
      }
    }
    for (final logo in logos) {
      if (logo is Map && logo['file_path'] != null) {
        return logo['file_path'].toString();
      }
    }
    return null;
  }

  Future<List<dynamic>> fetchSeasonEpisodes(int tvId, int seasonNumber) async {
    final url = Uri.parse(
      '$baseUrl/tv/$tvId/season/$seasonNumber?api_key=$apiKey&language=$defaultLang',
    );
    try {
      final response = await _get(url);
      final data = json.decode(response.body);
      return data['episodes'] ?? [];
    } catch (e) {
      debugPrint('Error fetching season episodes: $e');
    }
    return [];
  }

  Future<String?> fetchLogoPath(int id, String mediaType) async {
    final endpoint = mediaType == 'tv' ? 'tv' : 'movie';
    final url = Uri.parse(
      '$baseUrl/$endpoint/$id/images?api_key=$apiKey&include_image_language=pt,en,null',
    );
    try {
      final response = await _get(url);
      return _logoFrom(json.decode(response.body));
    } catch (e) {
      debugPrint('Error fetching logo path: $e');
    }
    return null;
  }

  Future<List<CastMember>> fetchCast(int id, String mediaType) async {
    final endpoint = mediaType == 'tv' ? 'tv' : 'movie';
    final url = Uri.parse(
      '$baseUrl/$endpoint/$id/credits?api_key=$apiKey&language=$defaultLang',
    );
    try {
      final response = await _get(url);
      final data = json.decode(response.body);
      final List castList = data['cast'] ?? [];
      return castList
          .map((item) => CastMember.fromJson(item))
          .take(10)
          .toList();
    } catch (e) {
      debugPrint('Error fetching cast: $e');
    }
    return [];
  }

  Future<String?> fetchTrailerKey(int id, String mediaType) async {
    final endpoint = mediaType == 'tv' ? 'tv' : 'movie';
    try {
      var response = await _get(Uri.parse(
          '$baseUrl/$endpoint/$id/videos?api_key=$apiKey&language=$defaultLang'));
      var key = _trailerFrom(json.decode(response.body));
      if (key == null) {
        // If empty in pt-BR, try en-US
        response = await _get(Uri.parse(
            '$baseUrl/$endpoint/$id/videos?api_key=$apiKey&language=en-US'));
        key = _trailerFrom(json.decode(response.body));
      }
      return key;
    } catch (e) {
      debugPrint('Error fetching trailer: $e');
    }
    return null;
  }

  Future<List<MediaItem>> fetchSimilar(int id, String mediaType) async {
    final endpoint = mediaType == 'tv' ? 'tv' : 'movie';
    final items = await _safeList(
      Uri.parse(
          '$baseUrl/$endpoint/$id/recommendations?api_key=$apiKey&language=$defaultLang'),
      defaultMediaType: mediaType,
      label: 'recommendations',
    );
    return items.take(10).toList();
  }

  /// Titles that go well with something the viewer already watched.
  Future<List<MediaItem>> fetchRecommendationsFor(MediaItem seed) async {
    final items = await _safeList(
      Uri.parse(
          '$baseUrl/${seed.mediaType == 'tv' ? 'tv' : 'movie'}/${seed.id}/recommendations?api_key=$apiKey&language=$defaultLang'),
      defaultMediaType: seed.mediaType,
      label: 'because you watched',
    );
    return items.where((item) => item.id != seed.id).toList();
  }

  Future<List<MediaItem>> searchMedia(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final url = Uri.parse(
      '$baseUrl/search/multi?api_key=$apiKey&language=$defaultLang&query=${Uri.encodeComponent(query)}&page=$page&include_adult=false',
    );
    final response = await _get(url);
    final data = json.decode(response.body);
    final List results = data['results'] ?? [];
    return results
        .where(
          (item) => item['media_type'] == 'movie' || item['media_type'] == 'tv',
        )
        .map((item) => MediaItem.fromJson(item))
        .toList();
  }
}
