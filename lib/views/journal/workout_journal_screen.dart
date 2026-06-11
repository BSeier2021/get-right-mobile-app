import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get_right/models/workout_journal_model.dart';
import 'package:get_right/models/workout_exercise_model.dart';
import 'package:get_right/models/exercise_set_model.dart';
import 'package:get_right/models/journal_exercise_type.dart';
import 'package:get_right/repo/workout_repo.dart';
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
  List<WorkoutJournalModel> _journalEntries = [];
  Map<String, String> _workoutJournalByExerciseId = {};
  String? _workoutJournalId;
  bool _isLoading = true;
  bool _isSavingJournal = false;
  String? _loadError;
  final WorkoutRepository _workoutRepo = WorkoutRepository();
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
    _loadWorkoutJournal();
  }

  Future<void> _loadWorkoutJournal() async {
    await _refreshWorkoutJournalFromApi(showLoading: true);
  }

  WorkoutJournalModel _emptyWorkoutShell() {
    return WorkoutJournalModel(id: '', userId: 'user_1', date: DateTime.now(), warmupExercises: [], workoutExercises: [], createdAt: DateTime.now());
  }

  WorkoutJournalModel _reconcileExerciseSections(WorkoutJournalModel? previous, WorkoutJournalModel fromApi) {
    if (previous == null) return fromApi;

    final prevWarmupIds = previous.warmupExercises.map((e) => e.id).toSet();
    final prevWorkoutIds = previous.workoutExercises.map((e) => e.id).toSet();
    final apiWarmupIds = fromApi.warmupExercises.map((e) => e.id).toSet();
    final seen = <String>{};
    final warmup = <WorkoutExerciseModel>[];
    final workout = <WorkoutExerciseModel>[];

    void bucket(WorkoutExerciseModel ex) {
      if (!seen.add(ex.id)) return;
      if (ex.exerciseType?.isWarmup == true || prevWarmupIds.contains(ex.id) || apiWarmupIds.contains(ex.id)) {
        warmup.add(ex);
      } else {
        workout.add(ex);
      }
    }

    for (final ex in fromApi.warmupExercises) {
      bucket(ex);
    }
    for (final ex in fromApi.workoutExercises) {
      bucket(ex);
    }

    for (final ex in previous.warmupExercises) {
      if (!seen.contains(ex.id)) warmup.add(ex);
    }
    for (final ex in previous.workoutExercises) {
      if (!seen.contains(ex.id) && prevWorkoutIds.contains(ex.id)) workout.add(ex);
    }

    return fromApi.copyWith(warmupExercises: warmup, workoutExercises: workout);
  }

  void _mergeExercisesFromSaveResult(Map<String, dynamic> result) {
    final rawExercises = result['exercises'];
    if (rawExercises is! List || rawExercises.isEmpty) return;

    final exercises = rawExercises.whereType<WorkoutExerciseModel>().toList();
    if (exercises.isEmpty) return;

    final type = result['exerciseType'] is JournalExerciseType
        ? result['exerciseType'] as JournalExerciseType
        : (result['isWarmup'] == true ? JournalExerciseType.warmup : JournalExerciseType.workout);

    final typed = exercises
        .map((e) => e.exerciseType == null ? e.copyWith(exerciseType: type) : e)
        .toList();

    setState(() {
      _workout ??= _emptyWorkoutShell();
      if (type.isWarmup) {
        _workout = _workout!.copyWith(warmupExercises: [..._workout!.warmupExercises, ...typed]);
      } else {
        _workout = _workout!.copyWith(workoutExercises: [..._workout!.workoutExercises, ...typed]);
      }
    });
  }

  Future<void> _refreshWorkoutJournalFromApi({bool showLoading = false}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final page = await _workoutRepo.fetchWorkoutJournalEntries(dateFrom: DateTime.now());
      final rawEntries = WorkoutRepository.entriesForDay(page);
      final today = WorkoutRepository.todayEntryFrom(page);
      if (!mounted) return;

      final previousWorkout = _workout;
      setState(() {
        _journalEntries = rawEntries;
        _workoutJournalByExerciseId = WorkoutRepository.exerciseJournalMapFrom(rawEntries);
        _workoutJournalId = WorkoutRepository.primaryJournalIdForDay(rawEntries) ?? _workoutJournalId;
        if (today != null && today.id.isNotEmpty) {
          final merged = _reconcileExerciseSections(
            previousWorkout,
            today.copyWith(
              startedAt: previousWorkout?.startedAt,
              completedAt: previousWorkout?.completedAt,
              durationSeconds: previousWorkout?.durationSeconds ?? today.durationSeconds,
              caloriesBurned: previousWorkout?.caloriesBurned,
            ),
          );
          _workout = merged;
        } else if (_workout == null) {
          _workoutJournalId = null;
          _workout = _emptyWorkoutShell();
        }
        _isLoading = false;
        _loadError = null;
      });

      if (page.syncFailed && mounted) {
        Get.snackbar(
          'Sync unavailable',
          'Workout list could not be loaded from the server. You can still add exercises.',
          backgroundColor: AppColors.primaryGrayDark,
          colorText: AppColors.onSurface,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_workout == null) _workout = _emptyWorkoutShell();
        _loadError = null;
      });
      Get.snackbar('Sync unavailable', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
    }
  }

  WorkoutJournalModel? _journalEntryForExercise(String exerciseId) {
    final journalId = _workoutJournalByExerciseId[exerciseId];
    if (journalId == null) return null;
    return WorkoutRepository.journalEntryById(_journalEntries, journalId);
  }

  Future<bool> _persistJournalEntry({required String journalId, required List<String> workoutIds, int? duration, String? notes}) async {
    final entry = WorkoutRepository.journalEntryById(_journalEntries, journalId);
    if (entry == null) return false;

    setState(() => _isSavingJournal = true);
    try {
      await _workoutRepo.updateWorkoutJournal(journalId: journalId, workoutIds: workoutIds, duration: duration ?? entry.durationSeconds ?? 0, notes: notes ?? '');
      await _refreshWorkoutJournalFromApi();
      return true;
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSavingJournal = false);
    }
  }

  Future<void> _deleteExercise(WorkoutExerciseModel ex, bool isWarmup) async {
    final journalId = _workoutJournalByExerciseId[ex.id];
    if (journalId == null || !WorkoutRepository.isValidMongoId(journalId)) {
      setState(() {
        if (isWarmup) {
          _workout = _workout!.copyWith(warmupExercises: _workout!.warmupExercises.where((e) => e.id != ex.id).toList());
        } else {
          _workout = _workout!.copyWith(workoutExercises: _workout!.workoutExercises.where((e) => e.id != ex.id).toList());
        }
      });
      return;
    }

    final entry = WorkoutRepository.journalEntryById(_journalEntries, journalId);
    if (entry == null) return;

    final remainingIds = WorkoutRepository.workoutIdsFrom(entry).where((id) => id != ex.id).toList();
    await _persistJournalEntry(journalId: journalId, workoutIds: remainingIds);
  }

  Future<void> _reorderExercises(List<WorkoutExerciseModel> reordered, bool isWarmup) async {
    final idsByJournal = <String, List<String>>{};
    for (final ex in reordered) {
      final journalId = _workoutJournalByExerciseId[ex.id];
      if (journalId == null || !WorkoutRepository.isValidMongoId(ex.id)) continue;
      idsByJournal.putIfAbsent(journalId, () => []).add(ex.id);
    }

    if (idsByJournal.isEmpty) {
      setState(() {
        if (isWarmup) {
          _workout = _workout!.copyWith(warmupExercises: reordered);
        } else {
          _workout = _workout!.copyWith(workoutExercises: reordered);
        }
      });
      return;
    }

    setState(() => _isSavingJournal = true);
    try {
      for (final journalId in idsByJournal.keys) {
        final entry = WorkoutRepository.journalEntryById(_journalEntries, journalId);
        if (entry == null) continue;
        await _workoutRepo.updateWorkoutJournal(journalId: journalId, workoutIds: idsByJournal[journalId]!, duration: entry.durationSeconds ?? 0, notes: '');
      }
      await _refreshWorkoutJournalFromApi();
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
      }
    } finally {
      if (mounted) setState(() => _isSavingJournal = false);
    }
  }

  List<WorkoutExerciseModel> _applyExerciseNotes(List<WorkoutExerciseModel> exercises, String targetExerciseId, String notes) {
    final trimmed = notes.trim();
    return exercises.map((e) => e.id == targetExerciseId ? e.copyWith(notes: trimmed.isEmpty ? null : trimmed) : e).toList();
  }

  Future<void> _saveJournalNotes(WorkoutExerciseModel ex, String notes) async {
    setState(() {
      if (_workout == null) return;
      _workout = _workout!.copyWith(
        warmupExercises: _applyExerciseNotes(_workout!.warmupExercises, ex.id, notes),
        workoutExercises: _applyExerciseNotes(_workout!.workoutExercises, ex.id, notes),
      );
    });

    if (!WorkoutRepository.isValidMongoId(ex.id)) return;

    setState(() => _isSavingJournal = true);
    try {
      await _workoutRepo.updateWorkout(
        ex.id,
        WorkoutRepository.updateWorkoutBody(name: ex.exerciseName, exercise: WorkoutRepository.exerciseSetsToApi(ex.sets), notes: notes.trim()),
      );
      await _refreshWorkoutJournalFromApi();
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
      }
    } finally {
      if (mounted) setState(() => _isSavingJournal = false);
    }
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

  void _stopWorkout() async {
    _timer?.cancel();

    if (_workout != null && _startTime != null) {
      _workout = _workout!.copyWith(startedAt: _startTime, completedAt: DateTime.now(), durationSeconds: _seconds, caloriesBurned: _calories);
    }

    setState(() {
      _isStarted = false;
      _isPaused = false;
    });

    await _finalizeWorkoutJournal();

    if (!mounted) return;

    Get.to(
      () => WorkoutCelebrationScreen(duration: _formatTime(_seconds), calories: _calories, workoutName: _getWorkoutName()),
      transition: Transition.zoom,
      duration: const Duration(milliseconds: 500),
    )?.then((_) {
      if (!mounted) return;
      setState(() {
        _seconds = 0;
        _calories = 0;
        _startTime = null;
      });
    });
  }

  Future<void> _finalizeWorkoutJournal() async {
    if (_workout == null) return;

    final workoutIds = _workout!.allExercises.where((e) => WorkoutRepository.isValidMongoId(e.id)).map((e) => e.id).toList();
    if (workoutIds.isEmpty) {
      await _refreshWorkoutJournalFromApi();
      return;
    }

    final now = DateTime.now();
    final dateKey = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      if (WorkoutRepository.isValidMongoId(_workoutJournalId)) {
        await _workoutRepo.updateWorkoutJournal(journalId: _workoutJournalId!, workoutIds: workoutIds, duration: _seconds, notes: '');
      } else {
        await _workoutRepo.submitWorkoutJournal(date: dateKey, workoutIds: workoutIds, duration: _seconds, notes: '');
      }
      await _refreshWorkoutJournalFromApi();
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
    }
  }

  String _getWorkoutName() {
    if (_workout == null) return 'Workout';
    final exerciseCount = _workout!.warmupExercises.length + _workout!.workoutExercises.length;
    return '$exerciseCount Exercise${exerciseCount != 1 ? 's' : ''}';
  }

  // ignore: unused_element
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

  Future<void> _ensureWorkoutJournalId() async {
    if (WorkoutRepository.isValidMongoId(_workoutJournalId)) return;
    _workoutJournalId = await _workoutRepo.findWorkoutJournalIdForToday();
  }

  List<String> _currentJournalWorkoutIds() {
    if (_workout == null) return const [];
    return _workout!.allExercises.where((e) => WorkoutRepository.isValidMongoId(e.id)).map((e) => e.id).toList();
  }

  List<String> _currentAddedLibraryExerciseIds() {
    if (_workout == null) return const [];
    return _workout!.allExercises.map((e) => e.exerciseId).where((id) => id.isNotEmpty).toSet().toList();
  }

  Future<void> _openAddExerciseFlow(JournalExerciseType exerciseType) async {
    try {
      await _ensureWorkoutJournalId();
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }

    await Get.toNamed(
      AppRoutes.exerciseConfiguration,
      arguments: {
        'exerciseType': exerciseType,
        'isWarmup': exerciseType.isWarmup,
        'workoutJournalId': _workoutJournalId,
        'journalWorkoutIds': _currentJournalWorkoutIds(),
        'addedExerciseIds': _currentAddedLibraryExerciseIds(),
      },
    )?.then((r) async {
      if (r is! Map || r['exercises'] == null) return;
      _mergeExercisesFromSaveResult(Map<String, dynamic>.from(r));
      await _refreshWorkoutJournalFromApi();
    });
  }

  void _onAddWarmup() => _openAddExerciseFlow(JournalExerciseType.warmup);

  void _onAddWorkout() => _openAddExerciseFlow(JournalExerciseType.workout);

  // ignore: unused_element
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
                  : _loadError != null
                  ? _buildLoadError()
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
          : _loadError != null
          ? _buildLoadError()
          : _workout == null || _workout!.isEmpty
          ? _buildEmpty()
          : _buildContent(),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Could not load workout journal',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _loadError!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadWorkoutJournal, child: const Text('Retry')),
          ],
        ),
      ),
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
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          _onAddWarmup();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(0, 0, 0, 0),
                          foregroundColor: const Color(0xFF777777),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                            side: const BorderSide(
                              color: Color(0xFF777777), // Added border color
                              width: 1.2,
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Warmup',
                          style: AppTextStyles.buttonMedium.copyWith(color: Color(0xFF777777), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          _onAddWorkout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
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

  void _showShareDialog() {
    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Share Post',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.red),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Choose how you want to share your activity', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOption(icon: Icons.message_outlined, label: 'Message', onTap: () => _shareVia('message')),
                  _buildShareOption(icon: Icons.link, label: 'Copy Link', onTap: () => _shareVia('copy')),
                  _buildShareOption(icon: Icons.share_outlined, label: 'More', onTap: () => _shareVia('more')),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  Widget _buildShareOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withOpacity(0.25)),
            ),
            child: Icon(icon, color: const Color(0xFF1E5B2E)),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface)),
        ],
      ),
    );
  }

  void _shareVia(String method) {
    Get.back();
    switch (method) {
      case 'message':
        Get.snackbar('Share', 'Open messages to share', backgroundColor: AppColors.accent, colorText: AppColors.onAccent);
        break;
      case 'copy':
        Get.snackbar('Link Copied', 'Workout link copied to clipboard', backgroundColor: AppColors.completed, colorText: AppColors.onError);
        break;
      default:
        Get.snackbar('Share', 'Opening system share sheet', backgroundColor: AppColors.accentVariant, colorText: Colors.white);
    }
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isStarted) _buildMetrics(),

                if (_workout!.warmupExercises.isNotEmpty) ...[_buildHeader('Warmup', isWarmup: true), ..._buildExercisesList(_workout!.warmupExercises, true)],

                if (_workout!.workoutExercises.isNotEmpty) ...[_buildHeader('Workout', isWarmup: false), ..._buildExercisesList(_workout!.workoutExercises, false)],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        /// Bottom Buttons
        if (!_isStarted && !_workout!.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(33, 33, 78, 49),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: AppColors.accentVariant.withOpacity(0.25), width: 2),
                    ),
                    child: SvgPicture.asset('assets/icons/share.svg', width: 22, colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn)).paddingAll(5),
                  ),
                  onPressed: _showShareDialog,
                ),
                ElevatedButton.icon(
                  onPressed: _startWorkout,
                  icon: Icon(Icons.play_arrow, color: AppColors.white, size: 25),

                  label: Text('Start Workout', style: AppTextStyles.buttonMedium),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    elevation: 2,
                  ),
                ),

                if (_workout != null && !_workout!.isEmpty)
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(33, 33, 78, 49),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: AppColors.accentVariant.withOpacity(0.25), width: 2),
                      ),
                      child: Icon(Icons.add, color: AppColors.accentVariant, size: 30.sp),
                    ),
                    onPressed: _showAddExerciseDialog,
                  ),
              ],
            ),
          ),
      ],
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

  Widget _buildHeader(String title, {bool isWarmup = false}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(
      children: [
        // Icon(icon, color: isWarmup ? Colors.red : AppColors.accent, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  WorkoutExerciseModel _exerciseWithJournalNotes(WorkoutExerciseModel ex) => ex;

  (WorkoutExerciseModel, WorkoutExerciseModel) _orderedSupersetPair(WorkoutExerciseModel a, WorkoutExerciseModel b) {
    if (a.supersetOrder != null && b.supersetOrder != null) {
      return a.supersetOrder! <= b.supersetOrder! ? (a, b) : (b, a);
    }
    return (a, b);
  }

  /// Build exercises list with superset grouping support
  List<Widget> _buildExercisesList(List<WorkoutExerciseModel> exercises, bool isWarmup) {
    final List<Widget> widgets = [];
    final Set<String> processedSupersets = {};

    for (int i = 0; i < exercises.length; i++) {
      final exercise = _exerciseWithJournalNotes(exercises[i]);

      // Check if this exercise is part of a superset
      if (exercise.isSuperset && exercise.supersetId != null) {
        // Skip if we've already processed this superset group (e.g. A1 + A2 → group A)
        if (processedSupersets.contains(exercise.supersetId)) {
          continue;
        }

        // Find the partner exercise in the same superset group
        final otherRaw = exercises.firstWhereOrNull((e) => e.isSuperset && e.supersetId == exercise.supersetId && e.id != exercise.id);
        final otherExercise = otherRaw != null ? _exerciseWithJournalNotes(otherRaw) : null;

        if (otherExercise != null) {
          final pair = _orderedSupersetPair(exercise, otherExercise);
          final ex1 = pair.$1;
          final ex2 = pair.$2;
          // Add superset card
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SupersetCard(
                exercise1: ex1,
                exercise2: ex2,
                onMenuTap1: () => _showMenu(ex1, isWarmup),
                onMenuTap2: () => _showMenu(ex2, isWarmup),
                onTimerTap1: () {
                  if (ex1.hasTimedSets) {
                    Get.toNamed(AppRoutes.workoutTimer, arguments: {'exercise': ex1});
                  }
                },
                onTimerTap2: () {
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
                  Get.toNamed(
                    AppRoutes.exerciseConfiguration,
                    arguments: {'isEditing': true, 'existingExercise': ex, 'isWarmup': isWarmup, 'exerciseType': JournalExerciseType.fromIsWarmup(isWarmup)},
                  )?.then((r) async {
                    if (r != null) await _refreshWorkoutJournalFromApi();
                  });
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
                  final displayEx = _exerciseWithJournalNotes(ex);
                  Get.toNamed(
                    AppRoutes.videoWalkthrough,
                    arguments: {
                      'exerciseName': displayEx.exerciseName,
                      'exerciseId': displayEx.exerciseId,
                      'videoUrl': displayEx.videoUrl,
                      'videoThumbnailUrl': displayEx.videoThumbnailUrl ?? displayEx.iconUrl,
                    },
                  );
                },
                title: Center(
                  child: Text(
                    'Video Walkthrough',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              ListTile(
                onTap: _isSavingJournal
                    ? null
                    : () {
                        Get.back();
                        _deleteExercise(ex, isWarmup);
                      },
                title: Center(
                  child: Text(
                    'Delete',
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.red, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              ListTile(
                onTap: _isSavingJournal
                    ? null
                    : () {
                        Get.back();
                        Get.toNamed(AppRoutes.reorderExercises, arguments: {'exercises': isWarmup ? _workout!.warmupExercises : _workout!.workoutExercises})?.then((r) {
                          if (r != null && r['exercises'] != null) {
                            _reorderExercises(r['exercises'] as List<WorkoutExerciseModel>, isWarmup);
                          }
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
                onTap: _isSavingJournal
                    ? null
                    : () {
                        Get.back();
                        Get.toNamed(AppRoutes.addNotes, arguments: {'exerciseName': ex.exerciseName, 'existingNotes': ex.notes ?? ''})?.then((r) {
                          if (r != null && r['notes'] != null) {
                            _saveJournalNotes(ex, r['notes'] as String);
                          }
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
                      backgroundColor: AppColors.accentVariant,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
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
