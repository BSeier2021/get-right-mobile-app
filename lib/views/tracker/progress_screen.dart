import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Progress Tracking Screen
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        centerTitle: true,
        elevation: 0,
        title: Text('Progress', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w600)),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Stats Row 1 ─────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _statCard(asset: 'assets/images/Vector.png', iconBg: const Color(0xFFE8F5E9), value: '47', valueColor: const Color(0xFF2E7D32), label: 'Total Workouts'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(asset: 'assets/images/calendar-222.png', iconBg: const Color(0xFFE0F2F1), value: '05', valueColor: const Color(0xFF00796B), label: 'This Week'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Stats Row 2 ─────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _statCard(asset: 'assets/images/runing.png', iconBg: const Color(0xFFFFF8E1), value: '125 km', valueColor: const Color(0xFFE65100), label: 'Total Distance'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(asset: 'assets/images/Subtract (2).png', iconBg: const Color(0xFFE8F5E9), value: '32', valueColor: const Color(0xFF2E7D32), label: 'Active Days'),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Weekly Activity ─────────────────────────────
          Text(
            'Weekly Activity',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onBackground),
          ),
          const SizedBox(height: 12),
          Container(
            height: 160,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCDE7C8), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart_rounded, size: 52, color: AppColors.black),
                  const SizedBox(height: 12),
                  Text('Charts coming soon', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Recent Achievements ─────────────────────────
          Text(
            'Recent Achievements',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onBackground),
          ),
          const SizedBox(height: 12),
          _achievementItem(
            asset: 'assets/images/Group 48099145.png',
            iconBg: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
            title: 'First 10K Run',
            description: 'Completed your first 10 kilometer run',
          ),
          const SizedBox(height: 10),
          _achievementItem(
            asset: 'assets/images/Subtract (2).png',
            iconBg: const Color.fromARGB(255, 247, 233, 188),
            iconColor: const Color(0xFFE65100),
            title: 'Week Warrior',
            description: 'Trained 5 days this week',
          ),
          const SizedBox(height: 10),
          _achievementItem(
            asset: 'assets/images/Group 48099146.png',
            iconBg: const Color(0xFFFCE4EC),
            iconColor: const Color(0xFFC62828),
            title: '100 Workouts',
            description: 'Logged 100 total workouts',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Stat card ──────────────────────────────────────────────────────────
  Widget _statCard({required String asset, required Color iconBg, required String value, required Color valueColor, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCDE7C8), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Circular icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => Icon(Icons.fitness_center, color: valueColor, size: 22),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Value
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(color: valueColor, fontWeight: FontWeight.bold, fontSize: 22.sp),
          ),
          const SizedBox(height: 4),
          // Label
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Achievement item ───────────────────────────────────────────────────
  Widget _achievementItem({required String asset, required Color iconBg, required Color iconColor, required String title, required String description}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCDE7C8), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Circular icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                asset,
                fit: BoxFit.contain,

                errorBuilder: (c, e, s) => Icon(Icons.emoji_events_rounded, color: iconColor, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                const SizedBox(height: 3),
                Text(description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
