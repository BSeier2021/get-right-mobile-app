import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/journal/workout_celebration_screen.dart';
import 'package:intl/intl.dart';

class ProgramWorkoutScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String? calendarEntryId;
  final String? workoutJournalId;
  final String programTitle;
  final String status;
  final int caloriesBurned;
  final int? dayNumber;
  final int? existingDurationSeconds;
  final List<Map<String, dynamic>> exercises;

  const ProgramWorkoutScreen({
    super.key,
    required this.selectedDate,
    this.calendarEntryId,
    this.workoutJournalId,
    required this.programTitle,
    required this.status,
    required this.caloriesBurned,
    this.dayNumber,
    this.existingDurationSeconds,
    required this.exercises,
  });

  factory ProgramWorkoutScreen.fromArguments(dynamic args) {
    final map = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
    final program = map['program'] is Map ? Map<String, dynamic>.from(map['program'] as Map) : <String, dynamic>{};
    final rawDate = map['selectedDate'];
    final date = rawDate is DateTime
        ? rawDate
        : (rawDate is String ? DateTime.tryParse(rawDate) : null) ?? DateTime.now();
    final exercises = program['exercises'] is List
        ? (program['exercises'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    return ProgramWorkoutScreen(
      selectedDate: DateTime(date.year, date.month, date.day),
      calendarEntryId: map['calendarEntryId']?.toString(),
      workoutJournalId: map['workoutJournalId']?.toString(),
      programTitle: program['title']?.toString() ?? 'Program Workout',
      status: program['status']?.toString().toLowerCase() ?? 'incomplete',
      caloriesBurned: (program['caloriesBurned'] as num?)?.toInt() ?? (map['caloriesBurned'] as num?)?.toInt() ?? 0,
      dayNumber: (program['dayNumber'] as num?)?.toInt() ?? (program['currentDayNumber'] as num?)?.toInt(),
      existingDurationSeconds: (map['durationSeconds'] as num?)?.toInt(),
      exercises: exercises,
    );
  }

  @override
  State<ProgramWorkoutScreen> createState() => _ProgramWorkoutScreenState();
}

class _ProgramWorkoutScreenState extends State<ProgramWorkoutScreen> {
  final CalendarRepository _calendarRepo = CalendarRepository();
  final WorkoutRepository _workoutRepo = WorkoutRepository();

  Timer? _timer;
  int _seconds = 0;
  int _calories = 0;
  bool _isStarted = false;
  bool _isPaused = false;
  bool _isSaving = false;

  bool get _isCompleted => widget.status == 'completed';

  @override
  void initState() {
    super.initState();
    if (widget.existingDurationSeconds != null && widget.existingDurationSeconds! > 0) {
      _seconds = widget.existingDurationSeconds!;
      _calories = widget.caloriesBurned > 0 ? widget.caloriesBurned : (_seconds / 60 * 5).round();
    } else if (widget.caloriesBurned > 0) {
      _calories = widget.caloriesBurned;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startWorkout() {
    if (_isCompleted) {
      Get.snackbar('Workout completed', 'This program workout is already marked complete.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() {
      _isStarted = true;
      _isPaused = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused && mounted) {
        setState(() {
          _seconds++;
          _calories = (_seconds / 60 * 5).round();
        });
      }
    });
  }

  void _pauseWorkout() => setState(() => _isPaused = true);

  void _resumeWorkout() => setState(() => _isPaused = false);

  void _stopWorkout() {
    _timer?.cancel();
    setState(() {
      _isStarted = false;
      _isPaused = false;
    });
    _completeWorkout(_seconds);
  }

  String _formatTime(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  String _formatProgramRest(dynamic rest) {
    final seconds = rest is num ? rest.toInt() : int.tryParse(rest?.toString() ?? '');
    if (seconds == null || seconds <= 0) return '';
    if (seconds >= 60) {
      final m = seconds ~/ 60;
      final s = seconds % 60;
      return s > 0 ? '${m}m ${s}s rest' : '${m}m rest';
    }
    return '${seconds}s rest';
  }

  Future<void> _showManualDurationDialog() async {
    if (_isCompleted || _isSaving) return;

    final hoursController = TextEditingController(text: '0');
    final minutesController = TextEditingController(text: _seconds > 0 ? '${_seconds ~/ 60}' : '');
    final secondsController = TextEditingController(text: _seconds > 0 ? '${_seconds % 60}' : '0');

    final confirmed = await Get.dialog<bool>(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter Duration', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Set how long your workout took to mark it complete.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _durationField(hoursController, 'Hours')),
                  const SizedBox(width: 8),
                  Expanded(child: _durationField(minutesController, 'Min')),
                  const SizedBox(width: 8),
                  Expanded(child: _durationField(secondsController, 'Sec')),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Get.back(result: true),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.onAccent),
                      child: const Text('Mark Complete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final hours = int.tryParse(hoursController.text.trim()) ?? 0;
    final minutes = int.tryParse(minutesController.text.trim()) ?? 0;
    final secs = int.tryParse(secondsController.text.trim()) ?? 0;
    final totalSeconds = (hours * 3600) + (minutes * 60) + secs;

    if (totalSeconds <= 0) {
      Get.snackbar('Invalid duration', 'Enter a duration greater than zero', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }

    _timer?.cancel();
    setState(() {
      _seconds = totalSeconds;
      _calories = (totalSeconds / 60 * 5).round();
      _isStarted = false;
      _isPaused = false;
    });
    await _completeWorkout(totalSeconds);
  }

  Widget _durationField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Future<void> _completeWorkout(int durationSeconds) async {
    if (_isSaving) return;
    if (durationSeconds < 1) {
      Get.snackbar('Duration required', 'Workout must be at least 1 second to mark complete.', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final journalId = widget.workoutJournalId;
      final linkedJournalId = WorkoutRepository.isValidMongoId(journalId) ? journalId : null;

      // Program calendar entries require duration under `program.duration`.
      if (WorkoutRepository.isValidMongoId(widget.calendarEntryId)) {
        await _calendarRepo.completeProgramWorkoutOnCalendar(
          calendarEntryId: widget.calendarEntryId!,
          durationSeconds: durationSeconds,
          caloriesBurned: _calories > 0 ? _calories : null,
          workoutJournalId: linkedJournalId,
        );
      } else {
        await _calendarRepo.createCalendarEntry(
          date: widget.selectedDate,
          type: CalendarRepository.typeCompleted,
          durationInSeconds: durationSeconds,
          workoutJournal: linkedJournalId,
        );
      }

      if (linkedJournalId != null) {
        await _workoutRepo.completeWorkoutJournal(journalId: linkedJournalId, duration: durationSeconds);
      }

      if (!mounted) return;

      final exerciseCount = widget.exercises.length;
      final workoutName = '$exerciseCount Exercise${exerciseCount == 1 ? '' : 's'}';

      await Get.to(
        () => WorkoutCelebrationScreen(
          duration: _formatTime(durationSeconds),
          calories: _calories,
          workoutName: workoutName,
          workoutJournalId: linkedJournalId,
        ),
        transition: Transition.zoom,
        duration: const Duration(milliseconds: 500),
      );

      if (mounted) Get.back(result: true);
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  (Color, String) _statusStyle() {
    switch (widget.status) {
      case 'completed':
        return (const Color(0xFF6FCF97), 'Completed');
      case 'incomplete':
        return (const Color(0xFFE74C3C), 'Incomplete');
      case 'inprogress':
        return (AppColors.accent, 'In Progress');
      default:
        return (AppColors.accent, widget.status.isNotEmpty ? widget.status[0].toUpperCase() + widget.status.substring(1) : 'Scheduled');
    }
  }

  Widget _buildExerciseTile(Map<String, dynamic> ex, int order) {
    final name = (ex['exerciseName'] ?? ex['name'])?.toString().trim();
    final displayName = name != null && name.isNotEmpty ? name : 'Exercise $order';
    final sets = ex['numberOfSets'] ?? ex['sets'];
    final reps = ex['numberOfReps'] ?? ex['reps'];
    final rest = _formatProgramRest(ex['restSeconds'] ?? ex['restTime']);
    final description = (ex['exerciseDescription'] ?? ex['description'])?.toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text('$order', style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(displayName, style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (sets != null || reps != null || rest.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (sets != null) _metricChip(Icons.repeat, '$sets sets'),
                if (reps != null) _metricChip(Icons.fitness_center, '$reps reps'),
                if (rest.isNotEmpty) _metricChip(Icons.timer_outlined, rest),
              ],
            ),
          ],
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _metricChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMetricsBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.backgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isSaving ? null : _stopWorkout,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.stop, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isPaused ? _resumeWorkout : _pauseWorkout,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: _isPaused ? AppColors.accent : Colors.orange, shape: BoxShape.circle),
              child: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppColors.primaryGrayLight.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: AppColors.accent, size: 16),
                      const SizedBox(width: 4),
                      Text(_formatTime(_seconds), style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  // Row(
                  //   children: [
                  //     const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                  //     const SizedBox(width: 4),
                  //     Text('$_calories', style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                  //   ],
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = _statusStyle();
    final dateLabel = DateFormat.yMMMMd().format(widget.selectedDate);
    final dayLabel = widget.dayNumber != null && widget.dayNumber! > 0 ? 'Day ${widget.dayNumber}' : null;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withOpacity(0.15), width: 1),
            ),
            child: const Icon(Icons.chevron_left, color: AppColors.accent, size: 20),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          widget.programTitle,
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateLabel, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
                    if (dayLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(dayLabel, style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                          child: Text(statusLabel, style: AppTextStyles.labelSmall.copyWith(color: statusColor, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
                        // if (_calories > 0 || widget.caloriesBurned > 0)
                        //   Container(
                        //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        //     decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                        //     child: Row(
                        //       mainAxisSize: MainAxisSize.min,
                        //       children: [
                        //         const Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                        //         const SizedBox(width: 4),
                        //         Text(
                        //           '${_calories > 0 ? _calories : widget.caloriesBurned} cal',
                        //           style: AppTextStyles.labelSmall.copyWith(color: Colors.orange, fontWeight: FontWeight.w600),
                        //         ),
                        //       ],
                        //     ),
                        //   ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_isStarted) _buildMetricsBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    Text('Exercises', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    if (widget.exercises.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No exercises listed for this day.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark)),
                        ),
                      )
                    else
                      ...widget.exercises.asMap().entries.map((e) => _buildExerciseTile(e.value, e.key + 1)),
                  ],
                ),
              ),
              if (!_isStarted)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isCompleted)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.completed.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.completed.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, color: AppColors.completed, size: 18),
                              const SizedBox(width: 8),
                              Text('Workout completed', style: AppTextStyles.labelMedium.copyWith(color: AppColors.completed, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: (_isCompleted || _isSaving) ? null : _startWorkout,
                          icon: const Icon(Icons.play_arrow),
                          label: Text('Start Workout', style: AppTextStyles.buttonMedium),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.onAccent,
                            disabledBackgroundColor: AppColors.primaryGrayLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: (_isCompleted || _isSaving) ? null : _showManualDurationDialog,
                          icon: const Icon(Icons.edit_calendar, size: 18),
                          label: Text('Enter Duration Manually', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.accent)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            side: BorderSide(color: AppColors.accent.withOpacity(0.7)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_isSaving)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            ),
        ],
      ),
    );
  }
}
