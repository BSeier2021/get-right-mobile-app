/// Chat message model for trainer-client communication
class ChatMessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String message;
  final String type; // 'text', 'image', 'video', 'audio'
  final String? fileUrl;
  final String? fileName;
  final bool isRead;
  final DateTime timestamp;

  ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.type = 'text',
    this.fileUrl,
    this.fileName,
    this.isRead = false,
    required this.timestamp,
  });

  /// From JSON (legacy mock + API).
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel.fromApi(json);

  factory ChatMessageModel.fromApi(Map<String, dynamic> json) {
    final conversationId = _chatEntityId(json['conversationId'] ?? json['conversation']);
    return ChatMessageModel(
      id: _chatStr(json['_id'] ?? json['id']),
      conversationId: conversationId,
      senderId: _chatEntityId(json['senderId'] ?? json['sender']),
      receiverId: _chatEntityId(json['receiverId'] ?? json['receiver']),
      message: _chatStr(json['message'] ?? json['content'] ?? json['text']),
      type: _chatStr(json['type']).isEmpty ? 'text' : _chatStr(json['type']),
      fileUrl: _chatStr(json['fileUrl'] ?? json['url']).isEmpty ? null : _chatStr(json['fileUrl'] ?? json['url']),
      fileName: _chatStr(json['fileName'] ?? json['originalName']).isEmpty ? null : _chatStr(json['fileName'] ?? json['originalName']),
      isRead: json['isRead'] == true || json['read'] == true,
      timestamp: _chatDate(json['timestamp'] ?? json['createdAt'] ?? json['updatedAt']),
    );
  }

  /// To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'type': type,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'isRead': isRead,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Copy with
  ChatMessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? message,
    String? type,
    String? fileUrl,
    String? fileName,
    bool? isRead,
    DateTime? timestamp,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      type: type ?? this.type,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Conversation model
class ConversationModel {
  final String id;
  final String userId;
  final String trainerId;
  final String trainerName;
  final String? trainerImage;
  final String programId;
  final String programTitle;
  final ChatMessageModel? lastMessage;
  final int unreadCount;
  final DateTime createdAt;

  ConversationModel({
    required this.id,
    required this.userId,
    required this.trainerId,
    required this.trainerName,
    this.trainerImage,
    required this.programId,
    required this.programTitle,
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) => ConversationModel.fromApi(json);

  factory ConversationModel.fromApi(Map<String, dynamic> json) {
    final trainer = _chatMap(json['trainer']) ?? _chatMap(json['otherUser']) ?? _chatMap(json['participant']);
    final trainerProfile = trainer != null ? (_chatMap(trainer['profile']) ?? trainer) : null;
    final program = _chatMap(json['program']);

    final lastRaw = json['lastMessage'] ?? json['last_message'] ?? json['latestMessage'];
    final lastMessage = lastRaw is Map ? ChatMessageModel.fromApi(Map<String, dynamic>.from(lastRaw)) : null;

    final trainerName = _chatStr(
      json['trainerName'] ?? trainerProfile?['fullName'] ?? trainer?['fullName'] ?? trainer?['name'] ?? trainer?['email'],
    );

    String? trainerImage = _chatStr(json['trainerImage']).isEmpty ? null : _chatStr(json['trainerImage']);
    final profilePic = trainerProfile?['profilePicture'];
    if (profilePic is Map) {
      final url = _chatStr(Map<String, dynamic>.from(profilePic)['url']);
      if (url.isNotEmpty) trainerImage = url;
    }

    return ConversationModel(
      id: _chatStr(json['_id'] ?? json['id']),
      userId: _chatStr(json['userId'] ?? json['user'] ?? json['customer']),
      trainerId: _chatStr(json['trainerId'] ?? trainer?['_id'] ?? trainer?['id']),
      trainerName: trainerName,
      trainerImage: trainerImage,
      programId: _chatStr(json['programId'] ?? program?['_id'] ?? program?['id']),
      programTitle: _chatStr(json['programTitle'] ?? program?['title'] ?? program?['name']),
      lastMessage: lastMessage,
      unreadCount: _chatInt(json['unreadCount'] ?? json['unread']),
      createdAt: _chatDate(json['createdAt'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'trainerId': trainerId,
      'trainerName': trainerName,
      'trainerImage': trainerImage,
      'programId': programId,
      'programTitle': programTitle,
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

String _chatStr(dynamic value) => value?.toString().trim() ?? '';

String _chatEntityId(dynamic value) {
  if (value is Map) {
    final m = Map<String, dynamic>.from(value);
    return _chatStr(m['_id'] ?? m['id'] ?? m['userId'] ?? m['user']);
  }
  return _chatStr(value);
}

Map<String, dynamic>? _chatMap(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : null;

int _chatInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _chatDate(dynamic value) {
  if (value == null) return DateTime.now();
  return DateTime.tryParse(value.toString())?.toLocal() ?? DateTime.now();
}
