import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabuflix/models/media_item.dart';
import 'package:sabuflix/models/download_item.dart';
import 'package:sabuflix/services/download_service.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory =
        await Directory.systemTemp.createTemp('sabuflix-download-test-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  DownloadItem item() => DownloadItem(
      id: 'movie_1',
      media: MediaItem.fromJson({'id': 1, 'title': 'Test'}),
      url: 'https://example.com/video.mp4',
      quality: 'HD',
      fileName: 'movie_1.mp4',
      addedAt: 1);
  DownloadService service(http.Response Function(http.Request) response) =>
      DownloadService(
          documentsDirectory: () async => directory,
          clientFactory: () =>
              MockClient((request) async => response(request)));
  test('resumes only from the correct byte offset', () async {
    final s = service((request) {
      expect(request.headers['range'], 'bytes=3-');
      return http.Response.bytes([4, 5, 6], 206,
          headers: {'content-range': 'bytes 3-5/6'});
    });
    final file = await s.fileFor('default', item().fileName);
    await file.writeAsBytes([1, 2, 3]);
    await s.download(
        profileKey: 'default', item: item(), onProgress: (_, total) {});
    expect(await file.readAsBytes(), [1, 2, 3, 4, 5, 6]);
  });
  test('416 cannot mark a partial file as complete', () async {
    final s = service((_) =>
        http.Response('', 416, headers: {'content-range': 'bytes */12'}));
    await (await s.fileFor('default', item().fileName)).writeAsBytes([1, 2, 3]);
    await expectLater(
        s.download(
            profileKey: 'default', item: item(), onProgress: (_, total) {}),
        throwsA(isA<HttpException>()));
  });
  test('rejects a mismatched resume response without corrupting the file',
      () async {
    final s = service((_) => http.Response.bytes([9, 9], 206,
        headers: {'content-range': 'bytes 0-1/5'}));
    final file = await s.fileFor('default', item().fileName);
    await file.writeAsBytes([1, 2, 3]);
    await expectLater(
        s.download(
            profileKey: 'default', item: item(), onProgress: (_, total) {}),
        throwsA(isA<HttpException>()));
    expect(await file.readAsBytes(), [1, 2, 3]);
  });
  test('HTML and streaming manifests are not saved as playable videos',
      () async {
    for (final type in [
      'text/html',
      'application/vnd.apple.mpegurl',
      'application/dash+xml'
    ]) {
      final s = service((_) =>
          http.Response('not a video', 200, headers: {'content-type': type}));
      await expectLater(
          s.download(
              profileKey: 'default', item: item(), onProgress: (_, total) {}),
          throwsA(isA<HttpException>()));
    }
  });
  test('rejects paths outside the profile directory', () async {
    final s = service((_) => http.Response('', 200));
    await expectLater(s.fileFor('../outside', 'file.mp4'),
        throwsA(isA<FileSystemException>()));
    await expectLater(s.fileFor('default', '../outside.mp4'),
        throwsA(isA<FileSystemException>()));
  });
}
