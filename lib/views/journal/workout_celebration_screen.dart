import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/views/home/dashboard_screen.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Workout Celebration Screen
/// Full-screen celebration view shown after workout completion
class WorkoutCelebrationScreen extends StatefulWidget {
  final String duration;
  final int calories;
  final String workoutName;
  final String? workoutJournalId;

  const WorkoutCelebrationScreen({super.key, required this.duration, required this.calories, required this.workoutName, this.workoutJournalId});

  @override
  State<WorkoutCelebrationScreen> createState() => _WorkoutCelebrationScreenState();
}

class _WorkoutCelebrationScreenState extends State<WorkoutCelebrationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final CalendarRepository _calendarRepo = CalendarRepository();

  final List<String> _motivationalQuotes = [
    "You showed up—and that's what counts. Keep going!",
    "Every rep brings you closer to your goals!",
    "Consistency is the key. You're crushing it!",
    "Your only limit is you. Great job today!",
    "Progress over perfection. Well done!",
    "One workout at a time. You're doing amazing!",
    "Stronger than yesterday. Keep pushing!",
    "Champions train, legends never stop!",
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
    _addWorkoutJournalToCalendar();
  }

  Future<void> _addWorkoutJournalToCalendar() async {
    final journalId = widget.workoutJournalId?.trim();
    if (!WorkoutRepository.isValidMongoId(journalId)) return;

    try {
      final journalDay = HomeNavigationController.journalDayOrNow();
      await _calendarRepo.createCalendarEntry(date: journalDay, type: CalendarRepository.typeCompleted, workoutJournal: journalId);
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Calendar', CalendarRepository.errorMessageFrom(e), backgroundColor: AppColors.error, colorText: AppColors.onError);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getRandomQuote() {
    return _motivationalQuotes[Random().nextInt(_motivationalQuotes.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: AppColors.onBackground),
                onPressed: () => Get.back(),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Celebration Icon with Animation
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.accent.withOpacity(0.3), AppColors.accent.withOpacity(0.1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)],
                        ),
                        child: const Icon(Icons.celebration, size: 60, color: AppColors.accent),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'Workout Complete!',
                        style: AppTextStyles.headlineLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Motivational Quote
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1),
                        ),
                        child: Text(
                          _getRandomQuote(),
                          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onBackground, fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Stats Cards
                    _buildStatsGrid(),

                    const SizedBox(height: 32),

                    // Saved Message
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.check_circle, color: AppColors.accent, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Workout Saved!',
                                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your workout data has been saved to your calendar',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Done Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Get.back(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: Text('Done', style: AppTextStyles.buttonLarge),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard(Icons.timer_outlined, widget.duration, 'Duration')),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard(Icons.local_fire_department, '${widget.calories}', 'Calories')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard(Icons.fitness_center, widget.workoutName, 'Exercises')),
            const SizedBox(width: 16),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 2),
            ),
            child: Icon(icon, color: AppColors.accent, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
