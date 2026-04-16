// import 'dart:convert';
// import 'dart:developer';

// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:get/get.dart';

// import 'helper.dart';

// class NotificationHandler {
//   // Main notification handler function
//   Future<void> handleNotificationFunction(RemoteMessage message) async {
//     try {
//       final isAutoLoginSuccessful = await autoLoginCompleter.future;

//       if (!isAutoLoginSuccessful) {
//         _logNotificationSkipped('Auto login failed');
//         return;
//       }

//       // message.data is already a Map<String, dynamic>, no need to decode
//       final data = message.data;

//       // Firebase push notifications come as flat structure
//       // notificationType comes from eventType (e.g., "social", "content")
//       // event comes from event field (e.g., "post_liked", "new_follower")
//       final notificationType = data["eventType"];
//       final event = data["event"];

//       if (notificationType == null || event == null) {
//         _logError('Missing notification type or event', data);
//         return;
//       }

//       log('Processing notification - Type: $notificationType, Event: $event', name: 'NotificationHandler');

//       await processNotificationByType(notificationType, event, data);
//     } catch (error) {
//       _logError('Error handling notification: $error', message.data);
//       // You might want to report this error to crash analytics
//     }
//   }

//   // Process notification based on type
//   Future<void> processNotificationByType(
//     String type,
//     String event,
//     Map<String, dynamic> data,
//   ) async {
//     switch (type) {
//       // New notification types
//       case "social":
//         await _handleSocialNotification(event, data);
//         break;
//       case "content":
//         await _handleContentNotification(event, data);
//         break;

//       default:
//         _logUnknownType(type, data);
//     }
//   }

//   // =============================================================================
//   // NEW NOTIFICATION TYPE HANDLERS
//   // =============================================================================

//   // Handle 'Bid' type notifications
//   Future<void> _handleSocialNotification(String event, Map<String, dynamic> data) async {
//     log(data.toString(), name: "social");

//     switch (event) {
//       case "new_follower":
//         await _onNewFollower(data);
//         break;
//       case "follow_request":
//         await _onFollowRequest(data);
//         break;
//       case "follow_request_accepted":
//         await _onFollowRequestAccepted(data);
//         break;
//       // case "follow_request_rejected":
//       //   await _onFollowRequestRejected(data);
//       //   break;
//       case "post_liked":
//         await _onPostLiked(data);
//         break;
//       case "post_commented":
//         await _onPostCommented(data);
//         break;
//       case "post_shared":
//         await _onPostShared(data);
//         break;
//       case "new_message":
//         await _onNewMessage(data);
//         break;
//       // case "mention":
//       //   await _onMention(data);
//       //   break;
//       default:
//         _logUnknownEvent("social", event, data);
//     }
//   }

//   // Handle 'Job' type notifications
//   Future<void> _handleContentNotification(String event, Map<String, dynamic> data) async {
//     log(data.toString(), name: "content");

//     switch (event) {
//       case "new_post":
//         await _onNewPost(data);
//         break;
//       case "community_post":
//         await _onCommunityPost(data);
//         break;

//       default:
//         _logUnknownEvent("Job", event, data);
//     }
//   }

//   // =============================================================================
//   // NEW EVENT HANDLERS
//   // =============================================================================

//   // SOCIAL EVENT HANDLERS
//   Future<void> _onNewFollower(Map<String, dynamic> data) async {
//     try {
//       // Firebase push notification data comes as flat structure
//       final followerId = data["followerId"];
//       final followedUserId = data["followedUserId"];

//       log('New follower notification received - FollowerID: $followerId, FollowedUserID: $followedUserId', name: 'NotificationHandler');

//       // Navigate to FollowersScreen with the followerId to show the new follower
//       if (followerId != null) {
//         Get.to(() => FollowersScreen(followerId: followerId.toString()));
//       } else {
//         Get.to(() => FollowersScreen());
//       }
//     } catch (e) {
//       log('Error parsing new follower notification data: $e', name: 'NotificationHandler');
//     }
//   }

//   Future<void> _onFollowRequest(Map<String, dynamic> data) async {
//     try {
//       // Firebase push notification data comes as flat structure
//       // All fields (followerId, followedUserId, etc.) are at root level
//       final followerId = data["followerId"];
//       final followedUserId = data["followedUserId"];

//       log('Follow request notification received - FollowerID: $followerId, FollowedUserID: $followedUserId', name: 'NotificationHandler');

//       // Navigate to NotificationsScreen requests tab
//       log('Navigating to NotificationsScreen requests tab', name: 'NotificationHandler');

//       final navigationController = Get.put(NavigationController());
//       navigationController.changePage(3);
//     } catch (e) {
//       log('Error parsing follow request notification data: $e', name: 'NotificationHandler');
//     }
//   }

//   Future<void> _onFollowRequestAccepted(Map<String, dynamic> data) async {
//     try {
//       // Firebase push notification data comes as flat structure
//       // All fields (followerId, followedUserId, etc.) are at root level
//       final followerId = data["followerId"]; // Current user who sent the request
//       final followedUserId = data["followedUserId"]; // User who accepted the request

//       log('Follow request accepted notification received - FollowerID: $followerId, FollowedUserID: $followedUserId', name: 'NotificationHandler');

//       if (followedUserId != null) {
//         // Navigate to the profile of the user who accepted the request
//         log('Navigating to profile of user who accepted: $followedUserId', name: 'NotificationHandler');
//         Get.to(() => OtherUserProfileScreen(
//               userId: followedUserId.toString(),
//               profileId: followedUserId.toString(),
//             ));
//       } else {
//         log('Missing followedUserId in follow request accepted notification', name: 'NotificationHandler');
//       }
//     } catch (e) {
//       log('Error parsing follow request accepted notification data: $e', name: 'NotificationHandler');
//     }
//   }

//   // Future<void> _onFollowRequestRejected(Map<String, dynamic> data) async {
//   //   try {
//   //     // Firebase push notification data comes as flat structure
//   //     // TODO: Implement follow request rejected handling
//   //     log('Follow request rejected notification received - Data: $data', name: 'NotificationHandler');
//   //   } catch (e) {
//   //     log('Error parsing follow request rejected notification data: $e', name: 'NotificationHandler');
//   //   }
//   // }

//   Future<void> _onCommunityPost(Map<String, dynamic> data) async {
//     try {
//       // Firebase push notification data comes as flat structure
//       // TODO: Implement community post handling
//       log('Community post notification received - Data: $data', name: 'NotificationHandler');
//     } catch (e) {
//       log('Error parsing community post notification data: $e', name: 'NotificationHandler');
//     }
//   }

//   // COMMENT EVENT HANDLERS
//   Future<void> _onPostCommented(Map<String, dynamic> data) async {
//     try {
//       // Firebase push notification data can come as flat structure or nested in metadata
//       // Try to get postId from root level first, then from metadata
//       String? postId = _getStringValue(data["postId"]);
//       String? replyId = _getStringValue(data["replyId"]);
//       String? commenterId = _getStringValue(data["commenterId"]);
//       bool? isReplyToReply = _getBoolValue(data["isReplyToReply"]);

//       // If postId is not at root level, check metadata
//       if (postId == null && data["metadata"] != null) {
//         final metadata = data["metadata"] as Map<String, dynamic>;
//         postId = _getStringValue(metadata["postId"]);
//         replyId = _getStringValue(metadata["replyId"]);
//         commenterId = _getStringValue(metadata["commenterId"]);
//         isReplyToReply = _getBoolValue(metadata["isReplyToReply"]);
//       }

//       log('Comment on post notification received - PostID: $postId, ReplyID: $replyId, CommenterID: $commenterId, IsReplyToReply: $isReplyToReply', name: 'NotificationHandler');

//       if (postId != null && postId.isNotEmpty) {
//         // Navigate to CastsScreen to show all comments on this post
//         log('Navigating to CastsScreen for postId: $postId', name: 'NotificationHandler');
//         Get.to(() => CastsScreen(postId: postId!));
//       } else {
//         log('Missing postId in post commented notification', name: 'NotificationHandler');
//       }
//     } catch (e) {
//       log('Error parsing comment on post notification data: $e', name: 'NotificationHandler');
//     }
//   }

//   // Helper method to safely get string value (handles empty strings as null)
//   String? _getStringValue(dynamic value) {
//     if (value == null) return null;
//     if (value is String) {
//       return value.isEmpty ? null : value;
//     }
//     return value.toString().isEmpty ? null : value.toString();
//   }

//   // Helper method to safely get bool value (handles string "true"/"false")
//   bool? _getBoolValue(dynamic value) {
//     if (value == null) return null;
//     if (value is bool) return value;
//     if (value is String) {
//       final lowerValue = value.toLowerCase().trim();
//       if (lowerValue == 'true') return true;
//       if (lowerValue == 'false') return false;
//       return null;
//     }
//     if (value is int) {
//       return value != 0;
//     }
//     return null;
//   }

//   // REPLY EVENT HANDLERS
//   Future<void> _onPostShared(Map<String, dynamic> data) async {
//     try {
//       // Firebase push notification data comes as flat structure
//       // TODO: Implement post shared handling
//       log('Post shared notification received - Data: $data', name: 'NotificationHandler');
//     } catch (e) {
//       log('Error parsing post shared notification data: $e', name: 'NotificationHandler');
//     }
//   }

//   // MESSAGE EVENT HANDLERS
//   Future<void> _onNewMessage(Map<String, dynamic> data) async {
//     try {
//       final metadata = _extractMetadata(data);

//       final conversationId = _getStringValue(data["conversationId"]) ?? _getStringValue(metadata["conversationId"]);
//       final senderId = _getStringValue(data["senderId"]) ?? _getStringValue(metadata["senderId"]);
//       final messageId = _getStringValue(data["messageId"]) ?? _getStringValue(metadata["messageId"]);
//       final messageType = _getStringValue(data["messageType"]) ?? _getStringValue(metadata["messageType"]);

//       log(
//         'New message notification received - conversationId: $conversationId, senderId: $senderId, messageId: $messageId, type: $messageType',
//         name: 'NotificationHandler',
//       );

//       if (senderId == null || senderId.isEmpty) {
//         _logError('Missing senderId in new message notification', data);
//         return;
//       }

//       final chatController = Get.isRegistered<ChatController>() ? Get.find<ChatController>() : Get.put(ChatController());

//       // Fetch up-to-date conversation details with the sender
//       final conversation = await chatController.getConversationByUserId(senderId);

//       if (conversation == null) {
//         Get.snackbar(
//           'Error',
//           'Unable to open this conversation right now. Please try again.',
//           snackPosition: SnackPosition.BOTTOM,
//         );
//         return;
//       }

//       Get.to(() => ChatRoomScreen(
//             conversation: conversation,
//             userId: senderId,
//           ));
//     } catch (e) {
//       log('Error parsing new message notification data: $e', name: 'NotificationHandler');
//     }
//   }

//   // PROFILE EVENT HANDLERS
//   // Future<void> _onMention(Map<String, dynamic> data) async {
//   //   try {
//   //     // Firebase push notification data comes as flat structure
//   //     // TODO: Implement mention handling
//   //     log('Mention notification received - Data: $data', name: 'NotificationHandler');
//   //   } catch (e) {
//   //     log('Error parsing mention notification data: $e', name: 'NotificationHandler');
//   //   }
//   // }

//   // SCHEDULED JOB EVENT HANDLERS
//   Future<void> _onNewPost(Map<String, dynamic> data) async {
//     try {
//       // Firebase push notification data can come as flat structure or nested in metadata
//       // Try to get postId from root level first, then from metadata
//       String? postId = _getStringValue(data["postId"]);
//       String? userId = _getStringValue(data["userId"]);
//       String? postType = _getStringValue(data["postType"]);

//       // If postId is not at root level, check metadata
//       if (postId == null && data["metadata"] != null) {
//         final metadata = data["metadata"] as Map<String, dynamic>;
//         postId = _getStringValue(metadata["postId"]);
//         userId = _getStringValue(metadata["userId"]);
//         postType = _getStringValue(metadata["postType"]);
//       }

//       log('New post notification received - PostID: $postId, UserID: $userId, PostType: $postType', name: 'NotificationHandler');

//       // Navigate to home screen (index 0) and switch to "for-you" tab
//       try {
//         final navigationController = Get.find<NavigationController>();
//         navigationController.changePage(0); // Navigate to home screen

//         // Wait a bit for navigation to complete, then switch to "for-you" tab
//         await Future.delayed(const Duration(milliseconds: 100));

//         // Get HomeController and switch to "for-you" tab
//         if (Get.isRegistered<HomeController>()) {
//           final homeController = Get.find<HomeController>();
//           homeController.changeTab('for-you');
//           // Refresh posts to show the new post
//           homeController.fetchVoicePosts(refresh: true);
//           log('Navigated to home screen and switched to "for-you" tab', name: 'NotificationHandler');
//         } else {
//           // If HomeController is not registered yet, it will be created when home screen loads
//           // The tab will default to "for-you" anyway
//           log('HomeController not registered yet, navigation will handle tab switching', name: 'NotificationHandler');
//         }
//       } catch (e) {
//         log('Error navigating to home screen: $e', name: 'NotificationHandler');
//         // Fallback: just navigate to home
//         try {
//           final navigationController = Get.put(NavigationController());
//           navigationController.changePage(0);
//         } catch (e2) {
//           log('Fallback navigation also failed: $e2', name: 'NotificationHandler');
//         }
//       }
//     } catch (e) {
//       log('Error parsing new post notification data: $e', name: 'NotificationHandler');
//     }
//   }

//   // REVIEW EVENT HANDLERS

//   // POST EVENT HANDLERS
//   Future<void> _onPostLiked(Map<String, dynamic> data) async {
//     try {
//       // Firebase push notification data comes as flat structure
//       // All fields (postId, likerId, likeType, etc.) are at root level
//       final postId = data["postId"];
//       final likerId = data["likerId"];
//       final likeType = data["likeType"];

//       log('Post liked notification received - PostID: $postId, LikerID: $likerId, LikeType: $likeType', name: 'NotificationHandler');

//       if (postId != null) {
//         // Navigate to ReactionsScreen to show all reactions on this post
//         log('Navigating to ReactionsScreen for postId: $postId', name: 'NotificationHandler');
//         Get.to(() => ReactionsScreen(postId: postId.toString()));
//       } else {
//         log('Missing postId in post liked notification', name: 'NotificationHandler');
//       }
//     } catch (e) {
//       log('Error parsing post liked notification data: $e', name: 'NotificationHandler');
//     }
//   }

//   // =============================================================================
//   // UTILITY & LOGGING METHODS
//   // =============================================================================

//   void _logNotificationSkipped(String reason) {
//     log('Notification skipped: $reason', name: 'NotificationHandler');
//   }

//   void _logError(String message, Map<String, dynamic> data) {
//     log('$message - Data: $data', name: 'NotificationHandler', level: 1000);
//   }

//   void _logUnknownType(String type, Map<String, dynamic> data) {
//     log('Unknown notification type: $type - Data: $data', name: 'NotificationHandler', level: 900);
//   }

//   void _logUnknownEvent(String type, String event, Map<String, dynamic> data) {
//     log('Unknown event "$event" for type "$type" - Data: $data', name: 'NotificationHandler', level: 900);
//   }

//   Map<String, dynamic> _extractMetadata(Map<String, dynamic> data) {
//     final rawMetadata = data['metadata'];

//     if (rawMetadata == null) {
//       return {};
//     }

//     if (rawMetadata is Map<String, dynamic>) {
//       return rawMetadata;
//     }

//     if (rawMetadata is String && rawMetadata.isNotEmpty) {
//       try {
//         final decoded = jsonDecode(rawMetadata);
//         if (decoded is Map<String, dynamic>) {
//           return decoded;
//         }
//       } catch (e) {
//         log('Failed to decode metadata string: $e', name: 'NotificationHandler');
//       }
//     }

//     return {};
//   }
// }

// // Extension to make the notification data access safer
// extension SafeNotificationData on Map<String, dynamic> {
//   String? getType() => this["type"];
//   String? getEvent() => this["event"];

//   T? getValue<T>(String key) {
//     final value = this[key];
//     return value is T ? value : null;
//   }
// }
