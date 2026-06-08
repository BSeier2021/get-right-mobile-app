import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_right/Local%20Storage/local_storage.dart';
import 'package:get_right/app_url.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Real-time chat socket (`join-conversation`, typing, live messages).
class ChatSocketService {
  ChatSocketService._();

  static final ChatSocketService instance = ChatSocketService._();

  io.Socket? _socket;
  String? _joinedConversationId;
  bool _listenersAttached = false;

  final StreamController<Map<String, dynamic>> _newMessageController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _userTypingController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _userStatusController = StreamController.broadcast();
  final StreamController<bool> _connectionController = StreamController.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;
  Stream<Map<String, dynamic>> get onUserStatusChanged => _userStatusController.stream;
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  bool get isConnected => _socket?.connected == true;
  String? get joinedConversationId => _joinedConversationId;

  Future<void> connect() async {
    if (_socket?.connected == true) return;

    final localStorage = Get.isRegistered<LocalStorage>() ? Get.find<LocalStorage>() : Get.put(LocalStorage());
    final token = localStorage.getAccessToken()?.toString().trim() ?? '';

    _socket?.dispose();
    _listenersAttached = false;

    _socket = io.io(
      AppUrl.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .setAuth(<String, dynamic>{
            if (token.isNotEmpty) 'token': token,
            if (token.isNotEmpty) 'authorization': 'Bearer $token',
          })
          .build(),
    );

    _attachSocketListeners();
    _socket!.connect();
  }

  void _attachSocketListeners() {
    if (_socket == null || _listenersAttached) return;
    _listenersAttached = true;

    _socket!
      ..onConnect((_) {
        debugPrint('[ChatSocket] connected');
        _connectionController.add(true);
        final conversationId = _joinedConversationId;
        if (conversationId != null && conversationId.isNotEmpty) {
          _emitJoinConversation(conversationId);
        }
      })
      ..onDisconnect((_) {
        debugPrint('[ChatSocket] disconnected');
        _connectionController.add(false);
      })
      ..onConnectError((error) {
        debugPrint('[ChatSocket] connect error: $error');
        _connectionController.add(false);
      })
      ..on('new-message', (data) {
        final map = _asMap(data);
        if (map != null) _newMessageController.add(map);
      })
      ..on('user-typing', (data) {
        final map = _asMap(data);
        if (map != null) _userTypingController.add(map);
      })
      ..on('user-status-changed', (data) {
        final map = _asMap(data);
        if (map != null) _userStatusController.add(map);
      });
  }

  void joinConversation(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) return;

    if (_joinedConversationId != null && _joinedConversationId != id) {
      leaveConversation(_joinedConversationId!);
    }

    _joinedConversationId = id;
    if (isConnected) {
      _emitJoinConversation(id);
    } else {
      connect();
    }
  }

  void leaveConversation(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) return;

    if (isConnected) {
      _socket?.emit('leave-conversation', <String, dynamic>{'conversationId': id});
    }
    if (_joinedConversationId == id) {
      _joinedConversationId = null;
    }
  }

  void typingStart(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty || !isConnected) return;
    _socket?.emit('typing-start', <String, dynamic>{'conversationId': id});
  }

  void typingStop(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty || !isConnected) return;
    _socket?.emit('typing-stop', <String, dynamic>{'conversationId': id});
  }

  void disconnect() {
    final joined = _joinedConversationId;
    if (joined != null && joined.isNotEmpty) {
      leaveConversation(joined);
    }
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _listenersAttached = false;
    _joinedConversationId = null;
  }

  void _emitJoinConversation(String conversationId) {
    _socket?.emit('join-conversation', <String, dynamic>{'conversationId': conversationId});
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}
