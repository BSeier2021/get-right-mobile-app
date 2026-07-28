import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/workout_exercise_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

class ReorderExercisesScreen extends StatefulWidget {
  const ReorderExercisesScreen({super.key});
  @override
  State<ReorderExercisesScreen> createState() => _ReorderExercisesScreenState();
}

class _ReorderExercisesScreenState extends State<ReorderExercisesScreen> {
  List<WorkoutExerciseModel> _exercises = [];

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args['exercises'] != null) _exercises = List<WorkoutExerciseModel>.from(args['exercises']);
  }

  void _onReorder(int oldIdx, int newIdx) {
    setState(() {
      if (newIdx > oldIdx) newIdx--;
      final item = _exercises.removeAt(oldIdx);
      _exercises.insert(newIdx, item);
    });
  }

  void _onDone() => Get.back(result: {'exercises': _exercises});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text('Reorder Exercises', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
        centerTitle: true,
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ElevatedButton(onPressed: _onDone, style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)), child: Text('Done', style: AppTextStyles.buttonMedium)), Text('Drag to reorder', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark))])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [const Icon(Icons.fitness_center, color: AppColors.accent, size: 18), const SizedBox(width: 8), Text('Workout', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold))])),
        const SizedBox(height: 12),
        Expanded(child: ReorderableListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _exercises.length, onReorder: _onReorder, proxyDecorator: (child, idx, anim) => Material(elevation: 4, color: Colors.transparent, child: child), itemBuilder: (ctx, idx) {
          final ex = _exercises[idx];
          return Container(key: ValueKey(ex.id), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)), child: Row(children: [
            Container(padding: const EdgeInsets.all(16), child: Column(children: [Container(width: 24, height: 24, decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle), child: const Icon(Icons.check, color: AppColors.onAccent, size: 16)), const SizedBox(height: 8), const Icon(Icons.drag_indicator, color: AppColors.primaryGrayDark, size: 20)])),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(ex.exerciseName, style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)), const SizedBox(width: 8), const Icon(Icons.info_outline, color: AppColors.primaryGrayDark, size: 16), const Spacer(), const Icon(Icons.more_horiz, color: AppColors.primaryGrayDark, size: 20), const SizedBox(width: 16)]), const SizedBox(height: 8), Row(children: [Expanded(flex: 1, child: Text('Set', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark))), Expanded(flex: 2, child: Text('Reps', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark))), Expanded(flex: 2, child: Text('Weight', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark)))]), const SizedBox(height: 4), ...ex.sets.map((s) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [Expanded(flex: 1, child: Text('${s.setNumber}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface))), Expanded(flex: 2, child: Text('${s.reps ?? '-'}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface))), Expanded(flex: 2, child: Text(s.weight != null && s.weight! > 0 ? '${s.weight!.toInt()}' : '-', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)))])))]))),
          ]));
        })),
      ]),
    );
  }
}

