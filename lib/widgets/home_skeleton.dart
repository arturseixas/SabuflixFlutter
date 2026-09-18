import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/sabuflix_theme.dart';
import 'hero_banner.dart';

/// Placeholder that mirrors the home layout while the catalogue loads, so the
/// screen settles into place instead of snapping in from a spinner.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Shimmer.fromColors(
      baseColor: SabuflixTheme.of(context).surface,
      highlightColor: SabuflixTheme.of(context).surfaceLight,
      period: Duration(milliseconds: 1400),
      enabled: !MediaQuery.disableAnimationsOf(context),
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(isDesktop ? 40 : 20, 12, 20, 10),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 84,
                      height: 32,
                      margin: EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: SabuflixTheme.of(context).surface,
                        borderRadius: SabuflixTheme.radiusMd,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              height: heroHeightFor(context, MediaQuery.sizeOf(context).width),
              width: double.infinity,
              color: SabuflixTheme.of(context).surface,
            ),
            SizedBox(height: 26),
            for (int row = 0; row < 2; row++) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 14),
                child: Container(
                  width: 172,
                  height: 18,
                  decoration: BoxDecoration(
                    color: SabuflixTheme.of(context).surface,
                    borderRadius: SabuflixTheme.radiusSm,
                  ),
                ),
              ),
              SizedBox(
                height: (isDesktop ? 340 : 270) * 9 / 16,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 5,
                  itemBuilder: (context, index) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      width: isDesktop ? 340 : 270,
                      decoration: BoxDecoration(
                        color: SabuflixTheme.of(context).surface,
                        borderRadius: SabuflixTheme.radiusLg,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 26),
            ],
          ],
        ),
      ),
    );
  }
}
