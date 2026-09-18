import 'cast_member.dart';
import 'media_item.dart';

/// Director, creator or writer credit shown in the details header.
class CrewMember {
  final int id;
  final String name;
  final String job;
  const CrewMember({required this.id, required this.name, required this.job});
}

/// A streaming service that legally offers the title in Brazil (TMDB data,
/// powered by JustWatch).
class WatchProvider {
  final int id;
  final String name;
  final String? logoPath;

  /// `flatrate`, `rent`, `buy`, `free` or `ads`.
  final String kind;

  const WatchProvider({
    required this.id,
    required this.name,
    required this.kind,
    this.logoPath,
  });

  String? get fullLogoPath =>
      logoPath == null ? null : 'https://image.tmdb.org/t/p/w92$logoPath';

  String get kindLabel => switch (kind) {
        'flatrate' => 'Assinatura',
        'rent' => 'Aluguel',
        'buy' => 'Compra',
        'free' => 'Grátis',
        'ads' => 'Com anúncios',
        _ => kind,
      };
}

/// A film franchise (`belongs_to_collection`).
class MediaCollection {
  final int id;
  final String name;
  final String? backdropPath;
  final List<MediaItem> parts;
  const MediaCollection({
    required this.id,
    required this.name,
    required this.parts,
    this.backdropPath,
  });
}

/// Upcoming or most recent episode of a series in production.
class EpisodeSummary {
  final int season;
  final int episode;
  final String? name;
  final String? airDate;
  const EpisodeSummary({
    required this.season,
    required this.episode,
    this.name,
    this.airDate,
  });
}

/// Everything the details screen shows, fetched in one TMDB round trip.
class MediaDetails {
  final MediaItem media;
  final List<CastMember> cast;
  final List<CrewMember> crew;
  final List<MediaItem> recommendations;
  final List<MediaItem> similar;
  final List<WatchProvider> providers;
  final String? providersLink;
  final MediaCollection? collection;
  final List<String> networks;
  final EpisodeSummary? nextEpisode;
  final EpisodeSummary? lastEpisode;

  const MediaDetails({
    required this.media,
    this.cast = const [],
    this.crew = const [],
    this.recommendations = const [],
    this.similar = const [],
    this.providers = const [],
    this.providersLink,
    this.collection,
    this.networks = const [],
    this.nextEpisode,
    this.lastEpisode,
  });

  List<CrewMember> get directors =>
      crew.where((c) => c.job == 'Director').toList();
  List<CrewMember> get creators =>
      crew.where((c) => c.job == 'Creator').toList();
  List<CrewMember> get writers => crew
      .where(
          (c) => c.job == 'Writer' || c.job == 'Screenplay' || c.job == 'Novel')
      .toList();

  MediaDetails copyWith({MediaItem? media, MediaCollection? collection}) {
    return MediaDetails(
      media: media ?? this.media,
      cast: cast,
      crew: crew,
      recommendations: recommendations,
      similar: similar,
      providers: providers,
      providersLink: providersLink,
      collection: collection ?? this.collection,
      networks: networks,
      nextEpisode: nextEpisode,
      lastEpisode: lastEpisode,
    );
  }
}
