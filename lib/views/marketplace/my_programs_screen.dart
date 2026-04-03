import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// My Programs Screen - Shows active, scheduled and completed programs
class MyProgramsScreen extends StatefulWidget {
  const MyProgramsScreen({super.key});

  @override
  State<MyProgramsScreen> createState() => _MyProgramsScreenState();
}

class _MyProgramsScreenState extends State<MyProgramsScreen> {
  int _selectedTab = 0;

  // Mock enrolled programs
  final List<Map<String, dynamic>> _activePrograms = [
    {
      'id': '1',
      'title': 'Complete Strength Program',
      'trainer': 'Sarah Johnson',
      'trainerImage': 'SJ',
      'price': 49.99,
      'duration': '12 weeks',
      'category': 'Strength',
      'startDate': DateTime(2025, 5, 4),
      'endDate': DateTime(2025, 6, 4),
      'progress': 35,
      'status': 'active',
      'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600',
    },
    {
      'id': '2',
      'title': 'The Ultimate Strength Builder',
      'trainer': 'June Johnson',
      'trainerImage': 'JJ',
      'price': 29.99,
      'duration': '8 weeks',
      'category': 'Strength',
      'startDate': DateTime(2025, 5, 4),
      'endDate': DateTime(2025, 6, 4),
      'progress': 35,
      'status': 'active',
      'image': 'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=600',
    },
  ];

  final List<Map<String, dynamic>> _scheduledPrograms = [
    {
      'id': '3',
      'title': 'Yoga for Athletes',
      'trainer': 'Emma Davis',
      'trainerImage': 'ED',
      'price': 39.99,
      'duration': '6 weeks',
      'category': 'Flexibility',
      'startDate': DateTime.now().add(const Duration(days: 7)),
      'endDate': DateTime.now().add(const Duration(days: 49)),
      'progress': 0,
      'status': 'scheduled',
      'image': 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=600',
    },
    {
      'id': '4',
      'title': 'Marathon Prep',
      'trainer': 'Lisa Thompson',
      'trainerImage': 'LT',
      'price': 59.99,
      'duration': '16 weeks',
      'category': 'Running',
      'startDate': DateTime.now().add(const Duration(days: 14)),
      'endDate': DateTime.now().add(const Duration(days: 126)),
      'progress': 0,
      'status': 'scheduled',
      'image': 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=600',
    },
  ];

  final List<Map<String, dynamic>> _completedPrograms = [
    {
      'id': '5',
      'title': 'Beginner Strength Training',
      'trainer': 'John Smith',
      'trainerImage': 'JS',
      'price': 45.99,
      'duration': '8 weeks',
      'category': 'Strength',
      'startDate': DateTime.now().subtract(const Duration(days: 80)),
      'endDate': DateTime.now().subtract(const Duration(days: 24)),
      'progress': 100,
      'status': 'completed',
      'completedDate': DateTime.now().subtract(const Duration(days: 24)),
      'hasRating': false,
      'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600',
    },
    {
      'id': '6',
      'title': 'HIIT Workout Challenge',
      'trainer': 'Maria Garcia',
      'trainerImage': 'MG',
      'price': 35.99,
      'duration': '4 weeks',
      'category': 'Cardio',
      'startDate': DateTime.now().subtract(const Duration(days: 60)),
      'endDate': DateTime.now().subtract(const Duration(days: 32)),
      'progress': 100,
      'status': 'completed',
      'completedDate': DateTime.now().subtract(const Duration(days: 32)),
      'hasRating': true,
      'rating': 5.0,
      'review': 'Amazing program!',
      'image': 'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=600',
    },
  ];

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args != null && args is Map && args['enrolled'] == true) {
      final program = args['program'];
      if (program != null) {
        final startDate = program['startDate'] ?? DateTime.now().add(const Duration(days: 1));
        final calculatedEndDate = startDate is DateTime ? startDate.add(const Duration(days: 84)) : DateTime.now().add(const Duration(days: 85));
        final endDate = program['endDate'] ?? calculatedEndDate;
        _scheduledPrograms.insert(0, {
          ...program,
          'id': program['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'title': program['title']?.toString() ?? 'Program',
          'trainer': program['trainer']?.toString() ?? 'Trainer',
          'trainerImage': program['trainerImage']?.toString() ?? 'UT',
          'duration': program['duration']?.toString() ?? '12 weeks',
          'category': program['category']?.toString() ?? 'General',
          'progress': 0,
          'status': 'scheduled',
          'startDate': startDate,
          'endDate': endDate,
        });
      }
    }
  }

  void _viewProgramDetails(Map<String, dynamic> program) {
    Get.toNamed(AppRoutes.programDetail, arguments: program);
  }

  List<Map<String, dynamic>> get _currentPrograms {
    switch (_selectedTab) {
      case 0:
        return _activePrograms;
      case 1:
        return _scheduledPrograms;
      case 2:
        return _completedPrograms;
      default:
        return _activePrograms;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Get.offAllNamed(AppRoutes.home);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          elevation: 0,
          centerTitle: true,
          title: Text('My Programs', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w600)),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.accent, size: 16),
            ),
            onPressed: () => Get.offAllNamed(AppRoutes.home),
          ),
        ),
        body: Column(
          children: [
            // ── Tab chips ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_tabChip(0, 'Active'), const SizedBox(width: 12), _tabChip(1, 'Scheduled'), const SizedBox(width: 12), _tabChip(2, 'Completed')],
              ),
            ),

            // ── Program list ────────────────────────────
            Expanded(child: _buildProgramsList(_currentPrograms)),
          ],
        ),
      ),
    );
  }

  // ─── Tab chip ───────────────────────────────────────────────────────────
  Widget _tabChip(int index, String label) {
    final selected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: selected ? 25.w : 8.w, vertical: 5.h),
        decoration: BoxDecoration(color: selected ? AppColors.accentVariant : Colors.transparent, borderRadius: BorderRadius.circular(50)),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: selected ? Colors.white : AppColors.onPrimary.withOpacity(0.7),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13.sp,
          ),
        ),
      ),
    );
  }

  // ─── Program list ───────────────────────────────────────────────────────
  Widget _buildProgramsList(List<Map<String, dynamic>> programs) {
    if (programs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 72, color: AppColors.primaryGray.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('No programs yet', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
            const SizedBox(height: 8),
            Text('Explore the marketplace to find programs', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Get.toNamed(AppRoutes.marketplace),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentVariant,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                elevation: 0,
              ),
              child: const Text('Browse Programs'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: programs.length, itemBuilder: (context, index) => _buildProgramCard(programs[index]));
  }

  void _cancelProgram(Map<String, dynamic> program) {
    final programId = program['id']?.toString();
    if (programId == null) return;
    setState(() {
      _scheduledPrograms.removeWhere((p) => p['id']?.toString() == programId);
      _activePrograms.removeWhere((p) => p['id']?.toString() == programId);
      _completedPrograms.removeWhere((p) => p['id']?.toString() == programId);
    });
    Get.snackbar(
      'Program Cancelled',
      '${program['title'] ?? 'Program'} has been cancelled',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.completed,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  // ─── Program card ───────────────────────────────────────────────────────
  Widget _buildProgramCard(Map<String, dynamic> program) {
    final startDate = program['startDate'] is DateTime ? program['startDate'] as DateTime : DateTime.now();
    final endDate = program['endDate'] is DateTime ? program['endDate'] as DateTime : DateTime.now().add(const Duration(days: 30));
    final progress = program['progress'] ?? 0;
    final imageUrl = program['image'] as String?;
    final isActive = _selectedTab == 0;
    final isScheduled = _selectedTab == 1;
    final isCompleted = _selectedTab == 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCDE7C8), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image ────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: imageUrl != null
                ? Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => _imagePlaceholder())
                : _imagePlaceholder(),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active: progress first, then title
                if (isActive) ...[_progressSection(progress), const SizedBox(height: 14)],

                // ── Title ─────────────────────────────
                Text(
                  program['title']?.toString() ?? 'Program',
                  style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                const SizedBox(height: 4),

                // ── Trainer ───────────────────────────
                Text('by ${program['trainer']?.toString() ?? 'Trainer'}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                const SizedBox(height: 10),

                // ── Date range ────────────────────────
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primaryGrayDark),
                    const SizedBox(width: 6),
                    Text(
                      'From ${_formatDateFull(startDate)} – ${_formatDateFull(endDate)}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),

                // Scheduled / Completed: progress after date
                if (isScheduled || isCompleted) ...[const SizedBox(height: 14), _progressSection(progress)],

                const SizedBox(height: 16),

                // ── Buttons per tab ───────────────────
                if (isActive) _viewDetailsButton(program) else if (isScheduled) _cancelButton(program) else if (isCompleted) _completedButtons(program),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Progress row + bar ─────────────────────────────────────────────────
  Widget _progressSection(int progress) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.black, fontWeight: FontWeight.w500),
            ),
            Text(
              '$progress%',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.accentVariant, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 8,
            backgroundColor: AppColors.primaryGray.withOpacity(0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentVariant),
          ),
        ),
      ],
    );
  }

  // ─── Active: View Details ───────────────────────────────────────────────
  Widget _viewDetailsButton(Map<String, dynamic> program) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _viewProgramDetails(program),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentVariant,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          elevation: 0,
        ),
        child: Text(
          'View Details',
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ─── Scheduled: Cancel ──────────────────────────────────────────────────
  Widget _cancelButton(Map<String, dynamic> program) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _cancelProgram(program),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: BorderSide(color: AppColors.primaryGray.withOpacity(0.5), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        ),
        child: Text(
          'Cancel',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ─── Completed: Cancel + Review ─────────────────────────────────────────
  Widget _completedButtons(Map<String, dynamic> program) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _cancelProgram(program),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.onSurface,
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: BorderSide(color: AppColors.primaryGray.withOpacity(0.5), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _viewProgramDetails(program),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentVariant,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              elevation: 0,
            ),
            child: Text(
              'Review',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return Image.asset('assets/images/Rectangle 17030 (1).png', height: 160, width: double.infinity, fit: BoxFit.cover);
  }

  String _formatDateFull(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String suffix(int day) {
      if (day >= 11 && day <= 13) return 'th';
      switch (day % 10) {
        case 1:
          return 'st';
        case 2:
          return 'nd';
        case 3:
          return 'rd';
        default:
          return 'th';
      }
    }

    return '${months[date.month - 1]} ${date.day}${suffix(date.day)}';
  }
}
