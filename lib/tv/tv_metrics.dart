import 'package:flutter/widgets.dart';

import 'tv_platform.dart';

/// Sizing for the two very different distances the app is read from.
///
/// Everything the shared widgets measure — poster width, shelf height, hero
/// height, section titles, page gutters — comes from here instead of being
/// hard-coded, so a single `isTv` flag moves the whole interface from a
/// hand's reach to the far side of a living room.
///
/// The TV numbers are derived from the screen instead of being fixed, because
/// "TV" spans a 1280×720 set-top box and a 4K panel reporting 1920×1080 logical
/// pixels. The clamps keep both ends sane.
class TvMetrics {
  final bool isTv;
  final Size screen;

  const TvMetrics._({required this.isTv, required this.screen});

  factory TvMetrics.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return TvMetrics._(isTv: TvPlatform.isTv, screen: size);
  }

  /// Explicit variant, for the few places that need to reason about a mode
  /// they are not currently rendering in.
  factory TvMetrics.forSize(Size size, {required bool isTv}) {
    return TvMetrics._(isTv: isTv, screen: size);
  }

  double get _width => screen.width;

  bool get isCompact => !isTv && _width < 800;

  bool get isWide => isTv || _width >= 800;

  /// TVs crop the edges of the picture. Every full-bleed screen keeps its
  /// content inside this margin so nothing important lands off-panel — 4% of
  /// the width, 4.5% of the height, the industry-standard title-safe area.
  EdgeInsets get overscan {
    if (!isTv) return EdgeInsets.zero;
    return EdgeInsets.fromLTRB(
      _width * 0.04,
      screen.height * 0.045,
      _width * 0.04,
      screen.height * 0.045,
    );
  }

  /// Horizontal padding for shelves and page content.
  double get gutter => isTv ? _width * 0.045 : 16;

  /// Poster card width. Eight and a half posters across a TV screen is the
  /// density every living-room catalogue converges on.
  double get posterWidth {
    if (!isTv) return 148;
    return (_width / 8.6).clamp(150.0, 260.0);
  }

  /// Poster + title label.
  double get posterRowHeight => posterWidth * 1.5 + (isTv ? 58 : 32);

  /// 16:9 "Continue watching" card.
  double get continueCardWidth {
    if (!isTv) return isCompact ? 232 : 268;
    return (_width / 5.2).clamp(260.0, 440.0);
  }

  double get continueRowHeight => continueCardWidth * 9 / 16 + (isTv ? 84 : 62);

  /// 16:9 episode thumbnail.
  double get episodeCardWidth => isTv ? (_width / 6.2).clamp(240.0, 380.0) : 200;

  double get episodeRowHeight => episodeCardWidth * 9 / 16 + (isTv ? 76 : 38);

  double get castCardWidth => isTv ? 150 : 95;

  double get castRowHeight => isTv ? 210 : 145;

  /// Hero banner height: most of the screen on a TV, so the first shelf peeks
  /// in from the bottom and invites a scroll.
  double get heroHeight => isTv ? (screen.height * 0.74).clamp(420.0, 760.0) : 560;

  double get sectionTitleSize => isTv ? 26 : 19;

  double get cardLabelSize => isTv ? 17 : 13;

  double get bodySize => isTv ? 19 : 15;

  double get captionSize => isTv ? 15 : 12;

  double get titleSize => isTv ? 24 : 18;

  double get headlineSize => isTv ? 46 : 28;

  double get iconSize => isTv ? 30 : 22;

  /// Poster grid (search results, My List).
  int get gridCrossAxisCount {
    if (isTv) return (_width / 240).floor().clamp(4, 9);
    return (_width / 160).floor().clamp(2, 6);
  }

  /// Category grid.
  int get categoryCrossAxisCount {
    if (isTv) return (_width / 340).floor().clamp(3, 6);
    return (_width / 200).floor().clamp(2, 4);
  }

  /// Room the floating phone dock needs at the bottom of scrollable pages.
  /// The TV rail is on the left, so it needs none.
  double get bottomInset {
    if (isTv) return 40;
    return isCompact ? 118 : 32;
  }

  /// Collapsed / expanded width of the TV navigation rail.
  double get railWidth => 108;

  double get railExpandedWidth => (_width * 0.22).clamp(240.0, 340.0);

  /// How much a focused card grows. Small on purpose: big jumps make a shelf
  /// feel unstable when the remote is held down.
  double get focusScale => isTv ? 1.09 : 1.045;

  double get focusRingWidth => isTv ? 3.5 : 2;
}
