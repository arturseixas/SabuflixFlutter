import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/services/cast/chromecast_client.dart';
import 'package:sabuflix/services/cast/local_media_server.dart';

void main() {
  group('Google Cast framing', () {
    /// Strips the 4-byte big-endian length prefix the receiver expects.
    Uint8List body(Uint8List frame) {
      final length = ByteData.sublistView(frame, 0, 4).getUint32(0);
      expect(frame.length, 4 + length);
      return Uint8List.fromList(frame.sublist(4));
    }

    test('encodes a frame the decoder reads back', () {
      final payload = json.encode({'type': 'LAUNCH', 'requestId': 7});
      final frame = ChromecastClient.encodeFrame(
        namespace: 'urn:x-cast:com.google.cast.receiver',
        destination: 'receiver-0',
        payload: payload,
      );

      final decoded = ChromecastClient.decodeFrame(body(frame));
      expect(decoded.namespace, 'urn:x-cast:com.google.cast.receiver');
      expect(decoded.payload, payload);
      expect(decoded.sourceId, isNotNull);
    });

    test('writes the protobuf fields receivers require', () {
      final frame = body(ChromecastClient.encodeFrame(
        namespace: 'ns',
        destination: 'receiver-0',
        payload: '{}',
      ));

      // protocol_version = 0 (field 1, varint) then payload_type = STRING.
      expect(frame[0], 0x08);
      expect(frame[1], 0x00);
      expect(frame.contains(0x28), isTrue);
    });

    test('survives payloads long enough to need a multi-byte varint', () {
      final payload = json.encode({'title': 'x' * 500});
      final frame = ChromecastClient.encodeFrame(
        namespace: 'urn:x-cast:com.google.cast.media',
        destination: 'transport-1',
        payload: payload,
      );

      expect(ChromecastClient.decodeFrame(body(frame)).payload, payload);
    });
  });

  group('LocalMediaServer range parsing', () {
    test('ignores a missing or malformed header', () {
      expect(LocalMediaServer.parseRange(null, 1000), isNull);
      expect(LocalMediaServer.parseRange('items=0-10', 1000), isNull);
    });

    test('reads a closed range', () {
      expect(LocalMediaServer.parseRange('bytes=100-199', 1000), (100, 199));
    });

    test('reads an open-ended range', () {
      expect(LocalMediaServer.parseRange('bytes=100-', 1000), (100, 999));
    });

    test('reads a suffix range', () {
      expect(LocalMediaServer.parseRange('bytes=-200', 1000), (800, 999));
    });

    test('clamps an end past the file and rejects a start past it', () {
      expect(LocalMediaServer.parseRange('bytes=900-5000', 1000), (900, 999));
      expect(LocalMediaServer.parseRange('bytes=2000-', 1000), isNull);
    });
  });
}
