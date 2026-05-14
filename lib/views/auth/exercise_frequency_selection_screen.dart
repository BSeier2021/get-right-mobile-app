import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/models/exercise_plan_option.dart';
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
  static const List<ExercisePlanOption> _exerciseFrequencyOptions = [
    ExercisePlanOption(value: 'Daily', title: 'Daily', description: 'I plan to exercise every day.'),
    ExercisePlanOption(value: 'Weekly', title: 'Weekly', description: 'I follow a general weekly exercise routine.'),
    ExercisePlanOption(value: 'TwiceaWeek', title: 'Twice a Week', description: 'I can commit to two sessions per week.'),
    ExercisePlanOption(value: 'ThreeTimesaWeek', title: 'Three Times a Week', description: 'I can commit to three sessions per week.'),
    ExercisePlanOption(value: 'FourTimesaWeek', title: 'Four Times a Week', description: 'I can commit to four sessions per week.'),
    ExercisePlanOption(value: 'FiveTimesaWeek', title: 'Five Times a Week', description: 'I can commit to five sessions per week.'),
    ExercisePlanOption(value: 'SixTimesaWeek', title: 'Six Times a Week', description: 'I can commit to six sessions per week.'),
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

  Future<void> _getStarted(AuthController auth) async {
    final value = _selectedValue;
    if (value == null) return;
    ExercisePlanOption? plan;
    for (final p in _exerciseFrequencyOptions) {
      if (p.value == value) {
        plan = p;
        break;
      }
    }
    final prev = _routeArgs();
    final ok = await auth.updateCustomerOnboardingProfile(routeArgs: prev, exerciseFrequency: value);
    if (!mounted) return;
    if (!ok) return;
    await auth.completeOnboarding();
    Get.offAllNamed(AppRoutes.home, arguments: {...prev, 'exercisePlan': value, if (plan != null) 'exercisePlanTitle': plan.title});
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
                  child: Image.asset('assets/images/planexercisebg.png', fit: BoxFit.fitHeight),
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
                              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
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
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
                            );
                          }),
                        ),
                        GetBuilder<AuthController>(
                          builder: (auth) => TextButton(
                            onPressed: auth.isLoading ? null : () => _onSkip(auth),
                            child: Text(
                              'Skip',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.6), fontSize: 16, fontWeight: FontWeight.w500),
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
                                        textAlign: TextAlign.left,
                                        'How Often Do\nYou Plan To\nExercise?',
                                        style: AppTextStyles.headlineLarge.copyWith(color: AppColors.onBackground, fontSize: 35.sp, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'This helps us create realistic\ngoals for you',
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          color: AppColors.onBackground.withOpacity(0.8),
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w400,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      ..._exerciseFrequencyOptions.map(
                                        (plan) => Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: _buildPlanCard(plan: plan, isSelected: _selectedValue == plan.value, onTap: () => setState(() => _selectedValue = plan.value)),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(maxWidth: 250.w),
                                        child: CustomButton(
                                          text: 'Get Started',
                                          onPressed: (_selectedValue != null && !auth.isLoading) ? () => _getStarted(auth) : null,
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

  Widget _buildPlanCard({required ExercisePlanOption plan, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color.fromARGB(45, 41, 96, 60) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? AppColors.accent : const Color(0xFFD8DDD8), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.title,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (plan.description.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                plan.description,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.8), fontSize: 13.5, fontWeight: FontWeight.w400, height: 1.25),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
