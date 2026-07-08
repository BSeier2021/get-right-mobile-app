import 'package:get_right/app_url.dart';
import 'package:get_right/models/app_notification.dart';
import 'package:get_right/network/network_services.dart';

class NotificationRepository {
  final _network = NetworkApiService();

  /// `GET /user/notifications/unread-count`
  Future<int> fetchUnreadCount() async {
    final raw = await _network.get(AppUrl.userNotificationsUnreadCount);
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load notification count');
    }
    return _parseUnreadCount(raw);
  }

  /// `GET /user/notifications`
  Future<AppNotificationsPage> fetchNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
    String? currentUserId,
  }) async {
    final raw = await _network.get(
      AppUrl.userNotificationsList(page: page, limit: limit, unreadOnly: unreadOnly),
    );
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load notifications');
    }
    return AppNotificationsPage.fromApi(raw, currentUserId: currentUserId);
  }

  /// `PATCH /user/notifications/{notificationId}/read`
  Future<void> markAsRead(String notificationId) async {
    final raw = await _network.patch(AppUrl.userNotificationRead(notificationId), <String, dynamic>{});
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not mark notification as read');
    }
  }

  /// `PATCH /user/notifications/read-all`
  Future<void> markAllAsRead() async {
    final raw = await _network.patch(AppUrl.userNotificationsReadAll, <String, dynamic>{});
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not mark all notifications as read');
    }
  }

  static int _parseUnreadCount(dynamic raw) {
    if (raw is! Map) return 0;
    final root = Map<String, dynamic>.from(raw);
    final data = root['data'];
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final c = m['count'] ?? m['unreadCount'] ?? m['totalUnread'];
      if (c is num) return c.toInt();
    }
    final direct = root['count'] ?? root['unreadCount'] ?? root['totalUnread'];
    if (direct is num) return direct.toInt();
    return 0;
  }

  static bool _isOk(dynamic response) {
    if (response is! Map) return false;
    final m = Map<String, dynamic>.from(response);
    if (m['success'] == true || m['success'] == 1) return true;
    if (m['notifications'] is List) return true;
    final data = m['data'];
    if (data is Map && data['notifications'] is List) return true;
    final st = m['status'];
    return st == 200 || st == '200' || st == 201 || st == '201';
  }

  static String? _messageFrom(dynamic response) {
    if (response is! Map) return null;
    final message = Map<String, dynamic>.from(response)['message'];
    if (message is String && message.trim().isNotEmpty) return message;
    return null;
  }
}
