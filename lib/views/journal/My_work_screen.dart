import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/workout_model.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:intl/intl.dart';

/// Journal screen - workout logs and daily tracking
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  int _selectedDateIndex = 2; // Today is at index 2
  bool _isLoading = true;
  StorageService? _storageService;

  // Streak analytics data
  final int _currentStreak = 12;
  final int _longestStreak = 28;
  final List<bool> _weeklyStreak = [true, true, true, true, true, false, true]; // Last 7 days

  // Dynamic dates list (7 days centered around today)
  late List<Map<String, dynamic>> _dates;

  // Journal entries loaded from storage
  List<Map<String, dynamic>> _journalEntries = [];

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _initializeStorage();
    _loadWorkouts();
  }

  void _initializeDates() {
    final now = DateTime.now();
    _dates = List.generate(7, (index) {
      final date = now.subtract(Duration(days: 2 - index)); // Center today at index 2
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return {'day': dayNames[date.weekday - 1], 'date': date.day, 'dateTime': date, 'month': date.month, 'year': date.year};
    });
  }

  Future<void> _initializeStorage() async {
    _storageService = await StorageService.getInstance();
  }

  Future<void> _loadWorkouts() async {
    if (_storageService == null) {
      await _initializeStorage();
    }

    if (_storageService == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final workouts = await _storageService!.getWorkouts();
      setState(() {
        _journalEntries = workouts.map((workout) => _workoutToJournalEntry(workout)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar('Error', 'Failed to load workouts: ${e.toString()}', backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Map<String, dynamic> _workoutToJournalEntry(WorkoutModel workout) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final workoutDate = workout.date;

    // Calculate which date index this workout belongs to
    int dateIndex = -1;
    for (int i = 0; i < _dates.length; i++) {
      final dateInfo = _dates[i];
      final dateTime = dateInfo['dateTime'] as DateTime;
      if (workoutDate.year == dateTime.year && workoutDate.month == dateTime.month && workoutDate.day == dateTime.day) {
        dateIndex = i;
        break;
      }
    }

    // Calculate duration (simplified - you might want to store actual duration)
    final duration = '${workout.sets} sets × ${workout.reps} reps';

    return {
      'id': workout.id,
      'date': dateFormat.format(workoutDate),
      'time': timeFormat.format(workout.createdAt),
      'entry': '${workout.exerciseName}${workout.weight != null ? ' - ${workout.weight}kg' : ''}',
      'mood': 'Great 💪', // Default mood
      'type': 'Workout',
      'icon': Icons.fitness_center,
      'duration': duration,
      'dateIndex': dateIndex,
      'workout': workout, // Store original workout model
    };
  }

  // Get workout entries for the selected date
  List<Map<String, dynamic>> _getWorkoutsForSelectedDate() {
    final selectedDateInfo = _dates[_selectedDateIndex];
    final selectedDateTime = selectedDateInfo['dateTime'] as DateTime;

    return _journalEntries.where((entry) {
      final workout = entry['workout'] as WorkoutModel?;
      if (workout == null) return false;

      final workoutDate = workout.date;
      return workoutDate.year == selectedDateTime.year && workoutDate.month == selectedDateTime.month && workoutDate.day == selectedDateTime.day;
    }).toList();
  }

  void _showEntryOptions(Map<String, dynamic> entry, int index) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      entry['type'] as String,
                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w800, fontSize: 22),
                    ),
                    const SizedBox(height: 6),
                    Text('${entry['date']} • ${entry['time']}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildBottomSheetOption(
                      icon: Icons.edit_rounded,
                      title: 'Edit Entry',
                      color: AppColors.accent,
                      onTap: () {
                        Get.back();
                        _editEntry(entry, index);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildBottomSheetOption(
                      icon: Icons.delete_outline_rounded,
                      title: 'Delete Entry',
                      color: Colors.red,
                      onTap: () {
                        Get.back();
                        _showDeleteConfirmation(entry, index);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildBottomSheetOption({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.15)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.6), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _editEntry(Map<String, dynamic> entry, int index) {
    final entryType = entry['type'] as String;

    // Navigate to appropriate edit screen based on entry type
    if (entryType == 'Workout') {
      Get.toNamed(AppRoutes.addWorkout, arguments: {'edit': true, 'entry': entry});
    } else if (entryType == 'Cardio' || entryType == 'Run') {
      Get.toNamed(AppRoutes.logRun, arguments: {'edit': true, 'entry': entry});
    } else if (entryType == 'Meal') {
      Get.toNamed(AppRoutes.logMeal, arguments: {'edit': true, 'entry': entry});
    } else if (entryType == 'Note' || entryType == 'Rest Day') {
      Get.toNamed(AppRoutes.writeNote, arguments: {'edit': true, 'entry': entry});
    } else {
      Get.snackbar(
        'Edit Entry',
        'Edit functionality for this entry type is coming soon!',
        backgroundColor: AppColors.accent,
        colorText: AppColors.onAccent,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> entry, int index) {
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
                'Delete Entry?',
                style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete this journal entry? This action cannot be undone.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '${entry['type']} • ${entry['date']}',
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
                      child: Text('Cancel', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onBackground)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        _deleteEntry(index);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Delete', style: AppTextStyles.buttonMedium.copyWith(color: Colors.white)),
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

  Future<void> _deleteEntry(int index) async {
    final entry = _journalEntries[index];
    final workout = entry['workout'] as WorkoutModel?;

    if (workout != null && _storageService != null) {
      try {
        final success = await _storageService!.deleteWorkout(workout.id);
        if (success) {
          setState(() {
            _journalEntries.removeAt(index);
          });
          Get.snackbar(
            'Entry Deleted',
            'Journal entry has been deleted',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.completed,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
          );
        } else {
          Get.snackbar(
            'Error',
            'Failed to delete entry',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
          );
        }
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to delete entry: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
        );
      }
    } else {
      // Fallback for non-workout entries
      setState(() {
        _journalEntries.removeAt(index);
      });
      Get.snackbar(
        'Entry Deleted',
        'Journal entry has been deleted',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.completed,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      );
    }
  }

  void _showAddEntryOptions() {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'New Journal Entry',
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w800, fontSize: 24),
                ),
                const SizedBox(height: 8),
                Text('What would you like to log today?', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark, fontSize: 15)),
                const SizedBox(height: 24),
                _buildEntryOption(
                  icon: Icons.fitness_center_rounded,
                  title: 'Log Workout',
                  subtitle: 'Record exercise details',
                  color: AppColors.accent,
                  onTap: () async {
                    Get.back();
                    final result = await Get.toNamed(AppRoutes.addWorkout);
                    if (result == true) {
                      _loadWorkouts(); // Refresh workouts when returning
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildEntryOption(
                  icon: Icons.directions_run_rounded,
                  title: 'Log Run',
                  subtitle: 'Track your running session',
                  color: AppColors.completed,
                  onTap: () {
                    Get.back();
                    Get.toNamed(AppRoutes.logRun);
                  },
                ),
                const SizedBox(height: 12),
                _buildEntryOption(
                  icon: Icons.restaurant_rounded,
                  title: 'Log Meal',
                  subtitle: 'Record your nutrition',
                  color: const Color(0xFFFF9800),
                  onTap: () {
                    Get.back();
                    Get.toNamed(AppRoutes.logMeal);
                  },
                ),
                const SizedBox(height: 12),
                _buildEntryOption(
                  icon: Icons.note_rounded,
                  title: 'Write Note',
                  subtitle: 'Add thoughts or reflections',
                  color: const Color(0xFF9C27B0),
                  onTap: () {
                    Get.back();
                    Get.toNamed(AppRoutes.writeNote);
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildEntryOption({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.15)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.primaryGrayDark, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 20),
          ),
          onPressed: () {
            Get.back();
          },
        ),
        title: Text(
          'My Workouts',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Modern Date Selector Row
                  Container(
                    height: 100,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _dates.length,
                      itemBuilder: (context, index) {
                        final dateInfo = _dates[index];
                        final isSelected = index == _selectedDateIndex;
                        final isToday = index == 2;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDateIndex = index;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            width: 76,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.85)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                  : null,
                              color: isSelected ? null : AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? AppColors.accent : AppColors.primaryGray.withValues(alpha: 0.3), width: isSelected ? 2 : 1.5),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6), spreadRadius: 0)]
                                  : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  dateInfo['day'],
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: isSelected ? AppColors.onAccent : AppColors.primaryGrayDark,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${dateInfo['date']}',
                                  style: AppTextStyles.headlineSmall.copyWith(
                                    color: isSelected ? AppColors.onAccent : AppColors.onSurface,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 24,
                                  ),
                                ),
                                if (isToday) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(color: isSelected ? AppColors.onAccent : AppColors.accent, shape: BoxShape.circle),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  const SizedBox(height: 20),

                  // Modern Section Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Builder(
                      builder: (context) {
                        final dateInfo = _dates[_selectedDateIndex];
                        final dateTime = dateInfo['dateTime'] as DateTime;
                        final dateFormat = DateFormat('EEEE, MMM d');
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.accent.withValues(alpha: 0.2), AppColors.accent.withValues(alpha: 0.1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.fitness_center_rounded, color: AppColors.accent, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Workouts',
                                    style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w800, fontSize: 20),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(dateFormat.format(dateTime), style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Workouts List for Selected Day
                  Builder(
                    builder: (context) {
                      final workoutsForDay = _getWorkoutsForSelectedDate();
                      if (workoutsForDay.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2), width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppColors.accent.withValues(alpha: 0.15), AppColors.accent.withValues(alpha: 0.08)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.fitness_center_outlined, color: AppColors.accent, size: 48),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'No workouts logged',
                                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap the + button below to add a workout',
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: workoutsForDay.length,
                        itemBuilder: (context, index) {
                          final entry = workoutsForDay[index];
                          final originalIndex = _journalEntries.indexWhere((e) => e['id'] == entry['id']);
                          return TweenAnimationBuilder<double>(
                            duration: Duration(milliseconds: 300 + (index * 50)),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: Opacity(opacity: value, child: child),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2), width: 1.5),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4), spreadRadius: 0),
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _showEntryOptions(entry, originalIndex),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [AppColors.accent.withValues(alpha: 0.2), AppColors.accent.withValues(alpha: 0.15)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(entry['icon'] as IconData, color: AppColors.accent, size: 22),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    entry['type'] as String,
                                                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700, fontSize: 16),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${entry['date']} • ${entry['time']}',
                                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [AppColors.accent.withValues(alpha: 0.15), AppColors.accent.withValues(alpha: 0.1)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                entry['duration'] as String,
                                                style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: Icon(Icons.more_vert_rounded, color: AppColors.primaryGrayDark, size: 20),
                                              onPressed: () => _showEntryOptions(entry, originalIndex),
                                              tooltip: 'More options',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(color: AppColors.primaryGrayLight.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                                          child: Text(entry['entry'] as String, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontSize: 14, height: 1.4)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Modern Daily Summary Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.accent.withValues(alpha: 0.2), AppColors.accent.withValues(alpha: 0.1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.insights_rounded, color: AppColors.accent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Summary',
                              style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w800, fontSize: 20),
                            ),
                            const SizedBox(height: 2),
                            Text('Your activity overview', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildSummaryItem(Icons.local_fire_department_rounded, 'Calories', '420', 'kcal', AppColors.accent)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildSummaryItem(Icons.directions_walk_rounded, 'Steps', '7,850', '', AppColors.completed)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildSummaryItem(Icons.timer_rounded, 'Workout', '45', 'mins', const Color(0xFFFF9800))),
                            const SizedBox(width: 16),
                            Expanded(child: _buildSummaryItem(Icons.emoji_events_rounded, 'Mood', 'Great', '💪', const Color(0xFF9C27B0))),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: FloatingActionButton.extended(
          heroTag: 'journal_fab',
          onPressed: _showAddEntryOptions,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          icon: const Icon(Icons.add_rounded, size: 24),
          label: Text('Add Entry', style: AppTextStyles.buttonLarge.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2)),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.15)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGrayDark, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: AppTextStyles.headlineSmall.copyWith(color: color, fontWeight: FontWeight.w800, fontSize: 24),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 3),
                  child: Text(unit, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 11)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakStat(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.onPrimary.withValues(alpha: 0.7)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTextStyles.headlineSmall.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(unit, style: AppTextStyles.labelSmall.copyWith(color: AppColors.onPrimary.withValues(alpha: 0.6))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakDay(String dayLabel, bool isActive, bool isToday) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isActive ? (isToday ? AppColors.accent : AppColors.accent.withValues(alpha: 0.3)) : AppColors.primaryVariant.withValues(alpha: 0.3),
        shape: BoxShape.circle,
        border: Border.all(color: isToday ? AppColors.accent : Colors.transparent, width: 2),
      ),
      child: Center(
        child: Text(
          dayLabel,
          style: AppTextStyles.labelMedium.copyWith(
            color: isActive ? AppColors.onAccent : AppColors.onPrimary.withValues(alpha: 0.4),
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
