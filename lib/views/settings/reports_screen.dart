import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/safety_center_controller.dart';
import 'package:get_right/models/report_block_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/safe_circle_network_avatar.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SafetyCenterController controller = Get.isRegistered<SafetyCenterController>() ? Get.find<SafetyCenterController>() : Get.put(SafetyCenterController());
  final ScrollController _scrollController = ScrollController();

  int _selectedTab = 0;
  String? _selectedStatus;

  String get _activeRefType => ReportRefType.tabOrder[_selectedTab];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchReports(showLoading: controller.reportsCacheEmpty);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      controller.loadMoreReports();
    }
  }

  Future<void> _fetchReports({bool showLoading = true}) {
    return controller.loadReports(
      type: _activeRefType,
      status: _selectedStatus,
      showLoading: showLoading,
      reset: true,
    );
  }

  void _onTabSelected(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    _fetchReports();
  }

  void _onStatusSelected(String? status) {
    if (_selectedStatus == status) return;
    setState(() => _selectedStatus = status);
    _fetchReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.15), width: 1),
            ),
            child: const Icon(Icons.chevron_left, color: AppColors.accent, size: 25),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Reports',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < ReportRefType.tabOrder.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    _tabChip(ReportRefType.tabOrder[i], i),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _statusChip(null, 'All'),
                  const SizedBox(width: 8),
                  for (final status in UserReportStatus.all) ...[
                    _statusChip(status, status),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => controller.reportsQuery.value = v,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.white,
                hintText: 'Search reports',
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, fontSize: 14),
                suffixIcon: const Icon(Icons.search, color: AppColors.primaryGrayDark),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: const BorderSide(color: Color(0xFFE6F0DA), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: const BorderSide(color: Color(0xFFE6F0DA), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: BorderSide(color: AppColors.accent, width: 1),
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final refType = _activeRefType;
              final isInitialLoad = controller.reportsLoading.value && controller.reports.isEmpty;

              if (isInitialLoad) {
                return const Center(child: CircularProgressIndicator(color: AppColors.accent));
              }

              if (controller.reportsError.value != null && controller.reports.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          controller.reportsError.value!,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _fetchReports, child: const Text('Retry')),
                      ],
                    ),
                  ),
                );
              }

              final items = controller.filteredReports;

              if (items.isEmpty) {
                return RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: () => _fetchReports(showLoading: false),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          _emptyMessageFor(refType),
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                color: AppColors.accent,
                onRefresh: () => _fetchReports(showLoading: false),
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: items.length + (controller.reportsLoadingMore.value ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                      );
                    }
                    return _reportCard(items[i], refType);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _emptyMessageFor(String refType) {
    switch (refType) {
      case ReportRefType.auth:
        return 'No reported users.';
      case ReportRefType.feeds:
        return 'No reported feeds.';
      case ReportRefType.programs:
        return 'No reported programs.';
      case ReportRefType.feedComment:
        return 'No reported feed comments.';
      default:
        return 'No reports.';
    }
  }

  IconData _iconForRefType(String refType) {
    switch (refType) {
      case ReportRefType.auth:
        return Icons.person_outline;
      case ReportRefType.feeds:
        return Icons.article_outlined;
      case ReportRefType.programs:
        return Icons.fitness_center_outlined;
      case ReportRefType.feedComment:
        return Icons.chat_bubble_outline;
      default:
        return Icons.flag_outlined;
    }
  }

  Widget _tabChip(String refType, int index) {
    final selected = _selectedTab == index;
    return GestureDetector(
      onTap: () => _onTabSelected(index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10),
        decoration: BoxDecoration(color: selected ? AppColors.accentVariant : Colors.transparent, borderRadius: BorderRadius.circular(50)),
        child: Text(
          ReportRefType.tabLabel(refType),
          style: AppTextStyles.bodyMedium.copyWith(
            color: selected ? AppColors.white : AppColors.primaryGrayDark,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String? status, String label) {
    final selected = _selectedStatus == status;
    return GestureDetector(
      onTap: () => _onStatusSelected(status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.12) : AppColors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: selected ? AppColors.accent : const Color(0xFFE6F0DA), width: 1),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? AppColors.accent : AppColors.primaryGrayDark,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (UserReportStatus.normalize(status)) {
      case UserReportStatus.pending:
        return AppColors.accent;
      case UserReportStatus.reviewed:
        return AppColors.completed;
      case UserReportStatus.dismissed:
        return AppColors.primaryGrayDark;
      default:
        return AppColors.primaryGrayDark;
    }
  }

  Widget _reportCard(ReportItem r, String refType) {
    final statusLabel = UserReportStatus.displayLabel(r.status);
    final statusColor = _statusColor(r.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FFE9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6F0DA), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SafeCircleNetworkAvatar(
              radius: 22,
              imageUrl: r.avatarUrl,
              backgroundColor: AppColors.accent.withValues(alpha: 0.15),
              fallback: Icon(_iconForRefType(refType), color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (r.creatorName != null && r.creatorName!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      r.creatorName!,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    r.subtitle,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primaryGray,
                      fontSize: 12.5,
                      fontStyle: r.hasAdditionalDetails ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _pill(r.reason, AppColors.accent),
                      _pill(statusLabel, statusColor),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
