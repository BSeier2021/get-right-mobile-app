import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// About Screen - App information
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text('About', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        children: [
          // ── About description ───────────────────────────────────────
          Text('About Get Right', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
          SizedBox(height: 10.h),
          Text(
            'Get Right is your ultimate fitness companion. Track your workouts, plan your training, and achieve your fitness goals with our comprehensive fitness platform.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, height: 1.6),
          ),

          SizedBox(height: 24.h),

          // ── Feature cards ───────────────────────────────────────────
          _buildFeatureCard('Workout Tracking', 'Log and monitor your fitness progress'),
          _buildFeatureCard('GPS Run Tracking', 'Track your runs with real-time GPS'),
          _buildFeatureCard('Workout Planning', 'Plan and schedule your training'),
          _buildFeatureCard('Program Marketplace', 'Browse and purchase training programs'),

          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String title, String description) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6F0DA), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
          SizedBox(height: 4.h),
          Text(description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
        ],
      ),
    );
  }
}
