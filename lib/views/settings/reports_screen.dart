import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/safety_center_controller.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SafetyCenterController controller = Get.put(SafetyCenterController());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          title: Text('Reports', style: AppTextStyles.titleLarge.copyWith()),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: AppColors.accent,
            labelColor: AppColors.onBackground,
            unselectedLabelColor: AppColors.primaryGrayDark,
            tabs: const [
              Tab(text: 'Users'),
              Tab(text: 'Posts'),
            ],
          ),
          leading: GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
            ).paddingAll(8),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (v) => controller.reportsQuery.value = v,
                decoration: InputDecoration( filled: true, fillColor: AppColors.white,
                  hintText: 'Search reports',
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.accent.withOpacity(0.3), width: 2)),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Obx(
                    () => controller.reportsQuery.value.trim().isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            onPressed: () {
                              controller.reportsQuery.value = '';
                              FocusScope.of(context).unfocus();
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ReportsList(type: ReportType.user, controller: controller),
                  _ReportsList(type: ReportType.post, controller: controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsList extends StatelessWidget {
  final ReportType type;
  final SafetyCenterController controller;

  const _ReportsList({required this.type, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
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

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final r = items[i];
          final isPending = r.status.toLowerCase() == 'pending';
          final statusColor = isPending ? Colors.orange : AppColors.accent;

          return ListTile(
            leading: Icon(type == ReportType.user ? Icons.person_off_outlined : Icons.report_outlined, color: AppColors.onBackground),
            title: Text(r.title, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(r.subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(text: r.reason, background: AppColors.primaryGrayLight, foreground: AppColors.onBackground),
                    _Pill(text: r.status, background: statusColor.withOpacity(0.15), foreground: statusColor),
                  ],
                ),
              ],
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'Remove',
              onPressed: () async {
                final confirm = await _confirm(
                  title: 'Remove report?',
                  message: 'This will remove it from your list. (It won’t undo the report on the server if already submitted.)',
                  confirmText: 'Remove',
                );
                if (confirm == true) controller.removeReport(type: type, reportId: r.id);
              },
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
            ),
          );
        },
      );
    });
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

class _Pill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const _Pill({required this.text, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}
