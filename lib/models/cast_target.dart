enum CastTargetKind { googleCast, samsung, lg, roku, dlna }

extension CastTargetKindLabel on CastTargetKind {
  String get label {
    switch (this) {
      case CastTargetKind.googleCast:
        return 'Google Cast';
      case CastTargetKind.samsung:
        return 'Samsung Smart TV';
      case CastTargetKind.lg:
        return 'LG webOS TV';
      case CastTargetKind.roku:
        return 'Roku';
      case CastTargetKind.dlna:
        return 'Smart TV / DLNA';
    }
  }
}

class CastTarget {
  final String id;
  final String name;
  final CastTargetKind kind;
  final String address;
  final int port;

  const CastTarget({
    required this.id,
    required this.name,
    required this.kind,
    required this.address,
    required this.port,
  });
}

class CastMediaRequest {
  final String url;
  final String title;
  final String? imageUrl;
  final Duration startPosition;

  const CastMediaRequest({
    required this.url,
    required this.title,
    this.imageUrl,
    this.startPosition = Duration.zero,
  });
}
