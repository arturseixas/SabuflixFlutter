import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/models/stream_source.dart';

void main() {
  group('StreamSource naming', () {
    test('labels sources under the app name, never the provider', () {
      final source = StreamSource.tryParse({
        'url': 'https://example.test/a.mkv',
        'name': 'FrostStream\n1080p',
        'title': 'The.Movie.2024.1080p.WEB-DL.x265\n👤 42 💾 2.18 GB ⚙️ SomeTracker',
      })!;

      expect(source.label, 'Sabuflix 1080p');
      expect(source.label.toLowerCase(), isNot(contains('frost')));
      expect(source.subtitle.toLowerCase(), isNot(contains('frost')));
      expect(source.subtitle.toLowerCase(), isNot(contains('sometracker')));
    });

    test('falls back to the bare app name when resolution is unknown', () {
      final source = StreamSource.tryParse({
        'url': 'https://example.test/b.mkv',
        'name': 'FrostStream',
        'title': 'Some.Release.Group',
      })!;

      expect(source.label, 'Sabuflix');
    });

    test('reads 4K from any of its spellings', () {
      for (final spelling in ['2160p', '4K', 'UHD']) {
        final source = StreamSource.tryParse({
          'url': 'https://example.test/c.mkv',
          'title': 'Movie $spelling BluRay',
        })!;
        expect(source.label, 'Sabuflix 4K', reason: 'for "$spelling"');
      }
    });

    test('rejects entries with no playable url', () {
      expect(StreamSource.tryParse({'name': 'FrostStream 1080p'}), isNull);
      expect(StreamSource.tryParse({'url': '', 'name': 'x'}), isNull);
    });
  });

  group('StreamSource file size', () {
    test('prefers the exact byte count from behaviorHints', () {
      final source = StreamSource.tryParse({
        'url': 'https://example.test/d.mkv',
        'title': 'Movie 1080p 💾 9.99 GB',
        'behaviorHints': {'videoSize': 2341234567},
      })!;

      expect(source.sizeBytes, 2341234567);
      expect(source.sizeLabel, '2,18 GB');
    });

    test('parses the size out of the title when no byte count is given', () {
      final source = StreamSource.tryParse({
        'url': 'https://example.test/e.mkv',
        'title': 'Movie 1080p\n👤 12 💾 3.5 GB',
      })!;

      expect(source.sizeLabel, '3,50 GB');
    });

    test('handles a comma decimal separator', () {
      final source = StreamSource.tryParse({
        'url': 'https://example.test/f.mkv',
        'title': 'Filme 1080p 💾 1,75 GB',
      })!;

      expect(source.sizeLabel, '1,75 GB');
    });

    test('shows megabytes below a gigabyte', () {
      final source = StreamSource.tryParse({
        'url': 'https://example.test/g.mkv',
        'title': 'Movie 720p 💾 700 MB',
      })!;

      expect(source.sizeLabel, '700 MB');
    });

    test('says so plainly when the size is missing', () {
      final source = StreamSource.tryParse({
        'url': 'https://example.test/h.mkv',
        'title': 'Movie 1080p',
      })!;

      expect(source.sizeLabel, isNull);
      expect(source.subtitle, startsWith('Tamanho não informado'));
    });
  });

  group('StreamSource tags', () {
    test('surfaces technical descriptors and nothing else', () {
      final source = StreamSource.tryParse({
        'url': 'https://example.test/i.mkv',
        'title': 'Movie.2024.1080p.BluRay.x265.Atmos-RARBG 💾 4 GB',
      })!;

      expect(source.tags, ['BluRay', 'x265', 'Atmos']);
      expect(source.subtitle, '4,00 GB · BluRay · x265 · Atmos');
      expect(source.subtitle, isNot(contains('RARBG')));
    });

    test('caps the tag list so the row stays readable', () {
      final source = StreamSource.tryParse({
        'url': 'https://example.test/j.mkv',
        'title': 'Movie REMUX BluRay WEB-DL HDR x265 Atmos DTS Dual 💾 20 GB',
      })!;

      expect(source.tags.length, 3);
    });
  });

  group('StreamSource ordering', () {
    test('puts the best quality first, then the largest file', () {
      final sources = [
        StreamSource.tryParse({'url': 'a', 'title': '720p 💾 1 GB'})!,
        StreamSource.tryParse({'url': 'b', 'title': '4K 💾 20 GB'})!,
        StreamSource.tryParse({'url': 'c', 'title': '1080p 💾 2 GB'})!,
        StreamSource.tryParse({'url': 'd', 'title': '1080p 💾 8 GB'})!,
      ]..sort(StreamSource.compareByQuality);

      expect(sources.map((s) => s.url), ['b', 'd', 'c', 'a']);
    });
  });
}
