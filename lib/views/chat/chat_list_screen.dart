import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:get_right/controllers/chat_controller.dart';
import 'package:get_right/models/chat_message_model.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/api_service.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/safe_circle_network_avatar.dart';

/// Chat List Screen - Shows all conversations and allows starting new chats
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  ChatController? _chatController;
  bool _isInitializing = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeController();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _chatController == null) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _chatController!.loadMoreConversations();
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _chatController?.loadConversations(page: 1, search: value);
    });
  }

  Future<void> _initializeController() async {
    try {
      final apiService = await ApiService.getInstance();
      final storageService = await StorageService.getInstance();

      // Check if controller already exists
      if (Get.isRegistered<ChatController>()) {
        _chatController = Get.find<ChatController>();
      } else {
        _chatController = Get.put(ChatController(apiService, storageService));
      }

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        _chatController?.leaveChatRoom();
        await _chatController?.refreshConversations();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _openChatRoom(ConversationModel conversation) async {
    await Get.toNamed(
      AppRoutes.chatRoom,
      preventDuplicates: false,
      arguments: {
        'conversationId': conversation.id,
        'trainerId': conversation.trainerId,
        'trainerName': conversation.trainerName,
        'trainerImage': conversation.trainerImage,
        'programId': conversation.programId,
        'programTitle': conversation.programTitle,
      },
    );
    _chatController?.leaveChatRoom();
    await _chatController?.refreshConversations();
  }

  Future<void> _onRefreshConversations() async {
    await _chatController?.refreshConversations();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(timestamp);
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('Messages', style: AppTextStyles.titleLarge.copyWith()),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isInitializing || _chatController == null
          ? const Center(child: CircularProgressIndicator())
          : Obx(() {
              final conversations = _chatController!.conversations;
              final isLoading = _chatController!.isLoading.value;
              final isLoadingMore = _chatController!.isLoadingMore.value;

              return Column(
                children: [
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppColors.background,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search conversations...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primaryGray),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppColors.primaryGray),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.accent, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  // Conversations List
                  Expanded(child: _buildConversationsList(isLoading, isLoadingMore, conversations)),
                ],
              );
            }),
    );
  }

  Widget _buildConversationsList(bool isLoading, bool isLoadingMore, List<ConversationModel> conversations) {
    if (isLoading && conversations.isEmpty) {
      return RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _onRefreshConversations,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          children: const [
            SizedBox(height: 240),
            Center(child: CircularProgressIndicator(color: AppColors.accent)),
          ],
        ),
      );
    }

    if (conversations.isEmpty) {
      return RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _onRefreshConversations,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.chat_bubble_outline, size: 80, color: AppColors.primaryGray),
                  const SizedBox(height: 24),
                  Text(_searchQuery.isNotEmpty ? 'No Results Found' : 'No Messages', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground)),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isNotEmpty ? 'Try adjusting your search query' : 'Start a conversation with your trainers from enrolled programs.',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                    textAlign: TextAlign.center,
                  ),
                  if (!_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        Get.toNamed(AppRoutes.myPrograms);
                      },
                      icon: const Icon(Icons.fitness_center),
                      label: const Text('View My Programs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _onRefreshConversations,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: conversations.length + (isLoadingMore ? 1 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemBuilder: (context, index) {
          if (index >= conversations.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
            );
          }
          final conversation = conversations[index];
          final lastMessage = conversation.lastMessage;
          final displayTime = lastMessage?.timestamp ?? conversation.updatedAt;
          final previewText = lastMessage == null
              ? 'No messages yet'
              : lastMessage.type == 'image'
              ? '📷 Photo'
              : lastMessage.type == 'video'
              ? '🎥 Video'
              : lastMessage.type == 'audio'
              ? '🎤 Audio'
              : lastMessage.message;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryGray.withOpacity(0.2), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: SafeCircleNetworkAvatar(
                radius: 24,
                imageUrl: conversation.trainerImage,
                backgroundColor: AppColors.accent,
                fallback: Text(
                  conversation.trainerName.isNotEmpty ? conversation.trainerName[0].toUpperCase() : 'T',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onAccent),
                ),
              ),
              title: Text(
                conversation.trainerName,
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: conversation.unreadCount > 0 ? FontWeight.w700 : FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (conversation.programTitle.isNotEmpty) ...[
                    Text(
                      conversation.programTitle,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    previewText,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: conversation.unreadCount > 0 ? AppColors.onBackground : AppColors.primaryGrayDark,
                      fontWeight: conversation.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatTimestamp(displayTime), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark)),
                  if (conversation.unreadCount > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                      child: Text(conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}', style: AppTextStyles.labelSmall.copyWith(color: AppColors.onAccent)),
                    ),
                  ],
                ],
              ),
              onTap: () => _openChatRoom(conversation),
            ),
          );
        },
      ),
    );
  }
}
