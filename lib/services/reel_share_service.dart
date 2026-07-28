import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_right/app_url.dart';
import 'package:get_right/models/shared_content_model.dart';
import 'package:get_right/repo/feed_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/services/share_to_chat_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:share_plus/share_plus.dart';

/// Reel share — copy link, native share sheet, and in-app chat (see reel-share guide).
class ReelShareService {
  ReelShareService._();

  static final FeedRepository _feedRepo = FeedRepository();

  static String? feedIdFromPost(Map<String, dynamic> post) {
    final id = (post['id'] ?? post['_id'] ?? post['feedId'] ?? '').toString().trim();
    return WorkoutRepository.isValidMongoId(id) ? id : null;
  }

  static String shareLinkFor(String feedId) => AppUrl.reelShareLink(feedId);

  static String shareTextFor(Map<String, dynamic> post, String feedId) {
    final title = (post['title'] ?? '').toString().trim();
    final creator = (post['creator'] ?? 'Get Right').toString().trim();
    final link = shareLinkFor(feedId);
    final headline = title.isNotEmpty ? title : 'Check out this reel';
    return '$headline by $creator on Get Right\n$link';
  }

  static void _bumpShareCount(Map<String, dynamic> post, VoidCallback? onSharesChanged) {
    final current = (post['shares'] is num) ? (post['shares'] as num).toInt() : 0;
    post['shares'] = current + 1;
    onSharesChanged?.call();
  }

  static Future<void> copyLink({
    required Map<String, dynamic> post,
    VoidCallback? onSharesChanged,
  }) async {
    final feedId = feedIdFromPost(post);
    if (feedId == null) {
      Get.snackbar('Cannot share', 'This reel is not ready to share yet', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }
    final link = shareLinkFor(feedId);
    await Clipboard.setData(ClipboardData(text: link));
    unawaited(_feedRepo.recordFeedShareRepo(feedId, channel: 'copy_link'));
    _bumpShareCount(post, onSharesChanged);
    Get.snackbar('Link copied', 'Reel link copied to clipboard', backgroundColor: AppColors.completed, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
  }

  static Future<void> shareToOtherApps({
    required Map<String, dynamic> post,
    VoidCallback? onSharesChanged,
  }) async {
    final feedId = feedIdFromPost(post);
    if (feedId == null) {
      Get.snackbar('Cannot share', 'This reel is not ready to share yet', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }
    final text = shareTextFor(post, feedId);
    final title = (post['title'] ?? 'Get Right Reel').toString().trim();
    await Share.share(text, subject: title.isNotEmpty ? title : 'Get Right Reel');
    unawaited(_feedRepo.recordFeedShareRepo(feedId, channel: 'native_share'));
    _bumpShareCount(post, onSharesChanged);
  }

  static Future<void> shareToChat({
    required BuildContext hostContext,
    required Map<String, dynamic> post,
    VoidCallback? onSharesChanged,
  }) async {
    final feedId = feedIdFromPost(post);
    if (feedId == null) {
      Get.snackbar('Cannot share', 'This reel is not ready to share yet', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }
    final sent = await ShareToChatService.share(
      context: hostContext,
      type: SharedContentType.feed,
      contentId: feedId,
    );
    if (sent) {
      unawaited(_feedRepo.recordFeedShareRepo(feedId, channel: 'chat'));
      _bumpShareCount(post, onSharesChanged);
    }
  }

  static Future<void> showShareMenu({
    required BuildContext hostContext,
    required Map<String, dynamic> post,
    VoidCallback? onSharesChanged,
  }) async {
    if (!hostContext.mounted) return;
    final feedId = feedIdFromPost(post);
    if (feedId == null) {
      Get.snackbar('Cannot share', 'This reel is not ready to share yet', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }

    await showModalBottomSheet<void>(
      context: hostContext,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Text('Share Reel', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Send in chat, copy link, or share to other apps', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _menuAction(
                      icon: Icons.message_outlined,
                      label: 'Send in chat',
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await shareToChat(hostContext: hostContext, post: post, onSharesChanged: onSharesChanged);
                      },
                    ),
                    _menuAction(
                      icon: Icons.link,
                      label: 'Copy link',
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await copyLink(post: post, onSharesChanged: onSharesChanged);
                      },
                    ),
                    _menuAction(
                      icon: Icons.ios_share,
                      label: 'More apps',
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await shareToOtherApps(post: post, onSharesChanged: onSharesChanged);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _menuAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: AppColors.accent, size: 26),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 88,
            child: Text(label, textAlign: TextAlign.center, maxLines: 2, style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface)),
          ),
        ],
      ),
    );
  }
}

void unawaited(Future<void> future) {}
