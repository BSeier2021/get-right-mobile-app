import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get_right/models/run_model.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/planner/add_date_screen.dart';
import 'package:get_right/views/planner/calendar_type_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// Planner screen - workout plans and calendar with color-coded entries
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  bool _isCalendarCollapsed = false;
  final ImagePicker _imagePicker = ImagePicker();
  final CalendarRepository _calendarRepo = CalendarRepository();

  Map<DateTime, Map<String, dynamic>> _dayData = {};
  bool _isLoadingCalendar = false;
  bool _isLoadingDayDetail = false;
  String? _calendarLoadError;
  String? _dayDetailError;
  bool _isDeletingEntry = false;
  bool _isMarkingComplete = false;
  bool _isMovingProgramWorkout = false;

  bool get _hasDeletableEntry => _calendarEntryIdForSelectedDate() != null;

  bool get _canMoveProgramWorkout {
    final data = _getDataForDate(_selectedDate);
    return data?['program'] != null && _calendarEntryIdForSelectedDate() != null;
  }

  bool get _canMarkAsComplete {
    final status = _getDataForDate(_selectedDate)?['workoutStatus']?.toString();
    return status != 'completed' && status != 'rest';
  }

  @override
  void initState() {
    super.initState();
    _loadCalendarMonth();
  }

  Future<void> _loadCalendarMonth() async {
    setState(() {
      _isLoadingCalendar = true;
      _calendarLoadError = null;
    });
    try {
      final data = await _calendarRepo.fetchCalendarMonth(year: _focusedMonth.year, month: _focusedMonth.month);
      if (!mounted) return;
      setState(() {
        _dayData = data;
        _isLoadingCalendar = false;
      });
      await _loadSelectedDayDetail();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCalendar = false;
        _calendarLoadError = CalendarRepository.errorMessageFrom(e);
      });
    }
  }

  void _changeFocusedMonth(DateTime month) {
    setState(() {
      _focusedMonth = month;
      _isCalendarCollapsed = false;
    });
    _loadCalendarMonth();
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _isCalendarCollapsed = true;
      _dayDetailError = null;
    });
    _loadSelectedDayDetail();
  }

  Future<void> _loadSelectedDayDetail() async {
    final summary = _getDataForDate(_selectedDate);
    final entryId = summary?['calendarEntryId']?.toString();
    if (entryId == null || entryId.isEmpty) return;

    setState(() {
      _isLoadingDayDetail = true;
      _dayDetailError = null;
    });

    try {
      final detail = await _calendarRepo.fetchCalendarEntry(entryId);
      if (!mounted) return;
      setState(() {
        final key = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        _dayData[key] = detail;
        _isLoadingDayDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDayDetail = false;
        _dayDetailError = CalendarRepository.errorMessageFrom(e);
      });
    }
  }

  String _formatRunTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatPace(double paceMinPerKm) {
    if (paceMinPerKm == 0 || paceMinPerKm.isInfinite || paceMinPerKm.isNaN) {
      return '--:-- /km';
    }
    final minutes = paceMinPerKm.floor();
    final seconds = ((paceMinPerKm - minutes) * 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} /km';
  }

  Map<String, dynamic>? _getDataForDate(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return _dayData[key];
  }

  bool _dayHasVisibleContent(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['hasProgressPhoto'] == true) return true;
    if (data['workout'] != null) return true;
    if (data['program'] != null) return true;
    if (data['run'] != null) return true;
    if (data['nutrition'] != null) return true;
    final notes = data['notes']?.toString().trim();
    return notes != null && notes.isNotEmpty;
  }

  String _formatProgramRest(dynamic seconds) {
    final value = seconds is num ? seconds.toInt() : int.tryParse(seconds?.toString() ?? '');
    if (value == null || value <= 0) return '';
    if (value >= 60) {
      final mins = value ~/ 60;
      final secs = value % 60;
      return secs == 0 ? '${mins}m rest' : '${mins}m ${secs}s rest';
    }
    return '${value}s rest';
  }

  Color _getDateColor(DateTime date) {
    final data = _getDataForDate(date);
    if (data == null) return Colors.transparent;

    final status = data['workoutStatus'];

    // Completed workouts: Green
    if (status == 'completed') return const Color(0xFF6FCF97);
    // Planned/incomplete workouts: Red
    if (status == 'incomplete') return const Color(0xFFE74C3C);
    // Rest day: Blue
    if (status == 'rest') return const Color(0xFF4A90E2);

    return Colors.transparent;
  }

  bool _hasProgressPhoto(DateTime date) {
    final data = _getDataForDate(date);
    return data?['hasProgressPhoto'] ?? false;
  }

  Future<void> _addProgressPhoto() async {
    // Check if selected date is in the future
    final now = DateTime.now();
    final selectedDateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final nowDateOnly = DateTime(now.year, now.month, now.day);

    if (selectedDateOnly.isAfter(nowDateOnly)) {
      Get.snackbar(
        'Invalid Date',
        'Progress photos are not allowed for future dates',
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Show options for front or side photo
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: AppColors.blackOverlay, blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Add Progress Photo',
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Choose front or side photo', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                const SizedBox(height: 24),
                _buildShareOptionTile(
                  icon: Icons.camera_front,
                  title: 'Front Photo',
                  subtitle: 'Capture from the front',
                  onTap: () {
                    Navigator.pop(context);
                    _capturePhoto('front');
                  },
                ),
                const SizedBox(height: 12),
                _buildShareOptionTile(
                  icon: Icons.camera_alt,
                  title: 'Side Photo',
                  subtitle: 'Capture from the side',
                  onTap: () {
                    Navigator.pop(context);
                    _capturePhoto('side');
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _calendarEntryIdForSelectedDate() {
    return CalendarRepository.entryIdForDate(_dayData, _selectedDate);
  }

  Future<void> _persistCalendarNotes(String notes) async {
    final entryId = _calendarEntryIdForSelectedDate();

    try {
      if (entryId != null) {
        await _calendarRepo.updateCalendarEntry(calendarEntryId: entryId, notes: notes);
      } else {
        final type = await showCalendarTypeDialog(context);
        if (type == null || !mounted) return;
        await _calendarRepo.createCalendarEntry(date: _selectedDate, type: type, notes: notes);
      }

      if (!mounted) return;
      await _loadCalendarMonth();
      await _loadSelectedDayDetail();
      Get.snackbar('Saved', 'Notes updated', backgroundColor: AppColors.completed, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      if (!mounted) return;
      await showCalendarErrorDialog(context, e);
    }
  }

  Future<void> _persistProgressPhoto(File photo, String type) async {
    final entryId = _calendarEntryIdForSelectedDate();
    final existingNotes = _getDataForDate(_selectedDate)?['notes']?.toString();

    try {
      if (entryId != null) {
        await _calendarRepo.updateCalendarEntry(
          calendarEntryId: entryId,
          notes: existingNotes?.trim().isNotEmpty == true ? existingNotes!.trim() : null,
          progressPhotoFiles: [photo],
        );
      } else {
        final entryType = await showCalendarTypeDialog(context);
        if (entryType == null || !mounted) return;
        await _calendarRepo.createCalendarEntry(date: _selectedDate, type: entryType, notes: '$type progress photo', progressPhotoFiles: [photo]);
      }

      if (!mounted) return;
      await _loadCalendarMonth();
      await _loadSelectedDayDetail();
      Get.snackbar('Success', '$type photo added successfully', backgroundColor: AppColors.completed, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      if (!mounted) return;
      await showCalendarErrorDialog(context, e);
    }
  }

  Future<void> _confirmDeleteCalendarEntry() async {
    final entryId = _calendarEntryIdForSelectedDate();
    if (entryId == null || _isDeletingEntry) return;

    final dateLabel = DateFormat('MMM d, yyyy').format(_selectedDate);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete entry?', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
        content: Text('Remove this calendar entry for $dateLabel? This cannot be undone.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteCalendarEntry(entryId);
    }
  }

  Future<void> _deleteCalendarEntry(String entryId) async {
    setState(() => _isDeletingEntry = true);
    try {
      await _calendarRepo.deleteCalendarEntry(calendarEntryId: entryId);
      if (!mounted) return;

      setState(() {
        final key = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        _dayData.remove(key);
        _dayDetailError = null;
      });

      await _loadCalendarMonth();
      if (!mounted) return;
      Get.snackbar('Deleted', 'Calendar entry removed', backgroundColor: AppColors.completed, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      if (!mounted) return;
      await showCalendarErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _isDeletingEntry = false);
    }
  }

  Widget _buildMarkAsCompleteButton() {
    if (!_canMarkAsComplete) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isMarkingComplete ? null : _markAsComplete,
          icon: _isMarkingComplete
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onError))
              : const Icon(Icons.check_circle_outline, size: 20),
          label: Text(_isMarkingComplete ? 'Marking...' : 'Mark as Complete'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.onError,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          ),
        ),
      ),
    );
  }

  Future<void> _markAsComplete() async {
    setState(() => _isMarkingComplete = true);
    try {
      final entryId = _calendarEntryIdForSelectedDate();
      if (entryId != null) {
        await _calendarRepo.updateCalendarEntry(calendarEntryId: entryId, type: CalendarRepository.typeCompleted);
      } else {
        await _calendarRepo.createCalendarEntry(date: _selectedDate, type: CalendarRepository.typeCompleted);
      }

      if (!mounted) return;
      await _loadCalendarMonth();
      if (!mounted) return;
      Get.snackbar('Success', 'Day marked as complete', backgroundColor: AppColors.completed, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      if (!mounted) return;
      await showCalendarErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _isMarkingComplete = false);
    }
  }

  Future<void> _showMoveProgramWorkoutSheet() async {
    final entryId = _calendarEntryIdForSelectedDate();
    if (entryId == null || !_canMoveProgramWorkout) return;

    final program = _getDataForDate(_selectedDate)?['program'];
    final title = program is Map ? program['title']?.toString() ?? 'Program Workout' : 'Program Workout';
    DateTime targetDate = _selectedDate.add(const Duration(days: 1));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(top: 12, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.event_repeat, color: AppColors.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Move Workout', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Reschedule this program workout to another day', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close, color: AppColors.primaryGray),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FFE9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE8EFE0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          'Currently on ${DateFormat.yMMMd().format(_selectedDate)}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Move To', style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: targetDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) {
                          setModalState(() => targetDate = DateTime(picked.year, picked.month, picked.day));
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.accent.withOpacity(0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, color: AppColors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                DateFormat.yMMMd().format(targetDate),
                                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.primaryGray),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isMovingProgramWorkout
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);
                              await _moveProgramWorkout(targetDate);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      ),
                      icon: _isMovingProgramWorkout
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
                          : const Icon(Icons.swap_horiz),
                      label: Text(_isMovingProgramWorkout ? 'Moving...' : 'Move Workout', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _moveProgramWorkout(DateTime targetDate) async {
    final entryId = _calendarEntryIdForSelectedDate();
    if (entryId == null) return;

    final normalizedTarget = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final normalizedSelected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (normalizedTarget == normalizedSelected) {
      Get.snackbar('Move Workout', 'Choose a different date', backgroundColor: AppColors.error, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _isMovingProgramWorkout = true);
    try {
      await _calendarRepo.moveProgramWorkout(calendarEntryId: entryId, targetDate: normalizedTarget);
      if (!mounted) return;

      setState(() {
        _selectedDate = normalizedTarget;
        _isCalendarCollapsed = true;
        _dayDetailError = null;
        if (_focusedMonth.year != normalizedTarget.year || _focusedMonth.month != normalizedTarget.month) {
          _focusedMonth = DateTime(normalizedTarget.year, normalizedTarget.month);
        }
      });

      await _loadCalendarMonth();
      if (!mounted) return;
      Get.snackbar(
        'Moved',
        'Workout moved to ${DateFormat.yMMMd().format(normalizedTarget)}',
        backgroundColor: AppColors.completed,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      if (!mounted) return;
      await showCalendarErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _isMovingProgramWorkout = false);
    }
  }

  Future<void> _capturePhoto(String type) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);

      if (photo != null) {
        await _persistProgressPhoto(File(photo.path), type);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to capture photo: $e', backgroundColor: AppColors.error, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _showAddWorkoutDialog() {
    Get.to(
      () => AddDateScreen(selectedDate: _selectedDate, calendarEntryId: _calendarEntryIdForSelectedDate(), onAddProgressPhoto: _addProgressPhoto, onAddNotes: _showNotesDialog),
    )?.then((_) async {
      if (!mounted) return;
      await _loadCalendarMonth();
      await _loadSelectedDayDetail();
    });
  }

  String? _progressPhotoUrl(DateTime date, int index) {
    final photos = _getDataForDate(date)?['progressPhotos'];
    if (photos is! List || index >= photos.length) return null;
    final photo = photos[index];
    if (photo is Map) return photo['url']?.toString();
    return null;
  }

  void _showNotesDialog() {
    final data = _getDataForDate(_selectedDate);
    final currentNotes = data?['notes'] ?? '';
    final notesController = TextEditingController(text: currentNotes);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Daily Notes', style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent)),
        content: TextField(
          controller: notesController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Add notes for this day...',
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primaryGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              final notes = notesController.text.trim();
              Navigator.pop(context);
              await _persistCalendarNotes(notes);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.onAccent),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _markAsRestDay() {
    setState(() {
      final key = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      _dayData[key] = {'workoutStatus': 'rest', 'hasProgressPhoto': false, 'workout': null, 'run': null, 'nutrition': null, 'notes': _dayData[key]?['notes'] ?? ''};
    });

    Get.snackbar('Success', 'Day marked as rest day', backgroundColor: const Color(0xFF4A90E2), colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
  }

  void _showPhotoHistory() {
    // Get all dates with progress photos
    final photoDates = _dayData.entries.where((entry) => entry.value['hasProgressPhoto'] == true).map((entry) => entry.key).toList();

    if (photoDates.isEmpty) {
      Get.snackbar('No Photos', 'You haven\'t added any progress photos yet', backgroundColor: AppColors.error, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // Sort dates in descending order (newest first)
    photoDates.sort((a, b) => b.compareTo(a));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.onPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Progress Photo History',
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.onPrimary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // Photo Timeline
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: photoDates.length,
                itemBuilder: (context, index) {
                  final date = photoDates[index];
                  return _buildPhotoHistoryItem(date, index == 0);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoHistoryItem(DateTime date, bool isLatest) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLatest ? AppColors.accent : AppColors.primaryGray, width: isLatest ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                _formatDate(date),
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (isLatest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    'Latest',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _viewPhotoFullScreen(date, 'front');
                  },
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_front, size: 50, color: AppColors.primaryGray),
                        const SizedBox(height: 8),
                        Text('Front Photo', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                        const SizedBox(height: 4),
                        Text('Tap to view', style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _viewPhotoFullScreen(date, 'side');
                  },
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt, size: 50, color: AppColors.primaryGray),
                        const SizedBox(height: 8),
                        Text('Side Photo', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                        const SizedBox(height: 4),
                        Text('Tap to view', style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _viewPhotoFullScreen(DateTime date, String type) {
    final photoIndex = type == 'front' ? 0 : 1;
    final photoUrl = _progressPhotoUrl(date, photoIndex);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.camera_alt, color: AppColors.onPrimary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${type == 'front' ? 'Front' : 'Side'} Photo',
                                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
                              ),
                              Text(_formatDate(date), style: AppTextStyles.labelSmall.copyWith(color: AppColors.onPrimary.withOpacity(0.8))),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.onPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Photo placeholder
                  Container(
                    height: 400,
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.primaryGrayLight, borderRadius: BorderRadius.circular(12)),
                    child: photoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 400,
                              errorBuilder: (_, __, ___) => Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(type == 'front' ? Icons.camera_front : Icons.camera_alt, size: 80, color: AppColors.primaryGray),
                                  const SizedBox(height: 16),
                                  Text('Could not load photo', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(type == 'front' ? Icons.camera_front : Icons.camera_alt, size: 80, color: AppColors.primaryGray),
                              const SizedBox(height: 16),
                              Text('Photo Preview', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareOptions() {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title row with close button
              Row(
                children: [
                  const Spacer(),
                  Text(
                    'Share Options',
                    style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red.shade300, width: 1.5),
                      ),
                      child: Icon(Icons.close, size: 16, color: Colors.red.shade400),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Choose how you want to share your activity', style: AppTextStyles.bodySmall.copyWith(color: AppColors.black)),
              const SizedBox(height: 20),
              // Share Summary tile
              _buildShareOptionTile(
                icon: Icons.assignment_outlined,
                title: 'Share Summary',
                subtitle: 'Share workout summary to\nsocial media',
                onTap: () {
                  Navigator.pop(context);
                  _showSharePreview('summary');
                },
              ),
              const SizedBox(height: 12),
              // Share Workout Details tile
              _buildShareOptionTile(
                icon: Icons.download_for_offline_outlined,
                title: 'Share Workout Details',
                subtitle: 'Share workout details with\na friend',
                onTap: () {
                  Navigator.pop(context);
                  _showSharePreview('download');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareOptionTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F7E4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryGray.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primaryGray, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  void _showSharePreview(String type) {
    final data = _getDataForDate(_selectedDate);

    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    Text(
                      'Share Preview',
                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red.shade300, width: 1.5),
                        ),
                        child: Icon(Icons.close, size: 16, color: Colors.red.shade400),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Content
              Flexible(
                child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 0), child: _buildSharePreviewContent(type, data)),
              ),
              // Share Button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!Get.isSnackbarOpen) {
                          Get.snackbar(
                            'Shared',
                            'Content shared successfully',
                            backgroundColor: AppColors.completed,
                            colorText: AppColors.onError,
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        }
                      });
                    },
                    icon: const Icon(Icons.share_rounded, size: 20),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentVariant,
                      foregroundColor: AppColors.onAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSharePreviewContent(String type, Map<String, dynamic>? data) {
    if (type == 'download') {
      return _buildDownloadPreviewCard(data);
    } else {
      return _buildSummaryPreviewCard(data);
    }
  }

  /// Screenshot 1 â€“ Workout Summary card
  Widget _buildSummaryPreviewCard(Map<String, dynamic>? data) {
    final workout = data?['workout'] as Map<String, dynamic>?;
    final duration = workout?['duration'] ?? 'N/A';
    final exercises = workout?['exercises']?.toString() ?? '0';
    final sets = workout?['sets']?.toString() ?? '0';
    final calories = workout?['calories']?.toString() ?? '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workout Summary',
            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Duration row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Duration', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
              Text(
                duration,
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stat boxes row
          Row(
            children: [
              Expanded(child: _buildPreviewStatCircle('assets/images/Vector.png', exercises, 'Exercises')),
              const SizedBox(width: 10),
              Expanded(child: _buildPreviewStatCircle('assets/images/sets111.png', sets, 'Sets')),
              const SizedBox(width: 10),
              Expanded(child: _buildPreviewStatCircle('assets/images/Subtract (2).png', calories, 'Calories')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStatCircle(String imagePath, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Image.asset(imagePath, width: 22, height: 22, color: AppColors.primaryGray),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
          ),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 10)),
        ],
      ),
    );
  }

  /// Screenshot 2 â€“ Workout Download / Details card
  Widget _buildDownloadPreviewCard(Map<String, dynamic>? data) {
    final workout = data?['workout'] as Map<String, dynamic>?;
    final duration = workout?['duration'] ?? '55:00';
    final calories = workout?['calories']?.toString() ?? '450';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.fitness_center, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shoulder',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    Text(_formatDate(_selectedDate), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz, color: AppColors.primaryGray, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          // Exercise name
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.10), shape: BoxShape.circle),
                child: const Icon(Icons.fitness_center, color: AppColors.accent, size: 14),
              ),
              const SizedBox(width: 10),
              Text(
                'Overhead Press',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Exercise table
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                // Table header
                Row(
                  children: [
                    const SizedBox(width: 30),
                    Expanded(
                      child: Text(
                        'Sets',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Reps',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Weight',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                _buildSetRow('01', '10', '165'),
                const SizedBox(height: 6),
                _buildSetRow('02', '12', '165'),
                const SizedBox(height: 6),
                _buildSetRow('03', '14', '165'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Duration & Calories
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.timer_outlined, color: AppColors.primaryGray, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        duration,
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                      ),
                      Text('Duration', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 10)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.local_fire_department_outlined, color: AppColors.primaryGray, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        calories,
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                      ),
                      Text('Calories', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Info banner
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primaryGray, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Recipients can import this workout into their calendar', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(String set, String reps, String weight) {
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            set,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            reps,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            weight,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
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
          onPressed: () => Get.back(),
        ),
        title: Text('Calendar', style: AppTextStyles.titleLarge.copyWith(color: AppColors.black)),
        centerTitle: true,
        actions: [
          if (_isCalendarCollapsed && _hasDeletableEntry)
            IconButton(
              tooltip: 'Delete entry',
              onPressed: _isDeletingEntry ? null : _confirmDeleteCalendarEntry,
              icon: _isDeletingEntry
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error))
                  : const Icon(Icons.delete_outline, color: AppColors.error),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            if (!_isCalendarCollapsed) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(const Color(0xFFE74C3C), 'Incomplete'),
                    const SizedBox(width: 12),
                    _buildLegendItem(const Color(0xFF6FCF97), 'Completed'),
                    const SizedBox(width: 12),
                    _buildLegendItem(const Color(0xFF4A90E2), 'Rest Day'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Top: Year + Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppColors.onSurface),
                    onPressed: () => _changeFocusedMonth(DateTime(_focusedMonth.year - 1, _focusedMonth.month)),
                  ),
                  Text('${_focusedMonth.year}', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppColors.onSurface),
                    onPressed: () => _changeFocusedMonth(DateTime(_focusedMonth.year + 1, _focusedMonth.month)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.white,
                        hintText: 'Search exercise',
                        hintStyle: AppTextStyles.titleSmall.copyWith(color: AppColors.primaryGrayDark.withOpacity(0.6), fontSize: 14.sp),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide(color: AppColors.primaryGrayDark.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide(color: AppColors.primaryGrayDark.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide(color: AppColors.accent.withOpacity(0.3), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        suffixIcon: IconButton(
                          icon: SizedBox(width: 22, height: 22, child: SvgPicture.asset('assets/icons/search-normal.svg', width: 22, height: 22)),
                          onPressed: () => () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ).paddingOnly(right: 12),
                      ),
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Calendar
            Column(
              children: [
                // Month label (tap to expand/collapse)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isCalendarCollapsed = !_isCalendarCollapsed;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          _getMonthName(_focusedMonth.month),
                          style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Icon(_isCalendarCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: AppColors.primaryGray, size: 20),
                      ],
                    ),
                  ),
                ),

                // Weekday headers
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                        .map(
                          (day) => SizedBox(
                            width: 40,
                            child: Center(
                              child: Text(day, style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGray)),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),

                if (_calendarLoadError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      _calendarLoadError!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                    ),
                  ),
                if (_isLoadingCalendar)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  )
                else
                  _buildCalendarGrid(),
                const SizedBox(height: 16),

                // Pagination dots below calendar (hidden when collapsed)
                if (!_isCalendarCollapsed)
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.3), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.3), shape: BoxShape.circle),
                        ),
                      ],
                    ),
                  ).paddingOnly(bottom: 16),
              ],
            ),
            const SizedBox(height: 24),

            // Day detail view (only shown when calendar is collapsed / date selected)
            if (_isCalendarCollapsed) ...[_buildDayDetailView(), const SizedBox(height: 80)],
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;
    final totalItems = firstWeekday + daysInMonth;

    // Determine if we should show collapsed (single week) view
    final bool isCollapsed = _isCalendarCollapsed && _selectedDate.month == _focusedMonth.month && _selectedDate.year == _focusedMonth.year;

    // Calculate the row that contains the selected date
    int collapsedRowStart = 0;
    if (isCollapsed) {
      final selectedGridIndex = firstWeekday + _selectedDate.day - 1;
      final selectedRow = selectedGridIndex ~/ 7;
      collapsedRowStart = selectedRow * 7;
    }

    final int displayItemCount = isCollapsed ? 7 : totalItems;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < 0) {
            // Swipe left â†’ next month
            _changeFocusedMonth(DateTime(_focusedMonth.year, _focusedMonth.month + 1));
          } else if (details.primaryVelocity! > 0) {
            // Swipe right â†’ previous month
            _changeFocusedMonth(DateTime(_focusedMonth.year, _focusedMonth.month - 1));
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: isCollapsed ? 1.0 : 0.75),
            itemCount: displayItemCount,
            itemBuilder: (context, index) {
              // Map builder index to actual grid index
              final actualIndex = isCollapsed ? (collapsedRowStart + index) : index;

              // Empty cell for leading blanks or trailing overflow
              if (actualIndex < firstWeekday || actualIndex >= totalItems) {
                return const SizedBox();
              }

              final day = actualIndex - firstWeekday + 1;
              final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
              final isSelected = _selectedDate.year == date.year && _selectedDate.month == date.month && _selectedDate.day == date.day;
              final isToday = DateTime.now().year == date.year && DateTime.now().month == date.month && DateTime.now().day == date.day;
              final dateColor = _getDateColor(date);

              return GestureDetector(
                onTap: () => _selectDate(date),
                onLongPress: () {
                  _selectDate(date);
                  _showAddWorkoutDialog();
                },
                child: Builder(
                  builder: (context) {
                    final int position = actualIndex - firstWeekday;
                    final int rowIndex = position >= 0 ? (position / 7).floor() : 0;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        border: !isCollapsed && rowIndex > 0 ? Border(top: BorderSide(color: AppColors.primaryGray.withOpacity(0.3), width: 1)) : null,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isToday && !isSelected ? Border.all(color: AppColors.accent, width: 1.6) : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isSelected)
                              Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(color: Color(0xFFE74C3C), shape: BoxShape.circle),
                              ),
                            Text(
                              '$day',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isSelected ? Colors.white : (isToday ? AppColors.onBackground : AppColors.onSurface),
                                fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (dateColor != Colors.transparent)
                              Positioned(
                                bottom: 6,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(color: dateColor, shape: BoxShape.circle),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDayDetailView() {
    if (_isLoadingDayDetail) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    if (_dayDetailError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Text(
                _dayDetailError!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _loadSelectedDayDetail, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final data = _getDataForDate(_selectedDate);

    if (data == null || !_dayHasVisibleContent(data)) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.calendar_month_outlined, size: 60, color: AppColors.green),
              const SizedBox(height: 16),
              Text('No data for this day', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.green)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Data'),
                  onPressed: _showAddWorkoutDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              _buildMarkAsCompleteButton(),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Progress Photos Section with swipe hint
          if (data['hasProgressPhoto']) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Text('Swipe left for Progress Pictures', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray))],
            ),
            const SizedBox(height: 8),
            // Pagination dots for progress photos
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.3), shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.3), shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildProgressPhotosSection(),
            const SizedBox(height: 12),
          ],

          // Program Workout (mapped from enrolled program)
          if (data['program'] != null) _buildProgramWorkoutSection(data['program']),

          // Workout Summary
          if (data['workout'] != null) _buildWorkoutSummarySection(data['workout']),

          // Run Summary
          if (data['run'] != null) _buildRunSummarySection(data['run']),

          // Simple Calories Card (when only run calories available, no nutrition card)
          if (data['run'] != null && data['nutrition'] == null && data['workout'] == null) _buildSimpleCaloriesCard(data['run']),

          // Nutrition Summary
          if (data['nutrition'] != null) _buildNutritionSummarySection(data['nutrition']),

          // Notes Section
          if (data['notes'] != null && data['notes'].toString().isNotEmpty) _buildNotesSection(data['notes']),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showAddWorkoutDialog,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Add'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(color: AppColors.accent.withOpacity(0.8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showShareOptions,
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  ),
                ),
              ),
            ],
          ),
          _buildMarkAsCompleteButton(),
        ],
      ),
    );
  }

  Widget _buildProgressPhotosSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: AppColors.blackOverlay.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress Pictures',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _showPhotoHistory,
                icon: const Icon(Icons.history, size: 16),
                label: const Text('History'),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _viewPhotoFullScreen(_selectedDate, 'front'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGrayLight.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_front_rounded, size: 36, color: AppColors.primaryGray),
                          const SizedBox(height: 8),
                          Text('Front Photo', style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface)),
                          const SizedBox(height: 2),
                          Text('Tap to view', style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _viewPhotoFullScreen(_selectedDate, 'side'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGrayLight.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded, size: 36, color: AppColors.primaryGray),
                          const SizedBox(height: 8),
                          Text('Side Photo', style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface)),
                          const SizedBox(height: 2),
                          Text('Tap to view', style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgramWorkoutSection(Map<String, dynamic> program) {
    final title = program['title']?.toString() ?? 'Program Workout';
    final status = program['status']?.toString().toLowerCase() ?? '';
    final difficulty = program['difficulty']?.toString() ?? '';
    final exerciseCount = (program['exerciseCount'] as num?)?.toInt() ?? 0;
    final totalSets = (program['totalSets'] as num?)?.toInt() ?? 0;
    final exercises = program['exercises'] is List ? (program['exercises'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'completed':
        statusColor = const Color(0xFF6FCF97);
        statusLabel = 'Completed';
        break;
      case 'incomplete':
        statusColor = const Color(0xFFE74C3C);
        statusLabel = 'Incomplete';
        break;
      default:
        statusColor = AppColors.accent;
        statusLabel = status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Scheduled';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EFE0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.fitness_center, color: AppColors.accent, size: 22),
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
                    if (difficulty.isNotEmpty) ...[const SizedBox(height: 4), Text(difficulty, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray))],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  statusLabel,
                  style: AppTextStyles.labelSmall.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildWorkoutStatBox('assets/images/Vector.png', '$exerciseCount', 'Exercises')),
              const SizedBox(width: 10),
              Expanded(child: _buildWorkoutStatBox('assets/images/sets111.png', '$totalSets', 'Sets')),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Today\'s Exercises',
            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...exercises.asMap().entries.map((entry) => _buildProgramExerciseTile(entry.value, entry.key + 1)),
          if (_canMoveProgramWorkout) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _isMovingProgramWorkout ? null : _showMoveProgramWorkoutSheet,
                icon: _isMovingProgramWorkout
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                    : const Icon(Icons.event_repeat, size: 18),
                label: Text(_isMovingProgramWorkout ? 'Moving...' : 'Move to Another Date'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent.withOpacity(0.7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgramExerciseTile(Map<String, dynamic> ex, int order) {
    final name = (ex['exerciseName'] ?? ex['name'])?.toString().trim();
    final displayName = name != null && name.isNotEmpty ? name : 'Exercise $order';
    final sets = ex['numberOfSets'] ?? ex['sets'];
    final reps = ex['numberOfReps'] ?? ex['reps'];
    final rest = _formatProgramRest(ex['restSeconds'] ?? ex['restTime']);
    final weight = ex['weight'];
    final description = (ex['exerciseDescription'] ?? ex['description'])?.toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text(
                  '$order',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayName,
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (sets != null || reps != null || weight != null || rest.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (sets != null) _buildProgramMetricChip(Icons.repeat, '$sets sets'),
                if (reps != null) _buildProgramMetricChip(Icons.fitness_center, '$reps reps'),
                if (weight != null && (weight is num ? weight > 0 : double.tryParse(weight.toString()) != null && double.parse(weight.toString()) > 0))
                  _buildProgramMetricChip(Icons.scale, '${weight is num ? (weight % 1 == 0 ? weight.toInt() : weight) : weight} kg'),
                if (rest.isNotEmpty) _buildProgramMetricChip(Icons.timer_outlined, rest),
              ],
            ),
          ],
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _buildProgramMetricChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutSummarySection(Map<String, dynamic> workout) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Expanded(
                child: Text(
                  'Workout Summary',
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              GestureDetector(
                onTap: () => _showShareOptions(),
                child: Icon(Icons.share, color: AppColors.primaryGray, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Duration row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Duration', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
              Text(
                workout['duration'] ?? 'N/A',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stat boxes row
          Row(
            children: [
              Expanded(child: _buildWorkoutStatBox('assets/icons/nutrition.svg', workout['exercises'].toString(), 'Exercises')),
              const SizedBox(width: 10),
              Expanded(child: _buildWorkoutStatBox('assets/icons/nutrition.svg', workout['sets'].toString(), 'Sets')),
              const SizedBox(width: 10),
              Expanded(child: _buildWorkoutStatBox('assets/icons/nutrition.svg', workout['calories'].toString(), 'Calories')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutStatBox(String iconPath, String value, String label) {
    String imagePath;
    if (label == 'Exercises') {
      imagePath = 'assets/images/Vector.png';
    } else if (label == 'Sets') {
      imagePath = 'assets/images/sets111.png';
    } else {
      imagePath = 'assets/images/Subtract (2).png';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Image.asset(imagePath, width: 24, height: 24, color: AppColors.primaryGray),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSimpleCaloriesCard(Map<String, dynamic> run) {
    final calories = run['calories']?.toString() ?? '0';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppColors.blackOverlay.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.local_fire_department, color: AppColors.primaryGray, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Calories', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
          const Spacer(),
          Text(
            calories,
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRunSummarySection(Map<String, dynamic> run) {
    return GestureDetector(
      onTap: () => _viewRunDetails(run),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withOpacity(0.4)),
          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.directions_run, color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Running Summary',
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showShareOptions(),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.share_rounded, color: AppColors.accent, size: 22),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.route, 'Distance', run['distance'] ?? '0 km'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.timer, 'Time', run['time'] ?? '0:00'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.speed, 'Pace', run['pace'] ?? '--:-- /km'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.local_fire_department, 'Calories', (run['calories'] ?? 0).toString()),
          ],
        ),
      ),
    );
  }

  void _viewRunDetails(Map<String, dynamic> runData) {
    try {
      // If we have the actual RunModel stored, use it directly
      if (runData['runModel'] != null && runData['runModel'] is RunModel) {
        Get.toNamed(AppRoutes.runDetail, arguments: runData['runModel'] as RunModel);
        return;
      }

      // Otherwise, parse the run data from planner format to RunModel
      // Parse distance (e.g., "3.00 km" -> 3000 meters)
      final distanceStr = runData['distance']?.toString() ?? '0 km';
      final distanceMatch = RegExp(r'([\d.]+)\s*km').firstMatch(distanceStr);
      final distanceKm = distanceMatch != null ? double.tryParse(distanceMatch.group(1) ?? '0') ?? 0.0 : 0.0;
      final distanceMeters = distanceKm * 1000;

      // Parse time (e.g., "20:00" -> Duration)
      final timeStr = runData['time']?.toString() ?? '0:00';
      final timeParts = timeStr.split(':');
      final minutes = timeParts.length >= 1 ? int.tryParse(timeParts[0]) ?? 0 : 0;
      final seconds = timeParts.length >= 2 ? int.tryParse(timeParts[1]) ?? 0 : 0;
      final duration = Duration(minutes: minutes, seconds: seconds);

      // Parse pace (e.g., "4:00 /km" -> averagePace in min/km)
      final paceStr = runData['pace']?.toString() ?? '0:00 /km';
      final paceMatch = RegExp(r'(\d+):(\d+)\s*\/km').firstMatch(paceStr);
      final paceMinutes = paceMatch != null ? int.tryParse(paceMatch.group(1) ?? '0') ?? 0 : 0;
      final paceSeconds = paceMatch != null ? int.tryParse(paceMatch.group(2) ?? '0') ?? 0 : 0;
      final averagePace = paceMinutes + (paceSeconds / 60.0);

      // Get calories
      final calories = runData['calories'] is int ? runData['calories'] as int : (runData['calories'] is String ? int.tryParse(runData['calories'].toString()) ?? 0 : 0);

      // Create RunModel from parsed data
      final runModel = RunModel(
        id: runData['id'] ?? 'planner_${_selectedDate.millisecondsSinceEpoch}',
        userId: 'current_user',
        activityType: 'run',
        distanceMeters: distanceMeters,
        duration: duration,
        startTime: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, DateTime.now().hour, DateTime.now().minute),
        endTime: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, DateTime.now().hour, DateTime.now().minute).add(duration),
        averagePace: averagePace,
        caloriesBurned: calories > 0 ? calories : null,
        createdAt: _selectedDate,
      );

      Get.toNamed(AppRoutes.runDetail, arguments: runModel);
    } catch (e) {
      Get.snackbar('Error', 'Unable to view run details: $e', backgroundColor: AppColors.error, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Widget _buildNutritionSummarySection(Map<String, dynamic> nutrition) {
    // Parse numeric values from nutrition strings
    String caloriesVal = nutrition['calories']?.toString().split('/').first ?? '0';
    String proteinVal = nutrition['protein']?.toString().replaceAll('g', '') ?? '0';
    String carbsVal = nutrition['carbs']?.toString().replaceAll('g', '') ?? '0';
    String fatsVal = nutrition['fats']?.toString().replaceAll('g', '') ?? '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with serving controls
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nutrition (per serving)',
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Icon(Icons.remove_circle_outline, color: AppColors.primaryGray, size: 22),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '1.0',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Icon(Icons.add_circle_outline, color: AppColors.primaryGray, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Top row: Calories + Protein
          Row(
            children: [
              Expanded(child: _buildNutritionBox(caloriesVal, 'Calories kcal', const Color(0xFFE8F5E0), AppColors.onSurface)),
              const SizedBox(width: 12),
              Expanded(child: _buildNutritionBox(proteinVal, 'Protein g', const Color(0xFFE8F5E0), AppColors.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          // Bottom row: Carbs + Fats
          Row(
            children: [
              Expanded(child: _buildNutritionBox(carbsVal, 'Carbs g', const Color(0xFFE8F5E0), AppColors.onSurface)),
              const SizedBox(width: 12),
              Expanded(child: _buildNutritionBox(fatsVal, 'Fats g', const Color(0xFFFCDDD5), const Color(0xFFD94E2A))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionBox(String value, String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(color: textColor, fontWeight: FontWeight.bold, fontSize: 28),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: textColor.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildNotesSection(String notes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: AppColors.blackOverlay.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.note_alt_rounded, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Notes',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showNotesDialog,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.edit_rounded, size: 20, color: AppColors.primaryGray),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(notes, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryGray, size: 18),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return 'Today\'s Schedule';
    }
    // Format as "DEC 5, 2025" to match design
    final monthAbbrev = DateFormat('MMM').format(date).toUpperCase();
    return '$monthAbbrev ${date.day}, ${date.year}';
  }
}
