import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/sabuflix_theme.dart';

/// Stand-in for the home screen while the catalog loads.
///
/// It mirrors the real layout — hero, then poster rows — so the screen settles
/// into place instead of jumping from a centred spinner to a full page.
class CatalogSkeleton extends StatelessWidget {
  const CatalogSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: SabuflixTheme.surface,
      highlightColor: SabuflixTheme.surfaceLight,
      period: const Duration(milliseconds: 1400),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 380,
              width: double.infinity,
              color: SabuflixTheme.surface,
            ),
            const SizedBox(height: 24),
            for (int row = 0; row < 3; row++) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                child: Container(
                  width: 180,
                  height: 18,
                  decoration: BoxDecoration(
                    color: SabuflixTheme.surface,
                    borderRadius: SabuflixTheme.radiusSm,
                  ),
                ),
              ),
              SizedBox(
                height: 222,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 6,
                  itemBuilder: (context, index) => Container(
                    width: 148,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: SabuflixTheme.surface,
                      borderRadius: SabuflixTheme.radiusLg,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grid stand-in, for the search results.
class GridSkeleton extends StatelessWidget {
  final int crossAxisCount;

  const GridSkeleton({Key? key, required this.crossAxisCount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: SabuflixTheme.surface,
      highlightColor: SabuflixTheme.surfaceLight,
      period: const Duration(milliseconds: 1400),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: crossAxisCount * 3,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: SabuflixTheme.surface,
            borderRadius: SabuflixTheme.radiusLg,
          ),
        ),
      ),
    );
  }
}
