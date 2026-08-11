import 'dart:convert';
import 'dart:typed_data';

/// Wire-level codec for CASTV2 `CastMessage` frames.
///
/// The Google Cast channel protocol frames each message as a 4-byte
/// big-endian length prefix followed by a protobuf-encoded `CastMessage`
/// (see cast_channel.proto). That message only ever has four fields we
/// care about — source/destination ids, a namespace, and a UTF-8 JSON
/// payload — so this hand-rolls the varint/length-delimited encoding
/// directly instead of pulling in the `protobuf` package and its
/// generator for four fields.
class CastMessageCodec {
  static const _fieldProtocolVersion = 1;
  static const _fieldSourceId = 2;
  static const _fieldDestinationId = 3;
  static const _fieldNamespace = 4;
  static const _fieldPayloadType = 5;
  static const _fieldPayloadUtf8 = 6;

  /// Encodes one message, including the 4-byte length prefix used to frame
  /// messages on the raw TCP stream.
  static Uint8List encodeFrame({
    required String sourceId,
    required String destinationId,
    required String namespace,
    required String payloadUtf8,
  }) {
    final body = BytesBuilder();
    _writeVarintField(body, _fieldProtocolVersion, 0); // CASTV2_1_0
    _writeStringField(body, _fieldSourceId, sourceId);
    _writeStringField(body, _fieldDestinationId, destinationId);
    _writeStringField(body, _fieldNamespace, namespace);
    _writeVarintField(body, _fieldPayloadType, 0); // PayloadType.STRING
    _writeStringField(body, _fieldPayloadUtf8, payloadUtf8);
    final bodyBytes = body.toBytes();

    final frame = BytesBuilder();
    frame.add([
      (bodyBytes.length >> 24) & 0xFF,
      (bodyBytes.length >> 16) & 0xFF,
      (bodyBytes.length >> 8) & 0xFF,
      bodyBytes.length & 0xFF,
    ]);
    frame.add(bodyBytes);
    return frame.toBytes();
  }

  /// Decodes a single already-length-delimited `CastMessage` body (the
  /// frame prefix must already be stripped off by the caller).
  static CastWireMessage decodeBody(Uint8List body) {
    String namespace = '';
    String sourceId = '';
    String destinationId = '';
    String? payload;

    var offset = 0;
    while (offset < body.length) {
      final tag = _readVarint(body, offset);
      offset = tag.newOffset;
      final fieldNumber = tag.value >> 3;
      final wireType = tag.value & 0x7;

      if (wireType == 0) {
        final v = _readVarint(body, offset);
        offset = v.newOffset;
      } else if (wireType == 2) {
        final len = _readVarint(body, offset);
        offset = len.newOffset;
        final bytes = body.sublist(offset, offset + len.value);
        offset += len.value;
        switch (fieldNumber) {
          case _fieldSourceId:
            sourceId = utf8.decode(bytes);
            break;
          case _fieldDestinationId:
            destinationId = utf8.decode(bytes);
            break;
          case _fieldNamespace:
            namespace = utf8.decode(bytes);
            break;
          case _fieldPayloadUtf8:
            payload = utf8.decode(bytes);
            break;
        }
      } else {
        throw FormatException('Unsupported CastMessage wire type $wireType');
      }
    }

    return CastWireMessage(
      namespace: namespace,
      sourceId: sourceId,
      destinationId: destinationId,
      payloadUtf8: payload,
    );
  }

  static void _writeVarint(BytesBuilder out, int value) {
    var v = value;
    while (true) {
      if (v & ~0x7F == 0) {
        out.addByte(v);
        return;
      }
      out.addByte((v & 0x7F) | 0x80);
      v >>= 7;
    }
  }

  static void _writeVarintField(BytesBuilder out, int fieldNumber, int value) {
    out.addByte((fieldNumber << 3) | 0);
    _writeVarint(out, value);
  }

  static void _writeStringField(BytesBuilder out, int fieldNumber, String value) {
    final bytes = utf8.encode(value);
    out.addByte((fieldNumber << 3) | 2);
    _writeVarint(out, bytes.length);
    out.add(bytes);
  }

  static _VarintResult _readVarint(Uint8List data, int offset) {
    var result = 0;
    var shift = 0;
    var pos = offset;
    while (true) {
      final b = data[pos];
      result |= (b & 0x7F) << shift;
      pos++;
      if (b & 0x80 == 0) break;
      shift += 7;
    }
    return _VarintResult(result, pos);
  }
}

class _VarintResult {
  final int value;
  final int newOffset;
  _VarintResult(this.value, this.newOffset);
}

class CastWireMessage {
  final String namespace;
  final String sourceId;
  final String destinationId;
  final String? payloadUtf8;

  CastWireMessage({
    required this.namespace,
    required this.sourceId,
    required this.destinationId,
    this.payloadUtf8,
  });
}
