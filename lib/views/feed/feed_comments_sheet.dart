import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/report_block_model.dart';
import 'package:get_right/repo/feed_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/feed_comment_mapper.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

String _formatCommentCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return count.toString();
}

/// Lazy-loaded reply thread for one top-level comment.
class _ReplyThreadState {
  bool expanded = false;
  bool loading = false;
  bool loadingMore = false;
  bool hasNext = true;
  int page = 1;
  String? error;
  int totalReplies = 0;
  final List<Map<String, dynamic>> replies = <Map<String, dynamic>>[];
}

/// Bottom sheet: top-level comments from `GET /user/feed/:feedId/comments`;
/// replies from `GET /user/feed/comments/:commentId/replies` on demand.
class FeedCommentsSheet extends StatefulWidget {
  const FeedCommentsSheet({super.key, required this.feedId, required this.initialCommentCount, this.feedOwnerId, this.onCommentCountChanged});

  final String feedId;
  final int initialCommentCount;

  /// Post/reel creator — can delete any comment on this feed.
  final String? feedOwnerId;
  final ValueChanged<int>? onCommentCountChanged;

  @override
  State<FeedCommentsSheet> createState() => _FeedCommentsSheetState();
}

class _FeedCommentsSheetState extends State<FeedCommentsSheet> {
  final FeedRepository _feedRepo = FeedRepository();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];
  final Map<String, _ReplyThreadState> _replyThreads = <String, _ReplyThreadState>{};

  String? _replyParentId;
  String? _replyParentAuthorName;

  static const int _perPage = 20;

  bool _loading = true;
  bool _loadingMore = false;
  bool _submittingComment = false;
  bool _commentActionInFlight = false;
  bool _reportInFlight = false;
  bool _hasNext = true;
  String? _error;
  int _page = 1;
  int _totalDocs = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _totalDocs = widget.initialCommentCount;
    if (Get.isRegistered<StorageService>()) {
      _currentUserId = Get.find<StorageService>().getUserId();
    }
    _scrollController.addListener(_onScroll);
    if (widget.feedId.trim().isEmpty) {
      _loading = false;
      _error = 'Missing feed id';
    } else {
      _loadComments(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  _ReplyThreadState _threadFor(String parentCommentId) {
    return _replyThreads.putIfAbsent(parentCommentId, () => _ReplyThreadState());
  }

  int _replyCountHint(Map<String, dynamic> comment) {
    final thread = _replyThreads[(comment['id'] ?? '').toString()];
    if (thread != null && thread.expanded) return thread.totalReplies > 0 ? thread.totalReplies : thread.replies.length;
    final fromComment = comment['repliesCount'];
    if (fromComment is num && fromComment > 0) return fromComment.toInt();
    if (thread != null && thread.totalReplies > 0) return thread.totalReplies;
    if (thread != null && thread.replies.isNotEmpty) return thread.replies.length;
    return 0;
  }

  void _startReplyToComment(String commentId, String authorName) {
    if (commentId.isEmpty) return;
    setState(() {
      _replyParentId = commentId;
      _replyParentAuthorName = authorName;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    if (_replyParentId == null) return;
    setState(() {
      _replyParentId = null;
      _replyParentAuthorName = null;
    });
  }

  void _bumpCommentCount([int by = 1]) {
    _totalDocs += by;
    widget.onCommentCountChanged?.call(_totalDocs);
  }

  void _decrementCommentCount([int by = 1]) {
    _totalDocs = (_totalDocs - by).clamp(0, 1 << 30);
    widget.onCommentCountChanged?.call(_totalDocs);
  }

  bool _isOwnComment(Map<String, dynamic> comment) {
    final authorId = (comment['authorId'] ?? '').toString().trim();
    final myId = (_currentUserId ?? '').toString().trim();
    return authorId.isNotEmpty && myId.isNotEmpty && authorId == myId;
  }

  bool get _isFeedOwner {
    final owner = (widget.feedOwnerId ?? '').toString().trim();
    final myId = (_currentUserId ?? '').toString().trim();
    return owner.isNotEmpty && myId.isNotEmpty && owner == myId;
  }

  bool _canReportComment(Map<String, dynamic> comment) {
    if (_isOwnComment(comment)) return false;
    final myId = (_currentUserId ?? '').toString().trim();
    return myId.isNotEmpty;
  }

  Future<void> _showReportCommentDialog(Map<String, dynamic> comment) async {
    final commentId = (comment['id'] ?? '').toString().trim();
    final authorId = (comment['authorId'] ?? '').toString().trim();
    if (commentId.isEmpty || authorId.isEmpty) {
      Get.snackbar('Could not report', 'Comment information is missing.', snackPosition: SnackPosition.BOTTOM);
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
                    Text('Report comment', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface)),
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
                      textInputAction: TextInputAction.done,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    ),
                    if (MediaQuery.of(context).viewInsets.bottom > 0) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                          icon: const Icon(Icons.keyboard_hide_outlined, size: 18),
                          label: const Text('Done'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
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
                                  await _submitReportComment(authorId: authorId, commentId: commentId, reason: apiReason, details: details.isEmpty ? null : details);
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

  Future<void> _submitReportComment({required String authorId, required String commentId, required String reason, String? details}) async {
    if (_reportInFlight) return;
    setState(() => _reportInFlight = true);
    try {
      await _feedRepo.reportFeedRepo(creatorUserId: authorId, feedId: commentId, reason: reason, details: details, reportRefType: ReportRefType.feedComment);
      Get.snackbar('Report submitted', 'Thank you for your feedback.', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Could not report', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _reportInFlight = false);
    }
  }

  void _openCommentAuthorProfile(Map<String, dynamic> comment) {
    final authorId = (comment['authorId'] ?? '').toString().trim();
    final authorName = (comment['authorName'] ?? 'User').toString().trim();
    if (authorId.isEmpty && authorName.isEmpty) return;

    final initials = (comment['authorInitials'] ?? 'U').toString();
    final avatarUrl = (comment['avatarUrl'] ?? '').toString().trim();

    final profileData = <String, dynamic>{
      'returnToFeedOnBlock': true,
      if (authorId.isNotEmpty) '_id': authorId,
      if (authorId.isNotEmpty) 'id': authorId,
      if (authorId.isEmpty) 'id': authorName.toLowerCase().replaceAll(' ', '_'),
      'name': authorName.isNotEmpty ? authorName : 'User',
      'initials': initials,
      if (avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
      'bio': 'Fitness enthusiast sharing content with the community.',
      'specialties': <String>['Fitness', 'Training'],
      'yearsOfExperience': 2,
      'certified': false,
      'hourlyRate': 75.0,
      'rating': 4.8,
      'totalReviews': 0,
      'students': 0,
    };

    Get.toNamed(AppRoutes.trainerProfile, arguments: profileData);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Future<void> _editComment(Map<String, dynamic> comment, {required void Function(Map<String, dynamic>) onUpdated}) async {
    final commentId = (comment['id'] ?? '').toString().trim();
    if (commentId.isEmpty) return;

    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditCommentDialog(initialText: (comment['text'] ?? '').toString()),
    );

    if (newText == null || newText.trim().isEmpty || _commentActionInFlight) return;

    setState(() => _commentActionInFlight = true);
    try {
      final raw = await _feedRepo.updateFeedCommentRepo(feedId: widget.feedId, commentId: commentId, text: newText.trim());
      final data = (raw is Map && raw['data'] is Map) ? Map<String, dynamic>.from(raw['data'] as Map) : <String, dynamic>{};
      final commentRaw = data['comment'] ?? comment;
      final mapped = mapApiFeedCommentToUi(commentRaw);
      if (!mounted) return;
      setState(() => onUpdated(mapped));
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _commentActionInFlight = false);
    }
  }

  Future<void> _confirmDeleteTopLevel(int index, {bool asPostOwner = false}) async {
    final comment = _comments[index];
    final replyHint = _replyCountHint(comment);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(asPostOwner ? 'Remove comment' : 'Delete comment'),
        content: Text(
          asPostOwner
              ? (replyHint > 0 ? 'Remove this comment and its $replyHint ${replyHint == 1 ? 'reply' : 'replies'} from your post?' : 'Remove this comment from your post?')
              : (replyHint > 0 ? 'This will delete your comment and all $replyHint ${replyHint == 1 ? 'reply' : 'replies'}.' : 'Are you sure you want to delete this comment?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || _commentActionInFlight) return;
    await _deleteTopLevelComment(index);
  }

  Future<void> _confirmDeleteReply(String parentId, int replyIndex, {bool asCommentOwner = false, bool asPostOwner = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(asPostOwner || asCommentOwner ? 'Remove reply' : 'Delete reply'),
        content: Text(
          asPostOwner ? 'Remove this reply from your post?' : (asCommentOwner ? 'Remove this reply from your comment?' : 'Are you sure you want to delete this reply?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || _commentActionInFlight) return;
    await _deleteReply(parentId, replyIndex);
  }

  Future<void> _deleteTopLevelComment(int index) async {
    final comment = _comments[index];
    final commentId = (comment['id'] ?? '').toString().trim();
    if (commentId.isEmpty) return;

    final thread = _replyThreads[commentId];
    final replyRemoveCount = thread != null && thread.expanded ? thread.replies.length : _replyCountHint(comment);

    setState(() => _commentActionInFlight = true);
    try {
      await _feedRepo.deleteFeedCommentRepo(feedId: widget.feedId, commentId: commentId);
      if (!mounted) return;
      setState(() {
        _comments.removeAt(index);
        _replyThreads.remove(commentId);
        _decrementCommentCount(1 + replyRemoveCount);
        if (_replyParentId == commentId) {
          _replyParentId = null;
          _replyParentAuthorName = null;
        }
      });
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _commentActionInFlight = false);
    }
  }

  Future<void> _deleteReply(String parentId, int replyIndex) async {
    final thread = _threadFor(parentId);
    if (replyIndex < 0 || replyIndex >= thread.replies.length) return;

    final reply = thread.replies[replyIndex];
    final commentId = (reply['id'] ?? '').toString().trim();
    if (commentId.isEmpty) return;

    setState(() => _commentActionInFlight = true);
    try {
      await _feedRepo.deleteFeedCommentRepo(feedId: widget.feedId, commentId: commentId);
      if (!mounted) return;
      setState(() {
        thread.replies.removeAt(replyIndex);
        if (thread.totalReplies > 0) thread.totalReplies -= 1;
        final parentIdx = _comments.indexWhere((c) => (c['id'] ?? '').toString() == parentId);
        if (parentIdx >= 0) {
          final rc = _comments[parentIdx]['repliesCount'];
          if (rc is num && rc > 0) {
            _comments[parentIdx]['repliesCount'] = rc.toInt() - 1;
          }
        }
        _decrementCommentCount();
      });
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _commentActionInFlight = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _submittingComment) return;

    final parentId = _replyParentId;

    setState(() => _submittingComment = true);
    try {
      final raw = await _feedRepo.postFeedCommentRepo(feedId: widget.feedId, text: text, parentCommentId: parentId);
      final data = (raw is Map && raw['data'] is Map) ? Map<String, dynamic>.from(raw['data'] as Map) : <String, dynamic>{};
      final commentRaw = data['comment'];
      if (commentRaw == null) throw Exception('Invalid comment response');

      final mapped = mapApiFeedCommentToUi(commentRaw);
      if (parentId != null && parentId.isNotEmpty) {
        mapped['parentCommentId'] = parentId;
      }
      if ((mapped['id'] ?? '').toString().isEmpty) throw Exception('Invalid comment response');

      if (!mounted) return;
      setState(() {
        if (parentId != null && parentId.isNotEmpty) {
          final thread = _threadFor(parentId);
          if (thread.expanded) {
            final exists = thread.replies.any((r) => (r['id'] ?? '').toString() == (mapped['id'] ?? '').toString());
            if (!exists) thread.replies.add(mapped);
            sortFeedCommentsChronologically(thread.replies);
          }
          thread.totalReplies += 1;
          final parentIdx = _comments.indexWhere((c) => (c['id'] ?? '').toString() == parentId);
          if (parentIdx >= 0) {
            final rc = _comments[parentIdx]['repliesCount'];
            _comments[parentIdx]['repliesCount'] = (rc is num ? rc.toInt() : 0) + 1;
          }
        } else {
          final exists = _comments.any((c) => (c['id'] ?? '').toString() == (mapped['id'] ?? '').toString());
          if (!exists) _comments.insert(0, mapped);
        }
        _bumpCommentCount();
        _commentController.clear();
        _replyParentId = null;
        _replyParentAuthorName = null;
        _error = null;
      });

      if (_scrollController.hasClients && (parentId == null || parentId.isEmpty)) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _submittingComment = false);
    }
  }

  void _onScroll() {
    if (!_hasNext || _loading || _loadingMore || _error != null) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 120) return;
    _loadComments(reset: false);
  }

  Future<void> _loadComments({required bool reset}) async {
    if (reset) {
      if (_loading && _comments.isNotEmpty) return;
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _hasNext = true;
        _comments.clear();
        _replyThreads.clear();
      });
    } else {
      if (_loadingMore || !_hasNext) return;
      setState(() => _loadingMore = true);
    }

    final pageToFetch = reset ? 1 : _page;

    try {
      final raw = await _feedRepo.getFeedCommentsRepo(feedId: widget.feedId.trim(), page: pageToFetch, limit: _perPage);
      final data = (raw is Map && raw['data'] is Map) ? Map<String, dynamic>.from(raw['data'] as Map) : <String, dynamic>{};
      final commentsRaw = feedCommentsListFromApiResponse(raw);
      final mapped = commentsRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where(isTopLevelFeedCommentRaw)
          .map(mapApiFeedCommentToUi)
          .where((c) => (c['id'] ?? '').toString().isNotEmpty)
          .toList();

      final totalDocs = data['totalDocs'];
      if (totalDocs is num) {
        _totalDocs = totalDocs.toInt();
        widget.onCommentCountChanged?.call(_totalDocs);
      }

      if (!mounted) return;
      setState(() {
        _comments.addAll(mapped);
        _hasNext = readFeedCommentsHasNextPage(data);
        _page = pageToFetch + 1;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
        if (_comments.isNotEmpty) _hasNext = false;
      });
    }
  }

  Future<void> _loadReplies(String parentCommentId, {required bool reset}) async {
    final thread = _threadFor(parentCommentId);

    if (reset) {
      setState(() {
        thread.expanded = true;
        thread.loading = true;
        thread.error = null;
        thread.page = 1;
        thread.hasNext = true;
        thread.replies.clear();
      });
    } else {
      if (thread.loadingMore || !thread.hasNext) return;
      setState(() => thread.loadingMore = true);
    }

    final pageToFetch = reset ? 1 : thread.page;

    try {
      final raw = await _feedRepo.getFeedCommentRepliesRepo(commentId: parentCommentId, page: pageToFetch, limit: _perPage);
      final data = (raw is Map && raw['data'] is Map) ? Map<String, dynamic>.from(raw['data'] as Map) : <String, dynamic>{};
      final commentsRaw = feedCommentsListFromApiResponse(raw);
      final mapped = commentsRaw.map(mapApiFeedCommentToUi).where((c) => (c['id'] ?? '').toString().isNotEmpty).toList();

      final totalDocs = data['totalDocs'];
      final total = totalDocs is num ? totalDocs.toInt() : mapped.length;

      if (!mounted) return;
      setState(() {
        thread.replies.addAll(mapped);
        sortFeedCommentsChronologically(thread.replies);
        thread.totalReplies = total;
        thread.hasNext = readFeedCommentsHasNextPage(data);
        thread.page = pageToFetch + 1;
        thread.loading = false;
        thread.loadingMore = false;
        thread.error = null;

        final parentIdx = _comments.indexWhere((c) => (c['id'] ?? '').toString() == parentCommentId);
        if (parentIdx >= 0) _comments[parentIdx]['repliesCount'] = total;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        thread.error = e.toString();
        thread.loading = false;
        thread.loadingMore = false;
      });
    }
  }

  void _collapseReplies(String parentCommentId) {
    final thread = _replyThreads[parentCommentId];
    if (thread == null) return;
    setState(() {
      thread.expanded = false;
      thread.replies.clear();
      thread.loading = false;
      thread.loadingMore = false;
      thread.error = null;
    });
  }

  Widget _buildCommentContent({
    required Map<String, dynamic> comment,
    required bool showReplyOption,
    required VoidCallback onReply,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onReport,
    String deleteMenuLabel = 'Delete',
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(onTap: () => _openCommentAuthorProfile(comment), behavior: HitTestBehavior.opaque, child: _buildAvatar(comment)),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _openCommentAuthorProfile(comment),
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        (comment['authorName'] ?? 'User').toString(),
                        style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600, height: 1.2),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text((comment['text'] ?? '').toString(), style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, height: 1.25)),
                    const SizedBox(height: 2),
                    Text((comment['timestamp'] ?? '').toString(), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, height: 1.1)),
                  ],
                ),
              ),
              _buildCommentMenu(showReplyOption: showReplyOption, onReply: onReply, onEdit: onEdit, onDelete: onDelete, onReport: onReport, deleteLabel: deleteMenuLabel),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentMenu({
    required bool showReplyOption,
    required VoidCallback onReply,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onReport,
    String deleteLabel = 'Delete',
  }) {
    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        splashRadius: 18,
        offset: const Offset(0, 28),
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        enabled: !_commentActionInFlight && !_submittingComment && !_reportInFlight,
        icon: Icon(Icons.more_vert, size: 18, color: AppColors.primaryGray.withValues(alpha: 0.85)),
        onSelected: (value) {
          if (value == 'reply') onReply();
          if (value == 'report') onReport?.call();
          if (value == 'edit') onEdit?.call();
          if (value == 'delete') onDelete?.call();
        },
        itemBuilder: (context) => [
          if (showReplyOption)
            PopupMenuItem<String>(
              value: 'reply',
              child: Text('Reply', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontSize: 14)),
            ),
          if (onReport != null)
            PopupMenuItem<String>(
              value: 'report',
              child: Text('Report', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontSize: 14)),
            ),
          if (onEdit != null)
            PopupMenuItem<String>(
              value: 'edit',
              child: Text('Edit', style: AppTextStyles.bodySmall.copyWith(fontSize: 14)),
            ),
          if (onDelete != null)
            PopupMenuItem<String>(
              value: 'delete',
              child: Text(deleteLabel, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontSize: 14)),
            ),
        ],
      ),
    );
  }

  Widget _buildTopLevelComment(int index) {
    final comment = _comments[index];
    final commentId = (comment['id'] ?? '').toString();
    final isOwn = _isOwnComment(comment);
    final canDelete = isOwn || _isFeedOwner;
    final authorName = (comment['authorName'] ?? 'User').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentContent(
          comment: comment,
          showReplyOption: true,
          onReply: () => _startReplyToComment(commentId, authorName),
          onReport: _canReportComment(comment) ? () => _showReportCommentDialog(comment) : null,
          onEdit: isOwn ? () => _editComment(comment, onUpdated: (m) => setState(() => _comments[index] = m)) : null,
          onDelete: canDelete ? () => _confirmDeleteTopLevel(index, asPostOwner: _isFeedOwner && !isOwn) : null,
          deleteMenuLabel: _isFeedOwner && !isOwn ? 'Remove' : 'Delete',
        ),
        _buildRepliesSection(comment),
      ],
    );
  }

  Widget _buildRepliesSection(Map<String, dynamic> parentComment) {
    final parentId = (parentComment['id'] ?? '').toString();
    final thread = _threadFor(parentId);
    final hint = _replyCountHint(parentComment);

    if (!thread.expanded) {
      if (hint <= 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(left: 46, top: 6),
        child: GestureDetector(
          onTap: () => _loadReplies(parentId, reset: true),
          behavior: HitTestBehavior.opaque,
          child: Text(
            'View $hint ${hint == 1 ? 'reply' : 'replies'}',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 28, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (thread.loading && thread.replies.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
            )
          else if (thread.error != null && thread.replies.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Could not load replies', style: AppTextStyles.labelSmall.copyWith(color: AppColors.error)),
                TextButton(onPressed: () => _loadReplies(parentId, reset: true), child: const Text('Retry')),
              ],
            )
          else ...[
            for (var i = 0; i < thread.replies.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildReplyTile(parentId, i)),
            if (thread.loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                ),
              ),
            if (thread.hasNext && !thread.loading && !thread.loadingMore)
              TextButton(
                onPressed: () => _loadReplies(parentId, reset: false),
                child: Text('Load more replies', style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent)),
              ),
          ],
          GestureDetector(
            onTap: () => _collapseReplies(parentId),
            child: Text(
              'Hide replies',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyTile(String parentId, int replyIndex) {
    final reply = _threadFor(parentId).replies[replyIndex];
    final isOwnReply = _isOwnComment(reply);
    final parentIdx = _comments.indexWhere((c) => (c['id'] ?? '').toString() == parentId);
    final isParentOwner = parentIdx >= 0 && _isOwnComment(_comments[parentIdx]);
    final canDeleteReply = isOwnReply || _isFeedOwner || isParentOwner;
    final replyToName = parentIdx >= 0 ? (_comments[parentIdx]['authorName'] ?? 'User').toString() : 'User';

    return _buildCommentContent(
      comment: reply,
      showReplyOption: true,
      onReply: () => _startReplyToComment(parentId, replyToName),
      onReport: _canReportComment(reply) ? () => _showReportCommentDialog(reply) : null,
      onEdit: isOwnReply ? () => _editComment(reply, onUpdated: (m) => setState(() => _threadFor(parentId).replies[replyIndex] = m)) : null,
      onDelete: canDeleteReply
          ? () => _confirmDeleteReply(parentId, replyIndex, asPostOwner: _isFeedOwner && !isOwnReply, asCommentOwner: isParentOwner && !isOwnReply && !_isFeedOwner)
          : null,
      deleteMenuLabel: (_isFeedOwner || isParentOwner) && !isOwnReply ? 'Remove' : 'Delete',
    );
  }

  Widget _buildAvatar(Map<String, dynamic> comment) {
    final url = ImageUrlSanitizer.asHttpUrlOrNull((comment['avatarUrl'] ?? '').toString());
    final initials = (comment['authorInitials'] ?? 'U').toString();
    if (url != null) {
      return CircleAvatar(radius: 16, backgroundColor: AppColors.accent.withValues(alpha: 0.2), backgroundImage: NetworkImage(url));
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.accent.withValues(alpha: 0.2),
      child: Text(initials, style: AppTextStyles.labelMedium),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commentCountLabel = _formatCommentCount(_totalDocs > 0 ? _totalDocs : widget.initialCommentCount);

    final maxSheetHeight = MediaQuery.of(context).size.height * 0.75;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16 + MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Comments',
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(commentCountLabel, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: 220, maxHeight: maxSheetHeight * 0.55),
                child: _buildCommentsBody(),
              ),
            ),
            const SizedBox(height: 12),
            if (_replyParentId != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to ${_replyParentAuthorName ?? 'comment'}',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: _cancelReply,
                      child: Icon(Icons.close, size: 18, color: AppColors.primaryGray.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    enabled: !_submittingComment,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                    decoration: InputDecoration(
                      hintText: _replyParentId != null ? 'Write a reply...' : 'Add a comment...',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _submittingComment ? null : _submitComment,
                  icon: _submittingComment
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                      : const Icon(Icons.send, color: AppColors.accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsBody() {
    if (_loading && _comments.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_error != null && _comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Could not load comments',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => _loadComments(reset: true), child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_comments.isEmpty) {
      return Center(
        child: Text('No comments yet', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      itemCount: _comments.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 12),
      itemBuilder: (context, index) {
        if (index >= _comments.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
            ),
          );
        }
        return _buildTopLevelComment(index);
      },
    );
  }
}

/// Edit-comment dialog; owns [TextEditingController] so it is not disposed while the route animates out.
class _EditCommentDialog extends StatefulWidget {
  const _EditCommentDialog({required this.initialText});

  final String initialText;

  @override
  State<_EditCommentDialog> createState() => _EditCommentDialogState();
}

class _EditCommentDialogState extends State<_EditCommentDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit comment'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        minLines: 1,
        decoration: const InputDecoration(hintText: 'Write your comment...'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) return;
            Navigator.pop(context, text);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
