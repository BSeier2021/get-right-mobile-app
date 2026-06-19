import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:get_right/app_url.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/controllers/favorites_controller.dart';
import 'package:get_right/models/report_block_model.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/repo/feed_repo.dart';
import 'package:get_right/repo/marketplace_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/views/planner/calendar_type_dialog.dart';
import 'package:get_right/widgets/safe_circle_network_avatar.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:get_right/widgets/safe_network_image.dart';
import 'package:get_right/views/marketplace/program_hls_player_screen.dart';
import 'package:get_right/views/marketplace/program_send_review_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Program Detail Screen
class ProgramDetailScreen extends StatefulWidget {
  const ProgramDetailScreen({super.key});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  final FavoritesController _favoritesController = Get.put(FavoritesController());
  final FeedRepository _feedRepo = FeedRepository();
  final MarketplaceRepository _marketplaceRepo = MarketplaceRepository();
  final CalendarRepository _calendarRepo = CalendarRepository();
  final _reviewCommentController = TextEditingController();
  bool _isEnrolled = false;
  Map<String, dynamic> _safeProgram = {};
  String? _apiProgramId;
  bool _mappingProgramToCalendar = false;

  /// When set (e.g. from My Programs), loads `GET /customer/program/enrolled/:id` instead of program catalog detail.
  String? _enrollmentDetailId;
  bool _loadingDetail = false;
  bool _enrolling = false;
  bool _isHandlingBack = false;
  double _rating = 0.0;
  bool _hasSubmittedRating = false;
  bool _reportInFlight = false;

  List<Map<String, dynamic>> _programReviews = [];
  bool _reviewsLoading = false;
  String? _reviewsError;
  bool _reviewActionInFlight = false;

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadProgramDetail();
        _loadProgramReviews();
      });
    } else if (_apiProgramId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadProgramReviews());
    }
  }

  Future<void> _loadProgramReviews() async {
    final pid = _apiProgramId;
    if (pid == null || !_mongoIdRe.hasMatch(pid)) return;
    if (!mounted) return;
    setState(() {
      _reviewsLoading = true;
      _reviewsError = null;
    });
    try {
      final page = await _marketplaceRepo.fetchProgramReviews(pid, page: 1, limit: 10);
      if (!mounted) return;
      setState(() {
        _programReviews = page.reviews;
        _reviewsLoading = false;
        if (page.ratingAvg != null) {
          _safeProgram['rating'] = page.ratingAvg;
        }
        final count = page.ratingCount ?? page.total;
        _safeProgram['reviews'] = count;
        _syncMyReviewFromReviewsList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reviewsLoading = false;
        _reviewsError = e.toString();
      });
    }
  }

  String? _currentUserId() {
    if (!Get.isRegistered<StorageService>()) return null;
    return Get.find<StorageService>().getUserId()?.trim();
  }

  /// Enrolled customers may review (active, scheduled, or completed — not cancelled).
  bool get _canLeaveProgramReview {
    if (!_isEnrolled) return false;
    final status = _safeProgram['status']?.toString().toLowerCase().trim() ?? '';
    return status != 'cancelled';
  }

  bool get _userHasAlreadyReviewed => _hasSubmittedRating;

  bool get _isBundleEnrollment {
    final bp = _safeProgram['bundlePrograms'];
    if (bp is List && bp.isNotEmpty) return true;
    final enc = _safeProgram['enrollment'];
    if (enc is Map) {
      final ebp = enc['bundlePrograms'];
      if (ebp is List && ebp.isNotEmpty) return true;
    }
    return false;
  }

  String? get _enrolledBundleTitle {
    final direct = _safeProgram['bundleTitle']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final bundle = _safeProgram['enrolledBundle'];
    if (bundle is Map) {
      final title = bundle['title']?.toString().trim();
      if (title != null && title.isNotEmpty) return title;
    }
    final enc = _safeProgram['enrollment'];
    if (enc is Map) {
      final b = enc['bundle'];
      if (b is Map) {
        final title = b['title']?.toString().trim();
        if (title != null && title.isNotEmpty) return title;
      }
    }
    return null;
  }

  void _syncMyReviewFromReviewsList() {
    final uid = _currentUserId();
    if (uid == null || uid.isEmpty) return;
    for (final r in _programReviews) {
      if (r['userId']?.toString() == uid) {
        _hasSubmittedRating = true;
        final stars = (r['rating'] as num?)?.toDouble();
        if (stars != null && stars > 0) {
          _rating = stars;
          _safeProgram['myReviewRating'] = stars;
        }
        final comment = r['comment']?.toString().trim();
        if (comment != null && comment.isNotEmpty) {
          _safeProgram['review'] = comment;
          if (_reviewCommentController.text.isEmpty) {
            _reviewCommentController.text = comment;
          }
        }
        return;
      }
    }
  }

  /// Plus icon — always opens [ProgramSendReviewScreen].
  void _onAddReviewTap() {
    _navigateToProgramSendReviewScreen();
  }

  String? _resolveProgramIdForReview() {
    final apiId = _apiProgramId?.trim();
    if (apiId != null && _mongoIdRe.hasMatch(apiId)) return apiId;

    final fromSafe = (_safeProgram['_id'] ?? _safeProgram['id'])?.toString().trim();
    if (fromSafe != null && _mongoIdRe.hasMatch(fromSafe)) return fromSafe;

    final nested = _safeProgram['_apiProgram'];
    if (nested is Map) {
      final nestedId = (nested['_id'] ?? nested['id'])?.toString().trim();
      if (nestedId != null && _mongoIdRe.hasMatch(nestedId)) return nestedId;
    }

    final enc = _safeProgram['enrollment'];
    if (enc is Map) {
      final prog = enc['program'];
      if (prog is Map) {
        final encProgId = (prog['_id'] ?? prog['id'])?.toString().trim();
        if (encProgId != null && _mongoIdRe.hasMatch(encProgId)) return encProgId;
      }
    }
    return null;
  }

  String? _reviewBlockReason() {
    if (_userHasAlreadyReviewed) return 'You have already submitted a review for this program.';
    if (!_canLeaveProgramReview) {
      return _isEnrolled ? 'This enrollment cannot be reviewed.' : 'Enroll in this program to leave a review.';
    }
    return null;
  }

  Future<void> _navigateToProgramSendReviewScreen({bool checkEligibilityBeforeOpen = false}) async {
    if (checkEligibilityBeforeOpen) {
      final block = _reviewBlockReason();
      if (block != null) {
        Get.snackbar('Review', block, snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.primaryGrayDark, colorText: Colors.white);
        return;
      }
    }

    final pid = _resolveProgramIdForReview();
    if (pid == null) {
      Get.snackbar('Review', 'Program id is missing. Cannot open review.', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }

    final result = await Get.to(
      () => ProgramSendReviewScreen(
        programId: pid,
        programTitle: _safeProgram['title']?.toString() ?? 'Program',
        trainerName: _safeProgram['trainer']?.toString() ?? 'Trainer',
        trainerInitials: _safeProgram['trainerImage']?.toString() ?? 'UT',
        trainerAvatarUrl: _trainerAvatarUrl(),
        infoMessage: _reviewBlockReason(),
      ),
      transition: Transition.rightToLeft,
    );

    if (!mounted) return;
    await _onReviewScreenResult(result);
  }

  Future<void> _onReviewScreenResult(dynamic result) async {
    if (!mounted || result is! Map) return;
    final submitted = result['submitted'] == true;
    final updated = result['updated'] == true;
    if (!submitted && !updated) return;

    setState(() {
      _hasSubmittedRating = true;
      final stars = (result['rating'] as num?)?.toDouble();
      if (stars != null && stars > 0) {
        _rating = stars;
        _safeProgram['myReviewRating'] = stars;
      }
      final comment = result['comment']?.toString().trim();
      if (comment != null && comment.isNotEmpty) {
        _safeProgram['review'] = comment;
        _reviewCommentController.text = comment;
      }
    });

    Get.snackbar(
      updated ? 'Review Updated' : 'Review Submitted',
      updated ? 'Your review has been updated.' : 'Thank you for your feedback!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.completed,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );

    await _loadProgramReviews();
  }

  bool _isMyReview(Map<String, dynamic> review) {
    final uid = _currentUserId();
    if (uid == null || uid.isEmpty) return false;
    return review['userId']?.toString() == uid;
  }

  Future<void> _openEditReviewScreen(Map<String, dynamic> review) async {
    final pid = _resolveProgramIdForReview();
    if (pid == null) {
      Get.snackbar('Review', 'Program id is missing.', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }

    final result = await Get.to(
      () => ProgramSendReviewScreen(
        programId: pid,
        programTitle: _safeProgram['title']?.toString() ?? 'Program',
        trainerName: _safeProgram['trainer']?.toString() ?? 'Trainer',
        trainerInitials: _safeProgram['trainerImage']?.toString() ?? 'UT',
        trainerAvatarUrl: _trainerAvatarUrl(),
        reviewId: review['id']?.toString(),
        initialRating: (review['rating'] as num?)?.toDouble(),
        initialComment: review['comment']?.toString(),
      ),
      transition: Transition.rightToLeft,
    );

    if (!mounted) return;
    await _onReviewScreenResult(result);
  }

  Future<void> _confirmDeleteReview(Map<String, dynamic> review) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Review',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to delete your review? This cannot be undone.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryGray)),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              'Delete',
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _deleteReview();
  }

  Future<void> _deleteReview() async {
    final pid = _resolveProgramIdForReview();
    if (pid == null) {
      Get.snackbar('Review', 'Program id is missing. Cannot delete review.', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }

    setState(() => _reviewActionInFlight = true);
    try {
      final errorMessage = await _marketplaceRepo.deleteProgramReview(programId: pid);
      if (!mounted) return;
      setState(() => _reviewActionInFlight = false);
      if (errorMessage != null) {
        Get.snackbar('Review', errorMessage, snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
        return;
      }

      setState(() {
        _hasSubmittedRating = false;
        _rating = 0;
        _safeProgram.remove('myReviewRating');
        _safeProgram.remove('review');
        _reviewCommentController.clear();
      });

      Get.snackbar(
        'Review Deleted',
        'Your review has been removed.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.completed,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      await _loadProgramReviews();
    } catch (e) {
      if (!mounted) return;
      setState(() => _reviewActionInFlight = false);
      Get.snackbar('Review', e.toString(), snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
    }
  }

  void _onMyReviewMenuSelected(String value, Map<String, dynamic> review) {
    if (_reviewActionInFlight) return;
    switch (value) {
      case 'edit':
        _openEditReviewScreen(review);
        break;
      case 'delete':
        _confirmDeleteReview(review);
        break;
    }
  }

  Future<void> _openSendReviewScreen() => _navigateToProgramSendReviewScreen(checkEligibilityBeforeOpen: true);

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
      'review': program['review'],
      ...program,
    };
    _safeProgram['imageUrl'] = ImageUrlSanitizer.asHttpUrlOrNull(_safeProgram['imageUrl']?.toString());
    final trainerAvatar = _resolveTrainerAvatarUrlFromMap(_safeProgram);
    if (trainerAvatar != null) {
      _safeProgram['trainerImageUrl'] = trainerAvatar;
      _safeProgram['trainerAvatarUrl'] = trainerAvatar;
    }
    _syncEnrollmentFromProgram();
    _hydrateMyReviewFromProgram();
  }

  String? _resolveTrainerAvatarUrlFromMap(Map<String, dynamic> program) {
    final imageUrl = ImageUrlSanitizer.asHttpUrlOrNull(program['trainerImageUrl']?.toString());
    if (imageUrl != null) return imageUrl;

    final avatarUrl = ImageUrlSanitizer.asHttpUrlOrNull(program['trainerAvatarUrl']?.toString());
    if (avatarUrl != null) return avatarUrl;

    final api = program['_apiProgram'];
    if (api is Map) {
      final fromApi = MarketplaceRepository.trainerAvatarUrlFromApiNode(Map<String, dynamic>.from(api)['trainer']);
      if (fromApi != null) return fromApi;

      final display = Map<String, dynamic>.from(api)['display'];
      if (display is Map) {
        final fromDisplay = ImageUrlSanitizer.asHttpUrlOrNull(display['instructor_avatar_url']?.toString());
        if (fromDisplay != null) return fromDisplay;
      }
    }

    final marketplaceDetail = program['marketplace_detail'];
    if (marketplaceDetail is Map) {
      final trainer = marketplaceDetail['trainer'];
      if (trainer is Map) {
        final fromMd = ImageUrlSanitizer.asHttpUrlOrNull(trainer['avatar_url']?.toString());
        if (fromMd != null) return fromMd;
      }
    }

    return MarketplaceRepository.trainerAvatarUrlFromApiNode(program['trainer']);
  }

  String? _trainerAvatarUrl() => _resolveTrainerAvatarUrlFromMap(_safeProgram);

  String _trainerInitials() => (_safeProgram['trainerImage'] ?? 'UT').toString();

  Widget _buildTrainerAvatar({double radius = 30, TextStyle? fallbackStyle}) {
    final style = fallbackStyle ?? AppTextStyles.titleMedium.copyWith(color: AppColors.onAccent);
    return SafeCircleNetworkAvatar(
      radius: radius,
      imageUrl: _trainerAvatarUrl(),
      backgroundColor: AppColors.accent,
      fallback: Text(_trainerInitials(), style: style),
    );
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

  void _hydrateMyReviewFromProgram() {
    final myReview = _safeProgram['myReview'] ?? _safeProgram['userReview'];
    if (myReview is! Map) return;
    final m = Map<String, dynamic>.from(myReview);
    _hasSubmittedRating = true;
    final stars = (m['rating'] as num?)?.toDouble();
    if (stars != null && stars > 0) {
      _rating = stars;
      _safeProgram['myReviewRating'] = stars;
    }
    final comment = (m['description'] ?? m['comment'])?.toString().trim();
    if (comment != null && comment.isNotEmpty) {
      _safeProgram['review'] = comment;
      _reviewCommentController.text = comment;
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
        final hidePricing = _safeProgram['hidePricing'] == true;
        final previousStatus = _safeProgram['status']?.toString();
        final keepReviewText = _reviewCommentController.text;
        final keepRatingVal = _rating;
        final keepSubmitted = _hasSubmittedRating;
        final keepMyReviewRating = _safeProgram['myReviewRating'];
        _fillSafeProgramFrom(detail);
        final pid = detail['id'] ?? detail['_id'];
        if (pid != null && _mongoIdRe.hasMatch(pid.toString().trim())) {
          _apiProgramId = pid.toString().trim();
          _loadProgramReviews();
        }
        if (wasEnrolled) {
          _safeProgram['isEnrolled'] = true;
          _safeProgram['purchased'] = true;
          if (hidePricing) _safeProgram['hidePricing'] = true;
          _safeProgram['status'] ??= previousStatus ?? 'active';
          _syncEnrollmentFromProgram();
        }
        if (keepSubmitted) {
          _safeProgram['review'] = keepReviewText;
          _rating = keepRatingVal;
          _hasSubmittedRating = true;
          if (keepMyReviewRating != null) _safeProgram['myReviewRating'] = keepMyReviewRating;
        }
      }
    });
  }

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

  List<Map<String, dynamic>> _workoutDaysList() {
    dynamic raw = _safeProgram['workoutDays'];
    if (raw is! List || raw.isEmpty) {
      final api = _safeProgram['_apiProgram'];
      if (api is Map) raw = api['workoutDays'];
    }
    if (raw is! List || raw.isEmpty) {
      final enc = _safeProgram['enrollment'];
      if (enc is Map) {
        final prog = enc['program'];
        if (prog is Map) raw = prog['workoutDays'];
      }
    }
    if (raw is! List) return [];

    final days = <Map<String, dynamic>>[];
    for (final day in raw) {
      if (day is Map) days.add(Map<String, dynamic>.from(day));
    }
    days.sort((a, b) {
      final da = (a['dayNumber'] as num?)?.toInt() ?? 0;
      final db = (b['dayNumber'] as num?)?.toInt() ?? 0;
      return da.compareTo(db);
    });
    return days;
  }

  List<Map<String, dynamic>> _exercisesForWorkoutDay(Map<String, dynamic> day) {
    final raw = day['exercises'];
    if (raw is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map) out.add(Map<String, dynamic>.from(e));
    }
    return out;
  }

  String _formatRestDuration(dynamic seconds) {
    final value = seconds is num ? seconds.toInt() : int.tryParse(seconds?.toString() ?? '');
    if (value == null || value <= 0) return '';
    if (value >= 60) {
      final mins = value ~/ 60;
      final secs = value % 60;
      return secs == 0 ? '${mins}m rest' : '${mins}m ${secs}s rest';
    }
    return '${value}s rest';
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

  String? _programIdForCalendar() => _programEnrollMongoId();

  String? _enrollmentIdForCalendar() {
    final fromDetail = _enrollmentDetailId?.trim();
    if (fromDetail != null && _mongoIdRe.hasMatch(fromDetail)) return fromDetail;

    final direct = _safeProgram['enrollmentId']?.toString().trim();
    if (direct != null && _mongoIdRe.hasMatch(direct)) return direct;

    final enc = _safeProgram['enrollment'];
    if (enc is Map) {
      final id = enc['_id']?.toString().trim();
      if (id != null && _mongoIdRe.hasMatch(id)) return id;
    }
    return null;
  }

  bool get _canAddProgramToCalendar {
    if (!_isEnrolled) return false;
    final status = _safeProgram['status']?.toString().toLowerCase().trim() ?? '';
    return status != 'cancelled';
  }

  DateTime _defaultProgramCalendarStartDate() {
    final raw = _safeProgram['enrollmentStartDate'] ?? _safeProgram['startDate'];
    if (raw != null) {
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int get _programWorkoutDayCount => _workoutDaysList().length;

  Future<void> _showAddProgramToCalendarSheet() async {
    final programId = _programIdForCalendar();
    final enrollmentId = _enrollmentIdForCalendar();
    if (programId == null || enrollmentId == null) {
      Get.snackbar('Calendar', 'Enrollment information is missing.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    DateTime selectedDate = _defaultProgramCalendarStartDate();
    final title = _safeProgram['title']?.toString() ?? 'Program';
    final dayCount = _programWorkoutDayCount;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(top: 12, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.calendar_month, color: AppColors.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add to Calendar',
                              style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('Schedule this program on your planner', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close, color: AppColors.primaryGray),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FFE9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE8EFE0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayCount > 0 ? '$dayCount workout days will be mapped to your calendar' : 'Program workouts will be mapped to your calendar',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Start Date',
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = DateTime(picked.year, picked.month, picked.day));
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.accent.withOpacity(0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, color: AppColors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                DateFormat.yMMMd().format(selectedDate),
                                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.primaryGray),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _mappingProgramToCalendar
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);
                              await _addProgramToCalendar(selectedDate);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      ),
                      icon: _mappingProgramToCalendar
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
                          : const Icon(Icons.check_circle_outline),
                      label: Text(_mappingProgramToCalendar ? 'Adding...' : 'Add to Calendar', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addProgramToCalendar(DateTime startDate) async {
    final programId = _programIdForCalendar();
    final enrollmentId = _enrollmentIdForCalendar();
    if (programId == null || enrollmentId == null) {
      Get.snackbar('Calendar', 'Enrollment information is missing.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _mappingProgramToCalendar = true);
    try {
      await _calendarRepo.mapProgramToCalendar(enrollmentId: enrollmentId, programId: programId, startDate: startDate);
      if (!mounted) return;

      final formattedDate = DateFormat.yMMMd().format(startDate);
      await showProgramCalendarSuccessSheet(context, startDateLabel: formattedDate, workoutDayCount: _programWorkoutDayCount, onGoToPlanner: () => Get.toNamed(AppRoutes.planner));
    } catch (e) {
      if (!mounted) return;
      await showCalendarErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _mappingProgramToCalendar = false);
    }
  }

  String? _programTrainerUserId() {
    var tid = (_safeProgram['trainerId'] ?? '').toString().trim();
    if (tid.isEmpty && _safeProgram['_apiProgram'] is Map) {
      final tr = (Map<String, dynamic>.from(_safeProgram['_apiProgram'] as Map))['trainer'];
      if (tr is Map) {
        tid = (tr['_id'] ?? tr['id'] ?? '').toString().trim();
      }
    }
    if (tid.isNotEmpty && _mongoIdRe.hasMatch(tid)) return tid;
    return null;
  }

  String? _currentUserIdOrNull() {
    if (!Get.isRegistered<StorageService>()) return null;
    return Get.find<StorageService>().getUserId()?.trim();
  }

  bool _isOwnProgram() {
    final trainerId = _programTrainerUserId();
    final myId = _currentUserIdOrNull();
    if (trainerId == null || myId == null || myId.isEmpty) return false;
    return trainerId == myId;
  }

  bool get _showProgramOverflowMenu {
    if (_isOwnProgram()) return false;
    return _programTrainerUserId() != null && _programEnrollMongoId() != null && (_currentUserIdOrNull()?.isNotEmpty ?? false);
  }

  Future<void> _showReportProgramDialog() async {
    final programId = _programEnrollMongoId();
    final trainerId = _programTrainerUserId();
    if (programId == null || trainerId == null || _currentUserIdOrNull() == null) {
      Get.snackbar('Could not report', 'Program information is missing.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final descriptionController = TextEditingController();
    String? selectedReason;

    await Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 24 + MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Report program', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface)),
                    const SizedBox(height: 16),
                    Text(
                      'Reason',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...ReportReasons.all.map(
                      (reason) => RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(ReportReasons.getDisplayName(reason), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                        value: reason,
                        groupValue: selectedReason,
                        onChanged: (value) => setDialogState(() => selectedReason = value),
                        activeColor: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Additional details (optional)',
                        labelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.accent, width: 2),
                        ),
                      ),
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
                      maxLines: 3,
                      maxLength: 2000,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: selectedReason == null
                              ? null
                              : () async {
                                  final apiReason = ReportReasons.getApiValue(selectedReason!);
                                  final details = descriptionController.text.trim();
                                  Get.back();
                                  await _submitReportProgram(trainerId: trainerId, programId: programId, reason: apiReason, details: details.isEmpty ? null : details);
                                },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.onAccent),
                          child: const Text('Submit'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      descriptionController.dispose();
    });
  }

  Future<void> _submitReportProgram({required String trainerId, required String programId, required String reason, String? details}) async {
    if (_reportInFlight) return;
    setState(() => _reportInFlight = true);
    try {
      await _feedRepo.reportFeedRepo(creatorUserId: trainerId, feedId: programId, reason: reason, details: details, reportRefType: ReportRefType.programs);
      Get.snackbar('Report submitted', 'Thank you for your feedback.', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Could not report', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _reportInFlight = false);
    }
  }

  void _enrollAndOpenCheckout() {
    if (_isEnrolled) {
      Get.snackbar('Already enrolled', 'This program is already enrolled.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final enrollId = _programEnrollMongoId();
    if (enrollId == null) {
      Get.snackbar('Enroll', 'This program cannot be enrolled (invalid id).', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    Get.toNamed(AppRoutes.programTerms, arguments: {'isBundle': false, 'program': Map<String, dynamic>.from(_safeProgram)});
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

  String? _nestedResourcesUrl() {
    final resources = _safeProgram['resources'];
    if (resources is Map) {
      return resources['url']?.toString();
    }
    final api = _safeProgram['_apiProgram'];
    if (api is Map) {
      final nested = api['resources'];
      if (nested is Map) return nested['url']?.toString();
    }
    return null;
  }

  String? _programResourcesPdfUrl() {
    final direct = _safeProgram['resourcesUrl']?.toString();
    return _resolveApiMediaUrl(direct) ?? _resolveApiMediaUrl(_nestedResourcesUrl());
  }

  bool get _hasEnrolledProgramVideo {
    final raw = _safeProgram['programVideoUrl']?.toString() ?? _nestedVideoUrl(_safeProgram['video']);
    return raw != null && raw.trim().isNotEmpty;
  }

  bool get _hasProgramResourcesPdf => _programResourcesPdfUrl() != null;

  String _programResourcesLabel() {
    Map<String, dynamic>? resources;
    final direct = _safeProgram['resources'];
    if (direct is Map) {
      resources = Map<String, dynamic>.from(direct);
    } else {
      final api = _safeProgram['_apiProgram'];
      if (api is Map && api['resources'] is Map) {
        resources = Map<String, dynamic>.from(api['resources'] as Map);
      }
    }
    final name = resources?['originalName']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Download program guide';
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
          actions: [
            if (_showProgramOverflowMenu)
              PopupMenuButton<String>(
                tooltip: 'More options',
                padding: EdgeInsets.zero,
                offset: const Offset(0, 40),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                enabled: !_reportInFlight,
                icon: Icon(Icons.more_vert_rounded, color: AppColors.onBackground, size: 24),
                onSelected: (value) {
                  if (value == 'report') _showReportProgramDialog();
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.flag_outlined, size: 20, color: AppColors.error),
                        const SizedBox(width: 12),
                        Text(
                          'Report',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
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
                            child: SafeNetworkImage(
                              url: _heroImageUrl(),
                              fit: BoxFit.cover,
                              fallback: Container(
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
                    if (_isEnrolled && _isBundleEnrollment) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Part of bundle: ${_enrolledBundleTitle ?? 'Bundle'}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
                        ),
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
                            _buildTrainerAvatar(radius: 30),
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

                    if (_workoutDaysList().isNotEmpty) ...[
                      _buildWorkoutScheduleSection(),
                      const SizedBox(height: 24),
                    ] else if (_exercisesList().isNotEmpty) ...[
                      _buildExercisesSection(),
                      const SizedBox(height: 24),
                    ],

                    // Enrolled Content Section (only visible if enrolled)
                    if (_isEnrolled && (_hasEnrolledProgramVideo || _hasProgramResourcesPdf)) ...[
                      Text(
                        'Program Content',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_hasEnrolledProgramVideo)
                        _buildEnrolledContentCard(icon: Icons.video_library, title: 'Full Program Video', subtitle: 'Complete training video', onTap: () => _openEnrolledVideo()),
                      if (_hasEnrolledProgramVideo && _hasProgramResourcesPdf) const SizedBox(height: 12),
                      if (_hasProgramResourcesPdf)
                        _buildEnrolledContentCard(icon: Icons.picture_as_pdf, title: 'Program Guide PDF', subtitle: _programResourcesLabel(), onTap: () => _openPDF()),
                      const SizedBox(height: 24),
                    ],

                    // // Trainer rating (enrolled customers)
                    // if (_canLeaveProgramReview) ...[
                    //   Text(
                    //     _userHasAlreadyReviewed ? 'Your Trainer Rating' : 'Rate Your Trainer',
                    //     style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                    //   ),
                    //   const SizedBox(height: 12),
                    //   if (_userHasAlreadyReviewed) _buildExistingRatingCard() else _buildReviewPromptCard(),
                    //   const SizedBox(height: 24),
                    // ],

                    // Student Reviews
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reviews',
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                        ),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.star, color: AppColors.upcoming, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '${(_safeProgram['rating'] as num?)?.toStringAsFixed(1) ?? '0.0'} (${_safeProgram['reviews']} reviews)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
                            ),
                            if (_isEnrolled && !_userHasAlreadyReviewed)
                              IconButton(
                                tooltip: 'Add review',
                                onPressed: _onAddReviewTap,
                                icon: const Icon(Icons.add_circle_outline, color: AppColors.accent, size: 26),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_reviewsLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
                      )
                    else if (_reviewsError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Could not load reviews.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                            TextButton(onPressed: _loadProgramReviews, child: const Text('Retry')),
                          ],
                        ),
                      )
                    else if (_programReviews.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('No reviews yet.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                      )
                    else
                      ..._programReviews.map(_buildReviewCard),
                    const SizedBox(height: 20), // Space for bottom bar
                  ],
                ),
              ),
            ),
          ],
        ),
        // Bottom bar: enrolled users see status message; others see purchase/enroll.
        bottomNavigationBar: _isEnrolled ? _buildAlreadyEnrolledBottomBar() : _buildPurchaseBottomBar(),
      ),
    );
  }

  Widget _buildAlreadyEnrolledBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row(
            //   children: [
            //     Icon(Icons.check_circle, color: AppColors.completed, size: 22),
            //     const SizedBox(width: 10),
            //     Expanded(
            //       child: Text(
            //         'You are enrolled in this program',
            //         style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
            //       ),
            //     ),
            //   ],
            // ),
            if (_canAddProgramToCalendar) ...[
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _mappingProgramToCalendar ? null : _showAddProgramToCalendarSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  ),
                  icon: _mappingProgramToCalendar
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
                      : const Icon(Icons.calendar_month, size: 20),
                  label: Text(_mappingProgramToCalendar ? 'Adding to Calendar...' : 'Add to Calendar', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onAccent)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseBottomBar() {
    return Container(
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

  Widget _buildWorkoutScheduleSection() {
    final days = _workoutDaysList();
    if (days.isEmpty) return const SizedBox.shrink();

    final totalExercises = days.fold<int>(0, (sum, day) => sum + _exercisesForWorkoutDay(day).length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workout Schedule',
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Follow your trainer\'s day-by-day exercise plan', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${days.length} days · $totalExercises exercises',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...days.map(_buildWorkoutDayCard),
      ],
    );
  }

  Widget _buildWorkoutDayCard(Map<String, dynamic> day) {
    final dayNumber = (day['dayNumber'] as num?)?.toInt() ?? 0;
    final exercises = _exercisesForWorkoutDay(day);
    final label = dayNumber > 0 ? 'Day $dayNumber' : 'Workout Day';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EFE0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: dayNumber == 1,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              dayNumber > 0 ? '$dayNumber' : '•',
              style: AppTextStyles.titleSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            label,
            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            exercises.isEmpty ? 'No exercises listed' : '${exercises.length} exercise${exercises.length == 1 ? '' : 's'}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
          ),
          iconColor: AppColors.accent,
          collapsedIconColor: AppColors.primaryGray,
          children: exercises.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Exercises for this day will appear here.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  ),
                ]
              : exercises.asMap().entries.map((entry) => _buildWorkoutExerciseTile(entry.value, entry.key + 1)).toList(),
        ),
      ),
    );
  }

  Widget _buildWorkoutExerciseTile(Map<String, dynamic> ex, int order) {
    final name = (ex['exerciseName'] ?? ex['name'])?.toString().trim();
    final displayName = name != null && name.isNotEmpty ? name : 'Exercise $order';
    final sets = ex['numberOfSets'] ?? ex['sets'];
    final reps = ex['numberOfReps'] ?? ex['reps'];
    final rest = _formatRestDuration(ex['restSeconds'] ?? ex['restTime']);
    final weight = ex['weight'];
    final description = (ex['exerciseDescription'] ?? ex['description'] ?? ex['notes'])?.toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text(
                  '$order',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayName,
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (sets != null || reps != null || weight != null || rest.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (sets != null) _buildWorkoutMetricChip(Icons.repeat, '$sets sets'),
                if (reps != null) _buildWorkoutMetricChip(Icons.fitness_center, '$reps reps'),
                if (weight != null && (weight is num ? weight > 0 : double.tryParse(weight.toString()) != null && double.parse(weight.toString()) > 0))
                  _buildWorkoutMetricChip(Icons.scale, '${weight is num ? (weight % 1 == 0 ? weight.toInt() : weight) : weight} kg'),
                if (rest.isNotEmpty) _buildWorkoutMetricChip(Icons.timer_outlined, rest),
              ],
            ),
          ],
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkoutMetricChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseTile(Map<String, dynamic> ex) {
    final nameRaw = (ex['exerciseName'] ?? ex['name'])?.toString().trim();
    final name = nameRaw != null && nameRaw.isNotEmpty ? nameRaw : 'Exercise';
    final sets = ex['numberOfSets'] ?? ex['sets'];
    final reps = ex['numberOfReps'] ?? ex['reps'];
    final rest = _formatRestDuration(ex['restSeconds'] ?? ex['restTime']);
    final weight = ex['weight'];
    final detailParts = <String>[];
    if (sets != null) detailParts.add('$sets sets');
    if (reps != null) detailParts.add('$reps reps');
    if (weight != null && (weight is num ? weight > 0 : double.tryParse(weight.toString()) != null && double.parse(weight.toString()) > 0)) {
      detailParts.add('${weight is num ? (weight % 1 == 0 ? weight.toInt() : weight) : weight} kg');
    }
    if (rest.isNotEmpty) detailParts.add(rest);
    final detail = detailParts.join(' · ');
    final description = (ex['exerciseDescription'] ?? ex['description'] ?? ex['notes'])?.toString().trim();

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
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, height: 1.4)),
                ],
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
    final starCount = (review['rating'] as num?)?.toInt() ?? 0;
    final avatarUrl = review['avatarUrl']?.toString();
    final initials = (review['userInitials'] ?? 'U').toString();
    final isMine = _isMyReview(review);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (avatarUrl != null && avatarUrl.isNotEmpty)
                SafeCircleNetworkAvatar(
                  imageUrl: avatarUrl,
                  radius: 20,
                  backgroundColor: AppColors.accent,
                  fallback: Text(initials, style: AppTextStyles.labelMedium.copyWith(color: AppColors.onAccent)),
                )
              else
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.accent,
                  child: Text(initials, style: AppTextStyles.labelMedium.copyWith(color: AppColors.onAccent)),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            review['userName']?.toString() ?? 'User',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface),
                          ),
                        ),
                        if ((review['date']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            review['date'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
                          ),
                        ],
                        if (isMine)
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            enabled: !_reviewActionInFlight,
                            icon: Icon(Icons.more_vert, color: AppColors.primaryGray.withOpacity(0.9), size: 20),
                            color: AppColors.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (value) => _onMyReviewMenuSelected(value, review),
                            itemBuilder: (context) => [
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18, color: AppColors.accent),
                                    const SizedBox(width: 10),
                                    Text('Edit', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                    const SizedBox(width: 10),
                                    Text('Delete', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    Row(children: List.generate(5, (index) => Icon(index < starCount ? Icons.star : Icons.star_border, size: 14, color: AppColors.upcoming))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(review['comment']?.toString() ?? '', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
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

  Future<void> _openPDF() async {
    final url = _programResourcesPdfUrl();
    if (url == null) {
      Get.snackbar('PDF', 'Program guide is not available for this program.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      Get.snackbar('PDF', 'Invalid PDF URL.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        Get.snackbar('PDF', 'Could not open program guide.', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      if (mounted) {
        Get.snackbar('PDF', 'Could not open program guide.', snackPosition: SnackPosition.BOTTOM);
      }
    }
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

  Widget _buildReviewPromptCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _buildTrainerAvatar(radius: 22, fallbackStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.onAccent)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share your experience',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    Text('Rate ${_safeProgram['trainer']} and help others choose this program.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openSendReviewScreen,
              icon: const Icon(Icons.rate_review_outlined, size: 20),
              label: Text(
                'Send Review',
                style: AppTextStyles.buttonMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingRatingCard() {
    final existingRating = (_safeProgram['myReviewRating'] as num?)?.toDouble() ?? _rating;
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
              _buildTrainerAvatar(radius: 20, fallbackStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.onAccent)),
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
}
