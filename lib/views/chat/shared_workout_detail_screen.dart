import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:intl/intl.dart';

/// Read-only workout journal detail from chat [sharedContent].
class SharedWorkoutDetailScreen extends StatefulWidget {
  const SharedWorkoutDetailScreen({super.key, required this.data});

  final Map<String, dynamic> data;

  factory SharedWorkoutDetailScreen.fromArguments(dynamic args) {
    final map = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
    final data = map['sharedContent'] is Map ? Map<String, dynamic>.from(map['sharedContent'] as Map) : map;
    return SharedWorkoutDetailScreen(data: data);
  }

  @override
  State<SharedWorkoutDetailScreen> createState() => _SharedWorkoutDetailScreenState();
}

class _SharedWorkoutDetailScreenState extends State<SharedWorkoutDetailScreen> {
  bool _addingToCalendar = false;

  Map<String, dynamic> get data => widget.data;

  List<Map<String, dynamic>> get _exercises {
    final raw = data['workout'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String? _customerName() {
    final customer = data['customer'];
    if (customer is Map) {
      final profile = customer['profile'];
      if (profile is Map) {
        final name = profile['fullName']?.toString().trim();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _exerciseSetsForApi(Map<String, dynamic> workout) {
    final raw = workout['exercise'];
    if (raw is! List || raw.isEmpty) {
      return [
        {'sets': 1, 'reps': 10},
      ];
    }
    final sets = <Map<String, dynamic>>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map) continue;
      final set = Map<String, dynamic>.from(item);
      // Import structure only — no weight or rest time (recipient fills their own loads).
      sets.add({
        'sets': set['sets'] ?? (i + 1),
        if (set['reps'] != null) 'reps': set['reps'],
        if (set['distance'] != null) 'distance': set['distance'],
        if (set['time'] != null) 'time': set['time'],
      });
    }
    return sets.isEmpty
        ? [
            {'sets': 1, 'reps': 10},
          ]
        : sets;
  }

  String? _refExerciseId(Map<String, dynamic> workout) {
    final ref = workout['refExercise'];
    if (ref is Map) {
      final id = (ref['_id'] ?? ref['id'])?.toString();
      return WorkoutRepository.refExerciseForApi(id);
    }
    return WorkoutRepository.refExerciseForApi(ref?.toString());
  }

  Future<void> _addToCalendar() async {
    final exercises = _exercises;
    if (exercises.isEmpty) {
      Get.snackbar('Nothing to add', 'This shared workout has no exercises', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Add workout to calendar',
    );
    if (picked == null || !mounted) return;

    setState(() => _addingToCalendar = true);
    final repo = WorkoutRepository();
    final calendarRepo = CalendarRepository();
    final day = DateTime(picked.year, picked.month, picked.day);

    try {
      String? journalId = await repo.findWorkoutJournalIdForToday(date: day);
      for (final workout in exercises) {
        final name = workout['name']?.toString().trim().isNotEmpty == true ? workout['name'].toString().trim() : 'Exercise';
        final body = WorkoutRepository.createWorkoutBody(
          type: 'Workout',
          name: name,
          exercise: _exerciseSetsForApi(workout),
          refExercise: _refExerciseId(workout),
          workoutJournal: journalId,
          date: journalId == null ? WorkoutRepository.toJournalDate(day) : null,
          notes: 'Imported from shared workout',
        );
        final response = await repo.createWorkout(body);
        journalId ??= WorkoutRepository.journalIdFromCreateWorkout(response);
      }

      if (!WorkoutRepository.isValidMongoId(journalId)) {
        throw Exception('Could not create a journal for that day');
      }

      await calendarRepo.attachWorkoutJournalToCalendar(date: day, workoutJournalId: journalId!);
      if (!mounted) return;
      Get.snackbar(
        'Added to calendar',
        'Saved to ${DateFormat.MMMd().format(day)}',
        backgroundColor: AppColors.completed,
        colorText: AppColors.onError,
      );
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Could not add',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
      );
    } finally {
      if (mounted) setState(() => _addingToCalendar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = (data['duration'] as num?)?.toInt() ?? 0;
    final calories = (data['caloriesBurned'] as num?)?.toInt() ?? 0;
    final status = data['status']?.toString() ?? data['type']?.toString() ?? 'Workout';
    final dateRaw = data['date']?.toString();
    final date = dateRaw != null ? DateTime.tryParse(dateRaw) : null;
    final customerName = _customerName();
    final exercises = _exercises;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text('Shared Workout', style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (customerName != null) ...[
                  Text('Shared by $customerName', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
                  const SizedBox(height: 8),
                ],
                Text(status, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                if (date != null) ...[
                  const SizedBox(height: 4),
                  Text(DateFormat.yMMMMd().format(date.toLocal()), style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (duration > 0) _statChip(Icons.timer_outlined, CalendarRepository.formatDurationSeconds(duration)),
                    if (calories > 0) _statChip(Icons.local_fire_department, '$calories cal'),
                    _statChip(Icons.fitness_center, '${exercises.length} exercise${exercises.length == 1 ? '' : 's'}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Exercises', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No exercises in this workout.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark))),
            )
          else
            ...exercises.asMap().entries.map((entry) => _exerciseCard(entry.value, entry.key + 1)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _addingToCalendar ? null : _addToCalendar,
              icon: _addingToCalendar
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
                  : const Icon(Icons.calendar_today_outlined),
              label: Text(_addingToCalendar ? 'Adding…' : 'Add to Calendar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _exerciseCard(Map<String, dynamic> exercise, int order) {
    final name = exercise['name']?.toString().trim();
    final displayName = name != null && name.isNotEmpty ? name : 'Exercise $order';
    final sets = exercise['exercise'];
    final setList = sets is List ? sets.whereType<Map>().map((s) => Map<String, dynamic>.from(s)).toList() : <Map<String, dynamic>>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text('$order', style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(displayName, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w600))),
            ],
          ),
          if (setList.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...setList.asMap().entries.map((entry) {
              final set = entry.value;
              final setNum = (set['sets'] as num?)?.toInt() ?? entry.key + 1;
              final reps = set['reps']?.toString() ?? '—';
              final weight = set['weight']?.toString();
              final parts = <String>['Set $setNum', '$reps reps'];
              if (weight != null && weight.isNotEmpty) parts.add(weight == 'BW' ? 'Bodyweight' : '$weight kg');
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(parts.join(' · '), style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
              );
            }),
          ],
        ],
      ),
    );
  }
}
