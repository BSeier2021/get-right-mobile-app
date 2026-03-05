import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/favorites_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Program Detail Screen
class ProgramDetailScreen extends StatefulWidget {
  const ProgramDetailScreen({super.key});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  final FavoritesController _favoritesController = Get.put(FavoritesController());
  final _reviewFormKey = GlobalKey<FormState>();
  final _reviewCommentController = TextEditingController();
  bool _isEnrolled = false; // Mock enrollment status - in real app, check from enrolled programs
  late Map<String, dynamic> _safeProgram; // Store program data for use in methods
  double _rating = 0.0;
  bool _hasSubmittedRating = false;

  // Mock enrolled content URLs
  final String _enrolledVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4';
  final String _pdfUrl = 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf';

  @override
  void dispose() {
    _reviewCommentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> program = Get.arguments ?? _getMockProgramData();
    final programId = (program['id']?.toString() ?? program['title']?.toString() ?? 'unknown_program').replaceAll(' ', '_');

    // Check if program is completed (from trainer profile)
    final bool isCompletedProgram = program['status'] == 'completed';

    // Check if user is enrolled (mock - in real app, check from enrolled programs list)
    // For programs from My Programs (active, scheduled, or completed), user is enrolled
    _isEnrolled = program['isEnrolled'] ?? program['status'] == 'completed' || program['status'] == 'active' || program['status'] == 'scheduled';

    // Ensure required fields have defaults
    _safeProgram = {
      'id': programId,
      'title': program['title'] ?? 'Program',
      'trainer': program['trainer'] ?? 'Unknown Trainer',
      'trainerImage': program['trainerImage'] ?? 'UT',
      'price': program['price'] ?? 0.0,
      'duration': program['duration'] ?? '12 weeks',
      'category': program['category'] ?? 'General',
      'goal': program['goal'] ?? 'Fitness',
      'certified': program['certified'] ?? false,
      'rating': program['rating'] ?? 0.0,
      'students': program['students'] ?? 0,
      'reviews': program['reviews'] ?? 0,
      'description': program['description'] ?? 'No description available',
      'status': program['status'],
      'hasRating': program['hasRating'] ?? false,
      'review': program['review'],
      ...program, // Keep any additional fields
    };

    // Initialize rating state if program has existing rating
    if (_safeProgram['hasRating'] == true && _rating == 0.0) {
      _rating = (_safeProgram['rating'] ?? 0.0) as double;
      _hasSubmittedRating = true;
      if (_safeProgram['review'] != null) {
        _reviewCommentController.text = _safeProgram['review'].toString();
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          body: CustomScrollView(
            slivers: [
              // App Bar with Program Image
              SliverAppBar(
                expandedHeight: 250,
                backgroundColor: AppColors.background,
                pinned: true,
                automaticallyImplyLeading: false,
                actions: [
                  // Favorite Icon
                  Obx(() {
                    final isFavorite = _favoritesController.isFavorite(programId);
                    return IconButton(
                      onPressed: () {
                        _favoritesController.toggleFavorite(programId, {..._safeProgram, 'type': 'program'});
                        Get.snackbar(
                          isFavorite ? 'Removed' : 'Added',
                          isFavorite ? 'Removed from favorites' : 'Added to favorites',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: isFavorite ? AppColors.error : AppColors.completed,
                          colorText: Colors.white,
                          duration: const Duration(seconds: 2),
                        );
                      },
                      icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : AppColors.completed),
                    );
                  }),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Demo Video
                      Container(
                        color: AppColors.background,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Video thumbnail/placeholder
                            Image.network(
                              _safeProgram['imageUrl'] ?? 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&h=400&fit=crop',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.accent.withOpacity(0.8), AppColors.accentVariant],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Center(child: Icon(Icons.fitness_center, size: 80, color: AppColors.accent.withOpacity(0.3))),
                              ),
                            ),
                            // Play button overlay
                            Container(
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                              child: IconButton(
                                icon: const Icon(Icons.play_circle_filled, size: 64, color: Colors.white),
                                onPressed: () => _playDemoVideo(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Back button
                      Positioned(
                        top: 0,
                        left: 0,
                        child: SafeArea(
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AppColors.background]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Program Title
                      Text(
                        _safeProgram['title'] ?? 'Program',
                        style: AppTextStyles.headlineMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Trainer Section (Tappable)
                      GestureDetector(
                        onTap: () {
                          Get.toNamed(AppRoutes.trainerProfile, arguments: _getMockTrainerData());
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.accent),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: AppColors.accent,
                                child: Text(_safeProgram['trainerImage'] ?? 'UT', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onAccent)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 180.w,
                                          child: Text(_safeProgram['trainer'] ?? 'Trainer', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
                                        ),
                                        if (_safeProgram['certified'] == true)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8),
                                            child: Icon(Icons.verified, color: AppColors.completed, size: 18),
                                          ),
                                      ],
                                    ),

                                    Row(
                                      children: [
                                        Icon(Icons.star, color: AppColors.upcoming, size: 16),
                                        const SizedBox(width: 4),
                                        Text('${_safeProgram['rating']}', style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface)),
                                        const SizedBox(width: 8),
                                        Text('${_safeProgram['students']} students', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: AppColors.accent),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Quick Info Cards
                      Row(
                        children: [
                          Expanded(child: _buildInfoCard(Icons.schedule, 'Duration', _safeProgram['duration'] ?? '12 weeks')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildInfoCard(Icons.category, 'Category', _safeProgram['category'] ?? 'General')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildInfoCard(Icons.flag, 'Goal', _safeProgram['goal'] ?? 'Fitness')),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Description
                      Text(
                        'About This Program',
                        style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(_safeProgram['description'] ?? 'No description available', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, height: 1.6)),
                      const SizedBox(height: 24),

                      // What's Included
                      Text(
                        'What\'s Included',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureItem(Icons.fitness_center, 'Full workout plans and schedules'),
                      _buildFeatureItem(Icons.video_library, 'Video demonstrations for all exercises'),
                      _buildFeatureItem(Icons.track_changes, 'Progress tracking and analytics'),
                      _buildFeatureItem(Icons.chat, 'Direct messaging with trainer'),
                      _buildFeatureItem(Icons.library_books, 'Nutrition guide included'),
                      _buildFeatureItem(Icons.calendar_today, 'Lifetime access to program'),
                      const SizedBox(height: 24),

                      // Enrolled Content Section (only visible if enrolled)
                      if (_isEnrolled) ...[
                        Text(
                          'Program Content',
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildEnrolledContentCard(icon: Icons.video_library, title: 'Full Program Video', subtitle: 'Complete training video', onTap: () => _openEnrolledVideo()),
                        const SizedBox(height: 12),
                        _buildEnrolledContentCard(icon: Icons.picture_as_pdf, title: 'Program Guide PDF', subtitle: 'Download program guide', onTap: () => _openPDF()),
                        const SizedBox(height: 24),
                      ],

                      // Trainer Rating Section (for completed programs)
                      if (isCompletedProgram && _isEnrolled) ...[
                        Text(
                          _hasSubmittedRating || _safeProgram['hasRating'] == true ? 'Your Trainer Rating' : 'Rate Your Trainer',
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (_hasSubmittedRating || _safeProgram['hasRating'] == true) _buildExistingRatingCard() else _buildRatingForm(),
                        const SizedBox(height: 24),
                      ],

                      // Student Reviews
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Student Reviews',
                            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              Icon(Icons.star, color: AppColors.upcoming, size: 20),
                              const SizedBox(width: 4),
                              Text('${_safeProgram['rating']} (${_safeProgram['reviews']} reviews)', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._getMockReviews().take(2).map((review) => _buildReviewCard(review)),
                      const SizedBox(height: 20), // Space for bottom bar
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Bottom Purchase Bar (hidden for enrolled programs: completed, active, or scheduled)
          bottomNavigationBar: _isEnrolled
              ? null
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Price', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGray)),
                            Text(
                              '\$${_safeProgram['price']}',
                              style: AppTextStyles.headlineMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_isEnrolled) {
                                Get.snackbar(
                                  'Already Enrolled',
                                  'You are already enrolled in this program',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: AppColors.primaryGray,
                                  colorText: Colors.white,
                                );
                              } else {
                                Get.toNamed(AppRoutes.purchaseDetails);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isEnrolled ? AppColors.completed : AppColors.accent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: Icon(_isEnrolled ? Icons.check_circle : Icons.school, size: 20),
                            label: Text(_isEnrolled ? 'Enrolled' : 'Enroll Now', style: AppTextStyles.labelLarge.copyWith(color: AppColors.onAccent)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent, size: 24),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accent,
                child: Text(review['userInitials'], style: AppTextStyles.labelMedium.copyWith(color: AppColors.onAccent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review['userName'], style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
                    Row(children: List.generate(5, (index) => Icon(index < review['rating'] ? Icons.star : Icons.star_border, size: 14, color: AppColors.upcoming))),
                  ],
                ),
              ),
              Text(review['date'], style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review['comment'],
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getMockProgramData() {
    return {
      'id': 'mock_program_1',
      'title': 'Complete Strength Program',
      'trainer': 'Sarah Johnson',
      'trainerImage': 'SJ',
      'price': 49.99,
      'duration': '12 weeks',
      'category': 'Strength',
      'goal': 'Muscle Building',
      'certified': true,
      'rating': 4.8,
      'students': 1250,
      'reviews': 247,
      'description':
          'Transform your body with this comprehensive 12-week strength training program. Designed for intermediate to advanced lifters, this program combines proven powerlifting techniques with hypertrophy-focused training to help you build serious muscle and strength.\n\nYou\'ll follow a structured progressive overload protocol, ensuring continuous gains throughout the program. Each workout is meticulously planned with exercise selection, sets, reps, and rest periods optimized for maximum results.',
    };
  }

  Map<String, dynamic> _getMockTrainerData() {
    return {
      'id': '1',
      'name': 'Sarah Johnson',
      'initials': 'SJ',
      'bio': 'Certified personal trainer with over 8 years of experience',
      'specialties': ['Strength Training', 'Weight Loss'],
      'yearsOfExperience': 8,
      'certified': true,
      'certifications': ['NASM Certified Personal Trainer'],
      'hourlyRate': 75.0,
      'rating': 4.8,
      'totalReviews': 127,
      'students': 1250,
      'activePrograms': 5,
      'completedPrograms': 12,
      'totalPrograms': 17,
    };
  }

  List<Map<String, dynamic>> _getMockReviews() {
    return [
      {
        'userName': 'John Doe',
        'userInitials': 'JD',
        'rating': 5.0,
        'comment': 'Amazing program! I gained 15 pounds of muscle and my strength skyrocketed. Best investment I\'ve made.',
        'date': '1 week ago',
      },
      {
        'userName': 'Emily Davis',
        'userInitials': 'ED',
        'rating': 5.0,
        'comment': 'The program is challenging but the results speak for themselves. Sarah is always available for questions.',
        'date': '2 weeks ago',
      },
    ];
  }

  void _playDemoVideo() {
    // Show video player dialog or navigate to video player screen
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Demo Video', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Video placeholder
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.primaryVariant, borderRadius: BorderRadius.circular(8)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Video thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _safeProgram['imageUrl'] ?? 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&h=400&fit=crop',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.primaryVariant,
                            child: Icon(Icons.fitness_center, size: 60, color: AppColors.primaryGray),
                          ),
                        ),
                      ),
                      // Play button
                      Container(
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.play_circle_filled, size: 64, color: Colors.white),
                          onPressed: () {
                            // In a real app, this would open a video player
                            Get.snackbar(
                              'Video Player',
                              'Demo video would play here. In production, use a video player package like video_player.',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: AppColors.accent,
                              colorText: Colors.white,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEnrolledVideo() {
    // Open enrolled video
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Program Video', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.primaryVariant, borderRadius: BorderRadius.circular(8)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _safeProgram['imageUrl'] ?? 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&h=400&fit=crop',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.primaryVariant,
                            child: Icon(Icons.fitness_center, size: 60, color: AppColors.primaryGray),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.play_circle_filled, size: 64, color: Colors.white),
                          onPressed: () {
                            Get.snackbar(
                              'Video Player',
                              'Program video would play here. URL: $_enrolledVideoUrl',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: AppColors.accent,
                              colorText: Colors.white,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPDF() {
    // Open PDF viewer
    Get.snackbar(
      'PDF Viewer',
      'PDF would open here. In production, use a package like flutter_pdfview or open with url_launcher.\nURL: $_pdfUrl',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.accent,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );

    // In a real app, you would use:
    // - url_launcher to open PDF in external app
    // - flutter_pdfview to display PDF in-app
    // Example: launchUrl(Uri.parse(_pdfUrl));
  }

  Widget _buildEnrolledContentCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: AppColors.accent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingForm() {
    return Form(
      key: _reviewFormKey,
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
                  child: Text(_safeProgram['trainerImage'] ?? 'UT', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onAccent)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rate ${_safeProgram['trainer']}',
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
            Text('Tell others about your experience with ${_safeProgram['trainer']}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reviewCommentController,
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
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitRating,
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

  Widget _buildExistingRatingCard() {
    final existingRating = _safeProgram['rating'] ?? _rating;
    final existingReview = _safeProgram['review'] ?? _reviewCommentController.text;

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
                child: Text(_safeProgram['trainerImage'] ?? 'UT', style: AppTextStyles.labelMedium.copyWith(color: AppColors.onAccent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rating for ${_safeProgram['trainer']}',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(index < existingRating ? Icons.star : Icons.star_border, color: AppColors.accent, size: 20);
                        }),
                        const SizedBox(width: 8),
                        Text(
                          existingRating.toStringAsFixed(1),
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
          Text(existingReview.toString().isNotEmpty ? existingReview.toString() : 'No comment provided', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
        ],
      ),
    );
  }

  void _submitRating() {
    if (!_reviewFormKey.currentState!.validate()) {
      return;
    }

    if (_rating == 0) {
      Get.snackbar('Missing Rating', 'Please provide a rating', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }

    // Update the program data
    setState(() {
      _hasSubmittedRating = true;
      _safeProgram['hasRating'] = true;
      _safeProgram['rating'] = _rating;
      _safeProgram['review'] = _reviewCommentController.text;
    });

    Get.snackbar(
      'Review Submitted',
      'Thank you for your feedback!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.completed,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }
}
