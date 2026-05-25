import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/utils.dart';
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

  // Fallback local asset and accent color when no network icon is available.
  Map<String, dynamic> _getExerciseAssetAndColor(String exerciseName) {
    final name = exerciseName.toLowerCase();

    if (name.contains('chest') || (name.contains('bench') && !name.contains('overhead'))) {
      return {'asset': 'assets/images/1. bench press.png', 'color': AppColors.accent};
    }
    if (name.contains('back') || name.contains('lat') || name.contains('row') || name.contains('pull')) {
      return {'asset': 'assets/images/8. lat pulldown.png', 'color': AppColors.completed};
    }
    if (name.contains('shoulder') || name.contains('overhead')) {
      return {'asset': 'assets/images/4. overhead press.png', 'color': AppColors.accent};
    }
    if (name.contains('quad') || name.contains('squat') || (name.contains('leg') && !name.contains('ham'))) {
      return {'asset': 'assets/images/2. squat.png', 'color': AppColors.upcoming};
    }
    if (name.contains('hamstring') || name.contains('deadlift')) {
      return {'asset': 'assets/images/3. deadlift.png', 'color': AppColors.upcoming};
    }
    if (name.contains('tricep') || name.contains('pushdown') || name.contains('extension')) {
      return {'asset': 'assets/images/10. tricep pushdown.png', 'color': AppColors.error};
    }
    if (name.contains('bicep') || name.contains('curl')) {
      return {'asset': 'assets/images/9.  dumbell curl.png', 'color': AppColors.upcoming};
    }
    if (name.contains('core') || name.contains('abs') || name.contains('plank') || name.contains('crunch')) {
      return {'asset': 'assets/images/6. plank.png', 'color': AppColors.primaryGray};
    }
    if (name.contains('glute') || name.contains('lunge')) {
      return {'asset': 'assets/images/11. lunges.png', 'color': AppColors.upcoming};
    }
    if (name.contains('calf') || name.contains('calves') || name.contains('leg press')) {
      return {'asset': 'assets/images/12. Leg press.png', 'color': AppColors.upcoming};
    }
    return {'asset': 'assets/images/dumbles.png', 'color': AppColors.accent};
  }

  Widget _buildExerciseIcon(String exerciseName, String? iconUrl, Color color) {
    if (iconUrl != null && iconUrl.isNotEmpty) {
      return Image.network(
        iconUrl,
        width: 26.w,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildAssetIcon(exerciseName, color),
      );
    }
    return _buildAssetIcon(exerciseName, color);
  }

  Widget _buildAssetIcon(String exerciseName, Color color) {
    final asset = _getExerciseAssetAndColor(exerciseName)['asset'] as String;
    return Image.asset(
      asset,
      width: 26.w,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.fitness_center, size: 20.w, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
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
                    final data = _getExerciseAssetAndColor(widget.exercise.exerciseName);
                    final Color color = data['color'] as Color;
                    return Container(
                      width: 40.w,
                      height: 40.h,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color.withOpacity(0.25), color.withOpacity(0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: color.withOpacity(0.25), width: 1),
                      ),
                      child: Center(
                        child: _buildExerciseIcon(widget.exercise.exerciseName, widget.exercise.iconUrl, color),
                      ).paddingSymmetric(horizontal: 4, vertical: 4),
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
              color: AppColors.white,
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
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
                    margin: EdgeInsets.only(right: 10),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/sets.png', width: 15.w),
                        const SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Set',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.black, fontSize: 13.sp),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/reps.png', width: 15.w),
                        const SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.exercise.hasTimedSets ? 'Time' : 'Reps',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.black, fontSize: 13.sp),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 10),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/weight.png', width: 13.w),
                        const SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Weight',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.black, fontSize: 13.sp),
                            ),
                          ),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${set.setNumber}',
            textAlign: TextAlign.left,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontSize: 12),
          ),
          _buildRepsOrTime(set),
          _buildWeight(set),
        ],
      ).paddingSymmetric(horizontal: 30),
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
      decoration: BoxDecoration(color: AppColors.primaryGrayLight.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
      child: Text(
        widget.exercise.notes!,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontStyle: FontStyle.italic, fontSize: 11),
      ),
    );
  }
}
