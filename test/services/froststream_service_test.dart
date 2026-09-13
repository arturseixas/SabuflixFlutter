import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/services/froststream_service.dart';

void main() {
  group('FrostStreamService.addonBaseUrl', () {
    test('removes manifest.json and preserves the encoded auth segment', () {
      const manifestUrl =
          'https://example.com/%7B%22auth_token%22%3A%22secret%22%7D/'
          'manifest.json';

      expect(
        FrostStreamService.addonBaseUrl(manifestUrl),
        'https://example.com/%7B%22auth_token%22%3A%22secret%22%7D',
      );
    });

    test('keeps an add-on base URL unchanged', () {
      const baseUrl = 'https://example.com/addon';

      expect(FrostStreamService.addonBaseUrl(baseUrl), baseUrl);
    });

    test('extracts base URLs for Wali and FrostStream manifests', () {
      expect(
        FrostStreamService.addonBaseUrl(
            'https://bestcine.dpdns.org/manifest.json'),
        'https://bestcine.dpdns.org',
      );
      expect(
        FrostStreamService.addonBaseUrl(
            'https://froststream.cloutteam.com/manifest.json'),
        'https://froststream.cloutteam.com',
      );
    });
  });
}
