import 'package:get/get.dart';
import 'package:get_right/repo/blocks_repo.dart';
import 'package:get_right/repo/reports_repo.dart';
import 'package:get_right/utils/block_list_mapper.dart';
import 'package:get_right/utils/report_list_mapper.dart';

enum ReportType { user, post, programs, feedComment }

class BlockedUser {
  final String id;
  final String? blockRecordId;
  final String name;
  final String username;
  final String? avatarUrl;
  final DateTime blockedAt;

  const BlockedUser({
    required this.id,
    this.blockRecordId,
    required this.name,
    required this.username,
    this.avatarUrl,
    required this.blockedAt,
  });
}

class ReportItem {
  static const String noAdditionalDetailsLabel = 'No additional details';

  final String id;
  final ReportType type;
  final String title;
  final String subtitle;
  final String reason;
  final DateTime createdAt;
  final String status;
  final String? avatarUrl;
  final String? creatorName;
  final bool hasAdditionalDetails;

  const ReportItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.reason,
    required this.createdAt,
    required this.status,
    this.hasAdditionalDetails = false,
    this.avatarUrl,
    this.creatorName,
  });
}

/// Safety Center controller for blocked users + reports.
class SafetyCenterController extends GetxController {
  final ReportsRepository _reportsRepo = ReportsRepository();
  final BlocksRepository _blocksRepo = BlocksRepository();

  final RxList<BlockedUser> blockedUsers = <BlockedUser>[].obs;
  final RxList<ReportItem> reports = <ReportItem>[].obs;

  final RxString blockedQuery = ''.obs;
  final RxString reportsQuery = ''.obs;
  final RxBool blockedLoading = false.obs;
  final RxnString blockedError = RxnString();
  final RxBool reportsLoading = false.obs;
  final RxBool reportsLoadingMore = false.obs;
  final RxnString reportsError = RxnString();

  static const int _blockedPerPage = 10;
  static const int _reportsPerPage = 20;

  int _blockedPage = 1;
  bool _blockedHasNext = true;

  int _reportsPage = 1;
  bool _reportsHasNext = false;
  String? _activeReportRefType;
  String? _activeReportStatus;

  /// `GET /user/block` — populates [blockedUsers].
  Future<void> loadBlockedUsers({bool showLoading = true, bool reset = true}) async {
    if (blockedLoading.value) return;
    if (!reset && !_blockedHasNext) return;

    if (showLoading) blockedLoading.value = true;
    if (reset) {
      blockedError.value = null;
      _blockedPage = 1;
      _blockedHasNext = true;
    }

    final pageToFetch = reset ? 1 : _blockedPage;

    try {
      final raw = await _blocksRepo.getBlockedUsersRepo(page: pageToFetch, limit: _blockedPerPage);
      final page = parseBlockedUsersListResponse(raw);

      if (reset) {
        blockedUsers.assignAll(page.users);
      } else {
        final existingIds = blockedUsers.map((u) => u.id).toSet();
        for (final u in page.users) {
          if (!existingIds.contains(u.id)) blockedUsers.add(u);
        }
      }

      _blockedHasNext = page.hasNextPage;
      _blockedPage = pageToFetch + 1;
    } catch (e) {
      blockedError.value = e.toString();
      if (reset) blockedUsers.clear();
    } finally {
      blockedLoading.value = false;
    }
  }

  bool get reportsCacheEmpty => reports.isEmpty;

  bool get reportsHasNextPage => _reportsHasNext;

  /// `GET /user/report?type=&status=&page=&limit=` — server-filtered list for the active tab.
  Future<void> loadReports({
    required String type,
    String? status,
    bool showLoading = true,
    bool reset = true,
  }) async {
    if (reportsLoading.value || reportsLoadingMore.value) return;
    if (!reset && !_reportsHasNext) return;

    _activeReportRefType = type;
    _activeReportStatus = status;

    if (reset) {
      if (showLoading) reportsLoading.value = true;
      reportsError.value = null;
      _reportsPage = 1;
      _reportsHasNext = false;
    } else {
      reportsLoadingMore.value = true;
    }

    final pageToFetch = reset ? 1 : _reportsPage;

    try {
      final raw = await _reportsRepo.getReportsRepo(
        page: pageToFetch,
        limit: _reportsPerPage,
        type: type,
        status: status,
      );
      final page = parseReportsListResponse(raw);

      if (reset) {
        reports.assignAll(page.reports);
      } else {
        final existingIds = reports.map((r) => r.id).toSet();
        for (final item in page.reports) {
          if (!existingIds.contains(item.id)) reports.add(item);
        }
      }

      _reportsHasNext = page.hasNextPage;
      _reportsPage = pageToFetch + 1;
    } catch (e) {
      reportsError.value = e.toString();
      if (reset) reports.clear();
    } finally {
      if (reset) {
        reportsLoading.value = false;
      } else {
        reportsLoadingMore.value = false;
      }
    }
  }

  Future<void> loadMoreReports() {
    final type = _activeReportRefType;
    if (type == null || type.isEmpty || !_reportsHasNext) return Future.value();
    return loadReports(type: type, status: _activeReportStatus, showLoading: false, reset: false);
  }

  List<BlockedUser> get filteredBlockedUsers {
    final q = blockedQuery.value.trim().toLowerCase();
    if (q.isEmpty) return blockedUsers;
    return blockedUsers.where((u) => u.name.toLowerCase().contains(q) || u.username.toLowerCase().contains(q)).toList();
  }

  List<ReportItem> get filteredReports {
    final q = reportsQuery.value.trim().toLowerCase();
    if (q.isEmpty) return reports;
    return reports
        .where(
          (r) =>
              r.title.toLowerCase().contains(q) ||
              r.subtitle.toLowerCase().contains(q) ||
              (r.creatorName?.toLowerCase().contains(q) ?? false) ||
              r.reason.toLowerCase().contains(q) ||
              r.status.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> unblock(String userId) async {
    await _blocksRepo.unblockUserRepo(userId);
    blockedUsers.removeWhere((u) => u.id == userId);
  }

  void removeReport(String reportId) {
    reports.removeWhere((r) => r.id == reportId);
  }
}
