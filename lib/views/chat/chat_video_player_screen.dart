import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:video_player/video_player.dart';

class ChatVideoPlayerScreen extends StatefulWidget {
  const ChatVideoPlayerScreen({super.key, required this.videoUrl, this.title});

  final String videoUrl;
  final String? title;

  @override
  State<ChatVideoPlayerScreen> createState() => _ChatVideoPlayerScreenState();
}

class _ChatVideoPlayerScreenState extends State<ChatVideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri == null) {
      setState(() => _error = 'Invalid video URL');
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _videoController = controller;

    try {
      await controller.initialize();
      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.accent,
          handleColor: AppColors.accent,
          bufferedColor: AppColors.primaryGray,
          backgroundColor: AppColors.primaryGrayDark,
        ),
      );
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? 'Video', style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70), textAlign: TextAlign.center),
              )
            : _chewieController == null
            ? const CircularProgressIndicator(color: AppColors.accent)
            : Chewie(controller: _chewieController!),
      ),
    );
  }
}
