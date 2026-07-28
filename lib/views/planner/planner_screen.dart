import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get_right/models/run_model.dart';
import 'package:get_right/models/shared_content_model.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/repo/running_log_repo.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/services/share_to_chat_service.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/planner/add_date_screen.dart';
import 'package:get_right/views/planner/calendar_type_dialog.dart';
import 'package:get_right/widgets/safe_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

/// Planner screen - workout plans and calendar with color-coded entries
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, this.initialDate});

  final DateTime? initialDate;

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
  bool _isRemovingRun = false;
  bool _isMarkingComplete = false;
  bool _isMovingProgramWorkout = false;
  late final PageController _progressPhotoPageController;
  int _progressPhotoPageIndex = 0;
  String? _uploadingProgressPhotoType;
  bool _pendingDayDetailLoad = false;
  final Map<String, Map<String, String>> _localProgressPhotoPathsByDate = {};

  String _localPhotoStorageKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  void _setLocalProgressPhotoPath(DateTime date, String type, String path) {
    final storageKey = _localPhotoStorageKey(date);
    _localProgressPhotoPathsByDate.putIfAbsent(storageKey, () => {})[type] = path;
  }

  String? _localProgressPhotoPath(DateTime date, String type) {
    final path = _localProgressPhotoPathsByDate[_localPhotoStorageKey(date)]?[type];
    if (path == null) return null;
    if (!File(path).existsSync()) {
      _localProgressPhotoPathsByDate[_localPhotoStorageKey(date)]?.remove(type);
      return null;
    }
    return path;
  }

  void _clearLocalProgressPhotoPath(DateTime date, String type) {
    _localProgressPhotoPathsByDate[_localPhotoStorageKey(date)]?.remove(type);
  }

  void _scheduleProgressPhotoAction(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  Future<void> _afterBottomSheetDismiss(Future<void> Function() action) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    await action();
  }

  bool get _hasDeletableEntry => _calendarEntryIdForSelectedDate() != null;

  bool get _canMoveProgramWorkout {
    final data = _getDataForDate(_selectedDate);
    if (CalendarRepository.isRestDayData(data)) return false;
    final program = data?['program'];
    if (program is! Map || _calendarEntryIdForSelectedDate() == null) return false;
    final programMap = Map<String, dynamic>.from(program);
    if (_isProgramMovedToAnotherDay(programMap) || _isProgramWorkoutCompleted(programMap)) return false;
    return true;
  }

  bool _isProgramWorkoutCompleted(Map<String, dynamic> program) {
    final status = _programEntryStatusRaw(program);
    return status == 'completed';
  }

  bool _isProgramMovedToAnotherDay(Map<String, dynamic> program) {
    final status = _programEntryStatusRaw(program);
    return status.contains('moved');
  }

  String _programEntryStatusRaw(Map<String, dynamic> program) {
    return program['status']?.toString().toLowerCase().trim() ?? '';
  }

  String _programScheduleStatusLabel(Map<String, dynamic> program) {
    final raw = program['status']?.toString().trim() ?? '';
    if (raw.isEmpty) return '';
    if (raw.length == 1) return raw.toUpperCase();
    return raw[0].toUpperCase() + raw.substring(1);
  }

  bool get _isSelectedDayRestDay => CalendarRepository.isRestDayData(_getDataForDate(_selectedDate));

  bool get _canAddWorkoutToSelectedDay => !_isSelectedDayRestDay;

  bool get _canMarkAsComplete {
    if (_isSelectedDateInFuture) return false;
    final data = _getDataForDate(_selectedDate);
    if (!_canMarkDayCompleted(data)) return false;
    if (CalendarRepository.isRestDayData(data)) return false;
    if (_isCalendarDayMarkedComplete(data)) return false;
    return true;
  }

  bool _canMarkDayCompleted(Map<String, dynamic>? data) {
    if (CalendarRepository.isRestDayData(data)) return false;
    if (_dayHasLoggedData(data)) return true;
    return data?['program'] != null;
  }

  bool get _canSetDayStatus => true;

  String? _calendarEntryStatus(Map<String, dynamic>? data) {
    if (data == null) return null;
    final rawType = data['calendarEntryType']?.toString();
    if (rawType != null && rawType.trim().isNotEmpty) {
      return CalendarRepository.workoutStatusFromType(rawType);
    }
    if (_calendarEntryIdForSelectedDate() == null) return null;
    if (data['program'] == null) {
      return data['workoutStatus']?.toString();
    }
    return null;
  }

  bool _isCalendarDayMarkedComplete(Map<String, dynamic>? data) {
    return CalendarRepository.isCompletedDayData(data);
  }

  bool _isCalendarDayMarkedRest(Map<String, dynamic>? data) {
    return CalendarRepository.isRestDayData(data);
  }

  void _showRestDayBlockedMessage() {
    Get.snackbar(
      'Rest Day',
      'This day is marked as a rest day. Change the day status before adding workouts.',
      backgroundColor: AppColors.error,
      colorText: AppColors.onError,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _showIncompleteProgramWorkoutBlockedMessage() {
    Get.snackbar(
      'Complete Program Workout',
      'You cannot mark this day as complete until you complete your scheduled program workout',
      backgroundColor: AppColors.error,
      colorText: AppColors.onError,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  bool _hasIncompleteScheduledProgramWorkout(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (!_hasCalendarEntry(data)) return false;
    if (_isCalendarDayMarkedRest(data)) return false;
    final program = data['program'];
    if (program is! Map) return false;
    final status = program['status']?.toString().toLowerCase().trim() ?? '';
    return status != 'completed';
  }

  String? get _selectedDayStatusLabel {
    final status = _calendarEntryStatus(_getDataForDate(_selectedDate));
    return switch (status) {
      'completed' => 'Completed',
      'incomplete' => 'Incomplete',
      'inprogress' => 'In Progress',
      'rest' => 'Rest Day',
      _ => null,
    };
  }

  bool get _isSelectedDateInFuture {
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return selected.isAfter(_todayDate);
  }

  DateTime get _todayDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _dateOnOrAfterToday(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.isBefore(_todayDate) ? _todayDate : normalized;
  }

  bool _isPastDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.isBefore(_todayDate);
  }

  DateTime? _resolveInitialDate() {
    if (widget.initialDate != null) {
      final d = widget.initialDate!;
      return DateTime(d.year, d.month, d.day);
    }
    final args = Get.arguments;
    if (args is Map) {
      final raw = args['selectedDate'];
      if (raw is DateTime) return DateTime(raw.year, raw.month, raw.day);
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final initial = _resolveInitialDate();
    if (initial != null) {
      _selectedDate = DateTime(initial.year, initial.month, initial.day);
      _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    }
    _progressPhotoPageController = PageController();
    _loadCalendarMonth();
  }

  @override
  void dispose() {
    _progressPhotoPageController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await _loadCalendarMonth(isRefresh: true);
    if (_isCalendarCollapsed) {
      await _loadSelectedDayDetail(isRefresh: true);
    }
  }

  Future<void> _loadCalendarMonth({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (!isRefresh) {
        _isLoadingCalendar = true;
      }
      _calendarLoadError = null;
    });
    try {
      final fetched = await _calendarRepo.fetchCalendarMonth(year: _focusedMonth.year, month: _focusedMonth.month);
      if (!mounted) return;
      setState(() {
        final merged = <DateTime, Map<String, dynamic>>{};
        for (final entry in fetched.entries) {
          final existing = CalendarRepository.dayDataForDate(_dayData, entry.key);
          merged[entry.key] = CalendarRepository.mergeDayData(existing, entry.value);
        }
        for (final entry in _dayData.entries) {
          final key = CalendarRepository.normalizedDate(entry.key);
          if (key.year != _focusedMonth.year || key.month != _focusedMonth.month) continue;
          if (merged.containsKey(key)) continue;
          if (CalendarRepository.entryIdForDate(_dayData, key) != null || CalendarRepository.dayHasProgressPhotos(entry.value)) {
            merged[key] = entry.value;
          }
        }
        _dayData = merged;
        _isLoadingCalendar = false;
      });
      await _applyStoredRunCaloriesToDayData();
      if (_pendingDayDetailLoad || _isCalendarCollapsed) {
        await _loadSelectedDayDetail();
      }
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
      _progressPhotoPageIndex = 0;
      _pendingDayDetailLoad = true;
    });
    if (_progressPhotoPageController.hasClients) {
      _progressPhotoPageController.jumpToPage(0);
    }
    _loadSelectedDayDetail();
  }

  Future<void> _loadSelectedDayDetail({bool isRefresh = false}) async {
    if (_isLoadingCalendar) {
      _pendingDayDetailLoad = true;
      return;
    }

    final entryId = CalendarRepository.entryIdForDate(_dayData, _selectedDate);
    if (entryId == null) {
      if (mounted) {
        setState(() {
          _pendingDayDetailLoad = false;
          _isLoadingDayDetail = false;
        });
      }
      return;
    }
    if (!mounted) return;

    setState(() {
      if (!isRefresh) {
        _isLoadingDayDetail = true;
      }
      _dayDetailError = null;
    });

    try {
      final detail = await _calendarRepo.fetchCalendarEntry(entryId);
      if (!mounted) return;
      setState(() {
        final key = CalendarRepository.normalizedDate(_selectedDate);
        final existing = _dayData[key];
        _dayData[key] = CalendarRepository.mergeDayData(existing, detail);
        CalendarRepository.expandProgramScheduleInMap(_dayData);
        _isLoadingDayDetail = false;
        _pendingDayDetailLoad = false;
      });
      await _applyStoredRunCaloriesToDayData();
      if (CalendarRepository.progressPhotoUrlForType(detail['progressPhotos'], 'front') != null) {
        _clearLocalProgressPhotoPath(_selectedDate, 'front');
      }
      if (CalendarRepository.progressPhotoUrlForType(detail['progressPhotos'], 'side') != null) {
        _clearLocalProgressPhotoPath(_selectedDate, 'side');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDayDetail = false;
        _dayDetailError = CalendarRepository.errorMessageFrom(e);
        _pendingDayDetailLoad = false;
      });
    }
  }

  Future<Map<String, int>> _storedRunCaloriesById() async {
    if (!Get.isRegistered<StorageService>()) return const {};
    final runs = await Get.find<StorageService>().getRuns();
    final map = <String, int>{};
    for (final run in runs) {
      final calories = run.caloriesBurned;
      if (calories == null || calories <= 0) continue;
      final backendId = run.backendLogId?.trim();
      if (backendId != null && backendId.isNotEmpty) {
        map[backendId] = calories;
      }
      final id = run.id.trim();
      if (id.isNotEmpty) {
        map[id] = calories;
      }
    }
    return map;
  }

  Future<void> _applyStoredRunCaloriesToDayData() async {
    final caloriesByRunId = await _storedRunCaloriesById();
    if (caloriesByRunId.isEmpty || !mounted) return;
    setState(() {
      _dayData = CalendarRepository.applyStoredRunCalories(_dayData, caloriesByRunId);
    });
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
    return CalendarRepository.dayDataForDate(_dayData, date);
  }

  bool _hasCalendarEntry(Map<String, dynamic>? data) {
    final id = data?['calendarEntryId']?.toString();
    return id != null && id.isNotEmpty;
  }

  bool _dayHasVisibleContent(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (_isCalendarDayMarkedRest(data)) return true;
    if (data['program'] != null && _hasCalendarEntry(data)) return true;
    return _dayHasLoggedData(data);
  }

  bool _dayHasLoggedData(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['hasProgressPhoto'] == true) return true;
    if (data['workout'] != null) return true;
    if (CalendarRepository.runsFromDayData(data).isNotEmpty) return true;
    if (data['nutrition'] != null) return true;
    final notes = CalendarRepository.displayNotesFrom(data['notes']?.toString());
    return notes.isNotEmpty;
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

    if (_isCalendarDayMarkedRest(data)) return const Color(0xFF4A90E2);

    final program = data['program'];
    if (program is Map && _hasCalendarEntry(data)) {
      switch (program['status']?.toString().toLowerCase()) {
        case 'completed':
          return const Color(0xFF6FCF97);
        case 'incomplete':
          return const Color(0xFFE74C3C);
        case 'rest':
          return const Color(0xFF4A90E2);
      }
    }

    final status = data['workoutStatus'];

    // Completed workouts: Green
    if (status == 'completed') return const Color(0xFF6FCF97);
    // In progress workouts: Accent
    if (status == 'inprogress') return AppColors.accent;
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

    final frontUrl = _progressPhotoUrlByType(_selectedDate, 'front');
    final sideUrl = _progressPhotoUrlByType(_selectedDate, 'side');

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
                  decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Progress Photo',
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Add or replace front and side photos', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                const SizedBox(height: 24),
                _buildShareOptionTile(
                  icon: Icons.camera_front,
                  title: frontUrl == null ? 'Add Front Photo' : 'Replace Front Photo',
                  subtitle: 'Capture from the front',
                  onTap: () {
                    Navigator.pop(context);
                    _scheduleProgressPhotoAction(() => _pickProgressPhoto('front'));
                  },
                ),
                const SizedBox(height: 12),
                _buildShareOptionTile(
                  icon: Icons.camera_alt,
                  title: sideUrl == null ? 'Add Side Photo' : 'Replace Side Photo',
                  subtitle: 'Capture from the side',
                  onTap: () {
                    Navigator.pop(context);
                    _scheduleProgressPhotoAction(() => _pickProgressPhoto('side'));
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

  Future<void> _pickProgressPhoto(String type) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.accent),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;
    await _afterBottomSheetDismiss(() => _capturePhoto(type, source: source));
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
        await _calendarRepo.createCalendarEntry(
          date: _selectedDate,
          type: type,
          notes: notes,
          durationInSeconds: CalendarRepository.typeRequiresDuration(type)
              ? CalendarRepository.durationSecondsForDayComplete(_getDataForDate(_selectedDate))
              : null,
        );
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

  Future<void> _resolveCalendarEntryIdForSelectedDate() async {
    try {
      final fetched = await _calendarRepo.fetchCalendarMonth(year: _selectedDate.year, month: _selectedDate.month);
      if (!mounted) return;
      setState(() {
        for (final entry in fetched.entries) {
          if (!CalendarRepository.isSameCalendarDay(entry.key, _selectedDate)) continue;
          final key = CalendarRepository.normalizedDate(entry.key);
          _dayData[key] = CalendarRepository.mergeDayData(_dayData[key], entry.value);
        }
      });
      if (_calendarEntryIdForSelectedDate() != null) {
        await _loadSelectedDayDetail();
      }
    } catch (_) {
      /* best-effort lookup before create */
    }
  }

  Future<void> _persistProgressPhoto(File photo, String type) async {
    setState(() => _uploadingProgressPhotoType = type);
    try {
      var entryId = _calendarEntryIdForSelectedDate();
      if (entryId == null) {
        await _resolveCalendarEntryIdForSelectedDate();
        entryId = _calendarEntryIdForSelectedDate();
      }
      final userNotes = CalendarRepository.displayNotesFrom(_getDataForDate(_selectedDate)?['notes']?.toString());
      final key = CalendarRepository.normalizedDate(_selectedDate);
      final existingPhotos = _getDataForDate(_selectedDate)?['progressPhotos'];
      final replacePhotoId = CalendarRepository.progressPhotoIdFromDayData(_getDataForDate(_selectedDate), type) ??
          CalendarRepository.progressPhotoIdForSlot(existingPhotos, type);
      final removePhotoIds = replacePhotoId != null ? [replacePhotoId] : null;

      Map<String, dynamic> response;
      if (entryId != null) {
        response = await _calendarRepo.updateCalendarEntry(
          calendarEntryId: entryId,
          notes: userNotes.isEmpty ? null : userNotes,
          progressPhotoFiles: [photo],
          progressPhotoType: type,
          removeProgressPhotoIds: removePhotoIds,
        );
      } else {
        final entryType = await showCalendarTypeDialog(context);
        if (entryType == null || !mounted) return;
        final dayData = _getDataForDate(_selectedDate);
        response = await _calendarRepo.createCalendarEntry(
          date: _selectedDate,
          type: entryType,
          notes: userNotes.isEmpty ? null : userNotes,
          progressPhotoFiles: [photo],
          progressPhotoType: type,
          durationInSeconds: CalendarRepository.typeRequiresDuration(entryType)
              ? CalendarRepository.durationSecondsForDayComplete(dayData)
              : null,
        );
      }

      if (!mounted) return;

      _setLocalProgressPhotoPath(_selectedDate, type, photo.path);
      final mutationDay = CalendarRepository.dayDataFromMutationResponse(response);
      if (mutationDay != null) {
        setState(() {
          _dayData[key] = CalendarRepository.mergeDayData(
            _dayData[key],
            mutationDay,
            incomingProgressPhotoType: type,
          );
        });
      } else {
        setState(() {
          final existing = _dayData[key];
          final photos = existing?['progressPhotos'] is List
              ? List<Map<String, dynamic>>.from((existing!['progressPhotos'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)))
              : <Map<String, dynamic>>[];
          _dayData[key] = CalendarRepository.mergeDayData(existing, {
            'calendarEntryId': entryId ?? CalendarRepository.entryIdFrom(response),
            'hasProgressPhoto': true,
            'progressPhotos': CalendarRepository.upsertProgressPhoto(
              photos: photos,
              type: type,
              replacement: {
                'url': photo.path,
                'slot': type,
                'fieldName': CalendarRepository.progressPhotoFieldForSlot(type),
                'local': true,
              },
            ),
            if (userNotes.isNotEmpty) 'notes': userNotes,
          });
        });
      }

      await _refreshSelectedDayProgressPhotos();
      if (!mounted) return;
      Get.snackbar('Success', '$type photo added successfully', backgroundColor: AppColors.completed, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      if (!mounted) return;
      await showCalendarErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _uploadingProgressPhotoType = null);
    }
  }

  Future<void> _refreshSelectedDayProgressPhotos() async {
    final key = CalendarRepository.normalizedDate(_selectedDate);
    final entryId = _calendarEntryIdForSelectedDate();
    if (entryId == null) return;

    try {
      final detail = await _calendarRepo.fetchCalendarEntry(entryId);
      if (!mounted) return;
      setState(() {
        final existing = _dayData[key];
        _dayData[key] = CalendarRepository.mergeDayData(existing, detail);
      });
      if (CalendarRepository.progressPhotoUrlForType(detail['progressPhotos'], 'front') != null) {
        _clearLocalProgressPhotoPath(_selectedDate, 'front');
      }
      if (CalendarRepository.progressPhotoUrlForType(detail['progressPhotos'], 'side') != null) {
        _clearLocalProgressPhotoPath(_selectedDate, 'side');
      }
    } catch (_) {
      /* keep optimistic local state if detail refresh fails */
    }
  }

  Future<void> _reloadProgressPhotoDaysInMonth() async {
    try {
      final fetched = await _calendarRepo.fetchCalendarMonth(year: _focusedMonth.year, month: _focusedMonth.month);
      if (!mounted) return;
      setState(() {
        for (final entry in fetched.entries) {
          if (!CalendarRepository.dayHasProgressPhotos(entry.value)) continue;
          final key = CalendarRepository.normalizedDate(entry.key);
          _dayData[key] = CalendarRepository.mergeDayData(_dayData[key], entry.value);
        }
      });

      final entryId = _calendarEntryIdForSelectedDate();
      if (entryId != null) {
        await _refreshSelectedDayProgressPhotos();
      }
    } catch (_) {
      /* keep existing photo state if refresh fails */
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
        final key = CalendarRepository.normalizedDate(_selectedDate);
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

  Widget _buildDayStatusActions() {
    if (!_canSetDayStatus) return const SizedBox.shrink();

    final dayData = _getDataForDate(_selectedDate);
    final currentStatus = _selectedDayStatusLabel;
    final isCompletedDay = _isCalendarDayMarkedComplete(dayData);
    final blockedByIncompleteProgram = _hasIncompleteScheduledProgramWorkout(dayData);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          if (currentStatus != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Current status: $currentStatus',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (!isCompletedDay)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isMarkingComplete ? null : _showSetDayStatusSheet,
                icon: _isMarkingComplete
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                    : const Icon(Icons.event_available_outlined, size: 20),
                label: Text(_isMarkingComplete ? 'Saving...' : 'Set Day Status'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent.withValues(alpha: 0.8)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
              ),
            ),
          if (_canMarkAsComplete) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isMarkingComplete
                    ? null
                    : () {
                        if (blockedByIncompleteProgram) {
                          _showIncompleteProgramWorkoutBlockedMessage();
                          return;
                        }
                        _applyDayStatus(CalendarRepository.typeCompleted);
                      },
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('Quick Mark Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: blockedByIncompleteProgram ? AppColors.primaryGray.withValues(alpha: 0.45) : AppColors.accent,
                  foregroundColor: AppColors.onError,
                  disabledBackgroundColor: AppColors.primaryGray.withValues(alpha: 0.45),
                  disabledForegroundColor: AppColors.onError.withValues(alpha: 0.8),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showSetDayStatusSheet() async {
    final dayData = _getDataForDate(_selectedDate);
    final isRestDay = _isCalendarDayMarkedRest(dayData);
    final isCompletedDay = _isCalendarDayMarkedComplete(dayData);

    final selectedType = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Set Day Status',
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSelectedDateInFuture
                      ? 'Plan a rest day on your calendar'
                      : 'Choose how this day appears on your calendar',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                ),
                const SizedBox(height: 24),
                if (!_isSelectedDateInFuture && !isRestDay) ...[
                  _buildStatusOptionTile(
                    icon: Icons.check_circle_outline,
                    iconBg: const Color(0xFFDFF1D3),
                    iconColor: const Color(0xFF6FCF97),
                    title: 'Completed',
                    subtitle: 'Finished activity for this day',
                    onTap: () => Navigator.pop(sheetContext, CalendarRepository.typeCompleted),
                  ),
                  const SizedBox(height: 12),
                  _buildStatusOptionTile(
                    icon: Icons.timelapse,
                    iconBg: const Color(0xFFFFF0D8),
                    iconColor: AppColors.accent,
                    title: 'In Progress',
                    subtitle: 'Still working on this day\'s activity',
                    onTap: () => Navigator.pop(sheetContext, CalendarRepository.typeInProgress),
                  ),
                  const SizedBox(height: 12),
                  _buildStatusOptionTile(
                    icon: Icons.pending_outlined,
                    iconBg: const Color(0xFFFFE8E8),
                    iconColor: const Color(0xFFE74C3C),
                    title: 'Incomplete',
                    subtitle: 'Did not finish or skipped this activity',
                    onTap: () => Navigator.pop(sheetContext, CalendarRepository.typeIncomplete),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!isCompletedDay)
                  _buildStatusOptionTile(
                    icon: Icons.hotel_outlined,
                    iconBg: const Color(0xFFDCEBFA),
                    iconColor: const Color(0xFF4A90E2),
                    title: 'Rest Day',
                    subtitle: _isSelectedDateInFuture ? 'Schedule recovery for this upcoming day' : 'Planned recovery with no workout logged',
                    onTap: () => Navigator.pop(sheetContext, CalendarRepository.typeRest),
                  ),
                if (isRestDay && !_isSelectedDateInFuture) ...[
                  const SizedBox(height: 12),
                  _buildStatusOptionTile(
                    icon: Icons.timelapse,
                    iconBg: const Color(0xFFFFF0D8),
                    iconColor: AppColors.accent,
                    title: 'In Progress',
                    subtitle: 'Remove rest day and mark activity in progress',
                    onTap: () => Navigator.pop(sheetContext, CalendarRepository.typeInProgress),
                  ),
                  const SizedBox(height: 12),
                  _buildStatusOptionTile(
                    icon: Icons.pending_outlined,
                    iconBg: const Color(0xFFFFE8E8),
                    iconColor: const Color(0xFFE74C3C),
                    title: 'Incomplete',
                    subtitle: 'Remove rest day and mark activity incomplete',
                    onTap: () => Navigator.pop(sheetContext, CalendarRepository.typeIncomplete),
                  ),
                ],

                const SizedBox(height: 20),
                const SizedBox(height: 20),

              ],
            ),
          ),
        ),
      ),
    );

    if (selectedType == null || !mounted) return;
    await _applyDayStatus(selectedType);
  }

  Future<void> _showChangeDayStatusSheet() async => _showSetDayStatusSheet();

  Widget _buildStatusOptionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
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
            border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
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

  Future<void> _applyDayStatus(String type) async {
    if (_isSelectedDateInFuture && type != CalendarRepository.typeRest) {
      Get.snackbar(
        'Invalid date',
        'Only Rest Day can be set for future dates',
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final dayData = _getDataForDate(_selectedDate);

    if (type == CalendarRepository.typeRest && _isCalendarDayMarkedComplete(dayData)) {
      Get.snackbar(
        'Cannot mark Rest Day',
        'A completed day cannot be changed to a rest day.',
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (type == CalendarRepository.typeCompleted && _hasIncompleteScheduledProgramWorkout(dayData)) {
      _showIncompleteProgramWorkoutBlockedMessage();
      return;
    }

    if (type == CalendarRepository.typeCompleted && !_canMarkDayCompleted(dayData)) {
      Get.snackbar(
        'Add data first',
        'Log a workout, run, meal, note, photo, or program workout before marking complete',
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isMarkingComplete = true);
    try {
      final durationInSeconds = CalendarRepository.typeRequiresDuration(type)
          ? CalendarRepository.durationSecondsForDayComplete(dayData)
          : null;
      final entryId = _calendarEntryIdForSelectedDate();
      if (entryId != null) {
        await _calendarRepo.updateCalendarEntry(
          calendarEntryId: entryId,
          type: type,
          durationInSeconds: durationInSeconds,
        );
      } else {
        await _calendarRepo.createCalendarEntry(
          date: _selectedDate,
          type: type,
          durationInSeconds: durationInSeconds,
        );
      }
      if (!mounted) return;
      await _loadCalendarMonth();
      if (!mounted) return;
      if (type == CalendarRepository.typeRest) {
        final key = CalendarRepository.normalizedDate(_selectedDate);
        final refreshed = _getDataForDate(_selectedDate);
        if (refreshed != null) {
          setState(() {
            _dayData[key] = CalendarRepository.applyRestDayToDayData(refreshed);
          });
        }
      } else if (type == CalendarRepository.typeInProgress) {
        final key = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        final data = _getDataForDate(_selectedDate);
        if (data != null) {
          setState(() {
            _dayData[key] = Map<String, dynamic>.from(data)..['workoutStatus'] = 'inprogress';
          });
        }
      }
      final label = switch (type) {
        CalendarRepository.typeCompleted => 'Completed',
        CalendarRepository.typeIncomplete => 'Incomplete',
        CalendarRepository.typeInProgress => 'In Progress',
        CalendarRepository.typeRest => 'Rest Day',
        _ => 'Updated',
      };
      Get.snackbar('Updated', 'Day marked as $label', backgroundColor: AppColors.completed, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      if (!mounted) return;
      await showCalendarErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _isMarkingComplete = false);
    }
  }

  Future<void> _updateDayStatus(String type) async => _applyDayStatus(type);

  Future<void> _markAsComplete() async => _applyDayStatus(CalendarRepository.typeCompleted);

  Future<void> _openProgramWorkoutScreen(Map<String, dynamic> program, {List<Map<String, dynamic>>? dayExercises, Map<String, dynamic>? dayData}) async {
    final data = dayData ?? _getDataForDate(_selectedDate);
    final workout = data?['workout'];
    final journalId = workout is Map ? workout['journalId']?.toString() : null;
    final durationSeconds = workout is Map ? (workout['durationSeconds'] as num?)?.toInt() : null;
    final workoutCalories = workout is Map ? (workout['calories'] as num?)?.toInt() : null;

    final programPayload = Map<String, dynamic>.from(program);
    if (dayExercises != null && dayExercises.isNotEmpty) {
      programPayload['exercises'] = dayExercises;
    }
    final workoutStatus = data?['workoutStatus']?.toString().toLowerCase();
    if (workoutStatus == 'completed') {
      programPayload['status'] = 'completed';
    }

    final result = await Get.toNamed(
      AppRoutes.programWorkout,
      arguments: {
        'selectedDate': _selectedDate,
        'calendarEntryId': _calendarEntryIdForSelectedDate(),
        'workoutJournalId': journalId,
        'durationSeconds': durationSeconds,
        'caloriesBurned': workoutCalories ?? programPayload['caloriesBurned'],
        'program': programPayload,
      },
    );

    if (result == true && mounted) {
      await _loadCalendarMonth();
    }
  }

  Future<void> _showMoveProgramWorkoutSheet() async {
    final entryId = _calendarEntryIdForSelectedDate();
    if (entryId == null || !_canMoveProgramWorkout) return;

    final program = _getDataForDate(_selectedDate)?['program'];
    final title = program is Map ? program['title']?.toString() ?? 'Program Workout' : 'Program Workout';
    DateTime targetDate = _dateOnOrAfterToday(_selectedDate.add(const Duration(days: 1)));

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
                      decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.event_repeat, color: AppColors.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Move Workout',
                              style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('Reschedule this program workout to today or a future date', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
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
                        Text(
                          title,
                          style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text('Currently on ${DateFormat.yMMMd().format(_selectedDate)}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Move To',
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dateOnOrAfterToday(targetDate),
                          firstDate: _todayDate,
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) {
                          setModalState(() => targetDate = _dateOnOrAfterToday(picked));
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
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
    if (_isPastDate(normalizedTarget)) {
      Get.snackbar(
        'Move Workout',
        'Program workouts can only be scheduled for today or future dates',
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
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

  Future<void> _capturePhoto(String type, {ImageSource source = ImageSource.camera}) async {
    try {
      final permitted = await _ensurePhotoPermission(source);
      if (!permitted || !mounted) return;

      final XFile? photo = await _imagePicker.pickImage(source: source, imageQuality: 85);

      if (photo != null) {
        await _persistProgressPhoto(File(photo.path), type);
      }
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', 'Failed to add photo: $e', backgroundColor: AppColors.error, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<bool> _ensurePhotoPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isGranted || status.isLimited) return true;
      if (!mounted) return false;
      Get.snackbar(
        'Permission required',
        'Camera permission is needed to take a progress photo.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        mainButton: status.isPermanentlyDenied
            ? TextButton(onPressed: () => openAppSettings(), child: const Text('Settings'))
            : null,
      );
      return false;
    }

    if (!Platform.isAndroid && !Platform.isIOS) return true;

    var status = await Permission.photos.request();
    if (status.isGranted || status.isLimited) return true;
    if (Platform.isAndroid) {
      status = await Permission.storage.request();
      if (status.isGranted) return true;
    }
    if (!mounted) return false;
    Get.snackbar(
      'Permission required',
      'Gallery permission is needed to choose a progress photo.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: AppColors.onError,
      mainButton: status.isPermanentlyDenied
          ? TextButton(onPressed: () => openAppSettings(), child: const Text('Settings'))
          : null,
    );
    return false;
  }

  void _showAddWorkoutDialog() {
    if (!_canAddWorkoutToSelectedDay) {
      _showRestDayBlockedMessage();
      return;
    }

    Get.to(
      () => AddDateScreen(
        selectedDate: _selectedDate,
        calendarEntryId: _calendarEntryIdForSelectedDate(),
        dayData: _getDataForDate(_selectedDate),
        onAddProgressPhoto: _addProgressPhoto,
        onAddNotes: _showNotesDialog,
      ),
    )?.then((result) async {
      if (!mounted || result == 'workout_journal' || result == 'runner_log') return;
      await _loadCalendarMonth();
      if (!mounted) return;
      await _loadSelectedDayDetail();
      if (result is Map && result['type'] == 'manual_run') {
        Get.snackbar(
          'Saved',
          'Run added to your calendar',
          backgroundColor: AppColors.completed,
          colorText: AppColors.onError,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      if (result == 'manual_run') {
        Get.snackbar(
          'Saved',
          'Run added to your calendar',
          backgroundColor: AppColors.completed,
          colorText: AppColors.onError,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    });
  }

  String? _progressPhotoUrlByType(DateTime date, String type) {
    final photos = _getDataForDate(date)?['progressPhotos'];
    final networkUrl = CalendarRepository.progressPhotoUrlForType(photos, type);
    if (networkUrl != null) return networkUrl;

    final isSelectedDay = CalendarRepository.isSameCalendarDay(date, _selectedDate);
    if (isSelectedDay) {
      return _localProgressPhotoPath(date, type);
    }
    return null;
  }

  void _goToProgressPhotoPage(int index) {
    if (!_progressPhotoPageController.hasClients) return;
    _progressPhotoPageController.animateToPage(index.clamp(0, 1), duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Widget _buildProgressPhotoImage({required String? photoUrl, required IconData icon, required double height}) {
    if (photoUrl == null) {
      return Center(child: Icon(icon, size: 36, color: AppColors.primaryGray));
    }

    final localFile = File(photoUrl);
    if (localFile.existsSync()) {
      return Image.file(localFile, fit: BoxFit.cover, width: double.infinity, height: height);
    }

    return SafeNetworkImage(
      url: photoUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: height,
      fallback: Center(child: Icon(icon, size: 36, color: AppColors.primaryGray)),
    );
  }

  void _handleProgressPhotoTap(DateTime date, String type) {
    final photoUrl = _progressPhotoUrlByType(date, type);
    final isSelectedDay = CalendarRepository.isSameCalendarDay(date, _selectedDate);
    if (!isSelectedDay) {
      setState(() {
        _selectedDate = date;
        _isCalendarCollapsed = true;
        _pendingDayDetailLoad = true;
      });
      _loadSelectedDayDetail();
    }

    if (photoUrl != null) {
      _showProgressPhotoActions(date, type);
      return;
    }

    _scheduleProgressPhotoAction(() => _pickProgressPhoto(type));
  }

  Future<void> _showProgressPhotoActions(DateTime date, String type) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined, color: AppColors.accent),
                title: const Text('View Photo'),
                onTap: () => Navigator.pop(sheetContext, 'view'),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.accent),
                title: Text('Replace ${type == 'front' ? 'Front' : 'Side'} Photo'),
                onTap: () => Navigator.pop(sheetContext, 'replace'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'view') {
      _viewPhotoFullScreen(date, type);
      return;
    }
    if (action == 'replace') {
      _scheduleProgressPhotoAction(() => _pickProgressPhoto(type));
    }
  }

  void _showNotesDialog() {
    final data = _getDataForDate(_selectedDate);
    final currentNotes = CalendarRepository.displayNotesFrom(data?['notes']?.toString());
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
    _applyDayStatus(CalendarRepository.typeRest);
  }

  void _showPhotoHistory() {
    final photoDates = _dayData.entries.where((entry) => CalendarRepository.dayHasProgressPhotos(entry.value)).map((entry) => entry.key).toList();

    if (photoDates.isEmpty) {
      Get.snackbar('No Photos', 'You haven\'t added any progress photos yet', backgroundColor: AppColors.error, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
      return;
    }

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
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _scheduleProgressPhotoAction(_addProgressPhoto);
                    },
                    child: Text('Add', style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
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
    ).whenComplete(() {
      if (!mounted || !_isCalendarCollapsed) return;
      _scheduleProgressPhotoAction(_reloadProgressPhotoDaysInMonth);
    });
  }

  Widget _buildPhotoHistoryItem(DateTime date, bool isLatest) {
    final frontUrl = _progressPhotoUrlByType(date, 'front');
    final sideUrl = _progressPhotoUrlByType(date, 'side');

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
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
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
                child: _buildProgressPhotoTile(
                  type: 'front',
                  photoUrl: frontUrl,
                  height: 150,
                  isLoading: _uploadingProgressPhotoType == 'front',
                  onTap: () => _handleProgressPhotoTap(date, 'front'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildProgressPhotoTile(
                  type: 'side',
                  photoUrl: sideUrl,
                  height: 150,
                  isLoading: _uploadingProgressPhotoType == 'side',
                  onTap: () => _handleProgressPhotoTap(date, 'side'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _viewPhotoFullScreen(DateTime date, String type) {
    final photoUrl = _progressPhotoUrlByType(date, type);

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
                              Text(_formatDate(date), style: AppTextStyles.labelSmall.copyWith(color: AppColors.onPrimary.withValues(alpha: 0.8))),
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
                  Container(
                    height: 400,
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.primaryGrayLight, borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.antiAlias,
                    child: photoUrl != null
                        ? _buildProgressPhotoImage(photoUrl: photoUrl, icon: type == 'front' ? Icons.camera_front : Icons.camera_alt, height: 400)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(type == 'front' ? Icons.camera_front : Icons.camera_alt, size: 80, color: AppColors.primaryGray),
                              const SizedBox(height: 16),
                              Text('No photo added yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _scheduleProgressPhotoAction(() => _pickProgressPhoto(type));
                                },
                                child: const Text('Add Photo'),
                              ),
                            ],
                          ),
                  ),
                  if (photoUrl != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _scheduleProgressPhotoAction(() => _pickProgressPhoto(type));
                          },
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text('Replace ${type == 'front' ? 'Front' : 'Side'} Photo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.8)),
                          ),
                        ),
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

  String? _runningLogIdFromRunMap(Map<String, dynamic> run) {
    final direct = run['id']?.toString().trim();
    if (WorkoutRepository.isValidMongoId(direct)) return direct;

    final runModel = run['runModel'];
    if (runModel is RunModel) {
      final backendId = runModel.backendLogId?.trim();
      if (WorkoutRepository.isValidMongoId(backendId)) return backendId;
      final localId = runModel.id.trim();
      if (WorkoutRepository.isValidMongoId(localId)) return localId;
    }
    return null;
  }

  void _shareRunToChat(Map<String, dynamic> run) {
    final runId = _runningLogIdFromRunMap(run);
    if (runId != null) {
      ShareToChatService.share(context: context, type: SharedContentType.runningLog, contentId: runId);
      return;
    }
    Get.snackbar(
      'Cannot share',
      'This run is not saved yet',
      backgroundColor: AppColors.error,
      colorText: AppColors.onError,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _shareWorkoutToChat(Map<String, dynamic> workout) {
    final journalId = workout['journalId']?.toString().trim();
    if (WorkoutRepository.isValidMongoId(journalId)) {
      ShareToChatService.share(context: context, type: SharedContentType.workoutJournal, contentId: journalId!);
      return;
    }
    Get.snackbar(
      'Cannot share',
      'This workout is not saved yet',
      backgroundColor: AppColors.error,
      colorText: AppColors.onError,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _shareSelectedDayToChat() {
    final data = _getDataForDate(_selectedDate);
    final workout = data?['workout'];
    if (workout is Map) {
      final journalId = workout['journalId']?.toString().trim();
      if (WorkoutRepository.isValidMongoId(journalId)) {
        ShareToChatService.share(context: context, type: SharedContentType.workoutJournal, contentId: journalId!);
        return;
      }
    }
    final runs = CalendarRepository.runsFromDayData(data);
    if (runs.isNotEmpty) {
      final runId = _runningLogIdFromRunMap(runs.last);
      if (runId != null) {
        ShareToChatService.share(context: context, type: SharedContentType.runningLog, contentId: runId);
        return;
      }
    }
    Get.snackbar(
      'Nothing to share',
      'Add a workout or run to this day first',
      backgroundColor: AppColors.error,
      colorText: AppColors.onError,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // void _showShareOptions() {
  //   showDialog(
  //     context: context,
  //     barrierColor: Colors.black45,
  //     builder: (context) => Dialog(
  //       backgroundColor: Colors.white,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  //       insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
  //       child: Padding(
  //         padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             // Title row with close button
  //             Row(
  //               children: [
  //                 const Spacer(),
  //                 Text(
  //                   'Share Options',
  //                   style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
  //                 ),
  //                 const Spacer(),
  //                 GestureDetector(
  //                   onTap: () => Navigator.pop(context),
  //                   child: Container(
  //                     width: 28,
  //                     height: 28,
  //                     decoration: BoxDecoration(
  //                       shape: BoxShape.circle,
  //                       border: Border.all(color: Colors.red.shade300, width: 1.5),
  //                     ),
  //                     child: Icon(Icons.close, size: 16, color: Colors.red.shade400),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             const SizedBox(height: 6),
  //             Text('Choose how you want to share your activity', style: AppTextStyles.bodySmall.copyWith(color: AppColors.black)),
  //             const SizedBox(height: 20),
  //             _buildShareOptionTile(
  //               icon: Icons.message_outlined,
  //               title: 'Share to Chat',
  //               subtitle: 'Send workout or run to a conversation',
  //               onTap: () {
                 
  //               },
  //             ),
  //             const SizedBox(height: 12),
  //             // Share Summary tile
  //             _buildShareOptionTile(
  //               icon: Icons.assignment_outlined,
  //               title: 'Share Summary',
  //               subtitle: 'Share workout summary to\nsocial media',
  //               onTap: () {
  //                 Navigator.pop(context);
  //                 _showSharePreview('summary');
  //               },
  //             ),
  //             const SizedBox(height: 12),
  //             // Share Workout Details tile
  //             _buildShareOptionTile(
  //               icon: Icons.download_for_offline_outlined,
  //               title: 'Share Workout Details',
  //               subtitle: 'Share workout details with\na friend',
  //               onTap: () {
  //                 Navigator.pop(context);
  //                 _showSharePreview('download');
  //               },
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

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
            border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
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
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.25)),
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
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2)),
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
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.25)),
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
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
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
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.10), shape: BoxShape.circle),
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
              border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2)),
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
                    border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2)),
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
                    border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2)),
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
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
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
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
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
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!_isCalendarCollapsed)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildLegendItem(const Color(0xFFE74C3C), 'Incomplete'),
                          const SizedBox(width: 8),
                          _buildLegendItem(const Color(0xFF6FCF97), 'Completed'),
                          const SizedBox(width: 8),
                          _buildLegendItem(const Color(0xFF4A90E2), 'Rest Day'),
                        ],
                      ),
                    )
               
                  else
                    const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        icon: const Icon(Icons.chevron_left, color: AppColors.onSurface),
                        onPressed: () => _changeFocusedMonth(DateTime(_focusedMonth.year - 1, _focusedMonth.month)),
                      ),
                      Text('${_focusedMonth.year}', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface,fontSize: 15.sp)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        icon: const Icon(Icons.chevron_right, color: AppColors.onSurface),
                        onPressed: () => _changeFocusedMonth(DateTime(_focusedMonth.year + 1, _focusedMonth.month)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

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
                          decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.3), shape: BoxShape.circle),
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
                          decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.3), shape: BoxShape.circle),
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
        const SizedBox(width: 5),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray,fontSize: 11.sp)),
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
                        border: !isCollapsed && rowIndex > 0 ? Border(top: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3), width: 1)) : null,
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
              if (_canAddWorkoutToSelectedDay)
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
              if (_canAddWorkoutToSelectedDay) const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Add Progress Photo'),
                  onPressed: _addProgressPhoto,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(color: AppColors.accent.withValues(alpha: 0.8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              _buildDayStatusActions(),
            ],
          ),
        ),
      );
    }

    final isRestDay = _isCalendarDayMarkedRest(data);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (isRestDay) ...[
            _buildRestDayBanner(),
            const SizedBox(height: 12),
          ],
          if (!_isSelectedDateInFuture) ...[_buildProgressPhotosSection(), const SizedBox(height: 12)],

          // Program Workout (mapped from enrolled program)
          if (data['program'] != null) _buildProgramWorkoutSection(data['program'], dayData: data, isRestDay: isRestDay),

          // Workout Summary
          if (data['workout'] != null) _buildWorkoutSummarySection(data['workout']),

          // Run summaries (supports multiple running logs per day)
          if (CalendarRepository.runsFromDayData(data).isNotEmpty)
            _buildRunsSection(CalendarRepository.runsFromDayData(data)),

          // Nutrition Summary
          if (data['nutrition'] != null) _buildNutritionSummarySection(data['nutrition']),

          // Notes Section
          if (CalendarRepository.hasUserNotes(data['notes']?.toString())) _buildNotesSection(CalendarRepository.displayNotesFrom(data['notes']?.toString())),

          const SizedBox(height: 16),

          // Action Buttons
          if (_canAddWorkoutToSelectedDay)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showAddWorkoutDialog,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: BorderSide(color: AppColors.accent.withValues(alpha: 0.8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareSelectedDayToChat,
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
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _shareSelectedDayToChat,
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
          _buildDayStatusActions(),
        ],
      ),
    );
  }

  Widget _buildProgressPhotoTile({
    required String type,
    required String? photoUrl,
    required double height,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    final label = type == 'front' ? 'Front Photo' : 'Side Photo';
    final icon = type == 'front' ? Icons.camera_front_rounded : Icons.camera_alt_rounded;
    final hasPhoto = photoUrl != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.primaryGrayLight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hasPhoto ? AppColors.accent.withValues(alpha: 0.4) : AppColors.primaryGray.withValues(alpha: 0.3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasPhoto)
                Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildProgressPhotoImage(photoUrl: photoUrl, icon: icon, height: height),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: Colors.white)),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 36, color: AppColors.primaryGray),
                    const SizedBox(height: 8),
                    Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface)),
                    const SizedBox(height: 2),
                    Text(hasPhoto ? 'Tap for options' : 'Tap to add', style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontSize: 11)),
                  ],
                ),
              if (isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Updating photo...',
                          style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressPhotosSection() {
    const photoTypes = ['front', 'side'];
    final frontUrl = _progressPhotoUrlByType(_selectedDate, 'front');
    final sideUrl = _progressPhotoUrlByType(_selectedDate, 'side');
    final hasAnyPhoto = frontUrl != null || sideUrl != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: AppColors.blackOverlay.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
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
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _uploadingProgressPhotoType != null ? null : _addProgressPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  ),
                  TextButton.icon(
                    onPressed: _showPhotoHistory,
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('History'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  ),
                ],
              ),
            ],
          ),
          Text(
            hasAnyPhoto ? 'Swipe left for front and side photos' : 'Add front and side progress photos for this day',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(photoTypes.length, (index) {
              final isActive = _progressPhotoPageIndex == index;
              return Container(
                width: 6,
                height: 6,
                margin: EdgeInsets.only(right: index == photoTypes.length - 1 ? 0 : 4),
                decoration: BoxDecoration(color: isActive ? AppColors.accent : AppColors.primaryGray.withValues(alpha: 0.3), shape: BoxShape.circle),
              );
            }),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: Row(
              children: [
                IconButton(
                  onPressed: _progressPhotoPageIndex > 0 ? () => _goToProgressPhotoPage(_progressPhotoPageIndex - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                  color: AppColors.accent,
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _progressPhotoPageController,
                    physics: const PageScrollPhysics(),
                    onPageChanged: (index) {
                      if (mounted) setState(() => _progressPhotoPageIndex = index);
                    },
                    itemCount: photoTypes.length,
                    itemBuilder: (context, index) {
                      final type = photoTypes[index];
                      final photoUrl = type == 'front' ? frontUrl : sideUrl;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _buildProgressPhotoTile(
                          type: type,
                          photoUrl: photoUrl,
                          height: 220,
                          isLoading: _uploadingProgressPhotoType == type,
                          onTap: () => _handleProgressPhotoTap(_selectedDate, type),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  onPressed: _progressPhotoPageIndex < photoTypes.length - 1 ? () => _goToProgressPhotoPage(_progressPhotoPageIndex + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                  color: AppColors.accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _programWorkoutDaysList(Map<String, dynamic> program) {
    final raw = program['workoutDays'];
    if (raw is List && raw.isNotEmpty) {
      return raw.whereType<Map>().map((day) => Map<String, dynamic>.from(day)).toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> _exercisesForProgramWorkoutDay(Map<String, dynamic> day) {
    final raw = day['exercises'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((ex) => Map<String, dynamic>.from(ex)).toList();
  }

  Widget _buildRestDayBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDCEBFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4A90E2).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Color(0xFF4A90E2), shape: BoxShape.circle),
            child: const Icon(Icons.hotel_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rest Day', style: AppTextStyles.titleSmall.copyWith(color: const Color(0xFF2F6FB3), fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Recovery day — workouts cannot be added until you change the day status.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramWorkoutSection(Map<String, dynamic> program, {Map<String, dynamic>? dayData, bool isRestDay = false}) {
    final title = program['title']?.toString() ?? 'Program Workout';
    final status = isRestDay ? 'rest' : (program['status']?.toString().toLowerCase() ?? '');
    final difficulty = program['difficulty']?.toString() ?? '';
    final workoutDays = _programWorkoutDaysList(program);
    final currentDayNumber = (program['currentDayNumber'] as num?)?.toInt() ?? (program['dayNumber'] as num?)?.toInt() ?? 0;
    final exercises = program['exercises'] is List ? (program['exercises'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
    final workoutSummary = dayData?['workout'];
    final loggedCalories = workoutSummary is Map ? (workoutSummary['calories'] as num?)?.toInt() : null;
    final programCalories = (program['caloriesBurned'] as num?)?.toInt() ?? 0;
    final displayCalories = loggedCalories ?? programCalories;
    final totalExercises = workoutDays.isNotEmpty ? workoutDays.fold<int>(0, (sum, day) => sum + _exercisesForProgramWorkoutDay(day).length) : exercises.length;
    final totalSets = workoutDays.isNotEmpty
        ? workoutDays.fold<int>(0, (sum, day) {
            return sum +
                _exercisesForProgramWorkoutDay(day).fold<int>(0, (daySum, ex) {
                  final sets = ex['numberOfSets'] ?? ex['sets'];
                  return daySum + ((sets is num) ? sets.toInt() : int.tryParse(sets?.toString() ?? '') ?? 0);
                });
          })
        : (program['totalSets'] as num?)?.toInt() ?? 0;

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
      case 'rest':
        statusColor = const Color(0xFF4A90E2);
        statusLabel = 'Rest Day';
        break;
      default:
        statusColor = status.contains('moved') ? AppColors.primaryGray : AppColors.accent;
        statusLabel = _programScheduleStatusLabel(program);
        if (statusLabel.isEmpty) statusLabel = 'Scheduled';
    }

    final scheduleStatusLabel = _programScheduleStatusLabel(program);
    final scheduleHeading = workoutDays.isNotEmpty ? 'Program Schedule' : 'Today\'s Exercises';
    final scheduleTitle = scheduleStatusLabel.isNotEmpty ? '$scheduleStatusLabel · $scheduleHeading' : scheduleHeading;
    final movedToAnotherDay = _isProgramMovedToAnotherDay(program);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EFE0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
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
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
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
              Expanded(child: _buildWorkoutStatBox('assets/images/Vector.png', '$totalExercises', 'Exercises')),
              const SizedBox(width: 10),
              Expanded(child: _buildWorkoutStatBox('assets/images/sets111.png', '$totalSets', 'Sets')),
              if (workoutDays.isNotEmpty) ...[const SizedBox(width: 10), Expanded(child: _buildWorkoutStatBox('assets/icons/time.svg', '${workoutDays.length}', 'Workout Days'))],
            ],
          ),
          if (displayCalories > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.local_fire_department, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Text(
                  '$displayCalories calories burned',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            scheduleTitle,
            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
          ),
          if (workoutDays.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              isRestDay
                  ? 'Scheduled program workout skipped for this rest day'
                  : movedToAnotherDay
                      ? 'This program workout was moved to another date'
                      : 'Full day-by-day plan from your enrolled program',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
            ),
            const SizedBox(height: 12),
            ...workoutDays.map((day) => _buildProgramWorkoutDayCard(day, currentDayNumber, program: program, dayData: dayData)),
          ] else ...[
            const SizedBox(height: 10),
            ...exercises.asMap().entries.map(
              (entry) => _buildProgramExerciseTile(
                entry.value,
                entry.key + 1,
                onTap: isRestDay ? null : () => _openProgramWorkoutScreen(program, dayData: dayData),
              ),
            ),
          ],
          if (_canMoveProgramWorkout) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: OutlinedButton.icon(
                onPressed: _isMovingProgramWorkout ? null : _showMoveProgramWorkoutSheet,
                icon: _isMovingProgramWorkout
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                    : const Icon(Icons.event_repeat, size: 18),
                label: Text(_isMovingProgramWorkout ? 'Moving...' : 'Move to Another Date'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent.withValues(alpha: 0.7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgramWorkoutDayCard(Map<String, dynamic> day, int currentDayNumber, {required Map<String, dynamic> program, Map<String, dynamic>? dayData}) {
    final dayNumber = (day['dayNumber'] as num?)?.toInt() ?? 0;
    final dayExercises = _exercisesForProgramWorkoutDay(day);
    final isCurrentDay = dayNumber > 0 && dayNumber == currentDayNumber;
    final label = dayNumber > 0 ? 'Day $dayNumber' : 'Workout Day';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCurrentDay ? AppColors.accent.withValues(alpha: 0.08) : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isCurrentDay ? AppColors.accent.withValues(alpha: 0.45) : const Color(0xFFE8EFE0), width: isCurrentDay ? 1.5 : 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isCurrentDay,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: isCurrentDay ? AppColors.accent.withValues(alpha: 0.18) : AppColors.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              dayNumber > 0 ? '$dayNumber' : '•',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: isCurrentDay ? FontWeight.w800 : FontWeight.w700),
                ),
              ),
              if (isCurrentDay)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    'Today',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 10),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            dayExercises.isEmpty ? 'No exercises listed' : '${dayExercises.length} exercise${dayExercises.length == 1 ? '' : 's'}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
          ),
          iconColor: AppColors.accent,
          collapsedIconColor: AppColors.primaryGray,
          children: dayExercises.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Exercises for this day will appear here.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  ),
                ]
              : dayExercises.asMap().entries
                    .map(
                      (entry) => _buildProgramExerciseTile(
                        entry.value,
                        entry.key + 1,
                        onTap: () => _openProgramWorkoutScreen(program, dayExercises: dayExercises, dayData: dayData),
                      ),
                    )
                    .toList(),
        ),
      ),
    );
  }

  Widget _buildProgramExerciseTile(Map<String, dynamic> ex, int order, {VoidCallback? onTap}) {
    final name = (ex['exerciseName'] ?? ex['name'])?.toString().trim();
    final displayName = name != null && name.isNotEmpty ? name : 'Exercise $order';
    final sets = ex['numberOfSets'] ?? ex['sets'];
    final reps = ex['numberOfReps'] ?? ex['reps'];
    final rest = _formatProgramRest(ex['restSeconds'] ?? ex['restTime']);
    final weight = ex['weight'];
    final description = (ex['exerciseDescription'] ?? ex['description'])?.toString().trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
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
              if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.primaryGray, size: 20),
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
        ),
      ),
    );
  }

  Widget _buildProgramMetricChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
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
    final notes = workout['notes']?.toString().trim() ?? '';
    final journalDateRaw = workout['journalDate']?.toString();
    final journalDate = journalDateRaw != null ? DateTime.tryParse(journalDateRaw) : null;
    final journalType = workout['journalType']?.toString().trim();
    final workouts = workout['workouts'] is List ? (workout['workouts'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.fitness_center, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      journalType != null && journalType.isNotEmpty ? '$journalType Journal' : 'Workout Journal',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    if (journalDate != null) ...[
                      const SizedBox(height: 4),
                      Text(DateFormat('MMM d, yyyy').format(journalDate.toLocal()), style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                    ],
               
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _shareWorkoutToChat(workout),
                child: Icon(Icons.share, color: AppColors.primaryGray, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          Row(
            children: [
              Expanded(child: _buildWorkoutStatBox('assets/icons/nutrition.svg', workout['exercises'].toString(), 'Exercises')),
              const SizedBox(width: 10),
              Expanded(child: _buildWorkoutStatBox('assets/icons/nutrition.svg', workout['sets'].toString(), 'Sets')),
              const SizedBox(width: 10),
              Expanded(child: _buildWorkoutStatBox('assets/icons/nutrition.svg', workout['calories'].toString(), 'Calories')),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Notes',
              style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(notes, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, height: 1.4)),
          ],
          if (workouts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Exercises',
              style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...workouts.asMap().entries.map((entry) => _buildJournalExerciseTile(entry.value, entry.key + 1)),
          ],
        ],
      ),
    );
  }

  Widget _buildJournalExerciseTile(Map<String, dynamic> workout, int order) {
    final name = workout['name']?.toString().trim().isNotEmpty == true ? workout['name'].toString() : 'Exercise $order';
    final iconUrl = workout['iconUrl']?.toString();
    final exerciseType = workout['exerciseType']?.toString();
    final sets = workout['sets'] is List ? (workout['sets'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
    final showReps = sets.any((s) => s['hasReps'] == true);
    final showTime = sets.any((s) => s['hasTime'] == true);
    final showWeight = sets.any((s) => s['hasWeight'] == true);
    final showDistance = sets.any((s) => s['hasDistance'] == true);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                clipBehavior: Clip.antiAlias,
                child: iconUrl != null && iconUrl.isNotEmpty
                    ? SafeNetworkImage(
                        url: iconUrl,
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                        fallback: Icon(Icons.fitness_center, size: 20, color: AppColors.accent),
                      )
                    : Icon(Icons.fitness_center, size: 20, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                    ),
                    if (exerciseType != null && exerciseType.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(exerciseType, style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (sets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Center(child: Text(
                    'Set',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
                  )),
                ),
                if (showTime)
                  Expanded(
                    flex: 2,
                    child: Center(child: Text(
                      'Time',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
                    )),
                  ),
                if (showReps)
                  Expanded(
                    flex: 2,
                    child: Center(child: Text(
                      'Reps',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
                    )),
                  ),
                if (showDistance)
                  Expanded(
                    flex: 2,
                    child: Center(child: Text(
                      'Distance',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
                    )),
                  ),
                if (showWeight)
                  Expanded(
                    flex: 2,
                    child: Center(child: Text(
                      'Weight',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
                    )),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ...sets.map((set) => _buildJournalSetRow(
                  set,
                  showReps: showReps,
                  showTime: showTime,
                  showWeight: showWeight,
                  showDistance: showDistance,
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildJournalSetRow(
    Map<String, dynamic> set, {
    required bool showReps,
    required bool showTime,
    required bool showWeight,
    required bool showDistance,
  }) {
    final setNumber = set['setNumber']?.toString() ?? '-';
    final reps = set['reps']?.toString() ?? '-';
    final time = set['time']?.toString() ?? '-';
    final distanceRaw = set['distance'];
    final distance = distanceRaw is num ? '${distanceRaw % 1 == 0 ? distanceRaw.toInt() : distanceRaw}' : '-';
    final weightRaw = set['weight']?.toString();
    final weight = weightRaw != null && weightRaw.isNotEmpty ? (weightRaw.toUpperCase() == 'BW' ? 'BW' : '$weightRaw kg') : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Center(child: Text(
              setNumber,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
            )),
          ),
          if (showTime)
            Expanded(
              flex: 2,
              child: Center(child: Text(time, style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface))),
            ),
          if (showReps)
            Expanded(
              flex: 2,
              child: Center(child: Text(reps, style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface))),
            ),
          if (showDistance)
            Expanded(
              flex: 2,
              child: Center(child: Text(distance, style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface))),
            ),
          if (showWeight)
            Expanded(
              flex: 2,
              child: Center(child: Text(weight, style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface))),
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
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2)),
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

  String _runActivityLabel(Map<String, dynamic> run) {
    final raw = run['activityType']?.toString().trim();
    if (raw == null || raw.isEmpty) return 'Run';
    return RunningLogRepository.activityTypeFromRunningType(raw);
  }

  IconData _runActivityIcon(String activityLabel) {
    switch (activityLabel.toLowerCase()) {
      case 'walk':
        return Icons.directions_walk;
      case 'jog':
        return Icons.directions_walk_outlined;
      case 'bike':
        return Icons.directions_bike;
      case 'run':
      default:
        return Icons.directions_run;
    }
  }

  Widget _buildRunsSection(List<Map<String, dynamic>> runs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (runs.length > 1) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Runs (${runs.length})',
              style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
            ),
          ),
        ],
        ...runs.asMap().entries.map(
          (entry) => _buildRunSummarySection(
            entry.value,
            titleSuffix: runs.length > 1 ? ' #${entry.key + 1}' : null,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmUnlinkRunFromDay(Map<String, dynamic> run) async {
    final entryId = _calendarEntryIdForSelectedDate();
    final runId = _runningLogIdFromRunMap(run);
    if (entryId == null || runId == null || _isRemovingRun) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Remove from this day?', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
        content: Text(
          'This removes the run from this calendar day only. The run will stay in your running history.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Remove', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRemovingRun = true);
    try {
      await _calendarRepo.unlinkRunningLogFromCalendar(calendarEntryId: entryId, runningLogId: runId);
      if (!mounted) return;
      await _loadCalendarMonth();
      await _loadSelectedDayDetail(isRefresh: true);
      Get.snackbar('Removed', 'Run removed from this day', backgroundColor: AppColors.completed, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      if (!mounted) return;
      await showCalendarErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _isRemovingRun = false);
    }
  }

  Future<void> _confirmDeleteRunPermanently(Map<String, dynamic> run) async {
    final runId = _runningLogIdFromRunMap(run);
    if (runId == null || _isRemovingRun) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete run?', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
        content: Text(
          'This permanently deletes the run and removes it from all calendar days.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRemovingRun = true);
    try {
      await RunningLogRepository().deleteRunningLog(runId);
      if (!mounted) return;
      await _loadCalendarMonth();
      await _loadSelectedDayDetail(isRefresh: true);
      Get.snackbar('Deleted', 'Run deleted permanently', backgroundColor: AppColors.completed, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      if (!mounted) return;
      await showCalendarErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _isRemovingRun = false);
    }
  }

  Widget _buildRunSummarySection(Map<String, dynamic> run, {String? titleSuffix}) {
    final activityLabel = _runActivityLabel(run);
    final canManageRun = _calendarEntryIdForSelectedDate() != null && _runningLogIdFromRunMap(run) != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(_runActivityIcon(activityLabel), color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$activityLabel Summary${titleSuffix ?? ''}',
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
              ),
              if (canManageRun)
                PopupMenuButton<String>(
                  enabled: !_isRemovingRun,
                  icon: Icon(Icons.more_vert, color: AppColors.primaryGray, size: 22),
                  onSelected: (value) {
                    if (value == 'unlink') {
                      _confirmUnlinkRunFromDay(run);
                    } else if (value == 'delete') {
                      _confirmDeleteRunPermanently(run);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'unlink', child: Text('Remove from this day')),
                    PopupMenuItem(value: 'delete', child: Text('Delete run permanently')),
                  ],
                ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _shareRunToChat(run),
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
          GestureDetector(
            onTap: () => _viewRunDetails(run),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(Icons.category_outlined, 'Activity', activityLabel),
                const SizedBox(height: 8),
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
        ],
      ),
    );
  }

  Future<void> _viewRunDetails(Map<String, dynamic> runData) async {
    try {
      // If we have the actual RunModel stored, use it directly
      if (runData['runModel'] != null && runData['runModel'] is RunModel) {
        Get.toNamed(AppRoutes.runDetail, arguments: runData['runModel'] as RunModel);
        return;
      }

      final runId = runData['id']?.toString().trim();
      if (runId != null && runId.isNotEmpty && Get.isRegistered<StorageService>()) {
        final runs = await Get.find<StorageService>().getRuns();
        for (final stored in runs) {
          if (stored.id == runId || stored.backendLogId == runId) {
            Get.toNamed(AppRoutes.runDetail, arguments: stored);
            return;
          }
        }
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

      final activityType = _runActivityLabel(runData);

      // Create RunModel from parsed data
      final runModel = RunModel(
        id: runData['id'] ?? 'planner_${_selectedDate.millisecondsSinceEpoch}',
        userId: 'current_user',
        activityType: activityType,
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
    int readInt(dynamic value, {int fallback = 0}) {
      if (value is num) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    final hasStructuredCalories = nutrition.containsKey('caloriesConsumed') || nutrition.containsKey('caloriesGoal');
    late final int consumed;
    late final int burned;
    late final int goal;
    late final int remaining;
    late final int progressPercent;

    if (hasStructuredCalories) {
      consumed = readInt(nutrition['caloriesConsumed']);
      burned = readInt(nutrition['caloriesBurned']);
      goal = readInt(nutrition['caloriesGoal']);
      remaining = readInt(nutrition['caloriesRemaining'], fallback: goal - consumed);
      progressPercent = readInt(nutrition['caloriesProgressPercent'], fallback: goal > 0 ? ((consumed / goal) * 100).round() : 0);
    } else {
      final caloriesRaw = nutrition['calories']?.toString() ?? '0';
      final caloriesParts = caloriesRaw.split('/');
      consumed = readInt(caloriesParts.first.trim());
      goal = caloriesParts.length > 1 ? readInt(caloriesParts.last.trim()) : 0;
      burned = 0;
      remaining = goal - consumed;
      progressPercent = goal > 0 ? ((consumed / goal) * 100).round() : 0;
    }

    final proteinVal = nutrition.containsKey('proteinGrams')
        ? readInt(nutrition['proteinGrams']).toString()
        : nutrition['protein']?.toString().replaceAll('g', '').trim() ?? '0';
    final carbsVal = nutrition.containsKey('carbsGrams')
        ? readInt(nutrition['carbsGrams']).toString()
        : nutrition['carbs']?.toString().replaceAll('g', '').trim() ?? '0';
    final fatsVal = nutrition.containsKey('fatsGrams')
        ? readInt(nutrition['fatsGrams']).toString()
        : nutrition['fats']?.toString().replaceAll('g', '').trim() ?? '0';
    final proteinPercent = readInt(nutrition['proteinPercent']);
    final carbsPercent = readInt(nutrition['carbsPercent']);
    final fatsPercent = readInt(nutrition['fatsPercent']);

    final progressValue = (progressPercent / 100).clamp(0.0, 1.0);
    final isOverGoal = remaining < 0 || progressPercent > 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.restaurant_menu, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Nutrition',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text('Calories and macros for this day', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$consumed',
                style: const TextStyle(fontSize: 36, color: AppColors.onSurface, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 4),
              Text(
                goal > 0 ? '/ $goal kcal' : 'kcal',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.black, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(isOverGoal ? Colors.red : AppColors.accent),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$progressPercent% of goal',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
              ),
              Text(
                isOverGoal ? '${(-remaining)} kcal over' : '$remaining kcal remaining',
                style: AppTextStyles.bodySmall.copyWith(color: isOverGoal ? Colors.red : AppColors.black, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildNutritionMiniStat('Consumed', '$consumed', Icons.restaurant_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _buildNutritionMiniStat('Burned', '$burned', Icons.local_fire_department_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _buildNutritionMiniStat('Goal', '$goal', Icons.flag_outlined)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Macronutrients', style: AppTextStyles.labelLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildNutritionBox('$proteinVal', 'Protein g${proteinPercent > 0 ? ' · $proteinPercent%' : ''}', const Color(0xFFE8F5E0), AppColors.onSurface)),
              const SizedBox(width: 12),
              Expanded(child: _buildNutritionBox('$carbsVal', 'Carbs g${carbsPercent > 0 ? ' · $carbsPercent%' : ''}', const Color(0xFFE8F5E0), AppColors.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildNutritionBox('$fatsVal', 'Fats g${fatsPercent > 0 ? ' · $fatsPercent%' : ''}', const Color(0xFFFCDDD5), const Color(0xFFD94E2A))),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionMiniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600)),
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
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: textColor.withValues(alpha: 0.7), fontSize: 12)),
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
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: AppColors.blackOverlay.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
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
