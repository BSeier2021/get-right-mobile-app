import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/safety_center_controller.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SafetyCenterController controller = Get.put(SafetyCenterController());
  int _selectedTab = 0; // 0 = Users, 1 = Posts

  // Placeholder avatars for demo
  static const _userAvatars = {
    'r_u_1': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop',
    'r_u_2': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&h=100&fit=crop',
  };
  static const _postAvatars = {
    'r_p_1': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop',
    'r_p_2': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withOpacity(0.15), width: 1),
            ),
            child: const Icon(Icons.chevron_left, color: AppColors.accent, size: 20),
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
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_tabChip('Users', 0), const SizedBox(width: 12), _tabChip('Posts', 1)]),
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
              final type = _selectedTab == 0 ? ReportType.user : ReportType.post;
              final items = controller.filteredReportsFor(type);

              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      type == ReportType.user ? 'No reported users.' : 'No reported posts.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final avatars = type == ReportType.user ? _userAvatars : _postAvatars;

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final r = items[i];
                  return _reportCard(r, type, avatars[r.id]);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Pill tab chip ──────────────────────────────────────────
  Widget _tabChip(String label, int index) {
    final selected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 60.w, vertical: 10),
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
  Widget _reportCard(ReportItem r, ReportType type, String? avatarUrl) {
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
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accent.withOpacity(0.15),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null ? Icon(type == ReportType.user ? Icons.person_outline : Icons.article_outlined, color: AppColors.accent, size: 20) : null,
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
                  Text(r.subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [_pill(r.reason, AppColors.accent), _pill(r.status, statusColor)]),
                ],
              ),
            ),
            // Delete button
            GestureDetector(
              onTap: () async {
                final confirm = await _confirm(
                  title: 'Remove report?',
                  message: "This will remove it from your list. (It won't undo the report on the server if already submitted.)",
                  confirmText: 'Remove',
                );
                if (confirm == true) controller.removeReport(type: type, reportId: r.id);
              },
              child: Padding(padding: const EdgeInsets.only(left: 8, top: 4), child: Image.asset('assets/images/trash333.png', width: 22, height: 22)),
            ),
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
