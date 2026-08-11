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

  const PipWindowArgs({
    required this.videoUrl,
    required this.title,
    this.imageUrl,
    required this.startAtSeconds,
  });

  factory PipWindowArgs.fromJson(Map<String, dynamic> json) {
    return PipWindowArgs(
      videoUrl: json['videoUrl'] as String? ?? '',
      title: json['title'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      startAtSeconds: json['startAtSeconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'videoUrl': videoUrl,
        'title': title,
        'imageUrl': imageUrl,
        'startAtSeconds': startAtSeconds,
      };

  String toArguments() => jsonEncode(toJson());

  static PipWindowArgs fromArguments(String arguments) {
    if (arguments.isEmpty) return const PipWindowArgs(videoUrl: '', title: '', startAtSeconds: 0);
    return PipWindowArgs.fromJson(jsonDecode(arguments) as Map<String, dynamic>);
  }
}
