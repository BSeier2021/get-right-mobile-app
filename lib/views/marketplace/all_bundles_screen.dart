import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// All Bundles screen - displays all available program bundles
class AllBundlesScreen extends StatelessWidget {
  const AllBundlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> bundles = Get.arguments as List<Map<String, dynamic>>;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text('All Bundles', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${bundles.length} Bundles Available', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.65, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemCount: bundles.length,
              itemBuilder: (context, index) {
                return _buildBundleCard(context, bundles[index], bundles);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBundleCard(BuildContext context, Map<String, dynamic> bundle, List<Map<String, dynamic>> allBundles) {
    final programs = bundle['programs'] as List<Map<String, dynamic>>;
    final totalValue = bundle['totalValue'] as double;
    final bundlePrice = bundle['bundlePrice'] as double;

    // Calculate average rating from programs
    final avgRating = programs.isNotEmpty ? programs.map((p) => p['rating'] as double).reduce((a, b) => a + b) / programs.length : 4.7;
    final totalRatings = programs.isNotEmpty ? programs.map((p) => p['students'] as int).reduce((a, b) => a + b) : 1000;

    // Get primary trainer (first program's trainer)
    final primaryTrainer = programs.isNotEmpty ? programs[0]['trainer'] : 'Multiple Trainers';

    // Get thumbnail image based on bundle index
    final bundleIndex = allBundles.indexOf(bundle);
    final thumbnailUrls = [
      'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1517960413843-0aee8e2d471c?w=400&h=300&fit=crop',
    ];

    return GestureDetector(
      onTap: () {
        Get.toNamed(AppRoutes.bundleDetail, arguments: bundle);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: Image.network(
                    bundle['imageUrl'] ?? thumbnailUrls[bundleIndex % thumbnailUrls.length],
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: bundleIndex % 2 == 0 ? [const Color(0xFF9333EA), const Color(0xFFFBBF24)] : [const Color(0xFFDC2626), const Color(0xFFEF4444)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(child: Icon(Icons.fitness_center, size: 40, color: Colors.white)),
                    ),
                  ),
                ),
                // Bestseller badge
                if (bundleIndex < 5)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFF3D060), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        'Bestseller',
                        style: AppTextStyles.labelSmall.copyWith(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9),
                      ),
                    ),
                  ),
              ],
            ),

            // Content section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      bundle['title'],
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Instructor
                    Text(
                      primaryTrainer,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Rating
                    Row(
                      children: [
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 11),
                        ),
                        const SizedBox(width: 3),
                        ...List.generate(5, (index) => Icon(index < avgRating.floor() ? Icons.star : Icons.star_border, color: const Color(0xFFE59819), size: 11)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '(${_formatNumber(totalRatings)})',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Price
                    Row(
                      children: [
                        Text(
                          '\$${bundlePrice.toStringAsFixed(2)}',
                          style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '\$${totalValue.toStringAsFixed(2)}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, decoration: TextDecoration.lineThrough, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
