import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';

/// Plays one chat audio message at a time using flutter_sound (already linked in the app).
class ChatAudioPlayerService extends ChangeNotifier {
  ChatAudioPlayerService._();

  static final ChatAudioPlayerService instance = ChatAudioPlayerService._();

  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  StreamSubscription<PlaybackDisposition>? _progressSub;
  bool _isOpen = false;
  Future<void>? _openFuture;
  Future<void> _serial = Future<void>.value();

  final Map<String, Duration> _cachedDurations = {};
  final Map<String, Duration> _cachedDurationsByUrl = {};
  final Set<String> _probingUrls = {};

  String? activeMessageId;
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  bool isActive(String messageId) => activeMessageId == messageId;

  Duration displayDuration(String messageId) {
    if (isActive(messageId)) {
      if (isPlaying || position > Duration.zero) return position;
      if (duration > Duration.zero) return duration;
    }
    return _cachedDurations[messageId] ?? Duration.zero;
  }

  void cacheDuration(String messageId, Duration value, {String? url}) {
    if (value <= Duration.zero) return;
    _cachedDurations[messageId] = value;
    final resolvedUrl = url?.trim();
    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      _cachedDurationsByUrl[resolvedUrl] = value;
    }
    notifyListeners();
  }

  void migrateDuration({required String fromMessageId, required String toMessageId, String? url}) {
    final existing = _cachedDurations[fromMessageId];
    if (existing != null && existing > Duration.zero) {
      cacheDuration(toMessageId, existing, url: url);
    }
    _cachedDurations.remove(fromMessageId);
  }

  Future<T> _runSerial<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _serial = _serial.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> ensureDurationCached(String messageId, String url) async {
    if (displayDuration(messageId) > Duration.zero) return;

    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) return;

    final cachedByUrl = _cachedDurationsByUrl[trimmedUrl];
    if (cachedByUrl != null && cachedByUrl > Duration.zero) {
      cacheDuration(messageId, cachedByUrl, url: trimmedUrl);
      return;
    }

    if (_probingUrls.contains(trimmedUrl)) return;

    try {
      await _runSerial(() async {
        if (displayDuration(messageId) > Duration.zero) return;

        final cachedAgain = _cachedDurationsByUrl[trimmedUrl];
        if (cachedAgain != null && cachedAgain > Duration.zero) {
          cacheDuration(messageId, cachedAgain, url: trimmedUrl);
          return;
        }

        if (_probingUrls.contains(trimmedUrl)) return;
        _probingUrls.add(trimmedUrl);
        try {
          if (isPlaying && activeMessageId != null) return;
          final probed = await _probeDuration(trimmedUrl);
          if (probed != null && probed > Duration.zero) {
            cacheDuration(messageId, probed, url: trimmedUrl);
          }
        } finally {
          _probingUrls.remove(trimmedUrl);
        }
      });
    } catch (_) {
      // Duration probing is best-effort; never crash the UI.
    }
  }

  Future<Duration?> _probeDuration(String url) async {
    await _ensureOpen();

    final completer = Completer<Duration?>();
    StreamSubscription<PlaybackDisposition>? probeSub;

    try {
      if (!_player.isStopped) {
        await _player.stopPlayer();
      }

      probeSub = _player.onProgress?.listen((event) {
        if (event.duration > Duration.zero && !completer.isCompleted) {
          completer.complete(event.duration);
        }
      });

      await _player.startPlayer(fromURI: url, codec: _codecForUrl(url), whenFinished: () {});

      final probed = await completer.future.timeout(const Duration(seconds: 6), onTimeout: () => null);

      await _player.stopPlayer();
      isPlaying = false;
      activeMessageId = null;
      position = Duration.zero;
      duration = Duration.zero;
      notifyListeners();
      return probed;
    } catch (_) {
      return null;
    } finally {
      await probeSub?.cancel();
    }
  }

  double progressFor(String messageId) {
    if (!isActive(messageId)) return 0;
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Future<void> _ensureOpen() async {
    if (_isOpen) return;
    if (_openFuture != null) {
      await _openFuture;
      return;
    }

    _openFuture = _openPlayerSafely();
    try {
      await _openFuture;
    } finally {
      _openFuture = null;
    }
  }

  Future<void> _openPlayerSafely() async {
    if (_isOpen) return;
    try {
      await _player.openPlayer();
      await _player.setSubscriptionDuration(const Duration(milliseconds: 200));
      _isOpen = true;
    } catch (e) {
      // flutter_sound throws if openPlayer races; treat as already open.
      if (kDebugMode) {
        debugPrint('[ChatAudioPlayer] openPlayer: $e');
      }
      _isOpen = true;
    }
  }

  void _attachProgressListener() {
    _progressSub?.cancel();
    _progressSub = _player.onProgress?.listen((event) {
      position = event.position;
      duration = event.duration;
      if (activeMessageId != null && event.duration > Duration.zero) {
        _cachedDurations[activeMessageId!] = event.duration;
      }
      notifyListeners();
    });
  }

  Codec _codecForUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.mp3')) return Codec.mp3;
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) return Codec.aacMP4;
    if (lower.endsWith('.wav')) return Codec.pcm16WAV;
    return Codec.aacADTS;
  }

  Future<void> toggle(String messageId, String url) async {
    try {
      await _runSerial(() => _toggleInternal(messageId, url));
    } catch (_) {
      isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> _toggleInternal(String messageId, String url) async {
    await _ensureOpen();
    _attachProgressListener();

    if (activeMessageId == messageId) {
      if (_player.isPlaying) {
        await _player.pausePlayer();
        isPlaying = false;
      } else if (_player.isPaused) {
        await _player.resumePlayer();
        isPlaying = true;
      } else {
        await _startPlayback(messageId, url);
      }
      notifyListeners();
      return;
    }

    if (!_player.isStopped) {
      await _player.stopPlayer();
    }
    await _startPlayback(messageId, url);
  }

  Future<void> _startPlayback(String messageId, String url) async {
    activeMessageId = messageId;
    position = Duration.zero;
    duration = Duration.zero;
    notifyListeners();

    await _player.startPlayer(
      fromURI: url,
      codec: _codecForUrl(url),
      whenFinished: () {
        isPlaying = false;
        activeMessageId = null;
        position = Duration.zero;
        notifyListeners();
      },
    );
    isPlaying = true;
    notifyListeners();
  }

  Future<void> stop() async {
    try {
      await _runSerial(() async {
        if (_isOpen && !_player.isStopped) {
          await _player.stopPlayer();
        }
        isPlaying = false;
        activeMessageId = null;
        position = Duration.zero;
        notifyListeners();
      });
    } catch (_) {
      isPlaying = false;
      activeMessageId = null;
      notifyListeners();
    }
  }

  Future<void> disposePlayer() async {
    try {
      await _runSerial(() async {
        await _progressSub?.cancel();
        _progressSub = null;
        if (_isOpen) {
          await _player.closePlayer();
          _isOpen = false;
        }
      });
    } catch (_) {
      _isOpen = false;
    }
  }
}
