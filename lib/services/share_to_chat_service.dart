import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/shared_content_model.dart';
import 'package:get_right/repo/chat_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/widgets/chat/conversation_picker_sheet.dart';

/// Opens conversation picker and sends shared content to chat.
class ShareToChatService {
  ShareToChatService._();

  static final ChatRepository _chatRepo = ChatRepository();

  static Future<bool> share({
    required BuildContext context,
    required SharedContentType type,
    required String contentId,
    String? caption,
  }) async {
    final id = contentId.trim();
    if (!WorkoutRepository.isValidMongoId(id)) {
      Get.snackbar(
        'Cannot share',
        'This item is not ready to share yet',
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final conversationId = await ConversationPickerSheet.show(context);
    if (conversationId == null || conversationId.trim().isEmpty) return false;
    if (!context.mounted) return false;

    try {
      await _chatRepo.sendSharedContentMessage(
        conversationId: conversationId,
        type: type,
        contentId: id,
        content: caption,
      );
      if (!context.mounted) return true;
      Get.snackbar(
        'Shared',
        'Sent to chat',
        backgroundColor: AppColors.completed,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      Get.snackbar(
        'Could not share',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
  }
}
