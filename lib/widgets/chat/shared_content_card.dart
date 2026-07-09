import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/shared_content_model.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:get_right/widgets/safe_network_image.dart';
import 'package:intl/intl.dart';

/// Renders populated `message.sharedContent` by [type].
class SharedContentCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final title = _title();
    final subtitle = _subtitle();
    final imageUrl = _imageUrl();
    final accent = isCurrentUser ? AppColors.onAccent : AppColors.accent;
    final textColor = isCurrentUser ? AppColors.onAccent : AppColors.onSurface;
    final muted = isCurrentUser ? AppColors.onAccent.withOpacity(0.75) : AppColors.primaryGray;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isCurrentUser ? AppColors.onAccent.withOpacity(0.12) : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withOpacity(0.25)),
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
                  decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
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
            ],
          ),
        ),
      ),
    );
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

  String _title() {
    switch (type) {
      case SharedContentType.feed:
        return data['title']?.toString().trim().isNotEmpty == true ? data['title'].toString() : 'Feed post';
      case SharedContentType.workoutJournal:
        final exercises = data['workout'];
        final count = exercises is List ? exercises.length : 0;
        return count > 0 ? '$count exercise${count == 1 ? '' : 's'}' : 'Workout journal';
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

  String _subtitle() {
    switch (type) {
      case SharedContentType.feed:
        final duration = (data['duration'] as num?)?.toInt();
        return duration != null && duration > 0 ? CalendarRepository.formatDurationSeconds(duration) : '';
      case SharedContentType.workoutJournal:
        final duration = (data['duration'] as num?)?.toInt();
        final calories = (data['caloriesBurned'] as num?)?.round();
        final parts = <String>[];
        if (duration != null && duration > 0) parts.add(CalendarRepository.formatDurationSeconds(duration));
        if (calories != null && calories > 0) parts.add('$calories cal');
        final dateRaw = data['date']?.toString();
        final date = dateRaw != null ? DateTime.tryParse(dateRaw) : null;
        if (date != null) parts.add(DateFormat('MMM d').format(date.toLocal()));
        return parts.join(' · ');
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
          final ref = Map<String, dynamic>.from(item)['refExercise'];
          if (ref is Map) {
            final icon = Map<String, dynamic>.from(ref)['icon'];
            if (icon is Map) {
              final url = ImageUrlSanitizer.resolveMediaUrl(Map<String, dynamic>.from(icon)['url']?.toString());
              if (url != null) return url;
            }
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
        Get.toNamed(AppRoutes.home, arguments: {'navigateToTab': 2, 'journalTabIndex': 0});
      case SharedContentType.runningLog:
        if (contentId.isNotEmpty) Get.toNamed(AppRoutes.runDetail, arguments: {'runningLogId': contentId});
      case SharedContentType.recipe:
        if (contentId.isNotEmpty) Get.toNamed(AppRoutes.recipeDetail, arguments: {'recipeId': contentId});
      case SharedContentType.foodSave:
        Get.toNamed(AppRoutes.home, arguments: {'navigateToTab': 3});
    }
  }
}
