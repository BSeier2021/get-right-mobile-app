import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/workout_journal_model.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:intl/intl.dart';

enum _CompletedWorkoutRange { last30Days, last90Days, last6Months, allTime }

class CompletedWorkoutsScreen extends StatefulWidget {
  const CompletedWorkoutsScreen({super.key});

  @override
  State<CompletedWorkoutsScreen> createState() => _CompletedWorkoutsScreenState();
}

class _CompletedWorkoutsScreenState extends State<CompletedWorkoutsScreen> {
  static const int _pageSize = 10;

  final WorkoutRepository _repo = WorkoutRepository();
  final List<WorkoutJournalModel> _entries = [];
  final ScrollController _scrollController = ScrollController();

  _CompletedWorkoutRange _range = _CompletedWorkoutRange.last90Days;
  bool _loading = true;
  bool _loadingMore = false;
  String? _loadError;
  int _page = 1;
  bool _hasMore = false;
  int _totalDocs = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  (DateTime?, DateTime?) _dateBoundsForRange(_CompletedWorkoutRange range) {
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    switch (range) {
      case _CompletedWorkoutRange.last30Days:
        return (end.subtract(const Duration(days: 30)), end);
      case _CompletedWorkoutRange.last90Days:
        return (end.subtract(const Duration(days: 90)), end);
      case _CompletedWorkoutRange.last6Months:
        return (end.subtract(const Duration(days: 182)), end);
      case _CompletedWorkoutRange.allTime:
        return (null, null);
    }
  }

  String _rangeLabel(_CompletedWorkoutRange range) {
    return switch (range) {
      _CompletedWorkoutRange.last30Days => '30 days',
      _CompletedWorkoutRange.last90Days => '90 days',
      _CompletedWorkoutRange.last6Months => '6 months',
      _CompletedWorkoutRange.allTime => 'All time',
    };
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _page = 1;
      _hasMore = false;
      _totalDocs = 0;
      _entries.clear();
    });

    try {
      final bounds = _dateBoundsForRange(_range);
      final page = await _repo.fetchCompletedWorkoutJournals(
        page: 1,
        limit: _pageSize,
        dateFrom: bounds.$1,
        dateTo: bounds.$2,
      );
      if (!mounted) return;
      if (page.syncFailed) {
        throw Exception(page.syncError ?? 'Could not load completed workouts');
      }
      setState(() {
        _entries.addAll(page.entries);
        _hasMore = page.hasMore;
        _totalDocs = page.totalDocs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final bounds = _dateBoundsForRange(_range);
      final page = await _repo.fetchCompletedWorkoutJournals(
        page: nextPage,
        limit: _pageSize,
        dateFrom: bounds.$1,
        dateTo: bounds.$2,
      );
      if (!mounted) return;
      setState(() {
        _entries.addAll(page.entries);
        _hasMore = page.hasMore;
        _totalDocs = page.totalDocs > 0 ? page.totalDocs : _totalDocs;
        _page = nextPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onRangeChanged(_CompletedWorkoutRange range) {
    if (_range == range) return;
    setState(() => _range = range);
    _loadInitial();
  }

  void _openOnCalendar(WorkoutJournalModel entry) {
    final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
    Get.toNamed(AppRoutes.planner, arguments: {'selectedDate': day.toIso8601String()});
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '—';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  int _exerciseCount(WorkoutJournalModel entry) => entry.allExercises.length;

  int _setCount(WorkoutJournalModel entry) {
    return entry.allExercises.fold<int>(0, (sum, ex) => sum + ex.sets.length);
  }

  String _exercisePreview(WorkoutJournalModel entry) {
    final names = entry.allExercises.map((e) => e.exerciseName.trim()).where((n) => n.isNotEmpty).take(3).toList();
    if (names.isEmpty) return 'No exercises listed';
    final extra = entry.allExercises.length - names.length;
    if (extra > 0) return '${names.join(', ')} +$extra more';
    return names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
        ),
        title: Text(
          'Completed Workouts',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRangeFilters(),
          if (_totalDocs > 0 && !_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '$_totalDocs completed workout${_totalDocs == 1 ? '' : 's'}',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildRangeFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: _CompletedWorkoutRange.values.map((range) {
          final selected = _range == range;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_rangeLabel(range)),
              selected: selected,
              onSelected: _loading ? null : (_) => _onRangeChanged(range),
              selectedColor: AppColors.accent,
              labelStyle: AppTextStyles.labelSmall.copyWith(
                color: selected ? Colors.white : AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: Colors.white,
              side: BorderSide(color: AppColors.accent.withValues(alpha: 0.25)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_loadError!, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadInitial, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fitness_center_outlined, size: 64, color: AppColors.primaryGray.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(
                'No completed workouts',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Finish a workout in your journal to see it here.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadInitial,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _entries.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _entries.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
            );
          }
          return _buildWorkoutCard(_entries[index]);
        },
      ),
    );
  }

  Widget _buildWorkoutCard(WorkoutJournalModel entry) {
    final completedAt = entry.completedAt ?? entry.date;
    final dateLabel = DateFormat('EEE, MMM d, yyyy').format(completedAt.toLocal());
    final timeLabel = DateFormat('h:mm a').format(completedAt.toLocal());

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openOnCalendar(entry),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.check_circle_outline, color: AppColors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dateLabel, style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('Completed · $timeLabel', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.primaryGray.withValues(alpha: 0.7)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _statChip(Icons.timer_outlined, _formatDuration(entry.durationSeconds)),
                  const SizedBox(width: 8),
                  _statChip(Icons.fitness_center, '${_exerciseCount(entry)} exercises'),
                  const SizedBox(width: 8),
                  _statChip(Icons.repeat, '${_setCount(entry)} sets'),
                ],
              ),
              if (entry.caloriesBurned != null && entry.caloriesBurned! > 0) ...[
                const SizedBox(height: 8),
                _statChip(Icons.local_fire_department_outlined, '${entry.caloriesBurned} cal'),
              ],
              const SizedBox(height: 12),
              Text(
                _exercisePreview(entry),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, height: 1.35),
              ),
              if (entry.notes != null && entry.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  entry.notes!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface.withValues(alpha: 0.75), fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.primaryGrayLight.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
