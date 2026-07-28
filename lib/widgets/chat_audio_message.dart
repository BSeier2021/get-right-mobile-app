import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_right/models/chat_message_model.dart';
import 'package:get_right/services/chat_audio_player_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

/// WhatsApp-style audio message bubble with play/pause and waveform.
class ChatAudioMessage extends StatefulWidget {
  const ChatAudioMessage({super.key, required this.message, required this.isCurrentUser});

  final ChatMessageModel message;
  final bool isCurrentUser;

  @override
  State<ChatAudioMessage> createState() => _ChatAudioMessageState();
}

class _ChatAudioMessageState extends State<ChatAudioMessage> {
  final ChatAudioPlayerService _playerService = ChatAudioPlayerService.instance;

  @override
  void initState() {
    super.initState();
    _playerService.addListener(_onPlayerUpdate);
    _scheduleDurationResolve();
  }

  @override
  void didUpdateWidget(ChatAudioMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id || oldWidget.message.fileUrl != widget.message.fileUrl) {
      _scheduleDurationResolve();
    }
  }

  @override
  void dispose() {
    _playerService.removeListener(_onPlayerUpdate);
    super.dispose();
  }

  void _scheduleDurationResolve() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final url = _resolveAudioUrl();
      if (url == null || url.isEmpty) return;
      try {
        await _playerService.ensureDurationCached(widget.message.id, url);
      } catch (_) {
        // Best-effort duration resolve; playback still works without it.
      }
    });
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
  }

  String? _resolveAudioUrl() {
    for (final attachment in widget.message.displayAttachments) {
      if (!attachment.isVideo && !attachment.isImage) {
        final resolved = _resolveAttachmentUrl(attachment.url, isLocal: attachment.isLocal);
        if (resolved != null) return resolved;
      }
    }

    final fileUrl = widget.message.fileUrl?.trim();
    if (fileUrl != null && fileUrl.isNotEmpty) {
      return _resolveAttachmentUrl(fileUrl, isLocal: widget.message.isPending);
    }

    return null;
  }

  String? _resolveAttachmentUrl(String rawUrl, {required bool isLocal}) {
    final url = rawUrl.trim();
    if (url.isEmpty) return null;

    final lower = url.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return ImageUrlSanitizer.resolveMediaUrl(url) ?? ImageUrlSanitizer.asHttpUrlOrNull(url);
    }

    if (isLocal || !lower.startsWith('http')) {
      try {
        if (File(url).existsSync()) return url;
      } catch (_) {
        return url;
      }
      if (isLocal) return url;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolveAudioUrl();
    if (url == null || url.isEmpty) {
      if (widget.message.isPending) {
        return _PendingAudioPlaceholder(isCurrentUser: widget.isCurrentUser);
      }

      return Text('Audio unavailable', style: AppTextStyles.bodyMedium.copyWith(color: widget.isCurrentUser ? AppColors.onAccent : AppColors.onSurface));
    }

    final accent = widget.isCurrentUser ? AppColors.onAccent : AppColors.accent;
    final mutedAccent = accent.withValues(alpha: 0.45);
    final isActive = _playerService.isActive(widget.message.id);
    final isPlaying = isActive && _playerService.isPlaying;
    final progress = _playerService.progressFor(widget.message.id);
    final displayDuration = _playerService.displayDuration(widget.message.id);

    return SizedBox(
      width: 248,
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _playerService.toggle(widget.message.id, url),
              customBorder: const CircleBorder(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: widget.isCurrentUser ? 0.18 : 0.12)),
                child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: accent, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AudioWaveform(progress: progress, activeColor: accent, inactiveColor: mutedAccent, seed: widget.message.id.hashCode),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(displayDuration),
            style: AppTextStyles.labelSmall.copyWith(color: accent.withValues(alpha: 0.85), fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _PendingAudioPlaceholder extends StatelessWidget {
  const _PendingAudioPlaceholder({required this.isCurrentUser});

  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final accent = isCurrentUser ? AppColors.onAccent : AppColors.accent;

    return SizedBox(
      width: 248,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: isCurrentUser ? 0.18 : 0.12)),
            child: Icon(Icons.mic_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AudioWaveform(progress: 0, activeColor: accent, inactiveColor: accent.withValues(alpha: 0.45), seed: 11),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: accent)),
        ],
      ),
    );
  }
}

class _AudioWaveform extends StatelessWidget {
  const _AudioWaveform({required this.progress, required this.activeColor, required this.inactiveColor, required this.seed});

  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final int seed;

  static const List<double> _pattern = [
    0.35,
    0.55,
    0.85,
    0.45,
    0.95,
    0.5,
    0.75,
    0.4,
    0.9,
    0.55,
    0.7,
    0.35,
    0.8,
    0.5,
    0.65,
    0.9,
    0.4,
    0.75,
    0.55,
    0.85,
    0.45,
    0.7,
    0.6,
    0.95,
    0.5,
    0.8,
    0.4,
    0.65,
  ];

  @override
  Widget build(BuildContext context) {
    final playedBars = (progress * _pattern.length).floor();

    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_pattern.length, (index) {
          final heightFactor = _pattern[(index + seed.abs()) % _pattern.length];
          final isPlayed = index < playedBars;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: 6 + (heightFactor * 18),
                decoration: BoxDecoration(color: isPlayed ? activeColor : inactiveColor, borderRadius: BorderRadius.circular(999)),
              ),
            ),
          );
        }),
      ),
    );
  }
}
