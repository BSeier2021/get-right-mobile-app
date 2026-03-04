import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/workout_exercise_model.dart';
import 'package:get_right/models/exercise_set_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

class WorkoutTimerScreen extends StatefulWidget {
  const WorkoutTimerScreen({super.key});

  @override
  State<WorkoutTimerScreen> createState() => _WorkoutTimerScreenState();
}

class _WorkoutTimerScreenState extends State<WorkoutTimerScreen> {
  WorkoutExerciseModel? _exercise;
  List<ExerciseSetModel> _timedSets = [];
  Map<int, Timer?> _timers = {};
  Map<int, int> _currentSeconds = {};
  Map<int, int> _initialSeconds = {};
  Map<int, bool> _isRunning = {};

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args['exercise'] != null) {
      _exercise = args['exercise'] as WorkoutExerciseModel;
      _timedSets = _exercise!.timedSets;
      for (var i = 0; i < _timedSets.length; i++) {
        final set = _timedSets[i];
        _currentSeconds[i] = set.timeSeconds ?? 0;
        _initialSeconds[i] = set.timeSeconds ?? 0;
        _isRunning[i] = false;
      }
    }
  }

  @override
  void dispose() {
    for (var timer in _timers.values) {
      timer?.cancel();
    }
    super.dispose();
  }

  void _startTimer(int setIndex) {
    if (_currentSeconds[setIndex]! <= 0) {
      _currentSeconds[setIndex] = _initialSeconds[setIndex]!;
    }
    setState(() => _isRunning[setIndex] = true);
    _timers[setIndex] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSeconds[setIndex]! > 0) {
        setState(() => _currentSeconds[setIndex] = _currentSeconds[setIndex]! - 1);
      } else {
        _timers[setIndex]?.cancel();
        setState(() => _isRunning[setIndex] = false);
        _showCompletionDialog(setIndex);
      }
    });
  }

  void _pauseTimer(int setIndex) {
    _timers[setIndex]?.cancel();
    setState(() => _isRunning[setIndex] = false);
  }

  void _resetTimer(int setIndex) {
    _timers[setIndex]?.cancel();
    setState(() {
      _currentSeconds[setIndex] = _initialSeconds[setIndex]!;
      _isRunning[setIndex] = false;
    });
  }

  void _showCompletionDialog(int setIndex) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: AppColors.accent, size: 48),
              ),
              const SizedBox(height: 20),
              Text(
                'Time\'s Up!',
                style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('Set ${setIndex + 1} completed', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Done', style: AppTextStyles.buttonMedium),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildSetTimerCard(int setIndex) {
    final isRunning = _isRunning[setIndex] ?? false;
    final currentSeconds = _currentSeconds[setIndex] ?? 0;
    final initialSeconds = _initialSeconds[setIndex] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isRunning ? AppColors.accent : AppColors.primaryGray.withOpacity(0.3), width: isRunning ? 2 : 1),
        boxShadow: [BoxShadow(color: isRunning ? AppColors.accent.withOpacity(0.2) : Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Set ${setIndex + 1}',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  _formatTime(initialSeconds),
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isRunning ? AppColors.accent : AppColors.primaryGray, width: 3),
              ),
              child: Center(
                child: Text(
                  _formatTime(currentSeconds),
                  style: TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.bold, color: isRunning ? AppColors.accent : AppColors.onSurface),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!isRunning)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _startTimer(setIndex),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: Text('Start Timer', style: AppTextStyles.buttonMedium),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _pauseTimer(setIndex),
                      icon: const Icon(Icons.pause, size: 20),
                      label: const Text('Pause'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.accent, width: 2),
                        foregroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _resetTimer(setIndex),
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Reset'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryGray, width: 2),
                        foregroundColor: AppColors.onBackground,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_exercise == null || _timedSets.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onBackground,
          title: Text('Timer', style: AppTextStyles.titleLarge.copyWith()),
        ),
        body: Center(
          child: Text('No timed sets available', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent),
          onPressed: () => Get.back(),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Timer', style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent)),
            const SizedBox(width: 3),
            Text(
              _exercise!.exerciseName,
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [const SizedBox(height: 16), ...List.generate(_timedSets.length, (index) => _buildSetTimerCard(index)), const SizedBox(height: 24)],
        ),
      ),
    );
  }
}
