import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/models/customer_progress.dart';
import 'package:get_right/repo/progress_repo.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final progress = await _repo.fetchCustomerProgress();
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

  CustomerProgressSummary get _summary => _progress?.summary ?? CustomerProgressSummary.empty;

  String _formatDistance(double km) {
    if (km % 1 == 0) return '${km.toInt()} km';
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatWeekCount(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
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
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
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
                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withOpacity(0.25)),
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
                          label: 'This Week',
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
                  const SizedBox(height: 12),
                  _buildWeeklyActivityChart(_progress?.weeklyActivity ?? const []),
                  const SizedBox(height: 24),
                ],
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
            'No activity recorded this week',
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
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
