import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get_right/models/exercise_library_model.dart';
import 'package:get_right/models/exercise_set_model.dart';
import 'package:get_right/models/journal_exercise_type.dart';
import 'package:get_right/models/workout_exercise_model.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/home/dashboard_screen.dart';

class ExerciseConfigurationScreen extends StatefulWidget {
  const ExerciseConfigurationScreen({super.key});
  @override
  State<ExerciseConfigurationScreen> createState() => _ExerciseConfigurationScreenState();
}

class _ExerciseConfigurationScreenState extends State<ExerciseConfigurationScreen> {
  bool _isWarmup = false;
  JournalExerciseType _exerciseType = JournalExerciseType.workout;
  bool _isManual = false;
  bool _isSuperset = false;
  bool _isEditing = false;
  String? _editingWorkoutId;
  bool _hasAskedWarmupWorkout = false;
  bool _isSaving = false;
  String? _workoutJournalId;
  List<String> _journalWorkoutIds = const [];
  List<String> _addedExerciseIds = const [];
  final WorkoutRepository _workoutRepo = WorkoutRepository();
  final TextEditingController _nameController = TextEditingController();
  List<_Config> _configs = [];
  String? _focusedFieldType; // 'reps' or 'weight'
  int? _focusedConfigIdx;
  int? _focusedSetIdx;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      _isWarmup = args['isWarmup'] ?? false;
      _exerciseType = JournalExerciseType.fromArgs(args) ?? JournalExerciseType.fromIsWarmup(_isWarmup);
      _isWarmup = _exerciseType.isWarmup;
      _isManual = args['isManual'] ?? false;
      _isSuperset = args['isSuperset'] ?? false;
      _hasAskedWarmupWorkout = args['isWarmup'] != null; // If isWarmup is provided, we've already asked
      _workoutJournalId = args['workoutJournalId']?.toString() ?? args['workoutJournal']?.toString();
      final rawJournalWorkoutIds = args['journalWorkoutIds'];
      if (rawJournalWorkoutIds is List) {
        _journalWorkoutIds = rawJournalWorkoutIds.map((e) => e.toString()).where(WorkoutRepository.isValidMongoId).toList();
      }
      final rawAddedExerciseIds = args['addedExerciseIds'];
      if (rawAddedExerciseIds is List) {
        _addedExerciseIds = rawAddedExerciseIds.map((e) => e.toString()).where((id) => id.isNotEmpty).toList();
      }

      // Handle editing existing exercise
      if (args['existingExercise'] != null) {
        _isEditing = true;
        final existingEx = args['existingExercise'] as WorkoutExerciseModel;
        _editingWorkoutId = WorkoutRepository.isValidMongoId(existingEx.id) ? existingEx.id : null;
        _nameController.text = existingEx.exerciseName;

        // Determine mainType (Reps vs Time) from sets
        String mainType = 'Reps';
        if (existingEx.sets.isNotEmpty && existingEx.sets.any((s) => s.isTimed)) {
          mainType = 'Time';
        }

        // Determine extraType (Weight vs Distance) from sets
        String extraType = 'Weight';
        if (existingEx.sets.isNotEmpty && existingEx.sets.any((s) => s.isDistanceBased)) {
          extraType = 'Distance';
        }

        // Create config with existing data
        final cfg = _Config(name: existingEx.exerciseName, id: existingEx.exerciseId, iconUrl: existingEx.iconUrl);
        cfg.mainType = mainType;
        cfg.extraType = extraType;

        // Populate sets from existing exercise
        cfg.sets.clear();
        for (var set in existingEx.sets) {
          final setData = _SetData();
          if (mainType == 'Time') {
            setData.time = set.timeSeconds ?? 0;
          } else {
            setData.reps = set.reps ?? 0;
            if (set.repsType == 'FAILURE' || set.repsType == 'AMRAP') {
              setData.repsType = set.repsType;
            }
          }
          if (extraType == 'Distance') {
            setData.distance = set.distance ?? 0;
            setData.distanceUnit = set.distanceUnit ?? 'miles';
          } else {
            setData.weight = set.weight ?? 0;
            setData.isBodyweight = set.weightType == 'BW';
          }
          cfg.sets.add(setData);
        }

        // If no sets, add default sets
        if (cfg.sets.isEmpty) {
          cfg.sets.addAll([_SetData(), _SetData(), _SetData()]);
        }

        _configs.add(cfg);
      } else if (_isSuperset && args['exercises'] != null) {
        for (var ex in args['exercises'] as List<ExerciseLibraryModel>) {
          _configs.add(_Config(name: ex.name, id: ex.id, iconUrl: ex.iconUrl));
        }
      } else if (args['exercise'] != null) {
        final ex = args['exercise'] as ExerciseLibraryModel;
        _nameController.text = ex.name; // Pre-fill name for library exercises
        _configs.add(_Config(name: ex.name, id: ex.id, iconUrl: ex.iconUrl));
      } else if (_isManual) {
        _configs.add(_Config(name: '', id: 'manual_${DateTime.now().millisecondsSinceEpoch}'));
      }
    }
    if (_configs.isEmpty) {
      _configs.add(_Config(name: '', id: 'manual_${DateTime.now().millisecondsSinceEpoch}'));
    }

    // Show popup asking warmup/workout if not already determined
    if (!_hasAskedWarmupWorkout) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWarmupWorkoutDialog());
    }
  }

  void _showWarmupWorkoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Exercise',
                style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Would you like to add this exercise to warmup or workout?',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _exerciseType = JournalExerciseType.warmup;
                          _isWarmup = true;
                          _hasAskedWarmupWorkout = true;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        shadowColor: AppColors.error.withOpacity(0.4),
                      ),
                      child: Text(
                        'Warmup',
                        style: AppTextStyles.buttonMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _exerciseType = JournalExerciseType.workout;
                          _isWarmup = false;
                          _hasAskedWarmupWorkout = true;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        shadowColor: AppColors.accent.withOpacity(0.4),
                      ),
                      child: Text(
                        'Workout',
                        style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.bold),
                      ),
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

  void _openExerciseSelectionForCard(int cardIndex) {
    Get.toNamed(
      AppRoutes.exerciseSelection,
      arguments: {
        'isWarmup': _isWarmup,
        'exerciseType': _exerciseType,
        'isSuperset': false,
        'workoutJournalId': _workoutJournalId,
        'journalWorkoutIds': _journalWorkoutIds,
        'addedExerciseIds': _addedExerciseIds,
      },
    )?.then((result) {
      if (result != null && result['exercise'] != null) {
        final ex = result['exercise'] as ExerciseLibraryModel;
        setState(() {
          // Update the specific card's exercise name
          if (cardIndex < _configs.length) {
            _configs[cardIndex].name = ex.name;
            _configs[cardIndex].id = ex.id;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    // Dispose all configs and their sets
    for (var cfg in _configs) {
      cfg.dispose();
      for (var setData in cfg.sets) {
        setData.dispose();
      }
    }
    super.dispose();
  }

  static const int _maxExerciseNameLength = 80;
  static const int _maxReps = 999;
  static const int _maxTimeMinutes = 180;
  static const int _maxTimeSeconds = _maxTimeMinutes * 60;
  static const double _maxWeight = 2000;
  static const double _maxDistance = 1000;

  static final _decimalInputFormatter = FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));

  void _setMainTypeForConfig(_Config cfg, String mainType) {
    cfg.mainType = mainType;
    cfg.extraType = mainType == 'Time' ? 'Distance' : 'Weight';
    for (final set in cfg.sets) {
      set.updateControllerText(cfg.mainType);
    }
  }

  String? _validateConfig(_Config cfg, int exerciseNumber) {
    final name = (cfg.name.isNotEmpty ? cfg.name : _nameController.text).trim();
    if (name.isEmpty) {
      return _configs.length > 1 ? 'Please enter a name for exercise $exerciseNumber' : 'Please enter exercise name';
    }
    if (name.length > _maxExerciseNameLength) {
      return 'Exercise name cannot exceed $_maxExerciseNameLength characters';
    }

    var activeSets = 0;
    for (var j = 0; j < cfg.sets.length; j++) {
      final setErr = _validateSetForSave(cfg.sets[j], cfg, j + 1);
      if (setErr != null) return setErr;
      if (_setHasData(cfg.sets[j], cfg)) activeSets++;
    }

    if (activeSets == 0) {
      return _configs.length > 1 ? 'Add at least one valid set for exercise $exerciseNumber' : 'Add at least one valid set';
    }
    return null;
  }

  String? _validateSetForSave(_SetData setData, _Config cfg, int setNumber) {
    if (!_setHasData(setData, cfg)) return null;

    if (cfg.mainType == 'Time') {
      if (setData.time <= 0) return 'Set $setNumber: enter a valid time greater than 0';
      if (setData.time > _maxTimeSeconds) return 'Set $setNumber: time cannot exceed $_maxTimeSeconds seconds';
    } else if (setData.repsType != 'AMRAP' && setData.repsType != 'FAILURE') {
      if (setData.reps <= 0) return 'Set $setNumber: enter reps between 1 and $_maxReps';
      if (setData.reps > _maxReps) return 'Set $setNumber: reps cannot exceed $_maxReps';
    }

    if (cfg.extraType == 'Weight') {
      if (setData.weight < 0) return 'Set $setNumber: weight cannot be negative';
      if (!setData.isBodyweight && setData.weight > _maxWeight) {
        return 'Set $setNumber: weight cannot exceed ${_maxWeight.toInt()}';
      }
    }

    if (cfg.extraType == 'Distance') {
      if (setData.distance <= 0) return 'Set $setNumber: enter distance greater than 0';
      if (setData.distance > _maxDistance) return 'Set $setNumber: distance cannot exceed $_maxDistance';
    }

    return null;
  }

  Future<void> _onSave() async {
    for (var i = 0; i < _configs.length; i++) {
      final err = _validateConfig(_configs[i], i + 1);
      if (err != null) {
        Get.snackbar('Invalid values', err, backgroundColor: AppColors.error, colorText: AppColors.onError);
        return;
      }
    }

    final List<WorkoutExerciseModel> exercises = [];
    final now = DateTime.now();

    final createdApiIds = <String>[];
    if (_isEditing) {
      if (!WorkoutRepository.isValidMongoId(_editingWorkoutId)) {
        Get.snackbar('Error', 'Workout id is missing or invalid', backgroundColor: AppColors.error, colorText: AppColors.onError);
        return;
      }
      setState(() => _isSaving = true);
      try {
        for (var i = 0; i < _configs.length; i++) {
          final cfg = _configs[i];
          final name = cfg.name.isNotEmpty ? cfg.name : _nameController.text;
          await _workoutRepo.updateWorkout(_editingWorkoutId!, WorkoutRepository.updateWorkoutBody(name: name, exercise: _buildApiExerciseSets(cfg)));
        }
      } catch (e) {
        if (mounted) setState(() => _isSaving = false);
        Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
        return;
      }
      if (mounted) setState(() => _isSaving = false);
    } else if (!_isEditing) {
      setState(() => _isSaving = true);
      try {
        // One journal id per day — always attach warmups and workouts to the same entry.
        var journalId = WorkoutRepository.isValidMongoId(_workoutJournalId) ? _workoutJournalId!.trim() : null;
        journalId ??= await _workoutRepo.findWorkoutJournalIdForToday(date: HomeNavigationController.journalDayOrNow());

        for (var i = 0; i < _configs.length; i++) {
          final cfg = _configs[i];
          final name = cfg.name.isNotEmpty ? cfg.name : _nameController.text;
          final refId = cfg.id.trim();
          final body = WorkoutRepository.createWorkoutBody(
            type: _exerciseType.apiValue,
            name: name,
            exercise: _buildApiExerciseSets(cfg),
            refExercise: refId.isNotEmpty && !refId.startsWith('manual_') ? refId : null,
            supersetIdentifier: _isSuperset ? 'A${i + 1}' : null,
            workoutJournal: journalId,
          );
          final response = await _workoutRepo.createWorkout(body);
          final apiId = WorkoutRepository.createdWorkoutId(response);
          if (apiId != null && apiId.isNotEmpty) createdApiIds.add(apiId);

          if (!WorkoutRepository.isValidMongoId(journalId)) {
            final createdJournalId = WorkoutRepository.journalIdFromCreateWorkout(response);
            if (WorkoutRepository.isValidMongoId(createdJournalId)) {
              journalId = createdJournalId;
            }
          }
        }

        _workoutJournalId = journalId;
      } catch (e) {
        if (mounted) setState(() => _isSaving = false);
        Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
        return;
      }
      if (mounted) setState(() => _isSaving = false);
    }

    final supersetGroupId = _isSuperset ? 'A' : null;
    for (var i = 0; i < _configs.length; i++) {
      final cfg = _configs[i];
      final name = cfg.name.isNotEmpty ? cfg.name : _nameController.text;
      final sets = cfg.sets.asMap().entries.where((e) => _setHasData(e.value, cfg)).map((e) {
        final setIdx = e.key;
        final s = e.value;
        return ExerciseSetModel(
          id: 'set_${setIdx + 1}_${now.millisecondsSinceEpoch}',
          setNumber: setIdx + 1,
          reps: cfg.mainType != 'Time' ? (s.repsType == 'AMRAP' || s.repsType == 'FAILURE' ? null : s.reps) : null,
          repsType: cfg.mainType != 'Time' ? (s.repsType ?? 'standard') : null,
          timeSeconds: cfg.mainType == 'Time' && s.time > 0 ? s.time : null,
          weight: cfg.extraType == 'Weight' ? s.weight : null,
          weightType: cfg.extraType == 'Weight' ? (s.isBodyweight ? 'BW' : (s.weight > 0 ? 'standard' : null)) : null,
          distance: cfg.extraType == 'Distance' ? s.distance : null,
          distanceUnit: cfg.extraType == 'Distance' ? s.distanceUnit : null,
        );
      }).toList();
      final apiId = _isEditing ? _editingWorkoutId : (i < createdApiIds.length ? createdApiIds[i] : null);
      exercises.add(
        WorkoutExerciseModel(
          id: apiId ?? 'ex_${now.millisecondsSinceEpoch}_$i',
          exerciseName: name,
          exerciseId: cfg.id,
          iconUrl: cfg.iconUrl,
          sets: sets,
          isSuperset: _isSuperset,
          supersetId: supersetGroupId,
          supersetOrder: _isSuperset ? i : null,
          date: now,
          createdAt: now,
          exerciseType: _exerciseType,
        ),
      );
    }
    Get.back(result: {'exercises': exercises, 'isWarmup': _isWarmup, 'exerciseType': _exerciseType, if (_workoutJournalId != null) 'workoutJournalId': _workoutJournalId});
  }

  List<Map<String, dynamic>> _buildApiExerciseSets(_Config cfg) {
    const defaultRestTime = 90;
    final sets = <Map<String, dynamic>>[];

    for (var i = 0; i < cfg.sets.length; i++) {
      final s = cfg.sets[i];
      if (!_setHasData(s, cfg)) continue;

      final entry = <String, dynamic>{'sets': i + 1, 'restTime': defaultRestTime};

      if (cfg.mainType == 'Time') {
        entry['reps'] = WorkoutRepository.encodeTimedRepsForApi(s.time);
      } else if (s.repsType == 'FAILURE') {
        entry['reps'] = 'FAILURE';
      } else if (s.repsType == 'AMRAP') {
        entry['reps'] = 'AMRAP';
      } else {
        entry['reps'] = s.reps;
      }

      if (cfg.extraType == 'Weight') {
        if (s.isBodyweight) {
          entry['weight'] = 'BW';
        } else if (s.weight > 0) {
          entry['weight'] = s.weight % 1 == 0 ? s.weight.toInt() : s.weight;
        }
      }

      if (cfg.extraType == 'Distance' && s.distance > 0) {
        entry['distance'] = s.distance % 1 == 0 ? s.distance.toInt() : s.distance;
      }

      sets.add(entry);
    }

    return sets;
  }

  bool _setHasData(_SetData setData, _Config cfg) {
    if (cfg.mainType == 'Time') return setData.time > 0;
    if (setData.repsType == 'FAILURE' || setData.repsType == 'AMRAP') return true;
    if (setData.reps > 0) return true;
    if (cfg.extraType == 'Weight' && (setData.weight > 0 || setData.isBodyweight)) return true;
    if (cfg.extraType == 'Distance' && setData.distance > 0) return true;
    return false;
  }

  void _showPercentageCalc(int cfgIdx, int setIdx) {
    const double pr = 315.0;
    double pct = 75.0;
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 8,
        child: StatefulBuilder(
          builder: (ctx, setDlg) {
            final calc = (pr * pct / 100).round();
            return Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.2), AppColors.accent.withOpacity(0.1)]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.calculate_rounded, color: AppColors.accent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Percentage Calculator',
                            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: Icon(Icons.close_rounded, color: AppColors.primaryGrayDark),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.accent.withOpacity(0.1), AppColors.accent.withOpacity(0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'PERSONAL RECORD',
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w700, letterSpacing: 1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bench Press',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pr.toInt()} lbs',
                          style: AppTextStyles.headlineMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'SELECT PERCENTAGE',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [50, 60, 70, 75, 80, 85, 90, 95]
                        .map(
                          (p) => GestureDetector(
                            onTap: () => setDlg(() => pct = p.toDouble()),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: pct == p ? LinearGradient(colors: [AppColors.accent, AppColors.accent.withOpacity(0.85)]) : null,
                                color: pct == p ? null : AppColors.primaryGrayLight.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: pct == p ? AppColors.accent : AppColors.primaryGrayLight.withOpacity(0.5), width: 1.5),
                                boxShadow: pct == p ? [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
                              ),
                              child: Text(
                                '$p%',
                                style: AppTextStyles.labelLarge.copyWith(color: pct == p ? AppColors.onAccent : AppColors.onSurface, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.trending_up_rounded, color: AppColors.accent, size: 24),
                        const SizedBox(width: 12),
                        Text('≈ $calc lbs', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _configs[cfgIdx].sets[setIdx].weight = calc.toDouble());
                        Get.back();
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 22),
                      label: Text('Apply to Set ${setIdx + 1}', style: AppTextStyles.buttonMedium),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        elevation: 2,
                        shadowColor: AppColors.accent.withOpacity(0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _applyRepsTypeToSet(_SetData setData, _Config cfg, String type) {
    setData.repsTimeFocusNode.unfocus();
    setData.repsType = type;
    setData.reps = 0;
    setData.updateControllerText(cfg.mainType, force: true);
    _focusedFieldType = null;
    _focusedConfigIdx = null;
    _focusedSetIdx = null;
  }

  Widget _buildKeyboardToolbar() {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: _focusedFieldType == 'reps'
          ? Row(
              children: [
                // AMRAP button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_focusedConfigIdx != null && _focusedSetIdx != null) {
                        final cfg = _configs[_focusedConfigIdx!];
                        final setData = cfg.sets[_focusedSetIdx!];
                        setState(() => _applyRepsTypeToSet(setData, cfg, 'AMRAP'));
                        FocusScope.of(context).unfocus();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                      shadowColor: AppColors.accent.withOpacity(0.3),
                    ),
                    child: Text(
                      'AMRAP',
                      style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // FAILURE button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_focusedConfigIdx != null && _focusedSetIdx != null) {
                        final cfg = _configs[_focusedConfigIdx!];
                        final setData = cfg.sets[_focusedSetIdx!];
                        setState(() => _applyRepsTypeToSet(setData, cfg, 'FAILURE'));
                        FocusScope.of(context).unfocus();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                      shadowColor: AppColors.accent.withOpacity(0.3),
                    ),
                    child: Text(
                      'FAILURE',
                      style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Done button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _focusedFieldType = null;
                        _focusedConfigIdx = null;
                        _focusedSetIdx = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                      shadowColor: AppColors.accent.withOpacity(0.3),
                    ),
                    child: Text(
                      'Done',
                      style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // BW button for weight field
                _focusedFieldType == 'weight'
                    ? ElevatedButton(
                        onPressed: () {
                          if (_focusedConfigIdx != null && _focusedSetIdx != null) {
                            final cfg = _configs[_focusedConfigIdx!];
                            final setData = cfg.sets[_focusedSetIdx!];
                            setState(() {
                              setData.weight = 0; // 0 represents Bodyweight
                              setData.isBodyweight = true; // Mark as explicitly set to BW
                              _focusedFieldType = null;
                              _focusedConfigIdx = null;
                              _focusedSetIdx = null;
                            });
                            FocusScope.of(context).unfocus();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                          shadowColor: AppColors.accent.withOpacity(0.3),
                        ),
                        child: Text(
                          'BW',
                          style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      )
                    : const SizedBox.shrink(),
                // Done button
                ElevatedButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _focusedFieldType = null;
                      _focusedConfigIdx = null;
                      _focusedSetIdx = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    shadowColor: AppColors.accent.withOpacity(0.3),
                  ),
                  child: Text(
                    'Done',
                    style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSaveButton() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _onSave,
            icon: _isSaving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
                : const Icon(Icons.check_rounded, size: 22),
            label: Text(
              _isSaving ? 'Saving...' : 'Save Exercise',
              style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              elevation: 6,
              shadowColor: AppColors.accent.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = keyboardInset > 0;
    final showSaveButton = _focusedFieldType == null && !keyboardOpen;
    final showKeyboardToolbar = _focusedFieldType != null && keyboardOpen;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() {
          _focusedFieldType = null;
          _focusedConfigIdx = null;
          _focusedSetIdx = null;
        });
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
            ),
            onPressed: () => Get.back(),
          ),
          title: Text(
            'Configure Exercise',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _isSuperset,
                          onChanged: (value) {
                            setState(() {
                              _isSuperset = value ?? false;
                              if (_isSuperset && _configs.length < 2) {
                                final firstConfig = _configs[0];
                                final secondConfig = _Config(name: '', id: 'manual_${DateTime.now().millisecondsSinceEpoch}');
                                secondConfig.mainType = firstConfig.mainType;
                                secondConfig.extraType = firstConfig.extraType;
                                secondConfig.sets.clear();
                                for (var set in firstConfig.sets) {
                                  final newSet = _SetData();
                                  newSet.reps = set.reps;
                                  newSet.time = set.time;
                                  newSet.weight = set.weight;
                                  newSet.distance = set.distance;
                                  newSet.distanceUnit = set.distanceUnit;
                                  newSet.isBodyweight = set.isBodyweight;
                                  secondConfig.sets.add(newSet);
                                }
                                _configs.add(secondConfig);
                              } else if (!_isSuperset && _configs.length > 1) {
                                _configs.removeRange(1, _configs.length);
                              }
                            });
                          },
                          activeColor: AppColors.accent,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        Text(
                          'Create Superset',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ..._configs
                        .asMap()
                        .entries
                        .map(
                          (e) => Padding(
                            padding: EdgeInsets.only(bottom: e.key < _configs.length - 1 ? 20 : 0),
                            child: _buildCard(e.value, e.key),
                          ),
                        )
                        .toList(),
                  ],
                ),
              ),
            ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 100),
              padding: EdgeInsets.only(bottom: keyboardOpen ? keyboardInset : 0),
              child: showKeyboardToolbar
                  ? _buildKeyboardToolbar()
                  : showSaveButton
                  ? _buildSaveButton()
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _openExerciseSelection(int cfgIndex) async {
    final result = await Get.toNamed(
      AppRoutes.exerciseSelection,
      arguments: {
        'isWarmup': _isWarmup,
        'exerciseType': _exerciseType,
        'selectOnly': true,
        'workoutJournalId': _workoutJournalId,
        'journalWorkoutIds': _journalWorkoutIds,
        'addedExerciseIds': _addedExerciseIds,
      },
    );
    if (result != null && result['exercise'] != null) {
      final exercise = result['exercise'] as ExerciseLibraryModel;
      setState(() {
        if (cfgIndex < _configs.length) {
          _configs[cfgIndex].name = exercise.name;
          _configs[cfgIndex].id = exercise.id;
          _configs[cfgIndex].nameController.text = exercise.name;
        }
      });
    }
  }

  Widget _buildCard(_Config cfg, int idx) {
    // final isMan = cfg.name.isEmpty || _isEditing;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 2),
        boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: cfg.nameController,
            maxLength: _maxExerciseNameLength,
            inputFormatters: [LengthLimitingTextInputFormatter(_maxExerciseNameLength)],
            onChanged: (value) {
              setState(() {
                cfg.name = value;
              });
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.white,
              hintText: 'Enter exercise name',
              hintStyle: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGrayDark.withOpacity(0.6)),
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
                onPressed: () => _openExerciseSelection(idx),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          // "Two tabs" selector (like the screenshot): main metric (Reps/Time) + extra metric (Weight/Distance)
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: ['Reps', 'Time'].map((t) {
                      final sel = cfg.mainType == t;
                      final icons = {'Reps': Icons.repeat_rounded, 'Time': Icons.timer_outlined};
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _setMainTypeForConfig(cfg, t)),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: sel
                                  ? LinearGradient(
                                      colors: [AppColors.accentVariant, AppColors.accentVariant.withOpacity(0.85)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: sel ? null : Colors.transparent,
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: sel ? [BoxShadow(color: AppColors.accentVariant.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
                            ),
                            child: Center(
                              child: Text(
                                t,
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: sel ? AppColors.onAccent : AppColors.onSurface.withOpacity(0.8),
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: ['Weight', 'Distance'].map((t) {
                      final sel = cfg.extraType == t;
                      final icons = {'Weight': Icons.fitness_center, 'Distance': Icons.straighten_rounded};
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => cfg.extraType = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: sel
                                  ? LinearGradient(
                                      colors: [AppColors.accentVariant, AppColors.accentVariant.withOpacity(0.85)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: sel ? null : Colors.transparent,
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: sel ? [BoxShadow(color: AppColors.accentVariant.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
                            ),
                            child: Center(
                              child: Text(
                                t,
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: sel ? AppColors.onAccent : AppColors.onSurface.withOpacity(0.8),
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      'SET',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.black, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      (cfg.mainType == 'Time' ? 'TIME (s)' : 'REPS').toUpperCase(),
                      textAlign: TextAlign.left,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.black, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ).paddingOnly(left: 10),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      (cfg.extraType == 'Distance' ? 'DISTANCE (mi)' : 'WEIGHT (lbs)').toUpperCase(),
                      textAlign: TextAlign.left,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.black, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ).paddingSymmetric(horizontal: 10),

              const SizedBox(height: 12),
              ...cfg.sets.asMap().entries.map((e) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildSetRow(cfg, idx, e.key, e.value))),
              const SizedBox(height: 24),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50.h,
                  child: ElevatedButton.icon(
                    onPressed: cfg.sets.length > 1 ? () => setState(() => cfg.sets.removeLast()) : null,
                    icon: Icon(Icons.remove_rounded, size: 18.sp, color: const Color.fromARGB(255, 87, 86, 86)),
                    label: Text('Set', style: AppTextStyles.buttonMedium.copyWith(color: const Color.fromARGB(255, 87, 86, 86))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cfg.sets.length > 1 ? const Color.fromARGB(0, 41, 96, 60) : const Color.fromARGB(0, 209, 213, 219),
                      elevation: cfg.sets.length > 1 ? 2 : 0,
                      // Added side for border
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                        side: BorderSide(color: cfg.sets.length > 1 ? Colors.grey : Colors.grey.shade400, width: 1.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50.h,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => cfg.sets.add(_SetData())),
                    icon: Icon(Icons.add_rounded, size: 18),
                    label: Text('Set', style: AppTextStyles.buttonMedium),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                      elevation: 2,
                      shadowColor: AppColors.accent.withOpacity(0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  Widget _buildSetRow(_Config cfg, int cfgIdx, int setIdx, _SetData data) {
    final isAmrapOrFailure = cfg.mainType != 'Time' && (data.repsType == 'AMRAP' || data.repsType == 'FAILURE');
    // Create unique key for this set row to maintain TextField state
    final rowKey = ValueKey('set_${cfgIdx}_$setIdx');
    return Padding(
      key: rowKey,
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              height: 44,
              alignment: Alignment.centerLeft,
              child: Text(
                '${setIdx + 1}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: AppColors.primaryGray.withOpacity(0.2), width: 1),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Builder(
                      builder: (context) {
                        // Update controller text when data changes
                        data.updateControllerText(cfg.mainType);
                        return TextField(
                          key: ValueKey('reps_${cfgIdx}_${setIdx}_${data.repsType}_${cfg.mainType}_${cfg.mainType == 'Time' ? data.timeUnit : ''}'),
                          focusNode: data.repsTimeFocusNode,
                          controller: data.repsTimeController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: cfg.mainType == 'Time' || !isAmrapOrFailure ? [FilteringTextInputFormatter.digitsOnly] : null,
                          readOnly: isAmrapOrFailure,
                          showCursor: !isAmrapOrFailure,
                          enableInteractiveSelection: !isAmrapOrFailure,
                          canRequestFocus: !isAmrapOrFailure,
                          decoration: InputDecoration(
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.2), width: 1),
                            ),
                            border: InputBorder.none,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: BorderSide(color: AppColors.accent.withOpacity(0.3), width: 2),
                            ),
                            filled: true,
                            fillColor: AppColors.white,
                            hintText: cfg.mainType == 'Time' ? '30' : '10',
                            hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.black, fontSize: 14),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          style: AppTextStyles.bodyMedium.copyWith(color: isAmrapOrFailure ? AppColors.accent : AppColors.black, fontWeight: FontWeight.w600, fontSize: 15),
                          onTap: () {
                            if (isAmrapOrFailure) {
                              setState(() {
                                data.clearRepsType();
                                _focusedFieldType = null;
                                _focusedConfigIdx = null;
                                _focusedSetIdx = null;
                              });
                              return;
                            }
                            setState(() {
                              _focusedFieldType = cfg.mainType == 'Time' ? null : 'reps';
                              _focusedConfigIdx = cfgIdx;
                              _focusedSetIdx = setIdx;
                            });
                          },
                          onChanged: (v) {
                            if (cfg.mainType == 'Time') {
                              final n = int.tryParse(v) ?? 0;
                              final maxDisplay = data.timeUnit == 'M' ? _maxTimeMinutes : _maxTimeSeconds;
                              final clamped = n.clamp(0, maxDisplay);
                              setState(() {
                                data.time = data.timeUnit == 'M' ? clamped * 60 : clamped;
                              });
                            } else if (data.repsType == null || data.repsType == 'standard') {
                              final n = int.tryParse(v) ?? 0;
                              setState(() {
                                data.reps = n.clamp(0, _maxReps);
                                data.repsType = null;
                              });
                            }
                          },
                          onSubmitted: (_) {
                            setState(() {
                              _focusedFieldType = null;
                              _focusedConfigIdx = null;
                              _focusedSetIdx = null;
                            });
                            data.repsTimeFocusNode.unfocus();
                            FocusScope.of(context).unfocus();
                          },
                        );
                      },
                    ),
                  ),
                ),
                if (cfg.mainType == 'Time')
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(color: const Color.fromARGB(255, 149, 151, 155).withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (data.timeUnit != 'M') {
                                setState(() {
                                  // Switch to minutes mode (time stays in seconds, just display changes)
                                  data.timeUnit = 'M';
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: data.timeUnit == 'M'
                                    ? LinearGradient(colors: [AppColors.accent, AppColors.accent.withOpacity(0.85)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                    : null,
                                color: data.timeUnit == 'M' ? null : Colors.transparent,
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: data.timeUnit == 'M' ? [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
                              ),
                              child: Text(
                                'M',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: data.timeUnit == 'M' ? AppColors.onAccent : AppColors.onSurface.withOpacity(0.8),
                                  fontWeight: data.timeUnit == 'M' ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (data.timeUnit != 'S') {
                                setState(() {
                                  // Switch to seconds mode (time stays in seconds, just display changes)
                                  data.timeUnit = 'S';
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: data.timeUnit == 'S'
                                    ? LinearGradient(colors: [AppColors.accent, AppColors.accent.withOpacity(0.85)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                    : null,
                                color: data.timeUnit == 'S' ? null : Colors.transparent,
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: data.timeUnit == 'S' ? [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
                              ),
                              child: Text(
                                'S',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: data.timeUnit == 'S' ? AppColors.onAccent : AppColors.onSurface.withOpacity(0.8),
                                  fontWeight: data.timeUnit == 'S' ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: cfg.extraType == 'Distance'
                ? Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: AppColors.primaryGray, width: 1),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: TextField(
                            controller: TextEditingController(text: data.distance > 0 ? data.distance.toString() : ''),
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.done,
                            inputFormatters: [_decimalInputFormatter],
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.white,
                              border: InputBorder.none,
                              hintText: '0.0',
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                                borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.2), width: 1),
                              ),
                              hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark.withOpacity(0.4), fontSize: 14),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 15),
                            onChanged: (v) {
                              final parsed = double.tryParse(v) ?? 0;
                              setState(() => data.distance = parsed.clamp(0, _maxDistance));
                            },
                            onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: AppColors.primaryGray.withOpacity(0.2), width: 1),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: TextField(
                            key: ValueKey('weight_${cfgIdx}_${setIdx}'),
                            controller: TextEditingController(text: data.isBodyweight && data.weight == 0 ? 'BW' : (data.weight > 0 ? data.weight.toInt().toString() : ''))
                              ..selection = TextSelection.collapsed(
                                offset: data.isBodyweight && data.weight == 0
                                    ? 2 // 'BW'.length
                                    : (data.weight > 0 ? data.weight.toInt().toString().length : 0),
                              ),
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.done,
                            inputFormatters: [_decimalInputFormatter],
                            decoration: InputDecoration(
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                                borderSide: BorderSide(color: AppColors.accent.withOpacity(0.3), width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                                borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.2), width: 1),
                              ),
                              border: InputBorder.none,
                              filled: true,
                              fillColor: AppColors.white,
                              hintText: '0',
                              hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.black, fontSize: 14),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.black, fontWeight: FontWeight.w600, fontSize: 15),
                            onTap: () {
                              setState(() {
                                _focusedFieldType = 'weight';
                                _focusedConfigIdx = cfgIdx;
                                _focusedSetIdx = setIdx;
                              });
                            },
                            onChanged: (v) {
                              if (v.toUpperCase() == 'BW' || v.toLowerCase() == 'bw') {
                                data.weight = 0;
                                data.isBodyweight = true;
                              } else if (v.isEmpty) {
                                data.weight = 0;
                                data.isBodyweight = false;
                              } else {
                                final parsed = double.tryParse(v);
                                if (parsed != null) {
                                  data.weight = parsed.clamp(0, _maxWeight);
                                  data.isBodyweight = false;
                                }
                              }
                            },
                            onSubmitted: (_) {
                              FocusScope.of(context).unfocus();
                              setState(() {
                                _focusedFieldType = null;
                                _focusedConfigIdx = null;
                                _focusedSetIdx = null;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Config {
  String name, id;
  String? iconUrl;
  String mainType = 'Reps';
  String extraType = 'Weight';
  List<_SetData> sets;
  final TextEditingController nameController;

  _Config({required this.name, required this.id, this.iconUrl})
    : sets = [_SetData(), _SetData(), _SetData()],
      nameController = TextEditingController(text: name.isNotEmpty ? name : '');

  void dispose() {
    nameController.dispose();
  }
}

class _SetData {
  int reps = 0;
  int time = 0; // Stored in seconds
  double weight = 0;
  double distance = 0;
  String distanceUnit = 'miles';
  bool isBodyweight = false; // Track if BW was explicitly set
  String? repsType; // 'AMRAP', 'FAILURE', or null (standard)
  String timeUnit = 'S'; // 'M' for minutes, 'S' for seconds
  late final FocusNode repsTimeFocusNode;
  late final TextEditingController repsTimeController;

  _SetData() {
    repsTimeFocusNode = FocusNode();
    repsTimeController = TextEditingController();
  }

  void dispose() {
    repsTimeFocusNode.dispose();
    repsTimeController.dispose();
  }

  void updateControllerText(String mainType, {bool force = false}) {
    if (!force && repsTimeFocusNode.hasFocus) return;

    final text = mainType == 'Time'
        ? (time > 0 ? (timeUnit == 'M' ? (time / 60).round().toString() : time.toString()) : '')
        : (repsType == 'AMRAP'
              ? 'AMRAP'
              : repsType == 'FAILURE'
              ? 'FAILURE'
              : (reps > 0 ? reps.toString() : ''));
    if (repsTimeController.text != text) {
      repsTimeController.text = text;
    }
  }

  void clearRepsType() {
    repsType = null;
    reps = 0;
    repsTimeController.text = '';
  }
}
