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
  final String? originalTitle;
  final String? tagline;
  final List<String>? directors;
  final List<String>? countries;

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
    this.originalTitle,
    this.tagline,
    this.directors,
    this.countries,
  });

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

  /// Audience average on a five-star scale, written the Brazilian way (4,1).
  String get starRating =>
      (voteAverage / 2).toStringAsFixed(1).replaceAll('.', ',');

  /// Original title, only when it differs from the localized one.
  String? get distinctOriginalTitle {
    final original = originalTitle?.trim();
    if (original == null || original.isEmpty) return null;
    return original.toLowerCase() == title.toLowerCase() ? null : original;
  }

  /// "Dirigido por …" / "Criado por …" line, when the credits are known.
  String? get directorLine {
    final names = directors;
    if (names == null || names.isEmpty) return null;
    final joined = names.length == 1
        ? names.first
        : '${names.take(names.length - 1).join(', ')} e ${names.last}';
    return '${mediaType == 'tv' ? 'Criado por' : 'Dirigido por'} $joined';
  }

  /// Film-catalogue credit line: "Brasil, França, 2024".
  String get originLine {
    return [
      ...?countries?.take(2),
      if (releaseDate != null && releaseDate!.length >= 4) formattedYear,
    ].join(', ');
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

    List<String>? directors;
    final storedDirectors = json['directors'];
    if (storedDirectors is List) {
      directors = storedDirectors.map((d) => d.toString()).toList();
    } else if (json['credits'] is Map && json['credits']['crew'] is List) {
      directors = [
        for (final c in json['credits']['crew'] as List)
          if (c is Map && c['job'] == 'Director' && c['name'] != null)
            c['name'].toString(),
      ];
    } else if (json['created_by'] is List) {
      directors = [
        for (final c in json['created_by'] as List)
          if (c is Map && c['name'] != null) c['name'].toString(),
      ];
    }

    List<String>? countries;
    final storedCountries = json['countries'];
    if (storedCountries is List) {
      countries = storedCountries.map((c) => c.toString()).toList();
    } else if (json['production_countries'] is List) {
      countries = [
        for (final c in json['production_countries'] as List)
          if (c is Map)
            countryName(c['iso_3166_1']?.toString(), c['name']?.toString()),
      ].whereType<String>().toList();
    } else if (json['origin_country'] is List) {
      countries = [
        for (final c in json['origin_country'] as List)
          countryName(c?.toString(), null),
      ].whereType<String>().toList();
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
      originalTitle: json['original_title'] ?? json['original_name'],
      tagline: (json['tagline'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['tagline'],
      directors: directors == null || directors.isEmpty ? null : directors,
      countries: countries == null || countries.isEmpty ? null : countries,
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
      'original_title': originalTitle,
      'tagline': tagline,
      'directors': directors,
      'countries': countries,
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
      originalTitle: originalTitle,
      tagline: tagline,
      directors: directors,
      countries: countries,
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
      originalTitle: originalTitle,
      tagline: tagline,
      directors: directors,
      countries: countries,
    );
  }
}

const _countryNames = {
  'AR': 'Argentina',
  'AU': 'Austrália',
  'AT': 'Áustria',
  'BE': 'Bélgica',
  'BR': 'Brasil',
  'CA': 'Canadá',
  'CL': 'Chile',
  'CN': 'China',
  'CO': 'Colômbia',
  'KR': 'Coreia do Sul',
  'DK': 'Dinamarca',
  'EG': 'Egito',
  'ES': 'Espanha',
  'US': 'Estados Unidos',
  'FI': 'Finlândia',
  'FR': 'França',
  'GR': 'Grécia',
  'HK': 'Hong Kong',
  'HU': 'Hungria',
  'IN': 'Índia',
  'ID': 'Indonésia',
  'IE': 'Irlanda',
  'IR': 'Irã',
  'IS': 'Islândia',
  'IL': 'Israel',
  'IT': 'Itália',
  'JP': 'Japão',
  'MX': 'México',
  'NO': 'Noruega',
  'NZ': 'Nova Zelândia',
  'NL': 'Países Baixos',
  'PE': 'Peru',
  'PL': 'Polônia',
  'PT': 'Portugal',
  'GB': 'Reino Unido',
  'CZ': 'República Tcheca',
  'RO': 'Romênia',
  'RU': 'Rússia',
  'SE': 'Suécia',
  'CH': 'Suíça',
  'TH': 'Tailândia',
  'TW': 'Taiwan',
  'TR': 'Turquia',
  'UA': 'Ucrânia',
  'UY': 'Uruguai',
  'DE': 'Alemanha',
  'ZA': 'África do Sul',
};

/// Portuguese country name for an ISO 3166-1 code; TMDB only ships English.
String? countryName(String? code, String? fallback) {
  final name = _countryNames[code?.toUpperCase()] ?? fallback ?? code;
  return name == null || name.isEmpty ? null : name;
}
