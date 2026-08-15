import '../../models/cast_target.dart';

abstract class CastingService {
  bool get isSupported;

  Stream<List<CastTarget>> discover({
    Duration timeout = const Duration(seconds: 10),
  });

  void stopDiscovery();

  Future<void> cast(CastTarget target, CastMediaRequest media);

  Future<void> disconnect();

  Future<void> dispose();
}
