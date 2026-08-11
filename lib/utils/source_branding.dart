/// Streams from third-party addons often carry the addon's own branding —
/// name, promo links, Telegram handles — baked directly into the `name`/
/// `title` strings they return. This strips that out so every stream reads
/// as coming from Sabuflix itself, no matter which source actually
/// answered, while keeping the parts a viewer actually needs to pick a
/// stream: quality, size, audio/language.
library;

final RegExp _brandNoiseLine = RegExp(
  r'froststream|fenixflix|fenixhub|cloutteam|t\.me/|telegram|discord\.gg|@[a-z0-9_]{3,}|https?://\S+',
  caseSensitive: false,
);

final RegExp _qualityPattern = RegExp(r'\b(4K|2160p|1080p|720p|480p|SD|HD|FHD|UHD)\b', caseSensitive: false);

/// Splits raw addon text into lines, drops anything that looks like source
/// self-promotion, and rejoins what's left.
String _sanitizeLines(String? raw) {
  if (raw == null) return '';
  final lines =
      raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).where((l) => !_brandNoiseLine.hasMatch(l));
  return lines.join(' · ');
}

/// The quality badge for a stream (e.g. "4K", "1080p"), or null if none of
/// the usual tokens show up in its name/title.
String? streamQualityBadge(Map<String, dynamic> stream) {
  final combined = '${stream['name'] ?? ''} ${stream['title'] ?? ''}';
  final match = _qualityPattern.firstMatch(combined);
  return match?.group(0)?.toUpperCase();
}

/// A clean, Sabuflix-branded title for a stream entry in the source picker.
String sabuflixStreamTitle(Map<String, dynamic> stream, int index) {
  final quality = streamQualityBadge(stream);
  return quality != null ? 'Sabuflix • $quality' : 'Sabuflix • Fonte ${index + 1}';
}

/// Secondary detail line — whatever useful text survives sanitization
/// (size, audio/language, codec), falling back to a generic label instead
/// of ever showing raw addon text.
String sabuflixStreamSubtitle(Map<String, dynamic> stream) {
  final cleanedTitle = _sanitizeLines(stream['title'] as String?);
  if (cleanedTitle.isNotEmpty) return cleanedTitle;
  final cleanedName = _sanitizeLines(stream['name'] as String?);
  if (cleanedName.isNotEmpty) return cleanedName;
  return 'Qualidade automática';
}

/// Short quality/size label used where download entries persist a single
/// string (e.g. `DownloadItem.quality`) — same sanitization, condensed to
/// one line.
String sabuflixQualityLabel(Map<String, dynamic> stream) {
  final quality = streamQualityBadge(stream);
  final subtitle = sabuflixStreamSubtitle(stream);
  if (quality != null && subtitle != 'Qualidade automática') return '$quality · $subtitle';
  return quality ?? subtitle;
}
