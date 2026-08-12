import 'dart:convert';

/// Payload handed from the main window to a freshly-spawned PiP window via
/// `desktop_multi_window`'s `WindowConfiguration.arguments` — the two run
/// as separate Flutter engines, so this JSON blob is the only thing that
/// crosses between them at creation time.
class PipWindowArgs {
  final String videoUrl;
  final String title;
  final String? imageUrl;
  final int startAtSeconds;

  /// Cross-window channel this session talks over. Unique per PiP window:
  /// a channel accepts a limited number of engines, and a closing window's
  /// engine can still be alive (and still registered) when the next one
  /// starts — a fixed name would intermittently collide on reopen.
  final String channelName;

  const PipWindowArgs({
    required this.videoUrl,
    required this.title,
    this.imageUrl,
    required this.startAtSeconds,
    this.channelName = defaultChannelName,
  });

  static const String defaultChannelName = 'sabuflix_pip';

  factory PipWindowArgs.fromJson(Map<String, dynamic> json) {
    return PipWindowArgs(
      videoUrl: json['videoUrl'] as String? ?? '',
      title: json['title'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      startAtSeconds: json['startAtSeconds'] as int? ?? 0,
      channelName: json['channelName'] as String? ?? defaultChannelName,
    );
  }

  Map<String, dynamic> toJson() => {
        'videoUrl': videoUrl,
        'title': title,
        'imageUrl': imageUrl,
        'startAtSeconds': startAtSeconds,
        'channelName': channelName,
      };

  String toArguments() => jsonEncode(toJson());

  static PipWindowArgs fromArguments(String arguments) {
    if (arguments.isEmpty) return const PipWindowArgs(videoUrl: '', title: '', startAtSeconds: 0);
    return PipWindowArgs.fromJson(jsonDecode(arguments) as Map<String, dynamic>);
  }
}
