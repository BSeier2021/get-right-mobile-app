import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/models/user_preference_option.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_button.dart';

class PreferenceSelectionScreen extends StatefulWidget {
  const PreferenceSelectionScreen({super.key});

  @override
  State<PreferenceSelectionScreen> createState() => _PreferenceSelectionScreenState();
}

class _PreferenceSelectionScreenState extends State<PreferenceSelectionScreen> {
  String? _selectedPreferenceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreferences());
  }

  Future<void> _loadPreferences() async {
    final auth = Get.find<AuthController>();
    await auth.fetchPreferences();
    if (!mounted) return;
    setState(() {
      if (_selectedPreferenceId == null && auth.preferences.isNotEmpty) {
        _selectedPreferenceId = auth.preferences.first.id;
      }
    });
  }

  void _continue(AuthController auth) {
    final id = _selectedPreferenceId;
    if (id == null) return;
    UserPreferenceOption? selected;
    for (final p in auth.preferences) {
      if (p.id == id) {
        selected = p;
        break;
      }
    }
    if (selected == null) return;
    Get.toNamed(AppRoutes.goalSelection, arguments: {'preference': selected.name, 'preferenceId': selected.id, 'primaryFocus': selected.value});
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

  void _handleBack() {
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
      return;
    }
    Get.offAllNamed(AppRoutes.profileSetup);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _handleBack(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Image.asset('assets/images/preferencebg.png', fit: BoxFit.fitHeight),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 15.w),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Align(
                        //   alignment: Alignment.centerLeft,
                        //   child: IconButton(
                        //     icon: Container(
                        //       padding: const EdgeInsets.all(10),
                        //       decoration: BoxDecoration(
                        //         color: AppColors.accent.withOpacity(0.1),
                        //         borderRadius: BorderRadius.circular(10),
                        //       ),
                        //       child: const Icon(
                        //         Icons.arrow_back_ios_new,
                        //         color: AppColors.accent,
                        //         size: 18,
                        //       ),
                        //     ),
                        //     onPressed: _handleBack,
                        //   ),
                        // ),
                        SizedBox(width: 50.w),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: index == 0 ? AppColors.accent : const Color(0xFFC8D8C8)),
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
                    const SizedBox(height: 22),
                    Expanded(
                      child: GetBuilder<AuthController>(
                        builder: (auth) {
                          if (auth.preferencesLoading && auth.preferences.isEmpty) {
                            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                          }

                          if (auth.preferencesError != null && auth.preferences.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      auth.preferencesError!,
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withValues(alpha: 0.75)),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: _loadPreferences,
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
                                        'Whats Your\nPreference?',
                                        style: AppTextStyles.headlineLarge.copyWith(color: AppColors.onBackground, fontSize: 35.sp, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Choose your primary\nfocus to personalize\nyour experience',
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          color: AppColors.onBackground.withValues(alpha: 0.8),
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w400,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      ...auth.preferences.map(
                                        (p) => Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: _buildOptionCard(
                                            title: p.name,
                                            description: p.description,
                                            isSelected: _selectedPreferenceId == p.id,
                                            onTap: () => setState(() => _selectedPreferenceId = p.id),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(maxWidth: 230.w),
                                        child: CustomButton(
                                          text: 'Continue',
                                          onPressed: (_selectedPreferenceId != null && auth.preferences.isNotEmpty) ? () => _continue(auth) : null,
                                          backgroundColor: AppColors.accent,
                                          textColor: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
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

  Widget _buildOptionCard({required String title, String? description, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 230.w,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color.fromARGB(45, 41, 96, 60) : Colors.white,
          borderRadius: BorderRadius.circular(25.r),
          border: Border.all(color: isSelected ? AppColors.accent : const Color(0xFFD8DDD8), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            if (description != null && description.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                description.trim(),
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withValues(alpha: 0.85), fontSize: 15, fontWeight: FontWeight.w400, height: 1.25),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
