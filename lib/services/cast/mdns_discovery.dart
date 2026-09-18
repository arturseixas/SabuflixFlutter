import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'cast_device.dart';

/// Finds Google Cast receivers with a hand-rolled mDNS query for
/// `_googlecast._tcp.local`.
///
/// The question is sent with the "unicast response" bit, so devices answer
/// straight back to our ephemeral port; this sidesteps Android's multicast
/// lock and the daemons that already own port 5353 on desktops. A second
/// socket bound to 5353 catches multicast replies where that is possible.
class MdnsDiscovery {
  static final InternetAddress multicastAddress =
      InternetAddress('224.0.0.251');
  static const int multicastPort = 5353;
  static const String service = '_googlecast._tcp.local';

  Stream<CastDevice> discover({Duration timeout = const Duration(seconds: 4)}) {
    final controller = StreamController<CastDevice>();
    unawaited(_run(controller, timeout));
    return controller.stream;
  }

  Future<void> _run(
      StreamController<CastDevice> controller, Duration timeout) async {
    final sockets = <RawDatagramSocket>[];
    final seen = <String>{};
    final records = _RecordStore();

    void handle(RawDatagramSocket socket) {
      final datagram = socket.receive();
      if (datagram == null) return;
      try {
        final message = MdnsMessage.parse(datagram.data);
        records.absorb(message, datagram.address);
        for (final device in records.devices()) {
          if (!controller.isClosed && seen.add(device.id)) {
            controller.add(device);
          }
        }
      } catch (error) {
        debugPrint('Ignoring malformed mDNS packet: $error');
      }
    }

    try {
      final unicast = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      sockets.add(unicast);
      unicast.listen((event) {
        if (event == RawSocketEvent.read) handle(unicast);
      });

      try {
        final multicast = await RawDatagramSocket.bind(
            InternetAddress.anyIPv4, multicastPort,
            reuseAddress: true, reusePort: !Platform.isWindows);
        multicast.joinMulticast(multicastAddress);
        sockets.add(multicast);
        multicast.listen((event) {
          if (event == RawSocketEvent.read) handle(multicast);
        });
      } catch (error) {
        // Another responder owns 5353 — the unicast socket still works.
        debugPrint('mDNS multicast listener unavailable: $error');
      }

      final query = MdnsMessage.buildQuery(service, unicastResponse: true);
      for (var round = 0; round < 3; round++) {
        for (final socket in sockets) {
          try {
            socket.send(query, multicastAddress, multicastPort);
          } catch (error) {
            debugPrint('mDNS send failed: $error');
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
      await Future<void>.delayed(timeout);
    } catch (error) {
      debugPrint('mDNS discovery unavailable: $error');
    } finally {
      for (final socket in sockets) {
        socket.close();
      }
      await controller.close();
    }
  }
}

/// Tracks PTR/SRV/TXT/A records across packets until a Cast device is fully
/// described.
class _RecordStore {
  final Map<String, String> ptrToInstance = {}; // service -> instance name
  final Map<String, ({String target, int port})> srv = {};
  final Map<String, Map<String, String>> txt = {};
  final Map<String, String> a = {}; // host -> ipv4
  final Map<String, String> sourceByInstance = {};

  void absorb(MdnsMessage message, InternetAddress source) {
    for (final record in message.records) {
      final name = record.name.toLowerCase();
      switch (record.type) {
        case MdnsRecord.typePtr:
          if (name == MdnsDiscovery.service) {
            final instance = (record.data as String).toLowerCase();
            ptrToInstance[instance] = instance;
            sourceByInstance[instance] = source.address;
          }
          break;
        case MdnsRecord.typeSrv:
          final data = record.data as ({String target, int port});
          srv[name] = (target: data.target.toLowerCase(), port: data.port);
          sourceByInstance.putIfAbsent(name, () => source.address);
          break;
        case MdnsRecord.typeTxt:
          txt[name] = record.data as Map<String, String>;
          break;
        case MdnsRecord.typeA:
          a[name] = record.data as String;
          break;
      }
    }
  }

  Iterable<CastDevice> devices() {
    final result = <CastDevice>[];
    final instances = <String>{...ptrToInstance.keys, ...srv.keys}
        .where((name) => name.endsWith(MdnsDiscovery.service));
    for (final instance in instances) {
      final service = srv[instance];
      final attributes = txt[instance] ?? const {};
      final host = service != null
          ? (a[service.target] ?? sourceByInstance[instance])
          : sourceByInstance[instance];
      if (host == null || host.isEmpty) continue;
      final id = attributes['id'] ??
          instance.substring(
              0, instance.length - MdnsDiscovery.service.length - 1);
      final friendly = attributes['fn'];
      final model = attributes['md'];
      result.add(CastDevice(
        id: 'cast:$id',
        name: (friendly != null && friendly.trim().isNotEmpty)
            ? friendly.trim()
            : (model ?? 'Chromecast'),
        host: host,
        port: service?.port ?? 8009,
        protocol: CastProtocol.chromecast,
        manufacturer: 'Google Cast',
        model: model,
      ));
    }
    return result;
  }
}

/// A decoded DNS resource record.
class MdnsRecord {
  static const int typeA = 1;
  static const int typePtr = 12;
  static const int typeTxt = 16;
  static const int typeSrv = 33;

  final String name;
  final int type;
  final Object data;

  const MdnsRecord(this.name, this.type, this.data);
}

/// Minimal DNS wire-format codec: enough to ask one PTR question and read the
/// PTR, SRV, TXT and A answers Cast devices send back.
class MdnsMessage {
  final List<MdnsRecord> records;

  const MdnsMessage(this.records);

  static Uint8List buildQuery(String name, {bool unicastResponse = true}) {
    final builder = BytesBuilder();
    builder.add([0, 0]); // transaction id (always 0 for mDNS)
    builder.add([0, 0]); // flags: standard query
    builder.add([0, 1]); // QDCOUNT
    builder.add([0, 0, 0, 0, 0, 0]); // AN, NS, AR
    for (final label in name.split('.')) {
      if (label.isEmpty) continue;
      final bytes = utf8.encode(label);
      builder.addByte(bytes.length);
      builder.add(bytes);
    }
    builder.addByte(0);
    builder.add([0, MdnsRecord.typePtr]);
    // Class IN, with the top bit set when we want a unicast response.
    builder.add(unicastResponse ? [0x80, 0x01] : [0x00, 0x01]);
    return builder.toBytes();
  }

  static MdnsMessage parse(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 12) return const MdnsMessage([]);
    final qdCount = data.getUint16(4);
    final anCount = data.getUint16(6);
    final nsCount = data.getUint16(8);
    final arCount = data.getUint16(10);

    var offset = 12;
    for (var i = 0; i < qdCount; i++) {
      final name = _readName(bytes, offset);
      offset = name.next + 4;
    }

    final records = <MdnsRecord>[];
    final total = anCount + nsCount + arCount;
    for (var i = 0; i < total; i++) {
      if (offset + 10 > bytes.length) break;
      final name = _readName(bytes, offset);
      offset = name.next;
      final type = data.getUint16(offset);
      final length = data.getUint16(offset + 8);
      final rdataStart = offset + 10;
      final rdataEnd = rdataStart + length;
      if (rdataEnd > bytes.length) break;
      switch (type) {
        case MdnsRecord.typePtr:
          records.add(
              MdnsRecord(name.value, type, _readName(bytes, rdataStart).value));
          break;
        case MdnsRecord.typeSrv:
          final port = data.getUint16(rdataStart + 4);
          final target = _readName(bytes, rdataStart + 6).value;
          records
              .add(MdnsRecord(name.value, type, (target: target, port: port)));
          break;
        case MdnsRecord.typeTxt:
          records.add(MdnsRecord(
              name.value, type, _readTxt(bytes, rdataStart, rdataEnd)));
          break;
        case MdnsRecord.typeA:
          if (length == 4) {
            records.add(MdnsRecord(name.value, type,
                bytes.sublist(rdataStart, rdataEnd).join('.')));
          }
          break;
      }
      offset = rdataEnd;
    }
    return MdnsMessage(records);
  }

  static Map<String, String> _readTxt(Uint8List bytes, int start, int end) {
    final result = <String, String>{};
    var offset = start;
    while (offset < end) {
      final length = bytes[offset];
      offset++;
      if (length == 0 || offset + length > end) break;
      final entry = utf8.decode(bytes.sublist(offset, offset + length),
          allowMalformed: true);
      offset += length;
      final equals = entry.indexOf('=');
      if (equals == -1) {
        result[entry.toLowerCase()] = '';
      } else {
        result[entry.substring(0, equals).toLowerCase()] =
            entry.substring(equals + 1);
      }
    }
    return result;
  }

  static ({String value, int next}) _readName(Uint8List bytes, int offset) {
    final labels = <String>[];
    var position = offset;
    var next = -1;
    var hops = 0;
    while (position < bytes.length) {
      final length = bytes[position];
      if (length == 0) {
        position++;
        break;
      }
      if ((length & 0xC0) == 0xC0) {
        if (position + 1 >= bytes.length) break;
        final pointer = ((length & 0x3F) << 8) | bytes[position + 1];
        if (next == -1) next = position + 2;
        position = pointer;
        if (++hops > 32) break; // corrupted pointer loop
        continue;
      }
      position++;
      if (position + length > bytes.length) break;
      labels.add(utf8.decode(bytes.sublist(position, position + length),
          allowMalformed: true));
      position += length;
    }
    return (value: labels.join('.'), next: next == -1 ? position : next);
  }
}
