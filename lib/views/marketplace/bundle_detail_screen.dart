import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/bundle_card_mapper.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:get_right/utils/trainer_certification_helper.dart';
import 'package:get_right/widgets/safe_network_image.dart';

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
  bool _isEnrolled = false;

  static const String _webPurchaseNotice =
      'Program and bundle purchases are only available on the Marketplace website: http://getright.prodservers.com:8011/ Purchases cannot be made through the app.';

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      _bundle = Map<String, dynamic>.from(args);
      _isEnrolled = _bundle['isEnrolled'] == true;
      _bundleId = (_bundle['id'] ?? _bundle['_id'])?.toString().trim();
    } else if (args is String && args.trim().isNotEmpty) {
      _bundleId = args.trim();
    }
    if (_bundle['prefetchedBundle'] == true) {
      _loading = false;
    } else if (_bundleId != null && _bundleId!.isNotEmpty) {
      _loadDetail();
    } else if (_isEnrolled && _programsList().isNotEmpty) {
      _loading = false;
    } else {
      setState(() {
        _loading = false;
        _error = 'Could not load bundle details';
      });
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
    final enrolledPrograms = _programsList();
    final hidePricing = _bundle['hidePricing'] == true;
    final enrolledProgress = _bundle['progress'];
    final enrolledStatus = _bundle['status'];
    final enrolledStart = _bundle['startDate'];
    final enrolledEnd = _bundle['endDate'];

    final ui = await Get.find<AuthController>().fetchMarketplaceBundleDetail(_bundleId!);
    if (!mounted) return;
    if (ui == null) {
      setState(() {
        _loading = false;
        if (_isEnrolled && _programsList().isNotEmpty) {
          _error = 'Some bundle details could not be refreshed';
        } else {
          _error = 'Could not load bundle details';
        }
      });
      if (!_isEnrolled || _programsList().isEmpty) return;
    }
    setState(() {
      if (ui != null) _bundle = ui;
      if (_isEnrolled) {
        _bundle['isEnrolled'] = true;
        if (hidePricing) _bundle['hidePricing'] = true;
        if (enrolledProgress != null) _bundle['progress'] = enrolledProgress;
        if (enrolledStatus != null) _bundle['status'] = enrolledStatus;
        if (enrolledStart != null) _bundle['startDate'] = enrolledStart;
        if (enrolledEnd != null) _bundle['endDate'] = enrolledEnd;
        _mergeEnrolledPrograms(enrolledPrograms);
      }
      _loading = false;
    });
  }

  void _mergeEnrolledPrograms(List<Map<String, dynamic>> enrolledPrograms) {
    if (enrolledPrograms.isEmpty) return;
    final byId = <String, Map<String, dynamic>>{};
    for (final p in enrolledPrograms) {
      final id = (p['id'] ?? p['_id'])?.toString().trim();
      if (id != null && id.isNotEmpty) byId[id] = p;
    }
    final merged = <Map<String, dynamic>>[];
    for (final p in _programsList()) {
      final id = (p['id'] ?? p['_id'])?.toString().trim();
      final enrolled = id != null ? byId[id] : null;
      if (enrolled != null) {
        merged.add({...p, 'enrollmentId': enrolled['enrollmentId'], 'progress': enrolled['progress'], 'isEnrolled': true});
      } else {
        merged.add(p);
      }
    }
    if (merged.isNotEmpty) _bundle['programs'] = merged;
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

  Map<String, dynamic> _bundlePricing() {
    final api = _bundle['_apiBundle'];
    if (api is Map) {
      return resolveBundlePricingFromApi(Map<String, dynamic>.from(api));
    }
    return resolveBundlePricingFromApi({
      'price': _bundle['price'] ?? _bundle['totalValue'],
      'netPrice': _bundle['bundlePrice'],
      'bundlePrice': _bundle['bundlePrice'],
      'discount': _bundle['discount'],
    });
  }

  bool get _showWebPurchaseNotice => !_loading && !_isEnrolled && _bundle['hidePricing'] != true;

  String? _trainerAvatarUrlFromBundleApi(Map<String, dynamic> api) {
    final tr = api['trainer'];
    if (tr is! Map) return null;
    final t = Map<String, dynamic>.from(tr);
    final pic = t['profilePicture'];
    if (pic is Map) {
      final url = ImageUrlSanitizer.asHttpUrlOrNull(pic['url']?.toString());
      if (url != null) return url;
    }
    final prof = t['profile'];
    if (prof is Map) {
      final profPic = prof['profilePicture'];
      if (profPic is Map) {
        return ImageUrlSanitizer.asHttpUrlOrNull(profPic['url']?.toString());
      }
    }
    return ImageUrlSanitizer.asHttpUrlOrNull(t['profilePictureUrl']?.toString());
  }

  String? _trainerIdFromNode(dynamic node) {
    if (node is! Map) return null;
    final id = (node['_id'] ?? node['id'] ?? '').toString().trim();
    return id.isEmpty ? null : id;
  }

  Map<String, dynamic> _resolveBundleTrainer(List<Map<String, dynamic>> programs) {
    var trainerId = (_bundle['trainerId'] ?? '').toString().trim();
    var name = (_bundle['trainer'] ?? '').toString().trim();
    var initials = (_bundle['trainerImage'] ?? 'T').toString().trim();
    var avatarUrl = ImageUrlSanitizer.asHttpUrlOrNull(_bundle['trainerImageUrl']?.toString());

    final api = _bundle['_apiBundle'];
    if (api is Map) {
      final apiMap = Map<String, dynamic>.from(api);
      trainerId = trainerId.isNotEmpty ? trainerId : (_trainerIdFromNode(apiMap['trainer']) ?? '');
      if (name.isEmpty) {
        final tr = apiMap['trainer'];
        if (tr is Map) {
          final prof = tr['profile'];
          if (prof is Map) {
            final fn = prof['fullName']?.toString().trim();
            if (fn != null && fn.isNotEmpty) name = fn;
          }
        }
      }
      avatarUrl ??= _trainerAvatarUrlFromBundleApi(apiMap);
    }

    if (programs.isNotEmpty) {
      final primary = programs.first;
      if (trainerId.isEmpty) {
        trainerId = (primary['trainerId'] ?? '').toString().trim();
        if (trainerId.isEmpty) trainerId = _trainerIdFromNode(primary['trainer']) ?? '';
      }
      if (name.isEmpty) name = (primary['trainer'] ?? '').toString().trim();
      if (initials == 'T') initials = (primary['trainerImage'] ?? initials).toString().trim();
      avatarUrl ??= ImageUrlSanitizer.asHttpUrlOrNull(primary['trainerImageUrl']?.toString());
    }

    if (name.isEmpty) name = 'Trainer';
    if (initials.isEmpty) initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'T';

    var rating = 0.0;
    var students = 0;
    var certified = isCertifiedFromUiMap(_bundle);
    if (programs.isNotEmpty) {
      rating = programs.map((p) => ((p['rating'] as num?) ?? 0).toDouble()).fold<double>(0, (a, b) => a + b) / programs.length;
      students = programs.map((p) => ((p['students'] as num?) ?? 0).toInt()).fold<int>(0, (a, b) => a + b);
      certified = certified || programs.every((p) => isCertifiedFromUiMap(Map<String, dynamic>.from(p)));
    }

    return {
      if (trainerId.isNotEmpty) ...{'id': trainerId, '_id': trainerId, 'trainerId': trainerId},
      'name': name,
      'initials': initials,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'rating': rating,
      'students': students,
      'certified': certified,
      'role': 'Trainer',
      'isTrainer': true,
    };
  }

  void _openTrainerProfile(Map<String, dynamic> trainer) {
    final tid = (trainer['id'] ?? trainer['_id'] ?? trainer['trainerId'] ?? '').toString().trim();
    if (tid.isEmpty) {
      Get.snackbar('Trainer', 'Trainer profile is not available.', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }
    final args = Map<String, dynamic>.from(trainer);
    args['id'] = tid;
    args['_id'] = tid;
    Get.toNamed(AppRoutes.trainerProfile, arguments: args);
  }

  Widget _buildTrainerProfileBar(Map<String, dynamic> trainer) {
    final name = (trainer['name'] ?? 'Trainer').toString();
    final initials = (trainer['initials'] ?? 'T').toString();
    final avatarUrl = ImageUrlSanitizer.asHttpUrlOrNull(trainer['avatarUrl']?.toString());
    final rating = ((trainer['rating'] as num?) ?? 0).toDouble();
    final students = ((trainer['students'] as num?) ?? 0).toInt();
    final certified = isCertifiedFromUiMap(trainer);

    return GestureDetector(
      onTap: () => _openTrainerProfile(trainer),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FFE9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EFE0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            if (avatarUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: SafeNetworkImage(
                  url: avatarUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  fallback: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.accent,
                    child: Text(initials, style: AppTextStyles.titleMedium.copyWith(color: AppColors.onAccent)),
                  ),
                ),
              )
            else
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.accent,
                child: Text(initials, style: AppTextStyles.titleMedium.copyWith(color: AppColors.onAccent)),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Created by', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark)),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 15, color: Color(0xFFF6A623)),
                      const SizedBox(width: 4),
                      Text(rating.toStringAsFixed(1), style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface)),
                      const SizedBox(width: 10),
                      Text('$students students', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark)),
                    ],
                  ),
                  if (certified) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.verified, color: AppColors.completed, size: 16),
                        const SizedBox(width: 4),
                        Text('Certified Trainer', style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.accent, size: 26),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final programs = _programsList();
    final trainer = _resolveBundleTrainer(programs);

    final String title = (_bundle['title'] ?? 'Bundle Deal').toString();
    final String? subtitle = _bundle['subtitle']?.toString();
    final String description = (_bundle['description'] ?? '').toString();
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
        bottomNavigationBar: _showWebPurchaseNotice ? _buildWebPurchaseNoticeBar() : null,
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
                      const SizedBox(height: 14),
                      _buildTrainerProfileBar(trainer),
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
                      if (_isEnrolled) _buildEnrolledBottomBar(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeroImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SafeNetworkImage(
        url: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
        fallback: Image.asset('assets/images/demo.png', fit: BoxFit.cover, width: double.infinity, height: 200),
      ),
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

  void _openEnrolledProgram(Map<String, dynamic> program) {
    final enrollmentId = program['enrollmentId']?.toString().trim();
    final programId = (program['id'] ?? program['_id'])?.toString().trim();
    final args = <String, dynamic>{
      if (programId != null && programId.isNotEmpty) ...{'id': programId, '_id': programId},
      'title': program['title'],
      'trainer': program['trainer'],
      'duration': program['duration'],
      'isEnrolled': true,
      'hidePricing': true,
      'purchased': true,
      if (enrollmentId != null && enrollmentId.isNotEmpty) 'enrollmentId': enrollmentId,
    };
    Get.toNamed(AppRoutes.programDetail, arguments: args);
  }

  Widget _buildProgramCard(Map<String, dynamic> program) {
    final cover = ImageUrlSanitizer.asHttpUrlOrNull(program['imageUrl']?.toString());
    return GestureDetector(
      onTap: () => _isEnrolled ? _openEnrolledProgram(program) : Get.toNamed(AppRoutes.programDetail, arguments: program),
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
                child: SafeNetworkImage(
                  url: cover,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  fallback: CircleAvatar(
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
                if (_isEnrolled && program['progress'] != null)
                  Text(
                    '${program['progress']}%',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
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

  Widget _buildEnrolledBottomBar() {
    final progress = (_bundle['progress'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FCEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1EDCF)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.completed, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are enrolled in this bundle',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
                ),
                if (progress > 0)
                  Text(
                    '$progress% complete',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebPurchaseNoticeBar() {
    final pricing = _bundlePricing();
    final listPrice = (pricing['totalValue'] as num).toDouble();
    final netPrice = (pricing['bundlePrice'] as num).toDouble();
    final discount = (pricing['discount'] as num).toInt();
    final hasDiscount = discount > 0 && listPrice > netPrice;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '\$${netPrice.toStringAsFixed(2)}',
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700, height: 1),
                ),
                if (hasDiscount) ...[
                  const SizedBox(width: 6),
                  Text(
                    '\$${listPrice.toStringAsFixed(2)}',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, decoration: TextDecoration.lineThrough),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '$discount% OFF',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w700, fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _webPurchaseNotice,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.mediumGray, height: 1.35, fontSize: 11.sp),
            ),
          ],
        ),
      ),
    );
  }

}
