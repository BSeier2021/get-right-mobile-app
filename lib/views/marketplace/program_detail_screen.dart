import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:get_right/app_url.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/controllers/favorites_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:get_right/views/marketplace/program_hls_player_screen.dart';

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
  bool _isEnrolled = false;
  Map<String, dynamic> _safeProgram = {};
  String? _apiProgramId;

  /// When set (e.g. from My Programs), loads `GET /customer/program/enrolled/:id` instead of program catalog detail.
  String? _enrollmentDetailId;
  bool _loadingDetail = false;
  bool _enrolling = false;
  bool _isHandlingBack = false;
  double _rating = 0.0;
  bool _hasSubmittedRating = false;

  final String _fallbackPdfUrl = 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf';

  static final RegExp _mongoIdRe = RegExp(r'^[a-fA-F0-9]{24}$');

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final Map<String, dynamic> program = args is Map ? Map<String, dynamic>.from(args) : _getMockProgramData();
    _enrollmentDetailId = _extractEnrollmentMongoId(program);
    _apiProgramId = (program['id'] ?? program['_id'])?.toString().trim();
    if (!_mongoIdRe.hasMatch(_apiProgramId ?? '')) {
      _apiProgramId = null;
    }
    _fillSafeProgramFrom(program);
    final loadEnrolled = _enrollmentDetailId != null && _mongoIdRe.hasMatch(_enrollmentDetailId!);
    final loadCatalog = !loadEnrolled && _apiProgramId != null && _apiProgramId!.isNotEmpty;
    if (loadEnrolled || loadCatalog) {
      _loadingDetail = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadProgramDetail());
    }
  }

  String? _extractEnrollmentMongoId(Map<String, dynamic> program) {
    final direct = program['enrollmentId']?.toString().trim();
    if (direct != null && direct.isNotEmpty && _mongoIdRe.hasMatch(direct)) return direct;
    final enc = program['enrollment'];
    if (enc is Map) {
      final id = enc['_id']?.toString().trim();
      if (id != null && id.isNotEmpty && _mongoIdRe.hasMatch(id)) return id;
    }
    return null;
  }

  void _fillSafeProgramFrom(Map<String, dynamic> program) {
    final fallbackId = (program['title']?.toString() ?? 'unknown_program').replaceAll(' ', '_');
    final stableId = (program['id'] ?? program['_id'] ?? fallbackId).toString();
    _safeProgram = {
      'id': stableId,
      'title': program['title'] ?? 'Program',
      'trainer': program['trainer'] ?? 'Unknown Trainer',
      'trainerImage': program['trainerImage'] ?? 'UT',
      'price': (program['price'] as num?)?.toDouble() ?? double.tryParse(program['price']?.toString() ?? '') ?? 0.0,
      'duration': program['duration'] ?? '12 weeks',
      'category': program['category'] ?? 'General',
      'goal': program['goal'] ?? 'Fitness',
      'certified': program['certified'] == true,
      'rating': (program['rating'] as num?)?.toDouble() ?? 0.0,
      'students': (program['students'] as num?)?.toInt() ?? 0,
      'reviews': (program['reviews'] as num?)?.toInt() ?? 0,
      'description': program['description'] ?? 'No description available',
      'status': program['status'],
      'hasRating': program['hasRating'] == true,
      'review': program['review'],
      ...program,
    };
    _safeProgram['imageUrl'] = ImageUrlSanitizer.asHttpUrlOrNull(_safeProgram['imageUrl']?.toString());
    _syncEnrollmentFromProgram();
    _hydrateRatingFromProgram();
  }

  void _syncEnrollmentFromProgram() {
    if (_safeProgram['isEnrolled'] == true || _safeProgram['purchased'] == true) {
      _isEnrolled = true;
      return;
    }
    final enc = _safeProgram['enrollment'];
    if (enc is Map) {
      final id = enc['_id']?.toString().trim();
      if (id != null && id.isNotEmpty && _mongoIdRe.hasMatch(id)) {
        _isEnrolled = true;
        return;
      }
    }
    // Program catalog `status` (e.g. published / active listing) must not imply the viewer is enrolled.
    _isEnrolled = false;
  }

  void _hydrateRatingFromProgram() {
    if (_safeProgram['hasRating'] == true && _rating == 0.0) {
      _rating = (_safeProgram['rating'] as num?)?.toDouble() ?? 0.0;
      _hasSubmittedRating = true;
      if (_safeProgram['review'] != null) {
        _reviewCommentController.text = _safeProgram['review'].toString();
      }
    }
  }

  Future<void> _loadProgramDetail() async {
    if (!Get.isRegistered<AuthController>()) {
      if (mounted) setState(() => _loadingDetail = false);
      return;
    }

    final enrollmentId = _enrollmentDetailId;
    Map<String, dynamic>? detail;
    if (enrollmentId != null && enrollmentId.isNotEmpty && _mongoIdRe.hasMatch(enrollmentId)) {
      detail = await Get.find<AuthController>().fetchEnrolledProgramDetail(enrollmentId);
    } else {
      final pid = _apiProgramId;
      if (pid == null || pid.isEmpty) {
        if (mounted) setState(() => _loadingDetail = false);
        return;
      }
      detail = await Get.find<AuthController>().fetchMarketplaceProgramDetail(pid);
    }
    if (!mounted) return;
    setState(() {
      _loadingDetail = false;
      if (detail != null) {
        final wasEnrolled = _isEnrolled || _safeProgram['isEnrolled'] == true || _safeProgram['purchased'] == true;
        final previousStatus = _safeProgram['status']?.toString();
        final keepHasRating = _safeProgram['hasRating'] == true || _hasSubmittedRating;
        final keepReviewText = _reviewCommentController.text;
        final keepRatingVal = _rating;
        final keepSubmitted = _hasSubmittedRating;
        _fillSafeProgramFrom(detail);
        final pid = detail['id'] ?? detail['_id'];
        if (pid != null && _mongoIdRe.hasMatch(pid.toString().trim())) {
          _apiProgramId = pid.toString().trim();
        }
        if (wasEnrolled) {
          _safeProgram['isEnrolled'] = true;
          _safeProgram['purchased'] = true;
          _safeProgram['status'] ??= previousStatus ?? 'active';
          _syncEnrollmentFromProgram();
        }
        if (keepHasRating) {
          _safeProgram['hasRating'] = true;
          _safeProgram['review'] = keepReviewText;
          _rating = keepRatingVal;
          _hasSubmittedRating = keepSubmitted;
        }
      }
    });
  }

  bool get _isCompletedProgram =>
      (_safeProgram['isEnrolled'] == true || _safeProgram['purchased'] == true) && _safeProgram['status']?.toString().toLowerCase().trim() == 'completed';

  String _formatScheduleDate(dynamic raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString();
    return DateFormat.yMMMd().format(dt.toLocal());
  }

  double _enrollmentProgressFraction() {
    final v = _safeProgram['enrollmentProgress'] ?? _safeProgram['progress'];
    if (v == null) return 0;
    final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    if (n >= 0 && n <= 1) return n.clamp(0.0, 1.0);
    return (n / 100).clamp(0.0, 1.0);
  }

  bool get _hasEnrollmentMeta =>
      _isEnrolled &&
      (_safeProgram['enrollmentStartDate'] != null ||
          _safeProgram['enrollmentEndDate'] != null ||
          _safeProgram['startDate'] != null ||
          _safeProgram['endDate'] != null ||
          _safeProgram['enrollment'] != null ||
          _safeProgram['enrollmentProgress'] != null ||
          _safeProgram['progress'] != null);

  List<Map<String, dynamic>> _exercisesList() {
    final raw = _safeProgram['exercises'];
    if (raw is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map) out.add(Map<String, dynamic>.from(e));
    }
    return out;
  }

  String _heroImageUrl() {
    return _safeProgram['imageUrl']?.toString().isNotEmpty == true
        ? _safeProgram['imageUrl'].toString()
        : 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&h=400&fit=crop';
  }

  String? _programEnrollMongoId() {
    if (_apiProgramId != null && _mongoIdRe.hasMatch(_apiProgramId!)) return _apiProgramId;
    final a = _safeProgram['_id']?.toString().trim();
    if (a != null && _mongoIdRe.hasMatch(a)) return a;
    final b = _safeProgram['id']?.toString().trim();
    if (b != null && _mongoIdRe.hasMatch(b)) return b;
    return null;
  }

  Future<void> _enrollAndOpenCheckout() async {
    final enrollId = _programEnrollMongoId();
    if (enrollId == null || !Get.isRegistered<AuthController>()) {
      Get.snackbar('Enroll', 'This program cannot be enrolled (invalid id).', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _enrolling = true);
    final enrollment = await Get.find<AuthController>().enrollProgram(programOrBundleId: enrollId, isBundle: false);
    if (!mounted) return;
    setState(() => _enrolling = false);
    if (enrollment == null) return;
    final nextProgram = Map<String, dynamic>.from(_safeProgram);
    nextProgram['isEnrolled'] = true;
    nextProgram['status'] = 'active';
    if (enrollment.isNotEmpty) nextProgram['enrollment'] = enrollment;
    Get.toNamed(AppRoutes.purchaseDetails, arguments: {'isBundle': false, 'program': nextProgram, 'skipEnrollApi': true});
  }

  String? _resolveApiMediaUrl(String? raw) {
    final input = raw?.trim();
    if (input == null || input.isEmpty) return null;
    final absolute = ImageUrlSanitizer.asHttpUrlOrNull(input);
    if (absolute != null) return absolute;
    if (input.startsWith('/')) {
      final base = Uri.parse(AppUrl.baseUrl);
      return '${base.scheme}://${base.authority}$input';
    }
    return null;
  }

  String? _nestedVideoUrl(dynamic box) {
    if (box is Map && box['url'] != null) {
      final s = box['url'].toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  /// Opens [video_player] + [chewie] in-app — supports HLS master playlists (`.m3u8`) and progressive MP4.
  void _openInAppVideo(String? rawUrl, {required String title, String emptyMessage = 'Video URL is unavailable for this program.'}) {
    final resolved = _resolveApiMediaUrl(rawUrl);
    if (resolved == null) {
      Get.snackbar(title, emptyMessage, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final uri = Uri.tryParse(resolved);
    if (uri == null) {
      Get.snackbar(title, 'Invalid video URL.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    Get.to<void>(() => ProgramHlsPlayerScreen(videoUri: uri, title: title));
  }

  @override
  void dispose() {
    _reviewCommentController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    if (_isHandlingBack || !mounted) return;
    _isHandlingBack = true;

    final didPop = await Navigator.of(context).maybePop();
    if (didPop) return;

    final previousRoute = Get.previousRoute;
    if (previousRoute.isNotEmpty && previousRoute != AppRoutes.programDetail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Get.offNamed(previousRoute);
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Get.offAllNamed(AppRoutes.marketplace);
    });
  }

  @override
  Widget build(BuildContext context) {
    final programId = (_safeProgram['id'] ?? _apiProgramId ?? 'unknown_program').toString();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          surfaceTintColor: AppColors.backgroundColor,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Program Detail',
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
        body: CustomScrollView(
          slivers: [
            if (_loadingDetail) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 3)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              _heroImageUrl(),
                              fit: BoxFit.cover,
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
                          ),
                          // Play button center
                          Positioned.fill(
                            child: Center(
                              child: Container(
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                                child: GestureDetector(
                                  onTap: () => _playDemoVideo(),
                                  child: Image.asset('assets/images/playbutton.png', width: 65.w),
                                ),
                              ),
                            ),
                          ),
                          // Favorite icon at top-left
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Obx(() {
                              final isFavorite = _favoritesController.isFavorite(programId);
                              return InkWell(
                                onTap: () {
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
                                borderRadius: BorderRadius.circular(10),
                                child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : AppColors.white, size: 20),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    // Program Title
                    const SizedBox(height: 16),

                    Text(
                      _safeProgram['title'] ?? 'Program',
                      style: AppTextStyles.headlineMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold, fontSize: 18.sp),
                    ),
                    if ((_safeProgram['subtitle'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(_safeProgram['subtitle'].toString(), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                    ],
                    if (_isEnrolled) ...[
                      Builder(
                        builder: (context) {
                          final price = (_safeProgram['price'] as num?)?.toDouble() ?? 0;
                          final discount = (_safeProgram['discount'] as num?)?.toDouble();
                          if (price <= 0 && discount == null) return const SizedBox.shrink();
                          final hasPct = discount != null && discount > 0;
                          final payable = hasPct ? price * (1 - discount / 100) : price;
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                Text(
                                  payable > 0 ? '\$${payable.toStringAsFixed(2)}' : '',
                                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                                ),
                                if (hasPct && price > 0) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '\$${price.toStringAsFixed(2)}',
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, decoration: TextDecoration.lineThrough),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                      '${discount.toStringAsFixed(0)}% off',
                                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Trainer Section (Tappable)
                    GestureDetector(
                      onTap: () {
                        final t = Map<String, dynamic>.from(_getMockTrainerData());
                        var tid = (_safeProgram['trainerId'] ?? '').toString().trim();
                        if (tid.isEmpty && _safeProgram['_apiProgram'] is Map) {
                          final tr = (Map<String, dynamic>.from(_safeProgram['_apiProgram'] as Map))['trainer'];
                          if (tr is Map) {
                            tid = (tr['_id'] ?? tr['id'] ?? '').toString().trim();
                          }
                        }
                        t['id'] = tid.isNotEmpty ? tid : t['id'];
                        t['_id'] = tid.isNotEmpty ? tid : t['_id'];
                        t['name'] = _safeProgram['trainer'] ?? t['name'];
                        t['initials'] = (_safeProgram['trainerImage'] ?? t['initials']).toString();
                        Get.toNamed(AppRoutes.trainerProfile, arguments: t);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FFE9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8EFE0)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
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
                                  SizedBox(
                                    width: 180.w,
                                    child: Text((_safeProgram['trainer'] ?? 'Trainer').toString(), style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
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
                                  if (_safeProgram['certified'] == true)
                                    Row(
                                      children: [
                                        Icon(Icons.verified, color: AppColors.completed, size: 18),
                                        const SizedBox(width: 4),
                                        Text('Certified Trainer', style: AppTextStyles.labelSmall.copyWith(color: AppColors.black)),
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
                        Expanded(
                          child: _buildInfoCard(image: 'assets/images/clock.png', label: 'Duration', value: _safeProgram['duration'] ?? '12 weeks'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoCard(image: 'assets/images/strenght.png', label: 'Category', value: _safeProgram['category'] ?? 'General'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoCard(image: 'assets/images/muscles.png', label: 'Goal', value: _safeProgram['goal'] ?? 'Fitness'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (_hasEnrollmentMeta) ...[_buildEnrollmentSummaryCard(), const SizedBox(height: 24)],

                    // Description
                    Text(
                      'About This Program',
                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(_safeProgram['description'] ?? 'No description available', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, height: 1.6)),
                    const SizedBox(height: 24),

                    // What's Included
                    _buildWhatsIncludedBlock(),
                    const SizedBox(height: 24),

                    if (_exercisesList().isNotEmpty) ...[_buildExercisesSection(), const SizedBox(height: 24)],

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
                    if (_isCompletedProgram && _isEnrolled) ...[
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
                            '\$${(((_safeProgram['price'] as num?) ?? 0)).toStringAsFixed(2)}',
                            style: AppTextStyles.headlineMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _enrolling ? null : _enrollAndOpenCheckout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          ),
                          icon: _enrolling
                              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
                              : const Icon(Icons.school, size: 20),
                          label: Text('Enroll Now', style: AppTextStyles.labelLarge.copyWith(color: AppColors.onAccent)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildWhatsIncludedBlock() {
    final api = _safeProgram['whatsIncluded'];
    final ext = _safeProgram['whats_included'];
    final rows = <String>[];
    if (api is List) {
      for (final e in api) {
        final s = e.toString().trim();
        if (s.isNotEmpty) rows.add(s);
      }
    }
    if (ext is List) {
      for (final e in ext) {
        final s = e.toString().trim();
        if (s.isNotEmpty) rows.add(s);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What\'s Included',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (rows.isNotEmpty)
          ...rows.map((t) => _buildFeatureItem('assets/images/note-2.png', t))
        else ...[
          _buildFeatureItem('assets/images/video-square.png', 'Full workout plans and schedules'),
          _buildFeatureItem('assets/images/video.png', 'Video demonstrations for all exercises'),
          _buildFeatureItem('assets/images/status-up.png', 'Progress tracking and analytics'),
          _buildFeatureItem('assets/images/message.png', 'Direct messaging with trainer'),
          _buildFeatureItem('assets/images/note-2.png', 'Nutrition guide included'),
          _buildFeatureItem('assets/images/calendar-2.png', 'Lifetime access to program'),
        ],
      ],
    );
  }

  Widget _buildEnrollmentSummaryCard() {
    final statusRaw = (_safeProgram['status'] ?? '').toString().trim();
    final statusLabel = statusRaw.isEmpty ? '—' : statusRaw[0].toUpperCase() + statusRaw.substring(1).toLowerCase();
    final frac = _enrollmentProgressFraction();
    final pctRounded = (frac * 100).round().clamp(0, 100);
    final start = _formatScheduleDate(_safeProgram['enrollmentStartDate'] ?? _safeProgram['startDate']);
    final end = _formatScheduleDate(_safeProgram['enrollmentEndDate'] ?? _safeProgram['endDate']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EFE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Your enrollment',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  statusLabel,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Progress', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGray)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: frac, minHeight: 8, backgroundColor: AppColors.primaryGray.withOpacity(0.2), color: AppColors.accent),
          ),
          const SizedBox(height: 4),
          Text(
            '$pctRounded%',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildEnrollmentDateTile(Icons.play_circle_outline, 'Started', start)),
              const SizedBox(width: 12),
              Expanded(child: _buildEnrollmentDateTile(Icons.flag_outlined, 'Ends', end)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollmentDateTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                Text(
                  value,
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExercisesSection() {
    final items = _exercisesList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exercises',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...items.map(_buildExerciseTile),
      ],
    );
  }

  Widget _buildExerciseTile(Map<String, dynamic> ex) {
    final name = ex['name']?.toString().trim().isNotEmpty == true ? ex['name'].toString() : 'Exercise';
    final sets = ex['sets'];
    final reps = ex['reps'];
    final rest = ex['restTime'];
    final detailParts = <String>[];
    if (sets != null) detailParts.add('$sets sets');
    if (reps != null) detailParts.add('$reps reps');
    if (rest != null) detailParts.add('${rest}s rest');
    final detail = detailParts.join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fitness_center, color: AppColors.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                ),
                if (detail.isNotEmpty) ...[const SizedBox(height: 4), Text(detail, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray))],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String image, required String label, required dynamic value}) {
    final displayValue = value?.toString().trim().isNotEmpty == true ? value.toString() : 'N/A';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EFE0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Image.asset(image, width: 35.w),
          const SizedBox(height: 6),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
          const SizedBox(height: 2),
          Text(
            displayValue,
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String image, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Image.asset(image, width: 25.w),
          const SizedBox(width: 10),
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
    final raw = _safeProgram['demoVideoUrl']?.toString() ?? _nestedVideoUrl(_safeProgram['demoVideo']);
    _openInAppVideo(raw, title: 'Demo Video', emptyMessage: 'Demo video is unavailable for this program.');
  }

  void _openEnrolledVideo() {
    final raw =
        _safeProgram['programVideoUrl']?.toString() ??
        _nestedVideoUrl(_safeProgram['video']) ??
        _safeProgram['demoVideoUrl']?.toString() ??
        _nestedVideoUrl(_safeProgram['demoVideo']);
    if (raw == null || raw.trim().isEmpty) {
      Get.snackbar('Program Video', 'Video is unavailable for this program.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    _openInAppVideo(raw.trim(), title: 'Program Video');
  }

  void _openPDF() {
    // Open PDF viewer
    Get.snackbar(
      'PDF Viewer',
      'PDF would open here. In production, use a package like flutter_pdfview or open with url_launcher.\nURL: $_fallbackPdfUrl',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.accent,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );

    // In a real app, you would use:
    // - url_launcher to open PDF in external app
    // - flutter_pdfview to display PDF in-app
    // Example: launchUrl(Uri.parse(_fallbackPdfUrl));
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
