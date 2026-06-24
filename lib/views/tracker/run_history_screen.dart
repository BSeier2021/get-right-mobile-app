import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:get_right/models/run_model.dart';
import 'package:get_right/models/planned_route_model.dart';
import 'package:get_right/repo/running_log_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/tracker/route_endpoint_labels.dart';

/// Run History Screen - Display all completed runs
class RunHistoryScreen extends StatefulWidget {
  const RunHistoryScreen({super.key});

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  final StorageService _storageService = Get.find<StorageService>();
  final RunningLogRepository _runningLogRepo = RunningLogRepository();
  List<RunModel> _runs = [];
  List<RunModel> _filteredRuns = [];
  List<PlannedRouteModel> _plannedRoutes = [];
  bool _isLoading = true;
  String? _loadError;
  String _selectedFilter = 'All';
  String _selectedSort = 'Date';

  static const int _pageSize = 10;

  final List<String> _filterOptions = ['All', 'Walk', 'Jog', 'Run', 'Bike'];
  final List<String> _sortOptions = ['Date', 'Distance', 'Duration', 'Pace'];

  @override
  void initState() {
    super.initState();
    _loadRuns();
  }

  Future<void> _loadRuns() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final routesPage = await _runningLogRepo.fetchPlannedRoutes(page: 1, limit: _pageSize);
    final logsPage = await _runningLogRepo.fetchRunningLogs(page: 1, limit: _pageSize);

    var runs = logsPage.runs;
    var routes = routesPage.routes;
    String? loadError;

    if (logsPage.syncFailed || routesPage.syncFailed) {
      loadError = logsPage.syncError ?? routesPage.syncError ?? 'Could not load history from server';
      if (runs.isEmpty) {
        runs = await _storageService.getRuns();
      }
      if (routes.isEmpty) {
        final localRoutes = await _storageService.getPlannedRoutes();
        localRoutes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        routes = localRoutes;
      }
    }

    routes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;
    setState(() {
      _runs = runs;
      _plannedRoutes = routes;
      _loadError = loadError;
      _applyFiltersAndSort();
      _isLoading = false;
    });

    if (loadError != null && mounted) {
      Get.snackbar(
        'Sync issue',
        loadError,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Preview saved route on map, then optionally start a run with it.
  Future<void> _showSavedRoutePreview(PlannedRouteModel route) async {
    var resolvedRoute = route;
    if (WorkoutRepository.isValidMongoId(route.id)) {
      _showLoadingDialog();
      try {
        resolvedRoute = await _runningLogRepo.fetchPlannedRouteDetail(route.id);
      } catch (e) {
        _closeLoadingDialog();
        Get.snackbar(
          'Could not load route',
          e.toString().replaceFirst('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.onError,
        );
        return;
      }
      _closeLoadingDialog();
    }

    if (!mounted) return;
    if (resolvedRoute.routePoints.isEmpty) {
      Get.snackbar(
        'No route data',
        'This saved route has no points to display on the map.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SavedRoutePreviewSheet(
        route: resolvedRoute,
        onStartRun: () {
          Navigator.pop(ctx);
          _startRunWithRoute(resolvedRoute, skipFetch: true);
        },
      ),
    );
  }

  /// Start a run with a saved planned route (fetches full route from API when possible).
  Future<void> _startRunWithRoute(PlannedRouteModel route, {bool skipFetch = false}) async {
    var resolvedRoute = route;
    if (!skipFetch && WorkoutRepository.isValidMongoId(route.id)) {
      _showLoadingDialog();
      try {
        resolvedRoute = await _runningLogRepo.fetchPlannedRouteDetail(route.id);
      } catch (e) {
        _closeLoadingDialog();
        Get.snackbar(
          'Could not load route',
          e.toString().replaceFirst('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.onError,
        );
        return;
      }
      _closeLoadingDialog();
    }

    Get.toNamed(AppRoutes.activityTypeSelection, arguments: {'plannedRoute': resolvedRoute});
  }

  /// Open completed run detail (fetches full log from API when possible).
  Future<void> _openRunDetail(RunModel run) async {
    var detail = run;
    if (WorkoutRepository.isValidMongoId(run.id)) {
      _showLoadingDialog();
      try {
        detail = await _runningLogRepo.fetchRunningLogDetail(run.id);
      } catch (e) {
        _closeLoadingDialog();
        Get.snackbar(
          'Could not load run',
          e.toString().replaceFirst('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.onError,
        );
        return;
      }
      _closeLoadingDialog();
    }

    Get.toNamed(AppRoutes.runDetail, arguments: detail);
  }

  void _showLoadingDialog() {
    if (Get.isDialogOpen == true) return;
    Get.dialog(const Center(child: CircularProgressIndicator(color: AppColors.accent)), barrierDismissible: false);
  }

  void _closeLoadingDialog() {
    if (Get.isDialogOpen == true) Get.back();
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
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.accent, size: 18),
          ).paddingAll(8),
        ),
        title: Text('History', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.accent),
            onPressed: _isLoading ? null : _loadRuns,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _runs.isEmpty && _plannedRoutes.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: AppColors.accent,
              onRefresh: _loadRuns,
              child: Column(
                children: [
                  if (_loadError != null) _buildSyncBanner(),
                  if (_filteredRuns.isEmpty && _runs.isNotEmpty) _buildNoResultsState(),
                  if (_filteredRuns.isNotEmpty) _buildStatsHeader(),
                  if (_filteredRuns.isNotEmpty) _buildFilterChips(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_plannedRoutes.isNotEmpty) ...[
                            _buildSectionHeader('Saved Routes', Icons.route),
                            ..._plannedRoutes.map((route) => _buildPlannedRouteCard(route)),
                            const SizedBox(height: 24),
                          ],
                          if (_filteredRuns.isNotEmpty) ...[_buildSectionHeader('Completed Runs', Icons.directions_run), _buildRunList()],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Build filter chips
  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showFilterMenu,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset('assets/icons/filter.svg', color: AppColors.white, width: 16, height: 16),
                  const SizedBox(width: 6),
                  Text(
                    _selectedFilter,
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showFilterMenu,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryGray.withOpacity(0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort_rounded, size: 16, color: AppColors.primaryGrayDark),
                  const SizedBox(width: 6),
                  Text(
                    _selectedSort,
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Text('${_filteredRuns.length} runs', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
        ],
      ),
    );
  }

  Widget _buildSyncBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Showing cached data — pull down to retry', style: AppTextStyles.labelSmall.copyWith(color: AppColors.error)),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('${_filteredRuns.length}', 'Total Runs'),
          Container(width: 1, height: 36, color: AppColors.primaryGray.withOpacity(0.25)),
          _buildStatItem('${(totalDistance / 1000).toStringAsFixed(2)} km', 'Total Distance'),
          Container(width: 1, height: 36, color: AppColors.primaryGray.withOpacity(0.25)),
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
    final timeFormat = DateFormat('h:mm a');
    final createdAt = route.createdAt.toLocal();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSavedRoutePreview(route),
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
                      decoration: BoxDecoration(color: const Color(0xFFF6EAFE), shape: BoxShape.circle),
                      child: const Icon(Icons.sports_gymnastics_rounded, color: Color(0xFF7C49E2), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Planned Route',
                            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(dateFormat.format(createdAt), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 12)),
                          Text(timeFormat.format(createdAt), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 12)),
                        ],
                      ),
                    ),
                    _startPill(),
                  ],
                ),
                const SizedBox(height: 12),
                if (route.routePoints.isNotEmpty)
                  RouteEndpointLabels(
                    start: route.routePoints.first,
                    end: route.routePoints.length > 1 ? route.routePoints.last : route.routePoints.first,
                    startName: route.startPointName,
                    endName: route.endPointName,
                    compact: true,
                  ),
                const SizedBox(height: 12),
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

  Widget _startPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(22)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, color: AppColors.onAccent, size: 18),
          const SizedBox(width: 4),
          Text(
            'Start',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.bold),
          ),
        ],
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
    final startTime = run.startTime.toLocal();
    final endTime = run.endTime.toLocal();

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
            onTap: () => _openRunDetail(run),
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
                                Text(
                                  _formatDistanceKm(run.distanceMeters),
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                                const SizedBox(width: 8),
                                Text(dateFormat.format(startTime), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${timeFormat.format(startTime)} - ${timeFormat.format(endTime)}',
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.primaryGray),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (run.routePoints != null && run.routePoints!.isNotEmpty)
                    RouteEndpointLabels(
                      start: LatLng(run.routePoints!.first.latitude, run.routePoints!.first.longitude),
                      end: LatLng(run.routePoints!.last.latitude, run.routePoints!.last.longitude),
                      startName: run.startPointName,
                      endName: run.endPointName,
                      compact: true,
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildRunStat(Icons.straighten_rounded, _formatDistanceKm(run.distanceMeters)),
                      _buildRunStat(Icons.timer_rounded, _formatDuration(run.duration)),
                      if (_formatPace(run.averagePace) != null) _buildRunStat(Icons.speed_rounded, _formatPace(run.averagePace)!),
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

  String _formatDistanceKm(double meters) {
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String? _formatPace(double? paceMinPerKm) {
    if (paceMinPerKm == null || paceMinPerKm <= 0) return null;
    final minutes = paceMinPerKm.floor();
    final seconds = ((paceMinPerKm - minutes) * 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}/km';
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

class _SavedRoutePreviewSheet extends StatelessWidget {
  const _SavedRoutePreviewSheet({required this.route, required this.onStartRun});

  final PlannedRouteModel route;
  final VoidCallback onStartRun;

  LatLng _centerFor(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }
    return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  @override
  Widget build(BuildContext context) {
    final points = route.routePoints;
    final start = points.first;
    final end = points.length > 1 ? points.last : start;
    final dateFormat = DateFormat('MMM d, yyyy');
    final createdAt = route.createdAt.toLocal();

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.4), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF6EAFE), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.route, color: Color(0xFF7C49E2), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(route.name, style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        '${dateFormat.format(createdAt)} • ${(route.estimatedDistance / 1000).toStringAsFixed(2)} km • ${points.length} points',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: RouteEndpointLabels(
              start: start,
              end: end,
              startName: route.startPointName,
              endName: route.endPointName,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: _centerFor(points), zoom: 14),
                  onMapCreated: (controller) {
                    if (points.length < 2) return;
                    var minLat = points.first.latitude;
                    var maxLat = points.first.latitude;
                    var minLng = points.first.longitude;
                    var maxLng = points.first.longitude;
                    for (final point in points) {
                      minLat = minLat < point.latitude ? minLat : point.latitude;
                      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
                      minLng = minLng < point.longitude ? minLng : point.longitude;
                      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
                    }
                    controller.animateCamera(
                      CameraUpdate.newLatLngBounds(
                        LatLngBounds(
                          southwest: LatLng(minLat, minLng),
                          northeast: LatLng(maxLat, maxLng),
                        ),
                        48,
                      ),
                    );
                  },
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('saved_route'),
                      points: points,
                      color: const Color(0xFF7C49E2),
                      width: 5,
                      geodesic: true,
                    ),
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('start'),
                      position: start,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                      infoWindow: InfoWindow(title: 'Start', snippet: route.startPointName),
                    ),
                    if (points.length > 1)
                      Marker(
                        markerId: const MarkerId('end'),
                        position: end,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        infoWindow: InfoWindow(title: 'End', snippet: route.endPointName),
                      ),
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onStartRun,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('Start Run With This Route', style: AppTextStyles.buttonLarge),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
