import 'dart:convert';
import 'package:http/http.dart' as http;

/// A single playable source returned by the FrostStream add-on, with the
/// quality and file size parsed out so the user can tell sources apart and
/// pick the one they actually want instead of just the first one listed.
class StreamOption {
  final String name;
  final String title;
  final String url;
  final int? sizeBytes;
  final String? quality;

  StreamOption({
    required this.name,
    required this.title,
    required this.url,
    this.sizeBytes,
    this.quality,
  });

  factory StreamOption.fromMap(Map<String, dynamic> map) {
    final name = (map['name'] ?? 'Fonte').toString().trim();
    final title = (map['title'] ?? map['description'] ?? '').toString().trim();
    final url = (map['url'] ?? '').toString();
    final combinedText = '$name $title';

    int? sizeBytes = _sizeFromBehaviorHints(map['behaviorHints']);
    sizeBytes ??= _sizeFromText(combinedText);

    final quality = _qualityFromText(combinedText);

    return StreamOption(
      name: name.isEmpty ? 'Fonte' : name,
      title: title,
      url: url,
      sizeBytes: sizeBytes,
      quality: quality,
    );
  }

  static int? _sizeFromBehaviorHints(dynamic hints) {
    if (hints is! Map) return null;
    final raw = hints['videoSize'];
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  static final RegExp _sizeRegExp =
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(TB|GB|MB)', caseSensitive: false);

  static int? _sizeFromText(String text) {
    final match = _sizeRegExp.firstMatch(text);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (value == null) return null;
    final unit = match.group(2)!.toUpperCase();
    const int mb = 1024 * 1024;
    const int gb = mb * 1024;
    const int tb = gb * 1024;
    final multiplier = unit == 'TB' ? tb : (unit == 'GB' ? gb : mb);
    return (value * multiplier).round();
  }

  static final RegExp _qualityRegExp =
      RegExp(r'(2160p|4K|1440p|1080p|720p|480p|360p)', caseSensitive: false);

  static String? _qualityFromText(String text) {
    final match = _qualityRegExp.firstMatch(text);
    if (match != null) {
      final value = match.group(1)!;
      return value.toUpperCase() == '4K' ? '4K' : value.toLowerCase();
    }
    if (RegExp(r'\bHD\b').hasMatch(text)) return 'HD';
    if (RegExp(r'\bSD\b').hasMatch(text)) return 'SD';
    if (RegExp(r'\bCAM\b', caseSensitive: false).hasMatch(text)) return 'CAM';
    return null;
  }

  int get qualityRank {
    switch (quality) {
      case '4K':
      case '2160p':
        return 6;
      case '1440p':
        return 5;
      case '1080p':
        return 4;
      case 'HD':
      case '720p':
        return 3;
      case '480p':
        return 2;
      case 'SD':
      case '360p':
        return 1;
      case 'CAM':
        return 0;
      default:
        return -1;
    }
  }

  String get formattedSize {
    final bytes = sizeBytes;
    if (bytes == null || bytes <= 0) return '';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(0)} MB';
  }
}

class FrostStreamService {
  static const String _baseUrl = 'https://froststream.cloutteam.com/stream';

  static Future<List<StreamOption>> fetchStreams({
    required String imdbId,
    required String type, // 'movie' or 'tv'
    int? season,
    int? episode,
  }) async {
    if (imdbId.isEmpty) return [];

    String url;
    if (type == 'movie') {
      url = '$_baseUrl/movie/$imdbId.json';
    } else {
      if (season == null || episode == null) return [];
      url = '$_baseUrl/series/$imdbId:$season:$episode.json';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List streams = data['streams'] ?? [];
        final options = streams
            .map((s) => StreamOption.fromMap(s as Map<String, dynamic>))
            .toList();
        options.sort((a, b) {
          final qualityCompare = b.qualityRank.compareTo(a.qualityRank);
          if (qualityCompare != 0) return qualityCompare;
          return (b.sizeBytes ?? 0).compareTo(a.sizeBytes ?? 0);
        });
        return options;
      }
    } catch (e) {
      print('Error fetching FrostStream: $e');
    }
    return [];
  }
}
