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
  final Map<String, Duration> _cachedDurations = {};

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

  double progressFor(String messageId) {
    if (!isActive(messageId)) return 0;
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Future<void> _ensureOpen() async {
    if (_isOpen) return;
    await _player.openPlayer();
    await _player.setSubscriptionDuration(const Duration(milliseconds: 200));
    _isOpen = true;
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
    if (_isOpen && !_player.isStopped) {
      await _player.stopPlayer();
    }
    isPlaying = false;
    activeMessageId = null;
    position = Duration.zero;
    notifyListeners();
  }

  Future<void> disposePlayer() async {
    await _progressSub?.cancel();
    _progressSub = null;
    if (_isOpen) {
      await _player.closePlayer();
      _isOpen = false;
    }
  }
}
