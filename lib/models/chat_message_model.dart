/// Chat attachment (image, video, audio) from API or local pending upload.
class ChatAttachment {
  const ChatAttachment({
    this.id,
    required this.url,
    this.thumbnailUrl,
    this.type = 'image',
    this.originalName,
    this.isLocal = false,
  });

  final String? id;
  final String url;
  final String? thumbnailUrl;
  final String type;
  final String? originalName;
  final bool isLocal;

  bool get isImage {
    final normalized = type.toLowerCase();
    return normalized == 'image' || normalized.startsWith('image/');
  }

  bool get isVideo {
    final normalized = type.toLowerCase();
    return normalized == 'video' || normalized.startsWith('video/');
  }

  factory ChatAttachment.fromApi(Map<String, dynamic> json) {
    final typeRaw = _chatStr(json['type']);
    final mimeType = _chatStr(json['mimeType']).toLowerCase();
    var attachmentType = typeRaw.toLowerCase();
    if (attachmentType.isEmpty) {
      if (mimeType.startsWith('image/')) {
        attachmentType = 'image';
      } else if (mimeType.startsWith('video/')) {
        attachmentType = 'video';
      } else if (mimeType.startsWith('audio/')) {
        attachmentType = 'audio';
      } else {
        attachmentType = 'file';
      }
    } else if (attachmentType == 'image' || attachmentType == 'video' || attachmentType == 'audio') {
      // keep normalized lowercase values from API e.g. "Image"
    } else {
      attachmentType = attachmentType.toLowerCase();
    }

    String? thumbnailUrl;
    final thumb = json['thumbnail'];
    if (thumb is Map) {
      final url = _chatStr(Map<String, dynamic>.from(thumb)['url']);
      if (url.isNotEmpty) thumbnailUrl = url;
    }

    final url = _chatStr(json['url'] ?? json['fileUrl']);
    final originalName = _chatStr(json['originalName'] ?? json['fileName'] ?? json['name']);

    return ChatAttachment(
      id: _chatStr(json['_id'] ?? json['id']).isEmpty ? null : _chatStr(json['_id'] ?? json['id']),
      url: url,
      thumbnailUrl: thumbnailUrl,
      type: attachmentType,
      originalName: originalName.isEmpty ? null : originalName,
    );
  }

  factory ChatAttachment.local({required String path, required String type}) {
    return ChatAttachment(url: path, type: type, isLocal: true);
  }
}

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
  final String? thumbnailUrl;
  final List<ChatAttachment> attachments;
  final bool isPending;
  final String? senderName;
  final String? senderImage;
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
    this.thumbnailUrl,
    this.attachments = const [],
    this.isPending = false,
    this.senderName,
    this.senderImage,
    this.isRead = false,
    required this.timestamp,
  });

  List<ChatAttachment> get displayAttachments {
    if (attachments.isNotEmpty) return attachments;
    if (fileUrl != null && fileUrl!.isNotEmpty) {
      return [
        ChatAttachment(
          url: fileUrl!,
          thumbnailUrl: thumbnailUrl,
          type: type,
          originalName: fileName,
        ),
      ];
    }
    return const [];
  }

  bool get hasMediaAttachments => displayAttachments.isNotEmpty;

  String get displayCaption {
    final text = message.trim();
    if (text.isEmpty) return '';
    if (text == '📷 Photo' || text == '📷 Photos' || text == '🎥 Video' || text == '🎤 Audio' || text == '📎 Attachment') {
      return '';
    }
    return text;
  }

  String get displaySenderName {
    final name = senderName?.trim() ?? '';
    return name.isNotEmpty ? name : 'User';
  }

  /// From JSON (legacy mock + API).
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel.fromApi(json);

  factory ChatMessageModel.fromApi(Map<String, dynamic> json) {
    final conversationId = _chatEntityId(json['conversationId'] ?? json['conversation']);
    final attachmentsRaw = json['attachments'];
    final parsedAttachments = <ChatAttachment>[];
    String? fileUrl = _chatStr(json['fileUrl'] ?? json['url']).isEmpty ? null : _chatStr(json['fileUrl'] ?? json['url']);
    String? fileName = _chatStr(json['fileName'] ?? json['originalName']).isEmpty ? null : _chatStr(json['fileName'] ?? json['originalName']);
    String? thumbnailUrl;

    if (attachmentsRaw is List && attachmentsRaw.isNotEmpty) {
      for (final item in attachmentsRaw) {
        if (item is! Map) continue;
        final attachment = ChatAttachment.fromApi(Map<String, dynamic>.from(item));
        if (attachment.url.isEmpty) continue;
        parsedAttachments.add(attachment);
      }

      if (parsedAttachments.isNotEmpty) {
        final first = parsedAttachments.first;
        fileUrl ??= first.url;
        fileName ??= first.originalName;
        thumbnailUrl ??= first.thumbnailUrl;
      }
    }

    final senderRaw = json['sender'];
    var senderName = '';
    String? senderImage;
    if (senderRaw is Map) {
      final sender = Map<String, dynamic>.from(senderRaw);
      final profile = _chatMap(sender['profile']);
      senderName = _chatStr(profile?['fullName'] ?? sender['fullName'] ?? sender['name'] ?? sender['email']);
      final profilePic = profile?['profilePicture'];
      if (profilePic is Map) {
        final url = _chatStr(Map<String, dynamic>.from(profilePic)['url']);
        if (url.isNotEmpty) senderImage = url;
      }
    }

    final rawType = _chatStr(json['messageType'] ?? json['type']);
    var type = rawType.isEmpty ? 'text' : rawType.toLowerCase();

    if (parsedAttachments.isNotEmpty) {
      final attachmentTypes = parsedAttachments.map((a) => a.isVideo ? 'video' : a.isImage ? 'image' : a.type).toSet();
      if (attachmentTypes.length == 1) {
        type = attachmentTypes.first;
      } else if (attachmentTypes.contains('video')) {
        type = 'video';
      } else if (attachmentTypes.every((t) => t == 'image')) {
        type = 'image';
      }
    } else if (attachmentsRaw is List && attachmentsRaw.isNotEmpty && attachmentsRaw.first is Map) {
      final attachment = Map<String, dynamic>.from(attachmentsRaw.first as Map);
      final attachmentType = _chatStr(attachment['type']).toLowerCase();
      final mimeType = _chatStr(attachment['mimeType']).toLowerCase();

      if (attachmentType == 'image' || mimeType.startsWith('image/')) {
        type = 'image';
      } else if (attachmentType == 'video' || mimeType.startsWith('video/')) {
        type = 'video';
      } else if (attachmentType == 'audio' || mimeType.startsWith('audio/')) {
        type = 'audio';
      } else if (type == 'text_and_file' || type == 'file') {
        type = 'image';
      }
    } else if ((type == 'text_and_file' || type == 'file') && fileUrl != null) {
      final lowerName = (fileName ?? fileUrl).toLowerCase();
      if (lowerName.endsWith('.mp3') || lowerName.endsWith('.wav') || lowerName.endsWith('.aac') || lowerName.endsWith('.m4a')) {
        type = 'audio';
      } else if (lowerName.endsWith('.mp4') || lowerName.endsWith('.mov') || lowerName.endsWith('.avi')) {
        type = 'video';
      } else if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg') || lowerName.endsWith('.png') || lowerName.endsWith('.gif') || lowerName.endsWith('.webp')) {
        type = 'image';
      }
    }

    return ChatMessageModel(
      id: _chatStr(json['_id'] ?? json['id']),
      conversationId: conversationId,
      senderId: _chatEntityId(json['senderId'] ?? json['sender']),
      receiverId: _chatEntityId(json['receiverId'] ?? json['receiver']),
      message: _chatStr(json['message'] ?? json['content'] ?? json['text']),
      type: type,
      fileUrl: fileUrl,
      fileName: fileName,
      thumbnailUrl: thumbnailUrl,
      attachments: parsedAttachments,
      senderName: senderName.isEmpty ? null : senderName,
      senderImage: senderImage,
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
      'thumbnailUrl': thumbnailUrl,
      'attachments': attachments.map((a) => {'url': a.url, 'type': a.type, 'originalName': a.originalName}).toList(),
      'isPending': isPending,
      'senderName': senderName,
      'senderImage': senderImage,
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
    String? thumbnailUrl,
    List<ChatAttachment>? attachments,
    bool? isPending,
    String? senderName,
    String? senderImage,
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
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      attachments: attachments ?? this.attachments,
      isPending: isPending ?? this.isPending,
      senderName: senderName ?? this.senderName,
      senderImage: senderImage ?? this.senderImage,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class ChatParticipantProfile {
  const ChatParticipantProfile({required this.id, required this.name, this.imageUrl, this.isOnline});

  final String id;
  final String name;
  final String? imageUrl;
  final bool? isOnline;

  bool get isOnlineNow => isOnline == true;

  ChatParticipantProfile copyWith({String? id, String? name, String? imageUrl, bool? isOnline}) {
    return ChatParticipantProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      isOnline: isOnline ?? this.isOnline,
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
  final DateTime updatedAt;

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
    required this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) => ConversationModel.fromApi(json);

  factory ConversationModel.fromApi(Map<String, dynamic> json, {String? currentUserId}) {
    final trainer = _chatMap(json['trainer']) ?? _chatMap(json['otherUser']) ?? _chatMap(json['participant']);
    final program = _chatMap(json['program']);

    final participantsRaw = json['participants'];
    Map<String, dynamic>? otherParticipant;
    if (participantsRaw is List) {
      final participants = participantsRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      otherParticipant = _resolveOtherParticipant(participants, currentUserId);
    }

    final contact = otherParticipant ?? trainer;
    final contactProfile = contact != null ? (_chatMap(contact['profile']) ?? contact) : null;
    final trainerProfile = trainer != null ? (_chatMap(trainer['profile']) ?? trainer) : null;

    final lastRaw = json['lastMessage'] ?? json['last_message'] ?? json['latestMessage'];
    final lastMessage = lastRaw is Map ? ChatMessageModel.fromApi(Map<String, dynamic>.from(lastRaw)) : null;

    final trainerName = _chatStr(
      json['trainerName'] ??
          contactProfile?['fullName'] ??
          contact?['fullName'] ??
          contact?['name'] ??
          contact?['email'] ??
          trainerProfile?['fullName'] ??
          trainer?['fullName'] ??
          trainer?['name'] ??
          trainer?['email'],
    );

    String? trainerImage = _chatStr(json['trainerImage']).isEmpty ? null : _chatStr(json['trainerImage']);
    for (final profile in [contactProfile, trainerProfile]) {
      if (profile == null) continue;
      final profilePic = profile['profilePicture'];
      if (profilePic is Map) {
        final url = _chatStr(Map<String, dynamic>.from(profilePic)['url']);
        if (url.isNotEmpty) {
          trainerImage = url;
          break;
        }
      }
    }

    final resolvedUserId = _chatStr(json['userId'] ?? json['user'] ?? json['customer']).isNotEmpty
        ? _chatStr(json['userId'] ?? json['user'] ?? json['customer'])
        : (currentUserId ?? '');

    return ConversationModel(
      id: _chatStr(json['_id'] ?? json['id']),
      userId: resolvedUserId,
      trainerId: _chatStr(json['trainerId'] ?? contact?['_id'] ?? contact?['id'] ?? trainer?['_id'] ?? trainer?['id']),
      trainerName: trainerName.isNotEmpty ? trainerName : 'User',
      trainerImage: trainerImage,
      programId: _chatStr(json['programId'] ?? program?['_id'] ?? program?['id']),
      programTitle: _chatStr(json['programTitle'] ?? program?['title'] ?? program?['name']),
      lastMessage: lastMessage,
      unreadCount: _chatInt(json['unreadCount'] ?? json['unread']),
      createdAt: _chatDate(json['createdAt']),
      updatedAt: _chatDate(json['updatedAt'] ?? json['createdAt']),
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
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ConversationModel copyWith({
    String? id,
    String? userId,
    String? trainerId,
    String? trainerName,
    String? trainerImage,
    String? programId,
    String? programTitle,
    ChatMessageModel? lastMessage,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      trainerId: trainerId ?? this.trainerId,
      trainerName: trainerName ?? this.trainerName,
      trainerImage: trainerImage ?? this.trainerImage,
      programId: programId ?? this.programId,
      programTitle: programTitle ?? this.programTitle,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

Map<String, dynamic>? _resolveOtherParticipant(List<Map<String, dynamic>> participants, String? currentUserId) {
  if (participants.isEmpty) return null;

  if (currentUserId != null && currentUserId.isNotEmpty) {
    for (final participant in participants) {
      final id = _chatStr(participant['_id'] ?? participant['id']);
      if (id.isNotEmpty && id != currentUserId) return participant;
    }
  }

  for (final participant in participants) {
    final profile = _chatMap(participant['profile']);
    if (_chatStr(profile?['profileType']) == 'Trainer') return participant;
  }

  if (participants.length > 1) return participants[1];
  return participants.first;
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
