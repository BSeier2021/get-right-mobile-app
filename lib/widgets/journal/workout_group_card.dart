import 'package:flutter/material.dart';
import 'package:get_right/models/workout_exercise_model.dart';
import 'package:get_right/models/workout_group_type.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/journal/journal_exercise_card.dart';

/// Displays grouped exercises (superset or circuit) in the journal.
class WorkoutGroupCard extends StatelessWidget {
  const WorkoutGroupCard({
    super.key,
    required this.exercises,
    required this.groupType,
    this.onMenuTap,
    this.onTimerTap,
  });

  final List<WorkoutExerciseModel> exercises;
  final WorkoutGroupType groupType;
  final void Function(WorkoutExerciseModel exercise)? onMenuTap;
  final void Function(WorkoutExerciseModel exercise)? onTimerTap;

  String get _headerLabel => switch (groupType) {
        WorkoutGroupType.superset => 'SUPERSET',
        WorkoutGroupType.circuit => 'CIRCUIT',
        WorkoutGroupType.single => 'GROUP',
      };

  IconData get _headerIcon => switch (groupType) {
        WorkoutGroupType.superset => Icons.compare_arrows,
        WorkoutGroupType.circuit => Icons.loop,
        WorkoutGroupType.single => Icons.fitness_center,
      };

  @override
  Widget build(BuildContext context) {
    if (exercises.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 2),
        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Icon(_headerIcon, color: AppColors.onAccent, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _headerLabel,
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${exercises.length} exercises',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          for (var i = 0; i < exercises.length; i++) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(12, i == 0 ? 12 : 6, 12, i == exercises.length - 1 ? 12 : 6),
              child: JournalExerciseCard(
                embedded: true,
                index: i + 1,
                exercise: exercises[i],
                onMenuTap: onMenuTap != null ? () => onMenuTap!(exercises[i]) : null,
                onTimerTap: onTimerTap != null ? () => onTimerTap!(exercises[i]) : null,
              ),
            ),
            if (i < exercises.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.transparent, AppColors.accent.withValues(alpha: 0.3), Colors.transparent]),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
