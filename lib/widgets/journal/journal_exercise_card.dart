import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_right/models/workout_exercise_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/journal/journal_exercise_formatting.dart';
import 'package:get_right/widgets/journal/journal_exercise_set_list.dart';

const Color _kCardBg = Color(0xFFFFFFFF);
const Color _kCardBorder = Color(0xFFE8EBDC);
const Color _kMutedText = Color(0xFF6B7A6E);

/// Collapsible exercise row for the workout journal (mockup style).
class JournalExerciseCard extends StatefulWidget {
  const JournalExerciseCard({
    super.key,
    required this.exercise,
    required this.index,
    this.embedded = false,
    this.onMenuTap,
    this.onTimerTap,
  });

  final WorkoutExerciseModel exercise;
  final int index;
  final bool embedded;
  final VoidCallback? onMenuTap;
  final VoidCallback? onTimerTap;

  static String summaryFor(WorkoutExerciseModel exercise) => JournalExerciseFormatting.summaryFor(exercise);

  @override
  State<JournalExerciseCard> createState() => _JournalExerciseCardState();
}

class _JournalExerciseCardState extends State<JournalExerciseCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final summary = JournalExerciseFormatting.summaryFor(exercise);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(widget.embedded ? 12 : 16),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 8.w, 14.h),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.exerciseName,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!_expanded) ...[
                        SizedBox(height: 4.h),
                        Text(
                          summary,
                          style: AppTextStyles.bodySmall.copyWith(color: _kMutedText),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.accent,
                    size: 26.sp,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.w),
                  tooltip: _expanded ? 'Collapse' : 'Expand',
                ),
                if (widget.onMenuTap != null)
                  IconButton(
                    onPressed: widget.onMenuTap,
                    icon: Icon(Icons.more_horiz_rounded, color: AppColors.accent, size: 24.sp),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.w),
                  ),
              ],
            ),
          ),
        ),
        if (_expanded) JournalExerciseSetList(exercise: exercise),
      ],
    );

    if (widget.embedded) return content;

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: content,
    );
  }
}
