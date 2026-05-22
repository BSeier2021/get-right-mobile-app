import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/models/exercise_library_item.dart';
import 'package:get_right/repo/marketplace_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Library list — screen + card chrome (matches exercise detail cards in design).
const Color _kLibraryListBg = Color(0xFFF8FAF0);
const Color _kLibraryCardBorder = Color(0xFFE8EBDC);
const Color _kLibraryTagBg = Color(0xFFE8F4E0);

/// Exercise list screen — exercises for a category from `GET /user/exercises/category/:id`.
class ExerciseListScreen extends StatefulWidget {
  const ExerciseListScreen({super.key});

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  final MarketplaceRepository _repo = MarketplaceRepository();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  late Map<String, dynamic> muscleGroup;
  late String _categoryId;

  List<ExerciseLibraryItem> _exercises = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  static const int _limit = 20;

  List<ExerciseLibraryItem> get _filteredExercises {
    if (_searchQuery.isEmpty) return _exercises;
    final q = _searchQuery.toLowerCase();
    return _exercises.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    muscleGroup = Get.arguments as Map<String, dynamic>;
    _categoryId = muscleGroup['_id']?.toString() ?? muscleGroup['id']?.toString() ?? '';
    _scrollController.addListener(_onScroll);
    _loadExercises(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_searchQuery.isNotEmpty) return;
    if (!_hasMore || _loadingMore || _loading) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadExercises(reset: false);
    }
  }

  Future<void> _loadExercises({required bool reset}) async {
    if (_categoryId.isEmpty) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Invalid category';
      });
      return;
    }

    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _exercises = [];
      });
    } else {
      if (!_hasMore || _loadingMore) return;
      setState(() => _loadingMore = true);
    }

    final pageToLoad = reset ? 1 : _page + 1;
    try {
      final result = await _repo.fetchExercisesByCategoryPage(categoryId: _categoryId, page: pageToLoad, limit: _limit);
      if (!mounted) return;
      setState(() {
        if (reset) {
          _exercises = result.exercises;
        } else {
          final existing = _exercises.map((e) => e.id).toSet();
          _exercises.addAll(result.exercises.where((e) => !existing.contains(e.id)));
        }
        _page = result.page;
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
        _error = null;
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

  @override
  Widget build(BuildContext context) {
    final exercises = _filteredExercises;
    final muscleGroupName = muscleGroup['name']?.toString() ?? 'Exercises';

    return Scaffold(
      backgroundColor: _kLibraryListBg,
      appBar: AppBar(
        backgroundColor: _kLibraryListBg,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ).paddingAll(8),
        ),
        title: Text(
          muscleGroupName,
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.w900),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.only(top: 16.h),
        child: _buildBody(exercises, muscleGroupName),
      ),
    );
  }

  Widget _buildBody(List<ExerciseLibraryItem> exercises, String muscleGroupName) {
    if (_loading && _exercises.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_error != null && _exercises.isEmpty) {
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
    if (exercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: AppColors.primaryGray.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No exercises found', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => _loadExercises(reset: true),
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14.h, crossAxisSpacing: 12.w, childAspectRatio: 0.72),
        itemCount: exercises.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= exercises.length) {
            return const Center(
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
            );
          }
          return _buildExerciseCard(exercises[i], muscleGroupName);
        },
      ),
    );
  }

  Widget _buildExerciseCard(ExerciseLibraryItem exercise, String muscleGroupName) {
    final imageUrl = exercise.displayImageUrl ?? exercise.videoThumbnailUrl ?? exercise.iconUrl ?? '';
    const double cardRadius = 18;

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.exerciseDetail, arguments: exercise.toRouteArgs(muscleGroupName: muscleGroupName)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: _kLibraryCardBorder, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(cardRadius), bottom: Radius.circular(14)),
                    child: imageUrl.isEmpty
                        ? ColoredBox(
                            color: AppColors.accent.withOpacity(0.08),
                            child: const Center(child: Icon(Icons.fitness_center, color: AppColors.accent, size: 36)),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return ColoredBox(
                                color: AppColors.accent.withOpacity(0.06),
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                              );
                            },
                            errorBuilder: (c, e, s) => ColoredBox(
                              color: AppColors.accent.withOpacity(0.1),
                              child: const Center(child: Icon(Icons.fitness_center, color: AppColors.accent, size: 32)),
                            ),
                          ),
                  ),
                  if (exercise.hasVideo) Center(child: _libraryPlayButton()),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    exercise.name,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800, color: AppColors.black, fontSize: 13.5.sp, height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (exercise.tagNames.isNotEmpty) ...[SizedBox(height: 10.h), ...exercise.tagNames.take(2).map(_libraryTagPill)],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _libraryPlayButton() {
    final size = 44.w;
    return Image.asset('assets/images/playbutton.png', width: size, height: size, fit: BoxFit.contain);
  }

  Widget _libraryTagPill(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
          decoration: BoxDecoration(color: _kLibraryTagBg, borderRadius: BorderRadius.circular(50)),
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent, fontSize: 11.sp, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
