import '../../models/cast_target.dart';
import 'casting_contract.dart';

CastingService createCastingService() => _UnsupportedCastingService();

class _UnsupportedCastingService implements CastingService {
  @override
  bool get isSupported => false;

  @override
  Stream<List<CastTarget>> discover({
    Duration timeout = const Duration(seconds: 10),
  }) async* {
    yield const <CastTarget>[];
  }

  @override
  void stopDiscovery() {}

  @override
  Future<void> cast(CastTarget target, CastMediaRequest media) {
    throw UnsupportedError(
      'A descoberta de TVs requer o aplicativo nativo.',
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}
}
