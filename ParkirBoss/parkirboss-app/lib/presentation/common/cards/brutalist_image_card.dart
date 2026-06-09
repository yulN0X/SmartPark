import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';

/// Neo-brutalist image card with thick border and drop shadow.
/// Replicates Stitch:
/// `border-4 border-primary shadow-[6px_6px_0px_0px_rgba(26,26,26,1)]`
class BrutalistImageCard extends StatelessWidget {
  final String imagePath;
  final String? altText;
  final double width;
  final double height;
  final Widget? badge;
  final bool isNetworkImage;

  const BrutalistImageCard({
    super.key,
    required this.imagePath,
    this.altText,
    this.width = 256,
    this.height = 256,
    this.badge,
    this.isNetworkImage = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main image container
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: AppColors.onSurface,
                width: AppSpacing.borderMedium,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.onSurface,
                  offset: Offset(
                    AppSpacing.shadowMedium,
                    AppSpacing.shadowMedium,
                  ),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs - 1),
              child: isNetworkImage
                  ? Image.network(
                      imagePath,
                      fit: BoxFit.cover,
                      semanticLabel: altText,
                    )
                  : Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      semanticLabel: altText,
                    ),
            ),
          ),

          // Optional badge (e.g., icon overlay)
          if (badge != null)
            Positioned(
              bottom: -16,
              right: -16,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  border: Border.all(
                    color: AppColors.onSurface,
                    width: AppSpacing.borderMedium,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.onSurface,
                      offset: Offset(
                        AppSpacing.shadowSmall,
                        AppSpacing.shadowSmall,
                      ),
                    ),
                  ],
                ),
                child: badge,
              ),
            ),
        ],
      ),
    );
  }
}
