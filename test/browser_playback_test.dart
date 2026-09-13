import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/utils/browser_playback.dart';

void main() {
  test('autoplay and pause interruptions remain recoverable', () {
    for (final message in [
      "play() failed because the user didn't interact with the document first.",
      'NotAllowedError: playback requires a user gesture',
      'The play() request was interrupted by a call to pause().',
    ]) {
      expect(isRecoverableBrowserPlayError(message), isTrue);
    }
  });
  test('network and decoding failures are still reported', () {
    for (final message in [
      'MEDIA_ERR_DECODE',
      'Failed to fetch',
      'No supported source was found'
    ]) {
      expect(isRecoverableBrowserPlayError(message), isFalse);
    }
  });
}
