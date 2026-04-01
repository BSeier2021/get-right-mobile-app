import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_button.dart';

class ExerciseFrequencySelectionScreen extends StatefulWidget {
  const ExerciseFrequencySelectionScreen({super.key});

  @override
  State<ExerciseFrequencySelectionScreen> createState() => _ExerciseFrequencySelectionScreenState();
}

class _ExerciseFrequencySelectionScreenState extends State<ExerciseFrequencySelectionScreen> {
  String? _selectedFrequency;

  final List<String> _frequencies = ['Daily (7x/week)', '5 times per week', '3 times per week', '2 times per week', 'Once per week'];

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
                child: Image.asset('assets/images/planexercisebg.png', fit: BoxFit.fitHeight),
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
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
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
                            textAlign: TextAlign.left,
                            'How Often Do\nYou Plan To\nExercise?',
                            style: AppTextStyles.headlineLarge.copyWith(color: AppColors.onBackground, fontSize: 35.sp, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'This helps us create realistic\ngoals for you',
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
                              ..._frequencies.map((frequency) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildFrequencyButton(frequency))),
                              const SizedBox(height: 6),
                              CustomButton(
                                text: 'Get Started',
                                onPressed: _selectedFrequency != null
                                    ? () {
                                        final args = Get.arguments as Map<String, dynamic>?;
                                        final preference = args?['preference'] as String?;
                                        Get.offAllNamed(AppRoutes.home, arguments: {'preference': preference});
                                      }
                                    : null,
                                backgroundColor: _selectedFrequency != null ? AppColors.accent : const Color.fromARGB(195, 41, 96, 60),
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

  Widget _buildFrequencyButton(String frequency) {
    final isSelected = _selectedFrequency == frequency;
    return InkWell(
      onTap: () => setState(() => _selectedFrequency = frequency),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color.fromARGB(45, 41, 96, 60) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? AppColors.accent : const Color(0xFFD8DDD8), width: 1.2),
        ),
        child: Text(
          frequency,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
