import 'package:flutter/material.dart';
import 'package:get_right/theme/color_constants.dart';

/// User-facing notification kinds from `data.kind` (README-user.md).
enum NotificationKind {
  newMessage,
  newPost,
  newProgram,
  newBundle,
  newFollower,
  postLiked,
  commentOnPost,
  replyOnComment,
  feedProcessingCompleted,
  feedProcessingFailed,
  unknown,
}

/// Trainer-only kinds — ignore in customer app inbox/socket.
const Set<String> kTrainerOnlyNotificationKinds = {
  'PROGRAM_ENROLLED',
  'BUNDLE_ENROLLED',
  'ENROLLMENT_COMPLETED',
  'REVIEW_ADDED',
  'PROGRAM_PROCESSING_COMPLETED',
  'PROGRAM_PROCESSING_FAILED',
  'CERTIFICATION_VERIFIED',
  'FEATURED_PROGRAM_ENDING',
};

class AppNotificationData {
  final String? type;
  final String? eventType;
  final NotificationKind kind;
  final String? conversationId;
  final String? messageId;
  final String? feedId;
  final String? commentId;
  final String? programId;
  final String? bundleId;
  final String? followerId;

  const AppNotificationData({
    this.type,
    this.eventType,
    required this.kind,
    this.conversationId,
    this.messageId,
    this.feedId,
    this.commentId,
    this.programId,
    this.bundleId,
    this.followerId,
  });

  factory AppNotificationData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AppNotificationData(kind: NotificationKind.unknown);
    }
    final kindRaw = json['kind']?.toString().trim() ?? '';
    return AppNotificationData(
      type: json['type']?.toString(),
      eventType: json['eventType']?.toString(),
      kind: parseNotificationKind(kindRaw),
      conversationId: json['conversationId']?.toString(),
      messageId: json['messageId']?.toString(),
      feedId: json['feedId']?.toString(),
      commentId: json['commentId']?.toString(),
      programId: json['programId']?.toString(),
      bundleId: json['bundleId']?.toString(),
      followerId: json['followerId']?.toString(),
    );
  }
}

NotificationKind parseNotificationKind(String? raw) {
  switch (raw?.trim().toUpperCase()) {
    case 'NEW_MESSAGE':
      return NotificationKind.newMessage;
    case 'NEW_POST':
      return NotificationKind.newPost;
    case 'NEW_PROGRAM':
      return NotificationKind.newProgram;
    case 'NEW_BUNDLE':
      return NotificationKind.newBundle;
    case 'NEW_FOLLOWER':
      return NotificationKind.newFollower;
    case 'POST_LIKED':
      return NotificationKind.postLiked;
    case 'COMMENT_ON_POST':
      return NotificationKind.commentOnPost;
    case 'REPLY_ON_COMMENT':
      return NotificationKind.replyOnComment;
    case 'FEED_PROCESSING_COMPLETED':
      return NotificationKind.feedProcessingCompleted;
    case 'FEED_PROCESSING_FAILED':
      return NotificationKind.feedProcessingFailed;
    default:
      return NotificationKind.unknown;
  }
}

bool isTrainerOnlyNotificationKind(String? kindRaw) {
  if (kindRaw == null || kindRaw.trim().isEmpty) return false;
  return kTrainerOnlyNotificationKinds.contains(kindRaw.trim().toUpperCase());
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final AppNotificationData data;
  final String? senderId;
  final String? senderName;
  final String? senderPhotoUrl;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    this.senderId,
    this.senderName,
    this.senderPhotoUrl,
    this.isRead = false,
    this.createdAt,
  });

  bool get isInboxEligible => data.kind != NotificationKind.newMessage;

  bool get isTrainerOnly => isTrainerOnlyNotificationKind(_kindRawFromData);

  String? get _kindRawFromData {
    switch (data.kind) {
      case NotificationKind.newMessage:
        return 'NEW_MESSAGE';
      case NotificationKind.newPost:
        return 'NEW_POST';
      case NotificationKind.newProgram:
        return 'NEW_PROGRAM';
      case NotificationKind.newBundle:
        return 'NEW_BUNDLE';
      case NotificationKind.newFollower:
        return 'NEW_FOLLOWER';
      case NotificationKind.postLiked:
        return 'POST_LIKED';
      case NotificationKind.commentOnPost:
        return 'COMMENT_ON_POST';
      case NotificationKind.replyOnComment:
        return 'REPLY_ON_COMMENT';
      case NotificationKind.feedProcessingCompleted:
        return 'FEED_PROCESSING_COMPLETED';
      case NotificationKind.feedProcessingFailed:
        return 'FEED_PROCESSING_FAILED';
      case NotificationKind.unknown:
        return null;
    }
  }

  IconData get icon {
    switch (data.kind) {
      case NotificationKind.newPost:
      case NotificationKind.feedProcessingCompleted:
      case NotificationKind.feedProcessingFailed:
        return Icons.dynamic_feed_outlined;
      case NotificationKind.newProgram:
        return Icons.fitness_center_outlined;
      case NotificationKind.newBundle:
        return Icons.inventory_2_outlined;
      case NotificationKind.newFollower:
        return Icons.person_add_alt_1_outlined;
      case NotificationKind.postLiked:
        return Icons.favorite_outline;
      case NotificationKind.commentOnPost:
      case NotificationKind.replyOnComment:
        return Icons.chat_bubble_outline;
      case NotificationKind.newMessage:
        return Icons.chat_outlined;
      case NotificationKind.unknown:
        return Icons.notifications_outlined;
    }
  }

  Color get accentColor {
    switch (data.kind) {
      case NotificationKind.postLiked:
        return const Color(0xFFE85050);
      case NotificationKind.newFollower:
        return const Color(0xFF5A9BD5);
      case NotificationKind.feedProcessingFailed:
        return AppColors.error;
      case NotificationKind.feedProcessingCompleted:
        return AppColors.completed;
      default:
        return AppColors.accent;
    }
  }

  factory AppNotification.fromApiJson(Map<String, dynamic> json, {String? currentUserId}) {
    final dataNode = json['data'];
    final data = dataNode is Map ? AppNotificationData.fromJson(Map<String, dynamic>.from(dataNode)) : const AppNotificationData(kind: NotificationKind.unknown);

    final sendBy = json['sendBy'];
    String? senderId;
    String? senderName;
    String? senderPhotoUrl;
    if (sendBy is Map) {
      final m = Map<String, dynamic>.from(sendBy);
      senderId = m['_id']?.toString();
      final profile = m['profile'];
      if (profile is Map) {
        final p = Map<String, dynamic>.from(profile);
        senderName = p['fullName']?.toString() ?? p['name']?.toString();
        senderPhotoUrl = p['profilePicture']?.toString() ?? p['profilePictureUrl']?.toString();
      }
    } else if (sendBy != null) {
      senderId = sendBy.toString();
    }

    final readBy = json['readBy'];
    var isRead = false;
    if (readBy is List) {
      if (readBy.isEmpty) {
        isRead = false;
      } else if (currentUserId != null && currentUserId.trim().isNotEmpty) {
        isRead = readBy.any((e) => e?.toString() == currentUserId);
      } else {
        isRead = true;
      }
    }

    return AppNotification(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? json['message']?.toString() ?? '',
      data: data,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      isRead: isRead,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  /// Socket payload may be the notification object or `{ notification: {...} }`.
  static AppNotification? tryParseSocket(dynamic raw, {String? currentUserId}) {
    if (raw is! Map) return null;
    final root = Map<String, dynamic>.from(raw);
    final nested = root['notification'];
    if (nested is Map) {
      return AppNotification.fromApiJson(Map<String, dynamic>.from(nested), currentUserId: currentUserId);
    }
    if (root.containsKey('title') || root.containsKey('data') || root.containsKey('_id')) {
      return AppNotification.fromApiJson(root, currentUserId: currentUserId);
    }
    final data = root['data'];
    if (data is Map) {
      return AppNotification.fromApiJson(
        {
          '_id': root['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'title': root['title']?.toString() ?? '',
          'body': root['body']?.toString() ?? '',
          'sendBy': root['sendBy'],
          'data': data,
          'createdAt': root['createdAt']?.toString(),
        },
        currentUserId: currentUserId,
      );
    }
    return null;
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      data: data,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

class AppNotificationsPage {
  final List<AppNotification> notifications;
  final int totalDocs;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  const AppNotificationsPage({
    required this.notifications,
    required this.totalDocs,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory AppNotificationsPage.fromApi(dynamic raw, {String? currentUserId}) {
    final root = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final data = root['data'] is Map ? Map<String, dynamic>.from(root['data'] as Map) : root;
    final list = data['notifications'];
    final items = <AppNotification>[];
    if (list is List) {
      for (final item in list) {
        if (item is! Map) continue;
        final n = AppNotification.fromApiJson(Map<String, dynamic>.from(item), currentUserId: currentUserId);
        if (n.id.isEmpty || n.isTrainerOnly || !n.isInboxEligible) continue;
        items.add(n);
      }
    }
    return AppNotificationsPage(
      notifications: items,
      totalDocs: (data['totalDocs'] as num?)?.toInt() ?? items.length,
      currentPage: (data['currentPage'] as num?)?.toInt() ?? 1,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
      hasNextPage: data['hasNextPage'] == true,
      hasPrevPage: data['hasPrevPage'] == true,
    );
  }
}
