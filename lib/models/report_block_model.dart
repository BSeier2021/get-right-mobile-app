/// Report and Block models for trainer reporting functionality
class ReportModel {
  final String id;
  final String conversationId;
  final String reporterId; // User who reported
  final String reportedUserId; // Trainer who was reported
  final String reason;
  final String? description;
  final DateTime reportedAt;
  final ReportStatus status;
  final String? adminNotes;
  final DateTime? reviewedAt;

  ReportModel({
    required this.id,
    required this.conversationId,
    required this.reporterId,
    required this.reportedUserId,
    required this.reason,
    this.description,
    required this.reportedAt,
    this.status = ReportStatus.pending,
    this.adminNotes,
    this.reviewedAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      reporterId: json['reporterId'] ?? '',
      reportedUserId: json['reportedUserId'] ?? '',
      reason: json['reason'] ?? '',
      description: json['description'],
      reportedAt: json['reportedAt'] != null ? DateTime.parse(json['reportedAt']) : DateTime.now(),
      status: ReportStatus.fromString(json['status'] ?? 'pending'),
      adminNotes: json['adminNotes'],
      reviewedAt: json['reviewedAt'] != null ? DateTime.parse(json['reviewedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'description': description,
      'reportedAt': reportedAt.toIso8601String(),
      'status': status.toString(),
      'adminNotes': adminNotes,
      'reviewedAt': reviewedAt?.toIso8601String(),
    };
  }
}

enum ReportStatus {
  pending,
  reviewed,
  dismissed;

  static ReportStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return ReportStatus.pending;
      case 'reviewed':
      case 'resolved':
      case 'under_review':
      case 'underreview':
        return ReportStatus.reviewed;
      case 'dismissed':
        return ReportStatus.dismissed;
      default:
        return ReportStatus.pending;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ReportStatus.pending:
        return 'Pending';
      case ReportStatus.reviewed:
        return 'Reviewed';
      case ReportStatus.dismissed:
        return 'Dismissed';
    }
  }
}

/// Block model - represents a blocked user
class BlockModel {
  final String id;
  final String blockerId; // User who blocked
  final String blockedUserId; // User who was blocked (trainer)
  final DateTime blockedAt;
  final String? reason;

  BlockModel({required this.id, required this.blockerId, required this.blockedUserId, required this.blockedAt, this.reason});

  factory BlockModel.fromJson(Map<String, dynamic> json) {
    return BlockModel(
      id: json['id'] ?? '',
      blockerId: json['blockerId'] ?? '',
      blockedUserId: json['blockedUserId'] ?? '',
      blockedAt: json['blockedAt'] != null ? DateTime.parse(json['blockedAt']) : DateTime.now(),
      reason: json['reason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'blockerId': blockerId, 'blockedUserId': blockedUserId, 'blockedAt': blockedAt.toIso8601String(), 'reason': reason};
  }
}

/// `reportRefType` values — matches backend `ReportRefTypeEnums`.
class ReportRefType {
  static const String feedComment = 'FeedComment';
  static const String auth = 'Auth';
  static const String feeds = 'Feeds';
  static const String programs = 'Programs';

  static const all = [feedComment, auth, feeds, programs];

  /// Tab order for the reports screen.
  static const tabOrder = [auth, feeds, programs, feedComment];

  static String tabLabel(String refType) {
    switch (refType) {
      case auth:
        return 'User';
      case feeds:
        return 'Feeds';
      case programs:
        return 'Programs';
      case feedComment:
        return 'Feed comment';
      default:
        return refType;
    }
  }
}

/// Moderation queue state — matches backend `UserReportStatusEnums`.
class UserReportStatus {
  static const String pending = 'Pending';
  static const String reviewed = 'Reviewed';
  static const String dismissed = 'Dismissed';

  static const all = [pending, reviewed, dismissed];

  static String normalize(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return pending;
    switch (value.toLowerCase()) {
      case 'pending':
        return pending;
      case 'reviewed':
      case 'resolved':
      case 'under_review':
      case 'underreview':
        return reviewed;
      case 'dismissed':
        return dismissed;
      default:
        return value;
    }
  }

  static String displayLabel(String? raw) => normalize(raw);
}

/// Report reasons — UI keys map to API `UserReportReasonEnums` via [getApiValue].
class ReportReasons {
  static const String spam = 'spam';
  static const String harassment = 'harassment';
  static const String impersonation = 'impersonation';
  static const String inappropriateContent = 'inappropriate_content';
  static const String scam = 'scam';
  static const String other = 'other';

  /// API: `Spam` | `Harassment` | `Impersonation` | `InappropriateContent` | `Scam` | `Other`
  static List<String> get all => [spam, harassment, impersonation, inappropriateContent, scam, other];

  static String getDisplayName(String reason) {
    switch (reason) {
      case spam:
        return 'Spam';
      case harassment:
        return 'Harassment';
      case impersonation:
        return 'Impersonation';
      case inappropriateContent:
        return 'Inappropriate Content';
      case scam:
        return 'Scam';
      case other:
        return 'Other';
      default:
        return 'Other';
    }
  }

  /// Human-readable label for API enum values in lists (e.g. `InappropriateContent`).
  static String displayLabelFromApi(String apiReason) {
    switch (apiReason) {
      case 'Spam':
        return 'Spam';
      case 'Harassment':
        return 'Harassment';
      case 'Impersonation':
        return 'Impersonation';
      case 'InappropriateContent':
        return 'Inappropriate Content';
      case 'Scam':
        return 'Scam';
      case 'Other':
        return 'Other';
      default:
        return apiReason.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    }
  }

  /// Exact `reason` string for `POST /user/report/:reportRef`.
  static String getApiValue(String reason) {
    switch (reason) {
      case spam:
        return 'Spam';
      case harassment:
        return 'Harassment';
      case impersonation:
        return 'Impersonation';
      case inappropriateContent:
        return 'InappropriateContent';
      case scam:
        return 'Scam';
      case other:
        return 'Other';
      default:
        return 'Other';
    }
  }
}
