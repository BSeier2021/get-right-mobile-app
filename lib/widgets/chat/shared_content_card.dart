import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/shared_content_model.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/repo/running_log_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:get_right/widgets/safe_network_image.dart';
import 'package:intl/intl.dart';

/// Renders populated `message.sharedContent` by [type].
class SharedContentCard extends StatefulWidget {
  const SharedContentCard({
    super.key,
    required this.type,
    required this.data,
    this.isCurrentUser = false,
  });

  final SharedContentType type;
  final Map<String, dynamic> data;
  final bool isCurrentUser;

  @override
  State<SharedContentCard> createState() => _SharedContentCardState();
}

class _SharedContentCardState extends State<SharedContentCard> {
  bool _addingToCalendar = false;

  SharedContentType get type => widget.type;
  Map<String, dynamic> get data => widget.data;
  bool get isCurrentUser => widget.isCurrentUser;

  @override
  Widget build(BuildContext context) {
    if (type == SharedContentType.workoutJournal) {
      return _buildWorkoutShareCard(context);
    }
    return _buildGenericCard(context);
  }

  Widget _buildWorkoutShareCard(BuildContext context) {
    final title = _workoutTitle();
    final subtitle = _workoutSubtitle();
    final imageUrl = _imageUrl();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(Icons.link_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  'Shared Workout',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl != null
                      ? SafeNetworkImage(
                          url: imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          fallback: _workoutThumbFallback(),
                        )
                      : _workoutThumbFallback(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () => _openDetail(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.onAccent,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'View Workout',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.onAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.primaryGray.withValues(alpha: 0.25)),
          InkWell(
            onTap: _addingToCalendar ? null : () => _addToCalendar(context),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  if (_addingToCalendar)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                    )
                  else
                    Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.onSurface),
                  const SizedBox(width: 8),
                  Text(
                    _addingToCalendar ? 'Adding…' : 'Add to Calendar',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workoutThumbFallback() {
    return Container(
      width: 72,
      height: 72,
      color: AppColors.accent.withValues(alpha: 0.12),
      child: Icon(Icons.fitness_center, color: AppColors.accent, size: 28),
    );
  }

  Widget _buildGenericCard(BuildContext context) {
    final title = _genericTitle();
    final subtitle = _genericSubtitle();
    final imageUrl = _imageUrl();
    final accent = isCurrentUser ? AppColors.onAccent : AppColors.accent;
    final textColor = isCurrentUser ? AppColors.onAccent : AppColors.onSurface;
    final muted = isCurrentUser ? AppColors.onAccent.withValues(alpha: 0.75) : AppColors.primaryGray;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isCurrentUser ? AppColors.onAccent.withValues(alpha: 0.12) : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              if (imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SafeNetworkImage(
                    url: imageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    fallback: Icon(_icon(), color: accent, size: 24),
                  ),
                ),
                const SizedBox(width: 10),
              ] else ...[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Icon(_icon(), color: accent, size: 24),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _typeLabel(),
                      style: AppTextStyles.labelSmall.copyWith(color: muted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(color: textColor, fontWeight: FontWeight.w600),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(color: muted),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _workoutItems() {
    final raw = data['workout'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  int _setCount(List<Map<String, dynamic>> workouts) {
    var count = 0;
    for (final workout in workouts) {
      final sets = workout['exercise'];
      if (sets is List) count += sets.length;
    }
    return count;
  }

  String _workoutTitle() {
    final workouts = _workoutItems();
    if (workouts.isEmpty) return 'Workout journal';
    final first = workouts.first;
    final name = first['name']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      if (workouts.length == 1) return name;
      return '$name +${workouts.length - 1} more';
    }
    return '${workouts.length} exercise${workouts.length == 1 ? '' : 's'}';
  }

  String _workoutSubtitle() {
    final workouts = _workoutItems();
    final exerciseCount = workouts.length;
    final setCount = _setCount(workouts);
    final parts = <String>[
      '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'}',
      if (setCount > 0) '$setCount set${setCount == 1 ? '' : 's'}',
    ];
    return parts.join(' • ');
  }

  String _typeLabel() {
    return switch (type) {
      SharedContentType.feed => 'Feed',
      SharedContentType.workoutJournal => 'Workout',
      SharedContentType.runningLog => 'Run',
      SharedContentType.recipe => 'Recipe',
      SharedContentType.foodSave => 'Food',
    };
  }

  IconData _icon() {
    return switch (type) {
      SharedContentType.feed => Icons.play_circle_outline,
      SharedContentType.workoutJournal => Icons.fitness_center,
      SharedContentType.runningLog => Icons.directions_run,
      SharedContentType.recipe => Icons.restaurant_menu,
      SharedContentType.foodSave => Icons.restaurant,
    };
  }

  String _genericTitle() {
    switch (type) {
      case SharedContentType.feed:
        return data['title']?.toString().trim().isNotEmpty == true ? data['title'].toString() : 'Feed post';
      case SharedContentType.workoutJournal:
        return _workoutTitle();
      case SharedContentType.runningLog:
        final distance = (data['distance'] as num?)?.toDouble();
        if (distance != null && distance > 0) return '${distance.toStringAsFixed(2)} km run';
        return data['runningType']?.toString() ?? 'Running log';
      case SharedContentType.recipe:
        return data['name']?.toString() ?? 'Recipe';
      case SharedContentType.foodSave:
        final nested = data['recipe'];
        if (nested is Map && nested['name'] != null) return nested['name'].toString();
        return data['name']?.toString() ?? 'Saved food';
    }
  }

  String _genericSubtitle() {
    switch (type) {
      case SharedContentType.feed:
        final duration = (data['duration'] as num?)?.toInt();
        return duration != null && duration > 0 ? CalendarRepository.formatDurationSeconds(duration) : '';
      case SharedContentType.workoutJournal:
        return _workoutSubtitle();
      case SharedContentType.runningLog:
        final duration = (data['duration'] as num?)?.toInt();
        final calories = (data['caloriesBurned'] as num?)?.round();
        final parts = <String>[];
        if (duration != null && duration > 0) parts.add(CalendarRepository.formatDurationSeconds(duration));
        if (calories != null && calories > 0) parts.add('$calories cal');
        return parts.join(' · ');
      case SharedContentType.recipe:
        final calories = (data['nutrition'] is Map ? (data['nutrition'] as Map)['calories'] : data['calories']) as num?;
        return calories != null ? '${calories.round()} cal' : '';
      case SharedContentType.foodSave:
        final calories = (data['calories'] as num?)?.round();
        return calories != null ? '$calories cal' : '';
    }
  }

  String? _imageUrl() {
    String? fromMap(Map<String, dynamic> map) {
      final image = map['image'];
      if (image is Map) {
        final url = ImageUrlSanitizer.resolveMediaUrl(Map<String, dynamic>.from(image)['url']?.toString());
        if (url != null) return url;
      }
      final video = map['video'];
      if (video is Map) {
        final vm = Map<String, dynamic>.from(video);
        final thumb = vm['thumbnail'];
        if (thumb is Map) {
          final url = ImageUrlSanitizer.resolveMediaUrl(Map<String, dynamic>.from(thumb)['url']?.toString());
          if (url != null) return url;
        }
      }
      final images = map['images'];
      if (images is List && images.isNotEmpty && images.first is Map) {
        final url = ImageUrlSanitizer.resolveMediaUrl(Map<String, dynamic>.from(images.first as Map)['url']?.toString());
        if (url != null) return url;
      }
      return null;
    }

    if (type == SharedContentType.foodSave) {
      final nested = data['recipe'];
      if (nested is Map) return fromMap(Map<String, dynamic>.from(nested));
      return null;
    }

    if (type == SharedContentType.workoutJournal) {
      final workouts = data['workout'];
      if (workouts is List) {
        for (final item in workouts) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final ref = map['refExercise'];
          if (ref is Map) {
            final icon = Map<String, dynamic>.from(ref)['icon'];
            if (icon is Map) {
              final url = ImageUrlSanitizer.resolveMediaUrl(Map<String, dynamic>.from(icon)['url']?.toString());
              if (url != null) return url;
            }
          }
          final media = map['icon'] ?? map['image'];
          if (media is Map) {
            final url = ImageUrlSanitizer.resolveMediaUrl(Map<String, dynamic>.from(media)['url']?.toString());
            if (url != null) return url;
          }
        }
      }
      return null;
    }

    return fromMap(data);
  }

  void _openDetail(BuildContext context) {
    final contentId = data['_id']?.toString() ?? data['id']?.toString() ?? '';
    switch (type) {
      case SharedContentType.feed:
        if (contentId.isNotEmpty) Get.toNamed(AppRoutes.feedSingleReel, arguments: {'feedId': contentId});
      case SharedContentType.workoutJournal:
        Get.toNamed(AppRoutes.sharedWorkoutDetail, arguments: {'sharedContent': data});
      case SharedContentType.runningLog:
        final run = RunningLogRepository.runModelFromApiLog(data);
        Get.toNamed(AppRoutes.runDetail, arguments: {'run': run, 'viewOnly': true});
      case SharedContentType.recipe:
        if (contentId.isNotEmpty) Get.toNamed(AppRoutes.recipeDetail, arguments: {'recipeId': contentId});
      case SharedContentType.foodSave:
        Get.toNamed(AppRoutes.home, arguments: {'navigateToTab': 3});
    }
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

  Future<void> _addToCalendar(BuildContext context) async {
    final workouts = _workoutItems();
    if (workouts.isEmpty) {
      Get.snackbar(
        'Nothing to add',
        'This shared workout has no exercises',
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Add workout to calendar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.accent,
                  onPrimary: AppColors.onAccent,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;

    setState(() => _addingToCalendar = true);
    final repo = WorkoutRepository();
    final calendarRepo = CalendarRepository();
    final day = DateTime(picked.year, picked.month, picked.day);

    try {
      String? journalId = await repo.findWorkoutJournalIdForToday(date: day);
      for (final workout in workouts) {
        final name = workout['name']?.toString().trim().isNotEmpty == true
            ? workout['name'].toString().trim()
            : 'Exercise';
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

      await calendarRepo.attachWorkoutJournalToCalendar(
        date: day,
        workoutJournalId: journalId!,
      );

      if (!mounted) return;
      Get.snackbar(
        'Added to calendar',
        'Saved to ${DateFormat.MMMd().format(day)}',
        backgroundColor: AppColors.completed,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Could not add',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _addingToCalendar = false);
    }
  }
}
