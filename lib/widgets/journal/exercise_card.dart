import 'package:flutter/material.dart';
import 'package:get_right/models/workout_exercise_model.dart';
import 'package:get_right/models/exercise_set_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

class ExerciseCard extends StatefulWidget {
  final WorkoutExerciseModel exercise;
  final VoidCallback? onMenuTap;
  final VoidCallback? onTimerTap;
  final bool showBorder;

  const ExerciseCard({super.key, required this.exercise, this.onMenuTap, this.onTimerTap, this.showBorder = true});

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  bool _isNotesExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        // border: widget.showBorder ? Border.all(color: AppColors.accent.withOpacity(0.3), width: 2) : null,
        boxShadow: widget.showBorder ? [BoxShadow(color: AppColors.accent.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.exercise.exerciseName,
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.exercise.notes != null && widget.exercise.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _isNotesExpanded = !_isNotesExpanded),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(_isNotesExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: AppColors.primaryGrayDark),
                      ),
                    ),
                  ),
                if (widget.onMenuTap != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: GestureDetector(
                      onTap: widget.onMenuTap,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.more_horiz, size: 16, color: AppColors.primaryGrayDark),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.all(20),
 decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        // border: widget.showBorder ? Border.all(color: AppColors.accent.withOpacity(0.3), width: 2) : null,
        boxShadow: widget.showBorder ? [BoxShadow(color: AppColors.accent.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),


            child: Column(children: [

          if (widget.exercise.sets.isNotEmpty) ...[_buildSetsTable(), const SizedBox(height: 6)],
          if (_isNotesExpanded && widget.exercise.notes != null && widget.exercise.notes!.isNotEmpty) _buildNotesSection(),
      

            ],),
          )
        ],
      ),
    );
  }

  Widget _buildSetsTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Set',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 11),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.exercise.hasTimedSets ? 'Time' : 'Reps',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 11),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Weight',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...widget.exercise.sets.map((set) => _buildSetRow(set)),
        ],
      ),
    );
  }

  Widget _buildSetRow(ExerciseSetModel set) {
    final isLast = set.setNumber == widget.exercise.sets.length;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: AppColors.primaryGray.withOpacity(0.1), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '${set.setNumber}',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontSize: 12),
            ),
          ),
          Expanded(flex: 2, child: _buildRepsOrTime(set)),
          Expanded(flex: 2, child: _buildWeight(set)),
        ],
      ),
    );
  }

  Widget _buildRepsOrTime(ExerciseSetModel set) {
    if (set.isTimed) {
      final m = (set.timeSeconds! / 60).floor();
      final s = set.timeSeconds! % 60;
      final timeText = m > 0 ? (s > 0 ? '$m M $s S' : '$m M') : '$s S';
      return GestureDetector(
        onTap: widget.onTimerTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_outlined, size: 12, color: AppColors.accent),
            const SizedBox(width: 4),
            Text(timeText, style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontSize: 12)),
          ],
        ),
      );
    }
    if (set.isAMRAP)
      return Text(
        'AMRAP',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontSize: 12),
      );
    if (set.isFAILURE)
      return Text(
        'FAILURE',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontSize: 12),
      );
    return Text(
      '${set.reps ?? '-'}',
      textAlign: TextAlign.center,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontSize: 12),
    );
  }

  Widget _buildWeight(ExerciseSetModel set) {
    if (set.isBodyweight)
      return Text(
        'BW',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontSize: 12),
      );
    if (set.weight != null && set.weight! > 0)
      return Text(
        '${set.weight!.toInt()}',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontSize: 12),
      );
    return Text(
      '-',
      textAlign: TextAlign.center,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 12),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.primaryGrayLight.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
      child: Text(
        widget.exercise.notes!,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontStyle: FontStyle.italic, fontSize: 11),
      ),
    );
  }
}
