import 'dart:convert';
import 'dart:typed_data';

/// One frame of the Google Cast v2 channel.
///
/// Mirrors the `CastMessage` protobuf used by the Cast SDK. The message has
/// so few fields that hand-encoding beats pulling in a protobuf runtime.
class CastChannelMessage {
  static const String platformSender = 'sender-0';
  static const String platformReceiver = 'receiver-0';

  static const String connectionNamespace =
      'urn:x-cast:com.google.cast.tp.connection';
  static const String heartbeatNamespace =
      'urn:x-cast:com.google.cast.tp.heartbeat';
  static const String receiverNamespace = 'urn:x-cast:com.google.cast.receiver';
  static const String mediaNamespace = 'urn:x-cast:com.google.cast.media';

  final String sourceId;
  final String destinationId;
  final String namespace;
  final String payload;

  const CastChannelMessage({
    required this.sourceId,
    required this.destinationId,
    required this.namespace,
    required this.payload,
  });

  Map<String, dynamic>? get json {
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  /// Length-prefixed frame ready to write on the TLS socket.
  Uint8List toFrame() {
    final body = encode();
    final frame = ByteData(4 + body.length);
    frame.setUint32(0, body.length);
    final bytes = frame.buffer.asUint8List();
    bytes.setRange(4, bytes.length, body);
    return bytes;
  }

  /// Protobuf body (without the length prefix).
  Uint8List encode() {
    final out = BytesBuilder();
    _writeVarint(out, (1 << 3) | 0); // protocol_version
    _writeVarint(out, 0); // CASTV2_1_0
    _writeString(out, 2, sourceId);
    _writeString(out, 3, destinationId);
    _writeString(out, 4, namespace);
    _writeVarint(out, (5 << 3) | 0); // payload_type
    _writeVarint(out, 0); // STRING
    _writeString(out, 6, payload);
    return out.toBytes();
  }

  static CastChannelMessage decode(Uint8List bytes) {
    var offset = 0;
    var sourceId = '';
    var destinationId = '';
    var namespace = '';
    var payload = '';
    while (offset < bytes.length) {
      final tag = _readVarint(bytes, offset);
      offset = tag.next;
      final field = tag.value >> 3;
      final wireType = tag.value & 0x7;
      switch (wireType) {
        case 0:
          offset = _readVarint(bytes, offset).next;
          break;
        case 2:
          final length = _readVarint(bytes, offset);
          offset = length.next;
          final end = offset + length.value;
          if (end > bytes.length) {
            throw const FormatException('Truncated Cast message');
          }
          final text =
              utf8.decode(bytes.sublist(offset, end), allowMalformed: true);
          switch (field) {
            case 2:
              sourceId = text;
              break;
            case 3:
              destinationId = text;
              break;
            case 4:
              namespace = text;
              break;
            case 6:
              payload = text;
              break;
            case 7:
              // Binary payloads are not used by the media receiver.
              break;
          }
          offset = end;
          break;
        case 1:
          offset += 8;
          break;
        case 5:
          offset += 4;
          break;
        default:
          throw FormatException('Unsupported protobuf wire type $wireType');
      }
    }
    return CastChannelMessage(
      sourceId: sourceId,
      destinationId: destinationId,
      namespace: namespace,
      payload: payload,
    );
  }

  static void _writeString(BytesBuilder out, int field, String value) {
    final bytes = utf8.encode(value);
    _writeVarint(out, (field << 3) | 2);
    _writeVarint(out, bytes.length);
    out.add(bytes);
  }

  static void _writeVarint(BytesBuilder out, int value) {
    var remaining = value;
    while (remaining >= 0x80) {
      out.addByte((remaining & 0x7F) | 0x80);
      remaining >>= 7;
    }
    out.addByte(remaining);
  }

  static ({int value, int next}) _readVarint(Uint8List bytes, int offset) {
    var result = 0;
    var shift = 0;
    var position = offset;
    while (position < bytes.length) {
      final byte = bytes[position++];
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) return (value: result, next: position);
      shift += 7;
      if (shift > 63) break;
    }
    throw const FormatException('Malformed varint');
  }
}

/// Splits a TCP byte stream into complete Cast frames.
class CastFrameReader {
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  List<CastChannelMessage> add(List<int> chunk) {
    _buffer.add(chunk);
    final messages = <CastChannelMessage>[];
    var bytes = _buffer.toBytes();
    var consumed = 0;
    while (bytes.length - consumed >= 4) {
      final length =
          ByteData.sublistView(bytes, consumed, consumed + 4).getUint32(0);
      if (bytes.length - consumed - 4 < length) break;
      final start = consumed + 4;
      messages
          .add(CastChannelMessage.decode(bytes.sublist(start, start + length)));
      consumed = start + length;
    }
    if (consumed > 0) {
      final rest = bytes.sublist(consumed);
      _buffer.clear();
      _buffer.add(rest);
    }
    return messages;
  }
}
