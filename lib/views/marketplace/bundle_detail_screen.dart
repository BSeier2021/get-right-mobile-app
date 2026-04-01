import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Bundle Detail Screen - redesigned to match compact marketplace mockup
class BundleDetailScreen extends StatelessWidget {
  const BundleDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> bundle = Get.arguments ?? _getMockBundleData();
    final programs = (bundle['programs'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final String title = (bundle['title'] ?? 'Bundle Deal').toString();
    final String description = (bundle['description'] ?? 'Full body transformation program').toString();
    final double totalValue = (bundle['totalValue'] as num?)?.toDouble() ?? 64.99;
    final double bundlePrice = (bundle['bundlePrice'] as num?)?.toDouble() ?? 49.99;
    final int discount = (bundle['discount'] as num?)?.toInt() ?? 25;
    final String imageUrl = (bundle['imageUrl'] ?? 'https://images.unsplash.com/photo-1571902943202-507ec2618e8f?w=1200&h=800&fit=crop').toString();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Bundle Deal',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w700),
          ),
          leading: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: IconButton(
              onPressed: () => Get.back(),
              icon: Container(
                width: 40.w,
                height: 35.h,
                decoration: BoxDecoration(color: const Color(0xFFE7F1E7), borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.chevron_left, size: 20.sp, color: AppColors.accent),
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/images/demo.png', fit: BoxFit.cover, width: double.infinity),
              const SizedBox(height: 14),
              Text(
                title,
                style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(description, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.75))),
              const SizedBox(height: 12),
              _buildPricingCard(totalValue: totalValue, bundlePrice: bundlePrice, discount: discount),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Included Programs',
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w800),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      '${programs.length} Programs',
                      style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...programs.take(2).map((program) => _buildProgramCard(program)),
              const SizedBox(height: 10),
              Text(
                'What\'s Included',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _buildFeatureItem('assets/images/video-square.png', 'Access to all ${programs.length} programs'),
              _buildFeatureItem('assets/images/video.png', 'Video demonstrations for all exercises'),
              _buildFeatureItem('assets/images/status-up.png', 'Progress tracking and analytics'),
              _buildFeatureItem('assets/images/message.png', 'Direct messaging with trainer'),
              _buildFeatureItem('assets/images/note-2.png', 'Comprehensive nutrition guides'),
              _buildFeatureItem('assets/images/calendar-2.png', 'Lifetime access to all programs'),
              _buildFeatureItem('assets/images/receipt-discount.png', 'Special bundle discount (${discount}% OFF)'),
              const SizedBox(height: 10),
              _buildBottomPriceRow(totalValue: totalValue, bundlePrice: bundlePrice),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingCard({required double totalValue, required double bundlePrice, required int discount}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FCEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1EDCF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Value', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
                    Text(
                      '\$${totalValue.toStringAsFixed(2)}',
                      style: AppTextStyles.headlineSmall.copyWith(color: AppColors.primaryGrayDark, decoration: TextDecoration.lineThrough, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Bundle Price', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onBackground)),
                    Text(
                      '\$${bundlePrice.toStringAsFixed(2)}',
                      style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color(0xFFF5FCEB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFCFDEC0)),
            ),
            child: Text(
              'Save \$${(totalValue - bundlePrice).toStringAsFixed(2)} (${discount}% OFF)',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCard(Map<String, dynamic> program) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.programDetail, arguments: program),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FDEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5F0D4)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE2E9DC),
              child: Text(
                (program['trainerImage'] ?? 'T').toString(),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (program['title'] ?? 'Program').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w700),
                  ),
                  Text((program['trainer'] ?? 'Trainer').toString(), style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Color(0xFFF6A623)),
                      const SizedBox(width: 3),
                      Text('${program['rating'] ?? 0.0}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onBackground)),
                      const SizedBox(width: 10),
                      const Icon(Icons.schedule, size: 13, color: AppColors.primaryGrayDark),
                      const SizedBox(width: 3),
                      Text((program['duration'] ?? '').toString(), style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${((program['price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w800),
                ),
                const Icon(Icons.chevron_right, color: AppColors.primaryGrayDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String image, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Image.asset(image, width: 20.w, height: 20.h),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.85))),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPriceRow({required double totalValue, required double bundlePrice}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FCEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1EDCF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Price', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
                Row(
                  children: [
                    Text(
                      '\$${totalValue.toStringAsFixed(2)}',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark, decoration: TextDecoration.lineThrough),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '\$${bundlePrice.toStringAsFixed(2)}',
                      style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: () => Get.toNamed(AppRoutes.purchaseDetails, arguments: {'isBundle': true}),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: Text('Enroll Now', style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getMockBundleData() {
    return {
      'id': 'bundle_1',
      'title': 'Gym Floor Mastery',
      'description': 'Full body transformation program',
      'discount': 25,
      'totalValue': 64.99,
      'bundlePrice': 49.99,
      'imageUrl': 'https://images.unsplash.com/photo-1549060279-7e168fcee0c2?w=1200&h=800&fit=crop',
      'programs': [
        {'id': 'program_1', 'title': 'Complete Strength Program', 'trainer': 'Sarah', 'trainerImage': 'S', 'price': 49.99, 'duration': '12 Weeks', 'rating': 4.8},
        {'id': 'program_2', 'title': 'Cardio Blast Challenge', 'trainer': 'Mike Chen', 'trainerImage': 'M', 'price': 49.99, 'duration': '12 Weeks', 'rating': 4.8},
      ],
    };
  }
}
