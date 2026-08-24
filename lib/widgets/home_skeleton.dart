import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/sabuflix_theme.dart';

/// Placeholder that mirrors the home layout while the catalogue loads, so the
/// screen settles into place instead of snapping in from a spinner.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

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
              height: isDesktop ? 420 : 320,
              width: double.infinity,
              color: SabuflixTheme.surface,
            ),
            const SizedBox(height: 26),
            for (int row = 0; row < 2; row++) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                child: Container(
                  width: 172,
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
                  itemCount: 5,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      width: 148,
                      decoration: BoxDecoration(
                        color: SabuflixTheme.surface,
                        borderRadius: SabuflixTheme.radiusLg,
                      ),
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
