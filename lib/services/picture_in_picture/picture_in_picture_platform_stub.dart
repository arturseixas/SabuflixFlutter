import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'picture_in_picture_platform.dart';

PictureInPicturePlatform createPlatformImplementation() =>
    _UnsupportedPictureInPicturePlatform();

class _UnsupportedPictureInPicturePlatform implements PictureInPicturePlatform {
  @override
  bool get isSupported => false;

  @override
  bool get isActive => false;

  @override
  Stream<bool> get states => const Stream<bool>.empty();

  @override
  Future<void> attach(Player player) async {}

  @override
  Future<void> enter() async {}

  @override
  Future<void> exit() async {}

  @override
  Future<void> dispose() async {}
}
