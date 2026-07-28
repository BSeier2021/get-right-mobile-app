import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/search_controller.dart' as search_ctrl;
import 'package:get_right/models/filter_model.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Search and Filter Screen
class SearchScreen extends StatelessWidget {
  SearchScreen({super.key});

  final search_ctrl.WorkoutSearchController controller = Get.put(search_ctrl.WorkoutSearchController());
  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search & Filter', style: AppTextStyles.titleLarge.copyWith()), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Field
                  TextField(
                    controller: searchController,
                    onChanged: controller.updateSearchQuery,
                    decoration: InputDecoration(
                      hintText: 'Search workouts and programs...',
                      prefixIcon: Icon(Icons.search, color: AppColors.accent),
                      suffixIcon: Obx(
                        () => controller.searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: AppColors.primaryGray),
                                onPressed: () {
                                  searchController.clear();
                                  controller.updateSearchQuery('');
                                },
                              )
                            : const SizedBox(),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primaryGray),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primaryGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.accent, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Active filters count
                  Obx(() {
                    final count = controller.filters.activeFilterCount;
                    if (count > 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$count filter${count > 1 ? 's' : ''} applied',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                            ),
                            TextButton(
                              onPressed: controller.clearFilters,
                              child: Text('Clear All', style: AppTextStyles.labelMedium.copyWith(color: AppColors.error)),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox();
                  }),

                  // Workout Type
                  _buildFilterSection('Workout Type', WorkoutTypes.all, (type) => controller.filters.workoutTypes.contains(type), controller.toggleWorkoutType),
                  const SizedBox(height: 20),

                  // Difficulty Level
                  _buildFilterSection('Difficulty Level', DifficultyLevels.all, (level) => controller.filters.difficultyLevels.contains(level), controller.toggleDifficultyLevel),
                  const SizedBox(height: 20),

                  // Duration
                  _buildFilterSection('Duration', WorkoutDurations.all, (duration) => controller.filters.durations.contains(duration), controller.toggleWorkoutDuration),
                  const SizedBox(height: 20),

                  // Equipment Needed
                  _buildFilterSection('Equipment Needed', EquipmentTypes.all, (equipment) => controller.filters.equipmentTypes.contains(equipment), controller.toggleEquipmentType),
                  const SizedBox(height: 20),

                  // Program Duration
                  _buildFilterSection(
                    'Program Duration',
                    ProgramDurations.all,
                    (duration) => controller.filters.programDurations.contains(duration),
                    controller.toggleProgramDuration,
                  ),
                  const SizedBox(height: 20),

                  // Trainer Rating
                  _buildTrainerRatingFilter(),
                  const SizedBox(height: 20),

                  // Certification Status
                  _buildCertificationFilter(),
                  const SizedBox(height: 20),

                  // Price Range
                  _buildPriceRangeFilter(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.clearFilters,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.accent, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Clear Filters', style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      controller.performSearch();
                      Get.toNamed(AppRoutes.searchResults);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Obx(() {
                      final count = controller.searchResults.length;
                      return Text('Show Results${count > 0 ? ' ($count)' : ''}', style: AppTextStyles.labelLarge.copyWith(color: AppColors.onAccent));
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, List<String> options, bool Function(String) isSelected, void Function(String) onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            return Obx(() {
              final selected = isSelected(option);
              return FilterChip(
                label: Text(option),
                selected: selected,
                onSelected: (_) => onTap(option),
                backgroundColor: AppColors.surface,
                selectedColor: AppColors.accent.withValues(alpha: 0.2),
                checkmarkColor: AppColors.accent,
                side: BorderSide(color: selected ? AppColors.accent : AppColors.primaryGray, width: selected ? 2 : 1),
                labelStyle: AppTextStyles.labelMedium.copyWith(
                  color: selected ? AppColors.accent : AppColors.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            });
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTrainerRatingFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Minimum Trainer Rating',
          style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Obx(() {
          final rating = controller.filters.minTrainerRating ?? 0.0;
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${rating.toStringAsFixed(1)} Stars', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent)),
                  if (rating > 0)
                    TextButton(
                      onPressed: () => controller.setTrainerRating(null),
                      child: Text('Clear', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                    ),
                ],
              ),
              Slider(
                value: rating,
                min: 0,
                max: 5,
                divisions: 10,
                activeColor: AppColors.accent,
                inactiveColor: AppColors.primaryGray.withValues(alpha: 0.3),
                onChanged: (value) => controller.setTrainerRating(value > 0 ? value : null),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildCertificationFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Certification Status',
          style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Obx(() {
          final certified = controller.filters.certifiedOnly ?? false;
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: certified ? AppColors.accent : AppColors.primaryGray, width: certified ? 2 : 1),
            ),
            child: CheckboxListTile(
              title: Text('Certified Trainers Only', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
              subtitle: Text('Show only trainers with professional certifications', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
              value: certified,
              activeColor: AppColors.accent,
              onChanged: (value) => controller.toggleCertification(value),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPriceRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price Range',
          style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Obx(() {
          final minPrice = controller.filters.minPrice ?? 0.0;
          final maxPrice = controller.filters.maxPrice ?? 200.0;

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('\$${minPrice.toStringAsFixed(0)} - \$${maxPrice.toStringAsFixed(0)}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent)),
                  if (minPrice > 0 || maxPrice < 200)
                    TextButton(
                      onPressed: () => controller.setPriceRange(null, null),
                      child: Text('Clear', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                    ),
                ],
              ),
              RangeSlider(
                values: RangeValues(minPrice, maxPrice),
                min: 0,
                max: 200,
                divisions: 20,
                activeColor: AppColors.accent,
                inactiveColor: AppColors.primaryGray.withValues(alpha: 0.3),
                labels: RangeLabels('\$${minPrice.toStringAsFixed(0)}', '\$${maxPrice.toStringAsFixed(0)}'),
                onChanged: (values) {
                  controller.setPriceRange(values.start > 0 ? values.start : null, values.end < 200 ? values.end : null);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Free', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                  Text('\$200+', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                ],
              ),
            ],
          );
        }),
      ],
    );
  }
}
