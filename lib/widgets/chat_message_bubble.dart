import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_right/models/chat_message_model.dart';
import 'package:get_right/models/shared_content_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:get_right/views/chat/chat_image_viewer_screen.dart';
import 'package:get_right/views/chat/chat_video_player_screen.dart';
import 'package:get_right/widgets/chat/shared_content_card.dart';
import 'package:get_right/widgets/chat_audio_message.dart';
import 'package:get_right/widgets/safe_circle_network_avatar.dart';
import 'package:get_right/widgets/safe_network_image.dart';
import 'package:intl/intl.dart';

/// Chat message bubble widget
class ChatMessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isCurrentUser;
  final String? currentUserId;

  const ChatMessageBubble({super.key, required this.message, required this.isCurrentUser, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final displayName = message.displaySenderName;
    final sharedType = SharedContentType.fromApi(message.sharedContentType);
    final isWorkoutShare = sharedType == SharedContentType.workoutJournal && message.sharedContent != null;

    if (isWorkoutShare) {
      return _buildWorkoutShareLayout(context, displayName, sharedType!);
    }

    final outgoingBubble = const Color(0xFFE4EED8);
    final bubbleColor = isCurrentUser ? outgoingBubble : AppColors.white;
    final textColor = AppColors.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[_SenderAvatar(name: displayName, imageUrl: message.senderImage), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: isCurrentUser ? const Radius.circular(4) : null,
                      bottomLeft: !isCurrentUser ? const Radius.circular(4) : null,
                    ),
                    border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMessageContent(context, textColor: textColor),
                      const SizedBox(height: 4),
                      _buildTimestampRow(textColor: AppColors.primaryGrayDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutShareLayout(BuildContext context, String displayName, SharedContentType sharedType) {
    final caption = message.displayCaption.trim().isNotEmpty
        ? message.displayCaption.trim()
        : (message.message.trim().isNotEmpty && message.message.trim() != 'Shared content' ? message.message.trim() : '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[_SenderAvatar(name: displayName, imageUrl: message.senderImage), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (caption.isNotEmpty) ...[
                  Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCurrentUser ? const Color(0xFFE4EED8) : AppColors.white,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isCurrentUser ? const Radius.circular(4) : null,
                        bottomLeft: !isCurrentUser ? const Radius.circular(4) : null,
                      ),
                      border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.18)),
                    ),
                    child: Text(caption, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                  ),
                  const SizedBox(height: 8),
                ],
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                  child: SharedContentCard(
                    type: sharedType,
                    data: message.sharedContent!,
                    isCurrentUser: isCurrentUser,
                  ),
                ),
                const SizedBox(height: 4),
                _buildTimestampRow(textColor: AppColors.primaryGrayDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampRow({required Color textColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Text(
          _formatTimestamp(message.timestamp),
          style: AppTextStyles.labelSmall.copyWith(color: textColor.withValues(alpha: 0.8)),
        ),
        if (isCurrentUser && !message.isPending) ...[
          const SizedBox(width: 4),
          Icon(
            message.isRead ? Icons.done_all : Icons.done,
            size: 14,
            color: message.isRead ? AppColors.accent : AppColors.primaryGray,
          ),
        ],
      ],
    );
  }

  Widget _buildMessageContent(BuildContext context, {required Color textColor}) {
    final sharedType = SharedContentType.fromApi(message.sharedContentType);
    final sharedWidget = sharedType != null && message.sharedContent != null
        ? SharedContentCard(type: sharedType, data: message.sharedContent!, isCurrentUser: isCurrentUser)
        : null;

    Widget? body;
    switch (message.type) {
      case 'image':
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.hasMediaAttachments) _buildImageAttachments(context),
            if (message.displayCaption.isNotEmpty) ...[
              if (message.hasMediaAttachments) const SizedBox(height: 8),
              Text(message.displayCaption, style: AppTextStyles.bodyMedium.copyWith(color: textColor)),
            ],
          ],
        );
        break;
      case 'video':
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.fileUrl != null)
              _buildPendingWrapper(
                child: message.isPending
                    ? const _LocalVideoPreview()
                    : _VideoAttachmentPreview(
                        videoUrl: message.fileUrl!,
                        thumbnailUrl: message.thumbnailUrl ?? (message.displayAttachments.isNotEmpty ? message.displayAttachments.first.thumbnailUrl : null),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatVideoPlayerScreen(videoUrl: message.fileUrl!, title: message.fileName ?? 'Video'),
                            ),
                          );
                        },
                      ),
              ),
            if (message.displayCaption.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message.displayCaption, style: AppTextStyles.bodyMedium.copyWith(color: textColor)),
            ] else if (message.message.isNotEmpty && message.message != '🎥 Video') ...[
              const SizedBox(height: 8),
              Text(message.message, style: AppTextStyles.bodyMedium.copyWith(color: textColor)),
            ],
          ],
        );
        break;
      case 'audio':
        body = ChatAudioMessage(message: message, isCurrentUser: isCurrentUser);
        break;
      default:
        final text = message.displayCaption.isNotEmpty ? message.displayCaption : message.message;
        body = text.trim().isNotEmpty
            ? Text(text, style: AppTextStyles.bodyMedium.copyWith(color: textColor))
            : null;
    }

    if (sharedWidget == null) return body ?? const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (body != null && message.displayCaption.isNotEmpty && message.type != 'image' && message.type != 'video') ...[
          body,
          const SizedBox(height: 8),
        ] else if (body != null && (message.type == 'image' || message.type == 'video' || message.type == 'audio')) ...[
          body,
          const SizedBox(height: 8),
        ],
        sharedWidget,
      ],
    );
  }

  Widget _buildImageAttachments(BuildContext context) {
    final attachments = message.displayAttachments.where((a) => a.isImage).toList();
    if (attachments.isEmpty) return const SizedBox.shrink();

    if (attachments.length == 1) {
      return _buildPendingWrapper(
        child: _buildImageTile(attachments.first, width: 220, height: 220, onTap: message.isPending ? null : () => _openImageViewer(context, attachments, 0)),
      );
    }

    const tileSize = 104.0;
    const spacing = 4.0;
    final columns = attachments.length == 2 ? 2 : 2;
    final visible = attachments.length > 4 ? attachments.take(4).toList() : attachments;
    final extraCount = attachments.length - visible.length;

    return _buildPendingWrapper(
      child: SizedBox(
        width: tileSize * columns + spacing * (columns - 1),
        child: Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < visible.length; i++)
              Stack(
                children: [
                  _buildImageTile(visible[i], width: tileSize, height: tileSize, onTap: message.isPending ? null : () => _openImageViewer(context, attachments, i)),
                  if (extraCount > 0 && i == visible.length - 1)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(8)),
                          alignment: Alignment.center,
                          child: Text(
                            '+$extraCount',
                            style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _openImageViewer(BuildContext context, List<ChatAttachment> attachments, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatImageViewerScreen(attachments: attachments, initialIndex: initialIndex, title: message.fileName ?? 'Photo'),
      ),
    );
  }

  String? _resolvedImageUrl(ChatAttachment attachment) {
    if (attachment.isLocal) return attachment.url;
    return ImageUrlSanitizer.resolveMediaUrl(attachment.url) ?? ImageUrlSanitizer.asHttpUrlOrNull(attachment.url);
  }

  Widget _buildPendingWrapper({required Widget child}) {
    if (!message.isPending) return child;

    final count = message.displayAttachments.length;
    final label = count > 1 ? 'Sending $count photos...' : 'Sending...';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: isCurrentUser ? AppColors.onAccent : AppColors.accent)),
                    if (count > 1) ...[
                      const SizedBox(height: 8),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelSmall.copyWith(color: isCurrentUser ? AppColors.onAccent : AppColors.onSurface, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageTile(ChatAttachment attachment, {required double width, required double height, VoidCallback? onTap}) {
    final borderRadius = BorderRadius.circular(8);

    Widget imageWidget;
    if (attachment.isLocal) {
      imageWidget = Image.file(File(attachment.url), width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _brokenImagePlaceholder(width, height));
    } else {
      final imageUrl = _resolvedImageUrl(attachment);
      if (imageUrl == null || imageUrl.isEmpty) {
        imageWidget = _brokenImagePlaceholder(width, height);
      } else {
        imageWidget = SafeNetworkImage(
          url: imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          fallback: _brokenImagePlaceholder(width, height),
        );
      }
    }

    final tile = ClipRRect(borderRadius: borderRadius, child: imageWidget);

    if (onTap == null) return tile;

    return GestureDetector(onTap: onTap, child: tile);
  }

  Widget _brokenImagePlaceholder(double width, double height) {
    return Container(width: width, height: height, color: AppColors.primaryGray, child: const Icon(Icons.broken_image, size: 48));
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final local = timestamp.toLocal();
    final difference = now.difference(local);
    final time = DateFormat('h:mm a').format(local);

    if (difference.inDays == 0 && now.day == local.day) {
      return time;
    } else if (difference.inDays <= 1 && now.difference(DateTime(local.year, local.month, local.day)).inDays == 1) {
      return 'Yesterday $time';
    } else if (difference.inDays < 7) {
      return '${DateFormat('EEE').format(local)} $time';
    } else {
      return DateFormat('MMM d, h:mm a').format(local);
    }
  }
}

class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return SafeCircleNetworkAvatar(
      radius: 18,
      imageUrl: imageUrl,
      backgroundColor: AppColors.accent.withValues(alpha: 0.15),
      fallback: Text(
        initial,
        style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _LocalVideoPreview extends StatelessWidget {
  const _LocalVideoPreview();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 220,
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.primaryGray),
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                child: const Icon(Icons.videocam, color: Colors.white, size: 36),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoAttachmentPreview extends StatelessWidget {
  const _VideoAttachmentPreview({required this.videoUrl, required this.onTap, this.thumbnailUrl});

  final String videoUrl;
  final String? thumbnailUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 220,
          height: 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty)
                SafeNetworkImage(
                  url: thumbnailUrl,
                  fit: BoxFit.cover,
                  fallback: Container(color: AppColors.primaryGray),
                )
              else
                Container(color: AppColors.primaryGray),
              Container(color: Colors.black.withValues(alpha: 0.25)),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(6)),
                  child: Text('Tap to play', style: AppTextStyles.labelSmall.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
