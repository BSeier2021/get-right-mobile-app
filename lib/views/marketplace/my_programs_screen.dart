import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/app_url.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

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

  /// One list row for UI + [rawEnrollment] for navigation.
  static Map<String, dynamic> _enrollmentToCard(Map<String, dynamic> e) {
    final prog = e['program'] is Map ? Map<String, dynamic>.from(e['program'] as Map) : <String, dynamic>{};
    final status = (e['status']?.toString().toLowerCase().trim().isNotEmpty == true) ? e['status'].toString().toLowerCase().trim() : 'active';
    final title = prog['title']?.toString() ?? 'Program';
    final bundlePrograms = e['bundlePrograms'];
    final isBundlePart = bundlePrograms is List && bundlePrograms.isNotEmpty;

    return <String, dynamic>{
      'id': e['_id']?.toString(),
      'title': title,
      'trainer': 'Trainer',
      'startDate': _parseDate(e['startDate']) ?? DateTime.now(),
      'endDate': _parseDate(e['endDate']) ?? DateTime.now().add(const Duration(days: 30)),
      'progress': _progressPct(e['progress']),
      'status': status,
      'image': _coverFromProgram(prog),
      'rawEnrollment': e,
      'programId': prog['_id']?.toString() ?? prog['id']?.toString(),
      'isBundlePart': isBundlePart,
    };
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
      _hasMore = result.hasNextPage;
      _page = result.currentPage;
      _loadingMore = false;
    });
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
    p['enrollment'] = enrollment;
    p['_id'] ??= p['id'] ?? program['programId'];
    p['id'] ??= p['_id'];
    p['isEnrolled'] = true;
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
          return _buildProgramCard(programs[index]);
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
            child: imageUrl != null
                ? Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => _imagePlaceholder())
                : _imagePlaceholder(),
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
                if (program['isBundlePart'] == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Bundle enrollment',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.accentVariant, fontWeight: FontWeight.w600),
                  ),
                ],
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
