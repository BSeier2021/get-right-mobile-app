import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_button.dart';

class FitnessLevelSelectionScreen extends StatefulWidget {
  const FitnessLevelSelectionScreen({super.key});

  @override
  State<FitnessLevelSelectionScreen> createState() => _FitnessLevelSelectionScreenState();
}

class _FitnessLevelSelectionScreenState extends State<FitnessLevelSelectionScreen> {
  String? _selectedLevel;

  final List<Map<String, String>> _levels = [
    {'title': 'Beginner', 'description': 'New to fitness or getting back into it'},
    {'title': 'Intermediate', 'description': 'Regular exercise, comfortable with basics'},
    {'title': 'Advanced', 'description': 'Experienced athlete or fitness enthusiast'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: Image.asset('assets/images/fitnesslevelbg.png', fit: BoxFit.fitHeight),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 35.w,
                        height: 35.h,
                        decoration: BoxDecoration(color: const Color(0xFFE7F1E7), borderRadius: BorderRadius.circular(5)),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.chevron_left, color: AppColors.accent, size: 20.sp),
                          onPressed: () => Get.back(),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: index < 3 ? AppColors.accent : const Color(0xFFC8D8C8)),
                          );
                        }),
                      ),
                      TextButton(
                        onPressed: () => Get.offAllNamed(AppRoutes.home),
                        child: Text(
                          'Skip',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.6), fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What\'s Your\nFitness Level?',
                            style: AppTextStyles.headlineLarge.copyWith(color: AppColors.onBackground, fontSize: 35.sp, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'We\'ll adjust recommendations\nbased on your experience',
                            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onBackground.withOpacity(0.8), fontSize: 15.sp, fontWeight: FontWeight.w400, height: 1.35),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 250.w),
                          child: Column(
                            children: [
                              ..._levels.map(
                                (level) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildLevelCard(
                                    title: level['title']!,
                                    description: level['description']!,
                                    isSelected: _selectedLevel == level['title'],
                                    onTap: () => setState(() => _selectedLevel = level['title']),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              CustomButton(
                                text: 'Continue',
                                onPressed: _selectedLevel != null
                                    ? () {
                                        final existingArgs = Get.arguments as Map<String, dynamic>?;
                                        final args = <String, dynamic>{...?existingArgs, 'index': 3};
                                        Get.toNamed(AppRoutes.exerciseFrequencySelection, arguments: args);
                                      }
                                    : null,
                                backgroundColor: _selectedLevel != null ? AppColors.accent : const Color.fromARGB(195, 41, 96, 60),
                                textColor: Colors.white,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
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

  Widget _buildLevelCard({required String title, required String description, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color.fromARGB(45, 41, 96, 60) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? AppColors.accent : const Color(0xFFD8DDD8), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.8), fontSize: 13.5, fontWeight: FontWeight.w400, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}
