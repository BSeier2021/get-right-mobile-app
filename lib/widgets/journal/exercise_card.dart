import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

  // Get icon and color for exercise based on exercise name
  Map<String, dynamic> _getExerciseIconAndColor(String exerciseName) {
    final name = exerciseName.toLowerCase();

    if (name.contains('chest') || name.contains('bench') || name.contains('press') && !name.contains('overhead') && !name.contains('shoulder')) {
      return {'icon': Icons.fitness_center, 'color': AppColors.accent};
    } else if (name.contains('back') || name.contains('pull') || name.contains('row') || name.contains('lat')) {
      return {'icon': Icons.rowing, 'color': AppColors.completed};
    } else if (name.contains('squat') || name.contains('leg') || name.contains('quad') || name.contains('lunge')) {
      return {'icon': Icons.directions_run, 'color': AppColors.upcoming};
    } else if (name.contains('shoulder') || name.contains('overhead') || name.contains('press') && (name.contains('overhead') || name.contains('shoulder'))) {
      return {'icon': Icons.sports_mma, 'color': AppColors.accent};
    } else if (name.contains('core') || name.contains('plank') || name.contains('ab') || name.contains('crunch')) {
      return {'icon': Icons.self_improvement, 'color': AppColors.primaryGray};
    } else if (name.contains('bicep') || name.contains('curl')) {
      return {'icon': Icons.emoji_events, 'color': AppColors.upcoming};
    } else if (name.contains('tricep') || name.contains('extension') || name.contains('pushdown')) {
      return {'icon': Icons.local_fire_department, 'color': AppColors.error};
    } else if (name.contains('glute') || name.contains('hamstring') || name.contains('deadlift')) {
      return {'icon': Icons.directions_walk, 'color': AppColors.upcoming};
    } else {
      // Default icon and color
      return {'icon': Icons.fitness_center, 'color': AppColors.accent};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: widget.showBorder ? Border.all(color: AppColors.accent.withOpacity(0.3), width: 2) : null,
        boxShadow: widget.showBorder ? [BoxShadow(color: AppColors.accent.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7).copyWith(top: 10),
            child: Row(
              children: [
                Builder(
                  builder: (context) {
                    final iconData = _getExerciseIconAndColor(widget.exercise.exerciseName);
                    final icon = iconData['icon'] as IconData;
                    final color = iconData['color'] as Color;
                    return Container(
                      width: 40.w,
                      height: 40.h,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color.withOpacity(0.25), color.withOpacity(0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.25), width: 1),
                      ),
                      child: Center(child: Icon(icon, color: color, size: 22)),
                    );
                  },
                ),
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
            padding: EdgeInsets.all(10),
            margin: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              // border: widget.showBorder ? Border.all(color: AppColors.accent.withOpacity(0.3), width: 2) : null,
              boxShadow: widget.showBorder ? [BoxShadow(color: AppColors.accent.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))] : null,
            ),

            child: Column(
              children: [
                if (widget.exercise.sets.isNotEmpty) ...[_buildSetsTable(), const SizedBox(height: 6)],
                if (_isNotesExpanded && widget.exercise.notes != null && widget.exercise.notes!.isNotEmpty) _buildNotesSection(),
              ],
            ),
          ),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.settings, size: 12, color: AppColors.accentVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Set',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.exercise.hasTimedSets ? Icons.timer_outlined : Icons.repeat, size: 12, color: AppColors.accentVariant),
                        const SizedBox(width: 4),
                        Text(
                          widget.exercise.hasTimedSets ? 'Time' : 'Reps',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fitness_center, size: 12, color: AppColors.accentVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Weight',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 11),
                        ),
                      ],
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
