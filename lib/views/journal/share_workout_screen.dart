import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/models/shared_content_model.dart';
import 'package:get_right/repo/chat_repo.dart';
import 'package:get_right/repo/trainer_profile_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/follow_list_mapper.dart';
import 'package:get_right/widgets/safe_circle_network_avatar.dart';

/// Share a workout journal with people you follow.
class ShareWorkoutScreen extends StatefulWidget {
  const ShareWorkoutScreen({super.key});

  @override
  State<ShareWorkoutScreen> createState() => _ShareWorkoutScreenState();
}

class _ShareWorkoutScreenState extends State<ShareWorkoutScreen> {
  final TrainerProfileRepository _followRepo = TrainerProfileRepository();
  final ChatRepository _chatRepo = ChatRepository();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _users = [];
  final Set<String> _selectedIds = {};

  String? _currentUserId;
  String? _workoutJournalId;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sharing = false;
  bool _hasNext = true;
  int _page = 1;
  String? _error;
  String _searchQuery = '';

  static const int _perPage = 20;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      final id = (args['workoutJournalId'] ?? args['journalId'])?.toString().trim();
      if (WorkoutRepository.isValidMongoId(id)) {
        _workoutJournalId = id;
      }
    }
    _resolveCurrentUserId();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resolveCurrentUserId() {
    if (Get.isRegistered<AuthController>()) {
      final id = Get.find<AuthController>().customerProfile?.userId.trim();
      if (id != null && id.isNotEmpty) {
        _currentUserId = id;
        return;
      }
    }
    if (Get.isRegistered<StorageService>()) {
      _currentUserId = Get.find<StorageService>().getUserId()?.trim();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore || !_hasNext) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _load(reset: false);
    }
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim().toLowerCase();
    if (next == _searchQuery) return;
    setState(() => _searchQuery = next);
  }

  Future<void> _load({required bool reset}) async {
    final userId = _currentUserId?.trim();
    if (userId == null || userId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Could not load your following list';
      });
      return;
    }

    if (reset) {
      if (_loadingMore) return;
    } else {
      if (_loadingMore || !_hasNext) return;
    }

    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
        _page = 1;
        _hasNext = true;
        _users.clear();
      } else {
        _loadingMore = true;
      }
    });

    final pageToFetch = reset ? 1 : _page;

    try {
      final raw = await _followRepo.getFollowingRepo(userId, page: pageToFetch, limit: _perPage);
      final parsed = parseFollowListResponse(raw, followers: false);
      if (!mounted) return;

      setState(() {
        if (parsed != null) {
          _users.addAll(parsed.users);
          _hasNext = parsed.hasNextPage;
          _page = parsed.currentPage + 1;
        } else {
          _hasNext = false;
        }
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

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) {
      final name = (user['name'] ?? '').toString().toLowerCase();
      final username = (user['username'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || username.contains(_searchQuery);
    }).toList();
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedIds.contains(userId)) {
        _selectedIds.remove(userId);
      } else {
        _selectedIds.add(userId);
      }
    });
  }

  Future<void> _shareWorkout() async {
    final journalId = _workoutJournalId;
    if (!WorkoutRepository.isValidMongoId(journalId)) {
      Get.snackbar(
        'Cannot share',
        'Save at least one exercise first',
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (_selectedIds.isEmpty) {
      Get.snackbar(
        'Select a friend',
        'Choose at least one person to share with',
        backgroundColor: AppColors.primaryGrayDark,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _sharing = true);
    var successCount = 0;
    String? lastError;

    for (final userId in _selectedIds) {
      try {
        final conversation = await _chatRepo.createConversationWith(userId, currentUserId: _currentUserId);
        await _chatRepo.sendSharedContentMessage(
          conversationId: conversation.id,
          type: SharedContentType.workoutJournal,
          contentId: journalId!,
        );
        successCount++;
      } catch (e) {
        lastError = e.toString().replaceFirst('Exception: ', '');
      }
    }

    if (!mounted) return;
    setState(() => _sharing = false);

    if (successCount > 0) {
      Get.back(result: true);
      Get.snackbar(
        'Shared',
        successCount == 1 ? 'Workout shared with 1 friend' : 'Workout shared with $successCount friends',
        backgroundColor: AppColors.completed,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    Get.snackbar(
      'Could not share',
      lastError ?? 'Something went wrong',
      backgroundColor: AppColors.error,
      colorText: AppColors.onError,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 20.sp),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'SHARE WORKOUT',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            fontSize: 14.sp,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 4.h, 24.w, 0),
            child: Text(
              'Share your workout with a friend. They’ll be able to view it and add it to their own calendar.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primaryGrayDark,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: TextField(
              controller: _searchController,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: 'Search your followers...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                prefixIcon: Icon(Icons.search, color: AppColors.primaryGray, size: 22.sp),
                filled: true,
                fillColor: AppColors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.25)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
                ),
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'FOLLOWING',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(child: _buildList(filtered)),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
              child: SizedBox(
                width: double.infinity,
                height: 54.h,
                child: ElevatedButton(
                  onPressed: _sharing ? null : _shareWorkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: _sharing
                      ? SizedBox(
                          width: 22.w,
                          height: 22.w,
                          child: const CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onAccent),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Share Workout',
                              style: AppTextStyles.buttonLarge.copyWith(
                                color: AppColors.onAccent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Icon(Icons.send_rounded, color: AppColors.onAccent, size: 20.sp),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> users) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
              SizedBox(height: 12.h),
              TextButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Text(
            _searchQuery.isEmpty ? 'You’re not following anyone yet' : 'No matches found',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
      itemCount: users.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => SizedBox(height: 4.h),
      itemBuilder: (context, index) {
        if (index >= users.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
          );
        }

        final user = users[index];
        final id = (user['id'] ?? '').toString();
        final name = (user['name'] ?? 'User').toString();
        final username = (user['username'] ?? '').toString();
        final avatarUrl = user['avatarUrl']?.toString();
        final initials = (user['initials'] ?? 'U').toString();
        final selected = _selectedIds.contains(id);

        return InkWell(
          onTap: id.isEmpty ? null : () => _toggleSelection(id),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
            child: Row(
              children: [
                SafeCircleNetworkAvatar(
                  imageUrl: avatarUrl,
                  radius: 26,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                  fallback: Text(
                    initials,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (username.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          '@$username',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 24.w,
                  height: 24.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.accent : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.primaryGray.withValues(alpha: 0.7),
                      width: 1.6,
                    ),
                  ),
                  child: selected
                      ? Icon(Icons.check, size: 14.sp, color: AppColors.onAccent)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
