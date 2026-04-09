import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get_right/models/exercise_library_model.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

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
  bool _isWarmup = false;
  bool _selectOnly = false;
  List<ExerciseLibraryModel> _filtered = ExerciseLibraryData.exercises;
  final Set<ExerciseLibraryModel> _selected = {};
  bool _isSuperset = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      _isWarmup = args['isWarmup'] ?? false;
      _selectOnly = args['selectOnly'] ?? false;
    }
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() => _filtered = ExerciseLibraryData.exercises.where((e) => e.name.toLowerCase().contains(q) || e.primaryMuscle.toLowerCase().contains(q)).toList());
  }

  void _toggleSelect(ExerciseLibraryModel ex) {
    // In selectOnly mode, immediately return the selected exercise
    if (_selectOnly) {
      Get.back(result: {'exercise': ex});
      return;
    }
    setState(() {
      if (_selected.contains(ex))
        _selected.remove(ex);
      else if (_isSuperset && _selected.length < 2)
        _selected.add(ex);
      else if (!_isSuperset) {
        _selected.clear();
        _selected.add(ex);
      }
    });
  }

  void _onContinue() {
    if (_selected.isEmpty) {
      Get.snackbar('Select Exercise', 'Please select at least one exercise', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }
    if (_isSuperset && _selected.length != 2) {
      Get.snackbar('Superset', 'Select exactly 2 exercises for superset', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }
    // If selectOnly mode, return the selected exercise directly
    if (_selectOnly) {
      Get.back(result: {'exercise': _selected.first});
      return;
    }
    Get.toNamed(
      AppRoutes.exerciseConfiguration,
      arguments: {
        'isWarmup': _isWarmup,
        'isSuperset': _isSuperset,
        'exercise': _selected.length == 1 ? _selected.first : null,
        'exercises': _isSuperset ? _selected.toList() : null,
      },
    )?.then((r) {
      if (r != null) Get.back(result: r);
    });
  }

  void _onManual() => Get.toNamed(AppRoutes.exerciseConfiguration, arguments: {'isWarmup': _isWarmup, 'isManual': true})?.then((r) {
    if (r != null) Get.back(result: r);
  });

  // Resolve exercise-specific image asset by exercise name
  String _getExerciseAsset(ExerciseLibraryModel exercise) {
    final name = exercise.name.toLowerCase().replaceAll('-', ' ').trim();
    // Map normalized names to assets provided by user
    const Map<String, String> map = {
      'bench press': 'assets/images/1. bench press.png',
      'squat': 'assets/images/2. squat.png',
      'deadlift': 'assets/images/3. deadlift.png',
      'overhead press': 'assets/images/4. overhead press.png',
      'pull up': 'assets/images/5. pull up.png',
      'plank': 'assets/images/6. plank.png',
      'front squat': 'assets/images/7. front squat.png',
      'lat pulldown': 'assets/images/8. lat pulldown.png',
      'dumbbell curl': 'assets/images/9.  dumbell curl.png', // handle common spelling
      'dumbell curl': 'assets/images/9.  dumbell curl.png',
      'triceps pushdown': 'assets/images/10. tricep pushdown.png',
      'tricep pushdown': 'assets/images/10. tricep pushdown.png',
      'lunges': 'assets/images/11. lunges.png',
      'leg press': 'assets/images/12. Leg press.png',
    };

    // Try exact match
    if (map.containsKey(name)) return map[name]!;

    // Try relaxed contains matching for safety
    for (final entry in map.entries) {
      if (name.contains(entry.key)) return entry.value;
    }

    // Fallback to a neutral placeholder (uses accent icon background with no image)
    return '';
  }

  Color _iconBackgroundForIndex(int index) => _kIconPastels[index % _kIconPastels.length];

  @override
  Widget build(BuildContext context) {
    final showButtons = (!_isSuperset && _selected.isNotEmpty) || (_isSuperset && _selected.length == 2);

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
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
        ),
        title: Text('Select Exercise', style: AppTextStyles.titleMedium.copyWith(color: _kExerciseNameColor)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              TextField(
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
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {},
                  ),
                ),
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
              ).paddingSymmetric(horizontal: 20, vertical: 20),

              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(bottom: showButtons ? 140 : 0),
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) {
                    final ex = _filtered[i];
                    final sel = _selected.contains(ex);
                    final asset = _getExerciseAsset(ex);
                    final iconBg = _iconBackgroundForIndex(i);

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 7.h),
                      elevation: sel ? 4 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: sel ? AppColors.accent.withOpacity(0.35) : const Color(0xFFE8EBDC), width: sel ? 2 : 1),
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
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: iconBg,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: asset.isNotEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Image.asset(asset, fit: BoxFit.contain),
                                      )
                                    : Center(child: Icon(Icons.fitness_center, color: _kExerciseNameColor.withOpacity(0.55), size: 20)),
                              ),
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
                                    const SizedBox(height: 4),
                                    Text(ex.primaryMuscle, style: AppTextStyles.bodySmall.copyWith(color: _kMuscleSubtitleColor)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline, color: AppColors.primaryGrayDark),
                                onPressed: () => Get.toNamed(AppRoutes.exerciseLibraryDetail, arguments: {'exercise': ex}),
                              ),
                              const Icon(Icons.add_circle_outline, size: 25, color: AppColors.accent),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
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
                          _isSuperset && _selected.length == 2 ? 'Configure Superset' : 'Configure ${_selected.first.name}',
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
