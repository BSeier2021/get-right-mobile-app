import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/models/exercise_library_category.dart';
import 'package:get_right/repo/marketplace_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

/// Library screen — exercise categories from `GET /user/exercise-categories`.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final MarketplaceRepository _repo = MarketplaceRepository();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  List<ExerciseLibraryCategory> _categories = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  static const int _limit = 20;

  static const Map<String, String> _assetFallbackByName = {
    'chest': 'assets/images/1. Chest 2.png',
    'back': 'assets/images/2. Back 1.png',
    'shoulders': 'assets/images/3. Shoulders 1.png',
    'quads': 'assets/images/4. Quads 1.png',
    'hamstrings': 'assets/images/5. Hamstring 1.png',
    'triceps': 'assets/images/6. Triceps 1.png',
    'biceps': 'assets/images/7. Biceps 1.png',
    'core': 'assets/images/8. core.png',
    'glutes': 'assets/images/9. Glutes 1.png',
    'calves': 'assets/images/10. Calves 1.png',
    'forearms': 'assets/images/11. Forearms 1.png',
  };

  List<ExerciseLibraryCategory> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;
    final q = _searchQuery.toLowerCase();
    return _categories.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCategories(reset: true);
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
      _loadCategories(reset: false);
    }
  }

  Future<void> _loadCategories({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _categories = [];
      });
    } else {
      if (!_hasMore || _loadingMore) return;
      setState(() => _loadingMore = true);
    }

    final pageToLoad = reset ? 1 : _page + 1;
    try {
      final result = await _repo.fetchExerciseCategoriesPage(page: pageToLoad, limit: _limit);
      if (!mounted) return;
      setState(() {
        if (reset) {
          _categories = result.categories;
        } else {
          final existing = _categories.map((c) => c.id).toSet();
          _categories.addAll(result.categories.where((c) => !existing.contains(c.id)));
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

  String? _assetFallbackFor(String name) {
    final key = name.toLowerCase().trim();
    return _assetFallbackByName[key];
  }

  @override
  Widget build(BuildContext context) {
    final groups = _filteredCategories;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
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
          'Library',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          // Padding(
          //   padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          //   child: TextField(
          //     controller: _searchController,
          //     onChanged: (v) => setState(() => _searchQuery = v),
          //     style: AppTextStyles.bodyMedium.copyWith(color: Colors.black),
          //     decoration: InputDecoration(
          //       filled: true,
          //       fillColor: AppColors.white,
          //       hintText: 'Search exercise',
          //       hintStyle: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF9E9E9E)),
          //       suffixIcon: _searchQuery.isNotEmpty
          //           ? IconButton(
          //               icon: const Icon(Icons.clear, color: Color(0xFF9E9E9E)),
          //               onPressed: () => setState(() {
          //                 _searchController.clear();
          //                 _searchQuery = '';
          //               }),
          //             )
          //           : const Icon(Icons.search, color: Color(0xFF9E9E9E)),
          //       border: OutlineInputBorder(
          //         borderRadius: BorderRadius.circular(50),
          //         borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          //       ),
          //       enabledBorder: OutlineInputBorder(
          //         borderRadius: BorderRadius.circular(50),
          //         borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          //       ),
          //       focusedBorder: OutlineInputBorder(
          //         borderRadius: BorderRadius.circular(50),
          //         borderSide: const BorderSide(color: AppColors.accent, width: 1),
          //       ),
          //       contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
          //     ),
          //   ),
          // ),
          Expanded(
            child: _loading && _categories.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _error != null && _categories.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Could not load categories', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
                          SizedBox(height: 8.h),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                          ),
                          SizedBox(height: 16.h),
                          TextButton(onPressed: () => _loadCategories(reset: true), child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                : groups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 80, color: AppColors.primaryGray.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('No muscle groups found', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.accent,
                    onRefresh: () => _loadCategories(reset: true),
                    child: GridView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 16.h, crossAxisSpacing: 8.w, childAspectRatio: 0.72),
                      itemCount: groups.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= groups.length) {
                          return const Center(
                            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                          );
                        }
                        return _buildMuscleGroupTile(groups[i]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMuscleGroupTile(ExerciseLibraryCategory category) {
    final iconUrl = ImageUrlSanitizer.asHttpUrlOrNull(category.iconUrl);
    final assetPath = _assetFallbackFor(category.name);

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.exerciseList, arguments: category.toRouteArgs()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68.w,
            height: 68.w,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8EFE6)),
            child: ClipOval(
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: iconUrl != null ? Image.network(iconUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _assetOrIcon(assetPath)) : _assetOrIcon(assetPath),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            category.name,
            style: AppTextStyles.bodySmall.copyWith(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 11.5.sp),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _assetOrIcon(String? assetPath) {
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.fitness_center, color: AppColors.accent, size: 28.w),
      );
    }
    return Icon(Icons.fitness_center, color: AppColors.accent, size: 28.w);
  }
}
