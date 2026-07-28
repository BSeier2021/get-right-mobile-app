import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/models/fitness_level_option.dart';
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
  static const List<FitnessLevelOption> _fitnessLevelOptions = [
    FitnessLevelOption(value: 'Beginner', title: 'Beginner', description: 'I am just getting started with fitness training.'),
    FitnessLevelOption(value: 'Intermediate', title: 'Intermediate', description: 'I have some training experience and routine.'),
    FitnessLevelOption(value: 'Advanced', title: 'Advanced', description: 'I train consistently and can handle higher intensity.'),
    FitnessLevelOption(value: 'Professional', title: 'Professional', description: 'I am highly trained and perform at elite level.'),
  ];

  String? _selectedValue;

  @override
  void initState() {
    super.initState();
  }

  Map<String, dynamic> _routeArgs() {
    final raw = Get.arguments;
    if (raw is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(raw);
  }

  Future<void> _onSkip(AuthController auth) async {
    final ok = await auth.updateCustomerOnboardingProfile(routeArgs: _routeArgs());
    if (!mounted) return;
    if (!ok) return;
    await auth.completeOnboarding();
    Get.offAllNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
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
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
                            ),
                            onPressed: Get.back,
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
                        GetBuilder<AuthController>(
                          builder: (auth) => TextButton(
                            onPressed: auth.isLoading ? null : () => _onSkip(auth),
                            child: Text(
                              'Skip',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withValues(alpha: 0.6), fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 14),
                    Expanded(
                      child: GetBuilder<AuthController>(
                        builder: (auth) {
                          return SingleChildScrollView(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'What\'s Your\nFitness Level?',
                                        style: AppTextStyles.headlineLarge.copyWith(color: AppColors.onBackground, fontSize: 35.sp, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'We\'ll adjust recommendations\nbased on your experience',
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          color: AppColors.onBackground.withValues(alpha: 0.8),
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w400,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      ..._fitnessLevelOptions.map(
                                        (level) => Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: _buildLevelCard(
                                            level: level,
                                            isSelected: _selectedValue == level.value,
                                            onTap: () => setState(() => _selectedValue = level.value),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(maxWidth: 250.w),
                                        child: CustomButton(
                                          text: 'Continue',
                                          onPressed: _selectedValue != null
                                              ? () {
                                                  final existingArgs = Get.arguments as Map<String, dynamic>?;
                                                  final args = <String, dynamic>{...?existingArgs, 'index': 3, 'fitnessLevel': _selectedValue};
                                                  Get.toNamed(AppRoutes.exerciseFrequencySelection, arguments: args);
                                                }
                                              : null,
                                          backgroundColor: _selectedValue != null ? AppColors.accent : const Color.fromARGB(195, 41, 96, 60),
                                          textColor: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelCard({required FitnessLevelOption level, required bool isSelected, required VoidCallback onTap}) {
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
              level.title,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (level.description.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                level.description,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withValues(alpha: 0.8), fontSize: 13.5, fontWeight: FontWeight.w400, height: 1.25),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
