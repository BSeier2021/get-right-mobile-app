import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/models/user_goal_option.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_button.dart';

class GoalSelectionScreen extends StatefulWidget {
  const GoalSelectionScreen({super.key});

  @override
  State<GoalSelectionScreen> createState() => _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends State<GoalSelectionScreen> {
  final Set<String> _selectedGoalIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGoals());
  }

  Future<void> _loadGoals() async {
    final auth = Get.find<AuthController>();
    await auth.fetchGoals();
    if (!mounted) return;
    setState(() {});
  }

  void _continue(AuthController auth) {
    final prev = Get.arguments as Map<String, dynamic>?;
    final ordered = auth.goals.where((g) => _selectedGoalIds.contains(g.id)).toList();
    final goalIds = ordered.map((g) => g.id).toList();
    final goalNames = ordered.map((g) => g.name).toList();
    final mainGoals = ordered.map((g) => g.value).toList();
    Get.toNamed(AppRoutes.fitnessLevelSelection, arguments: {...?prev, 'goalIds': goalIds, 'goals': goalNames, 'mainGoals': mainGoals});
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
                  child: Image.asset('assets/images/maingoalbg.png', fit: BoxFit.fitHeight),
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
                              decoration: BoxDecoration(shape: BoxShape.circle, color: index < 2 ? AppColors.accent : const Color(0xFFC8D8C8)),
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
                          if (auth.goalsLoading && auth.goals.isEmpty) {
                            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                          }

                          if (auth.goalsError != null && auth.goals.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      auth.goalsError!,
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.75)),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: _loadGoals,
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
                                        'What\'s Your\nMain Goal?',
                                        style: AppTextStyles.headlineLarge.copyWith(color: AppColors.onBackground, fontSize: 35.sp, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'This helps us\nrecommend the best\nfeatures for you select\nall that apply',
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          color: AppColors.onBackground.withOpacity(0.8),
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w400,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      ...auth.goals.map((g) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildGoalButton(g))),
                                      const SizedBox(height: 6),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(maxWidth: 250.w),
                                        child: CustomButton(
                                          text: 'Continue',
                                          onPressed: _selectedGoalIds.isNotEmpty ? () => _continue(auth) : null,
                                          backgroundColor: _selectedGoalIds.isNotEmpty ? AppColors.accent : const Color.fromARGB(195, 41, 96, 60),
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

  Widget _buildGoalButton(UserGoalOption goal) {
    final isSelected = _selectedGoalIds.contains(goal.id);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedGoalIds.remove(goal.id);
          } else {
            _selectedGoalIds.add(goal.id);
          }
        });
      },
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
          goal.name,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
