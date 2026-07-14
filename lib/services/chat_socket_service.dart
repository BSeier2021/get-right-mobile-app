import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_right/Local%20Storage/local_storage.dart';
import 'package:get_right/app_url.dart';
import 'package:get_right/constants/app_constants.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/repo/chat_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Real-time chat socket (`join-conversation`, typing, live messages).
class ChatSocketService {
  ChatSocketService._();

  static final ChatSocketService instance = ChatSocketService._();

  io.Socket? _socket;
  String? _joinedConversationId;
  bool _listenersAttached = false;
  Completer<void>? _connectCompleter;
  Timer? _joinRetryTimer;
  int _joinRetryCount = 0;
  bool _authRejected = false;
  static bool _transportErrorHandlerInstalled = false;

  void _installTransportErrorHandler() {
    if (_transportErrorHandlerInstalled) return;
    _transportErrorHandlerInstalled = true;
    final previous = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      final text = error.toString();
      if (text.contains('WebSocketConnectionClosed') || text.contains('Connection Closed')) {
        debugPrint('[ChatSocket] ignored transport close: $text');
        return true;
      }
      return previous?.call(error, stack) ?? false;
    };
  }

  final StreamController<Map<String, dynamic>> _newMessageController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _userTypingController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _userStatusController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _conversationBlockController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _conversationUpdatedController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _accountBlockedController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _notificationController = StreamController.broadcast();
  final StreamController<bool> _connectionController = StreamController.broadcast();

  /// Direct handler — always invoked before the stream (avoids missed broadcast events).
  void Function(Map<String, dynamic> payload)? onMessageReceived;
  void Function(Map<String, dynamic> payload)? onAccountBlockedReceived;

  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;
  Stream<Map<String, dynamic>> get onUserStatusChanged => _userStatusController.stream;
  Stream<Map<String, dynamic>> get onConversationBlockChanged => _conversationBlockController.stream;
  Stream<Map<String, dynamic>> get onConversationUpdated => _conversationUpdatedController.stream;
  Stream<Map<String, dynamic>> get onAccountBlocked => _accountBlockedController.stream;
  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  bool get isConnected => _socket?.connected == true;
  String? get joinedConversationId => _joinedConversationId;

  /// Call after login, OTP verify, auto-login, or profile create when JWT is saved.
  Future<void> connectAfterAuth() async {
    _authRejected = false;
    _joinRetryCount = 0;
    _joinRetryTimer?.cancel();
    await connect();
  }

  Future<void> connect() async {
    if (_socket?.connected == true) return;
    if (_connectCompleter != null) return _connectCompleter!.future;

    _installTransportErrorHandler();

    final completer = Completer<void>();
    _connectCompleter = completer;

    try {
      final token = await _resolveAuthToken();
      if (token == null) {
        debugPrint('[ChatSocket] skip connect: no auth token available');
        if (!completer.isCompleted) completer.complete();
        return;
      }

      final bearer = 'Bearer $token';

      if (_socket != null) {
        _socket!.dispose();
        _listenersAttached = false;
        _socket = null;
      }

      // Backend expects Bearer-prefixed token (same as REST Authorization header).
      _socket = io.io(
        AppUrl.socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(2000)
            .setAuth(<String, dynamic>{'token': bearer})
            .setExtraHeaders(<String, String>{'Authorization': bearer})
            .build(),
      );

      _attachSocketListeners(completer);
      _socket!.connect();

      await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint('[ChatSocket] connect timeout');
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (e) {
      debugPrint('[ChatSocket] connect failed: $e');
      if (!completer.isCompleted) completer.complete();
    } finally {
      if (identical(_connectCompleter, completer)) {
        _connectCompleter = null;
      }
    }
  }

  Future<String?> _resolveAuthToken() async {
    final localStorage = Get.isRegistered<LocalStorage>() ? Get.find<LocalStorage>() : Get.put(LocalStorage());
    var token = _normalizeToken(localStorage.getAccessToken());

    if (token == null) {
      final prefs = await SharedPreferences.getInstance();
      token = _normalizeToken(prefs.getString(AppConstants.keyUserToken));
      if (token != null) localStorage.saveAccessToken(token);
    }

    if (token == null) {
      try {
        final storage = await StorageService.getInstance();
        token = _normalizeToken(storage.getToken());
        if (token != null) localStorage.saveAccessToken(token);
      } catch (_) {}
    }

    if (token == null || token.isEmpty) {
      debugPrint('[ChatSocket] no token found in storage');
      return null;
    }

    return token;
  }

  String? _normalizeToken(dynamic raw) {
    if (raw == null) return null;
    var value = raw.toString().trim();
    if (value.isEmpty || value == 'null') return null;
    if (value.toLowerCase().startsWith('bearer ')) {
      value = value.substring(7).trim();
    }
    return value.isEmpty ? null : value;
  }

  void _attachSocketListeners(Completer<void>? connectCompleter) {
    if (_socket == null || _listenersAttached) return;
    _listenersAttached = true;

    void onConnected(_) {
      _socket!.on('new-message', (data) {
        debugPrint('[ChatSocket] new-message: $data');
        _dispatchNewMessage('new-message', data);
      });
      debugPrint('[ChatSocket] connected');
      _connectionController.add(true);
      _joinRetryCount = 0;
      if (connectCompleter != null && !connectCompleter.isCompleted) {
        connectCompleter.complete();
      }
      final conversationId = _joinedConversationId;
      if (conversationId != null && conversationId.isNotEmpty) {
        _emitJoinConversation(conversationId);
      }
    }

    void onConnectFailed(error) {
      debugPrint('[ChatSocket] connect error: $error');
      _connectionController.add(false);
      if (_isAuthFormatError(error)) {
        _authRejected = true;
        _joinRetryTimer?.cancel();
        debugPrint('[ChatSocket] auth rejected — stopping retries');
      }
      if (connectCompleter != null && !connectCompleter.isCompleted) {
        connectCompleter.complete();
      }
    }

    _socket!
      ..onConnect(onConnected)
      ..onDisconnect((_) {
        debugPrint('[ChatSocket] disconnected');
        _connectionController.add(false);
      })
      ..onConnectError(onConnectFailed)
      ..onError(onConnectFailed);

    for (final event in const ['newMessage', 'message']) {
      _socket!.on(event, (data) {
        debugPrint('[ChatSocket] $event: $data');
        _dispatchNewMessage(event, data);
      });
    }

    for (final event in const ['user-typing', 'userTyping']) {
      _socket!.on(event, (data) {
        final map = _asMap(data);
        if (map != null) _userTypingController.add(map);
      });
    }

    for (final event in const ['user-status-changed', 'userStatusChanged']) {
      _socket!.on(event, (data) {
        final map = _asMap(data);
        if (map != null) {
          _userStatusController.add(map);
          _dispatchConversationBlockIfPresent(map, source: event);
        }
      });
    }

    for (final event in const ['conversation-updated', 'conversationUpdated']) {
      _socket!.on(event, (data) {
        final map = _asMap(data);
        if (map == null) return;
        debugPrint('[ChatSocket] $event: $data');
        if (!_conversationUpdatedController.isClosed) {
          _conversationUpdatedController.add(map);
        }
        _dispatchConversationBlockIfPresent(map, source: event);
      });
    }

    for (final event in const ['block-status-changed', 'blockStatusChanged', 'user-blocked', 'userBlocked']) {
      _socket!.on(event, (data) {
        final map = _asMap(data);
        if (map != null) _dispatchConversationBlockIfPresent(map, source: event);
      });
    }

    for (final event in const ['account-blocked', 'accountBlocked']) {
      _socket!.on(event, (data) {
        debugPrint('[ChatSocket] $event: $data');
        _dispatchAccountBlocked(_asMap(data) ?? <String, dynamic>{}, source: event);
      });
    }

    for (final event in const ['notification', 'notifications', 'new-notification', 'newNotification']) {
      _socket!.on(event, (data) {
        final map = _asMap(data);
        if (map == null) return;
        debugPrint('[ChatSocket] $event: $data');
        if (!_notificationController.isClosed) {
          _notificationController.add(map);
        }
      });
    }

    _socket!.onAny((event, data) {
      debugPrint('[ChatSocket] onAny: $event');
      if (event == 'new-message' || event == 'newMessage' || event == 'message') return;
      if (event == 'account-blocked' || event == 'accountBlocked') return;
      if (event == 'notification' || event == 'notifications' || event == 'new-notification' || event == 'newNotification') return;
      final map = _asMap(data);
      if (map == null) return;
      _dispatchConversationBlockIfPresent(map, source: event);
      final payload = _unwrapMessagePayload(map);
      if (payload != null) _publishMessage(payload, source: event);
    });
  }

  void _dispatchConversationBlockIfPresent(Map<String, dynamic> map, {required String source}) {
    if (!_containsBlockStatus(map)) return;
    debugPrint('[ChatSocket] $source → block status update');
    if (!_conversationBlockController.isClosed) {
      _conversationBlockController.add(map);
    }
  }

  void _dispatchAccountBlocked(Map<String, dynamic> map, {required String source}) {
    debugPrint('[ChatSocket] $source → admin account block');
    _authRejected = true;
    _joinRetryTimer?.cancel();
    _joinedConversationId = null;
    onAccountBlockedReceived?.call(map);
    if (!_accountBlockedController.isClosed) {
      _accountBlockedController.add(map);
    }
  }

  bool _containsBlockStatus(Map<String, dynamic> map) {
    return ConversationBlockStatus.payloadHasBlockStatus(map);
  }

  void _dispatchNewMessage(String event, dynamic data) {
    final map = _asMap(data);
    if (map == null) {
      debugPrint('[ChatSocket] $event ignored: non-map payload ($data)');
      return;
    }
    final payload = _unwrapMessagePayload(map);
    if (payload == null) {
      debugPrint('[ChatSocket] $event ignored: could not parse message ($map)');
      return;
    }
    _publishMessage(payload, source: event);
  }

  void _publishMessage(Map<String, dynamic> payload, {required String source}) {
    debugPrint('[ChatSocket] $source → message ${payload['_id'] ?? payload['id']}');
    onMessageReceived?.call(payload);
    if (!_newMessageController.isClosed) {
      _newMessageController.add(payload);
    }
  }

  /// Normalizes API/socket envelopes to the raw message object.
  Map<String, dynamic>? _unwrapMessagePayload(Map<String, dynamic> map) {
    Map<String, dynamic>? fromRoot(Map<String, dynamic> root) {
      final nested = root['message'];
      if (nested is Map) return Map<String, dynamic>.from(nested);

      if (_looksLikeChatMessage(root)) return root;

      final data = root['data'];
      if (data is Map) return fromRoot(Map<String, dynamic>.from(data));

      return null;
    }

    return fromRoot(map);
  }

  Future<void> joinConversation(String conversationId) async {
    final id = conversationId.trim();
    if (id.isEmpty) return;
    if (_authRejected) {
      debugPrint('[ChatSocket] skip join: previous auth failure');
      return;
    }

    if (_joinedConversationId != null && _joinedConversationId != id) {
      leaveConversation(_joinedConversationId!);
    }

    if (_joinedConversationId == id && isConnected) {
      return;
    }

    _joinedConversationId = id;
    _joinRetryCount = 0;
    _joinRetryTimer?.cancel();

    if (!isConnected) {
      await connect();
    }

    if (isConnected) {
      _emitJoinConversation(id);
    } else if (!_authRejected) {
      _scheduleJoinRetry(id);
    }
  }

  bool _isAuthFormatError(dynamic error) {
    final text = error?.toString().toLowerCase() ?? '';
    return text.contains('invalid token format') || text.contains('unauthorized') || text.contains('jwt');
  }

  void _scheduleJoinRetry(String conversationId) {
    if (_authRejected || _joinRetryCount >= 5) return;
    _joinRetryTimer?.cancel();
    _joinRetryTimer = Timer(Duration(seconds: 2 + _joinRetryCount), () async {
      if (_joinedConversationId != conversationId || _authRejected) return;
      _joinRetryCount++;
      debugPrint('[ChatSocket] join retry #$_joinRetryCount for $conversationId');
      if (!isConnected) await connect();
      if (_authRejected) return;
      if (isConnected && _joinedConversationId == conversationId) {
        _emitJoinConversation(conversationId);
      } else if (!_authRejected) {
        _scheduleJoinRetry(conversationId);
      }
    });
  }

  void leaveConversation(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) return;

    _joinRetryTimer?.cancel();
    _joinRetryCount = 0;

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
    _joinRetryTimer?.cancel();
    _joinRetryCount = 0;
    _authRejected = true;
    _joinedConversationId = null;
    _listenersAttached = false;
    _connectCompleter = null;

    final socket = _socket;
    _socket = null;
    if (socket == null) return;

    runZonedGuarded(() {
      try {
        if (socket.connected) {
          socket.disconnect();
        }
      } catch (e) {
        debugPrint('[ChatSocket] disconnect ignored: $e');
      }
      try {
        socket.dispose();
      } catch (e) {
        debugPrint('[ChatSocket] dispose ignored: $e');
      }
    }, (error, stack) {
      debugPrint('[ChatSocket] teardown ignored: $error');
    });
  }

  void _emitJoinConversation(String conversationId) {
    debugPrint('[ChatSocket] join-conversation: $conversationId');
    _socket?.emitWithAck('join-conversation', <String, dynamic>{'conversationId': conversationId}, ack: (ack) => debugPrint('[ChatSocket] join-conversation ack: $ack'));
  }

  bool _looksLikeChatMessage(Map<String, dynamic> map) {
    if (map.containsKey('message') && map['message'] is Map) return true;
    return map.containsKey('_id') || map.containsKey('id') || map.containsKey('content') || map.containsKey('messageType');
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty) return _asMap(data.first);
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        return _asMap(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
