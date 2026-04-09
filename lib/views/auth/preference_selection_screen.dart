import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
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
  String? _selectedPreference = 'Running & Cardio';

  @override
  Widget build(BuildContext context) {
    final double contentMaxWidth = MediaQuery.of(context).size.width * 0.68;

    return Scaffold(
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
                            decoration: BoxDecoration(shape: BoxShape.circle, color: index == 0 ? AppColors.accent : const Color(0xFFC8D8C8)),
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

                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'Whats Your\nPreference?',
                            style: AppTextStyles.headlineLarge.copyWith(color: AppColors.onBackground, fontSize: 35.sp, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose your primary\nfocus to personalize\nyour experience',
                            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onBackground.withOpacity(0.8), fontSize: 15.sp, fontWeight: FontWeight.w400, height: 1.35),
                          ),
                          const SizedBox(height: 18),
                          _buildOptionCard(
                            title: 'Strength Training',
                            description: 'I love lifting weights and\nbuilding strength',
                            isSelected: _selectedPreference == 'Strength Training',
                            onTap: () => setState(() => _selectedPreference = 'Strength Training'),
                          ),
                          const SizedBox(height: 12),
                          _buildOptionCard(
                            title: 'Running & Cardio',
                            description: 'I prefer running, jogging, and\ncardio activities',
                            isSelected: _selectedPreference == 'Running & Cardio',
                            onTap: () => setState(() => _selectedPreference = 'Running & Cardio'),
                          ),
                          const SizedBox(height: 20),

                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 230.w),
                            child: CustomButton(
                              text: 'Continue',
                              onPressed: _selectedPreference != null ? () => Get.toNamed(AppRoutes.goalSelection, arguments: {'preference': _selectedPreference}) : null,
                              backgroundColor: AppColors.accent,
                              textColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ).paddingSymmetric(horizontal: 5.w),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({required String title, required String description, required bool isSelected, required VoidCallback onTap}) {
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
            const SizedBox(height: 2),
            Text(
              description,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.85), fontSize: 15, fontWeight: FontWeight.w400, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}
