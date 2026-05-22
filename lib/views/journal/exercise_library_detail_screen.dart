import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/exercise_library_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

class ExerciseLibraryDetailScreenss extends StatelessWidget {
  const ExerciseLibraryDetailScreenss({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>?;
    final ExerciseLibraryModel? exercise = args?['exercise'] as ExerciseLibraryModel?;

    if (exercise == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
            ),
            onPressed: () => Get.back(),
          ),
        ),
        body: Center(
          child: Text('Exercise not found', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text('Exercise Library', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              height: 180,
              decoration: BoxDecoration(color: const Color.fromARGB(255, 238, 252, 210), borderRadius: BorderRadius.circular(16)),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow, color: AppColors.primaryGrayDark, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text('Exercise Video', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGrayDark)),
                  ],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  exercise.name,
                  style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Target Muscles',
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Primary: ${exercise.primaryMuscle}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)),
                  if (exercise.secondaryMuscle != null) Text('Secondary: ${exercise.secondaryMuscle}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to Perform',
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...exercise.instructions.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${e.key + 1}. ',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                          ),
                          Expanded(
                            child: Text(e.value, style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (exercise.tips.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pro Tips',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...exercise.tips.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline, color: AppColors.accent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(t, style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (exercise.equipmentRequired != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Equipment Required',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(exercise.equipmentRequired!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)),
                  ],
                ),
              ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Text(
                    'Difficulty: ',
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: exercise.difficulty == 'Beginner'
                          ? AppColors.accent
                          : exercise.difficulty == 'Intermediate'
                          ? Colors.orange
                          : Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(exercise.difficulty, style: AppTextStyles.labelSmall.copyWith(color: AppColors.onAccent)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
