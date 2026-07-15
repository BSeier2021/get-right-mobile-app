import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:intl/intl.dart';

/// Read-only workout journal detail from chat [sharedContent].
class SharedWorkoutDetailScreen extends StatelessWidget {
  const SharedWorkoutDetailScreen({super.key, required this.data});

  final Map<String, dynamic> data;

  factory SharedWorkoutDetailScreen.fromArguments(dynamic args) {
    final map = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
    final data = map['sharedContent'] is Map ? Map<String, dynamic>.from(map['sharedContent'] as Map) : map;
    return SharedWorkoutDetailScreen(data: data);
  }

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
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () {
            Get.back();
          },
        ),
        title: Text('Shared Workout', style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
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
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
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
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
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
              final rest = (set['restTime'] as num?)?.toInt();
              final parts = <String>['Set $setNum', '$reps reps'];
              if (weight != null && weight.isNotEmpty) parts.add(weight == 'BW' ? 'Bodyweight' : '$weight kg');
              if (rest != null && rest > 0) parts.add('${rest}s rest');
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
