import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_right/constants/app_constants.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/models/chat_message_model.dart';
import 'package:get_right/network/network_services.dart';
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
  StreamSubscription<Map<String, dynamic>>? _conversationBlockSub;
  StreamSubscription<Map<String, dynamic>>? _conversationUpdatedSub;
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
  final RxBool isBlockedByMe = false.obs;
  final RxBool isBlockedByOther = false.obs;
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
    _conversationBlockSub = _chatSocket.onConversationBlockChanged.listen(_handleConversationBlockChanged);
    _conversationUpdatedSub = _chatSocket.onConversationUpdated.listen(_handleConversationUpdated);
    _connectionSub = _chatSocket.onConnectionChanged.listen((connected) {
      if (!connected) return;
      final conversationId = currentConversationId.value;
      if (conversationId != null && conversationId.isNotEmpty) {
        unawaited(_chatSocket.joinConversation(conversationId));
        unawaited(refreshConversationBlockStatus());
      }
    });
  }

  void _detachSocketListeners() {
    _chatSocket.onMessageReceived = null;
    _userTypingSub?.cancel();
    _userStatusSub?.cancel();
    _conversationBlockSub?.cancel();
    _conversationUpdatedSub?.cancel();
    _connectionSub?.cancel();
    _userTypingSub = null;
    _userStatusSub = null;
    _conversationBlockSub = null;
    _conversationUpdatedSub = null;
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

    if (!_isViewingConversation(conversationId)) {
      return;
    }

    if (messages.any((m) => m.id == message.id)) return;

    final me = currentUserId;
    if (me != null && message.senderId == me) {
      final tempIndex = messages.indexWhere((m) => m.id.startsWith('temp_') && m.senderId == me);
      if (tempIndex != -1) {
        final tempId = messages[tempIndex].id;
        final audioUrl = message.fileUrl ?? (message.displayAttachments.isNotEmpty ? message.displayAttachments.first.url : null);
        ChatAudioPlayerService.instance.migrateDuration(
          fromMessageId: tempId,
          toMessageId: message.id,
          url: audioUrl,
        );
        messages[tempIndex] = message;
        messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        debugPrint('[Chat] socket replaced temp message: ${message.id}');
        return;
      }
    }

    // Replace optimistic pending upload from current user when socket delivers the real message.
    messages.removeWhere((m) => m.isPending && m.id.startsWith('temp_') && m.senderId == message.senderId);

    if (messages.any((m) => m.id == message.id)) return;

    messages.insert(0, message);
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    debugPrint('[Chat] socket message added: ${message.id}');
  }

  void _upsertMessage(ChatMessageModel message, {String? removeTempId}) {
    if (removeTempId != null) {
      final audioUrl = message.fileUrl ?? (message.displayAttachments.isNotEmpty ? message.displayAttachments.first.url : null);
      ChatAudioPlayerService.instance.migrateDuration(
        fromMessageId: removeTempId,
        toMessageId: message.id,
        url: audioUrl,
      );
      messages.removeWhere((m) => m.id == removeTempId);
    }

    final existingIndex = messages.indexWhere((m) => m.id == message.id);
    if (existingIndex != -1) {
      messages[existingIndex] = message;
    } else {
      messages.insert(0, message);
    }
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
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

  bool _isViewingConversation(String conversationId) {
    final activeId = currentConversationId.value;
    return activeId != null && activeId.isNotEmpty && _isSameConversation(activeId, conversationId);
  }

  int _conversationIndexFor(String conversationId) {
    for (var i = 0; i < conversations.length; i++) {
      if (_isSameConversation(conversations[i].id, conversationId)) return i;
    }
    return -1;
  }

  void _clearLocalUnread(String conversationId) {
    final index = _conversationIndexFor(conversationId);
    if (index < 0) return;

    final current = conversations[index];
    if (current.unreadCount == 0) return;

    conversations[index] = current.copyWith(unreadCount: 0);
    conversations.refresh();
    unawaited(loadUnreadCount());
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
    _applyConversationBlockStatus(payload);

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

  void _handleConversationBlockChanged(Map<String, dynamic> payload) {
    _applyConversationBlockStatus(payload);
  }

  void _handleConversationUpdated(Map<String, dynamic> payload) {
    _applyConversationUnreadFromPayload(payload);
    onConversationUpdated(payload);
    unawaited(loadUnreadCount());
  }

  void _applyConversationUnreadFromPayload(Map<String, dynamic> payload) {
    final conversationId = _extractConversationId(payload, payload);
    if (conversationId.isEmpty) return;

    final unreadCount = _extractUnreadCountFromPayload(payload);
    if (unreadCount == null) return;

    final index = _conversationIndexFor(conversationId);
    if (index < 0) return;

    conversations[index] = conversations[index].copyWith(unreadCount: unreadCount);
    conversations.refresh();
  }

  int? _extractUnreadCountFromPayload(Map<String, dynamic> payload) {
    for (final source in [payload, if (payload['conversation'] is Map) Map<String, dynamic>.from(payload['conversation'] as Map), if (payload['data'] is Map) Map<String, dynamic>.from(payload['data'] as Map)]) {
      for (final key in const ['unreadCount', 'unread']) {
        final value = source[key];
        if (value is num) return value.toInt();
      }
    }
    return null;
  }

  /// Live updates from socket `conversation-updated` (block status, participants, etc.).
  void onConversationUpdated(Map<String, dynamic> payload) {
    final activeId = currentConversationId.value;
    if (activeId == null || activeId.isEmpty) return;

    final conversationId = _extractConversationId(payload, payload);
    if (conversationId.isNotEmpty && !_isSameConversation(activeId, conversationId)) return;

    debugPrint('[Chat] conversation-updated → $conversationId');

    _applyConversationBlockStatus(payload);

    final profiles = ChatRepository.participantProfilesFromPayload(payload);
    if (profiles.isNotEmpty) {
      _participantProfiles.addAll(profiles);
      messages.refresh();
    }
  }

  void _applyConversationBlockStatus(Map<String, dynamic> payload) {
    if (!ConversationBlockStatus.payloadHasBlockStatus(payload)) return;

    final conversationId = _extractConversationId(payload, payload);
    final activeId = currentConversationId.value;
    if (conversationId.isNotEmpty && activeId != null && activeId.isNotEmpty && !_isSameConversation(activeId, conversationId)) {
      return;
    }

    final status = ChatRepository.parseBlockStatusFromPayload(payload);
    isBlockedByMe.value = status.isBlockedByMe;
    isBlockedByOther.value = status.isBlockedByOther || (status.isBlockedByBoth && !status.isBlockedByMe);
    debugPrint('[Chat] block status → me=${isBlockedByMe.value}, other=${isBlockedByOther.value}');
  }

  /// Refresh only conversation block flags (e.g. after resume or socket reconnect).
  Future<void> refreshConversationBlockStatus() async {
    final conversationId = currentConversationId.value;
    if (conversationId == null || conversationId.isEmpty) return;

    try {
      final result = await _chatRepo.fetchMessages(conversationId, page: 1, limit: 1);
      isBlockedByMe.value = result.isBlockedByMe;
      isBlockedByOther.value = result.isBlockedByOther || (result.isBlockedByBoth && !result.isBlockedByMe);
    } catch (_) {
      // Silent — chat history may still be visible.
    }
  }

  void _updateConversationPreview(ChatMessageModel message) {
    final senderId = message.senderId;
    final me = currentUserId;
    final isIncoming = me != null && senderId != me;
    final isViewing = _isViewingConversation(message.conversationId);
    final index = _conversationIndexFor(message.conversationId);

    if (index >= 0) {
      final current = conversations[index];
      final unreadDelta = (!isViewing && isIncoming) ? 1 : 0;

      conversations[index] = current.copyWith(
        lastMessage: message,
        updatedAt: message.timestamp,
        unreadCount: isViewing ? 0 : current.unreadCount + unreadDelta,
      );

      if (index > 0) {
        final updated = conversations.removeAt(index);
        conversations.insert(0, updated);
      }
      conversations.refresh();
    } else if (isIncoming) {
      unawaited(refreshConversations());
    }

    if (!isViewing && isIncoming) {
      unawaited(loadUnreadCount());
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
    final otherUserId = currentTrainerId.value?.trim();
    if (otherUserId != null && otherUserId.isNotEmpty) {
      final profile = _participantProfiles[otherUserId];
      if (profile != null) return profile;
    }
    if (me == null || me.isEmpty) {
      return _participantProfiles.values.isNotEmpty ? _participantProfiles.values.first : null;
    }
    for (final profile in _participantProfiles.values) {
      if (profile.id != me) return profile;
    }
    return null;
  }

  void _seedOtherParticipantProfile({String? userId, String? name, String? imageUrl}) {
    final id = userId?.trim();
    if (id == null || id.isEmpty) return;
    final existing = _participantProfiles[id];
    _participantProfiles[id] = ChatParticipantProfile(
      id: id,
      name: (name?.trim().isNotEmpty ?? false) ? name!.trim() : (existing?.name ?? 'User'),
      imageUrl: imageUrl ?? existing?.imageUrl,
      isOnline: existing?.isOnline,
    );
  }

  void _applyMessagesPage(ChatMessagesPage result) {
    if (result.participantProfiles.isNotEmpty) {
      _participantProfiles.addAll(result.participantProfiles);
    }
    messages.value = _enrichMessages(result.messages);
    hasNextMessagesPage.value = result.hasNextPage;
    _messagesPage = result.currentPage;
    isBlockedByMe.value = result.isBlockedByMe;
    isBlockedByOther.value = result.isBlockedByOther || (result.isBlockedByBoth && !result.isBlockedByMe);
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  bool get canSendMessages => !isBlockedByMe.value && !isBlockedByOther.value;
  bool get hasBlockRestriction => isBlockedByMe.value || isBlockedByOther.value;

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
    if (!_storageService.isLoggedIn()) {
      totalUnreadCount.value = 0;
      return;
    }
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      if (auth.isSessionInvalidating) {
        totalUnreadCount.value = 0;
        return;
      }
    }
    try {
      totalUnreadCount.value = await _chatRepo.fetchUnreadCount();
    } catch (_) {
      if (!_storageService.isLoggedIn()) {
        totalUnreadCount.value = 0;
        return;
      }
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

  /// Switch to a conversation — clears stale room state when the id changes.
  Future<void> switchToConversation(
    String conversationId, {
    String? trainerId,
    String? programId,
    String? trainerName,
    String? trainerImage,
  }) async {
    final id = conversationId.trim();
    if (id.isEmpty) return;

    if (currentConversationId.value != id) {
      clearConversation();
    }

    _seedOtherParticipantProfile(userId: trainerId, name: trainerName, imageUrl: trainerImage);
    await loadMessages(id, trainerId: trainerId, programId: programId);
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
      await refreshConversationBlockStatus();
      _clearLocalUnread(conversationId);
      unawaited(markAsRead(conversationId));
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
    if (message.trim().isEmpty || conversationId == null || !canSendMessages) return;

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

      _upsertMessage(actualMessage, removeTempId: tempMessage.id);
      stopTypingInRoom();
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('block') || message.contains('forbidden')) {
        isBlockedByOther.value = true;
      }
      Get.snackbar('Error', 'Failed to send message: $e');
      // Remove failed message
      messages.removeWhere((m) => m.id.startsWith('temp_'));
    } finally {
      isSending.value = false;
    }
  }

  static String chatErrorMessage(Object error) {
    final text = error.toString().trim();
    if (text.isEmpty) return 'Something went wrong. Please try again.';
    return text
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^ArgumentError:\s*'), '')
        .trim();
  }

  /// Send image/video/audio with optional caption. Supports multiple attachments in one message.
  Future<void> sendMediaMessage({
    required List<String> filePaths,
    required String type,
    String? caption,
    int? durationSeconds,
  }) async {
    final conversationId = currentConversationId.value;
    if (conversationId == null || filePaths.isEmpty || !canSendMessages) return;

    final userId = currentUserId;
    if (userId == null) return;

    if (type == 'image' && filePaths.length > AppConstants.maxChatImageAttachments) {
      Get.snackbar(
        'Photo limit',
        'You can send up to ${AppConstants.maxChatImageAttachments} photos at a time.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final trimmedCaption = caption?.trim() ?? '';
    final content = trimmedCaption.isNotEmpty
        ? trimmedCaption
        : switch (type) {
            'image' => filePaths.length > 1 ? '📷 Photos' : '📷 Photo',
            'video' => '🎥 Video',
            'audio' => '🎤 Audio',
            _ => '📎 Attachment',
          };

    final profile = _participantProfiles[userId];
    final localAttachments = filePaths.map((path) => ChatAttachment.local(path: path, type: type)).toList();
    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = ChatMessageModel(
      id: tempMessageId,
      conversationId: conversationId,
      senderId: userId,
      receiverId: currentTrainerId.value ?? '',
      message: content,
      type: type,
      fileUrl: filePaths.first,
      attachments: localAttachments,
      isPending: true,
      senderName: profile?.name ?? _storageService.getName(),
      senderImage: profile?.imageUrl,
      timestamp: DateTime.now(),
    );

    if (type == 'audio' && durationSeconds != null && durationSeconds > 0) {
      ChatAudioPlayerService.instance.cacheDuration(
        tempMessageId,
        Duration(seconds: durationSeconds),
        url: filePaths.first,
      );
    }

    try {
      isSending.value = true;
      messages.insert(0, tempMessage);

      final fileMessage = _enrichMessage(
        await _chatRepo.sendMessage(
          conversationId: conversationId,
          content: content,
          attachmentPaths: filePaths,
        ),
      );

      _upsertMessage(fileMessage, removeTempId: tempMessage.id);
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('block') || message.contains('forbidden')) {
        isBlockedByOther.value = true;
      }
      final title = e is BadRequestException ? 'Photo limit' : 'Error';
      Get.snackbar(title, chatErrorMessage(e), snackPosition: SnackPosition.BOTTOM);
      messages.removeWhere((m) => m.id == tempMessage.id);
    } finally {
      isSending.value = false;
    }
  }

  /// Send a single file message (audio recording, etc.).
  Future<void> sendFileMessage({
    required String filePath,
    required String type,
    String? fileName,
    String? caption,
    int? durationSeconds,
  }) async {
    await sendMediaMessage(
      filePaths: [filePath],
      type: type,
      caption: caption,
      durationSeconds: durationSeconds,
    );
  }

  /// Mark messages as read
  Future<void> markAsRead(String conversationId) async {
    try {
      await _apiService.markMessagesAsRead(conversationId);
      for (var i = 0; i < messages.length; i++) {
        final message = messages[i];
        if (_isSameConversation(message.conversationId, conversationId) && !message.isRead) {
          messages[i] = message.copyWith(isRead: true);
        }
      }
      _clearLocalUnread(conversationId);
      await loadUnreadCount();
    } catch (e) {
      // Silent fail
    }
  }

  /// User left the chat room but may still be on the messages list or elsewhere.
  void leaveChatRoom() {
    clearConversation();
    isOtherUserTyping.value = false;
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

      rememberBlockedUser(trainerId);
      isBlockedByMe.value = true;
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

      forgetBlockedUser(trainerId);
      isBlockedByMe.value = false;
      Get.snackbar('Success', 'User unblocked successfully.');
    } catch (e) {
      Get.snackbar('Error', 'Failed to unblock trainer: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void rememberBlockedUser(String userId) {
    final id = userId.trim();
    if (id.isEmpty || isUserBlocked(id)) return;
    blockedUsers.add(id);
  }

  void forgetBlockedUser(String userId) {
    final target = userId.trim().toLowerCase();
    blockedUsers.removeWhere((id) => id.trim().toLowerCase() == target);
  }

  /// Check if a user is blocked (session-wide, survives leaving a chat room).
  bool isUserBlocked(String userId) {
    final target = userId.trim().toLowerCase();
    if (target.isEmpty) return false;
    return blockedUsers.any((id) => id.trim().toLowerCase() == target);
  }

  @Deprecated('Use isUserBlocked')
  bool isBlocked(String userId) => isUserBlocked(userId);

  /// Clear current conversation
  void clearConversation() {
    _leaveConversationSocket();
    messages.clear();
    currentConversationId.value = null;
    currentTrainerId.value = null;
    currentProgramId.value = null;
    _messagesPage = 1;
    hasNextMessagesPage.value = false;
    isBlockedByMe.value = false;
    isBlockedByOther.value = false;
    _participantProfiles.clear();
  }
}
