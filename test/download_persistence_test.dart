import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/models/download_item.dart';
import 'package:sabuflix/models/media_item.dart';
import 'package:sabuflix/providers/download_provider.dart';
import 'package:sabuflix/services/download_service.dart';
import 'package:sabuflix/services/download_store.dart';

/// `flutter test` never registers a real platform implementation for
/// `path_provider` (that only happens in an actual running app), so we
/// stand in for it here — pointing "application support directory" at a
/// real temp folder, exactly like a real device would give us a real
/// private-storage path.
void _mockPathProvider(String supportDirPath) {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (MethodCall call) async {
      if (call.method == 'getApplicationSupportDirectory') return supportDirPath;
      return null;
    },
  );
}

MediaItem _media() => MediaItem(
      id: 9999,
      title: 'Domínio Público',
      voteAverage: 7.0,
      voteCount: 10,
      mediaType: 'movie',
      genreIds: const [],
      imdbId: 'tt0000000',
    );

Future<HttpServer> _startFakeVideoServer(List<int> bytes) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    request.response.headers.set('content-type', 'video/mp4');
    request.response.headers.contentLength = bytes.length;
    request.response.add(bytes);
    request.response.close();
  });
  return server;
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  String Function()? debug,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condição não atingida dentro do tempo limite. Último estado: ${debug?.call()}');
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // TestWidgetsFlutterBinding installs an HttpOverrides that fakes every
    // dart:io HttpClient request with a 400 — undo that so the download
    // service's real http.Client can talk to our local test server.
    HttpOverrides.global = null;
    DownloadService.resetCacheForTesting();
  });

  test('download concluído sobrevive a um "reinício do app" (novo provider, mesmo disco)', () async {
    // Diretório real em disco, compartilhado pelas duas "sessões" abaixo —
    // é exatamente isso que getApplicationSupportDirectory() devolveria de
    // verdade num app instalado (o mesmo caminho a cada abertura).
    final supportDir = await Directory.systemTemp.createTemp('sabuflix_support_');
    _mockPathProvider(supportDir.path);
    addTearDown(() => supportDir.delete(recursive: true));

    final bytes = List<int>.generate(2 * 1024 * 1024, (i) => i % 256);
    final server = await _startFakeVideoServer(bytes);
    final url = 'http://127.0.0.1:${server.port}/movie.mp4';
    final media = _media();

    // --- "Sessão 1": baixa o filme -----------------------------------
    final provider1 = DownloadProvider();
    await _waitUntil(() => !provider1.isLoading);

    final added = await provider1.addDownload(media: media, url: url, sourceName: 'Teste', quality: '720p');
    expect(added, isTrue, reason: 'addDownload deveria aceitar o novo item');

    final id = DownloadItem.buildId(media.id);
    await _waitUntil(
      () => provider1.byId(id)?.status == DownloadStatus.completed,
      timeout: const Duration(seconds: 20),
      debug: () {
        final item = provider1.byId(id);
        return 'status=${item?.status} recebidos=${item?.receivedBytes} total=${item?.totalBytes} erro=${item?.errorMessage}';
      },
    );

    final finishedItem = provider1.byId(id)!;
    expect(finishedItem.receivedBytes, bytes.length);

    final path1 = await DownloadService.filePath(finishedItem.fileName);
    expect(await File(path1).exists(), isTrue, reason: 'o arquivo final deveria existir em disco após concluir');
    expect(await File(path1).length(), bytes.length);

    // Confere diretamente o arquivo gravado em disco, sem passar pelo
    // provider — é a prova de que _save() realmente persistiu, e não só
    // manteve o estado na memória.
    final storedEntries = await DownloadStore.read();
    expect(storedEntries, isNotEmpty, reason: 'a lista de downloads deveria estar salva em disco');
    expect(storedEntries.first['status'], 'completed');

    provider1.dispose();
    await server.close(force: true);

    // --- "Sessão 2": simula reabrir o app -----------------------------
    final provider2 = DownloadProvider();
    await _waitUntil(() => !provider2.isLoading);

    final reloadedItem = provider2.byId(id);
    expect(reloadedItem, isNotNull, reason: 'o item deveria continuar na lista após "reabrir o app"');
    expect(reloadedItem!.status, DownloadStatus.completed);
    expect(provider2.isDownloaded(media.id), isTrue);

    final localPath = await provider2.localPathFor(media.id);
    expect(localPath, isNotNull, reason: 'localPathFor deveria apontar para o arquivo já baixado');
    expect(await File(localPath!).exists(), isTrue);

    provider2.dispose();
  });

  test('gravações simultâneas do arquivo de downloads não se corrompem', () async {
    final supportDir = await Directory.systemTemp.createTemp('sabuflix_support_race_');
    _mockPathProvider(supportDir.path);
    addTearDown(() => supportDir.delete(recursive: true));

    // Dispara várias escritas ao mesmo tempo, sem esperar cada uma
    // terminar — é exatamente o que acontecia antes entre _start()
    // (unawaited) e um _onComplete/_onError chegando logo em seguida.
    final writes = <Future<void>>[];
    for (int i = 0; i < 20; i++) {
      writes.add(DownloadStore.write([
        {'id': '$i', 'tick': i},
      ]));
    }
    await Future.wait(writes);

    // O arquivo final tem que ser um JSON válido e íntegro — nunca uma
    // mistura de duas escritas que se sobrepuseram no mesmo arquivo.
    final result = await DownloadStore.read();
    expect(result, hasLength(1));
    expect(result.first['id'], isNotNull);
  });

  test('diagnostics() reporta a pasta, os arquivos nela e o log de eventos', () async {
    final supportDir = await Directory.systemTemp.createTemp('sabuflix_support_diag_');
    _mockPathProvider(supportDir.path);
    addTearDown(() => supportDir.delete(recursive: true));

    await DownloadStore.write([
      {'id': '1', 'status': 'completed'},
    ]);
    await DownloadService.log('evento de teste');

    final report = await DownloadService.diagnostics();
    expect(report, contains('Pasta:'));
    expect(report, contains('downloads.json existe: true'));
    expect(report, contains('"status":"completed"'));
    expect(report, contains('evento de teste'));
  });
}
