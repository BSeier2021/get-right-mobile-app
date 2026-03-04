import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Trainer Reviews Screen - Shows all reviews for a trainer
class TrainerReviewsScreen extends StatefulWidget {
  const TrainerReviewsScreen({super.key});

  @override
  State<TrainerReviewsScreen> createState() => _TrainerReviewsScreenState();
}

class _TrainerReviewsScreenState extends State<TrainerReviewsScreen> {
  String _filterRating = 'All';

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> trainer = Get.arguments ?? {};
    final allReviews = _getMockReviews();
    final filteredReviews = _filterRating == 'All' ? allReviews : allReviews.where((r) => r['rating'] >= double.parse(_filterRating)).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Reviews', style: AppTextStyles.titleLarge.copyWith()), centerTitle: true),
      body: Column(
        children: [
          // Rating Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentVariant])),
            child: Column(
              children: [
                Text(
                  '${trainer['rating'] ?? 4.8}',
                  style: AppTextStyles.headlineLarge.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => Icon(Icons.star, color: index < (trainer['rating'] ?? 4.8).floor() ? AppColors.upcoming : Colors.white.withOpacity(0.3), size: 24),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Based on ${trainer['totalReviews'] ?? 127} reviews', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onAccent.withOpacity(0.9))),
              ],
            ),
          ),

          // Rating Filter
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('5'),
                  const SizedBox(width: 8),
                  _buildFilterChip('4'),
                  const SizedBox(width: 8),
                  _buildFilterChip('3'),
                  const SizedBox(width: 8),
                  _buildFilterChip('2'),
                  const SizedBox(width: 8),
                  _buildFilterChip('1'),
                ],
              ),
            ),
          ),

          // Reviews List
          Expanded(
            child: filteredReviews.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rate_review_outlined, size: 80, color: AppColors.primaryGray.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('No reviews found', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredReviews.length,
                    itemBuilder: (context, index) {
                      final review = filteredReviews[index];
                      return _buildReviewCard(review);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String rating) {
    final isSelected = _filterRating == rating;
    return GestureDetector(
      onTap: () => setState(() => _filterRating = rating),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.primaryGray, width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rating != 'All') ...[Icon(Icons.star, size: 16, color: isSelected ? AppColors.onAccent : AppColors.upcoming), const SizedBox(width: 4)],
            Text(
              rating == 'All' ? 'All Reviews' : '$rating & Up',
              style: AppTextStyles.labelMedium.copyWith(color: isSelected ? AppColors.onAccent : AppColors.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                radius: 24,
                backgroundColor: AppColors.accent,
                child: Text(review['userInitials'], style: AppTextStyles.titleSmall.copyWith(color: AppColors.onAccent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['userName'],
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (index) => Icon(index < review['rating'] ? Icons.star : Icons.star_border, size: 16, color: AppColors.upcoming)),
                        const SizedBox(width: 8),
                        Text(review['date'], style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(review['comment'], style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, height: 1.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fitness_center, size: 14, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(review['programName'], style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getMockReviews() {
    return [
      {
        'id': '1',
        'userName': 'John Doe',
        'userInitials': 'JD',
        'rating': 5.0,
        'comment':
            'Amazing trainer! Sarah helped me lose 30 pounds and build incredible strength. Her programs are well-structured and she\'s always available for questions. I couldn\'t be happier with the results.',
        'date': '2 days ago',
        'programName': 'Complete Strength Program',
      },
      {
        'id': '2',
        'userName': 'Emily Davis',
        'userInitials': 'ED',
        'rating': 5.0,
        'comment':
            'Best investment I\'ve made in my fitness journey. The program is challenging but achievable, and Sarah\'s support is outstanding. She really cares about her clients\' success.',
        'date': '1 week ago',
        'programName': 'Weight Loss Challenge',
      },
      {
        'id': '3',
        'userName': 'Mike Chen',
        'userInitials': 'MC',
        'rating': 4.0,
        'comment':
            'Great program with excellent results. Would recommend to anyone serious about their fitness goals. The only reason it\'s not 5 stars is that I wish there were more video examples.',
        'date': '2 weeks ago',
        'programName': 'Functional Fitness',
      },
      {
        'id': '4',
        'userName': 'Lisa Anderson',
        'userInitials': 'LA',
        'rating': 5.0,
        'comment': 'Sarah is incredibly knowledgeable and supportive. Her program transformed not just my body but my entire approach to fitness and health. Worth every penny!',
        'date': '3 weeks ago',
        'programName': 'Complete Strength Program',
      },
      {
        'id': '5',
        'userName': 'David Kim',
        'userInitials': 'DK',
        'rating': 5.0,
        'comment':
            'Outstanding trainer with a real passion for helping people. The program is well-designed, and the nutrition guidance alone is worth the price. Highly recommended!',
        'date': '1 month ago',
        'programName': 'Weight Loss Challenge',
      },
      {
        'id': '6',
        'userName': 'Rachel White',
        'userInitials': 'RW',
        'rating': 4.0,
        'comment': 'Very good program overall. I saw significant improvements in my strength and endurance. Sarah is responsive and helpful. Would do it again!',
        'date': '1 month ago',
        'programName': 'Functional Fitness',
      },
      {
        'id': '7',
        'userName': 'Tom Rodriguez',
        'userInitials': 'TR',
        'rating': 5.0,
        'comment':
            'Life-changing program! I\'ve tried many fitness programs before, but this is the first one that actually stuck. Sarah knows her stuff and really cares about results.',
        'date': '2 months ago',
        'programName': 'Complete Strength Program',
      },
      {
        'id': '8',
        'userName': 'Anna Martinez',
        'userInitials': 'AM',
        'rating': 5.0,
        'comment':
            'Absolutely loved working with Sarah! Her program is comprehensive, easy to follow, and most importantly - it works! I feel stronger and more confident than ever.',
        'date': '2 months ago',
        'programName': 'Weight Loss Challenge',
      },
    ];
  }
}
