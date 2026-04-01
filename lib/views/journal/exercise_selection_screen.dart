import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get_right/models/exercise_library_model.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

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

  // Get icon and color for exercise based on primary muscle group
  Map<String, dynamic> _getExerciseIconAndColor(ExerciseLibraryModel exercise) {
    final muscle = exercise.primaryMuscle.toLowerCase();

    if (muscle.contains('chest')) {
      return {'icon': Icons.fitness_center, 'color': AppColors.accent};
    } else if (muscle.contains('back')) {
      return {'icon': Icons.rowing, 'color': AppColors.completed};
    } else if (muscle.contains('quadriceps') || muscle.contains('leg')) {
      return {'icon': Icons.directions_run, 'color': AppColors.upcoming};
    } else if (muscle.contains('shoulder')) {
      return {'icon': Icons.sports_mma, 'color': AppColors.accent};
    } else if (muscle.contains('core')) {
      return {'icon': Icons.self_improvement, 'color': AppColors.primaryGray};
    } else if (muscle.contains('bicep')) {
      return {'icon': Icons.emoji_events, 'color': AppColors.upcoming};
    } else if (muscle.contains('tricep')) {
      return {'icon': Icons.local_fire_department, 'color': AppColors.error};
    } else if (muscle.contains('glute') || muscle.contains('hamstring')) {
      return {'icon': Icons.directions_walk, 'color': AppColors.upcoming};
    } else {
      // Default icon and color
      return {'icon': Icons.fitness_center, 'color': AppColors.accent};
    }
  }

  @override
  Widget build(BuildContext context) {
    final showButtons = (!_isSuperset && _selected.isNotEmpty) || (_isSuperset && _selected.length == 2);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
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
        title: Text('Select Exercise', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
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
                    final iconData = _getExerciseIconAndColor(ex);
                    final icon = iconData['icon'] as IconData;
                    final color = iconData['color'] as Color;

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 7.h),
                      elevation: sel ? 4 : 1,
                      // Add a 1 width border with proper color for clarity between cards. Using a light gray as border color.
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: const Color(0xFFE0E0E0), width: 1),
                      ),
                      // shape: RoundedRectangleBorder(
                      //   borderRadius: BorderRadius.circular(12),
                      //   side: BorderSide(color: sel ? AppColors.accent.withOpacity(0.2) : Colors.transparent, width: 2),
                      // ),
                      color: AppColors.surface,
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
                                  gradient: LinearGradient(colors: [color.withOpacity(0.25), color.withOpacity(0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: color.withOpacity(0.25), width: 1),
                                ),
                                child: Center(child: Icon(icon, color: color, size: 22)),
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
                                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(ex.primaryMuscle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
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
                color: AppColors.background,
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
