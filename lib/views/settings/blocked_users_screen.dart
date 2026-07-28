import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/safety_center_controller.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/safe_circle_network_avatar.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late final SafetyCenterController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<SafetyCenterController>() ? Get.find<SafetyCenterController>() : Get.put(SafetyCenterController());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadBlockedUsers(showLoading: controller.blockedUsers.isEmpty);
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
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.15), width: 1),
            ),
            child: const Icon(Icons.chevron_left, color: AppColors.accent, size: 25),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Blocked Users',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (controller.blockedLoading.value && controller.blockedUsers.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: AppColors.accent));
              }

              if (controller.blockedError.value != null && controller.blockedUsers.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          controller.blockedError.value!,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: () => controller.loadBlockedUsers(), child: const Text('Retry')),
                      ],
                    ),
                  ),
                );
              }

              final users = controller.filteredBlockedUsers;

              if (users.isEmpty) {
                return RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: () => controller.loadBlockedUsers(showLoading: false),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Center(
                        child: Text(
                          'No blocked users.',
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
                onRefresh: () => controller.loadBlockedUsers(showLoading: false),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: users.length,
                  itemBuilder: (context, i) => _userCard(users[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _userCard(BlockedUser u) {
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
          children: [
            SafeCircleNetworkAvatar(
              radius: 22,
              imageUrl: u.avatarUrl,
              backgroundColor: AppColors.accent.withValues(alpha: 0.15),
              fallback: Text(
                _initials(u.name),
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.name,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(u.username, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 12.5)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _onUnblockTap(u),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(color: AppColors.accentVariant, borderRadius: BorderRadius.circular(50)),
                child: Text(
                  'Unblock',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onUnblockTap(BlockedUser u) async {
    final confirm = await _confirm(title: 'Unblock user?', message: 'They will be able to view and interact with you again.', confirmText: 'Unblock');
    if (confirm != true) return;

    try {
      await controller.unblock(u.id);
      Get.snackbar('Unblocked', '${u.name} has been unblocked.', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Could not unblock', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
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
