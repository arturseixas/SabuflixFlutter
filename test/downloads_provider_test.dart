import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sabuflix/models/download_item.dart';
import 'package:sabuflix/models/media_item.dart';
import 'package:sabuflix/providers/downloads_provider.dart';
import 'package:sabuflix/services/download_service.dart';

/// Exercises the offline download engine against a real local HTTP server,
/// including the `Range` based resume path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late HttpServer server;
  late Uint8List payload;

  /// Milliseconds of delay injected between response chunks, so a test can
  /// pause a transfer while it is still in flight.
  int chunkDelayMs = 0;

  MediaItem movie(int id) => MediaItem(
        id: id,
        title: 'Filme $id',
        voteAverage: 8.0,
        voteCount: 100,
        mediaType: 'movie',
        genreIds: const [],
      );

  setUp(() async {
    // flutter_test installs an HttpOverrides that answers 400 to every real
    // request; these tests talk to a local server, so drop it.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('sabuflix_dl_test');
    DownloadService.debugRootOverride = root.path;

    // 512 KB of deterministic bytes, served in 32 KB chunks.
    payload = Uint8List.fromList(List<int>.generate(512 * 1024, (i) => i % 251));
    chunkDelayMs = 0;

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      var start = 0;
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null && range.startsWith('bytes=')) {
        start = int.tryParse(range.substring(6).split('-').first) ?? 0;
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-${payload.length - 1}/${payload.length}',
        );
      } else {
        request.response.statusCode = HttpStatus.ok;
      }
      request.response.contentLength = payload.length - start;

      const chunk = 32 * 1024;
      for (var offset = start; offset < payload.length; offset += chunk) {
        final end = (offset + chunk).clamp(0, payload.length);
        request.response.add(payload.sublist(offset, end));
        await request.response.flush();
        if (chunkDelayMs > 0) {
          await Future<void>.delayed(Duration(milliseconds: chunkDelayMs));
        }
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    DownloadService.debugRootOverride = null;
    if (await root.exists()) await root.delete(recursive: true);
  });

  String url() => 'http://${server.address.address}:${server.port}/video.mp4';

  /// Polls the provider until [test] holds, so we never race the transfer.
  Future<DownloadItem> waitFor(
    DownloadsProvider provider,
    String id,
    bool Function(DownloadItem) test, {
    Duration timeout = const Duration(seconds: 20),
    bool failFast = true,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final item = provider.itemById(id);
      if (item != null && test(item)) return item;
      if (failFast && item?.status == DownloadStatus.failed) {
        fail('Download $id falhou: ${item?.error}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    fail('Estado esperado não alcançado para $id: ${provider.itemById(id)?.status}');
  }

  test('baixa um filme por completo e grava o arquivo íntegro', () async {
    final provider = DownloadsProvider();
    await provider.loadForProfile('p1');

    final media = movie(1);
    final added = await provider.enqueue(
      media: media,
      url: url(),
      sourceName: 'FrostStream',
      quality: '1080p',
    );
    expect(added, isTrue);

    final id = DownloadItem.buildId(media.id, 'movie');
    final item = await waitFor(provider, id, (d) => d.status == DownloadStatus.completed);

    expect(item.error, isNull);
    expect(item.bytesReceived, payload.length);
    expect(item.totalBytes, payload.length);

    final file = File(provider.filePathFor(item)!);
    expect(await file.exists(), isTrue);
    expect(await file.readAsBytes(), equals(payload));
    expect(provider.isDownloaded(media), isTrue);
  });

  test('pausa no meio e retoma via Range sem corromper o arquivo', () async {
    chunkDelayMs = 25; // ~0.4s total, plenty of time to pause mid-flight.

    final provider = DownloadsProvider();
    await provider.loadForProfile('p1');

    final media = movie(2);
    await provider.enqueue(media: media, url: url(), sourceName: 'FrostStream', quality: '720p');
    final id = DownloadItem.buildId(media.id, 'movie');

    // Wait until something has landed on disk, then pause.
    await waitFor(provider, id, (d) => d.bytesReceived > 0 && d.status == DownloadStatus.downloading);
    await provider.pause(id);

    final paused = provider.itemById(id)!;
    expect(paused.status, DownloadStatus.paused);
    expect(paused.bytesReceived, greaterThan(0));
    expect(paused.bytesReceived, lessThan(payload.length));

    chunkDelayMs = 0;
    await provider.resume(id);
    final done = await waitFor(provider, id, (d) => d.status == DownloadStatus.completed);

    expect(done.bytesReceived, payload.length);
    final file = File(provider.filePathFor(done)!);
    expect(await file.readAsBytes(), equals(payload),
        reason: 'o arquivo retomado deve ser byte a byte idêntico ao original');
  });

  test('enfileira episódios distintos e não duplica o mesmo item', () async {
    final provider = DownloadsProvider();
    await provider.loadForProfile('p1');

    final serie = MediaItem(
      id: 77,
      title: 'Série',
      voteAverage: 9,
      voteCount: 10,
      mediaType: 'tv',
      genreIds: const [],
    );

    expect(await provider.enqueue(media: serie, url: url(), sourceName: 'F', quality: 'HD', season: 1, episode: 1), isTrue);
    expect(await provider.enqueue(media: serie, url: url(), sourceName: 'F', quality: 'HD', season: 1, episode: 2), isTrue);
    // Same episode again — must be rejected.
    expect(await provider.enqueue(media: serie, url: url(), sourceName: 'F', quality: 'HD', season: 1, episode: 1), isFalse);

    expect(provider.downloads.length, 2);

    final e1 = DownloadItem.buildId(77, 'tv', season: 1, episode: 1);
    final e2 = DownloadItem.buildId(77, 'tv', season: 1, episode: 2);
    await waitFor(provider, e1, (d) => d.status == DownloadStatus.completed);
    await waitFor(provider, e2, (d) => d.status == DownloadStatus.completed);

    expect(provider.isDownloaded(serie, season: 1, episode: 1), isTrue);
    expect(provider.itemById(e1)!.displayTitle, 'Série · T1:E1');
  });

  test('excluir remove a entrada e o arquivo do disco', () async {
    final provider = DownloadsProvider();
    await provider.loadForProfile('p1');

    final media = movie(3);
    await provider.enqueue(media: media, url: url(), sourceName: 'F', quality: 'SD');
    final id = DownloadItem.buildId(3, 'movie');
    final item = await waitFor(provider, id, (d) => d.status == DownloadStatus.completed);
    final path = provider.filePathFor(item)!;

    await provider.remove(id);

    expect(provider.itemById(id), isNull);
    expect(await File(path).exists(), isFalse);
  });

  test('marca falha quando a fonte responde com erro', () async {
    final provider = DownloadsProvider();
    await provider.loadForProfile('p1');

    final dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dead.listen((r) {
      r.response.statusCode = HttpStatus.notFound;
      r.response.close();
    });

    final media = movie(4);
    await provider.enqueue(
      media: media,
      url: 'http://${dead.address.address}:${dead.port}/nope.mp4',
      sourceName: 'F',
      quality: 'SD',
    );

    final id = DownloadItem.buildId(4, 'movie');
    final failed = await waitFor(
      provider,
      id,
      (d) => d.status == DownloadStatus.failed,
      failFast: false,
    );
    expect(failed.error, contains('404'));

    await dead.close(force: true);
  });

  test('downloads interrompidos voltam como pausados ao recarregar o perfil', () async {
    chunkDelayMs = 25;

    final first = DownloadsProvider();
    await first.loadForProfile('p2');
    final media = movie(5);
    await first.enqueue(media: media, url: url(), sourceName: 'F', quality: 'HD');
    final id = DownloadItem.buildId(5, 'movie');
    await waitFor(first, id, (d) => d.bytesReceived > 0);
    // Simulates the app being closed mid-transfer.
    await first.pause(id);
    first.dispose();

    chunkDelayMs = 0;
    final reopened = DownloadsProvider();
    await reopened.loadForProfile('p2');

    final restored = reopened.itemById(id);
    expect(restored, isNotNull);
    expect(restored!.status, DownloadStatus.paused);
    expect(restored.bytesReceived, greaterThan(0));
  });
}
