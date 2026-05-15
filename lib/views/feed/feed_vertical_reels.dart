import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:get_right/models/hls_video_quality.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/hls_master_playlist_parser.dart';
import 'package:video_player/video_player.dart';

/// YouTube Shorts–style vertical feed: autoplay visible reel, optionally preload neighbors (iOS ±1; Android current only to limit decoders).
///
/// Playback uses [video_player] with the same HLS variant resolution strategy as [VideoReelScreen].
class FeedVerticalReels extends StatefulWidget {
  const FeedVerticalReels({
    super.key,
    required this.posts,
    required this.pageController,
    required this.active,
    required this.onPageChangedIndex,
    required this.onNearEndIndex,
    required this.resolvePlaybackUrl,
    required this.backdropForPost,
    required this.overlay,
  });

  final List<Map<String, dynamic>> posts;
  final PageController pageController;

  /// When false (other tab visible), all playback pauses.
  final bool active;

  final ValueChanged<int> onPageChangedIndex;

  /// Fire when user scrolls near the end (parent loads next page).
  final ValueChanged<int> onNearEndIndex;

  /// Absolute playable URL after API/base-url resolution (or null if none).
  final String? Function(Map<String, dynamic> post) resolvePlaybackUrl;

  final Widget Function(BuildContext context, Map<String, dynamic> post) backdropForPost;

  /// Gradient, actions, captions — paints above video.
  /// [videoController] is the reel at [index] when initialized (same as video layer).
  final Widget Function(BuildContext context, Map<String, dynamic> post, int index, VideoPlayerController? videoController) overlay;

  @override
  State<FeedVerticalReels> createState() => _FeedVerticalReelsState();
}

class _FeedVerticalReelsState extends State<FeedVerticalReels> {
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _pending = {};
  final Map<int, String?> _errors = {};
  final Map<int, bool> _isPlaying = {};
  int _currentIndex = 0;

  /// Fewer simultaneous [VideoPlayer]s on Android lowers MediaCodec `BufferPool` churn and noisy PES demux warnings.
  int get _keepAliveRadius {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 0;
    }
    return 1;
  }

  Future<void> _disposeControllerQuiet(VideoPlayerController? controller) async {
    if (controller == null) return;
    try {
      await controller.dispose();
    } catch (e, st) {
      debugPrint('FeedReel: controller.dispose failed → $e\n$st');
    }
  }

  Future<Uri> _resolveReelPlaybackUri(String rawUrl) async {
    final trimmed = rawUrl.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.hasScheme) {
      throw FormatException('Invalid video URL');
    }
    final path = parsed.path.toLowerCase();
    if (!path.endsWith('.m3u8')) {
      return parsed;
    }
    try {
      final variants = await HlsMasterPlaylistParser.fetchVariantQualities(parsed);
      if (variants.isEmpty) {
        return parsed;
      }
      variants.sort((a, b) => (a.heightPx ?? 0).compareTo(b.heightPx ?? 0));

      // Prefer a capped fixed variant on Android to shrink decoder buffers vs 720p+.
      final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      final maxTierAndroid = 576;

      HlsVideoQuality? choice;

      if (isAndroid) {
        HlsVideoQuality? bestUnderCap;
        for (final q in variants) {
          final h = q.heightPx ?? 0;
          if (h <= 0) continue;
          if (h > maxTierAndroid) continue;
          if (bestUnderCap == null || (bestUnderCap.heightPx ?? 0) < h) {
            bestUnderCap = q;
          }
        }
        choice = bestUnderCap;
      }

      if (choice == null && isAndroid) {
        HlsVideoQuality? lowest;
        for (final q in variants) {
          final h = q.heightPx ?? 0;
          if (h <= 0) continue;
          if (lowest == null || h < (lowest.heightPx ?? 1 << 30)) {
            lowest = q;
          }
        }
        choice = lowest;
      }

      if (choice == null) {
        for (final q in variants) {
          final h = q.heightPx ?? 0;
          if (h >= 480 && h <= 720) {
            choice = q;
            break;
          }
        }
      }
      choice ??= variants.length >= 2 ? variants[variants.length ~/ 2] : variants.first;
      return choice.playbackUri;
    } catch (e) {
      debugPrint('FeedReel: HLS variant resolve failed, using master: $e');
      return parsed;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.pageController.initialPage.clamp(0, widget.posts.isEmpty ? 0 : widget.posts.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.posts.isEmpty || !widget.active) return;
      _preloadAround(_currentIndex);
    });
  }

  @override
  void didUpdateWidget(FeedVerticalReels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && oldWidget.active) {
      // Free decoder / texture buffers when tab not visible.
      _disposeAllControllers();
    } else if (widget.active && !oldWidget.active) {
      _playIndex(_currentIndex);
      _preloadAround(_currentIndex);
      _trimControllers(_currentIndex);
    }

    final newLen = widget.posts.length;
    final oldLen = oldWidget.posts.length;
    if (newLen < oldLen) {
      _disposeFromIndex(newLen);
    }

    if (widget.posts.isEmpty) {
      _disposeAllControllers();
    } else {
      _currentIndex = _currentIndex.clamp(0, widget.posts.length - 1);
    }
  }

  @override
  void dispose() {
    final toClose = List<VideoPlayerController>.from(_controllers.values);
    _controllers.clear();
    for (final c in toClose) {
      unawaited(_disposeControllerQuiet(c));
    }
    super.dispose();
  }

  void _disposeFromIndex(int from) {
    for (final k in _controllers.keys.toList()) {
      if (k >= from) {
        final c = _controllers.remove(k);
        unawaited(_disposeControllerQuiet(c));
        _isPlaying.remove(k);
        _errors.remove(k);
      }
    }
  }

  void _disposeAllControllers() {
    final snapshot = Map<int, VideoPlayerController>.from(_controllers);
    _controllers.clear();
    for (final c in snapshot.values) {
      unawaited(_disposeControllerQuiet(c));
    }
    _pending.clear();
    _errors.clear();
    _isPlaying.clear();
    if (mounted) setState(() {});
  }

  Future<void> _trimControllersSync(int center) async {
    final r = _keepAliveRadius;
    final minKeep = (center - r).clamp(0, 1 << 30);
    final maxKeep = center + r;
    for (final k in _controllers.keys.toList()) {
      if (k < minKeep || k > maxKeep) {
        final c = _controllers.remove(k);
        await _disposeControllerQuiet(c);
        _isPlaying.remove(k);
        _errors.remove(k);
      }
    }
  }

  void _trimControllers(int center) {
    unawaited(_trimControllersSync(center));
  }

  void _playIndex(int index) {
    if (!widget.active) return;
    for (final e in _controllers.entries) {
      if (e.key == index) {
        e.value.setLooping(true);
        e.value.play();
        _isPlaying[e.key] = true;
      } else {
        e.value.pause();
        _isPlaying[e.key] = false;
      }
    }
    if (mounted) setState(() {});
  }

  void _preloadAround(int center) {
    if (widget.posts.isEmpty) return;
    final r = _keepAliveRadius;
    final lo = (center - r).clamp(0, widget.posts.length - 1);
    final hi = (center + r).clamp(0, widget.posts.length - 1);
    for (var i = lo; i <= hi; i++) {
      _ensureVideo(i);
    }
    _trimControllers(center);
  }

  void _ensureVideo(int index) {
    if (index < 0 || index >= widget.posts.length) return;
    if (_controllers.containsKey(index) || _pending.contains(index)) return;

    final resolved = widget.resolvePlaybackUrl(widget.posts[index]);
    if (resolved == null || resolved.isEmpty) {
      setState(() => _errors[index] = 'No video for this post');
      return;
    }

    _pending.add(index);
    () async {
      Uri playbackUri;
      try {
        playbackUri = await _resolveReelPlaybackUri(resolved);
      } catch (_) {
        playbackUri = Uri.parse(resolved.trim());
      }

      if (!mounted) {
        _pending.remove(index);
        return;
      }

      Future<bool> tryPlay(Uri uri) async {
        VideoPlayerController? controller;
        try {
          controller = VideoPlayerController.networkUrl(uri);
          await controller.initialize().timeout(const Duration(seconds: 45));
        } catch (e) {
          debugPrint('FeedReel: init failed for $uri → $e');
          await _disposeControllerQuiet(controller);
          return false;
        }

        if (!mounted) {
          await _disposeControllerQuiet(controller);
          return false;
        }

        final existing = _controllers.remove(index);
        if (existing != null) await _disposeControllerQuiet(existing);

        _controllers[index] = controller;
        await controller.setLooping(true);

        final shouldPlay = widget.active && index == _currentIndex;
        _isPlaying[index] = shouldPlay;
        if (shouldPlay) {
          await controller.play();
        }

        await _trimControllersSync(_currentIndex);
        _errors.remove(index);
        return true;
      }

      var ok = await tryPlay(playbackUri);
      if (!ok && playbackUri.toString() != resolved.trim()) {
        ok = await tryPlay(Uri.parse(resolved.trim()));
      }

      _pending.remove(index);

      if (!ok && mounted) {
        setState(() => _errors[index] = 'Could not load video');
      } else if (mounted) {
        _playIndex(_currentIndex);
        setState(() {});
      }
    }();
  }

  void _onPageChanged(int index) {
    widget.onNearEndIndex(index);
    widget.onPageChangedIndex(index);

    final prev = _currentIndex;
    _currentIndex = index;

    if (_controllers.containsKey(prev)) {
      _controllers[prev]?.pause();
      _isPlaying[prev] = false;
    }

    _preloadAround(index);

    if (_controllers.containsKey(index)) {
      _playIndex(index);
    } else {
      _ensureVideo(index);
      if (_controllers.containsKey(index)) {
        _playIndex(index);
      }
    }

    setState(() {});
  }

  void _togglePlayPause(int index) {
    if (!_controllers.containsKey(index)) {
      _ensureVideo(index);
      return;
    }
    final controller = _controllers[index]!;
    if (!controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
      _isPlaying[index] = false;
    } else {
      controller.play();
      _isPlaying[index] = true;
    }
    setState(() {});
  }

  void _retry(int index) {
    final c = _controllers.remove(index);
    unawaited(_disposeControllerQuiet(c));
    _errors.remove(index);
    _pending.remove(index);
    _ensureVideo(index);
    setState(() {});
  }

  /// Prefer [post] `videoPixelWidth` / `videoPixelHeight` when set (display size from API metadata, then encoded);
  /// otherwise [post] `videoAspectRatio` (`metadata.aspectRatio` or derived from display/encoded dimensions).
  Widget _coverVideo(VideoPlayerController controller, Map<String, dynamic> post) {
    final apiW = post['videoPixelWidth'];
    final apiH = post['videoPixelHeight'];
    if (apiW is num && apiH is num) {
      final dw = apiW.toDouble();
      final dh = apiH.toDouble();
      if (dw > 0 && dh > 0) {
        return FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          child: SizedBox(width: dw, height: dh, child: VideoPlayer(controller)),
        );
      }
    }

    final arObj = post['videoAspectRatio'];
    if (arObj is num && arObj > 0 && !arObj.isNaN) {
      final ar = arObj.toDouble();
      return FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.center,
        child: AspectRatio(aspectRatio: ar, child: VideoPlayer(controller)),
      );
    }

    final v = controller.value;
    final w = v.size.width;
    final h = v.size.height;
    if (w > 0 && h > 0) {
      return FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.center,
        child: SizedBox(width: w, height: h, child: VideoPlayer(controller)),
      );
    }
    final controllerAr = v.aspectRatio;
    if (controllerAr > 0 && !controllerAr.isNaN) {
      return FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.center,
        child: AspectRatio(aspectRatio: controllerAr, child: VideoPlayer(controller)),
      );
    }
    return VideoPlayer(controller);
  }
  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty) {
      return const SizedBox.shrink();
    }

    return PageView.builder(
      controller: widget.pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: _onPageChanged,
      itemCount: widget.posts.length,
      itemBuilder: (context, index) {
        final post = widget.posts[index];
        final hasVideo = _controllers.containsKey(index) && _controllers[index]!.value.isInitialized;
        final loadError = _errors[index];

        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.black),
            // Video touch target (below chrome)
            if (hasVideo)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _togglePlayPause(index),
                child: SizedBox.expand(
                  child: ClipRect(child: _coverVideo(_controllers[index]!, post)),
                ),
              )
            else if (loadError != null)
              GestureDetector(
                onTap: () => _retry(index),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.backdropForPost(context, post),
                    Container(color: Colors.black.withValues(alpha: 0.45)),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              loadError,
                              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: () => _retry(index),
                              style: TextButton.styleFrom(foregroundColor: AppColors.accentVariant),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Stack(
                fit: StackFit.expand,
                children: [
                  widget.backdropForPost(context, post),
                  const Center(child: CircularProgressIndicator(color: AppColors.accentVariant)),
                ],
              ),

            widget.overlay(context, post, index, hasVideo ? _controllers[index] : null),

            if (hasVideo && (_isPlaying[index] != true))
              Center(
                child: GestureDetector(
                  onTap: () => _togglePlayPause(index),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
