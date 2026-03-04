import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/enrolled_program_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// Completed Program Detail Screen
class CompletedProgramDetailScreen extends StatefulWidget {
  const CompletedProgramDetailScreen({super.key});

  @override
  State<CompletedProgramDetailScreen> createState() => _CompletedProgramDetailScreenState();
}

class _CompletedProgramDetailScreenState extends State<CompletedProgramDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  double _rating = 0.0;
  List<XFile> _selectedImages = [];
  bool _hasReview = false;
  Review? _existingReview;

  @override
  void initState() {
    super.initState();
    final program = Get.arguments as EnrolledProgramModel?;
    if (program?.review != null) {
      _hasReview = true;
      _existingReview = program!.review;
      _rating = _existingReview!.rating;
      _commentController.text = _existingReview!.comment;
      // Note: In a real app, you'd load images from URLs
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _showImageSourceDialog() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Image Source',
                style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(Icons.camera_alt, 'Camera', () {
                    Get.back();
                    _pickImage(ImageSource.camera);
                  }),
                  _buildImageSourceOption(Icons.photo_library, 'Gallery', () {
                    Get.back();
                    _pickImage(ImageSource.gallery);
                  }),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Cancel', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.primaryGray)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceOption(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.accent, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)),
        ],
      ),
    );
  }

  void _submitReview() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_rating == 0) {
      Get.snackbar('Missing Rating', 'Please provide a rating', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }

    // TODO: Submit review to backend
    Get.snackbar(
      'Review Submitted',
      'Thank you for your feedback!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.completed,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );

    setState(() {
      _hasReview = true;
    });
  }

  void _downloadProgressReport(EnrolledProgramModel program) {
    // TODO: Implement actual PDF generation and download
    Get.snackbar(
      'Download Started',
      'Progress report for ${program.programTitle} is being generated...',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.accent,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final program = Get.arguments as EnrolledProgramModel?;
    if (program == null) {
      Get.back();
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: Text('Program Details', style: AppTextStyles.titleLarge.copyWith()), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Program Header
            _buildProgramHeader(program),
            const SizedBox(height: 24),

            // Program Info
            _buildSectionTitle('Program Information'),
            const SizedBox(height: 12),
            _buildInfoCard(program),
            const SizedBox(height: 24),

            // Progress Report
            _buildSectionTitle('Progress Report'),
            const SizedBox(height: 12),
            _buildProgressReportCard(program),
            const SizedBox(height: 24),

            // Trainer Rating Section
            _buildSectionTitle(_hasReview ? 'Your Trainer Rating' : 'Rate Your Trainer'),
            const SizedBox(height: 12),
            if (_hasReview) _buildExistingReviewCard(_existingReview!, program) else _buildReviewForm(program),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramHeader(EnrolledProgramModel program) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.completed.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.completed,
                child: Text(
                  program.trainerImage ?? program.trainerName[0],
                  style: AppTextStyles.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.programTitle,
                      style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('by ${program.trainerName}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.completed.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(
              'COMPLETED',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.completed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildInfoCard(EnrolledProgramModel program) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _buildInfoRow('Category', program.category),
          const Divider(color: AppColors.primaryGray, height: 24),
          _buildInfoRow('Duration', '${program.durationWeeks} weeks'),
          const Divider(color: AppColors.primaryGray, height: 24),
          _buildInfoRow('Completed Date', program.completedAt != null ? DateFormat('MMM dd, yyyy').format(program.completedAt!) : 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildProgressReportCard(EnrolledProgramModel program) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Progress Report',
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Download your complete progress report', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                ],
              ),
              Icon(Icons.description, color: AppColors.accent, size: 32),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _downloadProgressReport(program),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.download, color: Colors.white),
              label: Text('Download Report', style: AppTextStyles.buttonMedium.copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingReviewCard(Review review, EnrolledProgramModel program) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trainer Info
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accent,
                child: Text(program.trainerImage ?? program.trainerName[0], style: AppTextStyles.labelMedium.copyWith(color: AppColors.onAccent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rating for ${program.trainerName}',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(index < review.rating ? Icons.star : Icons.star_border, color: AppColors.accent, size: 20);
                        }),
                        const SizedBox(width: 8),
                        Text(
                          review.rating.toStringAsFixed(1),
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.primaryGray, height: 1),
          const SizedBox(height: 12),
          Text('Your Comment', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGray)),
          const SizedBox(height: 4),
          Text(review.comment, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
          if (review.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Media: ${review.mediaUrls.length} file(s)', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
          ],
          const SizedBox(height: 8),
          Text('Submitted on ${DateFormat('MMM dd, yyyy').format(review.createdAt)}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
        ],
      ),
    );
  }

  Widget _buildReviewForm(EnrolledProgramModel program) {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trainer Info Header
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.accent,
                  child: Text(program.trainerImage ?? program.trainerName[0], style: AppTextStyles.titleMedium.copyWith(color: AppColors.onAccent)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rate ${program.trainerName}',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                      ),
                      Text('Share your experience with this trainer', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: AppColors.primaryGray, height: 1),
            const SizedBox(height: 20),

            // Rating
            Text(
              'Your Rating',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _rating = (index + 1).toDouble();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(index < _rating ? Icons.star : Icons.star_border, color: AppColors.accent, size: 36),
                  ),
                );
              }),
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              Text(
                _rating == 1
                    ? 'Poor'
                    : _rating == 2
                    ? 'Fair'
                    : _rating == 3
                    ? 'Good'
                    : _rating == 4
                    ? 'Very Good'
                    : 'Excellent',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 24),

            // Comment
            Text(
              'Your Review Comment',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('Tell others about your experience with ${program.trainerName}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _commentController,
              maxLines: 4,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: 'Share your experience...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                filled: true,
                fillColor: AppColors.primaryVariant,
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
                  borderSide: BorderSide(color: AppColors.accent, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide a comment';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Media Upload
            Text('Add Photos/Videos', style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showImageSourceDialog,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppColors.accent, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(Icons.add_photo_alternate, color: AppColors.accent, size: 20),
                    label: Text('Add Media', style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent)),
                  ),
                ),
              ],
            ),
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryGray),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(_selectedImages[index].path), fit: BoxFit.cover, width: 100, height: 100),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
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
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Submit Review',
                  style: AppTextStyles.buttonMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
