import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/views/home/dashboard_screen.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/planner/add_notes_screen.dart';
import 'package:get_right/views/planner/calendar_type_dialog.dart';

class AddDateScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String? calendarEntryId;
  final VoidCallback? onAddProgressPhoto;
  final VoidCallback? onAddNotes;

  const AddDateScreen({super.key, required this.selectedDate, this.calendarEntryId, this.onAddProgressPhoto, this.onAddNotes});

  @override
  State<AddDateScreen> createState() => _AddDateScreenState();
}

class _AddDateScreenState extends State<AddDateScreen> {
  final CalendarRepository _calendarRepo = CalendarRepository();
  bool _isSaving = false;

  bool get _hasExistingEntry {
    final id = widget.calendarEntryId?.trim();
    return id != null && WorkoutRepository.isValidMongoId(id);
  }

  Future<bool> _saveCalendarNotes(String notes) async {
    setState(() => _isSaving = true);
    try {
      if (_hasExistingEntry) {
        await _calendarRepo.updateCalendarEntry(calendarEntryId: widget.calendarEntryId!, notes: notes);
      } else {
        final type = await showCalendarTypeDialog(context);
        if (type == null || !mounted) return false;
        await _calendarRepo.createCalendarEntry(date: widget.selectedDate, type: type, notes: notes);
      }

      if (!mounted) return false;
      Get.snackbar(
        'Saved',
        _hasExistingEntry ? 'Calendar entry updated' : 'Calendar entry added',
        backgroundColor: AppColors.completed,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      await showCalendarErrorDialog(context, e);
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleAddWorkout() {
    Get.back(result: 'workout_journal');
    Get.back();
    if (Get.isRegistered<HomeNavigationController>()) {
      if (Get.currentRoute != AppRoutes.home) {
        Get.until((route) => route.settings.name == AppRoutes.home);
      }
      Get.find<HomeNavigationController>().changeTab(2, journalTab: 0);
      return;
    }
    Get.offNamed(AppRoutes.home, arguments: {'navigateToTab': 2, 'journalTabIndex': 0});
  }

  Future<void> _handleAddNotes() async {
    final result = await Get.to(() => const AddNotesScreen());
    if (result is! String || result.trim().isEmpty) return;
    final saved = await _saveCalendarNotes(result.trim());
    if (!mounted || !saved) return;
    Get.back(result: result.trim());
  }

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
          onPressed: _isSaving ? null : () => Get.back(),
        ),
        title: Text('Add Date', style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
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
                    onTap: _isSaving ? () {} : _handleAddWorkout,
                  ),
                  const SizedBox(height: 12),
                  _buildActionTile(
                    context: context,
                    imagePath: 'assets/images/runing.png',
                    iconBg: const Color(0xFFFFE8D1),
                    title: 'Add Run',
                    subtitle: 'Log a run or outdoor activity',
                    onTap: _isSaving
                        ? () {}
                        : () {
                            Get.toNamed(AppRoutes.logRun, arguments: {'selectedDate': widget.selectedDate});
                          },
                  ),
                  const SizedBox(height: 12),
                  _buildActionTile(
                    context: context,
                    imagePath: 'assets/images/camera.png',
                    iconBg: const Color(0xFFF6E6FF),
                    title: 'Add Progress Photo',
                    subtitle: 'Front or side progress photo',
                    onTap: _isSaving
                        ? () {}
                        : () {
                            if (widget.onAddProgressPhoto != null) {
                              Get.back();
                              WidgetsBinding.instance.addPostFrameCallback((_) => widget.onAddProgressPhoto!.call());
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
                    onTap: _isSaving ? () {} : _handleAddNotes,
                  ),
                ],
              ),
            ),
          ),
          if (_isSaving)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
              ),
            ),
        ],
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
