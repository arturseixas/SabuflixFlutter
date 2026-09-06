import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabuflix/models/media_item.dart';
import 'package:sabuflix/providers/search_provider.dart';
import 'package:sabuflix/services/tmdb_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ControlledSearch extends TMDBService {
  final requests = <String, Completer<List<MediaItem>>>{};
  @override
  Future<List<MediaItem>> searchMedia(String query) =>
      (requests[query] = Completer<List<MediaItem>>()).future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('typing invalidates an in-flight search before the next debounce',
      () async {
    final service = ControlledSearch();
    final provider = SearchProvider(service: service);
    await Future<void>.delayed(Duration.zero);
    final old = provider.search('old');
    provider.scheduleSearch('new');
    service.requests['old']!.complete([
      MediaItem.fromJson({'id': 1, 'title': 'Old'})
    ]);
    await old;
    expect(provider.query, 'new');
    expect(provider.searchResults, isEmpty);
    expect(provider.isSearching, isTrue);
    provider.dispose();
  });
  test('request completion after dispose does not notify', () async {
    final service = ControlledSearch();
    final provider = SearchProvider(service: service);
    await Future<void>.delayed(Duration.zero);
    final request = provider.search('query');
    provider.dispose();
    service.requests['query']!.complete([]);
    await request;
  });
  test('service distinguishes network failure from empty results', () async {
    final client = MockClient((_) async => http.Response('{}', 503));
    final service = TMDBService(client: client);
    await expectLater(service.searchMedia('movie'), throwsStateError);
    await expectLater(service.fetchByGenre(28), throwsStateError);
    client.close();
  });
  test('requests time out instead of leaving the UI loading forever', () async {
    final client = MockClient((_) => Completer<http.Response>().future);
    final service =
        TMDBService(client: client, timeout: const Duration(milliseconds: 10));
    await expectLater(
        service.searchMedia('movie'), throwsA(isA<TimeoutException>()));
    client.close();
  });
}
