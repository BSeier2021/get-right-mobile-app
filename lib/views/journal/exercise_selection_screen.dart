import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/data/gr_exercise_catalog.dart';
import 'package:get_right/models/exercise_library_model.dart';
import 'package:get_right/models/journal_exercise_type.dart';
import 'package:get_right/models/workout_group_type.dart';
import 'package:get_right/repo/marketplace_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/utils/journal_flow.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/gr_catalog_image.dart';
import 'package:get_right/widgets/safe_network_image.dart';

/// Exercise list palette (creamy cards + cycling pastel icon circles).
const Color _kExerciseCardBg = Color(0xFFF8FAF0);
const Color _kExerciseNameColor = Color(0xFF1C1C1C);
const Color _kMuscleSubtitleColor = Color(0xFF4A4A4A);
const List<Color> _kIconPastels = [
  Color(0xFFE2F0D9), // pale green
  Color(0xFFFDE7D2), // pale peach
  Color(0xFFF9E2F8), // pale pink / lavender
  Color(0xFFD9EBF1), // pale blue / teal
];

class ExerciseSelectionScreen extends StatefulWidget {
  const ExerciseSelectionScreen({super.key});
  @override
  State<ExerciseSelectionScreen> createState() => _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState extends State<ExerciseSelectionScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MarketplaceRepository _repo = MarketplaceRepository();

  bool _isWarmup = false;
  bool _journalFlow = false;
  bool _pickAdditional = false;
  WorkoutGroupType? _workoutGroupType;
  int _requiredTotal = 1;
  List<ExerciseLibraryModel> _preselected = const [];
  String? _muscleGroupKey;
  String? _muscleGroupName;
  JournalExerciseType _exerciseType = JournalExerciseType.workout;
  bool _selectOnly = false;
  String? _workoutJournalId;
  List<String> _journalWorkoutIds = const [];
  List<String> _addedExerciseIds = const [];
  List<ExerciseLibraryModel> _allExercises = [];
  List<ExerciseLibraryModel> _filtered = [];
  final Set<ExerciseLibraryModel> _selected = {};
  bool _isSuperset = false;

  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  static const int _limit = 50;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      _isWarmup = args['isWarmup'] ?? false;
      _exerciseType = JournalExerciseType.fromArgs(args) ?? JournalExerciseType.fromIsWarmup(_isWarmup);
      _isWarmup = _exerciseType.isWarmup;
      _selectOnly = args['selectOnly'] ?? false;
      _workoutJournalId = args['workoutJournalId']?.toString() ?? args['workoutJournal']?.toString();
      final rawJournalWorkoutIds = args['journalWorkoutIds'];
      if (rawJournalWorkoutIds is List) {
        _journalWorkoutIds = rawJournalWorkoutIds.map((e) => e.toString()).toList();
      }
      final rawAddedExerciseIds = args['addedExerciseIds'];
      if (rawAddedExerciseIds is List) {
        _addedExerciseIds = rawAddedExerciseIds.map((e) => e.toString()).where((id) => id.isNotEmpty).toList();
      }
      _journalFlow = args['journalFlow'] == true;
      _pickAdditional = args['pickAdditional'] == true;
      _workoutGroupType = WorkoutGroupType.fromArgs(args['workoutGroupType']);
      _requiredTotal = (args['requiredTotal'] as num?)?.toInt() ?? _workoutGroupType?.minExercises ?? 1;
      final rawPreselected = args['preselected'];
      if (rawPreselected is List) {
        _preselected = rawPreselected.whereType<ExerciseLibraryModel>().toList();
        _selected.addAll(_preselected);
      }
      _isSuperset = _workoutGroupType == WorkoutGroupType.superset || (args['isSuperset'] ?? false);
      _muscleGroupKey = args['muscleGroupKey']?.toString();
      _muscleGroupName = args['muscleGroupName']?.toString();
    }
    _searchCtrl.addListener(_filter);
    _scrollController.addListener(_onScroll);
    _loadExercises(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_searchCtrl.text.isNotEmpty) return;
    if (!_hasMore || _loadingMore || _loading) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadExercises(reset: false);
    }
  }

  Future<void> _loadExercises({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _allExercises = [];
        _filtered = [];
      });
    } else {
      if (!_hasMore || _loadingMore) return;
      setState(() => _loadingMore = true);
    }

    final pageToLoad = reset ? 1 : _page + 1;
    try {
      if (_journalFlow) {
        await GrExerciseCatalog.instance.ensureLoaded();
        final entries = _muscleGroupKey != null && _muscleGroupKey!.isNotEmpty
            ? GrExerciseCatalog.instance.exercisesForMuscleGroup(_muscleGroupKey!)
            : GrExerciseCatalog.instance.allExercises;
        final exercises = entries.map((e) => e.toExerciseLibraryModel()).toList();
        if (!mounted) return;
        setState(() {
          _allExercises = exercises;
          _page = 1;
          _hasMore = false;
          _loading = false;
          _loadingMore = false;
          _error = null;
          _applyFilter();
        });
        return;
      }

      final result = await _repo.fetchUserExercisesPage(page: pageToLoad, limit: _limit);
      if (!mounted) return;
      setState(() {
        if (reset) {
          _allExercises = result.exercises;
        } else {
          final existing = _allExercises.map((e) => e.id).toSet();
          _allExercises.addAll(result.exercises.where((e) => !existing.contains(e.id)));
        }
        _page = result.page;
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
        _error = null;
        _applyFilter();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.toString();
      });
    }
  }

  void _filter() => _applyFilter();

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List<ExerciseLibraryModel>.from(_allExercises)
          : _allExercises.where((e) => e.name.toLowerCase().contains(q) || e.primaryMuscle.toLowerCase().contains(q)).toList();
    });
  }

  void _toggleSelect(ExerciseLibraryModel ex) {
    if (_selectOnly) {
      Get.back(result: {'exercise': ex});
      return;
    }

    if (_journalFlow && !_pickAdditional) {
      _openAddToWorkout(ex);
      return;
    }

    setState(() {
      if (_selected.contains(ex)) {
        if (!_preselected.contains(ex)) _selected.remove(ex);
      } else if (_pickAdditional && _workoutGroupType != null) {
        if (_workoutGroupType == WorkoutGroupType.circuit) {
          _selected.add(ex);
        } else if (_selected.length < _requiredTotal) {
          _selected.add(ex);
        }
      } else if (_isSuperset && _selected.length < 2) {
        _selected.add(ex);
      } else if (!_isSuperset) {
        _selected.clear();
        _selected.add(ex);
      }
    });
  }

  void _openAddToWorkout(ExerciseLibraryModel ex) {
    JournalFlowNavigator.pushChildAndBubble(
      AppRoutes.addToWorkout,
      arguments: {
        ...JournalFlowContext.fromArgs(Get.arguments as Map<String, dynamic>?).toRouteArgs(),
        'exercise': ex,
      },
    );
  }

  void _onContinue() {
    if (_selected.isEmpty) {
      Get.snackbar('Select Exercise', 'Please select at least one exercise', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }

    if (_pickAdditional && _workoutGroupType != null) {
      if (_selected.length < _requiredTotal) {
        final label = _workoutGroupType!.label;
        Get.snackbar(
          label,
          'Select at least ${_requiredTotal - _selected.length} more exercise(s)',
          backgroundColor: AppColors.error,
          colorText: AppColors.onError,
        );
        return;
      }
    } else if (_isSuperset && _selected.length != 2) {
      Get.snackbar('Superset', 'Select exactly 2 exercises for superset', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }

    if (_selectOnly) {
      Get.back(result: {'exercise': _selected.first});
      return;
    }

    final isGrouped = _pickAdditional && _workoutGroupType?.isGrouped == true || _isSuperset;
    final groupType = _workoutGroupType ?? (_isSuperset ? WorkoutGroupType.superset : WorkoutGroupType.single);
    final selectedList = _selected.toList();

    Get.toNamed(
      AppRoutes.exerciseConfiguration,
      arguments: {
        'isWarmup': _isWarmup,
        'exerciseType': _exerciseType,
        'isSuperset': isGrouped,
        'workoutGroupType': groupType.apiValue,
        'journalFlow': _journalFlow,
        'workoutJournalId': _workoutJournalId,
        'journalWorkoutIds': _journalWorkoutIds,
        'addedExerciseIds': _addedExerciseIds,
        'exercise': selectedList.length == 1 ? selectedList.first : null,
        'exercises': selectedList.length > 1 ? selectedList : null,
      },
    )?.then(JournalFlowNavigator.bubbleResult);
  }

  void _onManual() => Get.toNamed(AppRoutes.exerciseConfiguration, arguments: {
        'isWarmup': _isWarmup,
        'exerciseType': _exerciseType,
        'isManual': true,
        'workoutJournalId': _workoutJournalId,
        'journalWorkoutIds': _journalWorkoutIds,
      })?.then((r) {
    if (r != null) Get.back(result: r);
  });

  Color _iconBackgroundForIndex(int index) => _kIconPastels[index % _kIconPastels.length];

  Widget _buildExerciseIcon(ExerciseLibraryModel exercise, Color iconBg) {
    final iconUrl = exercise.iconUrl;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: iconBg,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: iconUrl != null && iconUrl.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(6),
              child: iconUrl.startsWith('assets/')
                  ? GrCatalogImage(
                      assetPath: iconUrl,
                      fit: BoxFit.contain,
                      borderRadius: 22,
                      scale: 1.08,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : SafeNetworkImage(
                      url: iconUrl,
                      fit: BoxFit.contain,
                      fallback: Center(child: Icon(Icons.fitness_center, color: _kExerciseNameColor.withValues(alpha: 0.55), size: 20)),
                    ),
            )
          : Center(child: Icon(Icons.fitness_center, color: _kExerciseNameColor.withValues(alpha: 0.55), size: 20)),
    );
  }

  Widget _buildExerciseList(bool showButtons) {
    if (_loading && _allExercises.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_error != null && _allExercises.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Could not load exercises', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
              SizedBox(height: 8.h),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
              ),
              SizedBox(height: 16.h),
              TextButton(onPressed: () => _loadExercises(reset: true), child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: AppColors.primaryGray.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No exercises found', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => _loadExercises(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: showButtons ? 140 : 0),
        itemCount: _filtered.length + (_loadingMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= _filtered.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            );
          }

          final ex = _filtered[i];
          final sel = _selected.contains(ex);
          final iconBg = _iconBackgroundForIndex(i);

          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 7.h),
            elevation: sel ? 4 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: sel ? AppColors.accent.withValues(alpha: 0.35) : const Color(0xFFE8EBDC), width: sel ? 2 : 1),
            ),
            color: _kExerciseCardBg,
            child: InkWell(
              onTap: () {
                _toggleSelect(ex);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildExerciseIcon(ex, iconBg),
                    SizedBox(width: 12.w),
                    if (sel)
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        child: const Icon(Icons.check, color: AppColors.onAccent, size: 16),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ex.name,
                            style: AppTextStyles.titleSmall.copyWith(color: _kExerciseNameColor, fontWeight: FontWeight.bold),
                          ),
                          if (ex.primaryMuscle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(ex.primaryMuscle, style: AppTextStyles.bodySmall.copyWith(color: _kMuscleSubtitleColor)),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: AppColors.primaryGrayDark),
                      onPressed: () => Get.toNamed(
                        AppRoutes.exerciseDetail,
                        arguments: {
                          '_id': ex.id,
                          'id': ex.id,
                          'name': ex.name,
                          'fromWorkout': true,
                          'addedExerciseIds': _addedExerciseIds,
                        },
                      ),
                    ),
                    const Icon(Icons.add_circle_outline, size: 25, color: AppColors.accent),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showButtons = _pickAdditional
        ? _selected.length >= _requiredTotal
        : (!_isSuperset && _selected.isNotEmpty) || (_isSuperset && _selected.length == 2);

    return Scaffold(
      backgroundColor: _kExerciseCardBg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: _kExerciseCardBg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            margin: EdgeInsets.only(left: 16.w, top: 16.h),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
        ),
        title: Text(
          _pickAdditional
              ? 'Select ${_requiredTotal - _preselected.length} more'
              : (_muscleGroupName ?? 'Select Exercise'),
          style: AppTextStyles.titleMedium.copyWith(color: _kExerciseNameColor),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // TextField(
              //   controller: _searchCtrl,
              //   decoration: InputDecoration(
              //     filled: true,
              //     fillColor: AppColors.white,
              //     hintText: 'Enter exercise name',
              //     hintStyle: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGrayDark.withOpacity(0.6)),
              //     border: OutlineInputBorder(
              //       borderRadius: BorderRadius.circular(50),
              //       borderSide: BorderSide(color: AppColors.primaryGrayDark.withOpacity(0.3)),
              //     ),
              //     enabledBorder: OutlineInputBorder(
              //       borderRadius: BorderRadius.circular(50),
              //       borderSide: BorderSide(color: AppColors.primaryGrayDark.withOpacity(0.3)),
              //     ),
              //     focusedBorder: OutlineInputBorder(
              //       borderRadius: BorderRadius.circular(50),
              //       borderSide: BorderSide(color: AppColors.accent.withOpacity(0.3), width: 2),
              //     ),
              //     contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              //     suffixIcon: IconButton(
              //       icon: SizedBox(width: 22, height: 22, child: SvgPicture.asset('assets/icons/search-normal.svg', width: 22, height: 22)),
              //       padding: EdgeInsets.zero,
              //       constraints: const BoxConstraints(),
              //       onPressed: () {},
              //     ),
              //   ),
              //   style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
              // ).paddingSymmetric(horizontal: 20, vertical: 20),
              Expanded(child: _buildExerciseList(showButtons)),
            ],
          ),
          // Fixed buttons at bottom - only show when appropriate selections are made
          if (showButtons)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: _kExerciseCardBg,
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom, left: 16, right: 16, top: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _pickAdditional && _workoutGroupType != null
                              ? 'Configure ${_workoutGroupType!.label}'
                              : (_isSuperset && _selected.length == 2 ? 'Configure Superset' : 'Configure ${_selected.first.name}'),
                          style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _onManual,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.onBackground,
                          side: const BorderSide(color: AppColors.primaryGray, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text("Couldn't find Exercise?", style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onBackground)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
