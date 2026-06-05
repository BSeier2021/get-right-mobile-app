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
  final String status; // e.g. Pending/Resolved
  final String? avatarUrl;
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
  });
}

/// Safety Center controller for blocked users + reports.
class SafetyCenterController extends GetxController {
  final ReportsRepository _reportsRepo = ReportsRepository();
  final BlocksRepository _blocksRepo = BlocksRepository();

  final RxList<BlockedUser> blockedUsers = <BlockedUser>[].obs;
  final RxList<ReportItem> reportedUsers = <ReportItem>[].obs;
  final RxList<ReportItem> reportedPosts = <ReportItem>[].obs;
  final RxList<ReportItem> reportedPrograms = <ReportItem>[].obs;
  final RxList<ReportItem> reportedFeedComments = <ReportItem>[].obs;

  final RxString blockedQuery = ''.obs;
  final RxString reportsQuery = ''.obs;
  final RxBool blockedLoading = false.obs;
  final RxnString blockedError = RxnString();
  final RxBool reportsLoading = false.obs;
  final RxnString reportsError = RxnString();

  static const int _blockedPerPage = 10;
  int _blockedPage = 1;
  bool _blockedHasNext = true;

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

  bool get _allReportListsEmpty =>
      reportedUsers.isEmpty && reportedPosts.isEmpty && reportedPrograms.isEmpty && reportedFeedComments.isEmpty;

  /// `GET /user/report` — populates report lists by [ReportType].
  Future<void> loadReports({bool showLoading = true}) async {
    if (showLoading) reportsLoading.value = true;
    reportsError.value = null;
    try {
      final raw = await _reportsRepo.getReportsRepo();
      final page = parseReportsListResponse(raw);
      reportedUsers.assignAll(page.userReports);
      reportedPosts.assignAll(page.postReports);
      reportedPrograms.assignAll(page.programReports);
      reportedFeedComments.assignAll(page.feedCommentReports);
    } catch (e) {
      reportsError.value = e.toString();
    } finally {
      reportsLoading.value = false;
    }
  }

  bool get reportsCacheEmpty => _allReportListsEmpty;

  List<BlockedUser> get filteredBlockedUsers {
    final q = blockedQuery.value.trim().toLowerCase();
    if (q.isEmpty) return blockedUsers;
    return blockedUsers.where((u) => u.name.toLowerCase().contains(q) || u.username.toLowerCase().contains(q)).toList();
  }

  List<ReportItem> _reportsSourceFor(ReportType type) {
    switch (type) {
      case ReportType.user:
        return reportedUsers;
      case ReportType.post:
        return reportedPosts;
      case ReportType.programs:
        return reportedPrograms;
      case ReportType.feedComment:
        return reportedFeedComments;
    }
  }

  List<ReportItem> filteredReportsFor(ReportType type) {
    final q = reportsQuery.value.trim().toLowerCase();
    final source = _reportsSourceFor(type);
    if (q.isEmpty) return source;
    return source
        .where(
          (r) =>
              r.title.toLowerCase().contains(q) ||
              r.subtitle.toLowerCase().contains(q) ||
              r.reason.toLowerCase().contains(q) ||
              r.status.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> unblock(String userId) async {
    await _blocksRepo.unblockUserRepo(userId);
    blockedUsers.removeWhere((u) => u.id == userId);
  }

  void removeReport({required ReportType type, required String reportId}) {
    _reportsSourceFor(type).removeWhere((r) => r.id == reportId);
  }
}


