import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_right/models/chat_message_model.dart';
import 'package:get_right/repo/chat_repo.dart';
import 'package:get_right/services/api_service.dart';
import 'package:get_right/services/chat_audio_player_service.dart';
import 'package:get_right/services/chat_socket_service.dart';
import 'package:get_right/services/storage_service.dart';

/// Chat Controller - Manages chat functionality
class ChatController extends GetxController {
  final ApiService _apiService;
  final StorageService _storageService;
  final ChatRepository _chatRepo = ChatRepository();
  final ChatSocketService _chatSocket = ChatSocketService.instance;

  ChatController(this._apiService, this._storageService);

  StreamSubscription<Map<String, dynamic>>? _userTypingSub;
  StreamSubscription<Map<String, dynamic>>? _userStatusSub;
  StreamSubscription<bool>? _connectionSub;
  Timer? _typingIdleTimer;
  Timer? _remoteTypingClearTimer;
  bool _isLocalTyping = false;
  bool _socketListenersAttached = false;

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
  final RxBool isOtherUserTyping = false.obs;
  final Rxn<String> currentConversationId = Rxn<String>();
  final Rxn<String> currentTrainerId = Rxn<String>();
  final Rxn<String> currentProgramId = Rxn<String>();
  final Map<String, ChatParticipantProfile> _participantProfiles = {};

  static const int _pageLimit = 10;
  static const int _messagesPageLimit = 20;
  int _currentPage = 1;
  int _messagesPage = 1;
  String _currentSearch = '';

  @override
  void onInit() {
    super.onInit();
    loadUnreadCount();
    _attachSocketListeners();
    unawaited(_ensureSocketConnected());
  }

  @override
  void onClose() {
    _detachSocketListeners();
    _typingIdleTimer?.cancel();
    _remoteTypingClearTimer?.cancel();
    _leaveConversationSocket();
    super.onClose();
  }

  void _attachSocketListeners() {
    if (_socketListenersAttached) return;
    _socketListenersAttached = true;

    _chatSocket.onMessageReceived = _handleSocketNewMessage;
    _userTypingSub = _chatSocket.onUserTyping.listen(_handleSocketUserTyping);
    _userStatusSub = _chatSocket.onUserStatusChanged.listen(_handleSocketUserStatusChanged);
    _connectionSub = _chatSocket.onConnectionChanged.listen((connected) {
      if (!connected) return;
      final conversationId = currentConversationId.value;
      if (conversationId != null && conversationId.isNotEmpty) {
        unawaited(_chatSocket.joinConversation(conversationId));
      }
    });
  }

  void _detachSocketListeners() {
    _chatSocket.onMessageReceived = null;
    _userTypingSub?.cancel();
    _userStatusSub?.cancel();
    _connectionSub?.cancel();
    _userTypingSub = null;
    _userStatusSub = null;
    _connectionSub = null;
    _socketListenersAttached = false;
  }

  Future<void> _ensureSocketConnected() async {
    if (!_chatSocket.isConnected) {
      await _chatSocket.connect();
    }
  }

  /// Connect socket and join the active conversation room.
  Future<void> _enterActiveConversation(String conversationId) async {
    _attachSocketListeners();
    if (!_chatSocket.isConnected) {
      await _chatSocket.connect();
    }
    await _chatSocket.joinConversation(conversationId);
  }

  void _leaveConversationSocket() {
    final conversationId = currentConversationId.value;
    if (conversationId == null) return;
    stopTypingInRoom();
    _chatSocket.leaveConversation(conversationId);
    isOtherUserTyping.value = false;
  }

  void _handleSocketNewMessage(Map<String, dynamic> payload) {
    // Socket service already unwraps nested { data: { message } } envelopes.
    final messageRaw = _extractSocketMessage(payload) ?? payload;
    var conversationId = _extractConversationId(messageRaw, payload);
    if (conversationId.isEmpty) {
      conversationId = currentConversationId.value ?? '';
    }
    if (conversationId.isEmpty) {
      debugPrint('[Chat] socket message ignored: no conversationId');
      return;
    }

    final message = _enrichMessage(ChatMessageModel.fromApi(_withConversationId(messageRaw, conversationId)));
    if (message.id.isEmpty) {
      debugPrint('[Chat] socket message ignored: empty id ($messageRaw)');
      return;
    }

    _updateConversationPreview(message);

    final activeId = currentConversationId.value;
    if (activeId == null || activeId.isEmpty || !_isSameConversation(activeId, conversationId)) {
      loadUnreadCount();
      return;
    }

    if (messages.any((m) => m.id == message.id)) return;

    messages.value = [message, ...messages];
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    debugPrint('[Chat] socket message added: ${message.id}');
  }

  Map<String, dynamic>? _extractSocketMessage(Map<String, dynamic> payload) {
    if (_looksLikeMessage(payload)) return payload;

    Map<String, dynamic>? fromMap(Map<String, dynamic> root) {
      final nestedMessage = root['message'];
      if (nestedMessage is Map) {
        return Map<String, dynamic>.from(nestedMessage);
      }
      if (_looksLikeMessage(root)) return root;
      final data = root['data'];
      if (data is Map) return fromMap(Map<String, dynamic>.from(data));
      return null;
    }

    return fromMap(_unwrapSocketPayload(payload));
  }

  String _extractConversationId(Map<String, dynamic> messageRaw, Map<String, dynamic> payload) {
    final conv = messageRaw['conversationId'] ?? messageRaw['conversation'] ?? payload['conversationId'] ?? currentConversationId.value;

    if (conv is Map) {
      return _chatStr(conv['_id'] ?? conv['id']);
    }
    return _chatStr(conv);
  }

  bool _isSameConversation(String? a, String? b) {
    if (a == null || b == null) return false;
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }

  Map<String, dynamic> _unwrapSocketPayload(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return payload;
  }

  bool _looksLikeMessage(Map<String, dynamic> json) {
    return json.containsKey('_id') ||
        json.containsKey('id') ||
        json.containsKey('content') ||
        json.containsKey('message') ||
        json.containsKey('text') ||
        json.containsKey('messageType');
  }

  void _handleSocketUserTyping(Map<String, dynamic> payload) {
    final root = _unwrapSocketPayload(payload);
    final conversationId = _chatStr(root['conversationId'] ?? payload['conversationId']);
    if (conversationId.isEmpty || !_isSameConversation(currentConversationId.value, conversationId)) return;

    final typingUserId = _chatStr(payload['userId'] ?? payload['user'] ?? payload['senderId'] ?? payload['sender']);
    final me = currentUserId;
    if (me != null && typingUserId.isNotEmpty && typingUserId == me) return;

    if (payload.containsKey('isTyping') || payload.containsKey('typing') || payload.containsKey('status')) {
      final isTyping = payload['isTyping'] == true || payload['typing'] == true || payload['status'] == 'typing';
      isOtherUserTyping.value = isTyping;
      if (!isTyping) {
        _remoteTypingClearTimer?.cancel();
      }
      return;
    }

    isOtherUserTyping.value = true;
    _remoteTypingClearTimer?.cancel();
    _remoteTypingClearTimer = Timer(const Duration(seconds: 3), () {
      isOtherUserTyping.value = false;
    });
  }

  void _handleSocketUserStatusChanged(Map<String, dynamic> payload) {
    final userId = _chatStr(payload['userId'] ?? payload['user'] ?? payload['_id'] ?? payload['id']);
    if (userId.isEmpty) return;

    final isOnline = payload['isOnline'] == true || payload['status'] == 'online' || payload['online'] == true;
    final profile = _participantProfiles[userId];
    if (profile != null) {
      _participantProfiles[userId] = profile.copyWith(isOnline: isOnline);
    }

    final me = currentUserId;
    if (me != null && userId != me) {
      messages.refresh();
    }
  }

  void _updateConversationPreview(ChatMessageModel message) {
    final index = conversations.indexWhere((c) => c.id == message.conversationId);
    if (index < 0) return;

    final current = conversations[index];
    final isActiveConversation = currentConversationId.value == message.conversationId;
    final senderId = message.senderId;
    final me = currentUserId;
    final unreadDelta = (!isActiveConversation && me != null && senderId != me) ? 1 : 0;

    conversations[index] = current.copyWith(lastMessage: message, updatedAt: message.timestamp, unreadCount: isActiveConversation ? 0 : current.unreadCount + unreadDelta);

    if (index > 0) {
      final updated = conversations.removeAt(index);
      conversations.insert(0, updated);
    }
  }

  Map<String, dynamic> _withConversationId(Map<String, dynamic> json, String conversationId) {
    if (_chatStr(json['conversationId'] ?? json['conversation']).isEmpty) {
      return {...json, 'conversationId': conversationId};
    }
    return json;
  }

  String _chatStr(dynamic value) => value?.toString().trim() ?? '';

  /// Emit typing-start while composing; auto typing-stop after idle.
  void notifyTypingInRoom(String text) {
    final conversationId = currentConversationId.value;
    if (conversationId == null) return;

    if (text.trim().isEmpty) {
      stopTypingInRoom();
      return;
    }

    if (!_isLocalTyping) {
      _isLocalTyping = true;
      _chatSocket.typingStart(conversationId);
    }

    _typingIdleTimer?.cancel();
    _typingIdleTimer = Timer(const Duration(seconds: 2), stopTypingInRoom);
  }

  void stopTypingInRoom() {
    _typingIdleTimer?.cancel();
    final conversationId = currentConversationId.value;
    if (conversationId == null) return;

    if (_isLocalTyping) {
      _isLocalTyping = false;
      _chatSocket.typingStop(conversationId);
    }
  }

  /// Call when leaving the chat room screen.
  void leaveActiveConversation() {
    _leaveConversationSocket();
  }

  /// Re-join socket room when chat screen becomes visible again.
  Future<void> resumeActiveConversation() async {
    final conversationId = currentConversationId.value;
    if (conversationId == null || conversationId.isEmpty) return;
    _attachSocketListeners();
    await _chatSocket.joinConversation(conversationId);
  }

  /// Get current user ID
  String? get currentUserId => _storageService.getUserId();

  ChatMessageModel _enrichMessage(ChatMessageModel message) {
    if ((message.senderName?.trim().isNotEmpty ?? false) && message.senderImage != null) return message;
    final profile = _participantProfiles[message.senderId];
    if (profile == null) return message;
    return message.copyWith(senderName: (message.senderName?.trim().isNotEmpty ?? false) ? message.senderName : profile.name, senderImage: message.senderImage ?? profile.imageUrl);
  }

  List<ChatMessageModel> _enrichMessages(List<ChatMessageModel> list) => list.map(_enrichMessage).toList();

  /// Other participant in the active conversation (not the logged-in user).
  ChatParticipantProfile? get otherParticipant {
    final me = currentUserId?.trim();
    if (me == null || me.isEmpty) {
      return _participantProfiles.values.isNotEmpty ? _participantProfiles.values.first : null;
    }
    for (final profile in _participantProfiles.values) {
      if (profile.id != me) return profile;
    }
    return null;
  }

  void _applyMessagesPage(ChatMessagesPage result) {
    if (result.participantProfiles.isNotEmpty) {
      _participantProfiles.addAll(result.participantProfiles);
    }
    messages.value = _enrichMessages(result.messages);
    hasNextMessagesPage.value = result.hasNextPage;
    _messagesPage = result.currentPage;
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

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

      final result = await _chatRepo.fetchConversations(page: page, limit: _pageLimit, search: query, currentUserId: currentUserId);
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
      final conversation = await _chatRepo.createConversationWith(id, currentUserId: currentUserId);
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
      _applyMessagesPage(result);
      await _enterActiveConversation(conversationId);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load messages: $e');
    } finally {
      isLoadingMessages.value = false;
    }
  }

  /// Manual refresh (pull-to-refresh only — live updates come from socket).
  Future<void> refreshMessages() async {
    final conversationId = currentConversationId.value;
    if (conversationId == null || isLoadingMessages.value) return;

    try {
      _messagesPage = 1;
      final result = await _chatRepo.fetchMessages(conversationId, page: 1, limit: _messagesPageLimit);
      _applyMessagesPage(result);
    } catch (e) {
      Get.snackbar('Error', 'Failed to refresh messages: $e');
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
      if (result.participantProfiles.isNotEmpty) {
        _participantProfiles.addAll(result.participantProfiles);
      }
      final older = _enrichMessages(result.messages.where((m) => !existingIds.contains(m.id)).toList());
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

      // Optimistically add message to UI
      final profile = _participantProfiles[userId];
      final tempMessage = ChatMessageModel(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: conversationId,
        senderId: userId,
        receiverId: currentTrainerId.value ?? '',
        message: message.trim(),
        type: 'text',
        senderName: profile?.name ?? _storageService.getName(),
        senderImage: profile?.imageUrl,
        timestamp: DateTime.now(),
      );
      messages.insert(0, tempMessage);

      final actualMessage = _enrichMessage(await _chatRepo.sendMessage(conversationId: conversationId, content: message.trim()));

      final messageIndex = messages.indexWhere((m) => m.id == tempMessage.id);
      if (messageIndex != -1) {
        messages[messageIndex] = actualMessage;
      } else {
        // If temp message was removed somehow, just add the actual message
        messages.insert(0, actualMessage);
      }

      // Sort messages by timestamp (newest first since list is reversed)
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      stopTypingInRoom();
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
      if (currentUserId == null) return;

      final caption = switch (type) {
        'image' => '📷 Photo',
        'video' => '🎥 Video',
        'audio' => '🎤 Audio',
        _ => '📎 Attachment',
      };

      final fileMessage = _enrichMessage(await _chatRepo.sendMessage(conversationId: conversationId, content: caption, attachmentPath: filePath));

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

  /// `DELETE /user/chat/messages/:messageId`
  Future<void> deleteMessage(String messageId) async {
    final id = messageId.trim();
    if (id.isEmpty || id.startsWith('temp_')) return;

    try {
      if (ChatAudioPlayerService.instance.isActive(id)) {
        await ChatAudioPlayerService.instance.stop();
      }

      await _chatRepo.deleteMessage(id);
      messages.removeWhere((m) => m.id == id);
    } catch (e) {
      Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''));
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

  /// Clear current conversation
  void clearConversation() {
    _leaveConversationSocket();
    messages.clear();
    currentConversationId.value = null;
    currentTrainerId.value = null;
    currentProgramId.value = null;
    _messagesPage = 1;
    hasNextMessagesPage.value = false;
    _participantProfiles.clear();
  }
}
