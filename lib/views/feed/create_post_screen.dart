import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/feed_publish_controller.dart';
import 'package:get_right/models/feed_category_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// Create Post Screen — media picker + form; publish logic in [FeedPublishController].

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const int _maxImages = 5;

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _tagsController = TextEditingController();

  /// Tags committed from the field (Done / Enter). Order preserved, no duplicates (case-insensitive).
  final List<String> _committedTags = [];

  final ImagePicker _picker = ImagePicker();

  late final FeedPublishController _feed = Get.find<FeedPublishController>();

  final List<XFile> _selectedImages = [];
  XFile? _selectedVideo;
  int _previewImageIndex = 0;
  final PageController _imagePageController = PageController();

  bool get _isVideo => _selectedVideo != null;
  int get _remainingImageSlots => (_maxImages - _selectedImages.length).clamp(0, _maxImages);

  VideoPlayerController? _videoPreviewController;
  String? _videoPreviewPath;
  String? _videoPreviewInitError;

  String? _editingFeedId;
  String? _draftThumbnailUrl;
  bool _draftHasRemoteVideo = false;
  bool _draftIsVideo = false;

  bool get _hasLocalMedia => _isVideo || _selectedImages.isNotEmpty;
  bool get _hasRemoteMedia => _editingFeedId != null && (_draftThumbnailUrl?.isNotEmpty ?? false);
  bool get _canPublish => _hasLocalMedia || (_hasRemoteMedia && (!_draftIsVideo || _draftHasRemoteVideo));
  bool get _isEditingDraft => _editingFeedId != null;

  void _videoPreviewListener() {
    if (mounted) setState(() {});
  }

  Future<void> _disposeVideoPreview() async {
    final c = _videoPreviewController;
    _videoPreviewController = null;
    _videoPreviewPath = null;
    _videoPreviewInitError = null;
    if (c == null) return;
    c.removeListener(_videoPreviewListener);
    try {
      await c.dispose();
    } catch (_) {}
  }

  /// Local file preview for gallery/camera video (not [Image.file]).
  Future<void> _syncVideoPreview() async {
    final path = (_isVideo && _selectedVideo != null) ? _selectedVideo!.path.trim() : null;
    if (path == null || path.isEmpty) {
      await _disposeVideoPreview();
      if (mounted) setState(() {});
      return;
    }
    if (_videoPreviewPath == path && _videoPreviewController != null && _videoPreviewController!.value.isInitialized) {
      return;
    }

    await _disposeVideoPreview();
    _videoPreviewPath = path;
    _videoPreviewInitError = null;

    final controller = VideoPlayerController.file(File(path));
    _videoPreviewController = controller;
    controller.addListener(_videoPreviewListener);

    try {
      await controller.initialize();
      if (!mounted || _videoPreviewPath != path || _videoPreviewController != controller) {
        controller.removeListener(_videoPreviewListener);
        await controller.dispose();
        if (_videoPreviewController == controller) _videoPreviewController = null;
        return;
      }
      await controller.setLooping(true);
      if (mounted) setState(() {});
    } catch (e) {
      controller.removeListener(_videoPreviewListener);
      await controller.dispose();
      if (_videoPreviewController == controller) _videoPreviewController = null;
      _videoPreviewPath = null;
      _videoPreviewInitError = e.toString();
      if (mounted) setState(() {});
    }
  }

  void _toggleVideoPreviewPlayback() {
    final c = _videoPreviewController;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  void _applyDraftPost(Map<String, dynamic> post) {
    final id = (post['id'] ?? post['_id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    _editingFeedId = id;
    _titleController.text = (post['title'] ?? '').toString();
    _descriptionController.text = (post['description'] ?? '').toString();

    _committedTags
      ..clear()
      ..addAll((post['tags'] as List<dynamic>?)?.map((e) => e.toString().replaceFirst(RegExp(r'^#+'), '').trim()).where((t) => t.isNotEmpty).toList() ?? const <String>[]);

    final categoryId = (post['categoryId'] ?? '').toString().trim();
    if (categoryId.isNotEmpty) {
      _feed.setCategory(categoryId);
    }

    _draftIsVideo = post['isVideo'] == true;
    _draftHasRemoteVideo = _draftIsVideo && (post['videoUrl'] ?? '').toString().trim().isNotEmpty;
    _draftThumbnailUrl = ImageUrlSanitizer.asHttpUrlOrNull((post['thumbnail'] ?? post['imageUrl'] ?? '').toString());
  }

  @override
  void initState() {
    super.initState();

    final args = Get.arguments as Map<String, dynamic>?;

    if (args != null) {
      final post = args['post'];
      if (post is Map) {
        _applyDraftPost(Map<String, dynamic>.from(post));
      } else {
        final feedId = (args['feedId'] ?? args['id'])?.toString().trim();
        if (feedId != null && feedId.isNotEmpty) {
          _editingFeedId = feedId;
        }
      }

      final type = args['type'];
      if (type == 'record') {
        _recordVideo();
      } else if (type == 'video') {
        _pickVideo();
      }
      // 'image': show create screen first; user picks from Add Media / Photo (no auto gallery).
    }
  }

  @override
  void dispose() {
    final c = _videoPreviewController;
    _videoPreviewController = null;
    if (c != null) {
      c.removeListener(_videoPreviewListener);
      unawaited(c.dispose());
    }

    _titleController.dispose();

    _descriptionController.dispose();

    _tagsController.dispose();
    _imagePageController.dispose();

    super.dispose();
  }

  void _pickImage() {
    Get.dialog(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Photo',
                style: AppTextStyles.headlineMedium.copyWith(color: AppColors.onBackground, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: () {
                  Get.back();
                  unawaited(_pickImageFromSource(ImageSource.gallery));
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.photo_library_rounded, color: AppColors.accent, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gallery',
                              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text('Choose one or more photos', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontSize: 13)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.primaryGray),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  Get.back();
                  unawaited(_pickImageFromSource(ImageSource.camera));
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.camera_alt_rounded, color: AppColors.accent, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Camera',
                              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text('Take a new photo', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontSize: 13)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.primaryGray),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearImages() {
    _selectedImages.clear();
    _previewImageIndex = 0;
  }

  void _clearVideo() {
    _selectedVideo = null;
    unawaited(_disposeVideoPreview());
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final picked = await _picker.pickMultiImage(imageQuality: 85);
        if (picked.isEmpty) return;

        if (_remainingImageSlots <= 0) {
          Get.snackbar(
            'Limit reached',
            'You can add up to $_maxImages images per post.',
            backgroundColor: AppColors.upcoming,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }

        final beforeCount = _selectedImages.length;
        _clearVideo();
        setState(() {
          _selectedImages.addAll(picked.take(_remainingImageSlots));
          _previewImageIndex = _selectedImages.length - 1;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_imagePageController.hasClients) {
            _imagePageController.jumpToPage(_previewImageIndex);
          }
        });

        if (picked.length > _selectedImages.length - beforeCount) {
          Get.snackbar(
            'Limit reached',
            'You can add up to $_maxImages images per post.',
            backgroundColor: AppColors.upcoming,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        return;
      }

      if (_remainingImageSlots <= 0) {
        Get.snackbar(
          'Limit reached',
          'You can add up to $_maxImages images per post.',
          backgroundColor: AppColors.upcoming,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image != null) {
        _clearVideo();
        setState(() {
          _selectedImages.add(image);
          _previewImageIndex = _selectedImages.length - 1;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_imagePageController.hasClients) {
            _imagePageController.jumpToPage(_previewImageIndex);
          }
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e', backgroundColor: AppColors.error, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _goToPreviewImage(int index) {
    if (index < 0 || index >= _selectedImages.length) return;
    setState(() => _previewImageIndex = index);
    if (_imagePageController.hasClients) {
      _imagePageController.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _removeImageAt(int index) {
    if (index < 0 || index >= _selectedImages.length) return;
    setState(() {
      _selectedImages.removeAt(index);
      if (_selectedImages.isEmpty) {
        _previewImageIndex = 0;
      } else if (_previewImageIndex >= _selectedImages.length) {
        _previewImageIndex = _selectedImages.length - 1;
      } else if (_previewImageIndex > index) {
        _previewImageIndex--;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedImages.isEmpty) return;
      if (_imagePageController.hasClients) {
        _imagePageController.jumpToPage(_previewImageIndex);
      }
    });
  }

  Future<void> _pickVideo() async {
    try {
      final video = await _picker.pickVideo(source: ImageSource.gallery);

      if (video != null) {
        _clearImages();
        setState(() => _selectedVideo = video);
        await _syncVideoPreview();
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick video: $e', backgroundColor: AppColors.error, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _recordVideo() async {
    try {
      final video = await _picker.pickVideo(source: ImageSource.camera);

      if (video != null) {
        _clearImages();
        setState(() => _selectedVideo = video);
        await _syncVideoPreview();
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to record video: $e', backgroundColor: AppColors.error, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  List<String> _localMediaPaths() {
    if (_isVideo && _selectedVideo != null) return [_selectedVideo!.path];
    if (_selectedImages.isNotEmpty) return _selectedImages.map((e) => e.path).toList();
    return const [];
  }

  bool get _publishAsVideo => _hasLocalMedia ? _isVideo : _draftIsVideo;

  Future<void> _saveDraft() async {
    if (_feed.isPublishing.value || _feed.isSavingDraft.value) return;

    final id = await _feed.saveDraft(
      existingFeedId: _editingFeedId,
      title: _titleController.text,
      description: _descriptionController.text,
      tagsRaw: _combinedTagsRaw(),
      mediaPaths: _localMediaPaths(),
      isVideo: _publishAsVideo,
    );
    if (id != null && mounted) {
      setState(() => _editingFeedId = id);
    }
  }

  Future<void> _publishPost() async {
    if (!_canPublish) {
      Get.snackbar('Media Required', 'Please select an image or video', backgroundColor: AppColors.error, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (_feed.isPublishing.value || _feed.isSavingDraft.value) return;

    await _feed.publish(
      existingFeedId: _editingFeedId,
      hasExistingMedia: _hasRemoteMedia && !_hasLocalMedia && (!_draftIsVideo || _draftHasRemoteVideo),
      mediaPaths: _localMediaPaths(),
      isVideo: _publishAsVideo,
      title: _titleController.text,
      description: _descriptionController.text,
      tagsRaw: _combinedTagsRaw(),
    );
  }

  /// Tags sent to the API: committed chips plus any text still in the field.
  String _combinedTagsRaw() {
    final fromField = parseFeedTagsInput(_tagsController.text);
    final seen = <String>{};
    final out = <String>[];
    void add(String t) {
      final key = t.toLowerCase();
      if (seen.contains(key)) return;
      seen.add(key);
      out.add(t);
    }

    for (final t in _committedTags) {
      add(t);
    }
    for (final t in fromField) {
      add(t);
    }
    return out.join(' ');
  }

  void _commitTagsFromField() {
    final parsed = parseFeedTagsInput(_tagsController.text);
    if (parsed.isEmpty) return;
    setState(() {
      for (final t in parsed) {
        final exists = _committedTags.any((x) => x.toLowerCase() == t.toLowerCase());
        if (!exists) _committedTags.add(t);
      }
      _tagsController.clear();
    });
  }

  Widget _buildVideoPreviewPanel() {
    final err = _videoPreviewInitError;
    if (err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(
                'Could not play preview',
                style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                err,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final c = _videoPreviewController;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    final v = c.value;
    final w = v.size.width;
    final h = v.size.height;

    final Widget videoChild;
    if (w > 0 && h > 0) {
      videoChild = FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(width: w, height: h, child: VideoPlayer(c)),
      );
    } else {
      final ar = v.aspectRatio;
      videoChild = AspectRatio(aspectRatio: ar > 0 && !ar.isNaN ? ar : 16 / 9, child: VideoPlayer(c));
    }

    return GestureDetector(
      onTap: _toggleVideoPreviewPlayback,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(child: videoChild),
          if (!v.isPlaying)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 50),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePreviewPanel() {
    if (_selectedImages.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 400,
          child: PageView.builder(
            itemCount: _selectedImages.length,
            controller: _imagePageController,
            onPageChanged: (index) => setState(() => _previewImageIndex = index),
            itemBuilder: (context, index) {
              return Image.file(File(_selectedImages[index].path), fit: BoxFit.contain);
            },
          ),
        ),
        if (_selectedImages.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_selectedImages.length, (index) {
              final active = index == _previewImageIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 10 : 8,
                height: active ? 10 : 8,
                decoration: BoxDecoration(color: active ? AppColors.accent : AppColors.primaryGray.withValues(alpha: 0.4), shape: BoxShape.circle),
              );
            }),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _selectedImages.length + (_remainingImageSlots > 0 ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == _selectedImages.length) {
                return InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: AppColors.accent, size: 24),
                        const SizedBox(height: 4),
                        Text('Add', style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent)),
                      ],
                    ),
                  ),
                );
              }

              final selected = index == _previewImageIndex;
              return GestureDetector(
                onTap: () => _goToPreviewImage(index),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? AppColors.accent : Colors.transparent, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(File(_selectedImages[index].path), width: 72, height: 72, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => _removeImageAt(index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDraftRemotePreview() {
    final thumb = _draftThumbnailUrl ?? '';
    return Stack(
      children: [
        Container(
          width: double.infinity,
          color: Colors.black,
          child: SizedBox(
            height: 400,
            child: thumb.isNotEmpty
                ? Image.network(
                    thumb,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(child: Icon(_draftIsVideo ? Icons.videocam_outlined : Icons.image_outlined, color: Colors.white54, size: 56)),
                  )
                : Center(child: Icon(_draftIsVideo ? Icons.videocam_outlined : Icons.image_outlined, color: Colors.white54, size: 56)),
          ),
        ),
        if (_draftIsVideo)
          const Positioned.fill(
            child: Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 56)),
          ),
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.upcoming.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
            child: Text(
              'Draft media',
              style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
            child: IconButton(
              icon: Icon(_draftIsVideo ? Icons.videocam : Icons.edit, color: Colors.white),
              tooltip: _draftIsVideo ? 'Replace video' : 'Replace photos',
              onPressed: () {
                if (_draftIsVideo) {
                  _pickVideo();
                } else {
                  _pickImage();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaPreview() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          color: Colors.black,
          child: _isVideo ? SizedBox(height: 400, child: _buildVideoPreviewPanel()) : _buildImagePreviewPanel(),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isVideo && _remainingImageSlots > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white),
                    tooltip: 'Add photos',
                    onPressed: _pickImage,
                  ),
                ),
              Container(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                child: IconButton(
                  icon: Icon(_isVideo ? Icons.videocam : Icons.edit, color: Colors.white),
                  tooltip: _isVideo ? 'Change video' : 'Change photos',
                  onPressed: () {
                    if (_isVideo) {
                      _pickVideo();
                    } else {
                      _pickImage();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        if (!_isVideo && _selectedImages.length > 1)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${_previewImageIndex + 1}/${_selectedImages.length}',
                style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  String _phaseLabel(FeedPublishController c) {
    switch (c.publishPhase.value) {
      case 'creating':
        return 'Creating post…';

      case 'preparing_upload':
        return 'Preparing upload…';

      case 'uploading':
        return 'Uploading video…';

      case 'finishing':
        return 'Finishing…';

      case 'processing':
        return 'Processing video…';

      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,

        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,

          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),

          title: Text(_isEditingDraft ? 'Edit draft' : 'Create Post', style: AppTextStyles.titleLarge.copyWith()),

          centerTitle: true,
        ),

        bottomNavigationBar: Obx(() {
          final busy = _feed.isPublishing.value || _feed.isSavingDraft.value;
          final savingDraft = _feed.isSavingDraft.value;
          final publishing = _feed.isPublishing.value;

          return SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                border: Border(top: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.2))),
                boxShadow: [BoxShadow(color: AppColors.secondary.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : _saveDraft,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.onBackground,
                          side: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.45), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: savingDraft
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGray))
                            : const Icon(Icons.save_outlined, size: 20),
                        label: Text(
                          'Draft',
                          style: AppTextStyles.buttonMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.onBackground),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: busy ? null : _publishPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                          disabledForegroundColor: Colors.white70,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: publishing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.publish_rounded, size: 20),
                        label: Text(
                          'Publish',
                          style: AppTextStyles.buttonMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        body: Column(
          children: [
            Obx(() {
              if (!_feed.isPublishing.value && !_feed.isSavingDraft.value) return const SizedBox.shrink();

              final label = _feed.isSavingDraft.value ? 'Saving draft…' : _phaseLabel(_feed);

              return Material(
                elevation: 1,

                color: AppColors.surface,

                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,

                    children: [
                      if (label.isNotEmpty) Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.onBackground)),

                      const SizedBox(height: 6),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),

                        child: LinearProgressIndicator(
                          value: _feed.uploadProgress.value <= 0 ? null : _feed.uploadProgress.value.clamp(0.0, 1.0),

                          minHeight: 6,

                          backgroundColor: AppColors.primaryGray.withValues(alpha: 0.2),

                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '${(_feed.uploadProgress.value * 100).clamp(0, 100).toStringAsFixed(0)}%',

                        textAlign: TextAlign.end,

                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
                      ),
                    ],
                  ),
                ),
              );
            }),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    if (_hasLocalMedia)
                      _buildMediaPreview()
                    else if (_hasRemoteMedia)
                      _buildDraftRemotePreview()
                    else
                      Container(
                        width: double.infinity,

                        height: 300,

                        margin: const EdgeInsets.all(16),

                        decoration: BoxDecoration(
                          color: AppColors.surface,

                          borderRadius: BorderRadius.circular(16),

                          border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.3), width: 2, style: BorderStyle.solid),
                        ),

                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,

                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 80, color: AppColors.primaryGray.withValues(alpha: 0.5)),

                            const SizedBox(height: 16),

                            Text('Add Media', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),

                            const SizedBox(height: 24),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,

                              children: [
                                ElevatedButton.icon(
                                  onPressed: _pickImage,

                                  icon: const Icon(Icons.image),

                                  label: const Text('Photo'),

                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                                ),

                                const SizedBox(width: 12),

                                ElevatedButton.icon(
                                  onPressed: _pickVideo,

                                  icon: const Icon(Icons.video_library),

                                  label: const Text('Video'),

                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(16),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            'Title',

                            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                          ),

                          const SizedBox(height: 8),

                          TextField(
                            controller: _titleController,

                            decoration: InputDecoration(
                              hintText: 'Give your post a catchy title...',

                              filled: true,

                              fillColor: AppColors.surface,

                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),

                                borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3)),
                              ),

                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),

                                borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3)),
                              ),

                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),

                                borderSide: const BorderSide(color: AppColors.accent, width: 2),
                              ),
                            ),

                            maxLength: 100,

                            textCapitalization: TextCapitalization.sentences,
                          ),

                          const SizedBox(height: 16),

                          Text(
                            'Description',

                            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                          ),

                          const SizedBox(height: 8),

                          TextField(
                            controller: _descriptionController,

                            decoration: InputDecoration(
                              hintText: 'Tell your story...',

                              filled: true,

                              fillColor: AppColors.surface,

                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),

                                borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3)),
                              ),

                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),

                                borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3)),
                              ),

                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),

                                borderSide: const BorderSide(color: AppColors.accent, width: 2),
                              ),
                            ),

                            maxLines: 4,

                            maxLength: 500,

                            textCapitalization: TextCapitalization.sentences,
                          ),

                          const SizedBox(height: 16),

                          // Categories come from API: GET /user/feed-categories → data.categories[]
                          // (AuthRepository.getFeedCategoriesRepo → FeedPublishController.loadFeedCategories in onInit).
                          Text(
                            'Category',

                            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                          ),

                          const SizedBox(height: 8),

                          Obx(() {
                            if (_feed.feedCategoriesLoading.value) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),

                                child: Center(
                                  child: SizedBox(
                                    width: 24,

                                    height: 24,

                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent)),
                                  ),
                                ),
                              );
                            }

                            if (_feed.feedCategoriesError.value != null) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  Text('Could not load categories.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),

                                  TextButton(onPressed: _feed.loadFeedCategories, child: const Text('Retry')),
                                ],
                              );
                            }

                            if (_feed.feedCategories.isEmpty) {
                              return Text('No categories available.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray));
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),

                              decoration: BoxDecoration(
                                color: AppColors.surface,

                                borderRadius: BorderRadius.circular(12),

                                border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.3)),
                              ),

                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _feed.selectedCategoryId.value,

                                  isExpanded: true,

                                  // Compact text in the closed button and in the menu (selectedItemBuilder replaces item children).
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface, fontSize: 15, fontWeight: FontWeight.w500),

                                  hint: Text('Select category', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 15)),

                                  selectedItemBuilder: (context) {
                                    return _feed.feedCategories.map((FeedCategory c) {
                                      return Align(
                                        alignment: AlignmentDirectional.centerStart,
                                        child: Text(
                                          c.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface, fontSize: 15, fontWeight: FontWeight.w600),
                                        ),
                                      );
                                    }).toList();
                                  },

                                  items: _feed.feedCategories.map((FeedCategory c) {
                                    return DropdownMenuItem<String>(
                                      value: c.id,
                                      child: Text(
                                        c.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface, fontSize: 15),
                                      ),
                                    );
                                  }).toList(),

                                  onChanged: (value) => _feed.setCategory(value),
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 16),

                          Text(
                            'Tags',

                            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                          ),

                          const SizedBox(height: 8),

                          if (_committedTags.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _committedTags
                                  .map(
                                    (t) => InputChip(
                                      label: Text('#$t', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)),
                                      deleteIconColor: AppColors.primaryGray,
                                      backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                                      side: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.25)),
                                      onDeleted: () {
                                        setState(() => _committedTags.remove(t));
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 8),
                          ],

                          TextField(
                            controller: _tagsController,

                            decoration: InputDecoration(
                              hintText: 'Type a tag, then tap Done or Enter',

                              filled: true,

                              fillColor: AppColors.surface,

                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),

                                borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3)),
                              ),

                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),

                                borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3)),
                              ),

                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),

                                borderSide: const BorderSide(color: AppColors.accent, width: 2),
                              ),

                              helperText: 'Multiple words add multiple tags. # prefix\nis optional.',
                            ),

                            textCapitalization: TextCapitalization.none,

                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.done,
                            maxLines: 1,
                            onSubmitted: (_) => _commitTagsFromField(),
                            onEditingComplete: _commitTagsFromField,
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
