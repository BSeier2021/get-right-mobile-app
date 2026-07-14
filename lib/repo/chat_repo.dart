import 'dart:io';

import 'package:get_right/app_url.dart';
import 'package:get_right/constants/app_constants.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/models/chat_message_model.dart';
import 'package:get_right/models/shared_content_model.dart';
import 'package:get_right/repo/workout_repo.dart';

class ConversationBlockStatus {
  const ConversationBlockStatus({
    this.isBlockedByMe = false,
    this.isBlockedByOther = false,
    this.isBlockedByBoth = false,
  });

  final bool isBlockedByMe;
  final bool isBlockedByOther;
  final bool isBlockedByBoth;

  factory ConversationBlockStatus.fromPayload(Map<String, dynamic> payload) {
    return ChatRepository.parseBlockStatusFromPayload(payload);
  }

  static bool payloadHasBlockStatus(Map<String, dynamic> map) {
    return ChatRepository._payloadHasBlockStatus(map);
  }
}

class ChatMessagesPage {
  const ChatMessagesPage({
    required this.messages,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
    required this.totalDocs,
    this.participantProfiles = const {},
    this.isBlockedByMe = false,
    this.isBlockedByOther = false,
    this.isBlockedByBoth = false,
  });

  final List<ChatMessageModel> messages;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;
  final int totalDocs;
  final Map<String, ChatParticipantProfile> participantProfiles;
  final bool isBlockedByMe;
  final bool isBlockedByOther;
  final bool isBlockedByBoth;
}

class ChatConversationsPage {
  const ChatConversationsPage({
    required this.conversations,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
    required this.totalDocs,
  });

  final List<ConversationModel> conversations;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;
  final int totalDocs;
}

class ChatRepository {
  final NetworkApiService _network = NetworkApiService();

  /// `GET /user/chat/conversations?page=&limit=&search=&unblockedOnly=` → `data.conversations[]`.
  Future<ChatConversationsPage> fetchConversations({
    int page = 1,
    int limit = 10,
    String search = '',
    String? currentUserId,
    bool? unblockedOnly,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    final trimmedSearch = search.trim();
    if (trimmedSearch.isNotEmpty) {
      params['search'] = trimmedSearch;
    }
    if (unblockedOnly == true) {
      params['unblockedOnly'] = true;
    }

    final raw = await _network.get(AppUrl.chatConversations, params: params);
    return _parseConversationsPage(raw, currentUserId: currentUserId);
  }

  /// `GET /user/chat/conversations/unread-count`.
  Future<int> fetchUnreadCount() async {
    final raw = await _network.get(AppUrl.chatUnreadCount);
    return _parseUnreadCount(raw);
  }

  /// `GET /user/chat/conversations/:conversationId/messages?page=&limit=` → `data.messages[]`.
  Future<ChatMessagesPage> fetchMessages(
    String conversationId, {
    int page = 1,
    int limit = 20,
  }) async {
    final id = conversationId.trim();
    if (id.isEmpty) {
      throw ArgumentError('conversationId is required');
    }

    final raw = await _network.get(
      AppUrl.chatConversationMessages(id),
      params: <String, dynamic>{'page': page, 'limit': limit},
    );
    return _parseMessagesPage(raw, fallbackConversationId: id);
  }

  /// `POST /user/chat/conversations/:conversationId/messages` — multipart: `content`, optional `attachments`.
  Future<ChatMessageModel> sendMessage({
    required String conversationId,
    required String content,
    List<String> attachmentPaths = const [],
  }) async {
    final id = conversationId.trim();
    if (id.isEmpty) {
      throw ArgumentError('conversationId is required');
    }

    final trimmedContent = content.trim();
    final attachmentFiles = <File>[];
    for (final path in attachmentPaths) {
      final trimmed = path.trim();
      if (trimmed.isEmpty) continue;
      final file = File(trimmed);
      if (await file.exists()) {
        attachmentFiles.add(file);
      } else {
        throw Exception('Attachment file not found');
      }
    }

    if (trimmedContent.isEmpty && attachmentFiles.isEmpty) {
      throw ArgumentError('content or attachment is required');
    }

    if (attachmentFiles.length > AppConstants.maxChatImageAttachments) {
      throw BadRequestException('You can send up to ${AppConstants.maxChatImageAttachments} photos at a time.');
    }

    final files = attachmentFiles.isEmpty ? <String, List<File>>{} : <String, List<File>>{'attachments': attachmentFiles};

    final raw = await _network.postMultipart(
      url: AppUrl.chatConversationMessages(id),
      fields: <String, dynamic>{'content': trimmedContent.isEmpty ? ' ' : trimmedContent},
      files: files,
    );
    return _parseSendMessageResponse(raw, fallbackConversationId: id);
  }

  /// `POST /user/chat/conversations/:conversationId/messages` — JSON body with `sharedContent`.
  Future<ChatMessageModel> sendSharedContentMessage({
    required String conversationId,
    required SharedContentType type,
    required String contentId,
    String? content,
  }) async {
    final id = conversationId.trim();
    final sharedId = contentId.trim();
    if (id.isEmpty) throw ArgumentError('conversationId is required');
    if (!WorkoutRepository.isValidMongoId(sharedId)) {
      throw ArgumentError('Invalid shared content id');
    }

    final body = <String, dynamic>{
      'sharedContent': SharedContentPayload(type: type, id: sharedId).toJson(),
    };
    final caption = content?.trim();
    if (caption != null && caption.isNotEmpty) body['content'] = caption;

    final raw = await _network.post(AppUrl.chatConversationMessages(id), body);
    return _parseSendMessageResponse(raw, fallbackConversationId: id);
  }

  /// `DELETE /user/chat/messages/:messageId`.
  Future<void> deleteMessage(String messageId) async {
    final id = messageId.trim();
    if (id.isEmpty || id.startsWith('temp_')) {
      throw ArgumentError('messageId is required');
    }

    final raw = await _network.delete(AppUrl.chatMessageDelete(id));
    if (raw is Map && raw['success'] == false) {
      throw Exception(raw['message']?.toString() ?? 'Failed to delete message');
    }
  }

  /// `GET /user/chat/conversations/with/:otherUserId` → `data.conversation`.
  Future<ConversationModel> createConversationWith(String otherUserId, {String? currentUserId}) async {
    final id = otherUserId.trim();
    if (id.isEmpty) {
      throw ArgumentError('otherUserId is required');
    }
    final raw = await _network.get(AppUrl.chatConversationWith(id));
    return _parseConversationResponse(raw, currentUserId: currentUserId);
  }

  static ConversationModel _parseConversationResponse(dynamic raw, {String? currentUserId}) {
    if (raw is! Map<String, dynamic> || raw['success'] != true) {
      final msg = raw is Map ? raw['message']?.toString() : null;
      throw Exception(msg ?? 'Could not start conversation');
    }
    final data = raw['data'];
    if (data is! Map) {
      throw Exception('Invalid conversation response');
    }

    final dm = Map<String, dynamic>.from(data);
    final conversation = dm['conversation'];
    if (conversation is Map) {
      final model = ConversationModel.fromApi(Map<String, dynamic>.from(conversation), currentUserId: currentUserId);
      if (model.id.isNotEmpty) return model;
    }

    final directId = (dm['_id'] ?? dm['id'] ?? dm['conversationId'])?.toString().trim();
    if (directId != null && directId.isNotEmpty) {
      final model = ConversationModel.fromApi(dm, currentUserId: currentUserId);
      if (model.id.isNotEmpty) return model;
      return ConversationModel.fromApi({'_id': directId, ...dm}, currentUserId: currentUserId);
    }

    throw Exception('Invalid conversation response');
  }

  static ChatConversationsPage _parseConversationsPage(dynamic raw, {String? currentUserId}) {
    if (raw is! Map) {
      return const ChatConversationsPage(
        conversations: [],
        currentPage: 1,
        totalPages: 0,
        hasNextPage: false,
        hasPrevPage: false,
        totalDocs: 0,
      );
    }

    final root = Map<String, dynamic>.from(raw);
    final data = root['data'];
    if (data is! Map) {
      return const ChatConversationsPage(
        conversations: [],
        currentPage: 1,
        totalPages: 0,
        hasNextPage: false,
        hasPrevPage: false,
        totalDocs: 0,
      );
    }

    final dm = Map<String, dynamic>.from(data);
    final listRaw = dm['conversations'];
    final conversations = listRaw is List
        ? listRaw
              .whereType<Map>()
              .map((e) => ConversationModel.fromApi(Map<String, dynamic>.from(e), currentUserId: currentUserId))
              .where((c) => c.id.isNotEmpty)
              .toList()
        : <ConversationModel>[];

    return ChatConversationsPage(
      conversations: conversations,
      currentPage: _intFrom(dm['currentPage'], fallback: 1),
      totalPages: _intFrom(dm['totalPages']),
      hasNextPage: dm['hasNextPage'] == true,
      hasPrevPage: dm['hasPrevPage'] == true,
      totalDocs: _intFrom(dm['totalDocs']),
    );
  }

  static ChatMessageModel _parseSendMessageResponse(dynamic raw, {required String fallbackConversationId}) {
    if (raw is! Map || raw['success'] != true) {
      final msg = raw is Map ? raw['message']?.toString() : null;
      throw Exception(msg ?? 'Failed to send message');
    }

    final data = raw['data'];
    if (data is Map) {
      final dm = Map<String, dynamic>.from(data);
      final message = dm['message'];
      if (message is Map) {
        return ChatMessageModel.fromApi(_withConversationId(Map<String, dynamic>.from(message), fallbackConversationId));
      }
      return ChatMessageModel.fromApi(_withConversationId(dm, fallbackConversationId));
    }

    throw Exception('Invalid message response');
  }

  static ChatMessagesPage _parseMessagesPage(dynamic raw, {required String fallbackConversationId}) {
    if (raw is! Map) {
      return const ChatMessagesPage(
        messages: [],
        currentPage: 1,
        totalPages: 0,
        hasNextPage: false,
        hasPrevPage: false,
        totalDocs: 0,
      );
    }

    final root = Map<String, dynamic>.from(raw);
    if (root['success'] == false) {
      final msg = root['message']?.toString();
      throw Exception(msg ?? 'Failed to load messages');
    }

    final data = root['data'];
    if (data is List) {
      final messages = data
          .whereType<Map>()
          .map((e) => ChatMessageModel.fromApi(_withConversationId(Map<String, dynamic>.from(e), fallbackConversationId)))
          .where((m) => m.id.isNotEmpty)
          .toList();
      return ChatMessagesPage(
        messages: messages,
        currentPage: 1,
        totalPages: messages.isEmpty ? 0 : 1,
        hasNextPage: false,
        hasPrevPage: false,
        totalDocs: messages.length,
      );
    }

    if (data is! Map) {
      return const ChatMessagesPage(
        messages: [],
        currentPage: 1,
        totalPages: 0,
        hasNextPage: false,
        hasPrevPage: false,
        totalDocs: 0,
      );
    }

    final dm = Map<String, dynamic>.from(data);
    final conversation = dm['conversation'];
    final blockStatus = ConversationBlockStatus.fromPayload(<String, dynamic>{'conversation': conversation, ...dm});
    final participantProfiles = _participantProfiles(conversation);
    final listRaw = dm['messages'] ?? dm['items'] ?? dm['docs'];
    final messages = listRaw is List
        ? listRaw
              .whereType<Map>()
              .map((e) => _parseMessage(Map<String, dynamic>.from(e), fallbackConversationId: fallbackConversationId, participantProfiles: participantProfiles))
              .where((m) => m.id.isNotEmpty)
              .toList()
        : <ChatMessageModel>[];

    return ChatMessagesPage(
      messages: messages,
      currentPage: _intFrom(dm['currentPage'], fallback: 1),
      totalPages: _intFrom(dm['totalPages']),
      hasNextPage: dm['hasNextPage'] == true,
      hasPrevPage: dm['hasPrevPage'] == true,
      totalDocs: _intFrom(dm['totalDocs']),
      participantProfiles: participantProfiles,
      isBlockedByMe: blockStatus.isBlockedByMe,
      isBlockedByOther: blockStatus.isBlockedByOther,
      isBlockedByBoth: blockStatus.isBlockedByBoth,
    );
  }

  /// Parses block flags from API `conversation`, `data`, socket `updates.data`, or root payloads.
  static ConversationBlockStatus parseBlockStatusFromPayload(dynamic raw) {
    if (raw is! Map) return const ConversationBlockStatus();

    final root = Map<String, dynamic>.from(raw);
    var isBlockedByMe = false;
    var isBlockedByOther = false;
    var isBlockedByBoth = false;
    var found = false;

    for (final source in _blockStatusSources(root)) {
      if (_mapHasBlockFlags(source)) {
        isBlockedByMe = _parseBool(source['isBlockedByMe']) ||
            _parseBool(source['blockedByMe']) ||
            _parseBool(source['iBlockedThem']);
        isBlockedByOther = _parseBool(source['isBlockedByOther']) ||
            _parseBool(source['blockedByOther']) ||
            _parseBool(source['theyBlockedMe']);
        isBlockedByBoth = _parseBool(source['isBlockedByBoth']);
        found = true;
        break;
      }
    }

    if (!found) {
      final updates = root['updates'];
      if (updates is Map) {
        final type = updates['type']?.toString().trim().toLowerCase();
        if (type == 'block' || type == 'unblock') {
          final updateData = updates['data'];
          if (updateData is Map) {
            final d = Map<String, dynamic>.from(updateData);
            isBlockedByMe = _parseBool(d['iBlockedThem']) || _parseBool(d['isBlockedByMe']) || _parseBool(d['blockedByMe']);
            isBlockedByOther = _parseBool(d['theyBlockedMe']) || _parseBool(d['isBlockedByOther']) || _parseBool(d['blockedByOther']);
            isBlockedByBoth = _parseBool(d['isBlockedByBoth']);
            found = true;
          }
        }
      }
    }

    if (!found) return const ConversationBlockStatus();

    if (isBlockedByBoth && !isBlockedByMe && !isBlockedByOther) {
      isBlockedByOther = true;
    }

    return ConversationBlockStatus(
      isBlockedByMe: isBlockedByMe,
      isBlockedByOther: isBlockedByOther,
      isBlockedByBoth: isBlockedByBoth,
    );
  }

  static bool _payloadHasBlockStatus(Map<String, dynamic> map) {
    for (final source in _blockStatusSources(map)) {
      if (_mapHasBlockFlags(source)) return true;
    }

    final updates = map['updates'];
    if (updates is Map) {
      final type = updates['type']?.toString().trim().toLowerCase();
      if (type == 'block' || type == 'unblock') return true;
      final updateData = updates['data'];
      if (updateData is Map && _mapHasBlockFlags(Map<String, dynamic>.from(updateData))) return true;
    }

    return false;
  }

  static bool _mapHasBlockFlags(Map<String, dynamic> source) {
    return source.containsKey('isBlockedByMe') ||
        source.containsKey('isBlockedByOther') ||
        source.containsKey('isBlockedByBoth') ||
        source.containsKey('blockedByMe') ||
        source.containsKey('blockedByOther') ||
        source.containsKey('iBlockedThem') ||
        source.containsKey('theyBlockedMe');
  }

  static Iterable<Map<String, dynamic>> _blockStatusSources(Map<String, dynamic> root) sync* {
    yield root;

    final conversation = root['conversation'];
    if (conversation is Map) yield Map<String, dynamic>.from(conversation);

    final data = root['data'];
    if (data is Map) {
      final dataMap = Map<String, dynamic>.from(data);
      yield dataMap;
      final nestedConversation = dataMap['conversation'];
      if (nestedConversation is Map) yield Map<String, dynamic>.from(nestedConversation);
    }

    final updates = root['updates'];
    if (updates is Map) {
      final updateData = updates['data'];
      if (updateData is Map) yield Map<String, dynamic>.from(updateData);
    }
  }

  static bool _parseBool(dynamic value) {
    if (value == true || value == 1) return true;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  /// Participant profiles from messages API or socket `conversation-updated` payload.
  static Map<String, ChatParticipantProfile> participantProfilesFromPayload(Map<String, dynamic> payload) {
    final conversation = payload['conversation'];
    if (conversation is Map) {
      return _participantProfiles(conversation);
    }

    final data = payload['data'];
    if (data is Map) {
      final dataMap = Map<String, dynamic>.from(data);
      final nestedConversation = dataMap['conversation'];
      if (nestedConversation is Map) {
        return _participantProfiles(nestedConversation);
      }
    }

    if (payload['participants'] is List) {
      return _participantProfiles(payload);
    }

    return const {};
  }

  static Map<String, ChatParticipantProfile> _participantProfiles(dynamic conversation) {
    if (conversation is! Map) return const {};
    final listRaw = conversation['participants'];
    if (listRaw is! List) return const {};

    final profiles = <String, ChatParticipantProfile>{};
    for (final item in listRaw.whereType<Map>()) {
      final participant = Map<String, dynamic>.from(item);
      final id = _chatStr(participant['_id'] ?? participant['id']);
      if (id.isEmpty) continue;

      final profile = participant['profile'];
      var name = _chatStr(participant['email']);
      String? imageUrl;
      if (profile is Map) {
        final profileMap = Map<String, dynamic>.from(profile);
        final fullName = _chatStr(profileMap['fullName']);
        if (fullName.isNotEmpty) name = fullName;
        final profilePic = profileMap['profilePicture'];
        if (profilePic is Map) {
          final url = _chatStr(Map<String, dynamic>.from(profilePic)['url']);
          if (url.isNotEmpty) imageUrl = url;
        }
      }

      profiles[id] = ChatParticipantProfile(
        id: id,
        name: name.isNotEmpty ? name : 'User',
        imageUrl: imageUrl,
        isOnline: participant['isOnline'] == true,
      );
    }
    return profiles;
  }

  static ChatMessageModel _parseMessage(
    Map<String, dynamic> json, {
    required String fallbackConversationId,
    Map<String, ChatParticipantProfile> participantProfiles = const {},
  }) {
    final model = ChatMessageModel.fromApi(_withConversationId(json, fallbackConversationId));
    final profile = participantProfiles[model.senderId];
    if (profile == null) return model;

    return model.copyWith(
      senderName: (model.senderName?.trim().isNotEmpty ?? false) ? model.senderName : profile.name,
      senderImage: model.senderImage ?? profile.imageUrl,
    );
  }

  static Map<String, dynamic> _withConversationId(Map<String, dynamic> json, String conversationId) {
    if (_chatStr(json['conversationId'] ?? json['conversation']).isEmpty) {
      return {...json, 'conversationId': conversationId};
    }
    return json;
  }

  static String _chatStr(dynamic value) => value?.toString().trim() ?? '';

  static int _parseUnreadCount(dynamic raw) {
    if (raw is! Map) return 0;
    final data = raw['data'];
    if (data is num) return data.toInt();
    if (data is Map) {
      final dm = Map<String, dynamic>.from(data);
      for (final key in ['unreadCount', 'count', 'total', 'totalUnread', 'unread']) {
        final v = dm[key];
        if (v is num) return v.toInt();
      }
    }
    return 0;
  }

  static int _intFrom(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
