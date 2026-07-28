import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/models/app_notification.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/safe_circle_network_avatar.dart';

/// Notification inbox — `GET /user/notifications` + tap navigation.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = Get.find<NotificationController>();
    _scrollController.addListener(_onScroll);
    if (_controller.notifications.isEmpty && !_controller.loading.value) {
      _controller.loadNotifications(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _controller.loading.value || _controller.loadingMore.value) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _controller.loadNotifications(reset: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('Notifications', style: AppTextStyles.titleLarge.copyWith()),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(() {
            if (_controller.unreadCount.value <= 0) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: _controller.markAllAsRead,
              icon: const Icon(Icons.done_all, size: 18, color: AppColors.accent),
              label: Text('Mark all read', style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (_controller.loading.value && _controller.notifications.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }

        if (_controller.error.value != null && _controller.notifications.isEmpty) {
          return _buildError(_controller.error.value!);
        }

        if (_controller.notifications.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _controller.refreshInbox,
          child: Column(
            children: [
              if (_controller.unreadCount.value > 0) _buildUnreadBanner(_controller.unreadCount.value),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                  itemCount: _controller.notifications.length + (_controller.loadingMore.value ? 1 : 0),
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (context, index) {
                    if (index >= _controller.notifications.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                      );
                    }
                    return _buildNotificationItem(_controller.notifications[index], index);
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.primaryGray),
            SizedBox(height: 16.h),
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: () => _controller.loadNotifications(reset: true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

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
              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Center(child: Icon(Icons.notifications_none_rounded, size: 60, color: AppColors.accent.withValues(alpha: 0.6))),
            ),
            const SizedBox(height: 32),
            Text('All Caught Up!', style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'You have no notifications at the moment.\nWe\'ll notify you when something new arrives.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnreadBanner(int unreadCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.accent.withValues(alpha: 0.12), AppColors.accent.withValues(alpha: 0.04)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        border: Border(bottom: BorderSide(color: AppColors.accent.withValues(alpha: 0.15), width: 0.5)),
      ),
      child: Text(
        '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}',
        style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification notification, int index) {
    final isRead = notification.isRead;
    final color = notification.accentColor;
    final timeLabel = NotificationController.formatTimeAgo(notification.createdAt);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 250 + (index * 30).clamp(0, 300)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Material(
        color: isRead ? AppColors.surface : const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _controller.onNotificationTap(notification),
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isRead ? AppColors.primaryGray.withValues(alpha: 0.2) : AppColors.accent.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (notification.senderPhotoUrl != null && notification.senderPhotoUrl!.trim().isNotEmpty)
                  SafeCircleNetworkAvatar(
                    imageUrl: notification.senderPhotoUrl,
                    radius: 22,
                    fallback: Icon(notification.icon, color: color, size: 22),
                  )
                else
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(notification.icon, color: color, size: 22),
                  ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: AppTextStyles.titleSmall.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: EdgeInsets.only(left: 6.w),
                              decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      if (notification.body.trim().isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          notification.body,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (timeLabel.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        Text(timeLabel, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
