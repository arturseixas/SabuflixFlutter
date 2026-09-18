import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabuflix/services/cast/cast_channel_codec.dart';
import 'package:sabuflix/services/cast/cast_device.dart';
import 'package:sabuflix/services/cast/cast_manager.dart';
import 'package:sabuflix/services/cast/dlna_renderer.dart';
import 'package:sabuflix/services/cast/mdns_discovery.dart';
import 'package:sabuflix/services/cast/ssdp_discovery.dart';

void main() {
  group('Cast channel codec', () {
    test('encodes and decodes a CastMessage round trip', () {
      const message = CastChannelMessage(
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: CastChannelMessage.receiverNamespace,
        payload: '{"type":"LAUNCH","appId":"CC1AD845","requestId":1}',
      );
      final decoded = CastChannelMessage.decode(message.encode());
      expect(decoded.sourceId, 'sender-0');
      expect(decoded.destinationId, 'receiver-0');
      expect(decoded.namespace, CastChannelMessage.receiverNamespace);
      expect(decoded.json?['appId'], 'CC1AD845');
    });

    test('frames carry a big-endian length prefix and reassemble from chunks',
        () {
      const first = CastChannelMessage(
          sourceId: 'a',
          destinationId: 'b',
          namespace: 'n',
          payload: '{"type":"PING"}');
      const second = CastChannelMessage(
          sourceId: 'c',
          destinationId: 'd',
          namespace: 'm',
          payload: '{"type":"PONG","requestId":7}');
      final bytes =
          Uint8List.fromList([...first.toFrame(), ...second.toFrame()]);
      final length = ByteData.sublistView(bytes, 0, 4).getUint32(0);
      expect(length, first.encode().length);

      final reader = CastFrameReader();
      final part1 = reader.add(bytes.sublist(0, 9));
      expect(part1, isEmpty);
      final part2 = reader.add(bytes.sublist(9, bytes.length - 3));
      expect(part2.map((m) => m.json?['type']), ['PING']);
      final part3 = reader.add(bytes.sublist(bytes.length - 3));
      expect(part3.single.json?['requestId'], 7);
    });

    test('payloads longer than 127 bytes use multi-byte varints', () {
      final payload = jsonEncode({
        'type': 'LOAD',
        'media': {'contentId': 'x' * 300}
      });
      final message = CastChannelMessage(
          sourceId: 's', destinationId: 'd', namespace: 'n', payload: payload);
      expect(CastChannelMessage.decode(message.encode()).payload, payload);
    });
  });

  group('SSDP', () {
    test('M-SEARCH is a valid HTTPU request', () {
      final message = SsdpDiscovery.buildSearchMessage(
          'urn:schemas-upnp-org:device:MediaRenderer:1');
      expect(message, startsWith('M-SEARCH * HTTP/1.1\r\n'));
      expect(message, contains('MAN: "ssdp:discover"\r\n'));
      expect(message, endsWith('\r\n\r\n'));
    });

    test('parses LOCATION from a reply and ignores NOTIFY chatter', () {
      expect(
          SsdpDiscovery.parseLocation(
              'HTTP/1.1 200 OK\r\nCACHE-CONTROL: max-age=1800\r\n'
              'Location: http://192.168.0.10:9197/dmr\r\nST: upnp:rootdevice\r\n\r\n'),
          'http://192.168.0.10:9197/dmr');
      expect(
          SsdpDiscovery.parseLocation(
              'NOTIFY * HTTP/1.1\r\nLOCATION: http://192.168.0.10/desc.xml\r\n\r\n'),
          isNull);
      expect(
          SsdpDiscovery.parseLocation(
              'HTTP/1.1 200 OK\r\nLOCATION: nope\r\n\r\n'),
          isNull);
    });

    test('device description yields a DLNA renderer with resolved control URLs',
        () {
      const xml = '''<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
<device>
<deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
<friendlyName>[TV] Sala &amp; Cinema</friendlyName>
<manufacturer>Samsung Electronics</manufacturer>
<modelName>UE55</modelName>
<UDN>uuid:abc-123</UDN>
<serviceList>
<service>
<serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
<controlURL>/upnp/control/RenderingControl1</controlURL>
</service>
<service>
<serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
<controlURL>/upnp/control/AVTransport1</controlURL>
</service>
</serviceList>
</device>
</root>''';
      final device = SsdpDiscovery.parseDescription(
          xml, Uri.parse('http://192.168.0.10:9197/dmr'))!;
      expect(device.id, 'dlna:uuid:abc-123');
      expect(device.name, '[TV] Sala & Cinema');
      expect(device.manufacturer, 'Samsung Electronics');
      expect(device.protocol, CastProtocol.dlna);
      expect(device.avTransportUrl.toString(),
          'http://192.168.0.10:9197/upnp/control/AVTransport1');
      expect(device.renderingControlUrl.toString(),
          'http://192.168.0.10:9197/upnp/control/RenderingControl1');
      expect(device.detailLabel, 'Samsung Electronics UE55 · DLNA / Smart TV');
    });

    test('devices without AVTransport are not offered as targets', () {
      const xml =
          '<root><device><friendlyName>Router</friendlyName><UDN>uuid:r</UDN>'
          '<serviceList><service><serviceType>urn:schemas-upnp-org:service:WANIPConnection:1</serviceType>'
          '<controlURL>/ctl</controlURL></service></serviceList></device></root>';
      expect(
          SsdpDiscovery.parseDescription(
              xml, Uri.parse('http://10.0.0.1/desc')),
          isNull);
    });

    test('device JSON survives a round trip through preferences', () {
      final device = CastDevice(
        id: 'dlna:uuid:x',
        name: 'Quarto',
        host: '10.0.0.5',
        port: 9197,
        protocol: CastProtocol.dlna,
        avTransportUrl: Uri.parse('http://10.0.0.5:9197/av'),
        manual: true,
      );
      final restored = CastDevice.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(device.toJson()))));
      expect(restored, device);
      expect(restored.avTransportUrl, device.avTransportUrl);
      expect(restored.manual, isTrue);
    });
  });

  group('DLNA renderer', () {
    test('SOAP envelope escapes arguments and targets InstanceID 0', () {
      final body = DlnaRenderer.buildEnvelope(
          DlnaRenderer.avTransport, 'SetAVTransportURI', {
        'CurrentURI': 'http://h/v.mp4?a=1&b=2',
        'CurrentURIMetaData': '<x/>',
      });
      expect(
          body,
          contains(
              '<u:SetAVTransportURI xmlns:u="${DlnaRenderer.avTransport}">'));
      expect(body, contains('<InstanceID>0</InstanceID>'));
      expect(body, contains('http://h/v.mp4?a=1&amp;b=2'));
      expect(body, contains('&lt;x/&gt;'));
    });

    test('metadata describes the title and picks a MIME type from the URL', () {
      final metadata = DlnaRenderer.buildMetadata(const CastMediaRequest(
          url: 'https://cdn.example/movie.mkv',
          title: 'Filme',
          subtitle: 'T1 E2',
          imageUrl: 'https://img/x.jpg'));
      expect(metadata, contains('<dc:title>Filme · T1 E2</dc:title>'));
      expect(metadata, contains('video/x-matroska'));
      expect(metadata,
          contains('<upnp:albumArtURI>https://img/x.jpg</upnp:albumArtURI>'));
      expect(CastMediaRequest.contentTypeFor('https://a/b.m3u8'),
          'application/x-mpegURL');
      expect(CastMediaRequest.contentTypeFor('https://a/b'), 'video/mp4');
    });

    test('formats and parses AVTransport time stamps', () {
      expect(
          DlnaRenderer.formatTime(
              const Duration(hours: 1, minutes: 2, seconds: 3)),
          '1:02:03');
      expect(DlnaRenderer.parseTime('01:02:03.500'),
          const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 500));
      expect(DlnaRenderer.parseTime('NOT_IMPLEMENTED'), isNull);
    });

    test('load sets the URI, plays and reports status from SOAP replies',
        () async {
      final actions = <String>[];
      final client = MockClient((request) async {
        final action =
            request.headers['SOAPACTION'] ?? request.headers['soapaction'];
        actions.add(action ?? '');
        if (action!.contains('GetTransportInfo')) {
          return http.Response(
              '<s:Envelope><s:Body><u:GetTransportInfoResponse>'
              '<CurrentTransportState>PLAYING</CurrentTransportState>'
              '</u:GetTransportInfoResponse></s:Body></s:Envelope>',
              200);
        }
        if (action.contains('GetPositionInfo')) {
          return http.Response(
              '<s:Envelope><s:Body><u:GetPositionInfoResponse>'
              '<TrackDuration>0:10:00</TrackDuration><RelTime>0:00:42</RelTime>'
              '</u:GetPositionInfoResponse></s:Body></s:Envelope>',
              200);
        }
        if (action.contains('GetVolume')) {
          return http.Response(
              '<s:Envelope><s:Body><u:GetVolumeResponse><CurrentVolume>35</CurrentVolume>'
              '</u:GetVolumeResponse></s:Body></s:Envelope>',
              200);
        }
        return http.Response('<s:Envelope><s:Body/></s:Envelope>', 200);
      });
      final renderer = DlnaRenderer(
          CastDevice(
            id: 'dlna:t',
            name: 'TV',
            host: '10.0.0.2',
            port: 9197,
            protocol: CastProtocol.dlna,
            avTransportUrl: Uri.parse('http://10.0.0.2:9197/av'),
            renderingControlUrl: Uri.parse('http://10.0.0.2:9197/rc'),
          ),
          client: client);
      await renderer
          .load(const CastMediaRequest(url: 'http://h/v.mp4', title: 'T'));
      expect(actions.map((a) => a.split('#').last.replaceAll('"', '')),
          ['SetAVTransportURI', 'Play']);
      final status = await renderer.status(const CastPlaybackStatus());
      expect(status.state, CastPlayerState.playing);
      expect(status.position, const Duration(seconds: 42));
      expect(status.duration, const Duration(minutes: 10));
      expect(status.volume, closeTo(0.35, 0.001));
    });

    test('UPnP errors surface as CastException', () async {
      final client = MockClient((_) async => http.Response(
          '<s:Envelope><s:Body><s:Fault><detail><UPnPError>'
          '<errorCode>701</errorCode><errorDescription>Transition not available</errorDescription>'
          '</UPnPError></detail></s:Fault></s:Body></s:Envelope>',
          500));
      final renderer = DlnaRenderer(
          CastDevice(
            id: 'dlna:t',
            name: 'TV',
            host: '10.0.0.2',
            port: 9197,
            protocol: CastProtocol.dlna,
            avTransportUrl: Uri.parse('http://10.0.0.2:9197/av'),
          ),
          client: client);
      await expectLater(renderer.pause(), throwsA(isA<CastException>()));
    });
  });

  group('mDNS', () {
    test('query asks for the Cast PTR with the unicast-response bit', () {
      final query = MdnsMessage.buildQuery(MdnsDiscovery.service);
      expect(query.sublist(0, 12), [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]);
      expect(query.sublist(query.length - 4), [0, 12, 0x80, 0x01]);
      final labels = utf8.decode(query.sublist(12, query.length - 5),
          allowMalformed: true);
      expect(labels, contains('_googlecast'));
    });

    test('parses PTR, SRV, TXT and A records with name compression', () {
      final packet = _castResponsePacket();
      final message = MdnsMessage.parse(packet);
      final byType = {for (final r in message.records) r.type: r};
      expect(
          byType[MdnsRecord.typePtr]!.data, 'Sala-abc._googlecast._tcp.local');
      final srv =
          byType[MdnsRecord.typeSrv]!.data as ({String target, int port});
      expect(srv.port, 8009);
      expect(srv.target, 'abc.local');
      expect((byType[MdnsRecord.typeTxt]!.data as Map)['fn'], 'TV da Sala');
      expect(byType[MdnsRecord.typeA]!.data, '192.168.0.20');
    });
  });

  group('Manual probe', () {
    test('finds a DLNA renderer by IP through its description document',
        () async {
      final client = MockClient((request) async {
        if (request.url.port == 9197) {
          return http.Response(
              '<root><device><friendlyName>Manual TV</friendlyName><UDN>uuid:m</UDN>'
              '<serviceList><service><serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>'
              '<controlURL>/av</controlURL></service></serviceList></device></root>',
              200);
        }
        return http.Response('', 404);
      });
      final device = await CastDiscovery.probe('192.168.0.77', client: client);
      expect(device, isNotNull);
      expect(device!.name, 'Manual TV');
      expect(device.manual, isTrue);
      expect(device.avTransportUrl.toString(), 'http://192.168.0.77:9197/av');
    });
  });
}

/// Hand-built mDNS answer the way a Chromecast replies: PTR, then SRV, TXT and
/// A in the additional section, using compression pointers for the names.
Uint8List _castResponsePacket() {
  final out = BytesBuilder();
  void u16(int v) => out.add([(v >> 8) & 0xFF, v & 0xFF]);
  void name(List<String> labels) {
    for (final label in labels) {
      out.addByte(label.length);
      out.add(utf8.encode(label));
    }
    out.addByte(0);
  }

  u16(0); // id
  u16(0x8400); // response, authoritative
  u16(0); // qd
  u16(1); // an
  u16(0); // ns
  u16(3); // ar

  // Answer: PTR _googlecast._tcp.local -> Sala-abc._googlecast._tcp.local
  final serviceOffset = out.length;
  name(['_googlecast', '_tcp', 'local']);
  u16(12);
  u16(0x8001);
  out.add([0, 0, 0, 120]);
  final instanceLabel = utf8.encode('Sala-abc');
  u16(1 + instanceLabel.length + 2); // rdlength: label + pointer
  final instanceOffset = out.length;
  out.addByte(instanceLabel.length);
  out.add(instanceLabel);
  out.add([0xC0 | (serviceOffset >> 8), serviceOffset & 0xFF]);

  // SRV for the instance (pointer to instance name)
  out.add([0xC0 | (instanceOffset >> 8), instanceOffset & 0xFF]);
  u16(33);
  u16(0x8001);
  out.add([0, 0, 0, 120]);
  final target = ['abc', 'local'];
  final targetBytes = target.fold<int>(0, (n, l) => n + 1 + l.length) + 1;
  u16(6 + targetBytes);
  u16(0);
  u16(0);
  u16(8009);
  final targetOffset = out.length;
  name(target);

  // TXT
  out.add([0xC0 | (instanceOffset >> 8), instanceOffset & 0xFF]);
  u16(16);
  u16(0x8001);
  out.add([0, 0, 0, 120]);
  final txt = ['id=abc', 'fn=TV da Sala', 'md=Chromecast'];
  final txtLength = txt.fold<int>(0, (n, e) => n + 1 + utf8.encode(e).length);
  u16(txtLength);
  for (final entry in txt) {
    final bytes = utf8.encode(entry);
    out.addByte(bytes.length);
    out.add(bytes);
  }

  // A record for abc.local
  out.add([0xC0 | (targetOffset >> 8), targetOffset & 0xFF]);
  u16(1);
  u16(0x8001);
  out.add([0, 0, 0, 120]);
  u16(4);
  out.add([192, 168, 0, 20]);
  return out.toBytes();
}
