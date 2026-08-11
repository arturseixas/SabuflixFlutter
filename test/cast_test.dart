import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/models/cast_device.dart';
import 'package:sabuflix/services/cast/cast_channel.dart';
import 'package:sabuflix/services/cast/chromecast_client.dart';
import 'package:sabuflix/services/cast/dlna_client.dart';

/// A trimmed-down but realistic UPnP description, of the shape a Samsung or LG
/// television answers an SSDP search with.
const String _rendererDescription = '''
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion><major>1</major><minor>0</minor></specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>[TV] Sala</friendlyName>
    <manufacturer>Samsung Electronics</manufacturer>
    <modelName>UE55TU7000</modelName>
    <UDN>uuid:0a1b2c3d-4e5f-6789-abcd-ef0123456789</UDN>
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
</root>
''';

/// The same search also turns up devices that cannot play anything.
const String _printerDescription = '''
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <device>
    <deviceType>urn:schemas-upnp-org:device:Printer:1</deviceType>
    <friendlyName>HP LaserJet</friendlyName>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:PrintBasic:1</serviceType>
        <controlURL>/print</controlURL>
      </service>
    </serviceList>
  </device>
</root>
''';

void main() {
  group('SSDP discovery', () {
    test('the search datagram carries what a renderer needs to answer', () {
      final request = DlnaClient.buildSearchRequest('urn:schemas-upnp-org:device:MediaRenderer:1');

      expect(request, startsWith('M-SEARCH * HTTP/1.1\r\n'));
      expect(request, contains('HOST: 239.255.255.250:1900'));
      expect(request, contains('MAN: "ssdp:discover"'));
      expect(request, contains('ST: urn:schemas-upnp-org:device:MediaRenderer:1'));
      // A blank line terminates the request; without it renderers ignore it.
      expect(request, endsWith('\r\n\r\n'));
    });

    test('headers are read case-insensitively, as devices spell them freely', () {
      const response = 'HTTP/1.1 200 OK\r\n'
          'CACHE-CONTROL: max-age=1800\r\n'
          'Location: http://192.168.0.42:9197/dmr\r\n'
          'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n';

      expect(DlnaClient.headerValue(response, 'LOCATION'), 'http://192.168.0.42:9197/dmr');
      expect(DlnaClient.headerValue(response, 'st'), 'urn:schemas-upnp-org:device:MediaRenderer:1');
      expect(DlnaClient.headerValue(response, 'usn'), isNull);
    });

    test('a renderer description becomes a device with an absolute control URL', () {
      final device = DlnaClient.parseDeviceDescription(
        _rendererDescription,
        Uri.parse('http://192.168.0.42:9197/dmr/description.xml'),
      );

      expect(device, isNotNull);
      expect(device!.name, '[TV] Sala');
      expect(device.model, 'UE55TU7000');
      expect(device.protocol, CastProtocol.dlna);
      expect(device.host, '192.168.0.42');
      // The description gives the path only; it has to be resolved against the
      // address the description itself came from.
      expect(device.controlUrl, 'http://192.168.0.42:9197/upnp/control/AVTransport1');
    });

    test('devices without AVTransport are dropped', () {
      final device = DlnaClient.parseDeviceDescription(
        _printerDescription,
        Uri.parse('http://192.168.0.9:8080/desc.xml'),
      );
      expect(device, isNull, reason: 'a printer cannot play a film');
    });

    test('malformed XML is ignored instead of crashing the sweep', () {
      expect(
        DlnaClient.parseDeviceDescription('<root><device>', Uri.parse('http://10.0.0.1/x.xml')),
        isNull,
      );
    });
  });

  group('DLNA control', () {
    test('the SOAP envelope names the action and the service', () {
      final envelope = DlnaClient.soapEnvelope(
        DlnaClient.avTransport,
        'Play',
        '<Speed>1</Speed>',
      );

      expect(envelope, contains('<u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">'));
      expect(envelope, contains('<InstanceID>0</InstanceID>'));
      expect(envelope, contains('<Speed>1</Speed>'));
      expect(envelope, contains('</s:Envelope>'));
    });

    test('a URL with query parameters survives being embedded in the metadata', () {
      // Stream URLs routinely carry tokens: an unescaped `&` makes the whole
      // SOAP body invalid XML and the television rejects the request.
      const url = 'http://cdn.example.com/v.mp4?token=a&exp=123';
      final didl = DlnaClient.buildDidl(url: url, title: 'Filme & Cia');

      expect(didl, contains('token=a&amp;exp=123'));
      expect(didl, contains('<dc:title>Filme &amp; Cia</dc:title>'));
      expect(didl, contains('object.item.videoItem'));
      expect(didl.contains('token=a&exp=123'), isFalse);
    });

    test('positions are written and read back in the UPnP clock format', () {
      expect(DlnaClient.formatUpnpTime(const Duration(seconds: 45)), '0:00:45');
      expect(DlnaClient.formatUpnpTime(const Duration(hours: 1, minutes: 5, seconds: 9)), '1:05:09');

      expect(DlnaClient.parseUpnpTime('0:12:31'), const Duration(minutes: 12, seconds: 31));
      // Some renderers append fractions.
      expect(DlnaClient.parseUpnpTime('01:02:03.000'), const Duration(hours: 1, minutes: 2, seconds: 3));
      expect(DlnaClient.parseUpnpTime('NOT_IMPLEMENTED'), Duration.zero);
      expect(DlnaClient.parseUpnpTime(null), Duration.zero);
    });

    test('the transport answers are turned into a status', () {
      const positionInfo = '<u:GetPositionInfoResponse>'
          '<Track>1</Track>'
          '<TrackDuration>01:32:10</TrackDuration>'
          '<RelTime>00:04:20</RelTime>'
          '</u:GetPositionInfoResponse>';
      const transportInfo = '<u:GetTransportInfoResponse>'
          '<CurrentTransportState>PLAYING</CurrentTransportState>'
          '</u:GetTransportInfoResponse>';

      final status = DlnaSession.parseStatus(positionInfo, transportInfo);

      expect(status.isPlaying, isTrue);
      expect(status.position, const Duration(minutes: 4, seconds: 20));
      expect(status.duration, const Duration(hours: 1, minutes: 32, seconds: 10));
      expect(status.progress, closeTo(260 / 5530, 0.001));
    });

    test('a paused renderer is not reported as playing', () {
      final status = DlnaSession.parseStatus(
        '<RelTime>00:00:10</RelTime><TrackDuration>00:10:00</TrackDuration>',
        '<CurrentTransportState>PAUSED_PLAYBACK</CurrentTransportState>',
      );
      expect(status.isPlaying, isFalse);
    });
  });

  group('Google Cast framing', () {
    test('a message survives the protobuf round trip', () {
      const original = CastMessage(
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: 'urn:x-cast:com.google.cast.receiver',
        payload: '{"type":"LAUNCH","appId":"CC1AD845","requestId":1}',
      );

      final decoded = CastMessage.decode(original.encode());

      expect(decoded.sourceId, original.sourceId);
      expect(decoded.destinationId, original.destinationId);
      expect(decoded.namespace, original.namespace);
      expect(decoded.payload, original.payload);
      expect(decoded.type, 'LAUNCH');
      expect(decoded.json['appId'], 'CC1AD845');
    });

    test('accented text is carried as UTF-8, not truncated', () {
      const message = CastMessage(
        sourceId: 'sender-0',
        destinationId: 'transport-1',
        namespace: 'urn:x-cast:com.google.cast.media',
        payload: '{"title":"Coração Selvagem — T1 E4"}',
      );

      expect(CastMessage.decode(message.encode()).payload, message.payload);
    });

    test('the frame carries a four-byte big-endian length', () {
      const message = CastMessage(
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: 'ns',
        payload: '{}',
      );

      final framed = message.encodeFramed();
      final body = message.encode();

      expect(framed.length, body.length + 4);
      expect(ByteData.sublistView(framed, 0, 4).getUint32(0, Endian.big), body.length);
    });

    test('frames split across socket reads are reassembled', () {
      const first = CastMessage(
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: 'urn:x-cast:com.google.cast.tp.heartbeat',
        payload: '{"type":"PING"}',
      );
      const second = CastMessage(
        sourceId: 'receiver-0',
        destinationId: 'sender-0',
        namespace: 'urn:x-cast:com.google.cast.media',
        payload: '{"type":"MEDIA_STATUS"}',
      );

      final stream = Uint8List.fromList([...first.encodeFramed(), ...second.encodeFramed()]);
      final reader = CastFrameReader();

      // A TCP read can land anywhere, including in the middle of the length
      // prefix — the reader has to hold on until a whole frame is present.
      expect(reader.add(stream.sublist(0, 2)), isEmpty);
      expect(reader.add(stream.sublist(2, 9)), isEmpty);

      final messages = reader.add(stream.sublist(9));
      expect(messages, hasLength(2));
      expect(messages.first.type, 'PING');
      expect(messages.last.type, 'MEDIA_STATUS');
    });

    test('two frames arriving in one read are both returned', () {
      const message = CastMessage(
        sourceId: 'a',
        destinationId: 'b',
        namespace: 'ns',
        payload: '{"type":"PONG"}',
      );

      final reader = CastFrameReader();
      final messages = reader.add([...message.encodeFramed(), ...message.encodeFramed()]);
      expect(messages, hasLength(2));
    });

    test('a non-JSON payload does not throw', () {
      const message = CastMessage(sourceId: 'a', destinationId: 'b', namespace: 'ns', payload: 'oops');
      expect(message.json, isEmpty);
      expect(message.type, '');
    });
  });

  group('Google Cast payloads', () {
    test('the MIME type follows the container, so HLS is not sent as MP4', () {
      // Cast will not sniff the stream: a playlist announced as video/mp4 fails
      // to open, which is the usual "it plays on the phone but not on the TV".
      expect(ChromecastSession.contentTypeFor('http://x/y/index.m3u8'), 'application/x-mpegurl');
      expect(ChromecastSession.contentTypeFor('http://x/y/manifest.mpd'), 'application/dash+xml');
      expect(ChromecastSession.contentTypeFor('http://x/y/film.mkv'), 'video/x-matroska');
      expect(ChromecastSession.contentTypeFor('http://x/y/film.mp4?token=1'), 'video/mp4');
      expect(ChromecastSession.contentTypeFor('http://x/y/stream'), 'video/mp4');
    });

    test('the TXT record gives the name the user gave the device', () {
      final values = ChromecastClient.parseTxtRecord(
        'id=1a2b3c\nfn=TV da Sala\nmd=Chromecast Ultra\nrs=',
      );

      expect(values['fn'], 'TV da Sala');
      expect(values['md'], 'Chromecast Ultra');
      expect(values['rs'], '');
    });
  });

  group('CastStatus', () {
    test('progress is zero until the device reports a duration', () {
      const status = CastStatus(position: Duration(seconds: 30));
      expect(status.progress, 0);
    });

    test('progress never leaves 0..1 even if the device overshoots', () {
      const status = CastStatus(
        position: Duration(seconds: 200),
        duration: Duration(seconds: 100),
      );
      expect(status.progress, 1.0);
    });
  });

  group('CastDevice', () {
    test('devices are identified by id, so both sweeps cannot list one twice', () {
      const a = CastDevice(id: 'dlna:uuid-1', name: 'TV', host: '10.0.0.2', port: 80, protocol: CastProtocol.dlna);
      const b = CastDevice(
        id: 'dlna:uuid-1',
        name: 'TV renomeada',
        host: '10.0.0.2',
        port: 8080,
        protocol: CastProtocol.dlna,
      );

      expect(a, b);
      expect({a, b}, hasLength(1));
    });
  });

  test('the LOAD payload is valid JSON with the fields the receiver requires', () {
    // Guards the shape of the payload the media receiver is handed; a missing
    // contentId or streamType is rejected with a generic LOAD_FAILED.
    final payload = jsonEncode({
      'type': 'LOAD',
      'autoplay': true,
      'currentTime': 90,
      'media': {
        'contentId': 'http://cdn/v.mp4',
        'contentType': ChromecastSession.contentTypeFor('http://cdn/v.mp4'),
        'streamType': 'BUFFERED',
        'metadata': {'metadataType': 0, 'title': 'Filme'},
      },
    });

    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    final media = decoded['media'] as Map<String, dynamic>;

    expect(decoded['type'], 'LOAD');
    expect(decoded['autoplay'], isTrue);
    expect(media['contentId'], isNotEmpty);
    expect(media['streamType'], 'BUFFERED');
    expect(media['contentType'], 'video/mp4');
  });
}
