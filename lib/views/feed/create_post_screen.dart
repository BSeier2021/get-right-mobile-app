import 'dart:io';

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:get_right/controllers/feed_publish_controller.dart';

import 'package:get_right/models/feed_category_model.dart';

import 'package:get_right/theme/color_constants.dart';

import 'package:get_right/theme/text_styles.dart';

import 'package:image_picker/image_picker.dart';

/// Create Post Screen — media picker + form; publish logic in [FeedPublishController].

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _tagsController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  late final FeedPublishController _feed = Get.find<FeedPublishController>();

  XFile? _selectedMedia;

  bool _isVideo = false;

  @override
  void initState() {
    super.initState();

    final args = Get.arguments as Map<String, dynamic>?;

    if (args != null && args['type'] != null) {
      _isVideo = args['type'] == 'video' || args['type'] == 'record';

      if (args['type'] == 'record') {
        _recordVideo();
      } else if (args['type'] == 'video') {
        _pickVideo();
      } else {
        _pickImage();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();

    _descriptionController.dispose();

    _tagsController.dispose();

    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedMedia = image;

          _isVideo = false;
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick image: $e',
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);

      if (video != null) {
        setState(() {
          _selectedMedia = video;

          _isVideo = true;
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick video: $e',
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _recordVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.camera);

      if (video != null) {
        setState(() {
          _selectedMedia = video;

          _isVideo = true;
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to record video: $e',
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _publishPost() async {
    if (_selectedMedia == null) {
      Get.snackbar(
        'Media Required',
        'Please select an image or video',
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      return;
    }

    if (_feed.isPublishing.value) return;

    await _feed.publish(
      mediaPath: _selectedMedia!.path,

      isVideo: _isVideo,

      title: _titleController.text,

      description: _descriptionController.text,

      tagsRaw: _tagsController.text,
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

      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,

        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Get.back(),
        ),

        title: Text('Create Post', style: AppTextStyles.titleLarge.copyWith()),

        centerTitle: true,

        actions: [
          Obx(() {
            final busy = _feed.isPublishing.value;

            return TextButton(
              onPressed: busy ? null : _publishPost,

              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.accent,
                        ),
                      ),
                    )
                  : Text(
                      'Publish',

                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            );
          }),
        ],
      ),

      body: Column(
        children: [
          Obx(() {
            if (!_feed.isPublishing.value) return const SizedBox.shrink();

            final label = _phaseLabel(_feed);

            return Material(
              elevation: 1,

              color: AppColors.surface,

              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,

                  children: [
                    if (label.isNotEmpty)
                      Text(
                        label,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.onBackground,
                        ),
                      ),

                    const SizedBox(height: 6),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),

                      child: LinearProgressIndicator(
                        value: _feed.uploadProgress.value <= 0
                            ? null
                            : _feed.uploadProgress.value.clamp(0.0, 1.0),

                        minHeight: 6,

                        backgroundColor: AppColors.primaryGray.withOpacity(0.2),

                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accent,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${(_feed.uploadProgress.value * 100).clamp(0, 100).toStringAsFixed(0)}%',

                      textAlign: TextAlign.end,

                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primaryGray,
                      ),
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
                  if (_selectedMedia != null)
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,

                          height: 400,

                          color: Colors.black,

                          child: _isVideo
                              ? Stack(
                                  alignment: Alignment.center,

                                  children: [
                                    Image.file(
                                      File(_selectedMedia!.path),

                                      fit: BoxFit.contain,

                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Center(
                                                child: Icon(
                                                  Icons.videocam,
                                                  size: 100,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                    ),

                                    Container(
                                      padding: const EdgeInsets.all(20),

                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),

                                      child: const Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 50,
                                      ),
                                    ),
                                  ],
                                )
                              : Image.file(
                                  File(_selectedMedia!.path),
                                  fit: BoxFit.contain,
                                ),
                        ),

                        Positioned(
                          top: 16,

                          right: 16,

                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),

                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),

                              onPressed: () {
                                if (_isVideo) {
                                  _pickVideo();
                                } else {
                                  _pickImage();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      width: double.infinity,

                      height: 300,

                      margin: const EdgeInsets.all(16),

                      decoration: BoxDecoration(
                        color: AppColors.surface,

                        borderRadius: BorderRadius.circular(16),

                        border: Border.all(
                          color: AppColors.primaryGray.withOpacity(0.3),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),

                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 80,
                            color: AppColors.primaryGray.withOpacity(0.5),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            'Add Media',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.primaryGray,
                            ),
                          ),

                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,

                            children: [
                              ElevatedButton.icon(
                                onPressed: _pickImage,

                                icon: const Icon(Icons.image),

                                label: const Text('Photo'),

                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                ),
                              ),

                              const SizedBox(width: 12),

                              ElevatedButton.icon(
                                onPressed: _pickVideo,

                                icon: const Icon(Icons.video_library),

                                label: const Text('Video'),

                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                ),
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

                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.onBackground,
                            fontWeight: FontWeight.bold,
                          ),
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

                              borderSide: BorderSide(
                                color: AppColors.primaryGray.withOpacity(0.3),
                              ),
                            ),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),

                              borderSide: BorderSide(
                                color: AppColors.primaryGray.withOpacity(0.3),
                              ),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),

                              borderSide: const BorderSide(
                                color: AppColors.accent,
                                width: 2,
                              ),
                            ),
                          ),

                          maxLength: 100,

                          textCapitalization: TextCapitalization.sentences,
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Description',

                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.onBackground,
                            fontWeight: FontWeight.bold,
                          ),
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

                              borderSide: BorderSide(
                                color: AppColors.primaryGray.withOpacity(0.3),
                              ),
                            ),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),

                              borderSide: BorderSide(
                                color: AppColors.primaryGray.withOpacity(0.3),
                              ),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),

                              borderSide: const BorderSide(
                                color: AppColors.accent,
                                width: 2,
                              ),
                            ),
                          ),

                          maxLines: 4,

                          maxLength: 500,

                          textCapitalization: TextCapitalization.sentences,
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Category',

                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.onBackground,
                            fontWeight: FontWeight.bold,
                          ),
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

                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.accent,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          if (_feed.feedCategoriesError.value != null) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  'Could not load categories.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.error,
                                  ),
                                ),

                                TextButton(
                                  onPressed: _feed.loadFeedCategories,
                                  child: const Text('Retry'),
                                ),
                              ],
                            );
                          }

                          if (_feed.feedCategories.isEmpty) {
                            return Text(
                              'No categories available.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.primaryGray,
                              ),
                            );
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),

                            decoration: BoxDecoration(
                              color: AppColors.surface,

                              borderRadius: BorderRadius.circular(12),

                              border: Border.all(
                                color: AppColors.primaryGray.withOpacity(0.3),
                              ),
                            ),

                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _feed.selectedCategoryId.value,

                                isExpanded: true,

                                hint: const Text('Select category'),

                                items: _feed.feedCategories.map((
                                  FeedCategory c,
                                ) {
                                  return DropdownMenuItem<String>(
                                    value: c.id,
                                    child: Text(c.name),
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

                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.onBackground,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          controller: _tagsController,

                          decoration: InputDecoration(
                            hintText: '#fitness #workout #motivation',

                            filled: true,

                            fillColor: AppColors.surface,

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),

                              borderSide: BorderSide(
                                color: AppColors.primaryGray.withOpacity(0.3),
                              ),
                            ),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),

                              borderSide: BorderSide(
                                color: AppColors.primaryGray.withOpacity(0.3),
                              ),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),

                              borderSide: const BorderSide(
                                color: AppColors.accent,
                                width: 2,
                              ),
                            ),

                            helperText: 'Separate tags with spaces',
                          ),

                          textCapitalization: TextCapitalization.none,
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
