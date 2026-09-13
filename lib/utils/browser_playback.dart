/// Browser policy rejections should leave Play available, not discard media.
bool isRecoverableBrowserPlayError(String message) {
  final text = message.toLowerCase();
  return text.contains('notallowederror') ||
      text.contains('request is not allowed') ||
      text.contains('user didn\'t interact') ||
      text.contains('user did not interact') ||
      text.contains('user gesture') ||
      text.contains('user interaction') ||
      text.contains('autoplay') ||
      text.contains('interrupted by a call to pause');
}
