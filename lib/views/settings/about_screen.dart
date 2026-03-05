import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/app_logo.dart';

/// About Screen - App information for Alpha
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('About', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 15),

            // App Logo
            Center(child: const AppLogo(borderRadius: 16)),

            const SizedBox(height: 24),

            // App Name & Version
            Text(
              'Get Right',
              style: AppTextStyles.headlineMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Version 1.0.0 (Alpha)', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),

            const SizedBox(height: 32),

            // Description
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryGray, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About Get Right', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
                  const SizedBox(height: 12),
                  Text(
                    'Get Right is your ultimate fitness companion. Track your workouts, plan your training, and achieve your fitness goals with our comprehensive fitness platform.',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, height: 1.6),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Features
            _buildFeatureItem(icon: Icons.fitness_center, title: 'Workout Tracking', description: 'Log and monitor your fitness progress'),
            _buildFeatureItem(icon: Icons.directions_run, title: 'GPS Run Tracking', description: 'Track your runs with real-time GPS'),
            _buildFeatureItem(icon: Icons.calendar_today, title: 'Workout Planning', description: 'Plan and schedule your training'),
            _buildFeatureItem(icon: Icons.store, title: 'Program Marketplace', description: 'Browse and purchase training programs'),

            const SizedBox(height: 32),

            // Legal
            Text(
              '© 2025 Get Right. All rights reserved.',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String title, required String description}) {
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.accent, size: 24),
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
