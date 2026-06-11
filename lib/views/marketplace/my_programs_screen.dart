import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/app_url.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/repo/marketplace_repo.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:get_right/widgets/safe_network_image.dart';

/// Tabs match API enrollment `status`: active | scheduled | completed | cancelled.
enum EnrollmentListTab {
  active,
  scheduled,
  completed,
  cancelled;

  /// Lowercase `status` query value from the API.
  String get apiValue => name;

  String get label => switch (this) {
    EnrollmentListTab.active => 'Active',
    EnrollmentListTab.scheduled => 'Scheduled',
    EnrollmentListTab.completed => 'Completed',
    EnrollmentListTab.cancelled => 'Cancelled',
  };
}

/// My Programs — `GET /customer/program/enrolled`.
class MyProgramsScreen extends StatefulWidget {
  const MyProgramsScreen({super.key});

  @override
  State<MyProgramsScreen> createState() => _MyProgramsScreenState();
}

class _MyProgramsScreenState extends State<MyProgramsScreen> {
  int _selectedTab = 0;

  static const int _pageSize = 10;

  bool _loading = true;
  bool _loadingMore = false;
  String? _loadError;
  final List<Map<String, dynamic>> _cardRows = [];
  int _page = 1;
  bool _hasMore = false;

  static Uri _originSansApiPath() {
    final u = Uri.parse(AppUrl.baseUrl);
    return Uri.parse(u.origin);
  }

  static String? _resolveMediaUrl(String? path) {
    if (path == null) return null;
    final t = path.trim();
    if (t.isEmpty || t == 'null') return null;
    final http = ImageUrlSanitizer.asHttpUrlOrNull(t);
    if (http != null) return http;
    try {
      final base = _originSansApiPath();
      final rel = t.startsWith('/') ? t.substring(1) : t;
      final resolved = base.resolve(rel);
      return ImageUrlSanitizer.asHttpUrlOrNull(resolved.toString());
    } catch (_) {
      return null;
    }
  }

  static String? _coverFromProgram(Map<String, dynamic> prog) {
    final cover = prog['coverImageUrl']?.toString();
    if (cover != null && cover.trim().isNotEmpty) {
      final resolved = _resolveMediaUrl(cover);
      if (resolved != null) return resolved;
    }
    final pm = prog['promoMedia'];
    if (pm is Map && pm['url'] != null) {
      return _resolveMediaUrl(pm['url']?.toString());
    }
    final dv = prog['demoVideo'];
    if (dv is Map) {
      final th = dv['thumbnail']?.toString();
      if (th != null && th.isNotEmpty) return _resolveMediaUrl(th);
      final url = dv['url']?.toString();
      if (url != null && url.startsWith('http')) return _resolveMediaUrl(url);
    }
    return null;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static int _progressPct(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v.clamp(0, 100);
    if (v is num) return v.round().clamp(0, 100);
    return int.tryParse(v.toString())?.clamp(0, 100) ?? 0;
  }

  static String _trainerNameFromEnrollment(Map<String, dynamic> e, Map<String, dynamic> prog) {
    final display = prog['display'] is Map ? Map<String, dynamic>.from(prog['display'] as Map) : null;
    return MarketplaceRepository.trainerDisplayName(trainer: e['trainer'] ?? prog['trainer'], display: display);
  }

  /// One list row for UI + [rawEnrollment] for navigation.
  static Map<String, dynamic> _enrollmentToCard(Map<String, dynamic> e) {
    final prog = e['program'] is Map ? Map<String, dynamic>.from(e['program'] as Map) : <String, dynamic>{};
    final status = (e['status']?.toString().toLowerCase().trim().isNotEmpty == true) ? e['status'].toString().toLowerCase().trim() : 'active';
    final title = prog['title']?.toString() ?? 'Program';
    final bundlePrograms = e['bundlePrograms'];
    final isBundlePart = bundlePrograms is List && bundlePrograms.isNotEmpty;
    final trainerName = _trainerNameFromEnrollment(e, prog);
    final startDate = _parseDate(e['startDate']) ?? DateTime.now();
    final durationWeeks = MarketplaceRepository.durationWeeksFrom(prog['durationWeeks'] ?? prog['duration']);
    final endDate = _parseDate(e['endDate']) ?? MarketplaceRepository.endDateFromStartAndWeeks(startDate, durationWeeks) ?? startDate.add(const Duration(days: 30));

    return <String, dynamic>{
      'id': e['_id']?.toString(),
      'title': title,
      'trainer': trainerName,
      'startDate': startDate,
      'endDate': endDate,
      'progress': _progressPct(e['progress']),
      'status': status,
      'image': _coverFromProgram(prog),
      'rawEnrollment': e,
      'programId': prog['_id']?.toString() ?? prog['id']?.toString(),
      'isBundlePart': isBundlePart,
      'isBundle': false,
    };
  }

  /// Stable key for enrollments that belong to the same bundle (`program._id` + `bundlePrograms`).
  static String? _bundleGroupKey(Map<String, dynamic> enrollment) {
    final bundlePrograms = enrollment['bundlePrograms'];
    if (bundlePrograms is! List || bundlePrograms.isEmpty) return null;

    final prog = enrollment['program'];
    final programId = prog is Map ? (prog['_id'] ?? prog['id'])?.toString().trim() : null;
    if (programId == null || programId.isEmpty) return null;

    final ids = <String>{programId};
    for (final bp in bundlePrograms) {
      final id = bp?.toString().trim();
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    final sorted = ids.toList()..sort();
    return sorted.join('|');
  }

  static String _bundleTitleFromEnrollments(List<Map<String, dynamic>> programCards) {
    for (final card in programCards) {
      final raw = card['rawEnrollment'];
      if (raw is Map) {
        final bundle = raw['bundle'];
        if (bundle is Map) {
          final title = bundle['title']?.toString().trim();
          if (title != null && title.isNotEmpty) return title;
        }
      }
    }
    return 'Bundle Deal';
  }

  static String? _coverFromBundle(Map<String, dynamic> bundle) {
    final cover = bundle['coverImageUrl']?.toString();
    if (cover != null && cover.trim().isNotEmpty) return _resolveMediaUrl(cover);
    final th = bundle['thumbnail'];
    if (th is Map) return _resolveMediaUrl(th['url']?.toString());
    final pm = bundle['promoMedia'];
    if (pm is Map) return _resolveMediaUrl(pm['url']?.toString());
    return null;
  }

  static Map<String, dynamic>? _bundleMetaFromCards(List<Map<String, dynamic>> programCards) {
    for (final card in programCards) {
      final raw = card['rawEnrollment'];
      if (raw is! Map) continue;
      final bundle = raw['bundle'];
      if (bundle is! Map) continue;
      final bm = Map<String, dynamic>.from(bundle);
      final id = (bm['_id'] ?? bm['id'])?.toString().trim();
      final price = (bm['bundlePrice'] as num?)?.toDouble() ?? (bm['price'] as num?)?.toDouble();
      return {
        'id': id,
        'bundlePrice': price,
        'subtitle': bm['subtitle']?.toString(),
        'description': bm['description']?.toString(),
        'image': _coverFromBundle(bm) ?? card['image'],
        'raw': bm,
      };
    }
    return null;
  }

  static Map<String, dynamic> _bundleCardFromGroup(List<Map<String, dynamic>> programCards) {
    final sorted = List<Map<String, dynamic>>.from(programCards)..sort((a, b) => (a['title']?.toString() ?? '').compareTo(b['title']?.toString() ?? ''));

    final totalProgress = sorted.fold<int>(0, (sum, c) => sum + _progressPct(c['progress']));
    final avgProgress = sorted.isEmpty ? 0 : (totalProgress / sorted.length).round();
    final first = sorted.first;
    final bundleMeta = _bundleMetaFromCards(sorted);

    return <String, dynamic>{
      'isBundle': true,
      'title': _bundleTitleFromEnrollments(sorted),
      'subtitle': bundleMeta?['subtitle']?.toString().trim().isNotEmpty == true ? bundleMeta!['subtitle'] : '${sorted.length} programs included',
      'programs': sorted,
      'trainer': first['trainer']?.toString() ?? 'Trainer',
      'startDate': first['startDate'],
      'endDate': first['endDate'],
      'progress': avgProgress,
      'status': first['status'],
      'image': bundleMeta?['image'] ?? first['image'],
      if (bundleMeta?['id'] != null) 'bundleId': bundleMeta!['id'],
      if (bundleMeta?['bundlePrice'] != null) 'bundlePrice': bundleMeta!['bundlePrice'],
      if (bundleMeta?['description'] != null) 'description': bundleMeta!['description'],
      if (bundleMeta?['raw'] != null) 'rawBundle': bundleMeta!['raw'],
    };
  }

  /// Collapse sibling bundle enrollments into one bundled card row.
  static List<Map<String, dynamic>> _groupEnrollmentCards(List<Map<String, dynamic>> cards) {
    final bundleGroups = <String, List<Map<String, dynamic>>>{};
    for (final card in cards) {
      final raw = card['rawEnrollment'];
      if (raw is! Map) continue;
      final key = _bundleGroupKey(Map<String, dynamic>.from(raw));
      if (key == null) continue;
      bundleGroups.putIfAbsent(key, () => []).add(card);
    }

    final seenBundleKeys = <String>{};
    final grouped = <Map<String, dynamic>>[];

    for (final card in cards) {
      final raw = card['rawEnrollment'];
      if (raw is! Map) {
        grouped.add(card);
        continue;
      }
      final key = _bundleGroupKey(Map<String, dynamic>.from(raw));
      if (key == null) {
        grouped.add(card);
      } else if (!seenBundleKeys.contains(key)) {
        seenBundleKeys.add(key);
        grouped.add(_bundleCardFromGroup(bundleGroups[key]!));
      }
    }
    return grouped;
  }

  List<Map<String, dynamic>> _flattenEnrollmentCards(List<Map<String, dynamic>> rows) {
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row['isBundle'] == true && row['programs'] is List) {
        out.addAll((row['programs'] as List).whereType<Map<String, dynamic>>());
      } else {
        out.add(row);
      }
    }
    return out;
  }

  void _regroupCardRows() {
    final flat = _flattenEnrollmentCards(_cardRows);
    _cardRows
      ..clear()
      ..addAll(_groupEnrollmentCards(flat));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrograms());
  }

  Future<void> _loadPrograms() async {
    if (!Get.isRegistered<AuthController>()) {
      setState(() {
        _loading = false;
        _loadError = 'Not signed in';
      });
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
      _cardRows.clear();
      _page = 1;
      _hasMore = false;
    });
    final result = await Get.find<AuthController>().fetchCustomerEnrolledPrograms(page: 1, limit: _pageSize, status: _currentTab.apiValue);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _loading = false;
        _loadError = 'Could not load programs';
      });
      return;
    }
    setState(() {
      _cardRows.addAll(result.enrollments.map(_enrollmentToCard));
      _regroupCardRows();
      _hasMore = result.hasNextPage;
      _page = result.currentPage;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading || _loadError != null) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final result = await Get.find<AuthController>().fetchCustomerEnrolledPrograms(page: nextPage, limit: _pageSize, status: _currentTab.apiValue);
    if (!mounted) return;
    if (result == null) {
      setState(() => _loadingMore = false);
      return;
    }
    setState(() {
      _cardRows.addAll(result.enrollments.map(_enrollmentToCard));
      _regroupCardRows();
      _hasMore = result.hasNextPage;
      _page = result.currentPage;
      _loadingMore = false;
    });
  }

  Map<String, dynamic> _enrolledBundleNavPayload(Map<String, dynamic> bundle) {
    final programs = bundle['programs'] is List ? (bundle['programs'] as List).whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
    final enrolledPrograms = <Map<String, dynamic>>[];
    for (final card in programs) {
      final raw = card['rawEnrollment'];
      final enrollment = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final prog = enrollment['program'] is Map ? Map<String, dynamic>.from(enrollment['program'] as Map) : <String, dynamic>{};
      final weeks = MarketplaceRepository.durationWeeksFrom(prog['durationWeeks'] ?? prog['duration']);
      enrolledPrograms.add({
        'id': prog['_id'] ?? prog['id'] ?? card['programId'],
        '_id': prog['_id'] ?? prog['id'] ?? card['programId'],
        'title': card['title'] ?? prog['title'] ?? 'Program',
        'trainer': card['trainer'] ?? _trainerNameFromEnrollment(enrollment, prog),
        'duration': weeks > 0 ? '$weeks weeks' : (prog['duration']?.toString() ?? ''),
        'progress': card['progress'],
        'enrollmentId': enrollment['_id']?.toString(),
        'isEnrolled': true,
      });
    }

    final bundleId = bundle['bundleId']?.toString().trim();
    return <String, dynamic>{
      if (bundleId != null && bundleId.isNotEmpty) ...{'id': bundleId, '_id': bundleId},
      'title': bundle['title']?.toString() ?? 'Bundle Deal',
      'subtitle': bundle['subtitle']?.toString(),
      'description': bundle['description']?.toString() ?? '',
      'bundlePrice': (bundle['bundlePrice'] as num?)?.toDouble() ?? 0.0,
      'imageUrl': bundle['image']?.toString() ?? '',
      'trainer': bundle['trainer']?.toString() ?? 'Trainer',
      'programs': enrolledPrograms,
      'isEnrolled': true,
      'hidePricing': true,
      'progress': bundle['progress'],
      'status': bundle['status'],
      'startDate': bundle['startDate'],
      'endDate': bundle['endDate'],
      if (bundle['rawBundle'] is Map) '_apiBundle': bundle['rawBundle'],
    };
  }

  Map<String, dynamic> _mergeEnrolledBundleWithApi(Map<String, dynamic> payload, Map<String, dynamic> apiBundle) {
    final merged = Map<String, dynamic>.from(apiBundle);
    merged['isEnrolled'] = true;
    merged['hidePricing'] = true;
    merged['prefetchedBundle'] = true;
    merged['progress'] = payload['progress'];
    merged['status'] = payload['status'];
    merged['startDate'] = payload['startDate'];
    merged['endDate'] = payload['endDate'];

    final enrolledPrice = (payload['bundlePrice'] as num?)?.toDouble();
    if (enrolledPrice != null && enrolledPrice > 0) {
      merged['bundlePrice'] = enrolledPrice;
    }

    final enrolledPrograms = payload['programs'] is List ? (payload['programs'] as List).whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
    if (enrolledPrograms.isEmpty) return merged;

    final byId = <String, Map<String, dynamic>>{};
    for (final p in enrolledPrograms) {
      final id = (p['id'] ?? p['_id'])?.toString().trim();
      if (id != null && id.isNotEmpty) byId[id] = p;
    }

    final apiPrograms = merged['programs'];
    if (apiPrograms is! List || apiPrograms.isEmpty) {
      merged['programs'] = enrolledPrograms;
      return merged;
    }

    final out = <Map<String, dynamic>>[];
    for (final raw in apiPrograms) {
      if (raw is! Map) continue;
      final p = Map<String, dynamic>.from(raw);
      final id = (p['id'] ?? p['_id'])?.toString().trim();
      final enrolled = id != null ? byId[id] : null;
      if (enrolled != null) {
        out.add({...p, 'enrollmentId': enrolled['enrollmentId'], 'progress': enrolled['progress'], 'isEnrolled': true});
      } else {
        out.add(p);
      }
    }
    merged['programs'] = out;
    return merged;
  }

  Future<void> _viewBundleDetails(Map<String, dynamic> bundle) async {
    final payload = _enrolledBundleNavPayload(bundle);
    final bundleId = (payload['id'] ?? payload['_id'])?.toString().trim();

    if (bundleId == null || bundleId.isEmpty || !Get.isRegistered<AuthController>()) {
      Get.toNamed(AppRoutes.bundleDetail, arguments: payload);
      return;
    }

    Get.dialog(const Center(child: CircularProgressIndicator(color: AppColors.accentVariant)), barrierDismissible: false);

    Map<String, dynamic>? apiBundle;
    try {
      apiBundle = await Get.find<AuthController>().fetchMarketplaceBundleDetail(bundleId);
    } finally {
      if (Get.isDialogOpen == true) Get.back();
    }

    final navArgs = apiBundle != null ? _mergeEnrolledBundleWithApi(payload, apiBundle) : payload;
    Get.toNamed(AppRoutes.bundleDetail, arguments: navArgs);
  }

  void _viewProgramDetails(Map<String, dynamic> program) {
    final raw = program['rawEnrollment'];
    if (raw is! Map) {
      Get.toNamed(AppRoutes.programDetail, arguments: program);
      return;
    }
    final enrollment = Map<String, dynamic>.from(raw);
    final nested = enrollment['program'];
    final p = nested is Map ? Map<String, dynamic>.from(nested) : <String, dynamic>{};
    p['enrollmentId'] = enrollment['_id']?.toString();
    p['_id'] ??= p['id'] ?? program['programId'];
    p['id'] ??= p['_id'];
    p['isEnrolled'] = true;
    p['hidePricing'] = true;
    p['progress'] = enrollment['progress'];
    p['startDate'] = enrollment['startDate'];
    p['endDate'] = enrollment['endDate'];
    p['status'] = enrollment['status'];
    Get.toNamed(AppRoutes.programDetail, arguments: p);
  }

  EnrollmentListTab get _currentTab {
    final i = _selectedTab.clamp(0, EnrollmentListTab.values.length - 1);
    return EnrollmentListTab.values[i];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Get.offAllNamed(AppRoutes.home);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          elevation: 0,
          centerTitle: true,
          title: Text('My Programs', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w600)),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.accent, size: 16),
            ),
            onPressed: () => Get.offAllNamed(AppRoutes.home),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (var i = 0; i < EnrollmentListTab.values.length; i++) ...[if (i > 0) SizedBox(width: 8.w), _tabChip(i, EnrollmentListTab.values[i].label)],
                  ],
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentVariant));
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _loadError!,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadPrograms, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(color: AppColors.accentVariant, onRefresh: _loadPrograms, child: _buildProgramsList(_cardRows));
  }

  Widget _tabChip(int index, String label) {
    final selected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        if (_selectedTab == index) return;
        setState(() => _selectedTab = index);
        _loadPrograms();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: selected ? 25.w : 8.w, vertical: 5.h),
        decoration: BoxDecoration(color: selected ? AppColors.accentVariant : Colors.transparent, borderRadius: BorderRadius.circular(50)),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: selected ? Colors.white : AppColors.onPrimary.withOpacity(0.7),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildProgramsList(List<Map<String, dynamic>> programs) {
    if (programs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Icon(Icons.fitness_center, size: 72, color: AppColors.primaryGray.withOpacity(0.4)),
          const SizedBox(height: 16),
          Center(
            child: Text(_emptyTitleForTab(), style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _emptySubtitleForTab(),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: () => Get.toNamed(AppRoutes.marketplace),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentVariant,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                elevation: 0,
              ),
              child: const Text('Browse Programs'),
            ),
          ),
        ],
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
          _loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: programs.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= programs.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.accentVariant)),
            );
          }
          final row = programs[index];
          if (row['isBundle'] == true) {
            return _buildBundleEnrollmentCard(row);
          }
          return _buildProgramCard(row);
        },
      ),
    );
  }

  String _emptyTitleForTab() {
    return switch (_currentTab) {
      EnrollmentListTab.active => 'No active programs',
      EnrollmentListTab.scheduled => 'Nothing scheduled',
      EnrollmentListTab.completed => 'No completed programs yet',
      EnrollmentListTab.cancelled => 'No cancelled enrollments',
    };
  }

  String _emptySubtitleForTab() {
    return switch (_currentTab) {
      EnrollmentListTab.active => 'Explore the marketplace to enroll in programs.',
      EnrollmentListTab.scheduled => 'Scheduled programs will appear here.',
      EnrollmentListTab.completed => 'Finish a program to see it listed here.',
      EnrollmentListTab.cancelled => 'Cancelled enrollments will show in this tab.',
    };
  }

  void _cancelProgram(Map<String, dynamic> program) {
    Get.snackbar('Cancel enrollment', 'Please contact support or use program settings to cancel.', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 3));
  }

  Widget _buildBundleEnrollmentCard(Map<String, dynamic> bundle) {
    final programs = bundle['programs'] is List ? (bundle['programs'] as List).whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
    final startDate = bundle['startDate'] is DateTime ? bundle['startDate'] as DateTime : DateTime.now();
    final endDate = bundle['endDate'] is DateTime ? bundle['endDate'] as DateTime : DateTime.now().add(const Duration(days: 30));
    final progress = bundle['progress'] ?? 0;
    final imageUrl = bundle['image'] as String?;
    final tab = _currentTab;
    final isActiveTab = tab == EnrollmentListTab.active;
    final isScheduledTab = tab == EnrollmentListTab.scheduled;
    final isCompletedTab = tab == EnrollmentListTab.completed;
    final isCancelledTab = tab == EnrollmentListTab.cancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCDE7C8), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                SafeNetworkImage(
                  url: imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  fallback: _imagePlaceholder(),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.accentVariant, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Bundle',
                          style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isActiveTab) ...[_progressSection(progress), const SizedBox(height: 14)],
                Text(
                  bundle['title']?.toString() ?? 'Bundle Deal',
                  style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  bundle['subtitle']?.toString() ?? '${programs.length} programs included',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.accentVariant, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('by ${bundle['trainer']?.toString() ?? 'Trainer'}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primaryGrayDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'From ${_formatDateFull(startDate)} – ${_formatDateFull(endDate)}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                if (programs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Included programs',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  ...programs.asMap().entries.map((entry) {
                    final program = entry.value;
                    return Column(
                      children: [
                        if (entry.key > 0) const Divider(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.fitness_center, size: 18, color: AppColors.accentVariant),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    program['title']?.toString() ?? 'Program',
                                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                                  ),
                                  Text('${program['progress'] ?? 0}% complete', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _viewProgramDetails(program),
                              child: Text(
                                isCompletedTab ? 'Review' : 'View',
                                style: AppTextStyles.labelMedium.copyWith(color: AppColors.accentVariant, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ],
                if (isScheduledTab || isCompletedTab || isCancelledTab) ...[const SizedBox(height: 14), _progressSection(progress)],
                const SizedBox(height: 16),
                if (isActiveTab || isCancelledTab)
                  _viewBundleDetailsButton(bundle)
                else if (isScheduledTab)
                  _cancelButton(programs.isNotEmpty ? programs.first : bundle)
                else if (isCompletedTab)
                  _completedBundleButtons(bundle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCard(Map<String, dynamic> program) {
    final startDate = program['startDate'] is DateTime ? program['startDate'] as DateTime : DateTime.now();
    final endDate = program['endDate'] is DateTime ? program['endDate'] as DateTime : DateTime.now().add(const Duration(days: 30));
    final progress = program['progress'] ?? 0;
    final imageUrl = program['image'] as String?;
    final tab = _currentTab;
    final isActiveTab = tab == EnrollmentListTab.active;
    final isScheduledTab = tab == EnrollmentListTab.scheduled;
    final isCompletedTab = tab == EnrollmentListTab.completed;
    final isCancelledTab = tab == EnrollmentListTab.cancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCDE7C8), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SafeNetworkImage(
              url: imageUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              fallback: _imagePlaceholder(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isActiveTab) ...[_progressSection(progress), const SizedBox(height: 14)],
                Text(
                  program['title']?.toString() ?? 'Program',
                  style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                const SizedBox(height: 4),
                Text('by ${program['trainer']?.toString() ?? 'Trainer'}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primaryGrayDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'From ${_formatDateFull(startDate)} – ${_formatDateFull(endDate)}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                if (isScheduledTab || isCompletedTab || isCancelledTab) ...[const SizedBox(height: 14), _progressSection(progress)],
                const SizedBox(height: 16),
                if (isActiveTab)
                  _viewDetailsButton(program)
                else if (isScheduledTab)
                  _cancelButton(program)
                else if (isCompletedTab)
                  _completedButtons(program)
                else if (isCancelledTab)
                  _viewDetailsButton(program),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressSection(int progress) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.black, fontWeight: FontWeight.w500),
            ),
            Text(
              '$progress%',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.accentVariant, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 8,
            backgroundColor: AppColors.primaryGray.withOpacity(0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentVariant),
          ),
        ),
      ],
    );
  }

  Widget _viewBundleDetailsButton(Map<String, dynamic> bundle) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _viewBundleDetails(bundle),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentVariant,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          elevation: 0,
        ),
        child: Text(
          'View Details',
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _completedBundleButtons(Map<String, dynamic> bundle) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _cancelProgram(bundle),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.onSurface,
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: BorderSide(color: AppColors.primaryGray.withOpacity(0.5), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _viewBundleDetails(bundle),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentVariant,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              elevation: 0,
            ),
            child: Text(
              'Review',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _viewDetailsButton(Map<String, dynamic> program) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _viewProgramDetails(program),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentVariant,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          elevation: 0,
        ),
        child: Text(
          'View Details',
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _cancelButton(Map<String, dynamic> program) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _cancelProgram(program),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: BorderSide(color: AppColors.primaryGray.withOpacity(0.5), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        ),
        child: Text(
          'Cancel',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _completedButtons(Map<String, dynamic> program) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _cancelProgram(program),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.onSurface,
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: BorderSide(color: AppColors.primaryGray.withOpacity(0.5), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _viewProgramDetails(program),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentVariant,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              elevation: 0,
            ),
            child: Text(
              'Review',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return Image.asset('assets/images/Rectangle 17030 (1).png', height: 160, width: double.infinity, fit: BoxFit.cover);
  }

  String _formatDateFull(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String suffix(int day) {
      if (day >= 11 && day <= 13) return 'th';
      switch (day % 10) {
        case 1:
          return 'st';
        case 2:
          return 'nd';
        case 3:
          return 'rd';
        default:
          return 'th';
      }
    }

    return '${months[date.month - 1]} ${date.day}${suffix(date.day)}';
  }
}
