import 'package:flutter/material.dart';
import 'package:get_right/models/chat_message_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/chat/chat_video_player_screen.dart';
import 'package:get_right/widgets/chat_audio_message.dart';
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            _SenderAvatar(name: displayName, imageUrl: message.senderImage),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(displayName, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w600)),
                  ),
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrentUser ? AppColors.accent : AppColors.surface,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: isCurrentUser ? const Radius.circular(4) : null,
                      bottomLeft: !isCurrentUser ? const Radius.circular(4) : null,
                    ),
                    border: isCurrentUser ? null : Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMessageContent(context),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTimestamp(message.timestamp),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: isCurrentUser ? AppColors.onAccent.withOpacity(0.7) : AppColors.onSurface.withOpacity(0.7),
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 4),
                            Icon(
                              message.isRead ? Icons.done_all : Icons.done,
                              size: 14,
                              color: message.isRead ? AppColors.onAccent.withOpacity(0.7) : AppColors.onAccent.withOpacity(0.5),
                            ),
                          ],
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
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (message.type) {
      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.fileUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  message.fileUrl!,
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 220,
                    height: 220,
                    color: AppColors.primaryGray,
                    child: const Icon(Icons.broken_image, size: 48),
                  ),
                ),
              ),
            if (message.message.isNotEmpty && message.message != '📷 Photo') ...[
              const SizedBox(height: 8),
              Text(message.message, style: AppTextStyles.bodyMedium.copyWith(color: isCurrentUser ? AppColors.onAccent : AppColors.onSurface)),
            ],
          ],
        );
      case 'video':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.fileUrl != null)
              _VideoAttachmentPreview(
                videoUrl: message.fileUrl!,
                thumbnailUrl: message.thumbnailUrl,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatVideoPlayerScreen(
                        videoUrl: message.fileUrl!,
                        title: message.fileName ?? 'Video',
                      ),
                    ),
                  );
                },
              ),
            if (message.message.isNotEmpty && message.message != '🎥 Video') ...[
              const SizedBox(height: 8),
              Text(message.message, style: AppTextStyles.bodyMedium.copyWith(color: isCurrentUser ? AppColors.onAccent : AppColors.onSurface)),
            ],
          ],
        );
      case 'audio':
        return ChatAudioMessage(message: message, isCurrentUser: isCurrentUser);
      default:
        return Text(message.message, style: AppTextStyles.bodyMedium.copyWith(color: isCurrentUser ? AppColors.onAccent : AppColors.onSurface));
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(timestamp)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE HH:mm').format(timestamp);
    } else {
      return DateFormat('MMM d, HH:mm').format(timestamp);
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
    final hasImage = imageUrl != null && imageUrl!.startsWith('http');

    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.accent.withOpacity(0.15),
      backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
      child: hasImage
          ? null
          : Text(initial, style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700)),
    );
  }
}

class _VideoAttachmentPreview extends StatelessWidget {
  const _VideoAttachmentPreview({
    required this.videoUrl,
    required this.onTap,
    this.thumbnailUrl,
  });

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
              if (thumbnailUrl != null && thumbnailUrl!.startsWith('http'))
                Image.network(
                  thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: AppColors.primaryGray),
                )
              else
                Container(color: AppColors.primaryGray),
              Container(color: Colors.black.withOpacity(0.25)),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(6)),
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
