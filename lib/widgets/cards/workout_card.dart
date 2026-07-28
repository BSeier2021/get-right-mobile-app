import 'package:flutter/material.dart';
import 'package:get_right/models/workout_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/helpers.dart';

/// Workout card widget
class WorkoutCard extends StatelessWidget {
  final WorkoutModel workout;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const WorkoutCard({super.key, required this.workout, this.onTap, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(workout.exerciseName, style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
                  ), // White text
                  if (onEdit != null || onDelete != null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppColors.onSurface), // White icon
                      onSelected: (value) {
                        if (value == 'edit' && onEdit != null) {
                          onEdit!();
                        } else if (value == 'delete' && onDelete != null) {
                          onDelete!();
                        }
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                          ),
                        if (onDelete != null)
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                          ),
                      ],
                      color: AppColors.surface, // Dark background
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(icon: Icons.fitness_center, text: '${workout.sets} sets'),
                  const SizedBox(width: 8),
                  _buildInfoChip(icon: Icons.repeat, text: '${workout.reps} reps'),
                  if (workout.weight != null) ...[const SizedBox(width: 8), _buildInfoChip(icon: Icons.scale, text: '${workout.weight} kg')],
                ],
              ),
              if (workout.notes != null && workout.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  workout.notes!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray), // Gray text
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (workout.tags != null && workout.tags!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: workout.tags!.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(tag, style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary)),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              Text(Helpers.formatDate(workout.date), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)), // Gray text
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.primaryGray, borderRadius: BorderRadius.circular(6)), // Gray background
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.onSurface), // Black icon
          const SizedBox(width: 4),
          Text(text, style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface)), // Black text
        ],
      ),
    );
  }
}
