import 'dart:async';

import 'package:multicast_dns/multicast_dns.dart';

import '../../models/cast_device.dart';

const _serviceName = '_googlecast._tcp.local';

/// Finds Chromecast receivers — dongles, Android TV/Google TV, and any
/// "Chromecast built-in" smart TV — via mDNS/Bonjour service discovery.
///
/// Devices are yielded as they respond, so a picker UI can populate live
/// instead of waiting for one fixed timeout.
Stream<CastDevice> discoverChromecastDevices({
  Duration timeout = const Duration(seconds: 5),
}) async* {
  final client = MDnsClient();
  final seen = <String>{};
  try {
    await client.start();

    await for (final ptr in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(_serviceName),
      timeout: timeout,
    )) {
      String? host;
      int? port;
      String? friendlyName;

      await for (final srv in client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
        timeout: const Duration(seconds: 3),
      )) {
        port = srv.port;
        await for (final ip in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
          timeout: const Duration(seconds: 3),
        )) {
          host = ip.address.address;
          break;
        }
        break;
      }

      await for (final txt in client.lookup<TxtResourceRecord>(
        ResourceRecordQuery.text(ptr.domainName),
        timeout: const Duration(seconds: 3),
      )) {
        for (final line in txt.text.split('\n')) {
          if (line.startsWith('fn=')) {
            friendlyName = line.substring(3).trim();
          }
        }
        break;
      }

      if (host == null || port == null) continue;
      final id = 'cc-$host:$port';
      if (!seen.add(id)) continue;

      yield CastDevice(
        id: id,
        name: (friendlyName == null || friendlyName.isEmpty)
            ? ptr.domainName.replaceAll('.$_serviceName', '')
            : friendlyName,
        protocol: CastProtocol.chromecast,
        host: host,
        port: port,
      );
    }
  } finally {
    client.stop();
  }
}
