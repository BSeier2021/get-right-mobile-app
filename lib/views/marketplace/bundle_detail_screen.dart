import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

/// Bundle detail — loads `GET /customer/bundle/:id` when opened with a bundle id.
class BundleDetailScreen extends StatefulWidget {
  const BundleDetailScreen({super.key});

  @override
  State<BundleDetailScreen> createState() => _BundleDetailScreenState();
}

class _BundleDetailScreenState extends State<BundleDetailScreen> {
  Map<String, dynamic> _bundle = {};
  bool _loading = true;
  String? _error;
  String? _bundleId;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      _bundle = Map<String, dynamic>.from(args);
      _bundleId = (_bundle['id'] ?? _bundle['_id'])?.toString().trim();
    } else if (args is String && args.trim().isNotEmpty) {
      _bundleId = args.trim();
    }
    if (_bundleId != null && _bundleId!.isNotEmpty) {
      _loadDetail();
    } else {
      _bundle = _getMockBundleData();
      _loading = false;
    }
  }

  Future<void> _loadDetail() async {
    if (!Get.isRegistered<AuthController>()) {
      setState(() {
        _loading = false;
        _error = 'Sign in to view this bundle';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final ui = await Get.find<AuthController>().fetchMarketplaceBundleDetail(_bundleId!);
    if (!mounted) return;
    if (ui == null) {
      setState(() {
        _loading = false;
        _error = 'Could not load bundle details';
      });
      return;
    }
    setState(() {
      _bundle = ui;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _programsList() {
    final raw = _bundle['programs'];
    final out = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          out.add(e);
        } else if (e is Map) {
          out.add(Map<String, dynamic>.from(e));
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final programs = _programsList();

    final String title = (_bundle['title'] ?? 'Bundle Deal').toString();
    final String? subtitle = _bundle['subtitle']?.toString();
    final String description = (_bundle['description'] ?? '').toString();
    final double totalValue = (_bundle['totalValue'] as num?)?.toDouble() ?? 64.99;
    final double bundlePrice = (_bundle['bundlePrice'] as num?)?.toDouble() ?? 49.99;
    final int discount = (_bundle['discount'] as num?)?.toInt() ?? 25;
    final String imageUrl = (_bundle['imageUrl'] ?? '').toString();

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
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
            ),
            onPressed: () => Get.back(),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && programs.isEmpty && (_bundle['title'] == null || _bundle['title'].toString().trim().isEmpty)
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground),
                      ),
                      const SizedBox(height: 16),
                      TextButton(onPressed: _loadDetail, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: (_bundleId != null && _bundleId!.isNotEmpty) ? _loadDetail : () async {},
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: Colors.red.shade700)),
                        ),
                      _buildHeroImage(imageUrl),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w800),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(subtitle, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.7))),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(description, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.75))),
                      ],
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
                      ...programs.map((program) => _buildProgramCard(program)),
                      const SizedBox(height: 10),
                      _buildWhatsIncludedSection(programs.length, discount),
                      const SizedBox(height: 10),
                      _buildBottomPriceRow(totalValue: totalValue, bundlePrice: bundlePrice),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeroImage(String url) {
    final safe = ImageUrlSanitizer.asHttpUrlOrNull(url);
    if (safe != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          safe,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 200,
          errorBuilder: (_, __, ___) => Image.asset('assets/images/demo.png', fit: BoxFit.cover, width: double.infinity, height: 200),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset('assets/images/demo.png', fit: BoxFit.cover, width: double.infinity, height: 200),
    );
  }

  Widget _buildWhatsIncludedSection(int programCount, int discount) {
    final raw = _bundle['whatsIncluded'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What\'s Included',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (raw is List && raw.isNotEmpty)
          ...raw.map((e) => _buildFeatureItem('assets/images/note-2.png', e.toString()))
        else ...[
          _buildFeatureItem('assets/images/video-square.png', 'Access to all $programCount programs'),
          _buildFeatureItem('assets/images/video.png', 'Video demonstrations for all exercises'),
          _buildFeatureItem('assets/images/status-up.png', 'Progress tracking and analytics'),
          _buildFeatureItem('assets/images/message.png', 'Direct messaging with trainer'),
          _buildFeatureItem('assets/images/note-2.png', 'Comprehensive nutrition guides'),
          _buildFeatureItem('assets/images/calendar-2.png', 'Lifetime access to all programs'),
          _buildFeatureItem('assets/images/receipt-discount.png', 'Special bundle discount ($discount% OFF)'),
        ],
      ],
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
              color: const Color(0xFFF5FCEB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFCFDEC0)),
            ),
            child: Text(
              'Save \$${(totalValue - bundlePrice).clamp(0, double.infinity).toStringAsFixed(2)} ($discount% OFF)',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCard(Map<String, dynamic> program) {
    final cover = ImageUrlSanitizer.asHttpUrlOrNull(program['imageUrl']?.toString());

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
            if (cover != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  cover,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE2E9DC),
                    child: Text(
                      (program['trainerImage'] ?? 'T').toString(),
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              )
            else
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
              onPressed: () => Get.toNamed(AppRoutes.programTerms, arguments: {'isBundle': true, 'bundle': _bundle}),
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
