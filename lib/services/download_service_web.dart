import '../models/download_item.dart';

/// Thrown when a transfer is stopped on purpose (pause / remove).
class DownloadCancelled implements Exception {
  const DownloadCancelled();
  @override
  String toString() => 'DownloadCancelled';
}

typedef DownloadProgress = void Function(int received, int total);

/// Web stand-in for [DownloadService].
///
/// The TV browsers (Tizen, webOS) sandbox the app away from any storage a
/// multi-gigabyte video could live in, so downloads simply do not exist there.
/// Every query answers "nothing on disk" and the transfer itself refuses
/// loudly, in the user's language, instead of failing somewhere deeper with a
/// stack trace nobody can read from a sofa.
class DownloadService {
  static const String unsupportedMessage =
      'Downloads não estão disponíveis na versão para TVs Samsung e LG. '
      'Use o streaming — ou o aplicativo de Android TV, Windows ou celular para baixar.';

  bool isRunning(String id) => false;

  Future<String?> existingPath(String profileKey, String fileName) async => null;

  Future<int> bytesOnDisk(String profileKey, String fileName) async => 0;

  Future<void> deleteFile(String profileKey, String fileName) async {}

  Future<void> download({
    required String profileKey,
    required DownloadItem item,
    required DownloadProgress onProgress,
  }) async {
    throw UnsupportedError(unsupportedMessage);
  }

  Future<void> stop(String id) async {}

  Future<void> stopAll() async {}
}
