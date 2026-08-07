/// A playable source, presented under the app's own name.
///
/// The upstream provider hands back free-form `name`/`title` strings carrying
/// its own branding, release-group names and tracker chatter. None of that
/// reaches the UI: everything shown is re-derived here from what is actually
/// useful — resolution, file size, and a fixed set of technical tags.
class StreamSource {
  final String url;

  /// '4K', '1080p', … or null when the source says nothing about it.
  final String? resolution;

  final int? sizeBytes;

  /// Technical descriptors only, drawn from [_knownTags].
  final List<String> tags;

  const StreamSource({
    required this.url,
    this.resolution,
    this.sizeBytes,
    this.tags = const [],
  });

  /// What the user picks from — never the provider's own name.
  String get label => resolution == null ? 'Sabuflix' : 'Sabuflix $resolution';

  String? get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null || bytes <= 0) return null;

    const gigabyte = 1024 * 1024 * 1024;
    if (bytes >= gigabyte) {
      return '${(bytes / gigabyte).toStringAsFixed(2).replaceAll('.', ',')} GB';
    }
    return '${(bytes / (1024 * 1024)).round()} MB';
  }

  String get subtitle {
    final parts = [
      sizeLabel ?? 'Tamanho não informado',
      ...tags,
    ];
    return parts.join(' · ');
  }

  /// Higher is better. Drives the ordering of the source list.
  int get qualityRank => _resolutionRanks[resolution] ?? -1;

  static const Map<String, int> _resolutionRanks = {
    '4K': 5,
    '1440p': 4,
    '1080p': 3,
    '720p': 2,
    '480p': 1,
    '360p': 0,
  };

  /// Substrings worth surfacing, mapped to how they should be spelled. Nothing
  /// outside this list is ever displayed, which is what keeps provider and
  /// release-group names out of the UI.
  static const Map<String, String> _knownTags = {
    'remux': 'REMUX',
    'bluray': 'BluRay',
    'blu-ray': 'BluRay',
    'bdrip': 'BDRip',
    'brrip': 'BRRip',
    'web-dl': 'WEB-DL',
    'webdl': 'WEB-DL',
    'webrip': 'WEBRip',
    'hdtv': 'HDTV',
    'dolby vision': 'Dolby Vision',
    'dovi': 'Dolby Vision',
    'hdr10': 'HDR10',
    'hdr': 'HDR',
    'x265': 'x265',
    'h265': 'x265',
    'hevc': 'x265',
    'x264': 'x264',
    'h264': 'x264',
    'av1': 'AV1',
    'atmos': 'Atmos',
    'truehd': 'TrueHD',
    'dts-hd': 'DTS-HD',
    'dts': 'DTS',
    'ac3': 'AC3',
    'aac': 'AAC',
    'dual': 'Dual Áudio',
    'dublado': 'Dublado',
    'legendado': 'Legendado',
  };

  /// Returns null for entries with no playable URL.
  static StreamSource? tryParse(Map<String, dynamic> raw) {
    final url = raw['url'];
    if (url is! String || url.isEmpty) return null;

    // The provider spreads quality across both fields inconsistently, so both
    // are searched as one.
    final haystack = [
      raw['name'],
      raw['title'],
      raw['description'],
      (raw['behaviorHints'] is Map) ? raw['behaviorHints']['filename'] : null,
    ].whereType<String>().join(' ').toLowerCase();

    return StreamSource(
      url: url,
      resolution: _parseResolution(haystack),
      sizeBytes: _parseSizeBytes(raw, haystack),
      tags: _parseTags(haystack),
    );
  }

  static String? _parseResolution(String haystack) {
    if (RegExp(r'(2160p?|\b4k\b|\buhd\b)').hasMatch(haystack)) return '4K';
    if (RegExp(r'1440p?\b').hasMatch(haystack)) return '1440p';
    if (RegExp(r'(1080p?\b|\bfhd\b|full ?hd)').hasMatch(haystack)) return '1080p';
    if (RegExp(r'(720p?\b|\bhd\b)').hasMatch(haystack)) return '720p';
    if (RegExp(r'(480p?\b|\bsd\b)').hasMatch(haystack)) return '480p';
    if (RegExp(r'360p?\b').hasMatch(haystack)) return '360p';
    return null;
  }

  static int? _parseSizeBytes(Map<String, dynamic> raw, String haystack) {
    // Newer entries carry an exact byte count; prefer it over parsing prose.
    final hints = raw['behaviorHints'];
    if (hints is Map) {
      final hinted = hints['videoSize'];
      if (hinted is num && hinted > 0) return hinted.toInt();
    }
    final direct = raw['size'] ?? raw['videoSize'];
    if (direct is num && direct > 0) return direct.toInt();
    if (direct is String) {
      final parsed = int.tryParse(direct);
      if (parsed != null && parsed > 0) return parsed;
    }

    // Otherwise it is spelled out in the title, e.g. '💾 2.18 GB'.
    final match = RegExp(r'(\d+(?:[.,]\d+)?)\s*(gb|gib|mb|mib)').firstMatch(haystack);
    if (match == null) return null;

    final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (value == null || value <= 0) return null;

    final isGigabyte = match.group(2)!.startsWith('g');
    return (value * (isGigabyte ? 1024 * 1024 * 1024 : 1024 * 1024)).round();
  }

  static List<String> _parseTags(String haystack) {
    final found = <String>[];
    for (final entry in _knownTags.entries) {
      if (found.length >= 3) break;
      if (!haystack.contains(entry.key)) continue;
      if (found.contains(entry.value)) continue;
      found.add(entry.value);
    }
    return found;
  }

  /// Best quality first, then largest file — the order people actually want.
  static int compareByQuality(StreamSource a, StreamSource b) {
    final byResolution = b.qualityRank.compareTo(a.qualityRank);
    if (byResolution != 0) return byResolution;
    return (b.sizeBytes ?? 0).compareTo(a.sizeBytes ?? 0);
  }
}
