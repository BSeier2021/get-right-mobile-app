import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/repo/feed_repo.dart';
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

/// Bottom sheet listing feed comments from `GET /user/feed/:feedId/comments`.
class FeedCommentsSheet extends StatefulWidget {
  const FeedCommentsSheet({super.key, required this.feedId, required this.initialCommentCount, this.onCommentCountChanged});

  final String feedId;
  final int initialCommentCount;
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
  String? _replyParentId;
  String? _replyParentAuthorName;

  static const int _perPage = 20;

  bool _loading = true;
  bool _loadingMore = false;
  bool _submittingComment = false;
  bool _commentActionInFlight = false;
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
    _loadComments(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _startReply(int index) {
    final comment = _comments[index];
    final parentId = (comment['id'] ?? '').toString().trim();
    if (parentId.isEmpty) return;
    setState(() {
      _replyParentId = parentId;
      _replyParentAuthorName = (comment['authorName'] ?? 'User').toString();
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

  void _insertCommentInList(Map<String, dynamic> mapped) {
    final parentId = _replyParentId;
    if (parentId != null && parentId.isNotEmpty) {
      final parentIdx = _comments.indexWhere((c) => (c['id'] ?? '').toString() == parentId);
      if (parentIdx >= 0) {
        var insertAt = parentIdx + 1;
        while (insertAt < _comments.length) {
          final nextParent = (_comments[insertAt]['parentCommentId'] ?? '').toString();
          if (nextParent != parentId) break;
          insertAt++;
        }
        _comments.insert(insertAt, mapped);
        return;
      }
    }
    _comments.insert(0, mapped);
  }

  void _bumpCommentCount() {
    _totalDocs = _totalDocs + 1;
    widget.onCommentCountChanged?.call(_totalDocs);
  }

  void _decrementCommentCount() {
    if (_totalDocs > 0) _totalDocs = _totalDocs - 1;
    widget.onCommentCountChanged?.call(_totalDocs);
  }

  bool _isOwnComment(Map<String, dynamic> comment) {
    final authorId = (comment['authorId'] ?? '').toString().trim();
    final myId = (_currentUserId ?? '').toString().trim();
    return authorId.isNotEmpty && myId.isNotEmpty && authorId == myId;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Future<void> _editComment(int index) async {
    final comment = _comments[index];
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
      setState(() => _comments[index] = mapped);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _commentActionInFlight = false);
    }
  }

  Future<void> _confirmDeleteComment(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment'),
        content: const Text('Are you sure you want to delete this comment?'),
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
    await _deleteComment(index);
  }

  Future<void> _deleteComment(int index) async {
    final comment = _comments[index];
    final commentId = (comment['id'] ?? '').toString().trim();
    if (commentId.isEmpty) return;

    setState(() => _commentActionInFlight = true);
    try {
      await _feedRepo.deleteFeedCommentRepo(feedId: widget.feedId, commentId: commentId);
      if (!mounted) return;
      setState(() {
        _comments.removeAt(index);
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
      if (commentRaw == null) {
        throw Exception('Invalid comment response');
      }
      final mapped = mapApiFeedCommentToUi(commentRaw);
      if (parentId != null && parentId.isNotEmpty && (mapped['parentCommentId'] ?? '').toString().isEmpty) {
        mapped['parentCommentId'] = parentId;
      }
      if ((mapped['id'] ?? '').toString().isEmpty) {
        throw Exception('Invalid comment response');
      }

      if (!mounted) return;
      setState(() {
        final exists = _comments.any((c) => (c['id'] ?? '').toString() == (mapped['id'] ?? '').toString());
        if (!exists) {
          _insertCommentInList(mapped);
          _bumpCommentCount();
        }
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating));
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
      });
    } else {
      if (_loadingMore || !_hasNext) return;
      setState(() => _loadingMore = true);
    }

    final pageToFetch = reset ? 1 : _page;

    try {
      final raw = await _feedRepo.getFeedCommentsRepo(feedId: widget.feedId, page: pageToFetch, limit: _perPage);
      final data = (raw is Map && raw['data'] is Map) ? Map<String, dynamic>.from(raw['data'] as Map) : <String, dynamic>{};
      final commentsRaw = (data['comments'] is List) ? List.from(data['comments'] as List) : const [];
      final mapped = commentsRaw.map(mapApiFeedCommentToUi).where((c) => (c['id'] ?? '').toString().isNotEmpty).toList();

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

  Widget _buildCommentTile(Map<String, dynamic> comment, int index) {
    final isOwn = _isOwnComment(comment);
    final parentId = (comment['parentCommentId'] ?? '').toString();
    final isReply = parentId.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 28 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(comment),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      (comment['authorName'] ?? 'User').toString(),
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                      enabled: !_commentActionInFlight && !_submittingComment,
                      icon: Icon(Icons.more_vert, size: 20, color: AppColors.primaryGray.withOpacity(0.85)),
                      onSelected: (value) {
                        if (value == 'reply') {
                          _startReply(index);
                        } else if (value == 'edit') {
                          _editComment(index);
                        } else if (value == 'delete') {
                          _confirmDeleteComment(index);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(value: 'reply', child: Text('Reply')),
                        if (isOwn) ...[
                          const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                Text((comment['text'] ?? '').toString(), style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)),
                Text((comment['timestamp'] ?? '').toString(), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> comment) {
    final url = ImageUrlSanitizer.asHttpUrlOrNull((comment['avatarUrl'] ?? '').toString());
    final initials = (comment['authorInitials'] ?? 'U').toString();
    if (url != null) {
      return CircleAvatar(radius: 16, backgroundColor: AppColors.accent.withOpacity(0.2), backgroundImage: NetworkImage(url));
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.accent.withOpacity(0.2),
      child: Text(initials, style: AppTextStyles.labelMedium),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commentCountLabel = _formatCommentCount(_totalDocs > 0 ? _totalDocs : widget.initialCommentCount);

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.4), borderRadius: BorderRadius.circular(2)),
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
          SizedBox(height: 280, child: _buildCommentsBody()),
          const SizedBox(height: 12),
          if (_replyParentId != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
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
                    child: Icon(Icons.close, size: 18, color: AppColors.primaryGray.withOpacity(0.9)),
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
                      borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.3)),
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
      separatorBuilder: (_, __) => const Divider(height: 8),
      itemBuilder: (context, index) {
        if (index >= _comments.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
            ),
          );
        }
        final comment = _comments[index];
        return _buildCommentTile(comment, index);
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
