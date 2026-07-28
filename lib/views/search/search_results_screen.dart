import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/search_controller.dart' as search_ctrl;
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/trainer_certification_helper.dart';

/// Search Results Screen
class SearchResultsScreen extends StatelessWidget {
  const SearchResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final search_ctrl.WorkoutSearchController controller = Get.find<search_ctrl.WorkoutSearchController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Search Results', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.onPrimary),
            onPressed: () => Get.back(),
            tooltip: 'Adjust Filters',
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isSearching) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.accent),
                const SizedBox(height: 16),
                Text('Searching...', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
              ],
            ),
          );
        }

        final results = controller.searchResults;

        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 80, color: AppColors.primaryGray.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('No results found', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
                const SizedBox(height: 8),
                Text('Try adjusting your filters', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.tune),
                  label: const Text('Adjust Filters'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Results Header
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${results.length} result${results.length > 1 ? 's' : ''} found',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                  ),
                  if (controller.filters.hasActiveFilters)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '${controller.filters.activeFilterCount} filter${controller.filters.activeFilterCount > 1 ? 's' : ''}',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),

            // Results List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final item = results[index];
                  return _buildResultCard(item);
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> item) {
    final isProgram = item['type'] == 'program';
    final isFree = (item['price'] as double) == 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.3), width: 1),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to detail screen
          if (isProgram) {
            Get.toNamed(AppRoutes.programDetail);
          } else {
            Get.toNamed(AppRoutes.workoutDetail);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image and Type Badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    color: AppColors.primaryGray.withValues(alpha: 0.2),
                    child: Image.asset(
                      item['image'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(child: Icon(isProgram ? Icons.fitness_center : Icons.play_circle_outline, size: 60, color: AppColors.accent.withValues(alpha: 0.5)));
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: isProgram ? AppColors.accent : AppColors.completed, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      isProgram ? 'PROGRAM' : 'WORKOUT',
                      style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (isFree)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.completed, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        'FREE',
                        style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    item['name'],
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Trainer and Rating
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: AppColors.primaryGray),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item['trainer'],
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCertifiedFromUiMap(Map<String, dynamic>.from(item)))
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.verified, size: 16, color: AppColors.accent),
                        ),
                      const SizedBox(width: 8),
                      Icon(Icons.star, size: 16, color: AppColors.upcoming),
                      const SizedBox(width: 4),
                      Text(
                        item['rating'].toString(),
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTag(item['workoutType'], Icons.fitness_center),
                      _buildTag(item['difficulty'], Icons.signal_cellular_alt),
                      _buildTag(item['duration'], Icons.schedule),
                      _buildTag(item['equipment'], Icons.home_repair_service),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!isFree)
                        Text(
                          '\$${item['price'].toStringAsFixed(2)}',
                          style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                        )
                      else
                        Text(
                          'Free',
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.completed, fontWeight: FontWeight.bold),
                        ),
                      ElevatedButton(
                        onPressed: () {
                          if (isProgram) {
                            Get.toNamed(AppRoutes.programDetail);
                          } else {
                            Get.toNamed(AppRoutes.workoutDetail);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: Text('View Details', style: AppTextStyles.labelMedium.copyWith(color: AppColors.onAccent)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryGray.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryGray),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface)),
        ],
      ),
    );
  }
}
