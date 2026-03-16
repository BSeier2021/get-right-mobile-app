import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/safety_center_controller.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SafetyCenterController controller = Get.put(SafetyCenterController());

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('Blocked Users', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
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
              onChanged: (v) => controller.blockedQuery.value = v,
              decoration: InputDecoration( filled: true, fillColor: AppColors.white,
                hintText: 'Search blocked users',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Obx(
                  () => controller.blockedQuery.value.trim().isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          onPressed: () {
                            controller.blockedQuery.value = '';
                            FocusScope.of(context).unfocus();
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final users = controller.filteredBlockedUsers;
              if (users.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No blocked users.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final u = users[i];
                  final initials = _initials(u.name);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accent.withOpacity(0.2),
                      foregroundColor: AppColors.onBackground,
                      child: Text(initials, style: AppTextStyles.labelMedium.copyWith(color: AppColors.onBackground)),
                    ),
                    title: Text(u.name, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground)),
                    subtitle: Text(u.username, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark)),
                    trailing: TextButton(
                      onPressed: () async {
                        final confirm = await _confirm(title: 'Unblock user?', message: 'They will be able to view and interact with you again.', confirmText: 'Unblock');
                        if (confirm == true) controller.unblock(u.id);
                      },
                      child: Text('Unblock', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.accent)),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.take(1).toString().toUpperCase();
    return (parts.first.characters.take(1).toString() + parts.last.characters.take(1).toString()).toUpperCase();
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
