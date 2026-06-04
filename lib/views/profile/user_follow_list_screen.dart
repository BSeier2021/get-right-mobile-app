import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/repo/trainer_profile_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/follow_list_mapper.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

enum UserFollowListType { followers, following }

/// Followers or following list for a profile (`GET /user/follow/:userId/...`).
class UserFollowListScreen extends StatefulWidget {
  const UserFollowListScreen({super.key, required this.type});

  final UserFollowListType type;

  @override
  State<UserFollowListScreen> createState() => _UserFollowListScreenState();
}

class _UserFollowListScreenState extends State<UserFollowListScreen> {
  final TrainerProfileRepository _repo = TrainerProfileRepository();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _users = <Map<String, dynamic>>[];
  final Set<String> _followActionInFlight = <String>{};

  String? _userId;
  String _profileName = '';
  String? _currentUserId;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNext = true;
  int _page = 1;
  int _totalDocs = 0;
  String? _error;

  static const int _perPage = 20;

  bool get _isFollowers => widget.type == UserFollowListType.followers;

  bool get _isOwnProfile {
    final viewer = _currentUserId?.trim();
    final owner = _userId?.trim();
    return viewer != null && viewer.isNotEmpty && owner != null && owner.isNotEmpty && viewer == owner;
  }

  String get _title => _isFollowers ? 'Followers' : 'Following';

  @override
  void initState() {
    super.initState();
    _readArguments();
    _resolveProfileUserId();
    if (Get.isRegistered<StorageService>()) {
      _currentUserId = Get.find<StorageService>().getUserId();
    }
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _readArguments() {
    final args = Get.arguments;
    if (args is Map) {
      _userId = (args['userId'] ?? args['id'] ?? args['_id'])?.toString().trim();
      _profileName = (args['profileName'] ?? args['name'] ?? '').toString().trim();
    }
  }

  void _resolveProfileUserId() {
    if (_userId != null && _userId!.isNotEmpty) return;

    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      final id = auth.customerProfile?.userId.trim();
      if (id != null && id.isNotEmpty) {
        _userId = id;
        if (_profileName.isEmpty) {
          final p = auth.customerProfile;
          final n = p?.fullName?.trim();
          if (n != null && n.isNotEmpty) {
            _profileName = n;
          } else if (p != null && p.email.isNotEmpty) {
            _profileName = p.email.split('@').first;
          }
        }
      }
    }

    if ((_userId == null || _userId!.isEmpty) && Get.isRegistered<StorageService>()) {
      _userId = Get.find<StorageService>().getUserId()?.trim();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore || !_hasNext) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _load(reset: false);
    }
  }

  Future<void> _load({required bool reset}) async {
    final id = _userId;
    if (id == null || id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'User id is missing';
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
      final raw = _isFollowers ? await _repo.getFollowersRepo(id, page: pageToFetch, limit: _perPage) : await _repo.getFollowingRepo(id, page: pageToFetch, limit: _perPage);

      final parsed = parseFollowListResponse(raw, followers: _isFollowers);
      if (!mounted) return;

      setState(() {
        if (parsed != null) {
          final batch = List<Map<String, dynamic>>.from(parsed.users);
          if (!_isFollowers && _isOwnProfile) {
            for (final u in batch) {
              u['isFollowing'] = true;
            }
          }
          if (reset) {
            _users
              ..clear()
              ..addAll(batch);
          } else {
            final existing = _users.map((u) => (u['id'] ?? '').toString()).toSet();
            _users.addAll(batch.where((u) => !existing.contains((u['id'] ?? '').toString())));
          }
          _totalDocs = parsed.totalDocs;
          _hasNext = parsed.hasNextPage;
          _page = parsed.currentPage + 1;
          _error = null;
        } else if (reset) {
          _error = 'Could not load $_title';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (reset) _error = e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Could not load $_title';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _openProfile(Map<String, dynamic> user) {
    final id = (user['id'] ?? '').toString();
    if (id.isEmpty) return;

    Get.toNamed(AppRoutes.trainerProfile, arguments: <String, dynamic>{'_id': id, 'id': id, 'name': user['name'], 'avatarUrl': user['avatarUrl'], 'role': user['role']});
  }

  Future<void> _toggleFollow(Map<String, dynamic> user) async {
    final id = (user['id'] ?? '').toString();
    if (id.isEmpty || _followActionInFlight.contains(id)) return;

    final wasFollowing = user['isFollowing'] == true;
    setState(() {
      _followActionInFlight.add(id);
      user['isFollowing'] = !wasFollowing;
    });

    try {
      final isFollowing = wasFollowing ? await _repo.unfollowUserRepo(id) : await _repo.followUserRepo(id);
      if (!mounted) return;
      setState(() {
        user['isFollowing'] = isFollowing;
        if (!_isFollowers && !isFollowing) {
          _users.removeWhere((u) => (u['id'] ?? '').toString() == id);
          _totalDocs = (_totalDocs - 1).clamp(0, 1 << 30);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => user['isFollowing'] = wasFollowing);
      Get.snackbar('Could not update', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _followActionInFlight.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _profileName.isNotEmpty ? _profileName : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_title, style: AppTextStyles.titleLarge.copyWith()),
            if (subtitle != null)
              Text(
                subtitle,
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_error != null && _users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _users.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _users.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
              ),
            );
          }
          return _buildUserCard(_users[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppColors.accent.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(_isFollowers ? 'No followers yet' : 'Not following anyone', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _isFollowers ? 'When people follow this account, they will appear here.' : 'Accounts this user follows will appear here.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final userId = (user['id'] ?? '').toString();
    final isSelf = _currentUserId != null && userId.isNotEmpty && userId == _currentUserId;
    final isFollowing = user['isFollowing'] == true;
    final busy = _followActionInFlight.contains(userId);
    final avatarUrl = ImageUrlSanitizer.asHttpUrlOrNull((user['avatarUrl'] ?? '').toString());
    final initials = (user['initials'] ?? 'U').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _openProfile(user),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.accent.withOpacity(0.2),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      initials,
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _openProfile(user),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          (user['name'] ?? '').toString(),
                          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user['isTrainer'] == true) ...[const SizedBox(width: 4), Icon(Icons.verified, size: 16, color: AppColors.accent)],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('@${user['username'] ?? ''}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                ],
              ),
            ),
          ),
          if (!isSelf) _buildFollowAction(user, isFollowing: isFollowing, busy: busy),
        ],
      ),
    );
  }

  Widget _buildFollowAction(Map<String, dynamic> user, {required bool isFollowing, required bool busy}) {
    final showUnfollow = isFollowing || (!_isFollowers && _isOwnProfile);

    if (showUnfollow) {
      return OutlinedButton(
        onPressed: busy ? null : () => _toggleFollow(user),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.primaryGray.withOpacity(0.55), width: 1.5),
          foregroundColor: AppColors.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: busy
            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onSurface.withOpacity(0.7)))
            : Text(
                'Unfollow',
                style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface),
              ),
      );
    }

    return ElevatedButton(
      onPressed: busy ? null : () => _toggleFollow(user),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: busy
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(
              'Follow',
              style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.onAccent),
            ),
    );
  }
}
