import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Notifications Screen using NotificationController
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationController _controller;

  // Enhanced notifications with IconData and Color for UI
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 1,
      'type': 'reminder',
      'title': 'Workout Reminder',
      'message': 'Time for your Upper Body workout! Let\'s crush it 💪',
      'time': '10 minutes ago',
      'isRead': false,
      'icon': Icons.fitness_center,
      'color': AppColors.accent,
    },
    {
      'id': 2,
      'type': 'achievement',
      'title': 'Achievement Unlocked! 🏆',
      'message': 'You\'ve completed 10 workouts this month. Keep going!',
      'time': '2 hours ago',
      'isRead': false,
      'icon': Icons.emoji_events,
      'color': AppColors.upcoming,
    },
    {
      'id': 3,
      'type': 'streak',
      'title': 'Streak Alert! 🔥',
      'message': 'You\'re on a 7-day workout streak. Don\'t break it!',
      'time': '5 hours ago',
      'isRead': false,
      'icon': Icons.local_fire_department,
      'color': AppColors.error,
    },
    {
      'id': 4,
      'type': 'program',
      'title': 'New Program Available',
      'message': 'Check out "Advanced Strength Training" by Coach Sarah',
      'time': 'Yesterday',
      'isRead': true,
      'icon': Icons.library_books,
      'color': AppColors.accent,
    },
    {
      'id': 5,
      'type': 'social',
      'title': 'Friend Activity',
      'message': 'Mike completed a 10K run. Send some motivation!',
      'time': 'Yesterday',
      'isRead': true,
      'icon': Icons.people,
      'color': AppColors.completed,
    },
    {
      'id': 6,
      'type': 'goal',
      'title': 'Goal Progress Update',
      'message': 'You\'re 75% towards your monthly goal of 20 workouts',
      'time': '2 days ago',
      'isRead': true,
      'icon': Icons.track_changes,
      'color': AppColors.upcoming,
    },
    {
      'id': 7,
      'type': 'rest',
      'title': 'Rest Day Reminder',
      'message': 'Your body needs recovery. Consider taking a rest day.',
      'time': '3 days ago',
      'isRead': true,
      'icon': Icons.hotel,
      'color': AppColors.primaryGray,
    },
    {
      'id': 8,
      'type': 'system',
      'title': 'App Update Available',
      'message': 'Get Right v1.1.0 is now available with new features!',
      'time': '1 week ago',
      'isRead': true,
      'icon': Icons.system_update,
      'color': AppColors.accent,
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = Get.find<NotificationController>();
    // Sync UI notifications with controller
    _syncNotifications();
  }

  void _syncNotifications() {
    final controllerNotifications = _controller.notifications;
    for (var i = 0; i < controllerNotifications.length && i < _notifications.length; i++) {
      _notifications[i]['isRead'] = controllerNotifications[i]['isRead'];
    }
  }

  void _markAsRead(int id) {
    _controller.markAsRead(id);
    setState(() {
      final index = _notifications.indexWhere((n) => n['id'] == id);
      if (index != -1) {
        _notifications[index]['isRead'] = true;
      }
    });
  }

  void _markAllAsRead() {
    _controller.markAllAsRead();
    setState(() {
      for (var notification in _notifications) {
        notification['isRead'] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Rebuild when notifications change
      final currentUnreadCount = _controller.unreadCount;
      _syncNotifications();

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Notifications', style: AppTextStyles.titleLarge.copyWith()),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
            ),
            onPressed: () => Get.back(),
          ),
          actions: [
            if (currentUnreadCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: _markAllAsRead,
                  icon: Icon(Icons.done_all, size: 18, color: AppColors.accent),
                  label: Text('Mark all read', style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
              ),
          ],
        ),
        body: _notifications.isEmpty ? _buildEmptyState() : _buildNotificationList(currentUnreadCount),
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), shape: BoxShape.circle),
              child: Center(child: Icon(Icons.notifications_none_rounded, size: 60, color: AppColors.accent.withOpacity(0.6))),
            ),
            const SizedBox(height: 32),
            Text(
              'All Caught Up!',
              style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'You have no notifications at the moment.\nWe\'ll notify you when something new arrives.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 20, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Stay tuned for updates',
                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(int unreadCount) {
    return Column(
      children: [
        // Unread count banner
        if (unreadCount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.12), AppColors.accent.withOpacity(0.04)], begin: Alignment.centerLeft, end: Alignment.centerRight),
              border: Border(bottom: BorderSide(color: AppColors.accent.withOpacity(0.15), width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.circle, size: 10, color: AppColors.accent),
                ),
                const SizedBox(width: 10),
                Text(
                  '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

        // Notifications list
        Expanded(
          child: ListView.builder(
            itemCount: _notifications.length,
            padding: const EdgeInsets.only(top: 4, bottom: 16, left: 0, right: 0),
            itemBuilder: (context, index) {
              final notification = _notifications[index];
              return _buildNotificationItem(notification, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification, int index) {
    final isRead = notification['isRead'] as bool;
    final title = notification['title'] as String;
    final message = notification['message'] as String;
    final time = notification['time'] as String;
    final icon = notification['icon'] as IconData;
    final color = notification['color'] as Color;
    final id = notification['id'] as int;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: () => _markAsRead(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            gradient: isRead ? null : LinearGradient(colors: [AppColors.primaryVariant, AppColors.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
            color: isRead ? AppColors.surface : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isRead ? AppColors.primaryGray.withOpacity(0.2) : AppColors.accent.withOpacity(0.4), width: isRead ? 1 : 1.5),
            boxShadow: isRead ? null : [BoxShadow(color: AppColors.accent.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 1))],
          ),
          child: Stack(
            children: [
              // Subtle accent line on left for unread
              if (!isRead)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                    ),
                  ),
                ),

              // Main content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon container with enhanced design
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color.withOpacity(0.25), color.withOpacity(0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.25), width: 1),
                      ),
                      child: Center(child: Icon(icon, color: color, size: 22)),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: isRead ? FontWeight.w600 : FontWeight.w700, fontSize: 15),
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 3, spreadRadius: 0.5)],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray.withOpacity(0.85), height: 1.4, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 11, color: color.withOpacity(0.7)),
                              const SizedBox(width: 4),
                              Text(
                                time,
                                style: AppTextStyles.labelSmall.copyWith(color: color.withOpacity(0.7), fontWeight: FontWeight.w600, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
