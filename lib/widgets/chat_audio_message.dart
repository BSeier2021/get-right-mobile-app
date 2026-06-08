import 'package:flutter/material.dart';
import 'package:get_right/models/chat_message_model.dart';
import 'package:get_right/services/chat_audio_player_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// WhatsApp-style audio message bubble with play/pause and waveform.
class ChatAudioMessage extends StatefulWidget {
  const ChatAudioMessage({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

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
  }

  @override
  void dispose() {
    _playerService.removeListener(_onPlayerUpdate);
    super.dispose();
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.message.fileUrl;
    if (url == null || !url.startsWith('http')) {
      return Text(
        'Audio unavailable',
        style: AppTextStyles.bodyMedium.copyWith(
          color: widget.isCurrentUser ? AppColors.onAccent : AppColors.onSurface,
        ),
      );
    }

    final accent = widget.isCurrentUser ? AppColors.onAccent : AppColors.accent;
    final mutedAccent = accent.withOpacity(0.45);
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withOpacity(widget.isCurrentUser ? 0.18 : 0.12),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: accent,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AudioWaveform(
              progress: progress,
              activeColor: accent,
              inactiveColor: mutedAccent,
              seed: widget.message.id.hashCode,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(displayDuration),
            style: AppTextStyles.labelSmall.copyWith(
              color: accent.withOpacity(0.85),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
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

class _AudioWaveform extends StatelessWidget {
  const _AudioWaveform({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.seed,
  });

  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final int seed;

  static const List<double> _pattern = [
    0.35, 0.55, 0.85, 0.45, 0.95, 0.5, 0.75, 0.4, 0.9, 0.55,
    0.7, 0.35, 0.8, 0.5, 0.65, 0.9, 0.4, 0.75, 0.55, 0.85,
    0.45, 0.7, 0.6, 0.95, 0.5, 0.8, 0.4, 0.65,
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
                decoration: BoxDecoration(
                  color: isPlayed ? activeColor : inactiveColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
