import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/data/gr_exercise_catalog.dart';
import 'package:get_right/models/exercise_library_category.dart';
import 'package:get_right/models/gr_exercise_entry.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/gr_catalog_image.dart';

const Color _kScreenBg = Color(0xFFFAFFEF);
const Color _kCardBg = Color(0xFFFFFFFF);
const Color _kCardBorder = Color(0xFFE2EBD8);
const Color _kMutedText = Color(0xFF6B7A6E);

/// Exercise library for the workout journal flow — categories from GR JSON.
class JournalExerciseLibraryScreen extends StatefulWidget {
  const JournalExerciseLibraryScreen({super.key});

  @override
  State<JournalExerciseLibraryScreen> createState() => _JournalExerciseLibraryScreenState();
}

class _JournalExerciseLibraryScreenState extends State<JournalExerciseLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<ExerciseLibraryCategory> _categories = [];
  List<GrExerciseEntry> _searchResults = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  Map<String, dynamic> get _journalArgs => (Get.arguments as Map<String, dynamic>?) ?? {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await GrExerciseCatalog.instance.ensureLoaded();
      if (!mounted) return;
      setState(() {
        _categories = GrExerciseCatalog.instance.getMuscleGroupCategories();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _searchQuery = query;
      _searchResults = query.isEmpty ? [] : GrExerciseCatalog.instance.searchExercises(query);
    });
  }

  void _openCategory(ExerciseLibraryCategory category) {
    Get.toNamed(
      AppRoutes.exerciseSelection,
      arguments: {
        ..._journalArgs,
        'journalFlow': true,
        'muscleGroupKey': category.id,
        'muscleGroupName': category.name,
      },
    )?.then((result) {
      if (result != null) Get.back(result: result);
    });
  }

  void _openExercise(GrExerciseEntry entry) {
    Get.toNamed(
      AppRoutes.addToWorkout,
      arguments: {
        ..._journalArgs,
        'exercise': entry.toExerciseLibraryModel(),
      },
    )?.then((result) {
      if (result != null) Get.back(result: result);
    });
  }

  void _onFilterTap() {
    Get.snackbar(
      'Filters',
      'Equipment, modality, and experience filters are coming soon.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.accent.withValues(alpha: 0.92),
      colorText: AppColors.onAccent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showingSearch = _searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: _kScreenBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: IconButton(
                onPressed: () => Get.back(),
                icon: Container(
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
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 4.h, 24.w, 0),
              child: Text(
                'Exercise Library',
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 16.h),
              child: Text(
                'Search or browse to find exercises and add them to your workout.',
                style: AppTextStyles.bodyMedium.copyWith(color: _kMutedText, height: 1.4),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.black),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _kCardBg,
                        hintText: 'Search exercises...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: _kMutedText),
                        prefixIcon: Icon(Icons.search, color: _kMutedText, size: 22.sp),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: _kMutedText, size: 20.sp),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _kCardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _kCardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Material(
                    color: _kCardBg,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _onFilterTap,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 52.w,
                        height: 52.w,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _kCardBorder),
                        ),
                        child: Icon(Icons.tune, color: AppColors.accent, size: 22.sp),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _error != null
                      ? _buildError()
                      : showingSearch
                          ? _buildSearchResults()
                          : _buildCategoryGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Could not load exercise library', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
            SizedBox(height: 8.h),
            Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
            SizedBox(height: 16.h),
            TextButton(onPressed: _loadCategories, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadCategories,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 12.h),
              child: Text(
                'Browse by Muscle Group',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _CategoryCard(
                  category: _categories[index],
                  onTap: () => _openCategory(_categories[index]),
                ),
                childCount: _categories.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No exercises found',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final entry = _searchResults[index];
        return Material(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _openExercise(entry),
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kCardBorder),
              ),
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52.w,
                      height: 52.w,
                      child: GrCatalogImage(
                        assetPath: entry.imageAssetPath,
                        borderRadius: 12,
                        scale: 1.08,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.name,
                            style: AppTextStyles.titleSmall.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            entry.primaryMuscleLabel,
                            style: AppTextStyles.bodySmall.copyWith(color: _kMutedText),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.accent, size: 22.sp),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final ExerciseLibraryCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imagePath = category.iconUrl;

    return Material(
      color: _kCardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kCardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(8.w, 10.h, 8.w, 10.h),
            child: Column(
              children: [
                Expanded(
                  child: imagePath != null
                      ? GrCatalogImage(
                          assetPath: imagePath,
                          borderRadius: 10,
                          scale: 1.08,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Icon(Icons.fitness_center, color: AppColors.accent, size: 32.sp),
                ),
                SizedBox(height: 8.h),
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _exerciseCountLabel(category.totalExercises),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: _kMutedText,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _exerciseCountLabel(int count) {
    if (count == 1) return '1 exercise';
    return '$count exercises';
  }
}
