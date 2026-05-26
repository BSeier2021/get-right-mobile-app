import 'package:get_right/controllers/safety_center_controller.dart';
import 'package:get_right/models/report_block_model.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

class ParsedReportsPage {
  const ParsedReportsPage({
    required this.userReports,
    required this.postReports,
    required this.programReports,
    required this.feedCommentReports,
    required this.totalDocs,
    required this.hasNextPage,
  });

  final List<ReportItem> userReports;
  final List<ReportItem> postReports;
  final List<ReportItem> programReports;
  final List<ReportItem> feedCommentReports;
  final int totalDocs;
  final bool hasNextPage;
}

/// `GET /user/report` → `data.result.reports[]`.
ParsedReportsPage parseReportsListResponse(dynamic raw) {
  final empty = ParsedReportsPage(
    userReports: const [],
    postReports: const [],
    programReports: const [],
    feedCommentReports: const [],
    totalDocs: 0,
    hasNextPage: false,
  );
  if (raw is! Map) return empty;

  final data = raw['data'];
  if (data is! Map) return empty;

  final result = data['result'];
  if (result is! Map) return empty;

  final list = result['reports'];
  if (list is! List) return empty;

  final users = <ReportItem>[];
  final posts = <ReportItem>[];
  final programs = <ReportItem>[];
  final feedComments = <ReportItem>[];

  for (final e in list) {
    if (e is! Map) continue;
    final item = _mapReportItem(Map<String, dynamic>.from(e));
    if (item == null) continue;
    switch (item.type) {
      case ReportType.user:
        users.add(item);
      case ReportType.post:
        posts.add(item);
      case ReportType.programs:
        programs.add(item);
      case ReportType.feedComment:
        feedComments.add(item);
    }
  }

  void sortList(List<ReportItem> items) => items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  sortList(users);
  sortList(posts);
  sortList(programs);
  sortList(feedComments);

  final totalDocs = (result['totalDocs'] as num?)?.toInt() ?? users.length + posts.length + programs.length + feedComments.length;
  final hasNext = result['hasNextPage'] == true;

  return ParsedReportsPage(
    userReports: users,
    postReports: posts,
    programReports: programs,
    feedCommentReports: feedComments,
    totalDocs: totalDocs,
    hasNextPage: hasNext,
  );
}

ReportItem? _mapReportItem(Map<String, dynamic> json) {
  final id = json['_id']?.toString();
  if (id == null || id.isEmpty) return null;

  final refType = json['reportRefType']?.toString() ?? '';
  final type = _reportTypeFromRefType(refType);

  final reportedUser = json['reportedUser'];
  var title = 'Report';
  var subtitle = json['details']?.toString().trim() ?? '';
  String? avatarUrl;

  if (reportedUser is Map) {
    final ru = Map<String, dynamic>.from(reportedUser);
    final profile = ru['profile'];
    if (profile is Map) {
      final prof = Map<String, dynamic>.from(profile);
      final name = prof['fullName']?.toString().trim();
      if (name != null && name.isNotEmpty) {
        title = type == ReportType.user ? name : '${_labelPrefixForType(type)} · $name';
      } else {
        title = ru['email']?.toString() ?? title;
      }
      final pic = prof['profilePicture'];
      if (pic is Map) {
        avatarUrl = ImageUrlSanitizer.asHttpUrlOrNull(pic['url']?.toString());
      }
    } else {
      title = ru['email']?.toString() ?? title;
    }
  }

  if (type != ReportType.user && title == 'Report') {
    title = _postTitleFromRefType(refType);
  }

  if (subtitle.isEmpty) {
    subtitle = _subtitleFromReportRef(refType, json['reportRef']) ?? _defaultSubtitleForType(type);
  }

  final apiReason = json['reason']?.toString() ?? '';
  final reason = ReportReasons.displayLabelFromApi(apiReason);

  DateTime createdAt = DateTime.now();
  final createdRaw = json['createdAt']?.toString();
  if (createdRaw != null && createdRaw.isNotEmpty) {
    createdAt = DateTime.tryParse(createdRaw) ?? createdAt;
  }

  return ReportItem(
    id: id,
    type: type,
    title: title,
    subtitle: subtitle,
    reason: reason,
    createdAt: createdAt,
    status: json['status']?.toString() ?? 'Pending',
    avatarUrl: avatarUrl,
  );
}

ReportType _reportTypeFromRefType(String refType) {
  switch (refType) {
    case ReportRefType.auth:
      return ReportType.user;
    case ReportRefType.programs:
      return ReportType.programs;
    case ReportRefType.feedComment:
      return ReportType.feedComment;
    case ReportRefType.post:
    case ReportRefType.feeds:
      return ReportType.post;
    default:
      final lower = refType.toLowerCase();
      if (lower == 'auth') return ReportType.user;
      if (lower == 'programs') return ReportType.programs;
      if (lower == 'feedcomment') return ReportType.feedComment;
      return ReportType.post;
  }
}

String _labelPrefixForType(ReportType type) {
  switch (type) {
    case ReportType.user:
      return '';
    case ReportType.post:
      return 'Post';
    case ReportType.programs:
      return 'Program';
    case ReportType.feedComment:
      return 'Comment';
  }
}

String _postTitleFromRefType(String refType) {
  switch (refType) {
    case ReportRefType.feeds:
      return 'Feed post';
    case ReportRefType.feedComment:
      return 'Comment';
    case ReportRefType.programs:
      return 'Program';
    case ReportRefType.post:
      return 'Post';
    default:
      return 'Post report';
  }
}

String? _subtitleFromReportRef(String refType, dynamic reportRef) {
  if (reportRef is! Map) return null;
  final ref = Map<String, dynamic>.from(reportRef);

  String? firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  switch (refType) {
    case ReportRefType.feeds:
    case ReportRefType.post:
      return firstNonEmpty([ref['title']?.toString(), ref['description']?.toString()]);
    case ReportRefType.feedComment:
      return firstNonEmpty([ref['text']?.toString()]);
    case ReportRefType.programs:
      return firstNonEmpty([ref['title']?.toString(), ref['description']?.toString()]);
    case ReportRefType.auth:
      return firstNonEmpty([ref['email']?.toString()]);
    default:
      final lower = refType.toLowerCase();
      if (lower == 'feeds' || lower == 'post') {
        return firstNonEmpty([ref['title']?.toString(), ref['description']?.toString()]);
      }
      if (lower == 'feedcomment') {
        return firstNonEmpty([ref['text']?.toString()]);
      }
      if (lower == 'programs') {
        return firstNonEmpty([ref['title']?.toString(), ref['description']?.toString()]);
      }
      if (lower == 'auth') {
        return firstNonEmpty([ref['email']?.toString()]);
      }
      return null;
  }
}

String _defaultSubtitleForType(ReportType type) {
  switch (type) {
    case ReportType.user:
      return 'No additional details';
    case ReportType.post:
      return 'Feed post';
    case ReportType.programs:
      return 'Program';
    case ReportType.feedComment:
      return 'Comment';
  }
}
