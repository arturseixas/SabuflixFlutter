import 'casting_contract.dart';
import 'casting_service_stub.dart'
    if (dart.library.io) 'casting_service_io.dart' as platform;

export 'casting_contract.dart';
export '../../models/cast_target.dart';

CastingService createCastingService() => platform.createCastingService();
