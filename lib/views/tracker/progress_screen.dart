import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Progress Tracking Screen - Placeholder for Alpha
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        centerTitle: true,
        title: Text('Progress', style: AppTextStyles.titleLarge.copyWith()),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overview Stats
          Text('Your Progress Overview', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
          const SizedBox(height: 16),

          // Stats Grid
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Workouts', '47', Icons.fitness_center, AppColors.accent)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('This Week', '5', Icons.calendar_today, AppColors.completed)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Distance', '125 km', Icons.directions_run, AppColors.upcoming)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Active Days', '32', Icons.local_fire_department, AppColors.error)),
            ],
          ),

          const SizedBox(height: 32),

          // Weekly Chart Placeholder
          Text('Weekly Activity', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
          const SizedBox(height: 16),
          Container(
            height: 200,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryGray, width: 1),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 64, color: AppColors.primaryGray),
                  const SizedBox(height: 16),
                  Text('Charts coming soon', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Recent Achievements
          Text('Recent Achievements', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
          const SizedBox(height: 16),
          _buildAchievementItem('First 10K Run', 'Completed your first 10 kilometer run', Icons.emoji_events, AppColors.accent),
          _buildAchievementItem('Week Warrior', 'Trained 5 days this week', Icons.local_fire_department, AppColors.upcoming),
          _buildAchievementItem('100 Workouts', 'Logged 100 total workouts', Icons.celebration, AppColors.completed),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(String title, String description, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
                const SizedBox(height: 4),
                Text(description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
