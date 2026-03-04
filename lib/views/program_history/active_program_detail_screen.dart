import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/enrolled_program_model.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:intl/intl.dart';

/// Active Program Detail Screen
class ActiveProgramDetailScreen extends StatelessWidget {
  const ActiveProgramDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final program = Get.arguments as EnrolledProgramModel?;
    if (program == null) {
      Get.back();
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: Text('Program Details', style: AppTextStyles.titleLarge.copyWith()), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Program Header Card
            _buildProgramHeader(program),
            const SizedBox(height: 24),

            // Program Info
            _buildSectionTitle('Program Information'),
            const SizedBox(height: 12),
            _buildInfoCard(program),
            const SizedBox(height: 24),

            // Progress Section
            if (program.status == ProgramStatus.active) ...[_buildSectionTitle('Progress'), const SizedBox(height: 12), _buildProgressCard(program), const SizedBox(height: 24)],

            // Pending Modification Request
            if (program.pendingModification != null) ...[
              _buildSectionTitle('Modification Request'),
              const SizedBox(height: 12),
              _buildModificationRequestCard(program.pendingModification!),
              const SizedBox(height: 24),
            ],

            // Action Buttons
            _buildSectionTitle('Actions'),
            const SizedBox(height: 12),
            _buildActionButtons(program),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramHeader(EnrolledProgramModel program) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.accent,
                child: Text(
                  program.trainerImage ?? program.trainerName[0],
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.programTitle,
                      style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('by ${program.trainerName}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: program.status == ProgramStatus.active
                  ? AppColors.completed.withOpacity(0.1)
                  : program.status == ProgramStatus.cancelled
                  ? AppColors.missed.withOpacity(0.1)
                  : AppColors.primaryGray.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              program.status.toString().toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                color: program.status == ProgramStatus.active
                    ? AppColors.completed
                    : program.status == ProgramStatus.cancelled
                    ? AppColors.missed
                    : AppColors.primaryGray,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildInfoCard(EnrolledProgramModel program) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _buildInfoRow('Category', program.category),
          const Divider(color: AppColors.primaryGray, height: 24),
          _buildInfoRow('Duration', '${program.durationWeeks} weeks'),
          const Divider(color: AppColors.primaryGray, height: 24),
          _buildInfoRow('Start Date', DateFormat('MMM dd, yyyy').format(program.startDate)),
          const Divider(color: AppColors.primaryGray, height: 24),
          _buildInfoRow('End Date', DateFormat('MMM dd, yyyy').format(program.endDate)),
          const Divider(color: AppColors.primaryGray, height: 24),
          _buildInfoRow('Price', '\$${program.price.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildProgressCard(EnrolledProgramModel program) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Overall Progress', style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
              Text(
                '${program.progress}%',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: program.progress / 100,
            backgroundColor: AppColors.primaryGray.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildModificationRequestCard(ModificationRequest request) {
    final statusColor = request.status == ModificationStatus.approved
        ? AppColors.completed
        : request.status == ModificationStatus.rejected
        ? AppColors.missed
        : AppColors.upcoming;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Modification Request',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  request.status.toString().toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (request.newStartDate != null)
            Text('New Start: ${DateFormat('MMM dd, yyyy').format(request.newStartDate!)}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
          if (request.newEndDate != null)
            Text('New End: ${DateFormat('MMM dd, yyyy').format(request.newEndDate!)}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
          const SizedBox(height: 8),
          Text('Reason: ${request.reason}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)),
          if (request.additionalNotes != null && request.additionalNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Notes: ${request.additionalNotes}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(EnrolledProgramModel program) {
    if (program.status == ProgramStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Text(
          'This program has been cancelled.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        // Request Program Modification
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Get.toNamed(AppRoutes.programModificationRequest, arguments: program);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: AppColors.accent, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(Icons.edit_calendar, color: AppColors.accent),
            label: Text(
              'Request Program Modification',
              style: AppTextStyles.buttonMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Chat with Trainer
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Get.toNamed(AppRoutes.chatRoom, arguments: program);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.chat),
            label: Text(
              'Chat with Trainer',
              style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Download Progress Report
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              _downloadProgressReport(program);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: AppColors.primaryGray, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(Icons.download, color: AppColors.primaryGray),
            label: Text(
              'Download Progress Report',
              style: AppTextStyles.buttonMedium.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Mark as Completed
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              _showMarkCompletedDialog(program);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.completed,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: Text(
              'Mark as Completed',
              style: AppTextStyles.buttonMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  void _downloadProgressReport(EnrolledProgramModel program) {
    // TODO: Implement actual PDF generation and download
    Get.snackbar(
      'Download Started',
      'Progress report for ${program.programTitle} is being generated...',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.accent,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  void _showMarkCompletedDialog(EnrolledProgramModel program) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.completed, size: 60),
              const SizedBox(height: 20),
              Text(
                'Mark as Completed?',
                style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to mark "${program.programTitle}" as completed?',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: AppColors.primaryGray, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onBackground)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        _markAsCompleted(program);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.completed,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Complete', style: AppTextStyles.buttonMedium.copyWith(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _markAsCompleted(EnrolledProgramModel program) {
    // TODO: Update program status in backend
    Get.snackbar(
      'Program Completed',
      '${program.programTitle} has been marked as completed',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.completed,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
    Get.until((route) => route.settings.name == AppRoutes.programHistory);
  }
}
