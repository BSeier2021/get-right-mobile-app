import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/models/customer_progress.dart';
import 'package:get_right/repo/progress_repo.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:intl/intl.dart';

/// Progress Tracking Screen — `GET /customer/profile/progress`.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ProgressRepository _repo = ProgressRepository();

  CustomerProgress? _progress;
  bool _loading = true;
  String? _error;

  late DateTime _selectedMonth;
  late int _selectedWeekIndex;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedWeekIndex = _weekIndexForDay(now.day);
    _loadProgress();
  }

  int _weekIndexForDay(int day) => (day - 1) ~/ 7;

  int _weekCountInMonth(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return _weekIndexForDay(lastDay) + 1;
  }

  (DateTime start, DateTime end) _selectedWeekRange() {
    final startDay = _selectedWeekIndex * 7 + 1;
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final endDay = (startDay + 6).clamp(1, lastDayOfMonth);
    return (
      DateTime(_selectedMonth.year, _selectedMonth.month, startDay),
      DateTime(_selectedMonth.year, _selectedMonth.month, endDay),
    );
  }

  bool get _isCurrentWeek {
    final now = DateTime.now();
    return _selectedMonth.year == now.year &&
        _selectedMonth.month == now.month &&
        _selectedWeekIndex == _weekIndexForDay(now.day);
  }

  String get _periodLabel {
    final (start, end) = _selectedWeekRange();
    final sameMonth = start.month == end.month;
    if (sameMonth) {
      return '${DateFormat('MMM d').format(start)} – ${DateFormat('d, yyyy').format(end)}';
    }
    return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
  }

  Future<void> _loadProgress() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (start, end) = _selectedWeekRange();
      final progress = await _repo.fetchCustomerProgress(startDate: start, endDate: end);
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month + 1, 0))) return;

    setState(() {
      _selectedMonth = next;
      final maxWeek = _weekCountInMonth(_selectedMonth) - 1;
      if (_selectedWeekIndex > maxWeek) _selectedWeekIndex = maxWeek;
    });
    _loadProgress();
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year, now.month + 1, 0),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month, 1);
      final maxWeek = _weekCountInMonth(_selectedMonth) - 1;
      if (_selectedWeekIndex > maxWeek) _selectedWeekIndex = maxWeek;
    });
    _loadProgress();
  }

  void _selectWeek(int index) {
    if (index == _selectedWeekIndex) return;
    setState(() => _selectedWeekIndex = index);
    _loadProgress();
  }

  CustomerProgressSummary get _summary => _progress?.summary ?? CustomerProgressSummary.empty;

  String _formatDistance(double km) {
    if (km % 1 == 0) return '${km.toInt()} km';
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatWeekCount(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final weekCount = _weekCountInMonth(_selectedMonth);
    final canGoNextMonth = _selectedMonth.year < DateTime.now().year ||
        (_selectedMonth.year == DateTime.now().year && _selectedMonth.month < DateTime.now().month);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        centerTitle: true,
        elevation: 0,
        title: Text('Progress', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _loadProgress,
        child: _loading && _progress == null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator(color: AppColors.accent)),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildPeriodFilter(weekCount: weekCount, canGoNextMonth: canGoNextMonth),
                  if (_loading) ...[
                    const SizedBox(height: 16),
                    const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                          ),
                          TextButton(onPressed: _loadProgress, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          asset: 'assets/images/Vector.png',
                          iconBg: const Color(0xFFFFF3E0),
                          value: '${_summary.totalWorkouts}',
                          valueColor: const Color(0xFFF57C00),
                          label: 'Total Workouts',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          asset: 'assets/images/calendar-222.png',
                          iconBg: const Color(0xFFE3F2FD),
                          value: _formatWeekCount(_summary.workoutsThisWeek),
                          valueColor: const Color(0xFF1976D2),
                          label: _isCurrentWeek ? 'This Week' : 'Workouts',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          asset: 'assets/images/running.png',
                          iconBg: const Color.fromARGB(43, 46, 125, 50),
                          value: _formatDistance(_summary.totalDistanceKm),
                          valueColor: const Color(0xFF4CAF50),
                          label: 'Total Distance',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          asset: 'assets/images/Subtract (2).png',
                          iconBg: const Color(0xFFFCE4EC),
                          value: '${_summary.activeDays}',
                          valueColor: const Color(0xFF8E24AA),
                          label: 'Active Days',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Weekly Activity',
                    style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onBackground),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _periodLabel,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                  ),
                  const SizedBox(height: 12),
                  _buildWeeklyActivityChart(_progress?.weeklyActivity ?? const []),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  Widget _buildPeriodFilter({required int weekCount, required bool canGoNextMonth}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCDE7C8)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Time Period',
            style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _filterIconButton(
                icon: Icons.chevron_left,
                onPressed: () => _shiftMonth(-1),
              ),
              Expanded(
                child: InkWell(
                  onTap: _pickMonth,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          DateFormat.yMMMM().format(_selectedMonth),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.accent),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to change month',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _filterIconButton(
                icon: Icons.chevron_right,
                onPressed: canGoNextMonth ? () => _shiftMonth(1) : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Week',
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < weekCount; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _weekChip(index: i),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterIconButton({required IconData icon, VoidCallback? onPressed}) {
    return Material(
      color: AppColors.accent.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: onPressed == null ? AppColors.primaryGray : AppColors.accent, size: 22),
        ),
      ),
    );
  }

  Widget _weekChip({required int index}) {
    final selected = index == _selectedWeekIndex;
    final startDay = index * 7 + 1;
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final endDay = (startDay + 6).clamp(1, lastDayOfMonth);
    final label = startDay == endDay ? '$startDay' : '$startDay–$endDay';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectWeek(index),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.accent : AppColors.accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Text(
                'Week ${index + 1}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: selected ? AppColors.onAccent : AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: selected ? AppColors.onAccent.withValues(alpha: 0.85) : AppColors.primaryGray,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyActivityChart(List<WeeklyActivityDay> activity) {
    if (activity.isEmpty) {
      return Container(
        height: 160,
        padding: const EdgeInsets.all(20),
        decoration: _chartDecoration,
        child: Center(
          child: Text(
            'No activity recorded for this period',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
          ),
        ),
      );
    }

    final maxMinutes = activity.fold<int>(0, (max, day) => day.minutes > max ? day.minutes : max);
    final chartMax = maxMinutes <= 0 ? 1 : maxMinutes;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: _chartDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < activity.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _weeklyBar(
                      day: activity[i],
                      maxMinutes: chartMax,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < activity.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activity[i].day,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _weeklyBar({required WeeklyActivityDay day, required int maxMinutes}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const labelBlockHeight = 18.0;
        final hasActivity = day.minutes > 0;
        final usableHeight = (constraints.maxHeight - (hasActivity ? labelBlockHeight : 0)).clamp(0.0, constraints.maxHeight);
        final fraction = maxMinutes > 0 ? day.minutes / maxMinutes : 0.0;
        final barHeight = hasActivity ? (usableHeight * fraction).clamp(8.0, usableHeight) : 0.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (hasActivity)
              Text(
                '${day.minutes}m',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 10),
              ),
            if (hasActivity) const SizedBox(height: 4),
            Container(
              height: barHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        );
      },
    );
  }

  BoxDecoration get _chartDecoration => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCDE7C8), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      );

  Widget _statCard({
    required String asset,
    required Color iconBg,
    required String value,
    required Color valueColor,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCDE7C8), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => Icon(Icons.fitness_center, color: valueColor, size: 22),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(color: valueColor, fontWeight: FontWeight.bold, fontSize: 22.sp),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
