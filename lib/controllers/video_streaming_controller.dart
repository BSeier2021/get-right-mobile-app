import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_right/models/hls_video_quality.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/hls_master_playlist_parser.dart';
import 'package:video_player/video_player.dart';

/// Program / marketplace video playback — HLS (.m3u8) parsing, [Chewie] UI hooks, manual quality selection.
///
/// Pass the **canonical** playback URI (typically `master.m3u8`). Variants are discovered by fetching the playlist.
class VideoStreamingController extends GetxController {
  VideoStreamingController({required this.masterOrVideoUri});

  final Uri masterOrVideoUri;

  final RxBool playerBusy = false.obs;
  final RxString errorMessage = ''.obs;

  final RxList<HlsVideoQuality> qualities = <HlsVideoQuality>[].obs;
  final Rxn<HlsVideoQuality> selectedQuality = Rxn<HlsVideoQuality>();

  ChewieController? chewieController;

  int chewieRebuildKey = 0;

  @override
  void onInit() {
    super.onInit();
    ever(playerBusy, (_) => update());
    ever(errorMessage, (_) => update());
  }

  Future<void> prepare() async {
    playerBusy.value = true;
    errorMessage.value = '';
    chewieController?.dispose();
    chewieController = null;

    try {
      var variants = <HlsVideoQuality>[];

      final pathLower = masterOrVideoUri.path.toLowerCase();
      if (pathLower.endsWith('.m3u8')) {
        try {
          variants = await HlsMasterPlaylistParser.fetchVariantQualities(masterOrVideoUri);
        } catch (e, st) {
          debugPrint('VideoStreaming: playlist fetch/parse skipped: $e\n$st');
        }
      }

      if (variants.isEmpty) {
        qualities.assignAll([HlsVideoQuality.auto(masterOrVideoUri)]);
      } else {
        qualities.assignAll([HlsVideoQuality.auto(masterOrVideoUri), ...variants]);
      }
      selectedQuality.value = qualities.first;

      await _openPlayerAt(selectedQuality.value!.playbackUri);
    } catch (e, st) {
      debugPrint('VideoStreaming prepare: $e\n$st');
      errorMessage.value = e.toString();
    } finally {
      playerBusy.value = false;
      update();
    }
  }

  Future<void> selectQuality(HlsVideoQuality q) async {
    if (selectedQuality.value?.id == q.id) return;
    playerBusy.value = true;
    update();
    selectedQuality.value = q;
    try {
      await _openPlayerAt(q.playbackUri);
    } catch (e) {
      errorMessage.value = e.toString();
      if (!Get.isSnackbarOpen) {
        Get.snackbar('Playback', errorMessage.value, snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      playerBusy.value = false;
      update();
    }
  }

  Future<void> _openPlayerAt(Uri playbackUri) async {
    // Snapshot before swapping — switching quality uses the same timeline (same-second resume).
    final priorVc = chewieController?.videoPlayerController;
    var resumePosition = Duration.zero;
    var wasPlaying = true;
    var playbackSpeed = 1.0;
    var volume = 1.0;
    if (priorVc != null && priorVc.value.isInitialized) {
      resumePosition = priorVc.value.position;
      wasPlaying = priorVc.value.isPlaying;
      playbackSpeed = priorVc.value.playbackSpeed;
      volume = priorVc.value.volume;
    }

    final newVc = VideoPlayerController.networkUrl(playbackUri);
    await newVc.initialize();

    final total = newVc.value.duration;
    var seekTo = resumePosition;
    if (total != Duration.zero) {
      if (seekTo >= total) {
        seekTo = total - const Duration(milliseconds: 250);
      }
      if (seekTo.isNegative) seekTo = Duration.zero;
    }

    await newVc.seekTo(seekTo);
    await newVc.setPlaybackSpeed(playbackSpeed);
    await newVc.setVolume(volume);

    final ratio = (newVc.value.aspectRatio > 0 && !newVc.value.aspectRatio.isNaN) ? newVc.value.aspectRatio : 16 / 9;

    final showOpts = qualities.length > 1;

    chewieRebuildKey++;

    final newChewie = ChewieController(
      videoPlayerController: newVc,
      autoPlay: wasPlaying,
      looping: false,
      aspectRatio: ratio,
      allowFullScreen: true,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
      showControls: true,
      draggableProgressBar: true,
      showOptions: showOpts,
      additionalOptions: showOpts ? (context) => _qualityChewieOption() : null,
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.accent,
        handleColor: AppColors.accentVariant,
        backgroundColor: AppColors.primaryGray.withValues(alpha: 0.35),
        bufferedColor: AppColors.accent.withValues(alpha: 0.45),
      ),
      errorBuilder: (context, message) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Could not load video.\n$message',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );

    final oldChewie = chewieController;
    chewieController = newChewie;

    update();

    oldChewie?.dispose();
  }

  List<OptionItem> _qualityChewieOption() {
    final label = selectedQuality.value?.label ?? 'Auto';
    return [OptionItem(onTap: openQualityPicker, iconData: Icons.high_quality_rounded, title: 'Quality', subtitle: label)];
  }

  /// Open from Chewie "⋯" — [context] is provided by chewie controls.
  void openQualityPicker(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.55;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      constraints: BoxConstraints(maxHeight: maxHeight),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        'Video quality',
                        style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: Obx(() {
                    final cur = selectedQuality.value;
                    return ListView.builder(
                      itemCount: qualities.length,
                      itemBuilder: (context, index) {
                        final q = qualities[index];
                        final sel = cur?.id == q.id;
                        return ListTile(
                          title: Text(
                            q.label,
                            style: TextStyle(color: sel ? AppColors.accentVariant : Colors.white, fontWeight: sel ? FontWeight.w700 : FontWeight.w500),
                          ),
                          subtitle: q.isAdaptive
                              ? Text('Adaptive bitrate (recommended)', style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 12))
                              : Text('Fixed rendition', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                          trailing: sel ? Icon(Icons.check_rounded, color: AppColors.accentVariant) : null,
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            Navigator.pop(ctx);
                            await selectQuality(q);
                          },
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void onClose() {
    chewieController?.dispose();
    chewieController = null;
    super.onClose();
  }
}
