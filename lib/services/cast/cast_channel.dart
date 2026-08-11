import 'dart:convert';
import 'dart:typed_data';

/// One frame of the Google Cast v2 protocol.
///
/// Cast speaks protobuf over TLS on port 8009. The message has six fields and
/// only two wire types, so it is encoded by hand here rather than pulling in a
/// protobuf compiler and a generated-code build step for one struct:
///
/// ```proto
/// message CastMessage {
///   required ProtocolVersion protocol_version = 1;  // varint, always 0
///   required string source_id              = 2;
///   required string destination_id         = 3;
///   required string namespace              = 4;
///   required PayloadType payload_type      = 5;     // varint, 0 = STRING
///   optional string payload_utf8           = 6;
///   optional bytes payload_binary          = 7;      // unused by this app
/// }
/// ```
class CastMessage {
  final String sourceId;
  final String destinationId;
  final String namespace;
  final String payload;

  const CastMessage({
    required this.sourceId,
    required this.destinationId,
    required this.namespace,
    required this.payload,
  });

  /// Decoded JSON body, or an empty map when the payload is not JSON.
  Map<String, dynamic> get json {
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String get type => json['type'] as String? ?? '';

  Uint8List encode() {
    final out = BytesBuilder();
    _writeVarintField(out, 1, 0); // protocol_version: CASTV2_1_0
    _writeStringField(out, 2, sourceId);
    _writeStringField(out, 3, destinationId);
    _writeStringField(out, 4, namespace);
    _writeVarintField(out, 5, 0); // payload_type: STRING
    _writeStringField(out, 6, payload);
    return out.toBytes();
  }

  /// The same bytes with the 4-byte big-endian length prefix each frame
  /// carries on the wire.
  Uint8List encodeFramed() {
    final body = encode();
    final framed = BytesBuilder();
    final header = ByteData(4)..setUint32(0, body.length, Endian.big);
    framed.add(header.buffer.asUint8List());
    framed.add(body);
    return framed.toBytes();
  }

  static CastMessage decode(Uint8List bytes) {
    var offset = 0;
    String sourceId = '';
    String destinationId = '';
    String namespace = '';
    String payload = '';

    (int, int) readVarint(int at) {
      var result = 0;
      var shift = 0;
      var index = at;
      while (index < bytes.length) {
        final byte = bytes[index++];
        result |= (byte & 0x7F) << shift;
        if (byte & 0x80 == 0) break;
        shift += 7;
      }
      return (result, index);
    }

    while (offset < bytes.length) {
      final (tag, afterTag) = readVarint(offset);
      offset = afterTag;
      final field = tag >> 3;
      final wireType = tag & 0x07;

      if (wireType == 0) {
        final (_, afterValue) = readVarint(offset);
        offset = afterValue;
        continue;
      }
      if (wireType != 2) break; // Nothing else appears in a CastMessage.

      final (length, afterLength) = readVarint(offset);
      offset = afterLength;
      final end = (offset + length).clamp(0, bytes.length);
      final value = utf8.decode(bytes.sublist(offset, end), allowMalformed: true);
      offset = end;

      switch (field) {
        case 2:
          sourceId = value;
        case 3:
          destinationId = value;
        case 4:
          namespace = value;
        case 6:
          payload = value;
      }
    }

    return CastMessage(
      sourceId: sourceId,
      destinationId: destinationId,
      namespace: namespace,
      payload: payload,
    );
  }

  static void _writeVarintField(BytesBuilder out, int field, int value) {
    _writeVarint(out, field << 3); // wire type 0
    _writeVarint(out, value);
  }

  static void _writeStringField(BytesBuilder out, int field, String value) {
    final encoded = utf8.encode(value);
    _writeVarint(out, (field << 3) | 2); // wire type 2
    _writeVarint(out, encoded.length);
    out.add(encoded);
  }

  static void _writeVarint(BytesBuilder out, int value) {
    var remaining = value;
    while (true) {
      final byte = remaining & 0x7F;
      remaining >>= 7;
      if (remaining == 0) {
        out.addByte(byte);
        return;
      }
      out.addByte(byte | 0x80);
    }
  }
}

/// Splits the TLS byte stream back into frames.
///
/// A read from the socket can hold half a frame, three frames, or a frame plus
/// the first two bytes of the next one, so the bytes are buffered until a whole
/// message is present.
class CastFrameReader {
  final BytesBuilder _buffer = BytesBuilder();

  List<CastMessage> add(List<int> chunk) {
    _buffer.add(chunk);
    final messages = <CastMessage>[];

    var bytes = _buffer.toBytes();
    var consumed = 0;

    while (bytes.length - consumed >= 4) {
      final view = ByteData.sublistView(bytes, consumed, consumed + 4);
      final length = view.getUint32(0, Endian.big);
      if (bytes.length - consumed - 4 < length) break;

      final start = consumed + 4;
      messages.add(CastMessage.decode(bytes.sublist(start, start + length)));
      consumed = start + length;
    }

    _buffer.clear();
    if (consumed < bytes.length) {
      _buffer.add(bytes.sublist(consumed));
    }

    return messages;
  }
}
