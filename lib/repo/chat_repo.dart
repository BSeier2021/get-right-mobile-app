import 'package:get_right/app_url.dart';
import 'package:get_right/models/chat_message_model.dart';
import 'package:get_right/network/network_services.dart';

class ChatMessagesPage {
  const ChatMessagesPage({
    required this.messages,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
    required this.totalDocs,
  });

  final List<ChatMessageModel> messages;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;
  final int totalDocs;
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

  /// `GET /user/chat/conversations?page=&limit=&search=` → `data.conversations[]`.
  Future<ChatConversationsPage> fetchConversations({
    int page = 1,
    int limit = 10,
    String search = '',
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    final trimmedSearch = search.trim();
    if (trimmedSearch.isNotEmpty) {
      params['search'] = trimmedSearch;
    }

    final raw = await _network.get(AppUrl.chatConversations, params: params);
    return _parseConversationsPage(raw);
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

  /// `GET /user/chat/conversations/with/:otherUserId` → `data.conversation`.
  Future<ConversationModel> createConversationWith(String otherUserId) async {
    final id = otherUserId.trim();
    if (id.isEmpty) {
      throw ArgumentError('otherUserId is required');
    }
    final raw = await _network.get(AppUrl.chatConversationWith(id));
    return _parseConversationResponse(raw);
  }

  static ConversationModel _parseConversationResponse(dynamic raw) {
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
      final model = ConversationModel.fromApi(Map<String, dynamic>.from(conversation));
      if (model.id.isNotEmpty) return model;
    }

    final directId = (dm['_id'] ?? dm['id'] ?? dm['conversationId'])?.toString().trim();
    if (directId != null && directId.isNotEmpty) {
      final model = ConversationModel.fromApi(dm);
      if (model.id.isNotEmpty) return model;
      return ConversationModel.fromApi({'_id': directId, ...dm});
    }

    throw Exception('Invalid conversation response');
  }

  static ChatConversationsPage _parseConversationsPage(dynamic raw) {
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
        ? listRaw.whereType<Map>().map((e) => ConversationModel.fromApi(Map<String, dynamic>.from(e))).where((c) => c.id.isNotEmpty).toList()
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
    final listRaw = dm['messages'] ?? dm['items'] ?? dm['docs'];
    final messages = listRaw is List
        ? listRaw
              .whereType<Map>()
              .map((e) => ChatMessageModel.fromApi(_withConversationId(Map<String, dynamic>.from(e), fallbackConversationId)))
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
