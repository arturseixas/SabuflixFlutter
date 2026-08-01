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

  test(
    'download de um item com "genres" preenchido sobrevive a reabrir o app '
    '(reprodução do bug relatado)',
    () async {
      // Esta é a diferença crucial em relação ao primeiro teste: um
      // MediaItem vindo da tela de detalhes tem `genres` preenchido (uma
      // lista de nomes, o formato que o próprio toJson() grava) — e era
      // exatamente isso que travava o parser ao recarregar, descartando
      // silenciosamente a entrada e sobrescrevendo o downloads.json com [].
      final supportDir = await Directory.systemTemp.createTemp('sabuflix_support_genres_');
      _mockPathProvider(supportDir.path);
      addTearDown(() => supportDir.delete(recursive: true));

      final mediaWithGenres = MediaItem(
        id: 40075,
        title: 'Gravity Falls: Um Verão de Mistérios',
        voteAverage: 8.62,
        voteCount: 3537,
        mediaType: 'tv',
        genreIds: const [10759, 16, 35],
        genres: const ['Action & Adventure', 'Animação', 'Comédia'],
        imdbId: 'tt1865718',
      );

      final bytes = List<int>.generate(1024 * 1024, (i) => i % 256);
      final server = await _startFakeVideoServer(bytes);
      final url = 'http://127.0.0.1:${server.port}/movie.mp4';

      final provider1 = DownloadProvider();
      await _waitUntil(() => !provider1.isLoading);

      await provider1.addDownload(
        media: mediaWithGenres,
        url: url,
        sourceName: 'FrostStream 1080p',
        quality: '1080p',
        season: 1,
        episode: 1,
      );

      final id = DownloadItem.buildId(mediaWithGenres.id, season: 1, episode: 1);
      await _waitUntil(
        () => provider1.byId(id)?.status == DownloadStatus.completed,
        timeout: const Duration(seconds: 20),
      );

      provider1.dispose();
      await server.close(force: true);

      // "Reabre o app".
      final provider2 = DownloadProvider();
      await _waitUntil(() => !provider2.isLoading);

      expect(
        provider2.byId(id),
        isNotNull,
        reason: 'o item não pode sumir só porque o MediaItem tinha genres preenchido',
      );
      expect(provider2.byId(id)!.status, DownloadStatus.completed);

      final stillOnDisk = await DownloadStore.read();
      expect(
        stillOnDisk,
        isNotEmpty,
        reason: 'load() nunca deve apagar o downloads.json por causa de um erro de parse',
      );

      provider2.dispose();
    },
  );

  test(
    'recupera o download quando o índice foi apagado mas o vídeo está no disco '
    '(estado exato relatado pelo usuário)',
    () async {
      final supportDir = await Directory.systemTemp.createTemp('sabuflix_support_recover_');
      _mockPathProvider(supportDir.path);
      addTearDown(() => supportDir.delete(recursive: true));

      // Reproduz literalmente o que estava no aparelho: o .mp4 de 279 MB
      // presente, o downloads.json zerado para [].
      final downloadsDir = await DownloadService.directory();
      final video = File('${downloadsDir.path}${Platform.pathSeparator}40075_s1e1.mp4');
      await video.writeAsBytes(List<int>.filled(4096, 7));
      await DownloadStore.write([]);

      final provider = DownloadProvider();
      await _waitUntil(() => !provider.isLoading);

      final recoveredItem = provider.byId('40075_s1e1');
      expect(
        recoveredItem,
        isNotNull,
        reason: 'o vídeo está em disco, então o app tem que voltar a mostrá-lo',
      );
      expect(recoveredItem!.status, DownloadStatus.completed);
      expect(recoveredItem.season, 1);
      expect(recoveredItem.episode, 1);
      expect(recoveredItem.media.id, 40075);
      expect(recoveredItem.media.mediaType, 'tv');
      expect(recoveredItem.receivedBytes, 4096);

      // E tem que ser jogável, que é o que de fato importa.
      final localPath = await provider.localPathFor(40075, season: 1, episode: 1);
      expect(localPath, isNotNull);
      expect(await File(localPath!).exists(), isTrue);

      provider.dispose();
    },
  );

  test('a recuperação usa o sidecar quando ele existe, preservando os metadados', () async {
    final supportDir = await Directory.systemTemp.createTemp('sabuflix_support_sidecar_');
    _mockPathProvider(supportDir.path);
    addTearDown(() => supportDir.delete(recursive: true));

    final downloadsDir = await DownloadService.directory();
    final video = File('${downloadsDir.path}${Platform.pathSeparator}550.mp4');
    await video.writeAsBytes(List<int>.filled(2048, 1));

    await DownloadStore.writeSidecar('550', {
      'id': '550',
      'media': MediaItem(
        id: 550,
        title: 'Clube da Luta',
        voteAverage: 8.4,
        voteCount: 100,
        mediaType: 'movie',
        genreIds: const [18],
        genres: const ['Drama'],
      ).toJson(),
      'url': 'https://exemplo.com/f.mp4',
      'fileName': '550.mp4',
      'sourceName': 'FrostStream',
      'quality': '1080p',
      'status': 'completed',
      'receivedBytes': 2048,
      'totalBytes': 2048,
      'createdAt': 1700000000000,
    });
    await DownloadStore.write([]);

    final provider = DownloadProvider();
    await _waitUntil(() => !provider.isLoading);

    final item = provider.byId('550');
    expect(item, isNotNull);
    expect(item!.media.title, 'Clube da Luta', reason: 'o título tem que vir do sidecar');
    expect(item.quality, '1080p');
    expect(item.status, DownloadStatus.completed);

    provider.dispose();
  });

  test('uma entrada ilegível é preservada no arquivo, nunca descartada', () async {
    final supportDir = await Directory.systemTemp.createTemp('sabuflix_support_preserve_');
    _mockPathProvider(supportDir.path);
    addTearDown(() => supportDir.delete(recursive: true));

    // Uma entrada que o parser atual não entende, sem vídeo correspondente
    // em disco (então a recuperação não tem como reconstruí-la).
    await DownloadStore.write([
      {'id': 'formato-do-futuro', 'algo': 'que ainda não sabemos ler'},
    ]);

    final provider = DownloadProvider();
    await _waitUntil(() => !provider.isLoading);
    provider.dispose();

    final stillThere = await DownloadStore.read();
    expect(
      stillThere.any((e) => e['id'] == 'formato-do-futuro'),
      isTrue,
      reason: 'uma entrada que não conseguimos ler tem que continuar no arquivo, intacta',
    );
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
