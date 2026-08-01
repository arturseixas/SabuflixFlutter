import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/models/download_item.dart';
import 'package:sabuflix/models/media_item.dart';
import 'package:sabuflix/services/download_service.dart';

MediaItem _media() => MediaItem(
      id: 550,
      title: 'Clube da Luta',
      voteAverage: 8.4,
      voteCount: 100,
      mediaType: 'movie',
      genreIds: const [18],
      imdbId: 'tt0137523',
    );

void main() {
  group('DownloadItem', () {
    test('sobrevive a um ciclo de serialização', () {
      final item = DownloadItem(
        id: DownloadItem.buildId(550),
        media: _media(),
        url: 'https://exemplo.com/filme.mkv',
        fileName: '550.mkv',
        sourceName: 'FrostStream',
        quality: '1080p',
        status: DownloadStatus.paused,
        receivedBytes: 1024,
        totalBytes: 4096,
        createdAt: 1700000000000,
      );

      final restored = DownloadItem.fromJson(
        json.decode(json.encode(item.toJson())) as Map<String, dynamic>,
      );

      expect(restored.id, item.id);
      expect(restored.media.id, 550);
      expect(restored.media.title, 'Clube da Luta');
      expect(restored.url, item.url);
      expect(restored.fileName, item.fileName);
      expect(restored.status, DownloadStatus.paused);
      expect(restored.receivedBytes, 1024);
      expect(restored.totalBytes, 4096);
      expect(restored.progress, 0.25);
    });

    test('identifica episódios separadamente do título', () {
      expect(DownloadItem.buildId(1399), '1399');
      expect(DownloadItem.buildId(1399, season: 2, episode: 5), '1399_s2e5');
    });

    test('expõe rótulos de progresso legíveis', () {
      final item = DownloadItem(
        id: '1399_s1e1',
        media: _media(),
        url: 'https://exemplo.com/ep.mp4',
        fileName: '1399_s1e1.mp4',
        season: 1,
        episode: 1,
        receivedBytes: 500 * 1024 * 1024,
        totalBytes: 1024 * 1024 * 1024,
        createdAt: 1700000000000,
      );

      expect(item.isEpisode, isTrue);
      expect(item.episodeLabel, 'T1:E1');
      expect(item.sizeLabel, '500 MB / 1.0 GB');
      expect(DownloadItem.formatBytes(0), '0 MB');
    });
  });

  group('DownloadService.buildFileName', () {
    test('mantém a extensão de vídeo anunciada pela fonte', () {
      expect(
        DownloadService.buildFileName(downloadId: '550', url: 'https://cdn.tld/a/b/filme.mkv?token=1'),
        '550.mkv',
      );
    });

    test('usa mp4 quando a URL não revela um container conhecido', () {
      expect(
        DownloadService.buildFileName(downloadId: '550_s1e2', url: 'https://cdn.tld/stream?id=9'),
        '550_s1e2.mp4',
      );
    });

    test('remove caracteres inválidos para o sistema de arquivos', () {
      expect(
        DownloadService.buildFileName(downloadId: 'a/b:c', url: 'https://cdn.tld/x.mp4'),
        'a_b_c.mp4',
      );
    });
  });
}
