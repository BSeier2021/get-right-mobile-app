import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/models/exercise_category_option.dart';
import 'package:get_right/repo/marketplace_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/bundle_card_mapper.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:get_right/views/home/dashboard_screen.dart';
import 'package:get_right/widgets/safe_circle_network_avatar.dart';

/// Marketplace screen - browse trainer programs
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final Set<String> _selectedCategoryIds = {};
  final Set<String> _selectedDifficulties = {};
  String _selectedDuration = 'All';
  String _sortBy = '';
  bool _showCertifiedOnly = false;
  List<ExerciseCategoryOption> _exerciseCategories = [];

  final MarketplaceRepository _marketplaceRepo = MarketplaceRepository();
  List<Map<String, dynamic>> _featuredSectionPrograms = [];
  List<Map<String, dynamic>> _newReleasesSectionPrograms = [];
  bool _marketplaceSectionsLoading = false;
  String? _marketplaceSectionsError;

  /// Home uses IndexedStack — avoid `/customer/program` + `/customer/bundle` until Market tab (index 0) is opened.
  Worker? _homeTabWorker;
  bool _marketTabLazyBootstrapped = false;

  List<Map<String, dynamic>> _apiBundles = [];
  bool _bundlesLoading = false;
  String? _bundlesError;

  late final ScrollController _marketplaceScrollController;

  @override
  void initState() {
    super.initState();
    _marketplaceScrollController = ScrollController()..addListener(_onMarketplaceScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Get.isRegistered<HomeNavigationController>()) {
        final nav = Get.find<HomeNavigationController>();
        _homeTabWorker = ever<int>(nav.currentIndexRx, (idx) {
          if (!mounted) return;
          if (idx == 0) _bootstrapMarketTabIfNeeded();
        });
        if (nav.currentIndex == 0) {
          _bootstrapMarketTabIfNeeded();
        }
      } else {
        _bootstrapMarketTabIfNeeded();
      }
    });
  }

  void _bootstrapMarketTabIfNeeded() {
    if (_marketTabLazyBootstrapped) return;
    _marketTabLazyBootstrapped = true;
    Future(() async {
      if (!mounted) return;
      await _loadExerciseCategories();
      if (!mounted) return;
      await Future.wait([_loadMarketplaceSections(), _loadBrowsePrograms(reset: true)]);
      if (mounted) await _loadMarketplaceBundles();
    });
  }

  Future<void> _loadExerciseCategories() async {
    try {
      final list = await _marketplaceRepo.fetchExerciseCategories();
      if (!mounted) return;
      setState(() => _exerciseCategories = list);
    } catch (_) {
      if (!mounted) return;
    }
  }

  String? get _apiSort {
    switch (_sortBy) {
      case 'Newest':
        return 'Newest';
      case 'Price Low-High':
        return 'PriceAsc';
      case 'Price High-Low':
        return 'PriceDesc';
      default:
        return null;
    }
  }

  /// When false, browse uses plain `GET /customer/program?page&limit` (no type/sort) for full catalog.
  bool get _hasServerSideBrowseFilters =>
      _selectedCategoryIds.isNotEmpty || _selectedDifficulties.isNotEmpty || _selectedDuration != 'All' || _showCertifiedOnly || _apiSort != null;

  (int?, int?)? _durationWeeksRange() {
    switch (_selectedDuration) {
      case '0-4 weeks':
        return (0, 4);
      case '5-8 weeks':
        return (5, 8);
      case '9-12 weeks':
        return (9, 12);
      case '13+ weeks':
        return (13, 520);
      default:
        return null;
    }
  }

  CustomerProgramsQuery _buildProgramsQuery({required int page, required int perPage}) {
    final range = _durationWeeksRange();
    final searchTitle = _programSearchTitle.trim();
    return CustomerProgramsQuery(
      page: page,
      limit: perPage,
      type: _hasServerSideBrowseFilters ? MarketplaceSection.all : null,
      sort: _apiSort,
      categories: _selectedCategoryIds.toList(),
      difficulties: _selectedDifficulties.toList(),
      durationMin: range?.$1,
      durationMax: range?.$2,
      certifiedOnly: _showCertifiedOnly,
      title: searchTitle.isEmpty ? null : searchTitle,
    );
  }

  bool get _hasActiveFilters =>
      _programSearchTitle.trim().isNotEmpty ||
      _selectedCategoryIds.isNotEmpty ||
      _selectedDifficulties.isNotEmpty ||
      _selectedDuration != 'All' ||
      _sortBy.isNotEmpty ||
      _showCertifiedOnly;

  void _openProgramSearch() {
    final controller = TextEditingController(text: _programSearchTitle);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.35), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Search Programs',
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => _applyProgramSearch(sheetContext, value),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search by program title...',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryGray),
                    filled: true,
                    fillColor: AppColors.backgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    if (_programSearchTitle.isNotEmpty)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _applyProgramSearch(sheetContext, ''),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.onBackground,
                            side: BorderSide(color: AppColors.primaryGray.withOpacity(0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                          child: const Text('Clear'),
                        ),
                      ),
                    if (_programSearchTitle.isNotEmpty) SizedBox(width: 12.w),
                    Expanded(
                      flex: _programSearchTitle.isNotEmpty ? 1 : 1,
                      child: ElevatedButton(
                        onPressed: () => _applyProgramSearch(sheetContext, controller.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        child: Text(
                          'Search',
                          style: AppTextStyles.buttonMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _applyProgramSearch(BuildContext sheetContext, String query) {
    Navigator.pop(sheetContext);
    final next = query.trim();
    if (next == _programSearchTitle) return;
    setState(() => _programSearchTitle = next);
    _loadBrowsePrograms(reset: true);
  }

  String _categoryLabel(String id) {
    for (final c in _exerciseCategories) {
      if (c.id == id) return c.name;
    }
    return id;
  }

  /// Pull-to-refresh: reload featured / new releases, browse programs, then bundles (uses updated catalog).
  Future<void> _refreshMarketplace() async {
    await Future.wait([_loadMarketplaceSections(), _loadBrowsePrograms(reset: true)]);
    if (!mounted) return;
    await _loadMarketplaceBundles();
  }

  @override
  void dispose() {
    _homeTabWorker?.dispose();
    _marketplaceScrollController.removeListener(_onMarketplaceScroll);
    _marketplaceScrollController.dispose();
    super.dispose();
  }

  void _onMarketplaceScroll() {
    if (!_browseProgramsHasMore || _browseProgramsLoadingMore || _browseProgramsLoading) return;
    final c = _marketplaceScrollController;
    if (!c.hasClients) return;
    if (c.position.pixels >= c.position.maxScrollExtent - 480) {
      _loadMoreBrowsePrograms();
    }
  }

  Future<void> _loadBrowsePrograms({bool reset = false}) async {
    if (reset) {
      setState(() {
        _browsePrograms.clear();
        _browseNextPage = 1;
        _browseProgramsHasMore = true;
        _browseProgramsLoading = true;
        _browseProgramsError = null;
        _browseProgramsTotal = 0;
      });
    }
    final page = reset ? 1 : _browseNextPage;
    try {
      final result = await _marketplaceRepo.fetchBrowsePrograms(
        page: page,
        perPage: _browseProgramsPerPage,
        query: _buildProgramsQuery(page: page, perPage: _browseProgramsPerPage),
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _browsePrograms
            ..clear()
            ..addAll(result.programs);
        } else {
          _browsePrograms.addAll(result.programs);
        }
        _browseProgramsTotal = result.total;
        _browseProgramsHasMore = result.hasMore;
        _browseNextPage = result.page + 1;
        _browseProgramsLoading = false;
        _browseProgramsLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _browseProgramsLoading = false;
        _browseProgramsLoadingMore = false;
        _browseProgramsError = e.toString();
      });
    }
  }

  Future<void> _loadMoreBrowsePrograms() async {
    if (!_browseProgramsHasMore || _browseProgramsLoadingMore || _browseProgramsLoading) return;
    setState(() => _browseProgramsLoadingMore = true);
    final page = _browseNextPage;
    try {
      final result = await _marketplaceRepo.fetchBrowsePrograms(
        page: page,
        perPage: _browseProgramsPerPage,
        query: _buildProgramsQuery(page: page, perPage: _browseProgramsPerPage),
      );
      if (!mounted) return;
      setState(() {
        _browsePrograms.addAll(result.programs);
        _browseProgramsTotal = result.total;
        _browseProgramsHasMore = result.hasMore;
        _browseNextPage = result.page + 1;
        _browseProgramsLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _browseProgramsLoadingMore = false;
        _browseProgramsError = e.toString();
      });
    }
  }

  Future<void> _loadMarketplaceSections() async {
    setState(() {
      _marketplaceSectionsLoading = true;
      _marketplaceSectionsError = null;
    });
    try {
      final results = await Future.wait([
        _marketplaceRepo.fetchSectionPrograms(type: MarketplaceSection.featured, page: 1, perPage: 10),
        _marketplaceRepo.fetchSectionPrograms(type: MarketplaceSection.newReleases, page: 1, perPage: 10),
      ]);
      if (!mounted) return;
      setState(() {
        _featuredSectionPrograms = results[0];
        _newReleasesSectionPrograms = results[1];
        _marketplaceSectionsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _marketplaceSectionsLoading = false;
        _marketplaceSectionsError = e.toString();
      });
    }
  }

  Future<void> _loadMarketplaceBundles() async {
    setState(() {
      _bundlesLoading = true;
      _bundlesError = null;
    });
    try {
      final catalog = List<Map<String, dynamic>>.from(_browsePrograms);
      final page = await _marketplaceRepo.fetchBrowseBundles(page: 1, perPage: 10, programCatalog: catalog);
      if (!mounted) return;
      setState(() {
        _apiBundles = page.bundles;
        _bundlesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bundlesLoading = false;
        _bundlesError = e.toString();
      });
    }
  }

  // Motivational quotes for success modal
  final List<String> _motivationalQuotes = [
    "The only bad workout is the one that didn't happen.",
    "Success is the sum of small efforts repeated day in and day out.",
    "Your body can stand almost anything. It's your mind you have to convince.",
    "The difference between try and triumph is a little umph.",
    "Don't stop when you're tired. Stop when you're done.",
    "Make yourself proud!",
    "The pain you feel today will be the strength you feel tomorrow.",
    "Push yourself because no one else is going to do it for you.",
  ];

  List<Map<String, dynamic>> _browsePrograms = [];
  int _browseNextPage = 1;
  bool _browseProgramsHasMore = true;
  bool _browseProgramsLoading = false;
  bool _browseProgramsLoadingMore = false;
  String? _browseProgramsError;
  int _browseProgramsTotal = 0;
  static const int _browseProgramsPerPage = 10;
  String _programSearchTitle = '';

  // Mock weekly free workouts
  final List<Map<String, dynamic>> _weeklyFreeWorkouts = [
    {
      'id': 'weekly_1',
      'programId': 'program_1',
      'title': 'Getright Free Workout',
      'description': 'Master the basics of strength training this week for free!',
      'startDate': DateTime.now().subtract(const Duration(days: 1)),
      'endDate': DateTime.now().add(const Duration(days: 5)),
      'imageUrl': 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=800&q=80',
    },
    {
      'id': 'weekly_2',
      'programId': 'program_2',
      'title': 'Next Week: Cardio Blast',
      'description': 'Get ready for an intense cardio week starting next Monday.',
      'startDate': DateTime.now().add(const Duration(days: 7)),
      'endDate': DateTime.now().add(const Duration(days: 14)),
      'imageUrl': 'https://images.unsplash.com/photo-1574673139641-77ad18305c79?auto=format&fit=crop&w=800&q=80',
    },
  ];

  Map<String, dynamic>? get _activeWeeklyWorkout {
    final now = DateTime.now();
    try {
      return _weeklyFreeWorkouts.firstWhere((w) {
        final start = w['startDate'] as DateTime;
        final end = w['endDate'] as DateTime;
        return now.isAfter(start) && now.isBefore(end);
      });
    } catch (e) {
      return null;
    }
  }

  List<Map<String, dynamic>> get _filteredPrograms => _browsePrograms;

  List<Map<String, dynamic>> get _filteredBundles {
    return _apiBundles.where((bundle) {
      if (_showCertifiedOnly) {
        if (bundle['isCertified'] == true) return true;
        final programs = bundle['programs'] as List<Map<String, dynamic>>;
        if (programs.isEmpty) return false;
        return programs.every((p) => p['certified'] == true);
      }
      return true;
    }).toList();
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(top: 50, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(50)),
                          child: const Icon(Icons.filter_list, color: AppColors.accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text('Filter Programs', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.primaryGray),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Sort By Section
                _buildFilterSectionHeader('Sort By', Icons.sort_outlined),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8FFE9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Featured', 'Newest', 'Price Low-High', 'Price High-Low'].map((sort) {
                      final isSelected = _sortBy == sort;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            _sortBy = isSelected ? '' : sort;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.accent : AppColors.surface,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: isSelected ? AppColors.accent : AppColors.primaryGray, width: isSelected ? 2 : 1),
                          ),
                          child: Text(
                            sort,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: isSelected ? AppColors.onAccent : AppColors.onBackground,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Category Section
                _buildFilterSectionHeader('Category', Icons.category_outlined),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_exerciseCategories.isEmpty)
                        Text('Loading categories…', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray))
                      else
                        ..._exerciseCategories.map((category) {
                          final isSelected = _selectedCategoryIds.contains(category.id);
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  _selectedCategoryIds.remove(category.id);
                                } else {
                                  _selectedCategoryIds.add(category.id);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accent : AppColors.surface,
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(color: isSelected ? AppColors.accent : AppColors.primaryGray, width: isSelected ? 2 : 1),
                              ),
                              child: Text(
                                category.name,
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: isSelected ? AppColors.onAccent : AppColors.onBackground,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Difficulty Section
                _buildFilterSectionHeader('Difficulty', Icons.bar_chart_outlined),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Beginner', 'Intermediate', 'Advanced', 'Professional'].map((difficulty) {
                      final isSelected = _selectedDifficulties.contains(difficulty);
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              _selectedDifficulties.remove(difficulty);
                            } else {
                              _selectedDifficulties.add(difficulty);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.accent : AppColors.surface,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: isSelected ? AppColors.accent : AppColors.primaryGray, width: isSelected ? 2 : 1),
                          ),
                          child: Text(
                            difficulty,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: isSelected ? AppColors.onAccent : AppColors.onBackground,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Duration Section
                _buildFilterSectionHeader('Duration', Icons.schedule_outlined),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', '0-4 weeks', '5-8 weeks', '9-12 weeks', '13+ weeks'].map((duration) {
                      final isSelected = _selectedDuration == duration;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            _selectedDuration = duration;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.accent : AppColors.surface,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: isSelected ? AppColors.accent : AppColors.primaryGray, width: isSelected ? 2 : 1),
                          ),
                          child: Text(
                            duration,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: isSelected ? AppColors.onAccent : AppColors.onBackground,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Certified Only Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _showCertifiedOnly ? AppColors.completed.withOpacity(0.2) : AppColors.primaryGray.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Icon(Icons.verified, color: _showCertifiedOnly ? AppColors.completed : AppColors.primaryGray, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Certified Trainers Only', style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
                            Text('Show only verified professionals', style: AppTextStyles.labelSmall.copyWith(color: const Color.fromARGB(255, 47, 48, 49))),
                          ],
                        ),
                      ),
                      Switch(
                        value: _showCertifiedOnly,
                        onChanged: (value) {
                          setModalState(() {
                            _showCertifiedOnly = value;
                          });
                        },
                        activeColor: AppColors.completed,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setModalState(() {
                              _selectedCategoryIds.clear();
                              _selectedDifficulties.clear();
                              _selectedDuration = 'All';
                              _sortBy = '';
                              _showCertifiedOnly = false;
                            });
                            setState(() {});
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryGray, width: 2),
                            foregroundColor: AppColors.onBackground,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          ),
                          icon: const Icon(Icons.clear_all, size: 20),
                          label: Text('Clear All', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onBackground)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {});
                            _loadBrowsePrograms(reset: true);
                            _loadMarketplaceBundles();
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            backgroundColor: AppColors.accentVariant,
                            foregroundColor: AppColors.onAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          ),
                          icon: const Icon(Icons.check, size: 20),
                          label: Text('Apply Filters', style: AppTextStyles.buttonMedium),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentVariant, size: 20),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
      ],
    );
  }

  void _viewProgram(Map<String, dynamic> program) {
    _showProgramDetail(program);
  }

  void _viewBundle(Map<String, dynamic> bundle) {
    Get.toNamed(AppRoutes.bundleDetail, arguments: bundle);
  }

  ButtonStyle _compactViewButtonStyle({required Color backgroundColor, required Color foregroundColor, required BorderRadius borderRadius, EdgeInsetsGeometry? padding}) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 0,
      padding: padding ?? EdgeInsets.symmetric(horizontal: 12.w, vertical: 0),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
    );
  }

  Widget _buildCompactViewButton({
    required VoidCallback onPressed,
    Color backgroundColor = AppColors.accent,
    Color foregroundColor = AppColors.onAccent,
    double height = 25,
    BorderRadius? borderRadius,
    TextStyle? textStyle,
  }) {
    return SizedBox(
      height: height.h,
      child: ElevatedButton(
        onPressed: onPressed,
        style: _compactViewButtonStyle(backgroundColor: backgroundColor, foregroundColor: foregroundColor, borderRadius: borderRadius ?? BorderRadius.circular(50)),
        child: Text(
          'View',
          style: textStyle ?? AppTextStyles.labelSmall.copyWith(color: foregroundColor, fontSize: 10.sp, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _showAddToCalendarModal(Map<String, dynamic> item, {bool isBundle = false}) {
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.accentVariant.withOpacity(0.2), borderRadius: BorderRadius.circular(50)),
                          child: const Icon(Icons.calendar_today, color: AppColors.accentVariant, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text('Add to Calendar', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.primaryGray),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Program/Bundle info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(color: AppColors.accentVariant.withOpacity(0.2), borderRadius: BorderRadius.circular(50)),
                        child: Icon(isBundle ? Icons.inventory_2 : Icons.fitness_center, color: AppColors.accentVariant, size: 30),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'],
                              style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isBundle ? '${(item['programs'] as List).length} programs included' : item['duration'] ?? '',
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Date Selection
                Text('Select Start Date', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accentVariant.withOpacity(0.5), width: 2),
                  ),
                  child: InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.accentVariant,
                                onPrimary: AppColors.onAccent,
                                surface: AppColors.surface,
                                onSurface: AppColors.onSurface,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: AppColors.accentVariant, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Date', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                              const SizedBox(height: 4),
                              Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.accentVariant),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Schedule info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentVariant.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accentVariant.withOpacity(0.3), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.accentVariant, size: 20),
                          const SizedBox(width: 8),
                          Text('Schedule Information', style: AppTextStyles.titleSmall.copyWith(color: AppColors.accentVariant)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.play_circle_outline, 'Program starts on selected date'),
                      _buildInfoRow(Icons.bedtime, 'Rest days included as per trainer'),
                      _buildInfoRow(Icons.edit_calendar, 'You can edit individual days after import'),
                      _buildInfoRow(Icons.schedule, 'Follows trainer recommended schedule'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryGray, width: 2),
                            foregroundColor: AppColors.onBackground,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Cancel', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onBackground)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _addToCalendar(item, selectedDate, isBundle: isBundle);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentVariant,
                            foregroundColor: AppColors.onAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check, size: 20),
                          label: Text('Add to Calendar', style: AppTextStyles.buttonMedium),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryGray, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
          ),
        ],
      ),
    );
  }

  void _addToCalendar(Map<String, dynamic> item, DateTime startDate, {bool isBundle = false}) {
    // Here you would integrate with your calendar storage/state management
    // For now, we'll show a success modal

    // TODO: Implement actual calendar integration
    // This would involve:
    // 1. Parsing the program duration (e.g., "12 weeks")
    // 2. Creating daily workout entries in the calendar
    // 3. Adding rest days as defined by the trainer
    // 4. Storing in local storage or state management

    _showSuccessModal(item, startDate, isBundle: isBundle);
  }

  void _showSuccessModal(Map<String, dynamic> item, DateTime startDate, {bool isBundle = false}) {
    final randomQuote = (_motivationalQuotes..shuffle()).first;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: AppColors.completed.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: AppColors.completed, size: 50),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Added to Calendar!',
                style: AppTextStyles.headlineMedium.copyWith(color: AppColors.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Start date info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(50)),
                child: Text('Starts: ${startDate.day}/${startDate.month}/${startDate.year}', style: AppTextStyles.titleSmall.copyWith(color: AppColors.accent)),
              ),
              const SizedBox(height: 16),

              // Motivational Quote
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.format_quote, color: AppColors.accent, size: 24),
                    const SizedBox(height: 8),
                    Text(
                      randomQuote,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Info boxes
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(50)),
                      child: Column(
                        children: [
                          Icon(Icons.calendar_today, color: AppColors.accent, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            'View in\nPlanner',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.completed.withOpacity(0.1), borderRadius: BorderRadius.circular(50)),
                      child: Column(
                        children: [
                          Icon(Icons.library_books, color: AppColors.completed, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            'View in\nPurchases',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // Action Buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to planner (calendar tab - index 1)
                        try {
                          Get.find<dynamic>().changeTab(1);
                        } catch (e) {
                          // If controller not found, show message
                          Get.snackbar(
                            'Success',
                            'Program added to calendar! View it in the Planner tab.',
                            backgroundColor: AppColors.completed,
                            colorText: AppColors.onError,
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.calendar_today, size: 20),
                      label: Text('Go to Planner', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryGray, width: 2),
                        foregroundColor: AppColors.onBackground,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Continue Browsing', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onBackground)),
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

  Map<String, dynamic>? _programRaw(Map<String, dynamic> program) {
    final r = program['_apiProgram'];
    if (r is Map<String, dynamic>) return r;
    if (r is Map) return Map<String, dynamic>.from(r);
    return null;
  }

  String? _trainerAvatarUrlFromBundle(Map<String, dynamic> bundle) {
    final fromCard = ImageUrlSanitizer.asHttpUrlOrNull(bundle['trainerImageUrl']?.toString());
    if (fromCard != null) return fromCard;

    final api = bundle['_apiBundle'];
    if (api is Map) {
      final tr = api['trainer'];
      if (tr is Map) {
        final t = Map<String, dynamic>.from(tr);
        final pic = t['profilePicture'];
        if (pic is Map) {
          final url = ImageUrlSanitizer.asHttpUrlOrNull(pic['url']?.toString());
          if (url != null) return url;
        }
        final prof = t['profile'];
        if (prof is Map) {
          final profPic = prof['profilePicture'];
          if (profPic is Map) {
            return ImageUrlSanitizer.asHttpUrlOrNull(profPic['url']?.toString());
          }
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _bundleTrainerChipPayload(Map<String, dynamic> bundle, Map<String, dynamic>? primaryProgram) {
    final trainerName = (bundle['trainer'] ?? primaryProgram?['trainer'] ?? 'Trainer').toString();
    final url = (primaryProgram != null ? _programTrainerAvatarUrl(primaryProgram) : null) ?? _trainerAvatarUrlFromBundle(bundle);
    final initials = (primaryProgram?['trainerImage'] ?? bundle['trainerImage'] ?? 'T').toString();
    return {'trainer': trainerName, 'trainerImageUrl': url, 'trainerImage': initials};
  }

  String? _programTrainerAvatarUrl(Map<String, dynamic> program) {
    final direct = ImageUrlSanitizer.asHttpUrlOrNull(program['trainerImageUrl']?.toString());
    if (direct != null) return direct;

    final p = _programRaw(program);
    if (p == null) return null;

    final display = p['display'];
    if (display is Map) {
      final fromDisplay = ImageUrlSanitizer.asHttpUrlOrNull(display['instructor_avatar_url']?.toString());
      if (fromDisplay != null) return fromDisplay;
    }

    final t = p['trainer'];
    if (t is! Map) return null;
    final pic = t['profilePicture'];
    if (pic is Map) {
      final url = ImageUrlSanitizer.asHttpUrlOrNull(pic['url']?.toString());
      if (url != null) return url;
    }
    final prof = t['profile'];
    if (prof is Map) {
      final profPic = prof['profilePicture'];
      if (profPic is Map) return ImageUrlSanitizer.asHttpUrlOrNull(profPic['url']?.toString());
    }
    return null;
  }

  Widget _programTrainerAvatarChip(Map<String, dynamic> program, {required double size}) {
    final url = _programTrainerAvatarUrl(program);
    final initials = (program['trainerImage'] ?? 'T').toString();
    final radius = size / 2;
    return SafeCircleNetworkAvatar(
      radius: radius,
      imageUrl: url,
      backgroundColor: AppColors.accent.withOpacity(0.15),
      fallback: Text(
        initials.length > 2 ? initials.substring(0, 1).toUpperCase() : initials.toUpperCase(),
        style: TextStyle(color: AppColors.accent, fontSize: radius * 0.85, fontWeight: FontWeight.w700),
      ),
    );
  }

  int? _programReviewCount(Map<String, dynamic> program) {
    final fromCard = (program['reviews'] as num?)?.toInt();
    final p = _programRaw(program);
    if (p != null) {
      final rc = (p['ratingCount'] as num?)?.toInt();
      if (rc != null) return rc;
      final d = p['display'];
      if (d is Map) {
        final fromDisplay = (d['review_count'] as num?)?.toInt();
        if (fromDisplay != null) return fromDisplay;
      }
    }
    return fromCard;
  }

  int _programEnrollmentCount(Map<String, dynamic> program) {
    final fromCard = (program['students'] as num?)?.toInt();
    if (fromCard != null) return fromCard;

    final p = _programRaw(program);
    if (p != null) {
      final total = (p['totalEnrollments'] as num?)?.toInt();
      if (total != null) return total;
      final d = p['display'];
      if (d is Map) {
        final fromDisplay = (d['enrollment_count'] as num?)?.toInt();
        if (fromDisplay != null) return fromDisplay;
      }
      final students = (p['students'] as num?)?.toInt();
      if (students != null) return students;
    }
    return 0;
  }

  double _programRatingValue(Map<String, dynamic> program) {
    final fromCard = (program['rating'] as num?)?.toDouble();
    final p = _programRaw(program);
    if (p != null) {
      final fromApi = (p['ratingAvg'] as num?)?.toDouble();
      if (fromApi != null) return fromApi;
      final d = p['display'];
      if (d is Map) {
        final fromDisplay = (d['average_rating'] as num?)?.toDouble();
        if (fromDisplay != null) return fromDisplay;
      }
    }
    return fromCard ?? 0.0;
  }

  double _programTrainerRatingValue(Map<String, dynamic> program) => MarketplaceRepository.trainerReviewRatingAvgFromProgramApi(program);

  int _programTrainerReviewCount(Map<String, dynamic> program) => MarketplaceRepository.trainerReviewCountFromProgramApi(program);

  static final RegExp _mongoIdRe = RegExp(r'^[a-fA-F0-9]{24}$');

  String? _programMongoId(Map<String, dynamic> program) {
    for (final key in ['id', '_id']) {
      final v = program[key]?.toString().trim();
      if (v != null && v.isNotEmpty && _mongoIdRe.hasMatch(v)) return v;
    }
    final raw = _programRaw(program);
    final fromApi = raw?['_id']?.toString().trim();
    if (fromApi != null && fromApi.isNotEmpty && _mongoIdRe.hasMatch(fromApi)) return fromApi;
    return null;
  }

  Map<String, dynamic> _programPricing(Map<String, dynamic> program) {
    final raw = _programRaw(program);
    if (raw != null) return resolveProgramPricingFromApi(raw);
    return resolveProgramPricingFromApi({
      'price': program['price'],
      'netPrice': program['netPrice'],
      'discount': program['discount'],
    });
  }

  Widget _buildProgramCardPrice(Map<String, dynamic> program, {bool compact = false}) {
    final pricing = _programPricing(program);
    final listPrice = (pricing['listPrice'] as num).toDouble();
    final netPrice = (pricing['netPrice'] as num).toDouble();
    final discount = (pricing['discount'] as num).toInt();
    final hasDiscount = discount > 0 && listPrice > netPrice;
    final priceStyle = AppTextStyles.titleMedium.copyWith(
      color: AppColors.onSurface,
      fontWeight: FontWeight.w700,
      fontSize: compact ? 13.sp : 16.sp,
      height: 1.1,
    );

    if (!hasDiscount) {
      return Text(
        '\$${netPrice.toStringAsFixed(2)}',
        style: priceStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
      );
    }

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '\$${netPrice.toStringAsFixed(2)}',
            style: priceStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(width: 3.w),
          Text(
            '\$${listPrice.toStringAsFixed(2)}',
            style: TextStyle(color: const Color(0xFF999999), fontSize: 9.sp, height: 1.1, decoration: TextDecoration.lineThrough),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '\$${netPrice.toStringAsFixed(2)}',
          style: priceStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '\$${listPrice.toStringAsFixed(2)}',
          style: TextStyle(color: const Color(0xFF999999), fontSize: 10.sp, decoration: TextDecoration.lineThrough),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildProgramCardPriceRow(Map<String, dynamic> program, {BorderRadius? viewButtonRadius, bool compact = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildCompactViewButton(
          onPressed: () => _viewProgram(program),
          borderRadius: viewButtonRadius ?? BorderRadius.circular(50),
          height: compact ? 22 : 25,
        ),
        SizedBox(width: 4.w),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: _buildProgramCardPrice(program, compact: compact),
          ),
        ),
      ],
    );
  }

  List<String> _programWhatsIncludedLines(Map<String, dynamic> program) {
    final p = _programRaw(program);
    if (p == null) return [];
    final wi = p['whatsIncluded'];
    if (wi is! List) return [];
    return wi.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }

  List<Map<String, dynamic>> _programExercisePreview(Map<String, dynamic> program, {int maxItems = 6}) {
    final p = _programRaw(program);
    if (p == null) return [];
    final ex = p['exercise'];
    if (ex is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in ex) {
      if (e is Map) out.add(Map<String, dynamic>.from(e));
      if (out.length >= maxItems) break;
    }
    return out;
  }

  String? _programStatusLabel(Map<String, dynamic> program) {
    final p = _programRaw(program);
    final s = p?['status']?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  Widget _programSheetHeroImage(Map<String, dynamic> program) {
    final url = ImageUrlSanitizer.asHttpUrlOrFallback(program['imageUrl']?.toString(), fallback: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=800&q=80');
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.primaryGray.withOpacity(0.25),
            alignment: Alignment.center,
            child: Icon(Icons.fitness_center, size: 48.sp, color: AppColors.accent),
          ),
        ),
      ),
    );
  }

  void _showProgramDetail(Map<String, dynamic> program) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _MarketplaceProgramPreviewSheet(initialProgram: program, hostState: this),
    );
  }

  Widget _buildProgramDetailSheetContent(BuildContext sheetContext, Map<String, dynamic> program, ScrollController scrollController) {
    final subtitle = program['subtitle']?.toString().trim();
    final desc = program['description']?.toString().trim();
    final descriptionText = (desc != null && desc.isNotEmpty) ? desc : 'No description available.';
    final difficulty = (program['difficulty'] ?? program['goal'])?.toString().trim();
    final statusLabel = _programStatusLabel(program);
    final reviewCount = _programReviewCount(program);
    final pricing = _programPricing(program);
    final listPrice = (pricing['listPrice'] as num).toDouble();
    final netPrice = (pricing['netPrice'] as num).toDouble();
    final discountPct = (pricing['discount'] as num).toInt();
    final hasDiscount = discountPct > 0 && listPrice > netPrice;
    final whatsLines = _programWhatsIncludedLines(program);
    final exercisePreview = _programExercisePreview(program);
    final trainerAvatar = _programTrainerAvatarUrl(program);
    final initials = (program['trainerImage'] ?? 'T').toString();
    final trainerRating = _programTrainerRatingValue(program);
    final trainerReviewCount = _programTrainerReviewCount(program);

    final chipRows = <Widget>[
      _buildInfoChip(Icons.schedule, '${program['duration']}'),
      _buildInfoChip(Icons.category, '${program['category']}'),
      _buildInfoChip(Icons.flag, '${program['goal']}'),
    ];
    if (difficulty != null && difficulty.isNotEmpty && difficulty != 'All') {
      chipRows.add(_buildInfoChip(Icons.speed, difficulty));
    }
    if (statusLabel != null && statusLabel.toLowerCase() == 'published') {
      chipRows.add(_buildInfoChip(Icons.verified_outlined, _titleCaseWords(statusLabel.replaceAll('_', ' '))));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        controller: scrollController,
        children: [
          _programSheetHeroImage(program),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              Navigator.pop(sheetContext);
              _navigateToTrainerProfile(program);
            },
            child: Row(
              children: [
                SafeCircleNetworkAvatar(
                  radius: 30,
                  imageUrl: trainerAvatar,
                  backgroundColor: AppColors.accent,
                  fallback: Text(initials, style: AppTextStyles.titleMedium.copyWith(color: AppColors.onAccent)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${program['trainer']}', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
                      Row(
                        children: [
                          Icon(Icons.star, color: AppColors.accent, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            trainerRating.toStringAsFixed(1),
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                          ),
                          if (trainerReviewCount > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '($trainerReviewCount ${trainerReviewCount == 1 ? 'review' : 'reviews'})',
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
                            ),
                          ],
                        ],
                      ),
                      if (program['certified'] == true)
                        Row(
                          children: [
                            Icon(Icons.verified, color: AppColors.completed, size: 16),
                            const SizedBox(width: 4),
                            Text('Certified Trainer', style: AppTextStyles.labelSmall.copyWith(color: AppColors.completed)),
                          ],
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.accent),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('${program['title']}', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.onSurface)),
          if (subtitle != null && subtitle.isNotEmpty) ...[const SizedBox(height: 8), Text(subtitle, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray))],
          const SizedBox(height: 12),
          Text(descriptionText, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, height: 1.45)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Wrap(spacing: 12, runSpacing: 8, children: chipRows),
          ),
          const SizedBox(height: 28),
          Text('What\'s included', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
          const SizedBox(height: 12),
          if (whatsLines.isNotEmpty)
            ...whatsLines.map((line) => _buildDetailItem(Icons.check_circle_outline, line))
          else ...[
            _buildDetailItem(Icons.fitness_center, 'Full workout plans and schedules'),
            _buildDetailItem(Icons.video_library, 'Video demonstrations for exercises'),
            _buildDetailItem(Icons.track_changes, 'Progress tracking and analytics'),
            _buildDetailItem(Icons.chat, 'Direct messaging with trainer'),
            _buildDetailItem(Icons.library_books, 'Nutrition guide included'),
          ],
          if (exercisePreview.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('Sample exercises', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
            const SizedBox(height: 12),
            ...exercisePreview.map((ex) {
              final name = ex['name']?.toString().trim().isNotEmpty == true ? ex['name'].toString() : 'Exercise';
              final sets = ex['sets'];
              final reps = ex['reps'];
              final rest = ex['restTime'];
              final bits = <String>[];
              if (sets != null) bits.add('$sets sets');
              if (reps != null) bits.add('$reps reps');
              if (rest != null) bits.add('${rest}s rest');
              final sub = bits.join(' · ');
              return Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sports_gymnastics, color: AppColors.accent, size: 20.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                          ),
                          if (sub.isNotEmpty)
                            Text(
                              sub,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontSize: 11.sp),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Price', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGray)),
                          if (hasDiscount) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '\$${netPrice.toStringAsFixed(2)}',
                                  style: AppTextStyles.headlineMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '\$${listPrice.toStringAsFixed(2)}',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, decoration: TextDecoration.lineThrough),
                                ),
                              ],
                            ),
                          
                          ] else
                            Text(
                              '\$${netPrice.toStringAsFixed(2)}',
                              style: AppTextStyles.headlineMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                            ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Get.toNamed(AppRoutes.programDetail, arguments: program);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      ),
                      child: const Text('View Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _titleCaseWords(String input) {
    final parts = input.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return input;
    return parts.map((w) => '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1).toLowerCase() : ''}').join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final filteredPrograms = _filteredPrograms;
    final filteredBundles = _filteredBundles;
    final featuredPrograms = _featuredSectionPrograms;
    final newReleases = _newReleasesSectionPrograms;

    final hasActiveFilters = _hasActiveFilters;
    final catalogCountLabel = _browseProgramsTotal > 0 ? '$_browseProgramsTotal' : '${filteredPrograms.length}';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD6D6D6), Color(0xFFE8E8E8), Color(0xFFC0C0C0)]),
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Obx(() {
            final notificationController = Get.find<NotificationController>();
            final unreadCount = notificationController.unreadCount.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Image.asset('assets/images/humburger.png', width: 25.w),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ).paddingOnly(left: 10),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.0),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          }),
          title: Text(
            'Marketplace',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
          actions: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Image.asset('assets/images/search-normal000.png', width: 20.w),
                  onPressed: _openProgramSearch,
                ),
                if (_programSearchTitle.isNotEmpty)
                  Positioned(
                    right: 10,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            Stack(
              children: [
                IconButton(
                  icon: Image.asset('assets/images/filter000.png', width: 20.w),
                  onPressed: _showFilterModal,
                ),
                if (hasActiveFilters)
                  Positioned(
                    right: 20,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ).paddingOnly(right: 5),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _refreshMarketplace,
          child: SingleChildScrollView(
            controller: _marketplaceScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // WEEKLY FREE WORKOUT BANNER
                _buildWeeklyFreeWorkoutBanner(),

                if (_marketplaceSectionsError != null && featuredPrograms.isEmpty && newReleases.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Could not load marketplace sections.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground)),
                        const SizedBox(height: 8),
                        Text(
                          _marketplaceSectionsError!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                        ),
                        TextButton(
                          onPressed: _loadMarketplaceSections,
                          child: Text(
                            'Retry',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                // FEATURED SECTION — `GET .../marketplace/sections?section=featured`
                _buildFeaturedSection(featuredPrograms, loading: _marketplaceSectionsLoading && featuredPrograms.isEmpty),

                SizedBox(height: 24.h),
                // BUNDLES — `GET /customer/bundle`
                if (_bundlesLoading && _apiBundles.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.h),
                    child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  )
                else if (_bundlesError != null && _apiBundles.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Could not load bundles.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground)),
                        SizedBox(height: 6.h),
                        Text(
                          _bundlesError!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                        ),
                        TextButton(
                          onPressed: _loadMarketplaceBundles,
                          child: Text(
                            'Retry',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _buildBundlesSection(filteredBundles),

                SizedBox(height: 24.h),
                // NEW RELEASES — `GET .../marketplace/sections?section=new_releases`
                _buildHorizontalSection('New Releases', Icons.fiber_new_rounded, newReleases, loading: _marketplaceSectionsLoading && newReleases.isEmpty),

                SizedBox(height: 24.h),

                // Active filters indicator
                if (hasActiveFilters) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Active Filters: ',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                        ),
                        if (_programSearchTitle.isNotEmpty)
                          _buildFilterChip('Search: $_programSearchTitle', () {
                            setState(() => _programSearchTitle = '');
                            _loadBrowsePrograms(reset: true);
                          }),
                        if (_sortBy.isNotEmpty)
                          _buildFilterChip(_sortBy, () {
                            setState(() => _sortBy = '');
                            _loadBrowsePrograms(reset: true);
                          }),
                        for (final id in _selectedCategoryIds)
                          _buildFilterChip(_categoryLabel(id), () {
                            setState(() => _selectedCategoryIds.remove(id));
                            _loadBrowsePrograms(reset: true);
                          }),
                        for (final d in _selectedDifficulties)
                          _buildFilterChip(d, () {
                            setState(() => _selectedDifficulties.remove(d));
                            _loadBrowsePrograms(reset: true);
                          }),
                        if (_selectedDuration != 'All')
                          _buildFilterChip(_selectedDuration, () {
                            setState(() => _selectedDuration = 'All');
                            _loadBrowsePrograms(reset: true);
                          }),
                        if (_showCertifiedOnly)
                          _buildFilterChip('Certified', () {
                            setState(() => _showCertifiedOnly = false);
                            _loadBrowsePrograms(reset: true);
                          }),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],

                // MARKETPLACE GRID - All Programs
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'All Programs',
                        style: AppTextStyles.titleLarge.copyWith(color: const Color(0xFF000000), fontWeight: FontWeight.w700),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          catalogCountLabel,
                          style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),

                // Programs Grid — `GET /marketplace/programs`
                if (_browseProgramsLoading && _browsePrograms.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 48.h),
                    child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  )
                else if (_browseProgramsError != null && _browsePrograms.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Could not load programs.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground)),
                        SizedBox(height: 8.h),
                        Text(
                          _browseProgramsError!,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                        ),
                        TextButton(
                          onPressed: () => _loadBrowsePrograms(reset: true),
                          child: Text(
                            'Retry',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (filteredPrograms.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.w),
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 80, color: AppColors.primaryGray.withOpacity(0.5)),
                          SizedBox(height: 16.h),
                          Text(hasActiveFilters ? 'No programs found' : 'No programs available', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
                          SizedBox(height: 8.h),
                          if (hasActiveFilters)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _programSearchTitle = '';
                                  _selectedCategoryIds.clear();
                                  _selectedDifficulties.clear();
                                  _selectedDuration = 'All';
                                  _sortBy = '';
                                  _showCertifiedOnly = false;
                                });
                                _loadBrowsePrograms(reset: true);
                                _loadMarketplaceBundles();
                              },
                              child: const Text('Clear Filters'),
                            )
                          else
                            TextButton(onPressed: () => _loadBrowsePrograms(reset: true), child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProgramsGrid(filteredPrograms),
                      if (_browseProgramsLoadingMore)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: const Center(
                            child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                          ),
                        ),
                    ],
                  ),

                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDelete) {
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDelete,
      backgroundColor: AppColors.accent.withOpacity(0.2),
      labelStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
    );
  }

  // Weekly Free Workout Banner
  Widget _buildWeeklyFreeWorkoutBanner() {
    final activeWorkout = _activeWeeklyWorkout;
    if (activeWorkout == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 30.h, 16.w, 8.h),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main Container
          Container(
            height: 200.h,
            width: double.infinity,
            decoration: BoxDecoration(
              boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Background Image (light beige with wavy green lines)
                  Positioned.fill(child: Image.asset('assets/images/bannerbg.png', fit: BoxFit.contain)),
                  // Content Row - Text on left
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      children: [
                        // Left side - Text content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Weekly Free Workout Badge
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                  'WEEKLY FREE WORKOUT',
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.bold, letterSpacing: 1.1, fontSize: 13.sp),
                                ),
                              ),
                              SizedBox(height: 20.h),
                              // Title
                              Text(
                                'The Weekly Strength Series',
                                style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w700, height: 1.0, fontSize: 25.sp),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 6.h),
                              // Description
                              Flexible(
                                child: Text(
                                  activeWorkout['description'] ?? 'Master the basics of strength training this week for free!',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.onBackground.withOpacity(0.7), fontSize: 15.sp, height: 1.4),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Spacer for image area
                        SizedBox(width: 120.w),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Banner Image - Positioned above container, extending from top
          Positioned(
            right: 16.w,
            top: -17.h,
            child: Image.asset('assets/images/bannerimage.png', fit: BoxFit.cover, height: 205.h),
          ),
        ],
      ),
    );
  }

  // Featured Section - Large Hero Cards (Netflix Style)
  Widget _buildFeaturedSection(List<Map<String, dynamic>> programs, {bool loading = false}) {
    if (loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Icon(Icons.local_fire_department, color: AppColors.error, size: 24.sp),
                SizedBox(width: 8.w),
                Text(
                  'Featured & Trending',
                  style: AppTextStyles.titleLarge.copyWith(color: const Color(0xFF000000), fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 220.h,
            child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          ),
        ],
      );
    }
    if (programs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Icon(Icons.local_fire_department, color: AppColors.error, size: 24.sp),
              SizedBox(width: 8.w),
              Text(
                'Featured & Trending',
                style: AppTextStyles.titleLarge.copyWith(color: const Color(0xFF000000), fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 220.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: programs.length,
            itemBuilder: (context, index) {
              return _buildFeaturedCard(programs[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(Map<String, dynamic> program) {
    return SizedBox(
      child: GestureDetector(
        onTap: () => _showProgramDetail(program),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.50,
          margin: EdgeInsets.only(right: 16.w),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail Image
              GestureDetector(
                onTap: () => _showProgramDetail(program),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
                      child: Image.network(
                        ImageUrlSanitizer.asHttpUrlOrFallback(
                          program['imageUrl']?.toString(),
                          fallback: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400&h=300&fit=crop',
                        ),
                        width: double.infinity,
                        height: 110.h,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: double.infinity,
                          height: 110.h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [const Color(0xFF9333EA), const Color(0xFFFBBF24)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          ),
                          child: const Center(child: Icon(Icons.fitness_center, size: 40, color: Colors.white)),
                        ),
                      ),
                    ),
                    // Certified badge
                    if (program['certified'])
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: EdgeInsets.all(4.w),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(50)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.local_fire_department, color: Color.fromARGB(255, 245, 140, 102), size: 12.sp),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'Hot',
                                      style: TextStyle(color: Colors.black, fontSize: 10.sp, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 4.w),
                              // Certified Badge
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(50)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified, color: AppColors.completed, size: 12.sp),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'Certified',
                                      style: TextStyle(color: Colors.black, fontSize: 10.sp, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Content section
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title
                      GestureDetector(
                        onTap: () => _showProgramDetail(program),
                        child: Text(
                          program['title'],
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700, height: 1.1, fontSize: 16.sp),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: 8.h),

                      // Instructor with Certification Badge
                      Row(
                        children: [
                          _programTrainerAvatarChip(program, size: 23.h),
                          SizedBox(width: 6.w),
                          // Trainer Name
                          Flexible(
                            child: Text(
                              (program['trainer'] ?? 'Trainer').toString().replaceAll(' ', '\n'),
                              style: TextStyle(color: const Color(0xFF333333), fontSize: 10.sp, height: 1.0, fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 7.w),
                          Icon(Icons.star, color: AppColors.accent, size: 13.sp),
                          Text(
                            _programRatingValue(program).toStringAsFixed(1),
                            style: TextStyle(color: Colors.black, fontSize: 13.sp, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 5.w),
                          Icon(Icons.people, color: Colors.black, size: 13.sp),
                          SizedBox(width: 3.w),
                          Flexible(
                            child: Text(
                              '${_formatNumber(_programEnrollmentCount(program))}',
                              style: TextStyle(color: Colors.black, fontSize: 13.sp),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 8.h),

                      // Price and Button
                      _buildProgramCardPriceRow(program),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalSection(String title, IconData icon, List<Map<String, dynamic>> programs, {bool loading = false}) {
    if (loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Icon(icon, color: AppColors.accent, size: 24),
                SizedBox(width: 8.w),
                Text(
                  title,
                  style: AppTextStyles.titleLarge.copyWith(color: const Color(0xFF000000), fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 230.h,
            child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          ),
        ],
      );
    }
    if (programs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 24),
              SizedBox(width: 8.w),
              Text(
                title,
                style: AppTextStyles.titleLarge.copyWith(color: const Color(0xFF000000), fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 230.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: programs.length,
            itemBuilder: (context, index) {
              return SizedBox(width: MediaQuery.of(context).size.width * 0.5, child: _buildProgramCard(programs[index]));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBundlesSection(List<Map<String, dynamic>> bundles) {
    if (bundles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Icon(Icons.inventory_2, color: AppColors.accent, size: 24),
              SizedBox(width: 8.w),
              Text(
                'Bundle Deals',
                style: AppTextStyles.titleLarge.copyWith(color: const Color(0xFF000000), fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 195.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: bundles.length > 3 ? 4 : bundles.length,
            itemBuilder: (context, index) {
              if (index < 3 && index < bundles.length) {
                return _buildBundleCard(bundles[index]);
              } else if (bundles.length > 3) {
                return _buildSeeMoreCard();
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgramsGrid(List<Map<String, dynamic>> programs) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.68, crossAxisSpacing: 12.w, mainAxisSpacing: 12.h),
        itemCount: programs.length,
        itemBuilder: (context, index) {
          return _buildGridProgramCard(programs[index]);
        },
      ),
    );
  }

  Widget _buildGridProgramCard(Map<String, dynamic> program) {
    return GestureDetector(
      onTap: () => _showProgramDetail(program),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Image
            GestureDetector(
                onTap: () => _showProgramDetail(program),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
                      child: Image.network(
                        ImageUrlSanitizer.asHttpUrlOrFallback(
                          program['imageUrl']?.toString(),
                          fallback: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400&h=300&fit=crop',
                        ),
                        width: double.infinity,
                        height: 110.h,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: double.infinity,
                          height: 110.h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [const Color(0xFF9333EA), const Color(0xFFFBBF24)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          ),
                          child: const Center(child: Icon(Icons.fitness_center, size: 40, color: Colors.white)),
                        ),
                      ),
                    ),
                    // Certified badge
                    if (program['certified'])
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: EdgeInsets.all(4.w),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(50)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.local_fire_department, color: Color.fromARGB(255, 245, 140, 102), size: 12.sp),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'Hot',
                                      style: TextStyle(color: Colors.black, fontSize: 10.sp, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 4.w),
                              // Certified Badge
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(50)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified, color: AppColors.completed, size: 12.sp),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'Certified',
                                      style: TextStyle(color: Colors.black, fontSize: 10.sp, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Content section
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 4.h, 10.w, 6.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Title
                      GestureDetector(
                        onTap: () => _showProgramDetail(program),
                        child: Text(
                          program['title'],
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700, height: 1.1, fontSize: 13.sp),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: 4.h),

                      // Instructor with Certification Badge
                      Row(
                        children: [
                          _programTrainerAvatarChip(program, size: 20.h),
                          SizedBox(width: 6.w),
                          Flexible(
                            child: Text(
                              (program['trainer'] ?? 'Trainer').toString(),
                              style: TextStyle(color: const Color(0xFF333333), fontSize: 10.sp, height: 1.1, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(Icons.star, color: AppColors.accent, size: 12.sp),
                          Text(
                            _programRatingValue(program).toStringAsFixed(1),
                            style: TextStyle(color: Colors.black, fontSize: 11.sp, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 3.w),
                          Icon(Icons.people, color: Colors.black, size: 12.sp),
                          SizedBox(width: 2.w),
                          Flexible(
                            child: Text(
                              '${_formatNumber(_programEnrollmentCount(program))}',
                              style: TextStyle(color: Colors.black, fontSize: 11.sp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Price and Button
                      _buildProgramCardPriceRow(program, viewButtonRadius: BorderRadius.circular(10), compact: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  int _bundleProgramCount(Map<String, dynamic> bundle) {
    final programs = bundle['programs'];
    if (programs is List) return programs.length;
    final api = bundle['_apiBundle'];
    if (api is Map) {
      final raw = api['programs'];
      if (raw is List) return raw.length;
    }
    return 0;
  }

  String _bundleProgramCountLabel(Map<String, dynamic> bundle) {
    final count = _bundleProgramCount(bundle);
    return count == 1 ? '1 Program' : '$count Programs';
  }

  Widget _buildBundleCard(Map<String, dynamic> bundle) {
    final programs = bundle['programs'] as List<Map<String, dynamic>>;
    final totalValue = ((bundle['totalValue'] as num?) ?? 0).toDouble();
    final bundlePrice = ((bundle['bundlePrice'] as num?) ?? 0).toDouble();

    // Calculate average rating from programs
    final avgRating = programs.isNotEmpty ? programs.map((p) => ((p['rating'] as num?) ?? 0).toDouble()).reduce((a, b) => a + b) / programs.length : 0.0;
    final totalEnrollments = programs.isNotEmpty ? programs.map((p) => _programEnrollmentCount(p)).reduce((a, b) => a + b) : 0;

    // Get primary trainer (bundle API trainer, else first program)
    final primaryProgram = programs.isNotEmpty ? programs[0] : null;
    final primaryTrainer = (bundle['trainer'] ?? primaryProgram?['trainer'] ?? 'Trainer').toString();
    final isHot = bundle['isHot'] == true;
    final isCertified = bundle['isCertified'] == true || (programs.isNotEmpty && programs.every((p) => p['certified'] == true));

    // Get bundle index to cycle through different images
    final bundleIndex = _apiBundles.indexOf(bundle);
    final backgroundImages = ['assets/images/bundlebg1.png', 'assets/images/bannerbg2.png', 'assets/images/bannerbg3.png'];
    final personImages = ['assets/images/bundleimage.png', 'assets/images/bannerimage2.png', 'assets/images/bannerimage3.png'];
    final bgImage = backgroundImages[bundleIndex % backgroundImages.length];
    final personImage = personImages[bundleIndex % personImages.length];

    return GestureDetector(
      onTap: () {
        Get.toNamed(AppRoutes.bundleDetail, arguments: bundle);
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.90,
        decoration: BoxDecoration(
          color: const Color.fromARGB(0, 255, 229, 229), // Soft pink background
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color.fromARGB(0, 0, 0, 0).withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Background with wavy pattern effect
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(image: AssetImage(bgImage), fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            // Content - Left side
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top section - Instructor Info with Badges
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // Profile Picture (bundle trainer from API, then program catalog)
                            _programTrainerAvatarChip(_bundleTrainerChipPayload(bundle, primaryProgram), size: 20.h),

                            SizedBox(width: 6.w),
                            // Trainer Name
                            Text(
                              primaryTrainer.toString().replaceAll(' ', '\n'),
                              style: TextStyle(color: const Color(0xFF333333), fontSize: 12.sp, height: 1.0, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(width: 4.w),
                            // Hot Badge
                            if (isHot)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.white, // Orange
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.local_fire_department, color: Color.fromARGB(255, 245, 140, 102), size: 12.sp),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'Hot',
                                      style: TextStyle(color: Colors.black, fontSize: 10.sp, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(width: 4.w),
                            // Certified Badge
                            if (isCertified)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: AppColors.white, // Green
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified, color: AppColors.completed, size: 12.sp),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'Certified',
                                      style: TextStyle(color: Colors.black, fontSize: 10.sp, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 7.h),
                        // Program Title
                        SizedBox(
                          width: 210.w,
                          child: Text(
                            bundle['title'] ?? 'Gym Floor Mastery',
                            style: TextStyle(color: const Color(0xFF000000), fontWeight: FontWeight.w700, fontSize: 14.sp, height: 1.0),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        // Statistics Row
                        Row(
                          children: [
                            Text(
                              _bundleProgramCountLabel(bundle),
                              style: TextStyle(color: Colors.black, fontSize: 13.sp),
                            ),

                            SizedBox(width: 10.w),
                            Icon(Icons.people, color: Colors.black, size: 13.sp),
                            SizedBox(width: 3.w),
                            Text(
                              '${_formatNumber(totalEnrollments)}',
                              style: TextStyle(color: Colors.black, fontSize: 13.sp),
                            ),
                          ],
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${bundlePrice.toStringAsFixed(2)}',
                              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 26.sp),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              '\$${totalValue.toStringAsFixed(2)}',
                              style: TextStyle(color: const Color(0xFF999999), fontSize: 13.sp, decoration: TextDecoration.lineThrough),
                            ),
                          ],
                        ),
                        _buildCompactViewButton(
                          onPressed: () => _viewBundle(bundle),
                          height: 30,
                          backgroundColor: const Color(0xFF1A1A1A),
                          foregroundColor: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp),
                        ),
                      ],
                    ).paddingOnly(left: 16.w),

                    // Bottom section - Pricing and Button
                  ],
                ),
                Image.asset(personImage, width: 110.w, fit: BoxFit.contain).paddingOnly(bottom: 10.h),
              ],
            ),
            // Right side - Person image extending beyond card (above and to the right)
          ],
        ),
      ),
    );
  }

  Widget _buildSeeMoreCard() {
    return GestureDetector(
      onTap: () {
        Get.toNamed(AppRoutes.allBundles, arguments: <String, dynamic>{'programCatalog': _browsePrograms, if (_apiBundles.isNotEmpty) 'bundles': _apiBundles});
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.4,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(color: AppColors.primaryVariant, borderRadius: BorderRadius.circular(50)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.grid_view_rounded, size: 30, color: AppColors.accent),
            ),
            SizedBox(height: 16.h),
            Text(
              'See More',
              style: AppTextStyles.titleSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text('${(_apiBundles.length - 3).clamp(0, 999)}+ more bundles', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildProgramCard(Map<String, dynamic> program) {
    return SizedBox(
      width: 270.w,
      child: Container(
        margin: EdgeInsets.only(right: 12.w),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(50)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Image
            GestureDetector(
              onTap: () => _showProgramDetail(program),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8.r)),
                    child: Image.network(
                      ImageUrlSanitizer.asHttpUrlOrFallback(
                        program['imageUrl']?.toString(),
                        fallback: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400&h=300&fit=crop',
                      ),
                      width: double.infinity,
                      height: 110.h,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: double.infinity,
                        height: 110.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [const Color(0xFF9333EA), const Color(0xFFFBBF24)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        ),
                        child: const Center(child: Icon(Icons.fitness_center, size: 40, color: Colors.white)),
                      ),
                    ),
                  ),
                  // Certified badge
                  if (program['certified'])
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.all(4.w),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: Colors.white, // Orange
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_fire_department, color: Color.fromARGB(255, 245, 140, 102), size: 12.sp),
                                  SizedBox(width: 2.w),
                                  Text(
                                    'Hot',
                                    style: TextStyle(color: Colors.black, fontSize: 10.sp, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 4.w),
                            // Certified Badge
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: AppColors.white, // Green
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified, color: AppColors.completed, size: 12.sp),
                                  SizedBox(width: 2.w),
                                  Text(
                                    'Certified',
                                    style: TextStyle(color: Colors.black, fontSize: 10.sp, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content section
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title
                    GestureDetector(
                      onTap: () => _showProgramDetail(program),
                      child: Text(
                        program['title'],
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700, height: 1.1, fontSize: 16.sp),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: 6.h),

                    // Instructor with Certification Badge
                    Row(
                      children: [
                        _programTrainerAvatarChip(program, size: 23.h),
                        SizedBox(width: 6.w),
                        // Trainer Name
                        Flexible(
                          child: Text(
                            (program['trainer'] ?? 'Trainer').toString().replaceAll(' ', '\n'),
                            style: TextStyle(color: const Color(0xFF333333), fontSize: 10.sp, height: 1.0, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 7.w),
                        Icon(Icons.star, color: AppColors.accent, size: 13.sp),
                        Text(
                          _programRatingValue(program).toStringAsFixed(1),
                          style: TextStyle(color: Colors.black, fontSize: 13.sp, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(width: 5.w),
                        Icon(Icons.people, color: Colors.black, size: 13.sp),
                        SizedBox(width: 3.w),
                        Flexible(
                          child: Text(
                            '${_formatNumber(_programEnrollmentCount(program))}',
                            style: TextStyle(color: Colors.black, fontSize: 13.sp),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 6.h),

                    // Rating

                    // Price and Duration
                    _buildProgramCardPriceRow(program, viewButtonRadius: BorderRadius.circular(10)),

                    // View Button
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
      decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.2), borderRadius: BorderRadius.circular(50)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: AppColors.accent),
          SizedBox(width: 6.w),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface, fontSize: 12.sp),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTrainerProfile(Map<String, dynamic> program) {
    String? trainerMongoId = program['trainerId']?.toString().trim();
    if (trainerMongoId != null && trainerMongoId.isEmpty) trainerMongoId = null;
    final api = program['_apiProgram'];
    if (trainerMongoId == null && api is Map) {
      final tr = api['trainer'];
      if (tr is Map) {
        trainerMongoId = tr['_id']?.toString().trim();
      }
    }

    // Create trainer data from program info (real _id required for GET /user/profiles/:id/details)
    final trainerData = <String, dynamic>{
      if (trainerMongoId != null && trainerMongoId.isNotEmpty) ...{'_id': trainerMongoId, 'id': trainerMongoId},
      'role': 'Trainer',
      'isTrainer': true,
      'name': program['trainer'],
      'initials': program['trainerImage'],
      'bio': 'Certified personal trainer with years of experience helping clients achieve their fitness goals. Specializing in ${program['category']} and ${program['goal']}.',
      'specialties': [program['category'], program['goal'], 'Nutrition Coaching'],
      'yearsOfExperience': 8,
      'certified': program['certified'],
      'certifications': program['certified'] ? ['NASM Certified Personal Trainer', 'Precision Nutrition Level 1'] : null,
      'hourlyRate': 75.0,
      'rating': _programRatingValue(program),
      'totalReviews': 127,
      'students': program['students'],
      'activePrograms': 5,
      'completedPrograms': 12,
      'totalPrograms': 17,
    };

    Get.toNamed(AppRoutes.trainerProfile, arguments: trainerData);
  }
}

/// Loads `GET /customer/program/:id` then renders marketplace program preview sheet.
class _MarketplaceProgramPreviewSheet extends StatefulWidget {
  final Map<String, dynamic> initialProgram;
  final _MarketplaceScreenState hostState;

  const _MarketplaceProgramPreviewSheet({required this.initialProgram, required this.hostState});

  @override
  State<_MarketplaceProgramPreviewSheet> createState() => _MarketplaceProgramPreviewSheetState();
}

class _MarketplaceProgramPreviewSheetState extends State<_MarketplaceProgramPreviewSheet> {
  late Map<String, dynamic> _program;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _program = Map<String, dynamic>.from(widget.initialProgram);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProgramDetail());
  }

  Future<void> _loadProgramDetail() async {
    final id = widget.hostState._programMongoId(_program);
    if (id == null || !Get.isRegistered<AuthController>()) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final detail = await Get.find<AuthController>().fetchMarketplaceProgramDetail(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (detail != null) {
        _program = Map<String, dynamic>.from(detail);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        if (_loading) {
          return const SizedBox(
            height: 280,
            child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
          );
        }
        return widget.hostState._buildProgramDetailSheetContent(context, _program, scrollController);
      },
    );
  }
}
