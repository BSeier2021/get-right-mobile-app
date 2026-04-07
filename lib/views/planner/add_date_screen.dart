import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/journal/add_workout_screen.dart';
import 'package:get_right/views/planner/add_notes_screen.dart';

class AddDateScreen extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback? onAddProgressPhoto;
  final VoidCallback? onAddNotes;

  const AddDateScreen({super.key, required this.selectedDate, this.onAddProgressPhoto, this.onAddNotes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text('Add Date', style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add to Today\'s Schedule',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text('Log something for this day', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
              const SizedBox(height: 16),
              _buildActionTile(
                context: context,
                imagePath: 'assets/images/Vector.png',
                iconBg: const Color(0xFFDFF1D3),
                title: 'Add Workout',
                subtitle: 'Log a gym or home workout',
                onTap: () {
                  Get.to(AddWorkoutScreen());
                },
              ),
              const SizedBox(height: 12),
              _buildActionTile(
                context: context,
                imagePath: 'assets/images/runing.png',
                iconBg: const Color(0xFFFFE8D1),
                title: 'Add Run',
                subtitle: 'Log a run or outdoor activity',
                onTap: () {
                  Get.toNamed(AppRoutes.logRun, arguments: {'selectedDate': selectedDate});
                },
              ),
              const SizedBox(height: 12),
              _buildActionTile(
                context: context,
                imagePath: 'assets/images/camera.png',
                iconBg: const Color(0xFFF6E6FF),
                title: 'Add Progress Photo',
                subtitle: 'Front or side progress photo',
                onTap: () {
                  if (onAddProgressPhoto != null) {
                    Get.back();
                    WidgetsBinding.instance.addPostFrameCallback((_) => onAddProgressPhoto!.call());
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildActionTile(
                context: context,
                imagePath: 'assets/images/note-2.png',
                iconBg: const Color(0xFFDDECF7),
                title: 'Add Notes',
                subtitle: 'Add notes for this day',
                onTap: () {
                  Get.toNamed('/add-notes') ??
                      Get.to(() async {
                        // Fallback anonymous route if named route isn't set
                        final result = await Get.to(() => const AddNotesScreen());
                        if (result != null && result is String && result.isNotEmpty) {
                          Get.back(result: result);
                        }
                      });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required String imagePath,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FFE9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryGray.withOpacity(0.25)),
            boxShadow: [BoxShadow(color: AppColors.blackOverlay.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(imagePath, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primaryGray),
            ],
          ),
        ),
      ),
    );
  }
}
