import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:image_picker/image_picker.dart';

/// Create Post Screen - Upload images or videos
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

  XFile? _selectedMedia;
  bool _isVideo = false;
  bool _isLoading = false;

  final List<String> _categories = ['Workout', 'Nutrition', 'Running', 'Sports', 'Mobility', 'Lifestyle'];

  String _selectedCategory = 'Workout';

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args['type'] != null) {
      _isVideo = args['type'] == 'video';
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
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null) {
        setState(() {
          _selectedMedia = image;
          _isVideo = false;
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e', backgroundColor: AppColors.error, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
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
      Get.snackbar('Error', 'Failed to pick video: $e', backgroundColor: AppColors.error, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
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
      Get.snackbar('Error', 'Failed to record video: $e', backgroundColor: AppColors.error, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _publishPost() async {
    if (_selectedMedia == null) {
      Get.snackbar('Media Required', 'Please select an image or video', backgroundColor: AppColors.error, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      Get.snackbar('Title Required', 'Please enter a title for your post', backgroundColor: AppColors.error, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate upload
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
    });

    Get.back();
    Get.snackbar(
      'Post Published',
      'Your post has been shared successfully!',
      backgroundColor: AppColors.completed,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),
        title: Text('Create Post', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _publishPost,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent)))
                : Text(
                    'Publish',
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media Preview
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
                                errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.videocam, size: 100, color: Colors.white54)),
                              ),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                                child: const Icon(Icons.play_arrow, color: Colors.white, size: 50),
                              ),
                            ],
                          )
                        : Image.file(File(_selectedMedia!.path), fit: BoxFit.contain),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
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
                  border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 2, style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 80, color: AppColors.primaryGray.withOpacity(0.5)),
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

            // Post Details Form
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
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
                        borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.3)),
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

                  // Description
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
                        borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.3)),
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

                  // Category
                  Text(
                    'Category',
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        items: _categories.map((category) {
                          return DropdownMenuItem(value: category, child: Text(category));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tags
                  Text(
                    'Tags',
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
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
                        borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accent, width: 2),
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
    );
  }
}
