import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/models/download_task.dart';
import 'package:sabuflix/models/media_item.dart';

MediaItem _series() => MediaItem(
      id: 42,
      title: 'Severance',
      voteAverage: 8.7,
      voteCount: 100,
      mediaType: 'tv',
      genreIds: const [18],
    );

DownloadTask _episode(int season, int episode, {DownloadStatus? status}) => DownloadTask(
      id: DownloadTask.buildId(42, season: season, episode: episode),
      media: _series(),
      season: season,
      episode: episode,
      episodeTitle: 'Ep $episode',
      status: status ?? DownloadStatus.queued,
    );

void main() {
  group('DownloadTask', () {
    test('ids distinguish episodes from the film form', () {
      expect(DownloadTask.buildId(42), '42');
      expect(DownloadTask.buildId(42, season: 2, episode: 5), '42-s2-e5');
      // A season without an episode is not addressable on its own.
      expect(DownloadTask.buildId(42, season: 2), '42');
    });

    test('progress is bounded even when the server lies about the size', () {
      final task = _episode(1, 1)
        ..totalBytes = 100
        ..receivedBytes = 250;
      expect(task.progress, 1.0);

      final unknown = _episode(1, 2)..receivedBytes = 50;
      expect(unknown.progress, 0.0);
    });

    test('round-trips through JSON, parking in-flight work as paused', () {
      final task = _episode(3, 4, status: DownloadStatus.downloading)
        ..receivedBytes = 10
        ..totalBytes = 20
        ..filePath = '/tmp/s3e4.mp4'
        ..qualityLabel = '1080p';

      final restored = DownloadTask.fromJson(task.toJson());

      expect(restored.id, task.id);
      expect(restored.season, 3);
      expect(restored.episode, 4);
      expect(restored.filePath, '/tmp/s3e4.mp4');
      expect(restored.qualityLabel, '1080p');
      expect(restored.media.title, 'Severance');
      expect(restored.status, DownloadStatus.paused);
    });

    test('keeps a finished download finished across a restart', () {
      final done = _episode(1, 1, status: DownloadStatus.completed);
      expect(DownloadTask.fromJson(done.toJson()).status, DownloadStatus.completed);
    });
  });

  group('DownloadGroup', () {
    test('buckets episodes by season, in order', () {
      final group = DownloadGroup(
        media: _series(),
        tasks: [
          _episode(2, 2),
          _episode(1, 3),
          _episode(2, 1),
          _episode(1, 1),
        ],
      );

      final seasons = group.seasons;
      expect(seasons.keys.toList(), [1, 2]);
      expect(seasons[1]!.map((t) => t.episode).toList(), [1, 3]);
      expect(seasons[2]!.map((t) => t.episode).toList(), [1, 2]);
    });

    test('counts what is done and what is still moving', () {
      final group = DownloadGroup(
        media: _series(),
        tasks: [
          _episode(1, 1, status: DownloadStatus.completed),
          _episode(1, 2, status: DownloadStatus.downloading),
          _episode(1, 3, status: DownloadStatus.paused),
        ],
      );

      expect(group.completedCount, 1);
      expect(group.activeCount, 1);
      expect(group.progress, closeTo(1 / 3, 0.001));
    });
  });
}
