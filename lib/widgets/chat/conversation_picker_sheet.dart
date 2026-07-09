import 'package:flutter/material.dart';
import 'package:get_right/models/chat_message_model.dart';
import 'package:get_right/repo/chat_repo.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/safe_circle_network_avatar.dart';

/// Bottom sheet to pick a conversation for share-to-chat.
class ConversationPickerSheet extends StatefulWidget {
  const ConversationPickerSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ConversationPickerSheet(),
    );
  }

  @override
  State<ConversationPickerSheet> createState() => _ConversationPickerSheetState();
}

class _ConversationPickerSheetState extends State<ConversationPickerSheet> {
  final ChatRepository _chatRepo = ChatRepository();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ConversationModel> _conversations = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNextPage = false;
  int _page = 1;
  String? _error;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final storage = await StorageService.getInstance();
    _currentUserId = storage.getUserId();
    await _load(page: 1, search: '');
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasNextPage) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 120) {
      _load(page: _page + 1, search: _searchController.text, append: true);
    }
  }

  Future<void> _load({required int page, required String search, bool append = false}) async {
    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await _chatRepo.fetchConversations(
        page: page,
        limit: 20,
        search: search,
        currentUserId: _currentUserId,
      );
      if (!mounted) return;
      setState(() {
        if (append) {
          _conversations = [..._conversations, ...result.conversations];
        } else {
          _conversations = result.conversations;
        }
        _page = result.currentPage;
        _hasNextPage = result.hasNextPage;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.4), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text('Share to Chat', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search conversations',
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryGray),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onSubmitted: (value) => _load(page: 1, search: value),
              onChanged: (value) {
                if (value.trim().isEmpty) _load(page: 1, search: '');
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
        ),
      );
    }
    if (_conversations.isEmpty) {
      return Center(
        child: Text('No conversations yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _conversations.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index >= _conversations.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
          );
        }
        final conversation = _conversations[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pop(context, conversation.id),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  SafeCircleNetworkAvatar(
                    radius: 22,
                    imageUrl: conversation.trainerImage,
                    backgroundColor: AppColors.accent,
                    fallback: Text(
                      conversation.trainerName.isNotEmpty ? conversation.trainerName[0].toUpperCase() : 'T',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onAccent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      conversation.trainerName,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.primaryGray),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
