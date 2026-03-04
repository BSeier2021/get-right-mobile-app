import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/models/workout_journal_model.dart';
import 'package:get_right/models/workout_exercise_model.dart';
import 'package:get_right/models/exercise_set_model.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/journal/exercise_card.dart';
import 'package:get_right/widgets/journal/superset_card.dart';
import 'package:get_right/views/journal/workout_celebration_screen.dart';

class WorkoutJournalScreen extends StatefulWidget {
  final bool isEmbedded;
  const WorkoutJournalScreen({super.key, this.isEmbedded = false});

  @override
  State<WorkoutJournalScreen> createState() => _WorkoutJournalScreenState();
}

class _WorkoutJournalScreenState extends State<WorkoutJournalScreen> {
  WorkoutJournalModel? _workout;
  bool _isLoading = true;
  bool _isStarted = false;
  bool _isPaused = false;
  // Dialog is now used instead of inline add-exercise content
  Timer? _timer;
  int _seconds = 0;
  int _calories = 0;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _load() {
    setState(() {
      _isLoading = false;
      _workout = WorkoutJournalModel(
        id: 'w_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'user_1',
        date: DateTime.now(),
        warmupExercises: [],
        workoutExercises: [],
        createdAt: DateTime.now(),
      );
    });
  }

  void _startWorkout() {
    setState(() {
      _isStarted = true;
      _isPaused = false;
      _startTime = DateTime.now();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isPaused) {
        setState(() {
          _seconds++;
          _calories = (_seconds / 60 * 5).round();
        });
      }
    });
  }

  void _pauseWorkout() {
    setState(() => _isPaused = true);
  }

  void _resumeWorkout() {
    setState(() => _isPaused = false);
  }

  void _stopWorkout() {
    _timer?.cancel();

    // Calculate average heart rate

    // Update workout model with completion data
    if (_workout != null && _startTime != null) {
      _workout = _workout!.copyWith(startedAt: _startTime, completedAt: DateTime.now(), durationSeconds: _seconds, caloriesBurned: _calories);
    }

    setState(() {
      _isStarted = false;
      _isPaused = false;
    });

    // Show full-screen celebration view
    Get.to(
      () => WorkoutCelebrationScreen(duration: _formatTime(_seconds), calories: _calories, workoutName: _getWorkoutName()),
      transition: Transition.zoom,
      duration: const Duration(milliseconds: 500),
    )?.then((_) {
      // Reset workout stats after closing celebration
      setState(() {
        _seconds = 0;
        _calories = 0;
        _startTime = null;
      });
    });
  }

  String _getWorkoutName() {
    if (_workout == null) return 'Workout';
    final exerciseCount = _workout!.warmupExercises.length + _workout!.workoutExercises.length;
    return '$exerciseCount Exercise${exerciseCount != 1 ? 's' : ''}';
  }

  Widget _buildStatBadge({required IconData icon, required String value, required String label}) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 2),
          ),
          child: Icon(icon, color: AppColors.accent, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark)),
      ],
    );
  }

  String _formatTime(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  void _onAddWarmup() => Get.toNamed(AppRoutes.exerciseConfiguration, arguments: {'isWarmup': true})?.then((r) {
    if (r != null && r['exercises'] != null)
      setState(() {
        _workout = _workout!.copyWith(warmupExercises: [..._workout!.warmupExercises, ...r['exercises'] as List<WorkoutExerciseModel>]);
      });
  });
  void _onAddWorkout() => Get.toNamed(AppRoutes.exerciseConfiguration, arguments: {'isWarmup': false})?.then((r) {
    if (r != null && r['exercises'] != null)
      setState(() {
        _workout = _workout!.copyWith(workoutExercises: [..._workout!.workoutExercises, ...r['exercises'] as List<WorkoutExerciseModel>]);
      });
  });
  void _onAddExercise() => Get.toNamed(AppRoutes.addExercise);

  void _showQuickAddDialog({required bool isTimer}) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController setsController = TextEditingController(text: '3');
    final TextEditingController repsController = TextEditingController(text: '10');
    final TextEditingController timeController = TextEditingController(text: '60');
    bool isWarmup = false;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.backgroundColor, borderRadius: BorderRadius.circular(20)),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isTimer ? 'Quick Add Timer Exercise' : 'Quick Add Exercise',
                          style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.primaryGray),
                          onPressed: () => Get.back(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Exercise Name',
                        hintText: 'Enter exercise name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.fitness_center, color: AppColors.accent),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(value: isWarmup, onChanged: (v) => setDialogState(() => isWarmup = v ?? false), activeColor: AppColors.accent),
                        Text('Add as Warmup', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isTimer) ...[
                      TextField(
                        controller: setsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Number of Sets',
                          hintText: '3',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.repeat, color: AppColors.accent),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: timeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Time per Set (seconds)',
                          hintText: '60',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.timer, color: AppColors.accent),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: setsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Number of Sets',
                          hintText: '3',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.repeat, color: AppColors.accent),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: repsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Reps per Set',
                          hintText: '10',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.numbers, color: AppColors.accent),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              nameController.dispose();
                              setsController.dispose();
                              repsController.dispose();
                              timeController.dispose();
                              Get.back();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: AppColors.primaryGray),
                            ),
                            child: Text('Cancel', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.primaryGray)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                Get.snackbar('Error', 'Please enter exercise name', backgroundColor: AppColors.error, colorText: Colors.white);
                                return;
                              }

                              final sets = int.tryParse(setsController.text) ?? 3;
                              final now = DateTime.now();
                              final List<ExerciseSetModel> exerciseSets = [];

                              for (int i = 0; i < sets; i++) {
                                exerciseSets.add(
                                  ExerciseSetModel(
                                    id: 'set_${i + 1}_${now.millisecondsSinceEpoch}',
                                    setNumber: i + 1,
                                    reps: isTimer ? null : (int.tryParse(repsController.text) ?? 10),
                                    repsType: isTimer ? null : 'standard',
                                    timeSeconds: isTimer ? (int.tryParse(timeController.text) ?? 60) : null,
                                  ),
                                );
                              }

                              final exercise = WorkoutExerciseModel(
                                id: 'ex_${now.millisecondsSinceEpoch}',
                                exerciseName: name,
                                exerciseId: 'quick_${now.millisecondsSinceEpoch}',
                                sets: exerciseSets,
                                date: now,
                                createdAt: now,
                              );

                              setState(() {
                                if (isWarmup) {
                                  _workout = _workout!.copyWith(warmupExercises: [..._workout!.warmupExercises, exercise]);
                                } else {
                                  _workout = _workout!.copyWith(workoutExercises: [..._workout!.workoutExercises, exercise]);
                                }
                              });

                              nameController.dispose();
                              setsController.dispose();
                              repsController.dispose();
                              timeController.dispose();
                              Get.back();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.onAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Add Exercise', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onAccent)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      // When embedded in combined screen, no AppBar or Scaffold needed
      return Container(
        color: AppColors.backgroundColor,

        child: Column(
          children: [
            // Actions bar
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _workout == null || _workout!.isEmpty
                  ? _buildEmpty()
                  : _buildContent(),
            ),
          ],
        ),
      );
    }

    // Standalone screen with full scaffold
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.accent),
          onPressed: () {},
        ),
        title: Text(
          'Workout Journal',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: AppColors.accent),
            onPressed: () => Get.toNamed(AppRoutes.calendar),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: AppColors.onAccent, size: 20),
            ),
            onPressed: _showAddExerciseDialog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _workout == null || _workout!.isEmpty
          ? _buildEmpty()
          : _buildContent(),
    );
  }

  Widget _buildEmpty() {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // GR Logo with drop shadow
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: Offset(2, 10))],
                  ),
                  child: Image.asset('assets/images/logo-04.png', width: 130, height: 130, fit: BoxFit.contain),
                ),
              ),
              // Instructional text
              Text(
                'Build workout with + button',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark, fontSize: 16.sp),
              ),
            ],
          ),
        ),
        // Glass / Frosted Plus Button at bottom center with 3D effect
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _showAddExerciseDialog,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color.fromARGB(255, 240, 250, 219).withOpacity(0.7), // Light grey frosted
                  boxShadow: [
                    // Soft diffused shadow beneath and slightly to the right
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16, offset: const Offset(2, 6), spreadRadius: 0),
                    // Very subtle ambient shadow
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(1, 3), spreadRadius: 0),
                  ],
                  border: Border.all(
                    color: AppColors.accent,
                    width: 0.8, // Very thin border
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment.topLeft,
                      radius: 1.5,
                      colors: [
                        Colors.white.withOpacity(0.4), // Subtle highlight at top-left
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Center(child: Icon(Icons.add, size: 40, color: Colors.black87)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddExerciseDialog() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Exercise',
                style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 16),
              Text(
                'Would you like to add this exercise to warmup or workout?',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          _onAddWarmup();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB71C1C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Warmup',
                          style: AppTextStyles.buttonMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          _onAddWorkout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Workout',
                          style: AppTextStyles.buttonMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold).copyWith(fontSize: 13.sp),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isStarted) _buildMetrics(),
          if (!_isStarted && !_workout!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _startWorkout,
                    icon: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(color: AppColors.onAccent, shape: BoxShape.circle),
                      child: Icon(Icons.play_arrow, color: AppColors.accent, size: 18),
                    ),
                    label: Text('Start Workout', style: AppTextStyles.buttonMedium),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                  _workout == null || _workout!.isEmpty
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                                  child: const Icon(Icons.add, color: AppColors.onAccent, size: 20),
                                ),
                                onPressed: _showAddExerciseDialog,
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          if (_workout!.warmupExercises.isNotEmpty) ...[
            _buildHeader('Warmup', Icons.local_fire_department, isWarmup: true),
            ..._buildExercisesList(_workout!.warmupExercises, true),
          ],
          if (_workout!.workoutExercises.isNotEmpty) ...[_buildHeader('Workout', Icons.fitness_center, isWarmup: false), ..._buildExercisesList(_workout!.workoutExercises, false)],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.backgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          GestureDetector(
            onTap: _stopWorkout,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: Icon(Icons.stop, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isPaused ? _resumeWorkout : _pauseWorkout,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: _isPaused ? AppColors.accent : Colors.orange, shape: BoxShape.circle),
              child: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppColors.primaryGrayLight.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, color: AppColors.accent, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(_seconds),
                        style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 20, color: AppColors.primaryGrayLight),
                  Row(
                    children: [
                      Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$_calories',
                        style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, IconData icon, {bool isWarmup = false}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(
      children: [
        Icon(icon, color: isWarmup ? Colors.red : AppColors.accent, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  /// Build exercises list with superset grouping support
  List<Widget> _buildExercisesList(List<WorkoutExerciseModel> exercises, bool isWarmup) {
    final List<Widget> widgets = [];
    final Set<String> processedSupersets = {};

    for (int i = 0; i < exercises.length; i++) {
      final exercise = exercises[i];

      // Check if this exercise is part of a superset
      if (exercise.isSuperset && exercise.supersetId != null) {
        // Skip if we've already processed this superset
        if (processedSupersets.contains(exercise.supersetId)) {
          continue;
        }

        // Find the other exercise in the superset
        final otherExercise = exercises.firstWhereOrNull((e) => e.isSuperset && e.supersetId == exercise.supersetId && e.id != exercise.id);

        if (otherExercise != null) {
          // Add superset card
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SupersetCard(
                exercise1: exercise.supersetOrder == 0 ? exercise : otherExercise,
                exercise2: exercise.supersetOrder == 0 ? otherExercise : exercise,
                onMenuTap1: () => _showMenu(exercise.supersetOrder == 0 ? exercise : otherExercise, isWarmup),
                onMenuTap2: () => _showMenu(exercise.supersetOrder == 0 ? otherExercise : exercise, isWarmup),
                onTimerTap1: () {
                  final ex1 = exercise.supersetOrder == 0 ? exercise : otherExercise;
                  if (ex1.hasTimedSets) {
                    Get.toNamed(AppRoutes.workoutTimer, arguments: {'exercise': ex1});
                  }
                },
                onTimerTap2: () {
                  final ex2 = exercise.supersetOrder == 0 ? otherExercise : exercise;
                  if (ex2.hasTimedSets) {
                    Get.toNamed(AppRoutes.workoutTimer, arguments: {'exercise': ex2});
                  }
                },
              ),
            ),
          );
          processedSupersets.add(exercise.supersetId!);
        } else {
          // Superset partner not found, display as regular exercise
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ExerciseCard(
                exercise: exercise,
                onMenuTap: () => _showMenu(exercise, isWarmup),
                onTimerTap: () {
                  if (exercise.hasTimedSets) {
                    Get.toNamed(AppRoutes.workoutTimer, arguments: {'exercise': exercise});
                  }
                },
              ),
            ),
          );
        }
      } else {
        // Regular exercise (not a superset)
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ExerciseCard(
              exercise: exercise,
              onMenuTap: () => _showMenu(exercise, isWarmup),
              onTimerTap: () {
                if (exercise.hasTimedSets) {
                  Get.toNamed(AppRoutes.workoutTimer, arguments: {'exercise': exercise});
                }
              },
            ),
          ),
        );
      }
    }

    return widgets;
  }

  void _showMenu(WorkoutExerciseModel ex, bool isWarmup) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(color: AppColors.primaryGray, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              ListTile(
                onTap: () {
                  Get.back();
                  Get.toNamed(AppRoutes.exerciseConfiguration, arguments: {'isEditing': true, 'existingExercise': ex, 'isWarmup': isWarmup});
                },
                title: Center(
                  child: Text(
                    'Edit',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              ListTile(
                onTap: () {
                  Get.back();
                  Get.toNamed(AppRoutes.videoWalkthrough, arguments: {'exerciseName': ex.exerciseName});
                },
                title: Center(
                  child: Text(
                    'Video Walkthrough',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              ListTile(
                onTap: () {
                  Get.back();
                  setState(() {
                    if (isWarmup)
                      _workout = _workout!.copyWith(warmupExercises: _workout!.warmupExercises.where((e) => e.id != ex.id).toList());
                    else
                      _workout = _workout!.copyWith(workoutExercises: _workout!.workoutExercises.where((e) => e.id != ex.id).toList());
                  });
                },
                title: Center(
                  child: Text(
                    'Delete',
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.red, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              ListTile(
                onTap: () {
                  Get.back();
                  Get.toNamed(AppRoutes.reorderExercises, arguments: {'exercises': isWarmup ? _workout!.warmupExercises : _workout!.workoutExercises})?.then((r) {
                    if (r != null && r['exercises'] != null)
                      setState(() {
                        if (isWarmup)
                          _workout = _workout!.copyWith(warmupExercises: r['exercises'] as List<WorkoutExerciseModel>);
                        else
                          _workout = _workout!.copyWith(workoutExercises: r['exercises'] as List<WorkoutExerciseModel>);
                      });
                  });
                },
                title: Center(
                  child: Text(
                    'Move/Reorder',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              ListTile(
                onTap: () {
                  Get.back();
                  Get.toNamed(AppRoutes.addNotes, arguments: {'exerciseName': ex.exerciseName, 'existingNotes': ex.notes})?.then((r) {
                    if (r != null && r['notes'] != null)
                      setState(() {
                        if (isWarmup) {
                          final idx = _workout!.warmupExercises.indexWhere((e) => e.id == ex.id);
                          if (idx != -1) {
                            final l = List<WorkoutExerciseModel>.from(_workout!.warmupExercises);
                            l[idx] = ex.copyWith(notes: r['notes'] as String);
                            _workout = _workout!.copyWith(warmupExercises: l);
                          }
                        } else {
                          final idx = _workout!.workoutExercises.indexWhere((e) => e.id == ex.id);
                          if (idx != -1) {
                            final l = List<WorkoutExerciseModel>.from(_workout!.workoutExercises);
                            l[idx] = ex.copyWith(notes: r['notes'] as String);
                            _workout = _workout!.copyWith(workoutExercises: l);
                          }
                        }
                      });
                  });
                },
                title: Center(
                  child: Text(
                    'Add Notes',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Cancel', style: AppTextStyles.buttonMedium),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}
