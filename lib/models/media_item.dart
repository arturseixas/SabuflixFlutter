class MediaItem {
  final int id;
  final String title;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String? logoPath;
  final double voteAverage;
  final int voteCount;
  final String? releaseDate;
  final String mediaType; // 'movie' or 'tv'
  final List<int> genreIds;
  final List<String>? genres;
  final int? runtime;
  final int? numberOfSeasons;
  final String? trailerKey;
  final String? imdbId;
  final List<dynamic>? seasons; // To store season details for TV shows
  final String? ageRating;

  MediaItem({
    required this.id,
    required this.title,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.logoPath,
    required this.voteAverage,
    required this.voteCount,
    this.releaseDate,
    required this.mediaType,
    required this.genreIds,
    this.genres,
    this.runtime,
    this.numberOfSeasons,
    this.trailerKey,
    this.imdbId,
    this.seasons,
    this.ageRating,
  });

  String get fullPosterPath {
    if (posterPath != null && posterPath!.isNotEmpty) {
      return 'https://image.tmdb.org/t/p/w500$posterPath';
    }
    return 'https://via.placeholder.com/500x750/14141F/FFFFFF?text=Sabuflix';
  }

  String get fullBackdropPath {
    if (backdropPath != null && backdropPath!.isNotEmpty) {
      return 'https://image.tmdb.org/t/p/w1280$backdropPath';
    }
    return fullPosterPath;
  }

  String? get fullLogoPath {
    if (logoPath != null && logoPath!.isNotEmpty) {
      return 'https://image.tmdb.org/t/p/w500$logoPath';
    }
    return null;
  }

  String get formattedYear {
    if (releaseDate != null && releaseDate!.length >= 4) {
      return releaseDate!.substring(0, 4);
    }
    return '2026';
  }

  String get formattedRating {
    return voteAverage.toStringAsFixed(1);
  }

  factory MediaItem.fromJson(Map<String, dynamic> json, {String defaultMediaType = 'movie'}) {
    final titleStr = json['title'] ?? json['name'] ?? json['original_title'] ?? json['original_name'] ?? 'Sem Título';
    final mType = json['media_type'] ?? (json['first_air_date'] != null ? 'tv' : defaultMediaType);
    final rDate = json['release_date'] ?? json['first_air_date'];

    // `genres` comes in two incompatible shapes depending on the source:
    // TMDB's raw API responses use `[{id, name}, ...]`, but our own
    // toJson() flattens it to `[name, ...]` for storage. Every persisted
    // MediaItem (favorites, playlists, downloads) round-trips through
    // exactly this parser, so it must accept both.
    List<int> gIds = [];
    if (json['genre_ids'] != null) {
      gIds = List<int>.from(json['genre_ids']);
    } else if (json['genres'] != null) {
      gIds = (json['genres'] as List).whereType<Map>().map((g) => g['id'] as int).toList();
    }

    List<String>? gNames;
    if (json['genres'] != null) {
      gNames = (json['genres'] as List)
          .map((g) => g is Map ? g['name'].toString() : g.toString())
          .toList();
    }

    String? parsedImdbId = json['imdb_id'];
    if (parsedImdbId == null && json['external_ids'] != null) {
      parsedImdbId = json['external_ids']['imdb_id'];
    }

    return MediaItem(
      id: json['id'] ?? 0,
      title: titleStr,
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      logoPath: json['logo_path'],
      voteAverage: (json['vote_average'] is num) ? (json['vote_average'] as num).toDouble() : 0.0,
      voteCount: json['vote_count'] ?? 0,
      releaseDate: rDate,
      mediaType: mType,
      genreIds: gIds,
      genres: gNames,
      runtime: json['runtime'],
      numberOfSeasons: json['number_of_seasons'],
      trailerKey: json['trailerKey'],
      imdbId: parsedImdbId ?? json['imdbId'],
      seasons: json['seasons'],
      ageRating: json['ageRating'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'logo_path': logoPath,
      'vote_average': voteAverage,
      'vote_count': voteCount,
      'release_date': releaseDate,
      'media_type': mediaType,
      'genre_ids': genreIds,
      'genres': genres,
      'runtime': runtime,
      'number_of_seasons': numberOfSeasons,
      'trailerKey': trailerKey,
      'imdbId': imdbId,
      'seasons': seasons,
      'ageRating': ageRating,
    };
  }

  MediaItem copyWith({
    String? trailerKey,
    String? logoPath,
    List<String>? genres,
    int? runtime,
    int? numberOfSeasons,
    String? imdbId,
    List<dynamic>? seasons,
    String? ageRating,
  }) {
    return MediaItem(
      id: id,
      title: title,
      overview: overview,
      posterPath: posterPath,
      backdropPath: backdropPath,
      logoPath: logoPath ?? this.logoPath,
      voteAverage: voteAverage,
      voteCount: voteCount,
      releaseDate: releaseDate,
      mediaType: mediaType,
      genreIds: genreIds,
      genres: genres ?? this.genres,
      runtime: runtime ?? this.runtime,
      numberOfSeasons: numberOfSeasons ?? this.numberOfSeasons,
      trailerKey: trailerKey ?? this.trailerKey,
      imdbId: imdbId ?? this.imdbId,
      seasons: seasons ?? this.seasons,
      ageRating: ageRating ?? this.ageRating,
    );
  }
}
