import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/models/exercise_set_model.dart';
import 'package:get_right/models/exercise_library_model.dart';
import 'package:get_right/models/journal_exercise_type.dart';
import 'package:get_right/models/workout_group_type.dart';
import 'package:get_right/models/workout_exercise_model.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/utils/journal_flow.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/gr_catalog_image.dart';
import 'package:get_right/widgets/safe_network_image.dart';
import 'package:get_right/views/home/dashboard_screen.dart';

const Color _kScreenBg = Color(0xFFFAFFEF);
const Color _kCardBg = Color(0xFFFFFFFF);
const Color _kCardBorder = Color(0xFFE2EBD8);
const Color _kMutedText = Color(0xFF6B7A6E);
const Color _kInputBorder = Color(0xFFE5EAE0);

class _TrackingOption {
  const _TrackingOption({required this.key, required this.label, required this.icon, required this.isMain});
  final String key;
  final String label;
  final IconData icon;
  final bool isMain;
}

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
  WorkoutGroupType _workoutGroupType = WorkoutGroupType.single;
  bool _journalFlow = false;
  bool _isEditing = false;
  String? _editingWorkoutId;
  bool _hasAskedWarmupWorkout = false;
  bool _isSaving = false;
  String? _workoutJournalId;
  List<String> _journalWorkoutIds = const [];
  List<String> _addedExerciseIds = const [];
  DateTime? _journalDay;
  WorkoutExerciseModel? _supersetPartnerOf;
  final WorkoutRepository _workoutRepo = WorkoutRepository();
  final CalendarRepository _calendarRepo = CalendarRepository();
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
      _workoutGroupType = WorkoutGroupType.fromArgs(args['workoutGroupType']) ??
          (_isSuperset ? WorkoutGroupType.superset : WorkoutGroupType.single);
      _journalFlow = args['journalFlow'] == true;
      if (_workoutGroupType.isGrouped) _isSuperset = true;
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
      final rawJournalDay = args['journalDay'];
      if (rawJournalDay is DateTime) {
        _journalDay = DateTime(rawJournalDay.year, rawJournalDay.month, rawJournalDay.day);
      } else if (rawJournalDay is String && rawJournalDay.isNotEmpty) {
        final parsed = DateTime.tryParse(rawJournalDay);
        if (parsed != null) {
          _journalDay = DateTime(parsed.year, parsed.month, parsed.day);
        }
      }
      _journalDay ??= HomeNavigationController.journalDayOrNow();
      if (args['supersetPartnerOf'] is WorkoutExerciseModel) {
        _supersetPartnerOf = args['supersetPartnerOf'] as WorkoutExerciseModel;
        _isSuperset = false;
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
      } else if (_supersetPartnerOf != null) {
        _configs.add(_Config(name: '', id: 'manual_${DateTime.now().millisecondsSinceEpoch}'));
      } else if (_isSuperset && args['exercises'] != null) {
        for (var ex in args['exercises'] as List<ExerciseLibraryModel>) {
          _configs.add(_Config(name: ex.name, id: ex.id, iconUrl: ex.iconUrl, primaryMuscle: ex.primaryMuscle));
        }
        if (_configs.length > 1) _workoutGroupType = _workoutGroupType.isGrouped ? _workoutGroupType : WorkoutGroupType.superset;
        if (_configs.length >= 3 && _workoutGroupType != WorkoutGroupType.superset) {
          _workoutGroupType = WorkoutGroupType.circuit;
        }
      } else if (args['exercise'] != null) {
        final ex = args['exercise'] as ExerciseLibraryModel;
        _nameController.text = ex.name; // Pre-fill name for library exercises
        _configs.add(_Config(name: ex.name, id: ex.id, iconUrl: ex.iconUrl, primaryMuscle: ex.primaryMuscle));
      } else if (_isManual) {
        _configs.add(_Config(name: '', id: 'manual_${DateTime.now().millisecondsSinceEpoch}'));
      }
    }
    _journalDay ??= HomeNavigationController.journalDayOrNow();
    if (_configs.isEmpty) {
      _configs.add(_Config(name: '', id: 'manual_${DateTime.now().millisecondsSinceEpoch}'));
    }

    // Show popup asking warmup/workout if not already determined
    if (!_hasAskedWarmupWorkout && !_journalFlow) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWarmupWorkoutDialog());
    }
  }

  String _configTitle() {
    if (_supersetPartnerOf != null) return 'Add Superset Partner';
    return switch (_workoutGroupType) {
      WorkoutGroupType.superset => 'Configure Superset',
      WorkoutGroupType.circuit => 'Configure Circuit',
      WorkoutGroupType.single => 'Configure Exercise',
    };
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
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))],
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
                        shadowColor: AppColors.error.withValues(alpha: 0.4),
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
                        shadowColor: AppColors.accent.withValues(alpha: 0.4),
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

  void _showSaveMessage(String title, String message) {
    if (!mounted) return;
    final text = title.isEmpty ? message : '$title: $message';
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(text, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onError)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    debugPrint(text);
  }

  Future<void> _onSave() async {
    for (var i = 0; i < _configs.length; i++) {
      final err = _validateConfig(_configs[i], i + 1);
      if (err != null) {
        _showSaveMessage('Invalid values', err);
        return;
      }
    }

    final List<WorkoutExerciseModel> exercises = [];
    final now = DateTime.now();

    final createdApiIds = <String>[];
    String? savedSupersetIdentifier;
    if (_isEditing) {
      if (!WorkoutRepository.isValidMongoId(_editingWorkoutId)) {
        _showSaveMessage('Error', 'Workout id is missing or invalid');
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
        debugPrint('Exercise configuration update failed: $e');
        _showSaveMessage('Error', e.toString().replaceFirst('Exception: ', ''));
        return;
      }
      if (mounted) setState(() => _isSaving = false);
    } else if (!_isEditing) {
      setState(() => _isSaving = true);
      try {
        final journalDay = _journalDay ?? HomeNavigationController.journalDayOrNow();
        var journalId = WorkoutRepository.isValidMongoId(_workoutJournalId) ? _workoutJournalId!.trim() : null;
        journalId ??= await _workoutRepo.findWorkoutJournalIdForToday(date: journalDay);
        final sharedSupersetIdentifier = _isSuperset ? WorkoutRepository.generateSupersetIdentifier() : null;
        String? partnerSupersetIdentifier;

        if (_supersetPartnerOf != null) {
          final partner = _supersetPartnerOf!;
          if (!WorkoutRepository.isValidMongoId(partner.id)) {
            throw Exception('Existing exercise id is missing or invalid');
          }
          partnerSupersetIdentifier = partner.supersetIdentifier?.trim();
          if (partnerSupersetIdentifier == null || partnerSupersetIdentifier.isEmpty) {
            partnerSupersetIdentifier = WorkoutRepository.generateSupersetIdentifier();
            await _workoutRepo.updateWorkout(
              partner.id,
              WorkoutRepository.updateWorkoutBody(supersetIdentifier: partnerSupersetIdentifier),
            );
          }
        }

        savedSupersetIdentifier = partnerSupersetIdentifier ?? sharedSupersetIdentifier;

        for (var i = 0; i < _configs.length; i++) {
          final cfg = _configs[i];
          final name = cfg.name.isNotEmpty ? cfg.name : _nameController.text;
          final refId = cfg.id.trim();
          final supersetIdentifier = partnerSupersetIdentifier ?? sharedSupersetIdentifier;
          final body = WorkoutRepository.createWorkoutBody(
            type: _exerciseType.apiValue,
            name: name,
            exercise: _buildApiExerciseSets(cfg),
            refExercise: WorkoutRepository.refExerciseForApi(refId),
            supersetIdentifier: supersetIdentifier,
            workoutJournal: journalId,
            date: journalId == null ? WorkoutRepository.toJournalDate(journalDay) : null,
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
        if (WorkoutRepository.isValidMongoId(journalId)) {
          try {
            await _calendarRepo.attachWorkoutJournalToCalendar(date: journalDay, workoutJournalId: journalId!);
          } catch (_) {
            /* journal saved; calendar link is best-effort */
          }
        }
      } catch (e) {
        if (mounted) setState(() => _isSaving = false);
        debugPrint('Exercise configuration save failed: $e');
        _showSaveMessage('Error', e.toString().replaceFirst('Exception: ', ''));
        return;
      }
      if (mounted) setState(() => _isSaving = false);
    }

    final isSupersetExercise = _isSuperset || _supersetPartnerOf != null;
    for (var i = 0; i < _configs.length; i++) {
      final cfg = _configs[i];
      final name = cfg.name.isNotEmpty ? cfg.name : _nameController.text;
      final sets = <ExerciseSetModel>[];
      var setNum = 0;
      for (var setIdx = 0; setIdx < cfg.sets.length; setIdx++) {
        final s = cfg.sets[setIdx];
        if (!_setHasData(s, cfg)) continue;
        setNum++;
        sets.add(
          ExerciseSetModel(
            id: 'set_${setNum}_${now.millisecondsSinceEpoch}',
            setNumber: setNum,
            reps: cfg.mainType != 'Time' ? (s.repsType == 'AMRAP' || s.repsType == 'FAILURE' ? null : s.reps) : null,
            repsType: cfg.mainType != 'Time' ? (s.repsType ?? 'standard') : null,
            timeSeconds: cfg.mainType == 'Time' && s.time > 0 ? s.time : null,
            weight: cfg.extraType == 'Weight' ? s.weight : null,
            weightType: cfg.extraType == 'Weight' ? (s.isBodyweight ? 'BW' : (s.weight > 0 ? 'standard' : null)) : null,
            distance: cfg.extraType == 'Distance' ? s.distance : null,
            distanceUnit: cfg.extraType == 'Distance' ? s.distanceUnit : null,
          ),
        );
      }
      final apiId = _isEditing ? _editingWorkoutId : (i < createdApiIds.length ? createdApiIds[i] : null);
      final supersetParsed = WorkoutExerciseModel.parseSupersetIdentifier(savedSupersetIdentifier);
      exercises.add(
        WorkoutExerciseModel(
          id: apiId ?? 'ex_${now.millisecondsSinceEpoch}_$i',
          exerciseName: name,
          exerciseId: cfg.id,
          iconUrl: cfg.iconUrl,
          sets: sets,
          isSuperset: isSupersetExercise,
          supersetIdentifier: savedSupersetIdentifier,
          supersetId: supersetParsed?.groupId,
          supersetOrder: isSupersetExercise ? i : null,
          date: now,
          createdAt: now,
          exerciseType: _exerciseType,
        ),
      );
    }
    if (!mounted) return;
    _returnAfterSave({
      'exercises': exercises,
      'isWarmup': _isWarmup,
      'exerciseType': _exerciseType,
      if (_workoutJournalId != null) 'workoutJournalId': _workoutJournalId,
    });
  }

  void _returnAfterSave(Map<String, dynamic> result) {
    JournalFlowNavigator.completeAfterSave(
      result,
      journalFlow: _journalFlow,
      isEditing: _isEditing,
    );
  }

  List<Map<String, dynamic>> _buildApiExerciseSets(_Config cfg) {
    final models = <ExerciseSetModel>[];
    var setNum = 0;

    for (var i = 0; i < cfg.sets.length; i++) {
      final s = cfg.sets[i];
      if (!_setHasData(s, cfg)) continue;
      setNum++;

      models.add(
        ExerciseSetModel(
          id: 'set_$setNum',
          setNumber: setNum,
          reps: cfg.mainType != 'Time' && s.repsType != 'AMRAP' && s.repsType != 'FAILURE' ? s.reps : null,
          repsType: cfg.mainType != 'Time' ? s.repsType : null,
          timeSeconds: cfg.mainType == 'Time' && s.time > 0 ? s.time : null,
          weight: cfg.extraType == 'Weight' ? s.weight : null,
          weightType: cfg.extraType == 'Weight'
              ? (s.isBodyweight ? 'BW' : (s.weight > 0 ? 'standard' : null))
              : null,
          distance: cfg.extraType == 'Distance' && s.distance > 0 ? s.distance : null,
          distanceUnit: cfg.extraType == 'Distance' ? s.distanceUnit : null,
        ),
      );
    }

    return WorkoutRepository.exerciseSetsToApi(models);
  }

  bool _setHasData(_SetData setData, _Config cfg) {
    if (cfg.mainType == 'Time') return setData.time > 0;
    if (setData.repsType == 'FAILURE' || setData.repsType == 'AMRAP') return true;
    if (setData.reps > 0) return true;
    if (cfg.extraType == 'Weight' && (setData.weight > 0 || setData.isBodyweight)) return true;
    if (cfg.extraType == 'Distance' && setData.distance > 0) return true;
    return false;
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))],
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
                      shadowColor: AppColors.accent.withValues(alpha: 0.3),
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
                      shadowColor: AppColors.accent.withValues(alpha: 0.3),
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
                      shadowColor: AppColors.accent.withValues(alpha: 0.3),
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
                          shadowColor: AppColors.accent.withValues(alpha: 0.3),
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
                    shadowColor: AppColors.accent.withValues(alpha: 0.3),
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

  Widget _buildSaveButton({bool embedded = false}) {
    final button = SizedBox(
      width: double.infinity,
      height: 54.h,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSaving
            ? SizedBox(width: 22.w, height: 22.w, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, size: 20.sp, color: AppColors.onAccent),
                  SizedBox(width: 8.w),
                  Text(
                    _isSaving ? 'Saving...' : 'Save Exercise',
                    style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
      ),
    );

    if (embedded) return button;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 12.h),
        child: button,
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Get.back(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18.sp),
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          _configTitle(),
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        if (_workoutGroupType == WorkoutGroupType.single && _supersetPartnerOf == null) ...[
          SizedBox(height: 8.h),
          Text(
            'Customize how you want to track this exercise.',
            style: AppTextStyles.bodyMedium.copyWith(color: _kMutedText, height: 1.45),
          ),
        ],
        if (_supersetPartnerOf != null) ...[
          SizedBox(height: 8.h),
          Text(
            'Pair with ${_supersetPartnerOf!.exerciseName}',
            style: AppTextStyles.bodyMedium.copyWith(color: _kMutedText, height: 1.45),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = keyboardInset > 0;
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
        backgroundColor: _kScreenBg,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      SizedBox(height: 28.h),
                      if (_supersetPartnerOf == null && !_isEditing && !_journalFlow && _workoutGroupType == WorkoutGroupType.single)
                        Padding(
                          padding: EdgeInsets.only(bottom: 20.h),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _isSuperset,
                                onChanged: (value) {
                                  setState(() {
                                    _isSuperset = value ?? false;
                                    _workoutGroupType = _isSuperset ? WorkoutGroupType.superset : WorkoutGroupType.single;
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
                        ),
                      ..._configs.asMap().entries.map(
                            (e) => Padding(
                              padding: EdgeInsets.only(bottom: e.key < _configs.length - 1 ? 28.h : 0),
                              child: _buildCard(e.value, e.key),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              if (!keyboardOpen) _buildSaveButton(embedded: false),
              AnimatedPadding(
                duration: const Duration(milliseconds: 100),
                padding: EdgeInsets.only(bottom: keyboardOpen ? keyboardInset : 0),
                child: showKeyboardToolbar ? _buildKeyboardToolbar() : const SizedBox.shrink(),
              ),
            ],
          ),
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
        if (_journalDay != null) 'journalDay': _journalDay,
      },
    );
    if (result != null && result['exercise'] != null) {
      final exercise = result['exercise'] as ExerciseLibraryModel;
      setState(() {
        if (cfgIndex < _configs.length) {
          _configs[cfgIndex].name = exercise.name;
          _configs[cfgIndex].id = exercise.id;
          _configs[cfgIndex].iconUrl = exercise.iconUrl;
          _configs[cfgIndex].primaryMuscle = exercise.primaryMuscle;
          _configs[cfgIndex].nameController.text = exercise.name;
        }
      });
    }
  }

  Widget _buildExerciseInfoCard(_Config cfg, int idx) {
    final hasName = cfg.name.trim().isNotEmpty;
    final showEditableName = _isManual || !hasName || _isEditing;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80.w,
              height: 80.w,
              child: _buildExerciseImage(cfg),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: showEditableName
                ? TextField(
                    controller: cfg.nameController,
                    maxLength: _maxExerciseNameLength,
                    inputFormatters: [LengthLimitingTextInputFormatter(_maxExerciseNameLength)],
                    onChanged: (value) => setState(() => cfg.name = value),
                    decoration: InputDecoration(
                      counterText: '',
                      isDense: true,
                      filled: true,
                      fillColor: _kScreenBg,
                      hintText: 'Enter exercise name',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: _kMutedText),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kInputBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kInputBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.5))),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.search, color: AppColors.accent, size: 20.sp),
                        onPressed: () => _openExerciseSelection(idx),
                      ),
                    ),
                    style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w800),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cfg.name,
                        style: AppTextStyles.titleSmall.copyWith(color: AppColors.black, fontWeight: FontWeight.w800),
                      ),
                      if (cfg.primaryMuscle != null && cfg.primaryMuscle!.trim().isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4EC),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.accessibility_new, size: 14.sp, color: _kMutedText),
                              SizedBox(width: 4.w),
                              Text(
                                cfg.primaryMuscle!,
                                style: AppTextStyles.labelSmall.copyWith(color: _kMutedText, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseImage(_Config cfg) {
    final iconUrl = cfg.iconUrl;
    if (iconUrl != null && iconUrl.isNotEmpty) {
      if (iconUrl.startsWith('assets/')) {
        return GrCatalogImage(assetPath: iconUrl, borderRadius: 12, scale: 1.06, width: double.infinity, height: double.infinity);
      }
      return SafeNetworkImage(
        url: iconUrl,
        fit: BoxFit.cover,
        fallback: ColoredBox(
          color: const Color(0xFFE8F0E4),
          child: Icon(Icons.fitness_center, color: AppColors.accent, size: 28.sp),
        ),
      );
    }
    return ColoredBox(
      color: const Color(0xFFE8F0E4),
      child: Icon(Icons.fitness_center, color: AppColors.accent, size: 28.sp),
    );
  }

  Widget _buildTrackingModeBar(_Config cfg) {
    final options = [
      _TrackingOption(key: 'Reps', label: 'Reps', icon: Icons.looks_one_outlined, isMain: true),
      _TrackingOption(key: 'Time', label: 'Time', icon: Icons.timer_outlined, isMain: true),
      _TrackingOption(key: 'Weight', label: 'Weight', icon: Icons.fitness_center_outlined, isMain: false),
      _TrackingOption(key: 'Distance', label: 'Distance', icon: Icons.straighten_rounded, isMain: false),
    ];

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        children: options.map((option) {
          final selected = option.isMain ? cfg.mainType == option.key : cfg.extraType == option.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                if (option.isMain) {
                  _setMainTypeForConfig(cfg, option.key);
                } else {
                  cfg.extraType = option.key;
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(option.icon, size: 18.sp, color: selected ? AppColors.onAccent : Colors.black87),
                    SizedBox(height: 4.h),
                    Text(
                      option.label,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: selected ? AppColors.onAccent : Colors.black87,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCard(_Config cfg, int idx) {
    final mainLabel = cfg.mainType == 'Time' ? 'TIME (seconds)' : 'REPS (repetitions)';
    final extraLabel = cfg.extraType == 'Distance' ? 'DISTANCE (mi)' : 'WEIGHT (lbs)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_configs.length > 1) ...[
          Text(
            'Exercise ${idx + 1}',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 10.h),
        ],
        _buildExerciseInfoCard(cfg, idx),
        SizedBox(height: 20.h),
        _buildTrackingModeBar(cfg),
        SizedBox(height: 20.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kCardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 36.w,
                    child: Text(
                      'SET',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      mainLabel,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800, letterSpacing: 0.3, fontSize: 10.sp),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      extraLabel,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800, letterSpacing: 0.3, fontSize: 10.sp),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              ...cfg.sets.asMap().entries.map((e) => _buildSetRow(cfg, idx, e.key, e.value)),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: _buildSetActionButton(
                      label: 'Remove Set',
                      icon: Icons.remove,
                      enabled: cfg.sets.length > 1,
                      onTap: () => setState(() => cfg.sets.removeLast()),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildSetActionButton(
                      label: 'Add Set',
                      icon: Icons.add,
                      enabled: true,
                      onTap: () => setState(() => cfg.sets.add(_SetData())),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSetActionButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final color = enabled ? AppColors.accent : _kMutedText.withValues(alpha: 0.45);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: enabled ? _kInputBorder : _kInputBorder.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18.sp),
              SizedBox(width: 6.w),
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetRow(_Config cfg, int cfgIdx, int setIdx, _SetData data) {
    final isAmrapOrFailure = cfg.mainType != 'Time' && (data.repsType == 'AMRAP' || data.repsType == 'FAILURE');
    // Create unique key for this set row to maintain TextField state
    final rowKey = ValueKey('set_${cfgIdx}_$setIdx');
    return Padding(
      key: rowKey,
      padding: EdgeInsets.only(bottom: 14.h),
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
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kInputBorder, width: 1),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
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
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.2), width: 1),
                            ),
                            border: InputBorder.none,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.3), width: 2),
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
                      decoration: BoxDecoration(color: const Color.fromARGB(255, 149, 151, 155).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
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
                                    ? LinearGradient(colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.85)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                    : null,
                                color: data.timeUnit == 'M' ? null : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: data.timeUnit == 'M' ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
                              ),
                              child: Text(
                                'M',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: data.timeUnit == 'M' ? AppColors.onAccent : AppColors.onSurface.withValues(alpha: 0.8),
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
                                    ? LinearGradient(colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.85)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                    : null,
                                color: data.timeUnit == 'S' ? null : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: data.timeUnit == 'S' ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
                              ),
                              child: Text(
                                'S',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: data.timeUnit == 'S' ? AppColors.onAccent : AppColors.onSurface.withValues(alpha: 0.8),
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
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryGray, width: 1),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
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
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.2), width: 1),
                              ),
                              hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark.withValues(alpha: 0.4), fontSize: 14),
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
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2), width: 1),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
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
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.3), width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.2), width: 1),
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
  String? primaryMuscle;
  String mainType = 'Reps';
  String extraType = 'Weight';
  List<_SetData> sets;
  final TextEditingController nameController;

  _Config({required this.name, required this.id, this.iconUrl, this.primaryMuscle})
    : sets = [_SetData()..reps = 10, _SetData()..reps = 10, _SetData()..reps = 10],
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
