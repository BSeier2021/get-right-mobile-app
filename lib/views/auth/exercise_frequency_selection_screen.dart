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
  String? _selectedValue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlans());
  }

  Future<void> _loadPlans() async {
    final auth = Get.find<AuthController>();
    await auth.fetchExercisePlans();
    if (!mounted) return;
    setState(() {});
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
    for (final p in auth.exercisePlans) {
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
                        if (auth.exercisePlansLoading && auth.exercisePlans.isEmpty) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                        }

                        if (auth.exercisePlansError != null && auth.exercisePlans.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    auth.exercisePlansError!,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.75)),
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: _loadPlans,
                                    child: Text(
                                      'Retry',
                                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

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
                                    ...auth.exercisePlans.map(
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
