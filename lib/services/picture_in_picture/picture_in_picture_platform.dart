import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'picture_in_picture_platform_stub.dart'
    if (dart.library.js_interop) 'picture_in_picture_platform_web.dart';

abstract class PictureInPicturePlatform {
  bool get isSupported;
  bool get isActive;
  Stream<bool> get states;

  Future<void> attach(Player player);
  Future<void> enter();
  Future<void> exit();
  Future<void> dispose();
}

PictureInPicturePlatform createPictureInPicturePlatform() =>
    createPlatformImplementation();
