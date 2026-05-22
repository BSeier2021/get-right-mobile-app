import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/repo/marketplace_repo.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:get_right/widgets/safe_circle_network_avatar.dart';

/// Full-screen form to submit a program review (`POST /customer/program/:id/reviews`).
class ProgramSendReviewScreen extends StatefulWidget {
  const ProgramSendReviewScreen({super.key});

  @override
  State<ProgramSendReviewScreen> createState() => _ProgramSendReviewScreenState();
}

class _ProgramSendReviewScreenState extends State<ProgramSendReviewScreen> {
  final MarketplaceRepository _marketplaceRepo = MarketplaceRepository();
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();

  static final RegExp _mongoIdRe = RegExp(r'^[a-fA-F0-9]{24}$');

  late final String _programId;
  late final String _programTitle;
  late final String _trainerName;
  late final String _trainerInitials;
  String? _trainerAvatarUrl;

  double _rating = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final map = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
    _programId = (map['programId'] ?? map['id'] ?? '').toString().trim();
    _programTitle = map['programTitle']?.toString() ?? 'Program';
    _trainerName = map['trainerName']?.toString() ?? 'Trainer';
    _trainerInitials = map['trainerInitials']?.toString() ?? 'UT';
    _trainerAvatarUrl = ImageUrlSanitizer.asHttpUrlOrNull(map['trainerAvatarUrl']?.toString());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _ratingLabel(double rating) {
    if (rating <= 1) return 'Poor';
    if (rating <= 2) return 'Fair';
    if (rating <= 3) return 'Good';
    if (rating <= 4) return 'Very Good';
    return 'Excellent';
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rating == 0) {
      Get.snackbar('Missing Rating', 'Please select a star rating.', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }
    if (!_mongoIdRe.hasMatch(_programId)) {
      Get.snackbar('Review', 'Program id is missing. Cannot submit review.', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }

    setState(() => _submitting = true);
    try {
      final errorMessage = await _marketplaceRepo.submitProgramReview(
        programId: _programId,
        rating: _rating.round().clamp(1, 5),
        description: _commentController.text,
      );
      if (!mounted) return;
      if (errorMessage != null) {
        setState(() => _submitting = false);
        Get.snackbar('Review', errorMessage, snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
        return;
      }

      Get.back(result: {
        'submitted': true,
        'rating': _rating,
        'comment': _commentController.text.trim(),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      Get.snackbar('Review', e.toString(), snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.onBackground, size: 20),
          onPressed: _submitting ? null : () => Get.back(),
        ),
        title: Text('Send Review', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProgramCard(),
                    const SizedBox(height: 24),
                    Text('Your Rating', style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildStarRow(),
                    if (_rating > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        _ratingLabel(_rating),
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Text('Your Review', style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Share your experience with $_trainerName and this program.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _commentController,
                      maxLines: 6,
                      minLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
                      decoration: InputDecoration(
                        hintText: 'What did you like? What could be improved?',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
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
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please write your review';
                        }
                        if (value.trim().length < 10) {
                          return 'Review must be at least 10 characters';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                border: Border(top: BorderSide(color: AppColors.primaryGray.withOpacity(0.2))),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      disabledBackgroundColor: AppColors.accent.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Submit Review', style: AppTextStyles.buttonMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          if (_trainerAvatarUrl != null)
            SafeCircleNetworkAvatar(
              imageUrl: _trainerAvatarUrl,
              radius: 28,
              backgroundColor: AppColors.accent,
              fallback: Text(_trainerInitials, style: AppTextStyles.titleMedium.copyWith(color: AppColors.onAccent)),
            )
          else
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.accent,
              child: Text(_trainerInitials, style: AppTextStyles.titleMedium.copyWith(color: AppColors.onAccent)),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _programTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Rate $_trainerName', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final filled = index < _rating;
        return IconButton(
          onPressed: _submitting ? null : () => setState(() => _rating = (index + 1).toDouble()),
          icon: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.accent, size: 44),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        );
      }),
    );
  }
}
