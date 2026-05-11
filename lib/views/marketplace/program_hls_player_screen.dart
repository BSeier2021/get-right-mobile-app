import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/video_streaming_controller.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Thin UI shell for program / marketplace video — playback logic lives in [VideoStreamingController].
class ProgramHlsPlayerScreen extends StatefulWidget {
  const ProgramHlsPlayerScreen({super.key, required this.videoUri, required this.title});

  final Uri videoUri;
  final String title;

  @override
  State<ProgramHlsPlayerScreen> createState() => _ProgramHlsPlayerScreenState();
}

class _ProgramHlsPlayerScreenState extends State<ProgramHlsPlayerScreen> {
  late final String _tag;

  @override
  void initState() {
    super.initState();
    _tag = 'video_stream_${widget.videoUri.toString().hashCode}';
    Get.put(VideoStreamingController(masterOrVideoUri: widget.videoUri), tag: _tag).prepare();
  }

  @override
  void dispose() {
    if (Get.isRegistered<VideoStreamingController>(tag: _tag)) {
      Get.delete<VideoStreamingController>(tag: _tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Get.back<void>()),
        title: GetBuilder<VideoStreamingController>(
          tag: _tag,
          builder: (c) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.title, style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
                if (c.qualities.length > 1 && c.selectedQuality.value != null)
                  Text(
                    c.selectedQuality.value!.label,
                    style: AppTextStyles.labelSmall.copyWith(color: Colors.white70),
                  ),
              ],
            );
          },
        ),
        actions: [
          GetBuilder<VideoStreamingController>(
            tag: _tag,
            builder: (c) {
              if (c.qualities.length <= 1) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Quality',
                icon: const Icon(Icons.high_quality_rounded),
                onPressed: () => c.openQualityPicker(context),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Chewie sizes its outer AspectRatio from MediaQuery.size (full screen).
            // Override so it matches this viewport (below the AppBar); otherwise the
            // video is laid out with the wrong ratio and appears stretched.
            final mq = MediaQuery.of(context);
            final viewport = Size(
              constraints.maxWidth.clamp(1.0, 1000000.0),
              constraints.maxHeight.clamp(1.0, 1000000.0),
            );
            return MediaQuery(
              data: mq.copyWith(size: viewport),
              child: GetBuilder<VideoStreamingController>(
                tag: _tag,
                builder: (c) {
                  final err = c.errorMessage.value;
                  final busy = c.playerBusy.value;
                  final hasPlayer = c.chewieController != null;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasPlayer)
                        Chewie(
                          key: ValueKey<int>(c.chewieRebuildKey),
                          controller: c.chewieController!,
                        ),
                      if (!hasPlayer && err.isEmpty)
                        const Center(child: CircularProgressIndicator(color: AppColors.accentVariant)),
                      if (!hasPlayer && err.isNotEmpty)
                        _ErrorState(message: err, onBack: () => Get.back<void>()),
                      if (busy && hasPlayer)
                        const ColoredBox(
                          color: Color(0x66000000),
                          child: Center(child: CircularProgressIndicator(color: AppColors.accentVariant)),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_disabled_rounded, size: 56, color: AppColors.primaryGray.withValues(alpha: 0.85)),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onBack, child: const Text('Go back')),
          ],
        ),
      ),
    );
  }
}
