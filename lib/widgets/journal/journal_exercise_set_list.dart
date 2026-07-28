import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_right/models/workout_exercise_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/journal/journal_exercise_formatting.dart';

const Color _kCardBorder = Color(0xFFE8EBDC);
const Color _kHeaderBg = Color(0xFFF4F7EE);
const Color _kMutedText = Color(0xFF6B7A6E);

/// Expanded set table shown when a journal exercise card is open.
class JournalExerciseSetList extends StatelessWidget {
  const JournalExerciseSetList({
    super.key,
    required this.exercise,
    this.showTopDivider = true,
  });

  final WorkoutExerciseModel exercise;
  final bool showTopDivider;

  static const double _setColWidth = 44;

  @override
  Widget build(BuildContext context) {
    if (exercise.sets.isEmpty) return const SizedBox.shrink();

    final mainLabel = JournalExerciseFormatting.mainColumnLabel(exercise);
    final extraLabel = JournalExerciseFormatting.secondaryColumnLabel(exercise);
    final sets = exercise.sets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTopDivider) Divider(height: 1, color: _kCardBorder),
        Padding(
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 14.h),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: _kCardBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Column(
                children: [
                  _HeaderRow(mainLabel: mainLabel, extraLabel: extraLabel),
                  for (var i = 0; i < sets.length; i++)
                    _SetRow(
                      setNumber: sets[i].setNumber,
                      mainValue: JournalExerciseFormatting.mainCellValue(sets[i]),
                      extraValue: JournalExerciseFormatting.secondaryCellValue(sets[i], exercise),
                      showDivider: i < sets.length - 1,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.mainLabel, required this.extraLabel});

  final String mainLabel;
  final String extraLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
      color: _kHeaderBg,
      child: Row(
        children: [
          _columnHeader('Set', width: JournalExerciseSetList._setColWidth.w),
          _columnHeader(mainLabel, expanded: true),
          _columnHeader(extraLabel, expanded: true),
        ],
      ),
    );
  }

  Widget _columnHeader(String label, {double? width, bool expanded = false}) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: AppTextStyles.labelSmall.copyWith(
        color: _kMutedText,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
    if (width != null) return SizedBox(width: width, child: text);
    return Expanded(child: text);
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.setNumber,
    required this.mainValue,
    required this.extraValue,
    required this.showDivider,
  });

  final int setNumber;
  final String mainValue;
  final String extraValue;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 11.h),
          child: Row(
            children: [
              SizedBox(
                width: JournalExerciseSetList._setColWidth.w,
                child: Center(
                  child: Container(
                    width: 28.w,
                    height: 28.w,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$setNumber',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  mainValue,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  extraValue,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: extraValue == '—' ? _kMutedText : AppColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, thickness: 1, color: _kCardBorder),
      ],
    );
  }
}
