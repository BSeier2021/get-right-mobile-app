import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/repo/running_log_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/planner_day_reuse.dart';
import 'package:get_right/views/home/dashboard_screen.dart';
import 'package:get_right/views/planner/add_manual_run_screen.dart';
import 'package:get_right/views/planner/add_notes_screen.dart';
import 'package:get_right/views/planner/calendar_type_dialog.dart';
import 'package:intl/intl.dart';

class AddDateScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String? calendarEntryId;
  final Map<String, dynamic>? dayData;
  final VoidCallback? onAddProgressPhoto;
  final VoidCallback? onAddNotes;

  const AddDateScreen({
    super.key,
    required this.selectedDate,
    this.calendarEntryId,
    this.dayData,
    this.onAddProgressPhoto,
    this.onAddNotes,
  });

  @override
  State<AddDateScreen> createState() => _AddDateScreenState();
}

class _AddDateScreenState extends State<AddDateScreen> {
  final CalendarRepository _calendarRepo = CalendarRepository();
  final RunningLogRepository _runningLogRepo = RunningLogRepository();
  bool _isSaving = false;

  bool get _hasExistingEntry {
    final id = widget.calendarEntryId?.trim();
    return id != null && WorkoutRepository.isValidMongoId(id);
  }

  List<PlannerReuseOption> get _reuseOptions => PlannerDayReuse.optionsFromDayData(widget.dayData);

  String get _formattedDate => DateFormat.yMMMMd().format(widget.selectedDate);

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
    if (_reuseOptions.any((o) => o.kind == PlannerReuseKind.warmup || o.kind == PlannerReuseKind.workout)) {
      _showReuseSheet(forWorkout: true);
      return;
    }
    _openWorkoutJournal(startFresh: true);
  }

  void _handleAddRun() {
    if (_reuseOptions.any((o) => o.kind == PlannerReuseKind.plannedRoute || o.kind == PlannerReuseKind.savedActivity)) {
      _showReuseSheet(forWorkout: false);
      return;
    }
    _showRunOptionsSheet();
  }

  void _showRunOptionsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.35), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add Run',
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Log manually or track with GPS',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                ),
                const SizedBox(height: 16),
                _buildRunOptionTile(
                  icon: Icons.edit_note_outlined,
                  title: 'Log manually',
                  subtitle: 'Enter distance, duration, and activity type',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openManualRunScreen();
                  },
                ),
                const SizedBox(height: 10),
                _buildRunOptionTile(
                  icon: Icons.gps_fixed,
                  title: 'Track with GPS',
                  subtitle: 'Use live tracking on the map',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openRunnerLog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRunOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FFE9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accent.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
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

  Future<void> _openManualRunScreen() async {
    final result = await Get.to(
      () => AddManualRunScreen(
        selectedDate: widget.selectedDate,
        calendarEntryId: widget.calendarEntryId,
      ),
    );
    if (!mounted || result != 'manual_run') return;
    Get.back(result: 'manual_run');
  }

  void _showReuseSheet({required bool forWorkout}) {
    final options = forWorkout
        ? _reuseOptions.where((o) => o.kind == PlannerReuseKind.warmup || o.kind == PlannerReuseKind.workout).toList()
        : _reuseOptions.where((o) => o.kind == PlannerReuseKind.plannedRoute || o.kind == PlannerReuseKind.savedActivity).toList();
    if (options.isEmpty) {
      if (forWorkout) {
        _openWorkoutJournal(startFresh: true);
      } else {
        _showRunOptionsSheet();
      }
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.35), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  forWorkout ? 'Reuse existing entries?' : 'Reuse route or activity?',
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'This day already has logged content. Continue with what you have or start fresh.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                ),
                const SizedBox(height: 16),
                ...options.map((option) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildReuseOptionTile(
                        option: option,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          if (forWorkout) {
                            _openWorkoutJournal(startFresh: false, journalId: option.journalId);
                          } else {
                            _openRunnerLog(routeId: option.routeId, runningLogId: option.runningLogId);
                          }
                        },
                      ),
                    )),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      if (forWorkout) {
                        _openWorkoutJournal(startFresh: true);
                      } else {
                        _showRunOptionsSheet();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(forWorkout ? 'Start new workout' : 'Start new run', style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReuseOptionTile({required PlannerReuseOption option, required VoidCallback onTap}) {
    final icon = switch (option.kind) {
      PlannerReuseKind.warmup => Icons.self_improvement_outlined,
      PlannerReuseKind.workout => Icons.fitness_center_outlined,
      PlannerReuseKind.plannedRoute => Icons.route_outlined,
      PlannerReuseKind.savedActivity => Icons.directions_run_outlined,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FFE9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accent.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(option.subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ),
              Text(
                'Reuse',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWorkoutJournal({required bool startFresh, String? journalId}) {
    _navigateToJournalTab(0, result: 'workout_journal', startFresh: startFresh, journalId: journalId);
  }

  Future<void> _openRunnerLog({String? routeId, String? runningLogId}) async {
    var resolvedRouteId = WorkoutRepository.isValidMongoId(routeId) ? routeId!.trim() : null;
    if (resolvedRouteId == null && WorkoutRepository.isValidMongoId(runningLogId)) {
      try {
        resolvedRouteId = await _runningLogRepo.fetchRouteIdForRunningLog(runningLogId!.trim());
      } catch (_) {
        /* fall through without route id */
      }
    }
    if (!mounted) return;
    _navigateToJournalTab(1, result: 'runner_log', plannedRouteId: resolvedRouteId);
  }

  void _setPlannerContext({bool startFresh = false, String? journalId, String? plannedRouteId}) {
    if (!Get.isRegistered<HomeNavigationController>()) return;
    Get.find<HomeNavigationController>().setJournalPlannerContext(
      date: widget.selectedDate,
      journalId: journalId,
      startFresh: startFresh,
      plannedRouteId: plannedRouteId,
    );
  }

  Map<String, dynamic> _journalPlannerContextArgs({bool startFresh = false, String? journalId, String? plannedRouteId}) {
    return {
      'date': widget.selectedDate.toIso8601String(),
      if (journalId != null) 'journalId': journalId,
      'startFresh': startFresh,
      if (plannedRouteId != null) 'plannedRouteId': plannedRouteId,
    };
  }

  void _navigateToJournalTab(int journalTabIndex, {required String result, bool startFresh = false, String? journalId, String? plannedRouteId}) {
    Get.back(result: result);
    Get.back();
    if (Get.isRegistered<HomeNavigationController>()) {
      if (Get.currentRoute != AppRoutes.home) {
        Get.until((route) => route.settings.name == AppRoutes.home);
      }
      final nav = Get.find<HomeNavigationController>();
      nav.changeTab(2, journalTab: journalTabIndex);
      _setPlannerContext(startFresh: startFresh, journalId: journalId, plannedRouteId: plannedRouteId);
      return;
    }
    _setPlannerContext(startFresh: startFresh, journalId: journalId, plannedRouteId: plannedRouteId);
    Get.offNamed(
      AppRoutes.home,
      arguments: {
        'navigateToTab': 2,
        'journalTabIndex': journalTabIndex,
        'journalPlannerContext': _journalPlannerContextArgs(startFresh: startFresh, journalId: journalId, plannedRouteId: plannedRouteId),
      },
    );
  }

  Future<void> _handleAddNotes() async {
    final result = await Get.to(() => const AddNotesScreen());
    if (result is! String || result.trim().isEmpty) return;
    final saved = await _saveCalendarNotes(result.trim());
    if (!mounted || !saved) return;
    Get.back(result: result.trim());
  }

  void _reuseEntryDirectly(PlannerReuseOption option) {
    switch (option.kind) {
      case PlannerReuseKind.warmup:
      case PlannerReuseKind.workout:
        _openWorkoutJournal(startFresh: false, journalId: option.journalId);
      case PlannerReuseKind.plannedRoute:
        _openRunnerLog(routeId: option.routeId, runningLogId: option.runningLogId);
      case PlannerReuseKind.savedActivity:
        _openRunnerLog(routeId: option.routeId, runningLogId: option.runningLogId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reuseOptions = _reuseOptions;

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
                    'Add to $_formattedDate',
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text('Log something for this day', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  if (reuseOptions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Already on this day',
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reuse entries instead of starting from scratch',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                    ),
                    const SizedBox(height: 12),
                    ...reuseOptions.map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildReuseOptionTile(
                          option: option,
                          onTap: _isSaving ? () {} : () => _reuseEntryDirectly(option),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  _buildActionTile(
                    context: context,
                    imagePath: 'assets/images/Vector.png',
                    iconBg: const Color(0xFFDFF1D3),
                    title: 'Add Workout',
                    subtitle: reuseOptions.any((o) => o.kind == PlannerReuseKind.warmup || o.kind == PlannerReuseKind.workout)
                        ? 'Add another workout or reuse existing'
                        : 'Log a gym or home workout',
                    onTap: _isSaving ? () {} : _handleAddWorkout,
                  ),
                  const SizedBox(height: 12),
                  _buildActionTile(
                    context: context,
                    imagePath: 'assets/images/runing.png',
                    iconBg: const Color(0xFFFFE8D1),
                    title: 'Add Run',
                    subtitle: reuseOptions.any((o) => o.kind == PlannerReuseKind.plannedRoute || o.kind == PlannerReuseKind.savedActivity)
                        ? 'Add another run, log manually, or track with GPS'
                        : 'Log manually or track with GPS',
                    onTap: _isSaving ? () {} : _handleAddRun,
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
                              Get.back(result: 'progress_photo');
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
