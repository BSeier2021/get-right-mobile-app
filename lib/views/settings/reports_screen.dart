import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/safety_center_controller.dart';
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
  int _selectedTab = 0; // 0 Users, 1 Posts, 2 Programs, 3 FeedComment

  static const List<({String label, ReportType type})> _tabs = [
    (label: 'Users', type: ReportType.user),
    (label: 'Posts', type: ReportType.post),
    (label: 'Programs', type: ReportType.programs),
    (label: 'Feed Comment', type: ReportType.feedComment),
  ];

  ReportType get _activeReportType => _tabs[_selectedTab].type;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadReports(showLoading: controller.reportsCacheEmpty);
    });
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
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withOpacity(0.15), width: 1),
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
          // ── Pill tab selector ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++) ...[if (i > 0) const SizedBox(width: 8), _tabChip(_tabs[i].label, i)],
                ],
              ),
            ),
          ),

          // ── Search bar ────────────────────────────────────────
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

          // ── Report list ───────────────────────────────────────
          Expanded(
            child: Obx(() {
              if (controller.reportsLoading.value && controller.reportsCacheEmpty) {
                return const Center(child: CircularProgressIndicator(color: AppColors.accent));
              }

              if (controller.reportsError.value != null && controller.reportsCacheEmpty) {
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
                        ElevatedButton(onPressed: () => controller.loadReports(), child: const Text('Retry')),
                      ],
                    ),
                  ),
                );
              }

              final type = _activeReportType;
              final items = controller.filteredReportsFor(type);

              if (items.isEmpty) {
                return RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: () => controller.loadReports(showLoading: false),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Center(
                        child: Text(
                          _emptyMessageFor(type),
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
                onRefresh: () => controller.loadReports(showLoading: false),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _reportCard(items[i], type),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _emptyMessageFor(ReportType type) {
    switch (type) {
      case ReportType.user:
        return 'No reported users.';
      case ReportType.post:
        return 'No reported posts.';
      case ReportType.programs:
        return 'No reported programs.';
      case ReportType.feedComment:
        return 'No reported feed comments.';
    }
  }

  IconData _iconForReportType(ReportType type) {
    switch (type) {
      case ReportType.user:
        return Icons.person_outline;
      case ReportType.post:
        return Icons.article_outlined;
      case ReportType.programs:
        return Icons.fitness_center_outlined;
      case ReportType.feedComment:
        return Icons.chat_bubble_outline;
    }
  }

  // ── Pill tab chip ──────────────────────────────────────────
  Widget _tabChip(String label, int index) {
    final selected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 10),
        decoration: BoxDecoration(color: selected ? AppColors.accentVariant : Colors.transparent, borderRadius: BorderRadius.circular(50)),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: selected ? AppColors.white : AppColors.primaryGrayDark,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ── Report card ────────────────────────────────────────────
  Widget _reportCard(ReportItem r, ReportType type) {
    final isPending = r.status.toLowerCase() == 'pending';
    final statusColor = isPending ? AppColors.accent : AppColors.accent;

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
            // Avatar
            SafeCircleNetworkAvatar(
              radius: 22,
              imageUrl: r.avatarUrl,
              backgroundColor: AppColors.accent.withOpacity(0.15),
              fallback: Icon(_iconForReportType(type), color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
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
                  Wrap(spacing: 8, runSpacing: 6, children: [_pill(r.reason, AppColors.accent), _pill(r.status, statusColor)]),
                ],
              ),
            ),

            // Delete button
          ],
        ),
      ),
    );
  }

  // ── Tag pill ───────────────────────────────────────────────
  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Future<bool?> _confirm({required String title, required String message, required String confirmText}) {
    return Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Get.back(result: true), child: Text(confirmText)),
        ],
      ),
    );
  }
}
