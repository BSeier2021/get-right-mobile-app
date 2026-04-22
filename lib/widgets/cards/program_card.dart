import 'package:flutter/material.dart';
import 'package:get_right/models/program_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:get_right/widgets/safe_circle_network_avatar.dart';

/// Program card for marketplace
class ProgramCard extends StatelessWidget {
  final ProgramModel program;
  final VoidCallback? onTap;

  const ProgramCard({super.key, required this.program, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: () {
                final thumb = ImageUrlSanitizer.asHttpUrlOrNull(program.thumbnail);
                if (thumb != null) {
                  return Image.network(
                    thumb,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.primaryGray, // Gray background
                        child: const Icon(Icons.fitness_center, size: 48, color: AppColors.primaryGrayDark),
                      );
                    },
                  );
                }
                return Container(
                  color: AppColors.primaryGray, // Gray background
                  child: const Icon(Icons.fitness_center, size: 48, color: AppColors.primaryGrayDark),
                );
              }(),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title - White on dark card
                  Text(
                    program.title,
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Trainer info
                  Row(
                    children: [
                      SafeCircleNetworkAvatar(
                        radius: 12,
                        imageUrl: program.trainerImage,
                        backgroundColor: AppColors.primaryGray,
                        fallback: const Icon(Icons.person, size: 16, color: AppColors.primaryGrayDark),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          program.trainerName,
                          style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGray),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ), // Gray text
                      ),
                      if (program.isTrainerCertified) const Icon(Icons.verified, size: 16, color: AppColors.secondary),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Info row - Gray icons and text
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: AppColors.primaryGray),
                      const SizedBox(width: 4),
                      Text('${program.durationWeeks} weeks', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                      const Spacer(),
                      if (program.rating != null) ...[
                        Icon(Icons.star, size: 14, color: AppColors.upcoming),
                        const SizedBox(width: 4),
                        Text('${program.rating!.toStringAsFixed(1)} (${program.reviewCount ?? 0})', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Price
                  Text('\$${program.price.toStringAsFixed(2)}', style: AppTextStyles.titleMedium.copyWith(color: AppColors.secondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
