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
  final String? tagline;

  /// TMDB status: `Released`, `Returning Series`, `Ended`, `Canceled`…
  final String? status;
  final String? originalTitle;
  final double popularity;

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
    this.tagline,
    this.status,
    this.originalTitle,
    this.popularity = 0,
  });

  bool get isSeries => mediaType == 'tv';

  /// `Em exibição`, `Finalizada`… for series; `Lançado` / `Em breve` for films.
  String? get statusLabel {
    switch (status) {
      case 'Returning Series':
        return 'Em exibição';
      case 'Ended':
        return 'Finalizada';
      case 'Canceled':
        return 'Cancelada';
      case 'In Production':
      case 'Planned':
      case 'Post Production':
        return 'Em produção';
      case 'Released':
        return null;
      default:
        return null;
    }
  }

  /// `1h 52min` for films, `3 temporadas` for series.
  String? get lengthLabel {
    if (isSeries) {
      final seasons = numberOfSeasons;
      if (seasons == null || seasons <= 0) return null;
      return seasons == 1 ? '1 temporada' : '$seasons temporadas';
    }
    final minutes = runtime;
    if (minutes == null || minutes <= 0) return null;
    if (minutes < 60) return '$minutes min';
    final rest = minutes % 60;
    return rest == 0 ? '${minutes ~/ 60}h' : '${minutes ~/ 60}h ${rest}min';
  }

  bool get isUnreleased {
    final date = DateTime.tryParse(releaseDate ?? '');
    return date != null && date.isAfter(DateTime.now());
  }

  String get storageKey => '${mediaType}_$id';

  String get fullPosterPath {
    if (posterPath != null && posterPath!.isNotEmpty) {
      return 'https://image.tmdb.org/t/p/w500$posterPath';
    }
    return '';
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
    return 'Ano não informado';
  }

  String get formattedRating {
    return voteAverage.toStringAsFixed(1);
  }

  factory MediaItem.fromJson(Map<String, dynamic> json,
      {String defaultMediaType = 'movie'}) {
    final titleStr = json['title'] ??
        json['name'] ??
        json['original_title'] ??
        json['original_name'] ??
        'Sem Título';
    final mType = json['media_type'] ??
        (json['first_air_date'] != null ? 'tv' : defaultMediaType);
    final rDate = json['release_date'] ?? json['first_air_date'];

    // Genres arrive in two shapes: TMDB sends `[{id, name}]`, while an item
    // that has been through `toJson()` (favourites, downloads, continue
    // watching) comes back as a plain `[String]`. Parsing only the TMDB shape
    // used to throw while decoding local storage, and the caller's catch-all
    // then discarded the *entire* saved list — which is how saved items
    // "disappear" after the app is closed.
    List<int> gIds = [];
    final rawGenreIds = json['genre_ids'];
    if (rawGenreIds is List) {
      gIds = rawGenreIds.whereType<num>().map((g) => g.toInt()).toList();
    }

    List<String>? gNames;
    final rawGenres = json['genres'];
    if (rawGenres is List) {
      final names = <String>[];
      final idsFromGenres = <int>[];
      for (final g in rawGenres) {
        if (g is Map) {
          final id = g['id'];
          if (id is num) idsFromGenres.add(id.toInt());
          if (g['name'] != null) names.add(g['name'].toString());
        } else if (g != null) {
          names.add(g.toString());
        }
      }
      if (names.isNotEmpty) gNames = names;
      if (gIds.isEmpty) gIds = idsFromGenres;
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
      voteAverage: (json['vote_average'] is num)
          ? (json['vote_average'] as num).toDouble()
          : 0.0,
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
      tagline: json['tagline']?.toString(),
      status: json['status']?.toString(),
      originalTitle:
          (json['original_title'] ?? json['original_name'])?.toString(),
      popularity: (json['popularity'] is num)
          ? (json['popularity'] as num).toDouble()
          : 0.0,
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
      'tagline': tagline,
      'status': status,
      'original_title': originalTitle,
      'popularity': popularity,
    };
  }

  /// A slimmed copy meant for local storage.
  ///
  /// TMDB's `seasons` payload is several kilobytes per series and is always
  /// re-fetched when the details screen opens, so it is dropped before a title
  /// is written to shared preferences.
  MediaItem get forStorage {
    if (seasons == null) return this;
    return MediaItem(
      id: id,
      title: title,
      overview: overview,
      posterPath: posterPath,
      backdropPath: backdropPath,
      logoPath: logoPath,
      voteAverage: voteAverage,
      voteCount: voteCount,
      releaseDate: releaseDate,
      mediaType: mediaType,
      genreIds: genreIds,
      genres: genres,
      runtime: runtime,
      numberOfSeasons: numberOfSeasons,
      trailerKey: trailerKey,
      imdbId: imdbId,
      ageRating: ageRating,
      tagline: tagline,
      status: status,
      originalTitle: originalTitle,
      popularity: popularity,
    );
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
    String? tagline,
    String? status,
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
      tagline: tagline ?? this.tagline,
      status: status ?? this.status,
      originalTitle: originalTitle,
      popularity: popularity,
    );
  }
}
