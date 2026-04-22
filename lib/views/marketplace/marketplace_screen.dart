import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/repo/marketplace_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

/// Marketplace screen - browse trainer programs
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String _selectedCategory = 'All';
  String _selectedDifficulty = 'All';
  String _selectedDuration = 'All';
  String _sortBy = 'Featured'; // Featured, Newest, Highest Rated, Price Low-High, Price High-Low
  bool _showCertifiedOnly = false;

  final MarketplaceRepository _marketplaceRepo = MarketplaceRepository();
  List<Map<String, dynamic>> _featuredSectionPrograms = [];
  List<Map<String, dynamic>> _newReleasesSectionPrograms = [];
  bool _marketplaceSectionsLoading = true;
  String? _marketplaceSectionsError;

  List<Map<String, dynamic>> _apiBundles = [];
  bool _bundlesLoading = false;
  String? _bundlesError;

  late final ScrollController _marketplaceScrollController;

  @override
  void initState() {
    super.initState();
    _marketplaceScrollController = ScrollController()..addListener(_onMarketplaceScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([_loadMarketplaceSections(), _loadBrowsePrograms(reset: true)]);
      if (mounted) await _loadMarketplaceBundles();
    });
  }

  @override
  void dispose() {
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
      final result = await _marketplaceRepo.fetchBrowsePrograms(page: page, perPage: _browseProgramsPerPage);
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
      final result = await _marketplaceRepo.fetchBrowsePrograms(page: page, perPage: _browseProgramsPerPage);
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
        _marketplaceRepo.fetchSectionPrograms(section: MarketplaceSection.featured, page: 1, perPage: 20),
        _marketplaceRepo.fetchSectionPrograms(section: MarketplaceSection.newReleases, page: 1, perPage: 20),
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
      final page = await _marketplaceRepo.fetchBrowseBundles(page: 1, perPage: 20, programCatalog: catalog);
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
  static const int _browseProgramsPerPage = 20;

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

  List<Map<String, dynamic>> get _filteredPrograms {
    double ratingOf(Map<String, dynamic> p) => ((p['rating'] as num?) ?? 0).toDouble();
    double priceOf(Map<String, dynamic> p) => ((p['price'] as num?) ?? 0).toDouble();

    var filtered = _browsePrograms.where((program) {
      if (_selectedCategory != 'All' && program['category'] != _selectedCategory) return false;
      if (_selectedDifficulty != 'All' && program['difficulty'] != _selectedDifficulty) return false;
      if (_selectedDuration != 'All') {
        final duration = program['duration']?.toString() ?? '';
        if (_selectedDuration == '0-4 weeks' && !duration.contains(RegExp(r'[1-4]\s+week'))) return false;
        if (_selectedDuration == '5-8 weeks' && !duration.contains(RegExp(r'[5-8]\s+week'))) return false;
        if (_selectedDuration == '9-12 weeks' && !duration.contains(RegExp(r'(9|10|11|12)\s+week'))) return false;
        if (_selectedDuration == '13+ weeks' && !duration.contains(RegExp(r'(1[3-9]|[2-9]\d)\s+week'))) return false;
      }
      if (_showCertifiedOnly && program['certified'] != true) return false;
      return true;
    }).toList();

    switch (_sortBy) {
      case 'Newest':
        filtered = filtered.reversed.toList();
        break;
      case 'Highest Rated':
        filtered.sort((a, b) => ratingOf(b).compareTo(ratingOf(a)));
        break;
      case 'Price Low-High':
        filtered.sort((a, b) => priceOf(a).compareTo(priceOf(b)));
        break;
      case 'Price High-Low':
        filtered.sort((a, b) => priceOf(b).compareTo(priceOf(a)));
        break;
      default:
        break;
    }

    return filtered;
  }

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
                    children: ['Featured', 'Newest', 'Highest Rated', 'Price Low-High', 'Price High-Low'].map((sort) {
                      final isSelected = _sortBy == sort;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            _sortBy = sort;
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
                    children: ['All', 'Strength', 'Cardio', 'Flexibility', 'Bodyweight', 'Running', 'Core', 'Fat Loss', 'Hypertrophy', 'Sports-Specific'].map((category) {
                      final isSelected = _selectedCategory == category;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            _selectedCategory = category;
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
                            category,
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
                    children: ['All', 'Beginner', 'Intermediate', 'Advanced'].map((difficulty) {
                      final isSelected = _selectedDifficulty == difficulty;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            _selectedDifficulty = difficulty;
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
                              _selectedCategory = 'All';
                              _selectedDifficulty = 'All';
                              _selectedDuration = 'All';
                              _sortBy = 'Featured';
                              _showCertifiedOnly = false;
                            });
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
                            setState(() {});
                            Navigator.pop(context);
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

  void _showProgramDetail(Map<String, dynamic> program) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _navigateToTrainerProfile(program);
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.accent,
                      child: Text(program['trainerImage'], style: AppTextStyles.titleMedium.copyWith(color: AppColors.onAccent)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(program['trainer'], style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
                          Row(
                            children: [
                              Icon(Icons.star, color: AppColors.upcoming, size: 16),
                              const SizedBox(width: 4),
                              Text('${program['rating']}', style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface)),
                              const SizedBox(width: 8),
                              Text('${program['students']} students', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                            ],
                          ),
                          if (program['certified'])
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
              const SizedBox(height: 24),
              Text(program['title'], style: AppTextStyles.headlineMedium.copyWith(color: AppColors.onSurface)),
              const SizedBox(height: 12),
              Text(program['description'], style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [_buildInfoChip(Icons.schedule, program['duration']), _buildInfoChip(Icons.category, program['category']), _buildInfoChip(Icons.flag, program['goal'])],
                ),
              ),
              const SizedBox(height: 32),
              Text('Program Details', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
              const SizedBox(height: 12),
              _buildDetailItem(Icons.fitness_center, 'Full workout plans and schedules'),
              _buildDetailItem(Icons.video_library, 'Video demonstrations for all exercises'),
              _buildDetailItem(Icons.track_changes, 'Progress tracking and analytics'),
              _buildDetailItem(Icons.chat, 'Direct messaging with trainer'),
              _buildDetailItem(Icons.library_books, 'Nutrition guide included'),
              const SizedBox(height: 32),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Price', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGray)),
                            Text('\$${program['price']}', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.accent)),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddToCalendarModal(program, isBundle: false);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.accent, width: 2),
                          foregroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        ),
                        icon: const Icon(Icons.calendar_today, size: 20),
                        label: Text('Add to Calendar', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.accent)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPrograms = _filteredPrograms;
    final filteredBundles = _filteredBundles;
    final featuredPrograms = _featuredSectionPrograms;
    final newReleases = _newReleasesSectionPrograms;

    final hasActiveFilters = _selectedCategory != 'All' || _selectedDifficulty != 'All' || _selectedDuration != 'All' || _sortBy != 'Featured' || _showCertifiedOnly;
    final catalogCountLabel = hasActiveFilters ? '${filteredPrograms.length}' : (_browseProgramsTotal > 0 ? '$_browseProgramsTotal' : '${filteredPrograms.length}');

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
            final unreadCount = notificationController.unreadCount;
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
            IconButton(
              icon: Image.asset('assets/images/search-normal000.png', width: 20.w),
              onPressed: () {
                // TODO: Implement search
              },
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
        body: SingleChildScrollView(
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
              // BUNDLES — `GET /marketplace/bundles`
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
                      if (_sortBy != 'Featured') _buildFilterChip(_sortBy, () => setState(() => _sortBy = 'Featured')),
                      if (_selectedCategory != 'All') _buildFilterChip(_selectedCategory, () => setState(() => _selectedCategory = 'All')),
                      if (_selectedDifficulty != 'All') _buildFilterChip(_selectedDifficulty, () => setState(() => _selectedDifficulty = 'All')),
                      if (_selectedDuration != 'All') _buildFilterChip(_selectedDuration, () => setState(() => _selectedDuration = 'All')),
                      if (_showCertifiedOnly) _buildFilterChip('Certified', () => setState(() => _showCertifiedOnly = false)),
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
                        Text(_browsePrograms.isEmpty ? 'No programs available' : 'No programs found', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
                        SizedBox(height: 8.h),
                        if (_browsePrograms.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() {
                              _selectedCategory = 'All';
                              _selectedDifficulty = 'All';
                              _selectedDuration = 'All';
                              _sortBy = 'Featured';
                              _showCertifiedOnly = false;
                            }),
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
                          Image.asset('assets/images/avatar.png', height: 23.h),
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
                            ((program['rating'] as num?) ?? 0).toDouble().toStringAsFixed(1),
                            style: TextStyle(color: Colors.black, fontSize: 13.sp, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 5.w),
                          Icon(Icons.people, color: Colors.black, size: 13.sp),
                          SizedBox(width: 3.w),
                          Flexible(
                            child: Text(
                              '${_formatNumber((program['students'] as num?)?.toInt() ?? 0)}',
                              style: TextStyle(color: Colors.black, fontSize: 13.sp),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 8.h),

                      // Price and Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: SizedBox(
                              height: 25.h,
                              child: ElevatedButton.icon(
                                onPressed: () => _showAddToCalendarModal(program, isBundle: false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: AppColors.onAccent,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.h),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                                ),
                                label: Text(
                                  'Add to Calendar',
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.onAccent, fontSize: 10.sp, fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '\$${((program['price'] as num?) ?? 0).toDouble().toStringAsFixed(2)}',
                            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700, fontSize: 18.sp),
                          ),
                        ],
                      ),
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
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.65, crossAxisSpacing: 12.w, mainAxisSpacing: 12.h),
        itemCount: programs.length,
        itemBuilder: (context, index) {
          return _buildGridProgramCard(programs[index]);
        },
      ),
    );
  }

  Widget _buildGridProgramCard(Map<String, dynamic> program) {
    return SizedBox(
      height: 160.h,
      child: GestureDetector(
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
                      SizedBox(height: 15.h),

                      // Instructor with Certification Badge
                      Row(
                        children: [
                          Image.asset('assets/images/avatar.png', height: 23.h),
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
                            ((program['rating'] as num?) ?? 0).toDouble().toStringAsFixed(1),
                            style: TextStyle(color: Colors.black, fontSize: 13.sp, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 5.w),
                          Icon(Icons.people, color: Colors.black, size: 13.sp),
                          SizedBox(width: 3.w),
                          Flexible(
                            child: Text(
                              '${_formatNumber((program['students'] as num?)?.toInt() ?? 0)}',
                              style: TextStyle(color: Colors.black, fontSize: 13.sp),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 15.h),

                      // Price and Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: SizedBox(
                              height: 25.h,
                              child: ElevatedButton.icon(
                                onPressed: () => _showAddToCalendarModal(program, isBundle: false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: AppColors.onAccent,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.h),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                label: Text(
                                  'Add to Calendar',
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.onAccent, fontSize: 10.sp, fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '\$${((program['price'] as num?) ?? 0).toDouble().toStringAsFixed(2)}',
                            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700, fontSize: 18.sp),
                          ),
                        ],
                      ),
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

  Widget _buildBundleCard(Map<String, dynamic> bundle) {
    final programs = bundle['programs'] as List<Map<String, dynamic>>;
    final totalValue = ((bundle['totalValue'] as num?) ?? 0).toDouble();
    final bundlePrice = ((bundle['bundlePrice'] as num?) ?? 0).toDouble();

    // Calculate average rating from programs
    final avgRating = programs.isNotEmpty ? programs.map((p) => ((p['rating'] as num?) ?? 0).toDouble()).reduce((a, b) => a + b) / programs.length : 0.0;
    final totalRatings = programs.isNotEmpty ? programs.map((p) => ((p['students'] as num?) ?? 0).toInt()).reduce((a, b) => a + b) : 0;

    // Get primary trainer (first program's trainer)
    final primaryTrainer = programs.isNotEmpty ? programs[0]['trainer'] : 'Trainer';
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
                            // Profile Picture
                            Image.asset('assets/images/avatar.png', height: 20.h),

                            SizedBox(width: 6.w),
                            // Trainer Name
                            Text(
                              primaryTrainer.toString().replaceAll(' ', '\n'),
                              style: TextStyle(color: const Color(0xFF333333), fontSize: 12.sp, height: 1.0, fontWeight: FontWeight.w600),
                              maxLines: 2,
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
                            style: TextStyle(color: const Color(0xFF000000), fontWeight: FontWeight.w700, fontSize: 18.sp, height: 1.0),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        // Statistics Row
                        Row(
                          children: [
                            Text(
                              'Q3 Programs',
                              style: TextStyle(color: Colors.black, fontSize: 13.sp),
                            ),
                            SizedBox(width: 10.w),
                            Icon(Icons.star, color: AppColors.upcoming, size: 13.sp),
                            SizedBox(width: 3.w),
                            Text(
                              avgRating.toStringAsFixed(1),
                              style: TextStyle(color: Colors.black, fontSize: 13.sp, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(width: 10.w),
                            Icon(Icons.people, color: Colors.black, size: 13.sp),
                            SizedBox(width: 3.w),
                            Text(
                              '${_formatNumber(totalRatings)}',
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
                        SizedBox(
                          width: 130.w,
                          height: 30.h,
                          child: ElevatedButton(
                            onPressed: () => _showAddToCalendarModal(bundle, isBundle: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A1A1A), // Dark almost black
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              'Add to Calender',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp),
                            ),
                          ),
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
        Get.toNamed(AppRoutes.allBundles, arguments: _apiBundles);
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
                        Image.asset('assets/images/avatar.png', height: 23.h),
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
                          ((program['rating'] as num?) ?? 0).toDouble().toStringAsFixed(1),
                          style: TextStyle(color: Colors.black, fontSize: 13.sp, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(width: 5.w),
                        Icon(Icons.people, color: Colors.black, size: 13.sp),
                        SizedBox(width: 3.w),
                        Flexible(
                          child: Text(
                            '${_formatNumber((program['students'] as num?)?.toInt() ?? 0)}',
                            style: TextStyle(color: Colors.black, fontSize: 13.sp),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 6.h),

                    // Rating

                    // Price and Duration
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: SizedBox(
                            height: 25.h,
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddToCalendarModal(program, isBundle: false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: AppColors.onAccent,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 0.h),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              label: Text(
                                'Add to Calendar',
                                style: AppTextStyles.labelSmall.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w700, fontSize: 10.sp),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '\$${((program['price'] as num?) ?? 0).toDouble().toStringAsFixed(2)}',
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700, fontSize: 18.sp),
                        ),
                      ],
                    ),

                    // Add to Calendar Button
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
    // Create trainer data from program info
    final trainerData = {
      'id': program['trainer'].toString().toLowerCase().replaceAll(' ', '_'),
      'name': program['trainer'],
      'initials': program['trainerImage'],
      'bio': 'Certified personal trainer with years of experience helping clients achieve their fitness goals. Specializing in ${program['category']} and ${program['goal']}.',
      'specialties': [program['category'], program['goal'], 'Nutrition Coaching'],
      'yearsOfExperience': 8,
      'certified': program['certified'],
      'certifications': program['certified'] ? ['NASM Certified Personal Trainer', 'Precision Nutrition Level 1'] : null,
      'hourlyRate': 75.0,
      'rating': program['rating'],
      'totalReviews': 127,
      'students': program['students'],
      'activePrograms': 5,
      'completedPrograms': 12,
      'totalPrograms': 17,
    };

    Get.toNamed(AppRoutes.trainerProfile, arguments: trainerData);
  }
}
