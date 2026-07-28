import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/models/exercise_library_model.dart';
import 'package:get_right/models/workout_group_type.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/gr_catalog_image.dart';
import 'package:get_right/widgets/safe_network_image.dart';

const Color _kScreenBg = Color(0xFFFAFFEF);
const Color _kCardBg = Color(0xFFFFFFFF);
const Color _kCardBorder = Color(0xFFE2EBD8);
const Color _kSelectedBg = Color(0xFFEEF6E8);
const Color _kSelectedBorder = Color(0xFF2D5A3D);
const Color _kMutedText = Color(0xFF6B7A6E);
const Color _kContinueBg = Color(0xFFC5D4BC);

/// Lets the user choose how to add a selected exercise: regular, superset, or circuit.
class AddToWorkoutScreen extends StatefulWidget {
  const AddToWorkoutScreen({super.key});

  @override
  State<AddToWorkoutScreen> createState() => _AddToWorkoutScreenState();
}

class _AddToWorkoutScreenState extends State<AddToWorkoutScreen> {
  WorkoutGroupType _selectedType = WorkoutGroupType.single;

  Map<String, dynamic> get _args => (Get.arguments as Map<String, dynamic>?) ?? {};

  ExerciseLibraryModel? get _exercise {
    final raw = _args['exercise'];
    if (raw is ExerciseLibraryModel) return raw;
    return null;
  }

  Map<String, dynamic> get _journalContext {
    return {
      if (_args['workoutJournalId'] != null) 'workoutJournalId': _args['workoutJournalId'],
      if (_args['journalWorkoutIds'] != null) 'journalWorkoutIds': _args['journalWorkoutIds'],
      if (_args['addedExerciseIds'] != null) 'addedExerciseIds': _args['addedExerciseIds'],
      if (_args['journalDay'] != null) 'journalDay': _args['journalDay'],
      if (_args['exerciseType'] != null) 'exerciseType': _args['exerciseType'],
      'journalFlow': true,
    };
  }

  Future<void> _onContinue() async {
    final exercise = _exercise;
    if (exercise == null) {
      Get.snackbar('Missing exercise', 'Please go back and select an exercise again.', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }

    switch (_selectedType) {
      case WorkoutGroupType.single:
        final result = await Get.toNamed(
          AppRoutes.exerciseConfiguration,
          arguments: {
            ..._journalContext,
            'workoutGroupType': WorkoutGroupType.single.apiValue,
            'isSuperset': false,
            'exercise': exercise,
          },
        );
        if (result != null) Get.back(result: result);
        break;
      case WorkoutGroupType.superset:
      case WorkoutGroupType.circuit:
        final result = await Get.toNamed(
          AppRoutes.exerciseSelection,
          arguments: {
            ..._journalContext,
            'pickAdditional': true,
            'workoutGroupType': _selectedType.apiValue,
            'preselected': [exercise],
            'requiredTotal': _selectedType.minExercises,
          },
        );
        if (result != null) Get.back(result: result);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = _exercise;

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
          'ADD TO WORKOUT',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            fontSize: 14.sp,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (exercise != null) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 20.h),
                child: _SelectedExerciseCard(exercise: exercise),
              ),
            ],
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Text(
                'ADD AS…',
                style: AppTextStyles.labelSmall.copyWith(
                  color: _kMutedText,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
                children: [
                  _GroupOptionCard(
                    type: WorkoutGroupType.single,
                    selected: _selectedType == WorkoutGroupType.single,
                    onTap: () => setState(() => _selectedType = WorkoutGroupType.single),
                  ),
                  SizedBox(height: 12.h),
                  _GroupOptionCard(
                    type: WorkoutGroupType.superset,
                    selected: _selectedType == WorkoutGroupType.superset,
                    onTap: () => setState(() => _selectedType = WorkoutGroupType.superset),
                  ),
                  SizedBox(height: 12.h),
                  _GroupOptionCard(
                    type: WorkoutGroupType.circuit,
                    selected: _selectedType == WorkoutGroupType.circuit,
                    onTap: () => setState(() => _selectedType = WorkoutGroupType.circuit),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
              child: SizedBox(
                width: double.infinity,
                height: 54.h,
                child: ElevatedButton(
                  onPressed: exercise == null ? null : _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kContinueBg,
                    foregroundColor: AppColors.accent,
                    disabledBackgroundColor: _kContinueBg.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: Text(
                    'Continue',
                    style: AppTextStyles.buttonLarge.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedExerciseCard extends StatelessWidget {
  const _SelectedExerciseCard({required this.exercise});

  final ExerciseLibraryModel exercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0E4),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildIcon(),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              exercise.name,
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    final iconUrl = exercise.iconUrl;
    if (iconUrl != null && iconUrl.isNotEmpty) {
      if (iconUrl.startsWith('assets/')) {
        return GrCatalogImage(assetPath: iconUrl, borderRadius: 12, scale: 1.08);
      }
      return SafeNetworkImage(
        url: iconUrl,
        fit: BoxFit.contain,
        fallback: Icon(Icons.fitness_center, color: AppColors.accent, size: 22.sp),
      );
    }
    return Icon(Icons.fitness_center, color: AppColors.accent, size: 22.sp);
  }
}

class _GroupOptionCard extends StatelessWidget {
  const _GroupOptionCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final WorkoutGroupType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? _kSelectedBg : _kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? _kSelectedBorder : _kCardBorder, width: selected ? 1.5 : 1),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.label,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        type.subtitle,
                        style: AppTextStyles.bodySmall.copyWith(color: _kMutedText, height: 1.35),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  width: 24.w,
                  height: 24.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.accent : Colors.transparent,
                    border: Border.all(color: selected ? AppColors.accent : _kMutedText.withValues(alpha: 0.45), width: 2),
                  ),
                  child: selected ? Icon(Icons.check, color: AppColors.onAccent, size: 16.sp) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
