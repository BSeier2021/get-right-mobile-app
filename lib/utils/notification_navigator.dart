import 'package:get/get.dart';
import 'package:get_right/models/app_notification.dart';
import 'package:get_right/routes/app_routes.dart';

/// Deep-link navigation for user notification taps (README-user.md).
class NotificationNavigator {
  NotificationNavigator._();

  static Future<void> open(AppNotification notification) async {
    final data = notification.data;
    switch (data.kind) {
      case NotificationKind.newMessage:
        final conversationId = data.conversationId?.trim();
        if (conversationId == null || conversationId.isEmpty) return;
        await Get.toNamed(
          AppRoutes.chatRoom,
          arguments: <String, dynamic>{
            'conversationId': conversationId,
            if (notification.senderId != null) 'trainerId': notification.senderId,
            if (notification.senderName != null) 'trainerName': notification.senderName,
          },
        );
        return;

      case NotificationKind.newPost:
      case NotificationKind.postLiked:
      case NotificationKind.commentOnPost:
      case NotificationKind.replyOnComment:
      case NotificationKind.feedProcessingCompleted:
        final feedId = data.feedId?.trim();
        if (feedId == null || feedId.isEmpty) return;
        await Get.toNamed(
          AppRoutes.feedSingleReel,
          arguments: <String, dynamic>{
            'feedId': feedId,
            if (data.commentId != null && data.commentId!.trim().isNotEmpty) 'commentId': data.commentId!.trim(),
          },
        );
        return;

      case NotificationKind.feedProcessingFailed:
        final feedId = data.feedId?.trim();
        if (feedId != null && feedId.isNotEmpty) {
          await Get.toNamed(
            AppRoutes.feedSingleReel,
            arguments: <String, dynamic>{'feedId': feedId},
          );
          return;
        }
        await Get.toNamed(AppRoutes.createPost);
        return;

      case NotificationKind.newProgram:
        final programId = data.programId?.trim();
        if (programId == null || programId.isEmpty) return;
        await Get.toNamed(
          AppRoutes.programDetail,
          arguments: <String, dynamic>{'id': programId, '_id': programId},
        );
        return;

      case NotificationKind.newBundle:
        final bundleId = data.bundleId?.trim();
        if (bundleId == null || bundleId.isEmpty) return;
        await Get.toNamed(AppRoutes.bundleDetail, arguments: bundleId);
        return;

      case NotificationKind.newFollower:
        final followerId = data.followerId?.trim() ?? notification.senderId?.trim();
        if (followerId == null || followerId.isEmpty) return;
        await Get.toNamed(
          AppRoutes.trainerProfile,
          arguments: <String, dynamic>{'userId': followerId, 'id': followerId, '_id': followerId},
        );
        return;

      case NotificationKind.unknown:
        return;
    }
  }
}
