import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/video_streaming_controller.dart';
import 'package:get_right/repo/marketplace_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

class VideoWalkthroughScreen extends StatefulWidget {
  const VideoWalkthroughScreen({super.key});

  @override
  State<VideoWalkthroughScreen> createState() => _VideoWalkthroughScreenState();
}

class _VideoWalkthroughScreenState extends State<VideoWalkthroughScreen> {
  final MarketplaceRepository _marketplaceRepo = MarketplaceRepository();

  String _exerciseName = '';
  String? _exerciseId;
  String? _videoUrl;
  String? _thumbnailUrl;
  bool _loadingMeta = false;
  bool _playerStarted = false;
  String? _playerTag;

  @override
  void initState() {
    super.initState();
    _readArgs();
    _loadVideoMeta();
  }

  void _readArgs() {
    final args = Get.arguments as Map<String, dynamic>?;
    if (args == null) return;
    _exerciseName = args['exerciseName']?.toString() ?? '';
    _exerciseId = args['exerciseId']?.toString();
    _videoUrl = ImageUrlSanitizer.asHttpUrlOrNull(args['videoUrl']?.toString());
    _thumbnailUrl = ImageUrlSanitizer.asHttpUrlOrNull(args['videoThumbnailUrl']?.toString());

    final refExercise = args['refExercise'];
    if (refExercise is Map) {
      final media = WorkoutRepository.videoMediaFromRefExercise(Map<String, dynamic>.from(refExercise));
      _videoUrl ??= ImageUrlSanitizer.asHttpUrlOrNull(media.videoUrl);
      _thumbnailUrl ??= ImageUrlSanitizer.asHttpUrlOrNull(media.thumbnailUrl);
    }
  }

  Future<void> _loadVideoMeta() async {
    final hasVideo = _videoUrl != null && _videoUrl!.isNotEmpty;
    final hasThumb = _thumbnailUrl != null && _thumbnailUrl!.isNotEmpty;
    if (hasVideo && hasThumb) return;
    if (!WorkoutRepository.isValidMongoId(_exerciseId)) return;

    setState(() => _loadingMeta = true);
    try {
      final detail = await _marketplaceRepo.fetchExerciseDetail(_exerciseId!);
      if (!mounted) return;
      setState(() {
        _videoUrl ??= ImageUrlSanitizer.asHttpUrlOrNull(detail.videoUrl);
        _thumbnailUrl ??= ImageUrlSanitizer.asHttpUrlOrNull(detail.videoThumbnailUrl ?? detail.iconUrl);
        if (_exerciseName.isEmpty) _exerciseName = detail.name;
      });
    } catch (_) {
      // Keep thumbnail / name from journal args when detail fetch fails.
    } finally {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  Future<void> _startPlayback() async {
    final url = _videoUrl;
    if (url == null || url.isEmpty) {
      Get.snackbar('Video unavailable', 'No walkthrough video for this exercise.', backgroundColor: AppColors.primaryGrayDark, colorText: AppColors.onSurface);
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      Get.snackbar('Video unavailable', 'Invalid video URL.', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }

    _playerTag ??= 'walkthrough_${uri.hashCode}';
    if (!Get.isRegistered<VideoStreamingController>(tag: _playerTag!)) {
      Get.put(VideoStreamingController(masterOrVideoUri: uri), tag: _playerTag!);
    }
    await Get.find<VideoStreamingController>(tag: _playerTag!).prepare();
    if (!mounted) return;
    setState(() => _playerStarted = true);
    Get.find<VideoStreamingController>(tag: _playerTag!).chewieController?.play();
  }

  void _togglePlayback() {
    final tag = _playerTag;
    if (!_playerStarted || tag == null || !Get.isRegistered<VideoStreamingController>(tag: tag)) {
      _startPlayback();
      return;
    }
    final controller = Get.find<VideoStreamingController>(tag: tag);
    final chewie = controller.chewieController;
    final vc = chewie?.videoPlayerController;
    if (vc == null) return;
    if (vc.value.isPlaying) {
      chewie?.pause();
    } else {
      chewie?.play();
    }
    if (mounted) setState(() {});
  }

  bool get _isPlaying {
    final tag = _playerTag;
    if (tag == null || !Get.isRegistered<VideoStreamingController>(tag: tag)) return false;
    return Get.find<VideoStreamingController>(tag: tag).chewieController?.videoPlayerController.value.isPlaying ?? false;
  }

  @override
  void dispose() {
    final tag = _playerTag;
    if (tag != null && Get.isRegistered<VideoStreamingController>(tag: tag)) {
      Get.delete<VideoStreamingController>(tag: tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posterUrl = _thumbnailUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text('Video Walkthrough', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPoster(posterUrl),
                    if (_playerStarted && _isPlaying && _playerTag != null)
                      GetBuilder<VideoStreamingController>(
                        tag: _playerTag!,
                        builder: (c) {
                          final chewie = c.chewieController;
                          if (chewie != null) {
                            return Chewie(key: ValueKey<int>(c.chewieRebuildKey), controller: chewie);
                          }
                          if (c.errorMessage.value.isNotEmpty) {
                            return _buildOverlayMessage(c.errorMessage.value);
                          }
                          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                        },
                      )
                    else if (_loadingMeta)
                      Container(
                        color: Colors.black26,
                        child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                      ),
                    if (!_playerStarted || !_isPlaying)
                      GestureDetector(
                        onTap: _videoUrl != null && _videoUrl!.isNotEmpty ? _togglePlayback : null,
                        child: Container(
                          color: _playerStarted ? Colors.black38 : Colors.black26,
                          child: Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), shape: BoxShape.circle),
                              child: Icon(_playerStarted && _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: AppColors.accent, size: 40),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _exerciseName.isNotEmpty ? _exerciseName : 'Exercise',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _videoUrl != null && _videoUrl!.isNotEmpty ? 'Tap play to watch the walkthrough' : 'No video available for this exercise',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _roundControl(icon: Icons.replay_10_rounded, onTap: _playerStarted ? _seekBackward : null),
                const SizedBox(width: 24),
                _roundControl(
                  icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  filled: true,
                  onTap: _videoUrl != null && _videoUrl!.isNotEmpty ? _togglePlayback : null,
                ),
                const SizedBox(width: 24),
                _roundControl(icon: Icons.forward_10_rounded, onTap: _playerStarted ? _seekForward : null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoster(String? posterUrl) {
    if (posterUrl != null && posterUrl.isNotEmpty) {
      return Image.network(
        posterUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _posterFallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _posterFallback(showLoader: true);
        },
      );
    }
    return _posterFallback();
  }

  Widget _posterFallback({bool showLoader = false}) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: showLoader ? const CircularProgressIndicator(color: AppColors.accent) : Icon(Icons.fitness_center, size: 48, color: AppColors.primaryGray.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildOverlayMessage(String message) {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Text(
        message,
        style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _roundControl({required IconData icon, required VoidCallback? onTap, bool filled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          width: filled ? 56 : 48,
          height: filled ? 56 : 48,
          decoration: BoxDecoration(
            color: filled ? AppColors.accent : AppColors.surface,
            shape: BoxShape.circle,
            border: filled ? null : Border.all(color: AppColors.primaryGrayLight, width: 2),
          ),
          child: Icon(icon, color: filled ? AppColors.onAccent : AppColors.onSurface, size: filled ? 28 : 24),
        ),
      ),
    );
  }

  void _seekBackward() {
    final tag = _playerTag;
    if (tag == null || !Get.isRegistered<VideoStreamingController>(tag: tag)) return;
    final vc = Get.find<VideoStreamingController>(tag: tag).chewieController?.videoPlayerController;
    if (vc == null || !vc.value.isInitialized) return;
    final pos = vc.value.position - const Duration(seconds: 10);
    vc.seekTo(pos < Duration.zero ? Duration.zero : pos);
  }

  void _seekForward() {
    final tag = _playerTag;
    if (tag == null || !Get.isRegistered<VideoStreamingController>(tag: tag)) return;
    final vc = Get.find<VideoStreamingController>(tag: tag).chewieController?.videoPlayerController;
    if (vc == null || !vc.value.isInitialized) return;
    final dur = vc.value.duration;
    final next = vc.value.position + const Duration(seconds: 10);
    vc.seekTo(next > dur ? dur : next);
  }
}
