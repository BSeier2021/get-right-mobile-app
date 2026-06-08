import 'dart:async';
import 'package:get/get.dart';
import 'package:get_right/models/chat_message_model.dart';
import 'package:get_right/repo/chat_repo.dart';
import 'package:get_right/services/api_service.dart';
import 'package:get_right/services/storage_service.dart';

/// Chat Controller - Manages chat functionality
class ChatController extends GetxController {
  final ApiService _apiService;
  final StorageService _storageService;
  final ChatRepository _chatRepo = ChatRepository();

  ChatController(this._apiService, this._storageService);

  // Observable lists
  final RxList<ConversationModel> conversations = <ConversationModel>[].obs;
  final RxList<ChatMessageModel> messages = <ChatMessageModel>[].obs;
  final RxList<String> blockedUsers = <String>[].obs;

  // State
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMessages = false.obs;
  final RxBool isLoadingMoreMessages = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isSending = false.obs;
  final RxInt totalUnreadCount = 0.obs;
  final RxBool hasNextPage = false.obs;
  final RxBool hasNextMessagesPage = false.obs;
  final Rxn<String> currentConversationId = Rxn<String>();
  final Rxn<String> currentTrainerId = Rxn<String>();
  final Rxn<String> currentProgramId = Rxn<String>();

  static const int _pageLimit = 10;
  static const int _messagesPageLimit = 20;
  int _currentPage = 1;
  int _messagesPage = 1;
  String _currentSearch = '';

  // Timer for polling messages (simulating real-time)
  Timer? _messagePollTimer;

  @override
  void onInit() {
    super.onInit();
    loadUnreadCount();
  }

  @override
  void onClose() {
    _messagePollTimer?.cancel();
    super.onClose();
  }

  /// Get current user ID
  String? get currentUserId => _storageService.getUserId();

  /// Load conversations from `GET /user/chat/conversations`.
  Future<void> loadConversations({int page = 1, String? search, bool append = false}) async {
    try {
      if (append) {
        isLoadingMore.value = true;
      } else {
        isLoading.value = true;
      }

      final query = search ?? _currentSearch;
      _currentSearch = query;
      _currentPage = page;

      final result = await _chatRepo.fetchConversations(page: page, limit: _pageLimit, search: query);
      if (append && page > 1) {
        conversations.addAll(result.conversations);
      } else {
        conversations.value = result.conversations;
      }
      hasNextPage.value = result.hasNextPage;
      await loadUnreadCount();
    } catch (e) {
      if (!append) {
        Get.snackbar('Error', 'Failed to load conversations: $e');
      }
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMoreConversations() async {
    if (isLoadingMore.value || !hasNextPage.value) return;
    await loadConversations(page: _currentPage + 1, append: true);
  }

  /// `GET /user/chat/conversations/unread-count`
  Future<void> loadUnreadCount() async {
    try {
      totalUnreadCount.value = await _chatRepo.fetchUnreadCount();
    } catch (_) {
      totalUnreadCount.value = conversations.fold(0, (sum, c) => sum + c.unreadCount);
    }
  }

  Future<void> refreshConversations() => loadConversations(page: 1, search: _currentSearch);

  /// `GET /user/chat/conversations/with/:otherUserId`
  Future<ConversationModel?> startConversationWithUser(String otherUserId) async {
    final id = otherUserId.trim();
    if (id.isEmpty) return null;

    try {
      isLoading.value = true;
      final conversation = await _chatRepo.createConversationWith(id);
      final index = conversations.indexWhere((c) => c.id == conversation.id);
      if (index >= 0) {
        conversations[index] = conversation;
      } else {
        conversations.insert(0, conversation);
      }
      await loadUnreadCount();
      return conversation;
    } catch (e) {
      Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''));
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// Start a conversation with a trainer for a program
  Future<String?> startConversation({required String trainerId, required String trainerName, String? trainerImage, required String programId, required String programTitle}) async {
    try {
      isLoading.value = true;
      final userId = currentUserId;
      if (userId == null) return null;

      // Check if conversation already exists
      final existing = conversations.firstWhereOrNull((c) => c.trainerId == trainerId && c.programId == programId);

      if (existing != null) {
        return existing.id;
      }

      // Create new conversation
      final conversationId = await _apiService.createConversation(
        userId: userId,
        trainerId: trainerId,
        trainerName: trainerName,
        trainerImage: trainerImage,
        programId: programId,
        programTitle: programTitle,
      );

      // Reload conversations
      await refreshConversations();

      return conversationId;
    } catch (e) {
      Get.snackbar('Error', 'Failed to start conversation: $e');
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// Load messages for a conversation
  Future<void> loadMessages(String conversationId, {String? trainerId, String? programId}) async {
    try {
      isLoadingMessages.value = true;
      currentConversationId.value = conversationId;
      if (trainerId != null) currentTrainerId.value = trainerId;
      if (programId != null) currentProgramId.value = programId;

      _messagesPage = 1;
      final result = await _chatRepo.fetchMessages(conversationId, page: 1, limit: _messagesPageLimit);
      messages.value = result.messages;
      hasNextMessagesPage.value = result.hasNextPage;
      _messagesPage = result.currentPage;
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      _startMessagePolling(conversationId);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load messages: $e');
    } finally {
      isLoadingMessages.value = false;
    }
  }

  /// Load older messages (pagination).
  Future<void> loadMoreMessages() async {
    final conversationId = currentConversationId.value;
    if (conversationId == null || isLoadingMoreMessages.value || !hasNextMessagesPage.value) return;

    try {
      isLoadingMoreMessages.value = true;
      final nextPage = _messagesPage + 1;
      final result = await _chatRepo.fetchMessages(conversationId, page: nextPage, limit: _messagesPageLimit);

      final existingIds = messages.map((m) => m.id).toSet();
      final older = result.messages.where((m) => !existingIds.contains(m.id)).toList();
      if (older.isNotEmpty) {
        messages.addAll(older);
        messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }

      _messagesPage = result.currentPage;
      hasNextMessagesPage.value = result.hasNextPage;
    } catch (_) {
      // Silent fail for pagination
    } finally {
      isLoadingMoreMessages.value = false;
    }
  }

  /// Send a text message
  Future<void> sendMessage(String message) async {
    final conversationId = currentConversationId.value;
    if (message.trim().isEmpty || conversationId == null) return;

    try {
      isSending.value = true;
      final userId = currentUserId;
      if (userId == null) return;

      final trainerId = currentTrainerId.value ?? '';

      // Optimistically add message to UI
      final tempMessage = ChatMessageModel(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: conversationId,
        senderId: userId,
        receiverId: trainerId,
        message: message.trim(),
        type: 'text',
        timestamp: DateTime.now(),
      );
      messages.insert(0, tempMessage);

      // Send to API
      final response = await _apiService.sendMessage(conversationId: conversationId, senderId: userId, receiverId: trainerId, message: message.trim(), type: 'text');

      // Replace temp message with actual message from server
      final actualMessage = ChatMessageModel.fromJson(response);
      final messageIndex = messages.indexWhere((m) => m.id == tempMessage.id);
      if (messageIndex != -1) {
        messages[messageIndex] = actualMessage;
      } else {
        // If temp message was removed somehow, just add the actual message
        messages.insert(0, actualMessage);
      }

      // Sort messages by timestamp (newest first since list is reversed)
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      Get.snackbar('Error', 'Failed to send message: $e');
      // Remove failed message
      messages.removeWhere((m) => m.id.startsWith('temp_'));
    } finally {
      isSending.value = false;
    }
  }

  /// Send a file message (image, video, audio)
  Future<void> sendFileMessage({
    required String filePath,
    required String type, // 'image', 'video', 'audio'
    String? fileName,
  }) async {
    final conversationId = currentConversationId.value;
    if (conversationId == null) return;

    try {
      isSending.value = true;
      final userId = currentUserId;
      if (userId == null) return;

      final trainerId = currentTrainerId.value ?? '';

      // Upload file first
      final uploadResponse = await _apiService.uploadChatFile(filePath: filePath, conversationId: conversationId, type: type);

      final fileUrl = uploadResponse['fileUrl'] as String?;
      if (fileUrl == null) {
        throw Exception('File upload failed');
      }

      // Send message with file
      final response = await _apiService.sendMessage(
        conversationId: conversationId,
        senderId: userId,
        receiverId: trainerId,
        message: type == 'image'
            ? '📷 Photo'
            : type == 'video'
            ? '🎥 Video'
            : '🎤 Audio',
        type: type,
        fileUrl: fileUrl,
        fileName: fileName ?? filePath.split('/').last,
      );

      // Add message to list
      final fileMessage = ChatMessageModel.fromJson(response);
      messages.insert(0, fileMessage);

      // Sort messages by timestamp (newest first since list is reversed)
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      Get.snackbar('Error', 'Failed to send file: $e');
    } finally {
      isSending.value = false;
    }
  }

  /// Mark messages as read
  Future<void> markAsRead(String conversationId) async {
    try {
      await _apiService.markMessagesAsRead(conversationId);
      // Update local messages
      for (var message in messages) {
        if (message.conversationId == conversationId && !message.isRead) {
          messages[messages.indexOf(message)] = message.copyWith(isRead: true);
        }
      }
      // Update conversation unread count
      await refreshConversations();
    } catch (e) {
      // Silent fail
    }
  }

  /// Report a trainer
  Future<void> reportTrainer({required String trainerId, required String reason, String? description}) async {
    try {
      isLoading.value = true;
      final userId = currentUserId;
      final conversationId = currentConversationId.value;
      if (userId == null || conversationId == null) return;

      await _apiService.reportTrainer(conversationId: conversationId, reporterId: userId, reportedUserId: trainerId, reason: reason, description: description);

      Get.snackbar('Success', 'Report submitted. Thank you for your feedback.');
    } catch (e) {
      Get.snackbar('Error', 'Failed to submit report: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Block a trainer
  Future<void> blockTrainer(String trainerId, {String? reason}) async {
    try {
      isLoading.value = true;
      final userId = currentUserId;
      if (userId == null) return;

      await _apiService.blockUser(blockerId: userId, blockedUserId: trainerId, reason: reason);

      blockedUsers.add(trainerId);
      Get.snackbar('Success', 'Trainer blocked successfully.');
    } catch (e) {
      Get.snackbar('Error', 'Failed to block trainer: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Unblock a trainer
  Future<void> unblockTrainer(String trainerId) async {
    try {
      isLoading.value = true;
      final userId = currentUserId;
      if (userId == null) return;

      await _apiService.unblockUser(blockerId: userId, blockedUserId: trainerId);

      blockedUsers.remove(trainerId);
      Get.snackbar('Success', 'Trainer unblocked successfully.');
    } catch (e) {
      Get.snackbar('Error', 'Failed to unblock trainer: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Check if a user is blocked
  bool isBlocked(String userId) {
    return blockedUsers.contains(userId);
  }

  /// Start polling for new messages (simulating real-time)
  void _startMessagePolling(String conversationId) {
    _messagePollTimer?.cancel();
    _messagePollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final result = await _chatRepo.fetchMessages(conversationId, page: 1, limit: _messagesPageLimit);
        final existingMessageIds = messages.map((m) => m.id).toSet();
        final newMessagesFromServer = result.messages.where((msg) => !existingMessageIds.contains(msg.id)).toList();

        if (newMessagesFromServer.isNotEmpty) {
          messages.addAll(newMessagesFromServer);
          messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        }
      } catch (e) {
        // Silent fail for polling
      }
    });
  }

  /// Stop polling
  void stopPolling() {
    _messagePollTimer?.cancel();
    _messagePollTimer = null;
  }

  /// Clear current conversation
  void clearConversation() {
    stopPolling();
    messages.clear();
    currentConversationId.value = null;
    currentTrainerId.value = null;
    currentProgramId.value = null;
    _messagesPage = 1;
    hasNextMessagesPage.value = false;
  }
}
