import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/controllers/chat_controller.dart';
import 'package:get_right/models/app_notification.dart';
import 'package:get_right/repo/notification_repo.dart';
import 'package:get_right/services/chat_socket_service.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/utils/notification_navigator.dart';
import 'package:intl/intl.dart';

/// In-app notification inbox — REST + socket (`README-user.md`).
class NotificationController extends GetxController {
  final NotificationRepository _repo = NotificationRepository();

  final RxList<AppNotification> notifications = <AppNotification>[].obs;
  final RxInt unreadCount = 0.obs;
  final RxBool loading = false.obs;
  final RxBool loadingMore = false.obs;
  final RxnString error = RxnString();

  StreamSubscription<Map<String, dynamic>>? _socketSub;
  bool _hasNextPage = true;
  int _page = 1;
  static const int _limit = 20;

  StorageService? _storage;

  @override
  void onInit() {
    super.onInit();
    _attachSocketListener();
    WidgetsBinding.instance.addPostFrameCallback((_) => bootstrapInbox());
  }

  @override
  void onClose() {
    _socketSub?.cancel();
    super.onClose();
  }

  void _attachSocketListener() {
    _socketSub?.cancel();
    _socketSub = ChatSocketService.instance.onNotification.listen(_onSocketNotification);
  }

  StorageService? _tryStorage() {
    if (_storage != null) return _storage;
    if (Get.isRegistered<StorageService>()) {
      _storage = Get.find<StorageService>();
      return _storage;
    }
    return null;
  }

  String? _currentUserId() => _tryStorage()?.getUserId();

  bool _canSyncInbox() {
    final storage = _tryStorage();
    if (storage == null || !storage.isLoggedIn()) return false;
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      if (auth.isSessionInvalidating) return false;
    }
    return true;
  }

  /// After login / home entry: unread count + first inbox page.
  Future<void> bootstrapInbox() async {
    if (!_canSyncInbox()) return;
    await fetchUnreadCount();
    await loadNotifications(reset: true, showLoading: notifications.isEmpty);
  }

  Future<void> fetchUnreadCount() async {
    if (!_canSyncInbox()) {
      unreadCount.value = 0;
      return;
    }
    try {
      unreadCount.value = await _repo.fetchUnreadCount();
    } catch (_) {
      unreadCount.value = notifications.where((n) => !n.isRead).length;
    }
  }

  Future<void> loadNotifications({required bool reset, bool showLoading = true}) async {
    if (!_canSyncInbox()) return;
    if (reset) {
      if (loadingMore.value) return;
    } else {
      if (loadingMore.value || !_hasNextPage) return;
    }

    if (reset) {
      if (showLoading) loading.value = true;
      error.value = null;
      _page = 1;
      _hasNextPage = true;
    } else {
      loadingMore.value = true;
    }

    final pageToFetch = reset ? 1 : _page;

    try {
      final page = await _repo.fetchNotifications(
        page: pageToFetch,
        limit: _limit,
        currentUserId: _currentUserId(),
      );
      if (reset) {
        notifications.assignAll(page.notifications);
      } else {
        final existing = notifications.map((n) => n.id).toSet();
        for (final n in page.notifications) {
          if (!existing.contains(n.id)) notifications.add(n);
        }
      }
      _hasNextPage = page.hasNextPage;
      _page = pageToFetch + 1;
    } catch (e) {
      if (reset) {
        error.value = e.toString().replaceFirst('Exception: ', '');
        notifications.clear();
      }
    } finally {
      loading.value = false;
      loadingMore.value = false;
    }
  }

  Future<void> refreshInbox() async {
    await fetchUnreadCount();
    await loadNotifications(reset: true);
  }

  void _onSocketNotification(Map<String, dynamic> payload) {
    if (!_canSyncInbox()) return;

    final notification = AppNotification.tryParseSocket(payload, currentUserId: _currentUserId());
    if (notification == null) return;
    if (notification.isTrainerOnly) return;

    if (notification.data.kind == NotificationKind.newMessage) {
      if (Get.isRegistered<ChatController>()) {
        unawaited(Get.find<ChatController>().loadUnreadCount());
      }
      return;
    }

    if (!notification.isInboxEligible) return;

    final existingIndex = notifications.indexWhere((n) => n.id == notification.id);
    if (existingIndex >= 0) {
      notifications[existingIndex] = notification;
    } else {
      notifications.insert(0, notification);
      if (!notification.isRead) unreadCount.value++;
    }

    if (notification.data.kind == NotificationKind.feedProcessingCompleted) {
      Get.snackbar('Post live', notification.body.trim().isNotEmpty ? notification.body : 'Your post is now live.', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> onNotificationTap(AppNotification notification) async {
    if (!notification.isRead) {
      await markAsRead(notification.id);
    }
    await NotificationNavigator.open(notification);
  }

  Future<void> markAsRead(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return;
    final index = notifications.indexWhere((n) => n.id == id);
    if (index >= 0 && !notifications[index].isRead) {
      notifications[index] = notifications[index].copyWith(isRead: true);
      if (unreadCount.value > 0) unreadCount.value--;
    }
    try {
      await _repo.markAsRead(id);
      await fetchUnreadCount();
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    for (var i = 0; i < notifications.length; i++) {
      if (!notifications[i].isRead) {
        notifications[i] = notifications[i].copyWith(isRead: true);
      }
    }
    unreadCount.value = 0;
    try {
      await _repo.markAllAsRead();
    } catch (_) {}
  }

  static String formatTimeAgo(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final local = date.toLocal();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(local);
  }
}
