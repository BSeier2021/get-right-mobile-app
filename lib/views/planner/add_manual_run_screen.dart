import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_right/models/run_model.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/repo/running_log_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/planner/calendar_type_dialog.dart';
import 'package:intl/intl.dart';

class AddManualRunScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String? calendarEntryId;

  const AddManualRunScreen({
    super.key,
    required this.selectedDate,
    this.calendarEntryId,
  });

  @override
  State<AddManualRunScreen> createState() => _AddManualRunScreenState();
}

class _AddManualRunScreenState extends State<AddManualRunScreen> {
  final _formKey = GlobalKey<FormState>();
  final _distanceController = TextEditingController();
  final _hoursController = TextEditingController(text: '0');
  final _minutesController = TextEditingController();
  final _secondsController = TextEditingController(text: '0');
  final _caloriesController = TextEditingController();

  final CalendarRepository _calendarRepo = CalendarRepository();
  final RunningLogRepository _runningLogRepo = RunningLogRepository();

  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedActivity = 'run';
  bool _isSaving = false;

  static const _activities = [
    ('walk', 'Walk', Icons.directions_walk, Color(0xFF4CAF50)),
    ('jog', 'Jog', Icons.directions_walk_outlined, Color(0xFFFF9800)),
    ('run', 'Run', Icons.directions_run, Color(0xFFF44336)),
    ('bike', 'Bike', Icons.directions_bike, Color(0xFF2196F3)),
  ];

  String get _formattedDate => DateFormat.yMMMMd().format(widget.selectedDate);

  @override
  void dispose() {
    _distanceController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  DateTime _buildStartDateTime() {
    return DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Duration? _parseDuration() {
    final hours = int.tryParse(_hoursController.text.trim()) ?? 0;
    final minutes = int.tryParse(_minutesController.text.trim()) ?? 0;
    final seconds = int.tryParse(_secondsController.text.trim()) ?? 0;
    final totalSeconds = (hours * 3600) + (minutes * 60) + seconds;
    if (totalSeconds <= 0) return null;
    return Duration(seconds: totalSeconds);
  }

  int? _resolveCalories(double distanceKm) {
    final raw = _caloriesController.text.trim();
    if (raw.isEmpty) {
      return RunningLogRepository.estimateCaloriesForManualRun(
        activityType: _selectedActivity,
        distanceKm: distanceKm,
      );
    }
    final parsed = int.tryParse(raw);
    return parsed != null && parsed > 0 ? parsed : null;
  }

  String? _validateCaloriesField(String? _) {
    final raw = _caloriesController.text.trim();
    if (raw.isEmpty) return null;
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) return 'Enter a valid calorie amount';
    return null;
  }

  Future<void> _saveRun() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    final distanceKm = double.tryParse(_distanceController.text.trim()) ?? 0;
    if (distanceKm <= 0) {
      Get.snackbar(
        'Invalid distance',
        'Enter a distance greater than zero',
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final duration = _parseDuration();
    if (duration == null) {
      Get.snackbar(
        'Invalid duration',
        'Enter a duration greater than zero',
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final now = DateTime.now();
    final selectedDay = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    final today = DateTime(now.year, now.month, now.day);
    if (selectedDay.isAfter(today)) {
      Get.snackbar(
        'Invalid date',
        'Runs cannot be logged for future dates',
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final startTime = _buildStartDateTime();
      final endTime = startTime.add(duration);
      final distanceMeters = distanceKm * 1000;
      final calories = _resolveCalories(distanceKm);
      if (_caloriesController.text.trim().isNotEmpty && (calories == null || calories <= 0)) {
        Get.snackbar(
          'Invalid calories',
          'Enter a valid calorie amount greater than zero',
          backgroundColor: AppColors.error,
          colorText: AppColors.onError,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final response = await _runningLogRepo.saveManualRunningLog(
        startTime: startTime,
        endTime: endTime,
        activityType: _selectedActivity,
        distanceMeters: distanceMeters,
        duration: duration,
        caloriesBurned: calories,
      );

      final logId = RunningLogRepository.runningLogIdFrom(response);
      if (logId == null || !WorkoutRepository.isValidMongoId(logId)) {
        throw Exception('Could not save running log');
      }

      final durationSeconds = duration.inSeconds;
      final existingEntryId = widget.calendarEntryId?.trim();
      if (existingEntryId != null && WorkoutRepository.isValidMongoId(existingEntryId)) {
        await _calendarRepo.attachRunningLogToCalendar(
          date: widget.selectedDate,
          runningLogId: logId,
          calendarEntryId: existingEntryId,
          durationInSeconds: durationSeconds,
        );
      } else {
        final type = await showCalendarTypeDialog(context);
        if (type == null || !mounted) return;
        await _calendarRepo.createCalendarEntry(
          date: widget.selectedDate,
          type: type,
          runningLog: logId,
          durationInSeconds: CalendarRepository.typeRequiresDuration(type) ? durationSeconds : null,
        );
      }

      await _persistRunLocally(
        startTime: startTime,
        endTime: endTime,
        distanceMeters: distanceMeters,
        duration: duration,
        caloriesBurned: calories,
        backendLogId: logId,
      );

      if (!mounted) return;
      Get.back(result: {
        'type': 'manual_run',
        'logId': logId,
        'caloriesBurned': calories,
      });
    } catch (e) {
      if (!mounted) return;
      await showCalendarErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _persistRunLocally({
    required DateTime startTime,
    required DateTime endTime,
    required double distanceMeters,
    required Duration duration,
    required int? caloriesBurned,
    required String backendLogId,
  }) async {
    if (!Get.isRegistered<StorageService>()) return;

    final storage = Get.find<StorageService>();
    final averagePace = distanceMeters > 0 ? (duration.inSeconds / 60) / (distanceMeters / 1000) : null;
    final run = RunModel(
      id: backendLogId,
      userId: storage.getUserId() ?? 'anonymous',
      activityType: _selectedActivity,
      distanceMeters: distanceMeters,
      duration: duration,
      startTime: startTime,
      endTime: endTime,
      averagePace: averagePace,
      caloriesBurned: caloriesBurned,
      createdAt: DateTime.now(),
      backendLogId: backendLogId,
    );

    final runs = await storage.getRuns();
    runs.add(run);
    await storage.saveRuns(runs);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: _isSaving ? null : () => Get.back(),
        ),
        title: Text('Log Run', style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FFE9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: const Color(0xFFFFE8D1), shape: BoxShape.circle),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Image.asset('assets/images/runing.png', fit: BoxFit.contain),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Manual Run Entry',
                                  style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Logging for $_formattedDate',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Activity', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _activities.map((item) {
                        final (value, label, icon, color) = item;
                        final selected = _selectedActivity == value;
                        return ChoiceChip(
                          avatar: Icon(icon, size: 18, color: selected ? AppColors.onAccent : color),
                          label: Text(label),
                          selected: selected,
                          onSelected: _isSaving
                              ? null
                              : (_) {
                                  setState(() => _selectedActivity = value);
                                },
                          selectedColor: AppColors.accent,
                          backgroundColor: AppColors.white,
                          shape: StadiumBorder(
                            side: BorderSide(color: selected ? AppColors.accent : AppColors.primaryGray.withValues(alpha: 0.35)),
                          ),
                          labelStyle: AppTextStyles.labelMedium.copyWith(
                            color: selected ? AppColors.onAccent : AppColors.onSurface,
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text('Start Time', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _isSaving
                          ? null
                          : () async {
                              final time = await showTimePicker(context: context, initialTime: _selectedTime);
                              if (time != null) setState(() => _selectedTime = time);
                            },
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: AppColors.accent, size: 20),
                            const SizedBox(width: 10),
                            Text(_selectedTime.format(context), style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Distance', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _distanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      decoration: _fieldDecoration(hintText: 'e.g. 5.2', suffixText: 'km'),
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed <= 0) return 'Enter a valid distance';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Text('Duration', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _durationField(controller: _hoursController, label: 'Hr')),
                        const SizedBox(width: 10),
                        Expanded(child: _durationField(controller: _minutesController, label: 'Min')),
                        const SizedBox(width: 10),
                        Expanded(child: _durationField(controller: _secondsController, label: 'Sec')),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Calories (optional)', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      'Leave blank to auto-estimate from distance and activity',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _caloriesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _validateCaloriesField,
                      decoration: _fieldDecoration(hintText: 'Auto'),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveRun,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentVariant,
                          foregroundColor: AppColors.onAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          elevation: 0,
                        ),
                        child: Text(_isSaving ? 'Saving...' : 'Save Run', style: AppTextStyles.buttonLarge),
                      ),
                    ),
                  ],
                ),
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

  InputDecoration _fieldDecoration({required String hintText, String? suffixText}) {
    return InputDecoration(
      hintText: hintText,
      suffixText: suffixText,
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.35)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.6)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _durationField({required TextEditingController controller, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _fieldDecoration(hintText: '0'),
        ),
      ],
    );
  }
}
