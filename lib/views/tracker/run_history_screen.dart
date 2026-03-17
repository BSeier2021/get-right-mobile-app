import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:get_right/models/run_model.dart';
import 'package:get_right/models/planned_route_model.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Run History Screen - Display all completed runs
class RunHistoryScreen extends StatefulWidget {
  const RunHistoryScreen({super.key});

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  final StorageService _storageService = Get.find<StorageService>();
  List<RunModel> _runs = [];
  List<RunModel> _filteredRuns = [];
  List<PlannedRouteModel> _plannedRoutes = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  String _selectedSort = 'Date';

  final List<String> _filterOptions = ['All', 'Walk', 'Jog', 'Run', 'Bike'];
  final List<String> _sortOptions = ['Date', 'Distance', 'Duration', 'Pace'];

  @override
  void initState() {
    super.initState();
    _loadRuns();
  }

  Future<void> _loadRuns() async {
    setState(() => _isLoading = true);
    final runs = await _storageService.getRuns();
    final routes = await _storageService.getPlannedRoutes();
    // Sort routes by creation date (newest first)
    routes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() {
      _runs = runs;
      _plannedRoutes = routes;
      _applyFiltersAndSort();
      _isLoading = false;
    });
  }

  /// Start a run with a saved planned route
  void _startRunWithRoute(PlannedRouteModel route) {
    // Navigate to activity type selection with the route
    Get.toNamed(AppRoutes.activityTypeSelection, arguments: {'plannedRoute': route});
  }

  void _applyFiltersAndSort() {
    // Apply filter
    if (_selectedFilter == 'All') {
      _filteredRuns = List.from(_runs);
    } else {
      _filteredRuns = _runs.where((run) => run.activityType.toLowerCase() == _selectedFilter.toLowerCase()).toList();
    }

    // Apply sort
    switch (_selectedSort) {
      case 'Date':
        _filteredRuns.sort((a, b) => b.startTime.compareTo(a.startTime));
        break;
      case 'Distance':
        _filteredRuns.sort((a, b) => b.distanceMeters.compareTo(a.distanceMeters));
        break;
      case 'Duration':
        _filteredRuns.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case 'Pace':
        _filteredRuns.sort((a, b) {
          final paceA = a.averagePace ?? double.infinity;
          final paceB = b.averagePace ?? double.infinity;
          return paceA.compareTo(paceB);
        });
        break;
    }
  }

  void _showFilterMenu() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter & Sort',
              style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text('Activity Type', style: AppTextStyles.labelLarge.copyWith(color: AppColors.surface)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _filterOptions.map((filter) {
                final isSelected = _selectedFilter == filter;
                return ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = filter;
                      _applyFiltersAndSort();
                    });
                    Get.back();
                  },
                  selectedColor: AppColors.accent.withOpacity(0.2),
                  backgroundColor: isSelected ? null : Colors.white,
                  labelStyle: TextStyle(color: isSelected ? AppColors.accent : AppColors.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  side: BorderSide(color: isSelected ? AppColors.accent : AppColors.primaryGray, width: isSelected ? 2 : 1),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text('Sort By', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryGray)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _sortOptions.map((sort) {
                final isSelected = _selectedSort == sort;
                return ChoiceChip(
                  label: Text(sort),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedSort = sort;
                      _applyFiltersAndSort();
                    });
                    Get.back();
                  },
                  selectedColor: AppColors.accent.withOpacity(0.2),
                  backgroundColor: isSelected ? null : Colors.white,
                  labelStyle: TextStyle(color: isSelected ? AppColors.accent : AppColors.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  side: BorderSide(color: isSelected ? AppColors.accent : AppColors.primaryGray, width: isSelected ? 2 : 1),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ).paddingAll(8),
        ),
        title: Text('Run History', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: AppColors.onPrimary),
            onPressed: _showFilterMenu,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _runs.isEmpty && _plannedRoutes.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                if (_filteredRuns.isEmpty && _runs.isNotEmpty) _buildNoResultsState(),
                if (_filteredRuns.isNotEmpty) _buildStatsHeader(),
                if (_filteredRuns.isNotEmpty) _buildFilterChips(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Planned Routes Section
                        if (_plannedRoutes.isNotEmpty) ...[
                          _buildSectionHeader('Saved Routes', Icons.route),
                          ..._plannedRoutes.map((route) => _buildPlannedRouteCard(route)),
                          const SizedBox(height: 24),
                        ],
                        // Completed Runs Section
                        if (_filteredRuns.isNotEmpty) ...[_buildSectionHeader('Completed Runs', Icons.directions_run), _buildRunList()],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Build filter chips
  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_alt_outlined, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  _selectedFilter,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  _selectedSort,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text('${_filteredRuns.length} runs', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
        ],
      ),
    );
  }

  /// Build no results state
  Widget _buildNoResultsState() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.search_off_rounded, size: 50, color: AppColors.primaryGray),
              ),
              const SizedBox(height: 24),
              Text(
                'No Results',
                style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'No runs match your current filters',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedFilter = 'All';
                    _applyFiltersAndSort();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text('Clear Filters', style: AppTextStyles.buttonLarge),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build stats header
  Widget _buildStatsHeader() {
    final totalDistance = _filteredRuns.fold(0.0, (sum, run) => sum + run.distanceMeters);
    final totalDuration = _filteredRuns.fold(Duration.zero, (sum, run) => sum + run.duration);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.15), AppColors.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('${_filteredRuns.length}', 'Total Runs'),
          Container(width: 1, height: 40, color: AppColors.primaryGray.withOpacity(0.3)),
          _buildStatItem('${(totalDistance / 1000).toStringAsFixed(1)} km', 'Total Distance'),
          Container(width: 1, height: 40, color: AppColors.primaryGray.withOpacity(0.3)),
          _buildStatItem(_formatTotalDuration(totalDuration), 'Total Time'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 11)),
      ],
    );
  }

  /// Build section header
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Build planned route card
  Widget _buildPlannedRouteCard(PlannedRouteModel route) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 2),
        boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _startRunWithRoute(route),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.route, color: AppColors.accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.name,
                            style: AppTextStyles.titleSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(dateFormat.format(route.createdAt), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded, color: AppColors.accent, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'Start',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildRouteStat(Icons.straighten_rounded, '${(route.estimatedDistance / 1000).toStringAsFixed(2)} km'),
                    _buildRouteStat(Icons.place, '${route.routePoints.length} points'),
                    if (route.scheduledDate != null) _buildRouteStat(Icons.calendar_today, dateFormat.format(route.scheduledDate!)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 16),
        const SizedBox(width: 4),
        Text(
          value,
          style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// Build run list
  Widget _buildRunList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredRuns.length,
      itemBuilder: (context, index) {
        return _buildRunCard(_filteredRuns[index], index);
      },
    );
  }

  /// Build individual run card
  Widget _buildRunCard(RunModel run, int index) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryGray.withOpacity(0.2), width: 1),
          boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Get.toNamed(AppRoutes.runDetail, arguments: run),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: _getActivityColor(run.activityType).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: Icon(_getActivityIcon(run.activityType), color: _getActivityColor(run.activityType), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  run.activityType,
                                  style: AppTextStyles.titleSmall.copyWith(color: _getActivityColor(run.activityType), fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Text(dateFormat.format(run.startTime), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${timeFormat.format(run.startTime)} - ${timeFormat.format(run.endTime)}',
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.primaryGray),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildRunStat(Icons.straighten_rounded, '${(run.distanceMeters / 1000).toStringAsFixed(2)} km'),
                      _buildRunStat(Icons.timer_rounded, _formatDuration(run.duration)),
                      if (run.averagePace != null) _buildRunStat(Icons.speed_rounded, '${run.averagePace!.toStringAsFixed(1)}\'/km'),
                      if (run.caloriesBurned != null) _buildRunStat(Icons.local_fire_department_rounded, '${run.caloriesBurned} cal'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRunStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 16),
        const SizedBox(width: 4),
        Text(
          value,
          style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.directions_run_rounded, size: 60, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            Text(
              'No Runs Yet',
              style: AppTextStyles.headlineMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Start your first run to see it here!',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Start Running', style: AppTextStyles.buttonLarge),
            ),
          ],
        ),
      ),
    );
  }

  /// Format duration
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }

  /// Format total duration
  String _formatTotalDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Get activity color
  Color _getActivityColor(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walk':
        return const Color(0xFF4CAF50);
      case 'jog':
        return const Color(0xFFFF9800);
      case 'run':
        return const Color(0xFFF44336);
      case 'bike':
        return const Color(0xFF2196F3);
      default:
        return AppColors.accent;
    }
  }

  /// Get activity icon
  IconData _getActivityIcon(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walk':
        return Icons.directions_walk;
      case 'jog':
        return Icons.directions_walk_outlined;
      case 'run':
        return Icons.directions_run;
      case 'bike':
        return Icons.directions_bike;
      default:
        return Icons.directions_run;
    }
  }
}
