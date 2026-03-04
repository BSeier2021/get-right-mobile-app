import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/enrolled_program_model.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Program History Screen - Shows all enrolled programs with 3 tabs
class ProgramHistoryScreen extends StatefulWidget {
  const ProgramHistoryScreen({super.key});

  @override
  State<ProgramHistoryScreen> createState() => _ProgramHistoryScreenState();
}

class _ProgramHistoryScreenState extends State<ProgramHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock enrolled programs data
  final List<EnrolledProgramModel> _allPrograms = [
    EnrolledProgramModel(
      id: '1',
      programId: 'prog_1',
      programTitle: 'Complete Strength Program',
      trainerId: 'trainer_1',
      trainerName: 'Sarah Johnson',
      trainerImage: 'SJ',
      price: 49.99,
      category: 'Strength',
      durationWeeks: 12,
      startDate: DateTime.now().subtract(const Duration(days: 14)),
      endDate: DateTime.now().add(const Duration(days: 70)),
      status: ProgramStatus.active,
      progress: 35,
      enrolledAt: DateTime.now().subtract(const Duration(days: 14)),
    ),
    EnrolledProgramModel(
      id: '2',
      programId: 'prog_2',
      programTitle: 'Cardio Blast Challenge',
      trainerId: 'trainer_2',
      trainerName: 'Mike Chen',
      trainerImage: 'MC',
      price: 29.99,
      category: 'Cardio',
      durationWeeks: 8,
      startDate: DateTime.now().subtract(const Duration(days: 7)),
      endDate: DateTime.now().add(const Duration(days: 49)),
      status: ProgramStatus.active,
      progress: 15,
      enrolledAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
    EnrolledProgramModel(
      id: '3',
      programId: 'prog_3',
      programTitle: 'Yoga for Athletes',
      trainerId: 'trainer_3',
      trainerName: 'Emma Davis',
      trainerImage: 'ED',
      price: 39.99,
      category: 'Flexibility',
      durationWeeks: 6,
      startDate: DateTime.now().subtract(const Duration(days: 60)),
      endDate: DateTime.now().subtract(const Duration(days: 18)),
      status: ProgramStatus.completed,
      progress: 100,
      enrolledAt: DateTime.now().subtract(const Duration(days: 60)),
      completedAt: DateTime.now().subtract(const Duration(days: 18)),
      review: Review(
        id: 'rev_1',
        enrolledProgramId: '3',
        rating: 4.5,
        comment: 'Great program! Really helped with my flexibility.',
        mediaUrls: [],
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
    ),
    EnrolledProgramModel(
      id: '4',
      programId: 'prog_4',
      programTitle: 'Marathon Prep',
      trainerId: 'trainer_4',
      trainerName: 'Lisa Thompson',
      trainerImage: 'LT',
      price: 59.99,
      category: 'Running',
      durationWeeks: 16,
      startDate: DateTime.now().add(const Duration(days: 14)),
      endDate: DateTime.now().add(const Duration(days: 126)),
      status: ProgramStatus.cancelled,
      progress: 0,
      enrolledAt: DateTime.now().subtract(const Duration(days: 30)),
      cancelledAt: DateTime.now().subtract(const Duration(days: 5)),
      cancellationReason: 'Schedule conflict',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<EnrolledProgramModel> get _activePrograms => _allPrograms.where((p) => p.status == ProgramStatus.active).toList();
  List<EnrolledProgramModel> get _cancelledPrograms => _allPrograms.where((p) => p.status == ProgramStatus.cancelled).toList();
  List<EnrolledProgramModel> get _completedPrograms => _allPrograms.where((p) => p.status == ProgramStatus.completed).toList();

  void _viewProgramDetails(EnrolledProgramModel program) {
    if (program.status == ProgramStatus.active) {
      Get.toNamed(AppRoutes.activeProgramDetail, arguments: program);
    } else if (program.status == ProgramStatus.completed) {
      Get.toNamed(AppRoutes.completedProgramDetail, arguments: program);
    } else {
      // Cancelled programs - show basic details
      Get.toNamed(AppRoutes.activeProgramDetail, arguments: program);
    }
  }

  void _showCancelDialog(EnrolledProgramModel program) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 60),
              const SizedBox(height: 20),
              Text(
                'Cancel Program?',
                style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to cancel this program? This action cannot be undone.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  program.programTitle,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
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
                      child: Text('No', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onBackground)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        _cancelProgram(program);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Yes, Cancel', style: AppTextStyles.buttonMedium.copyWith(color: Colors.white)),
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

  void _cancelProgram(EnrolledProgramModel program) {
    setState(() {
      final index = _allPrograms.indexWhere((p) => p.id == program.id);
      if (index != -1) {
        // Create a new instance with cancelled status
        final cancelledProgram = EnrolledProgramModel(
          id: program.id,
          programId: program.programId,
          programTitle: program.programTitle,
          trainerId: program.trainerId,
          trainerName: program.trainerName,
          trainerImage: program.trainerImage,
          price: program.price,
          category: program.category,
          durationWeeks: program.durationWeeks,
          startDate: program.startDate,
          endDate: program.endDate,
          status: ProgramStatus.cancelled,
          progress: program.progress,
          enrolledAt: program.enrolledAt,
          completedAt: program.completedAt,
          cancelledAt: DateTime.now(),
          cancellationReason: 'User cancelled',
          pendingModification: program.pendingModification,
          review: program.review,
        );
        _allPrograms[index] = cancelledProgram;
      }
    });

    Get.snackbar(
      'Program Cancelled',
      'Your enrollment in ${program.programTitle} has been cancelled',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.missed,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withOpacity(0.1), width: 1),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Get.back();
            } else {
              Get.offAllNamed(AppRoutes.home);
            }
          },
        ),
        title: Text('Program History', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.onPrimary,
          unselectedLabelColor: AppColors.onPrimary.withOpacity(0.6),
          labelStyle: AppTextStyles.titleSmall,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Cancelled'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildProgramsList(_activePrograms, 'Active'), _buildProgramsList(_cancelledPrograms, 'Cancelled'), _buildProgramsList(_completedPrograms, 'Completed')],
      ),
    );
  }

  Widget _buildProgramsList(List<EnrolledProgramModel> programs, String statusType) {
    if (programs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              statusType == 'Active'
                  ? Icons.fitness_center
                  : statusType == 'Cancelled'
                  ? Icons.cancel_outlined
                  : Icons.check_circle_outline,
              size: 80,
              color: AppColors.primaryGray.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text('No $statusType Programs', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
            const SizedBox(height: 8),
            Text(
              statusType == 'Active'
                  ? 'You don\'t have any active programs'
                  : statusType == 'Cancelled'
                  ? 'You haven\'t cancelled any programs'
                  : 'You haven\'t completed any programs yet',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: programs.length,
      itemBuilder: (context, index) {
        final program = programs[index];
        return _buildProgramCard(program);
      },
    );
  }

  Widget _buildProgramCard(EnrolledProgramModel program) {
    final isActive = program.status == ProgramStatus.active;
    final isCompleted = program.status == ProgramStatus.completed;

    Color statusColor;
    String statusText;
    if (isActive) {
      statusColor = AppColors.completed;
      statusText = 'Active';
    } else if (isCompleted) {
      statusColor = AppColors.completed;
      statusText = 'Completed';
    } else {
      statusColor = AppColors.missed;
      statusText = 'Cancelled';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.accent,
                child: Text(program.trainerImage ?? program.trainerName[0], style: AppTextStyles.titleSmall.copyWith(color: AppColors.onAccent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.programTitle,
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    Text('by ${program.trainerName}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  statusText,
                  style: AppTextStyles.labelSmall.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar (for active programs)
          if (isActive) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progress', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                Text(
                  '${program.progress}%',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: program.progress / 100,
              backgroundColor: AppColors.primaryGray.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
            const SizedBox(height: 16),
          ],

          // Dates
          Row(
            children: [
              Expanded(child: _buildDateInfo(Icons.play_circle_outline, 'Start', _formatDate(program.startDate))),
              const SizedBox(width: 12),
              Expanded(child: _buildDateInfo(Icons.flag_outlined, 'End', _formatDate(program.endDate))),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewProgramDetails(program),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppColors.accent, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(Icons.visibility, size: 18, color: AppColors.accent),
                  label: Text('View Details', style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent)),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCancelDialog(program),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.red, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                    label: Text('Cancel', style: AppTextStyles.labelMedium.copyWith(color: Colors.red)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(IconData icon, String label, String date) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryGray),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                Text(
                  date,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
