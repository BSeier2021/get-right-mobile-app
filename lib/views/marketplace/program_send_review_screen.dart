import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/repo/marketplace_repo.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:get_right/widgets/safe_circle_network_avatar.dart';

/// Full-screen form to submit a program review (`POST /customer/program/:id/reviews`).
class ProgramSendReviewScreen extends StatefulWidget {
  const ProgramSendReviewScreen({
    super.key,
    required this.programId,
    this.programTitle = 'Program',
    this.trainerName = 'Trainer',
    this.trainerInitials = 'UT',
    this.trainerAvatarUrl,
    this.infoMessage,
    this.reviewId,
    this.initialRating,
    this.initialComment,
  });

  final String programId;
  final String programTitle;
  final String trainerName;
  final String trainerInitials;
  final String? trainerAvatarUrl;

  /// Optional hint (e.g. enroll first); does not disable the form.
  final String? infoMessage;
  final String? reviewId;
  final double? initialRating;
  final String? initialComment;

  bool get isEditing => reviewId != null && reviewId!.trim().isNotEmpty;

  /// Supports legacy `Get.toNamed` / `Get.arguments` navigation.
  factory ProgramSendReviewScreen.fromArguments([dynamic args]) {
    final map = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
    if (args == null && Get.arguments is Map) {
      map.addAll(Map<String, dynamic>.from(Get.arguments as Map));
    }
    final reason = map['blockReason']?.toString().trim();
    return ProgramSendReviewScreen(
      programId: (map['programId'] ?? map['id'] ?? '').toString().trim(),
      programTitle: map['programTitle']?.toString() ?? 'Program',
      trainerName: map['trainerName']?.toString() ?? 'Trainer',
      trainerInitials: map['trainerInitials']?.toString() ?? 'UT',
      trainerAvatarUrl: ImageUrlSanitizer.asHttpUrlOrNull(map['trainerAvatarUrl']?.toString()),
      infoMessage: reason != null && reason.isNotEmpty ? reason : null,
      reviewId: map['reviewId']?.toString(),
      initialRating: (map['initialRating'] as num?)?.toDouble(),
      initialComment: map['initialComment']?.toString(),
    );
  }

  @override
  State<ProgramSendReviewScreen> createState() => _ProgramSendReviewScreenState();
}

class _ProgramSendReviewScreenState extends State<ProgramSendReviewScreen> {
  final MarketplaceRepository _marketplaceRepo = MarketplaceRepository();
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();

  static final RegExp _mongoIdRe = RegExp(r'^[a-fA-F0-9]{24}$');

  double _rating = 0;
  bool _submitting = false;

  String get _programId => widget.programId.trim();

  @override
  void initState() {
    super.initState();
    final stars = widget.initialRating;
    if (stars != null && stars > 0) _rating = stars;
    final comment = widget.initialComment?.trim();
    if (comment != null && comment.isNotEmpty) {
      _commentController.text = comment;
    }
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
    if (_rating == 0) {
      Get.snackbar('Missing Rating', 'Please select a star rating.', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (!_mongoIdRe.hasMatch(_programId)) {
      Get.snackbar('Review', 'Program id is missing. Cannot submit review.', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }

    setState(() => _submitting = true);
    try {
      final String? errorMessage;
      if (widget.isEditing) {
        errorMessage = await _marketplaceRepo.updateProgramReview(programId: _programId, rating: _rating.round().clamp(1, 5), description: _commentController.text.trim());
      } else {
        errorMessage = await _marketplaceRepo.submitProgramReview(programId: _programId, rating: _rating.round().clamp(1, 5), description: _commentController.text.trim());
      }
      if (!mounted) return;
      if (errorMessage != null) {
        setState(() => _submitting = false);
        Get.snackbar('Review', errorMessage, snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
        return;
      }

      final result = <String, dynamic>{'rating': _rating, 'comment': _commentController.text.trim(), if (widget.isEditing) 'reviewId': widget.reviewId};
      if (widget.isEditing) {
        result['updated'] = true;
      } else {
        result['submitted'] = true;
      }
      Get.back(result: result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      Get.snackbar('Review', e.toString(), snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final info = widget.infoMessage;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          widget.isEditing ? 'Edit Review' : 'Send Review',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (info != null) ...[_buildInfoBanner(info), const SizedBox(height: 16)],
                _buildProgramCard(),
                const SizedBox(height: 24),
                Text(
                  'Your Rating',
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                ),
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
                Text(
                  'Your Review',
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Share your experience with ${widget.trainerName} and this program.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
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
                    if (widget.isEditing) return null;
                    if (value == null || value.trim().isEmpty) {
                      return 'Please write your review';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
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
                        : Text(
                            widget.isEditing ? 'Save Changes' : 'Submit Review',
                            style: AppTextStyles.buttonMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryGrayDark.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCard() {
    final avatarUrl = widget.trainerAvatarUrl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          if (avatarUrl != null && avatarUrl.isNotEmpty)
            SafeCircleNetworkAvatar(
              imageUrl: avatarUrl,
              radius: 28,
              backgroundColor: AppColors.accent,
              fallback: Text(widget.trainerInitials, style: AppTextStyles.titleMedium.copyWith(color: AppColors.onAccent)),
            )
          else
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.accent,
              child: Text(widget.trainerInitials, style: AppTextStyles.titleMedium.copyWith(color: AppColors.onAccent)),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.programTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Rate ${widget.trainerName}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
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
        final starValue = index + 1;
        final filled = _rating >= starValue;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _submitting
                ? null
                : () {
                    setState(() => _rating = starValue.toDouble());
                  },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.accent, size: 44),
            ),
          ),
        );
      }),
    );
  }
}
