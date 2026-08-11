import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/cast_device.dart';
import 'chromecast_client.dart';
import 'dlna_client.dart';

export 'chromecast_client.dart' show CastException;

/// Finds televisions on the local network, whichever protocol they speak.
///
/// Two searches run at once because the ecosystems do not overlap: Chromecast
/// and Google TV announce themselves over mDNS, while Samsung, LG and the rest
/// answer an SSDP search. Between them they cover practically every television
/// on sale, and neither needs anything installed on the TV.
class CastService {
  CastService._();

  /// Casting needs raw UDP and TLS sockets, which the browser does not give a
  /// web build.
  static bool get isSupported => !kIsWeb;

  /// A single device list, fed by both discoveries, de-duplicated.
  static Stream<CastDevice> discover({
    Duration timeout = const Duration(seconds: 6),
  }) {
    if (!isSupported) return const Stream<CastDevice>.empty();

    final controller = StreamController<CastDevice>();
    final seen = <String>{};
    var openSearches = 2;

    void forward(Stream<CastDevice> source) {
      source.listen(
        (device) {
          if (seen.add(device.id) && !controller.isClosed) controller.add(device);
        },
        onError: (Object error) => debugPrint('Cast: discovery error: $error'),
        onDone: () {
          openSearches--;
          if (openSearches <= 0 && !controller.isClosed) controller.close();
        },
        cancelOnError: false,
      );
    }

    controller.onListen = () {
      forward(ChromecastClient.discover(timeout: timeout));
      forward(DlnaClient.discover(timeout: timeout));
    };

    return controller.stream;
  }

  static CastSession sessionFor(CastDevice device) {
    switch (device.protocol) {
      case CastProtocol.googleCast:
        return ChromecastSession(device);
      case CastProtocol.dlna:
        return DlnaSession(device);
    }
  }
}
