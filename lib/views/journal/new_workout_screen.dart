import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/utils/journal_flow.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

const Color _kScreenBg = Color(0xFFFAFFEF);
const Color _kCardBg = Color(0xFFFFFFFF);
const Color _kIconCircle = Color(0xFFE8F0E4);
const Color _kMutedText = Color(0xFF6B7A6E);
const Color _kDivider = Color(0xFFE2E8DE);

/// Entry screen for starting a workout from the journal "+" button.
/// UI-first — Build Workout reuses the existing add-exercise save path.
class NewWorkoutScreen extends StatelessWidget {
  const NewWorkoutScreen({super.key});

  JournalFlowContext get _flowContext => JournalFlowContext.fromArgs(_args);

  Map<String, dynamic> get _args => (Get.arguments as Map<String, dynamic>?) ?? {};

  Future<void> _onBuildWorkout() async {
    final result = await JournalFlowNavigator.openExerciseLibrary(_flowContext);
    JournalFlowNavigator.bubbleResult(result);
  }

  void _onCopyPrevious() {
    Get.snackbar(
      'Coming soon',
      'Copy previous workout will be available in a later update.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.accent.withValues(alpha: 0.92),
      colorText: AppColors.onAccent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kScreenBg,
      appBar: AppBar(
        backgroundColor: _kScreenBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 20.sp),
        ),
        title: Text(
          'NEW WORKOUT',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            fontSize: 14.sp,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
          child: Column(
            children: [
              SizedBox(height: 24.h),
              Container(
                width: 96.w,
                height: 96.w,
                decoration: BoxDecoration(
                  color: _kIconCircle,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(Icons.fitness_center, color: AppColors.accent, size: 40.sp),
              ),
              SizedBox(height: 28.h),
              Text(
                'How would you like to start?',
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Choose an option below to create your first workout.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: _kMutedText, height: 1.4),
              ),
              SizedBox(height: 32.h),
              _OptionCard(
                icon: Icons.add,
                title: 'Build Workout',
                subtitle: 'Add exercises one at a time and build your workout from scratch.',
                onTap: _onBuildWorkout,
              ),
              SizedBox(height: 14.h),
              _OptionCard(
                icon: Icons.copy_outlined,
                title: 'Copy Previous Workout',
                subtitle: 'Choose from your previous workouts and copy one to get started.',
                onTap: _onCopyPrevious,
              ),
              const Spacer(),
              Divider(color: _kDivider, height: 1),
              SizedBox(height: 16.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: AppColors.accent, size: 20.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Tip: ',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: 'You can always edit or add exercises later if you forget something.',
                            style: AppTextStyles.bodySmall.copyWith(color: _kMutedText, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: const BoxDecoration(color: _kIconCircle, shape: BoxShape.circle),
                  child: Icon(icon, color: AppColors.accent, size: 22.sp),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(color: _kMutedText, height: 1.35),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(Icons.chevron_right, color: AppColors.accent, size: 24.sp),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
