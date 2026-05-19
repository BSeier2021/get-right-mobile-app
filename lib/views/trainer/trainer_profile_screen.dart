import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/repo/trainer_profile_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/feed_post_mapper.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

/// Trainer Profile Screen with Tabs
class TrainerProfileScreen extends StatefulWidget {
  const TrainerProfileScreen({super.key});

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen> with SingleTickerProviderStateMixin {
  static final RegExp _mongoIdRe = RegExp(r'^[a-fA-F0-9]{24}$');

  late TabController _tabController;
  final TrainerProfileRepository _trainerRepo = TrainerProfileRepository();
  final _storageService = Get.find<StorageService>();

  Map<String, dynamic> trainer = {};

  String? _mongoUserId;

  bool _bootstrapLoading = false;
  bool _programsTabLoading = false;
  String? _loadError;

  bool _isFollowedByMe = false;
  bool _followActionLoading = false;
  bool _bioExpanded = false;

  static const int _bioCollapsedMaxLines = 2;

  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _bundles = [];

  String? _programsLoadError;
  String? _bundlesLoadError;

  /// Programs + Training tabs only when API / args indicate `Trainer`.
  bool get _showProgramsTrainingTabs => (trainer['role'] ?? '').toString().trim().toLowerCase() == 'trainer';

  int _tabLengthForRole() => _showProgramsTrainingTabs ? 3 : 1;

  @override
  void initState() {
    super.initState();
    trainer = _argumentsToTrainerMap(Get.arguments);
    _mongoUserId = _extractMongoUserId(Get.arguments);
    _tabController = TabController(length: _tabLengthForRole(), vsync: this);
    _tabController.addListener(_onProgramsTabShow);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Arguments can be filled on the next frame in some navigations; re-resolve id once.
      _mongoUserId ??= _extractMongoUserId(Get.arguments);
      _loadProfileFromApi();
    });
  }

  void _onProgramsTabShow() {
    if (!_tabController.indexIsChanging && _tabController.index == 1 && _mongoUserId != null && !_programsTabLoading && _programs.isEmpty && _bundles.isEmpty) {
      _loadProgramsAndBundles();
    }
  }

  Map<String, dynamic> _argumentsToTrainerMap(dynamic args) {
    if (args is Map) {
      final m = Map<String, dynamic>.from(args);
      if (m['_id'] != null && (m['id'] == null || m['id'].toString().isEmpty)) {
        m['id'] = m['_id'];
      }
      if (m['role'] == null) {
        for (final nestedKey in ['trainer', 'user', 'creator']) {
          final nested = m[nestedKey];
          if (nested is Map && nested['role'] != null) {
            m['role'] = nested['role'];
            break;
          }
        }
      }
      return m;
    }
    return Map<String, dynamic>.from(_getMockTrainerData());
  }

  String? _extractMongoUserId(dynamic args) {
    // Support navigation via:
    // - Get.toNamed(..., arguments: { userId / id / _id / trainerId })
    // - Maps that nest the user under trainer / user / creator (e.g. program cards)
    // - named params (e.g. /trainer/:id) via Get.parameters
    final candidates = <String>[];

    void add(String? s) {
      final t = s?.toString().trim() ?? '';
      if (t.isNotEmpty) candidates.add(t);
    }

    if (args is Map) {
      final m = Map<String, dynamic>.from(args);
      for (final k in ['userId', 'trainerId', '_id', 'id']) {
        add(m[k]?.toString());
      }
      final apiProg = m['_apiProgram'];
      if (apiProg is Map) {
        final tr = apiProg['trainer'];
        if (tr is Map) {
          final tm = Map<String, dynamic>.from(tr);
          for (final k in ['_id', 'id', 'userId']) {
            add(tm[k]?.toString());
          }
        }
      }
      for (final nestedKey in ['trainer', 'user', 'creator']) {
        final nested = m[nestedKey];
        if (nested is Map) {
          final nm = Map<String, dynamic>.from(nested);
          for (final k in ['_id', 'id', 'userId']) {
            add(nm[k]?.toString());
          }
        }
      }
    }

    for (final k in ['userId', 'id', '_id', 'trainerId']) {
      add(Get.parameters[k]);
    }

    for (final v in candidates) {
      if (_mongoIdRe.hasMatch(v)) return v;
    }
    return null;
  }

  String? _currentUserIdOrNull() => _storageService.getUserId()?.trim();

  bool get _showFollowButton => _mongoUserId != null && _currentUserIdOrNull() != null && _mongoUserId != _currentUserIdOrNull();

  String get _displayName => (trainer['name'] ?? trainer['fullName'] ?? 'Trainer').toString();

  String get _displayBio => (trainer['bio'] ?? '').toString();

  String? get _avatarNetworkUrl {
    final u = trainer['avatarUrl'] ?? trainer['profilePictureUrl'];
    if (u == null) return null;
    final s = u.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// `GET /user/profiles/:userId/details` plus posts; runs when this screen is opened (post-frame).
  Future<void> _loadProfileFromApi() async {
    final id = _mongoUserId;
    if (id == null) {
      if (mounted) {
        setState(() {
          _loadError = 'Missing trainer id. Open this screen with a valid user id (e.g. from a program card).';
        });
      }
      return;
    }
    setState(() {
      _bootstrapLoading = true;
      _loadError = null;
    });
    try {
      final detailRaw = await _trainerRepo.getProfileDetailsRepo(id);
      if (mounted) {
        setState(() => _applyDetailsResponse(detailRaw));
        _ensureTabControllerMatchesRole();
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
    try {
      final postsRaw = await _trainerRepo.getProfilePostsRepo(id);
      if (mounted) {
        setState(() {
          _posts = _parsePostsResponse(postsRaw);
        });
      }
    } catch (_) {
      /* grid can stay empty */
    }
    if (mounted) setState(() => _bootstrapLoading = false);
  }

  /// Reloads `GET /user/profiles/:userId/details` only (counts, follow state) — e.g. after follow/unfollow.
  Future<void> _refreshProfileDetails() async {
    final id = _mongoUserId;
    if (id == null || !mounted) return;
    try {
      final detailRaw = await _trainerRepo.getProfileDetailsRepo(id);
      if (mounted) setState(() => _applyDetailsResponse(detailRaw));
    } catch (_) {
      /* keep existing counts on refresh failure */
    }
  }

  Future<void> _loadProgramsAndBundles() async {
    final id = _mongoUserId;
    if (id == null) return;
    if (!mounted) return;
    setState(() {
      _programsTabLoading = true;
      _programsLoadError = null;
      _bundlesLoadError = null;
    });
    try {
      final raw = await _trainerRepo.getProfileProgramsRepo(id);
      if (mounted) {
        setState(() {
          _programs = _parseProgramsList(raw, trainerName: _displayName);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _programsLoadError = e.toString());
    }
    try {
      final rawB = await _trainerRepo.getProfileBundlesRepo(id);
      if (mounted) {
        setState(() {
          _bundles = _parseBundlesList(rawB);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _bundlesLoadError = e.toString());
    }
    if (mounted) setState(() => _programsTabLoading = false);
  }

  void _applyDetailsResponse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return;
    final data = raw['data'];
    if (data is! Map<String, dynamic>) return;
    final user = data['user'];
    if (user is! Map<String, dynamic>) return;

    final profile = user['profile'] is Map<String, dynamic> ? user['profile'] as Map<String, dynamic> : <String, dynamic>{};
    final pic = profile['profilePicture'];
    String? picUrl;
    if (pic is Map<String, dynamic>) {
      picUrl = pic['url']?.toString();
    }

    final name = (profile['fullName'] ?? user['email'] ?? _displayName).toString();
    final bio = (profile['bio'] ?? trainer['bio'] ?? '').toString();
    if (bio != _displayBio) _bioExpanded = false;

    trainer = {
      ...trainer,
      '_id': user['_id']?.toString(),
      'id': user['_id']?.toString() ?? trainer['id'],
      'name': name,
      'fullName': name,
      'bio': bio,
      'email': user['email']?.toString(),
      'avatarUrl': picUrl,
      'profilePictureUrl': picUrl,
      'postCount': user['postCount'],
      'followersCount': user['followersCount'],
      'followingCount': user['followingCount'],
      'programCount': user['programCount'],
      'bundleCount': user['bundleCount'],
      'role': user['role']?.toString() ?? trainer['role'],
    };

    _isFollowedByMe = user['isFollowedByMe'] == true || user['isFollowing'] == true || data['isFollowing'] == true;
  }

  /// Recreates [TabController] when API reveals Customer vs Trainer (length 1 vs 3).
  void _ensureTabControllerMatchesRole() {
    if (!mounted) return;
    final want = _tabLengthForRole();
    if (_tabController.length == want) return;
    final prevIndex = _tabController.index;
    _tabController.removeListener(_onProgramsTabShow);
    _tabController.dispose();
    final initialIndex = want == 3 ? prevIndex.clamp(0, 2) : 0;
    _tabController = TabController(length: want, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(_onProgramsTabShow);
    setState(() {});
  }

  List<Map<String, dynamic>> _parsePostsResponse(dynamic raw) {
    final data = raw is Map ? raw['data'] : null;
    if (data is! Map) return [];

    List? list;
    for (final key in ['feeds', 'posts', 'items', 'data']) {
      final v = data[key];
      if (v is List) {
        list = v;
        break;
      }
      // Paginated shape: data.posts.feeds (GET /user/profiles/:id/posts)
      if (v is Map) {
        for (final innerKey in ['feeds', 'posts', 'items', 'list']) {
          final inner = v[innerKey];
          if (inner is List) {
            list = inner;
            break;
          }
        }
        if (list != null) break;
      }
    }
    if (list == null) return [];

    return list
        .map((e) {
          if (e is! Map) return <String, dynamic>{};
          final m = Map<String, dynamic>.from(e);
          try {
            return mapApiFeedDocumentToUiPost(m);
          } catch (_) {
            final id = (m['_id'] ?? m['id'])?.toString() ?? '';
            final thumb = _firstUrlFromMap(m, const ['thumbnail', 'cover', 'image', 'poster']);
            final videoHint = m['video'] != null || m['mediaType']?.toString().toLowerCase().contains('video') == true;
            return <String, dynamic>{'id': id, 'thumbnail': thumb, 'title': m['title'], 'isVideo': videoHint};
          }
        })
        .where((p) => (p['id'] ?? '').toString().isNotEmpty)
        .toList();
  }

  String _firstUrlFromMap(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.startsWith('http')) return v;
      if (v is Map && v['url'] is String) return v['url'] as String;
    }
    final video = m['video'];
    if (video is Map) {
      for (final k in ['thumbnail', 'poster', 'url']) {
        final u = video[k];
        if (u is String && u.startsWith('http')) return u;
        if (u is Map && u['url'] is String && (u['url'] as String).trim().startsWith('http')) {
          return (u['url'] as String).trim();
        }
      }
    }
    return '';
  }

  double _effectivePrice(Map<String, dynamic> m) {
    final price = (m['price'] is num) ? (m['price'] as num).toDouble() : double.tryParse(m['price']?.toString() ?? '') ?? 0;
    final disc = (m['discount'] is num) ? (m['discount'] as num).toDouble() : double.tryParse(m['discount']?.toString() ?? '') ?? 0;
    if (disc <= 0) return price;
    if (disc < 1) return price * (1 - disc);
    return price * (1 - disc / 100);
  }

  Map<String, dynamic> _mapProgramItemToCard(Map<String, dynamic> m, {required String trainerName}) {
    final promo = m['promoMedia'];
    String? imageUrl;
    if (promo is Map<String, dynamic>) {
      imageUrl = promo['url']?.toString();
    }
    final id = (m['_id'] ?? m['id'])?.toString() ?? '';
    return {
      '_id': id,
      'id': id,
      'title': (m['title'] ?? 'Program').toString(),
      'description': (m['description'] ?? '').toString(),
      'trainer': trainerName,
      'price': _effectivePrice(m),
      'discount': m['discount'],
      'imageUrl': imageUrl,
      // Do not set a fake enrollment-like status; [ProgramDetailScreen] uses flags + enrollment object only.
      if (m['status'] != null) 'status': m['status'],
    };
  }

  Map<String, dynamic> _mapBundleItemToCard(Map<String, dynamic> m) {
    final promo = m['promoMedia'];
    String? imageUrl;
    if (promo is Map<String, dynamic>) {
      imageUrl = promo['url']?.toString();
    }
    final id = (m['_id'] ?? m['id'])?.toString() ?? '';
    return {'_id': id, 'id': id, 'title': (m['title'] ?? m['name'] ?? 'Bundle').toString(), 'price': _effectivePrice(m), 'imageUrl': imageUrl ?? m['imageUrl']?.toString()};
  }

  List<Map<String, dynamic>> _parseProgramsList(dynamic raw, {required String trainerName}) {
    final data = raw is Map ? raw['data'] : null;
    if (data is! Map) return [];
    final block = data['programs'];
    List? list;
    if (block is Map && block['programs'] is List) {
      list = block['programs'] as List;
    } else if (block is List) {
      list = block;
    }
    if (list == null) return [];
    return list
        .whereType<Map>()
        .map((e) => _mapProgramItemToCard(Map<String, dynamic>.from(e), trainerName: trainerName))
        .where((e) => (e['id'] ?? '').toString().isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _parseBundlesList(dynamic raw) {
    final data = raw is Map ? raw['data'] : null;
    if (data is! Map) return [];
    final block = data['bundles'];
    List? list;
    if (block is Map && block['bundles'] is List) {
      list = block['bundles'] as List;
    } else if (block is List) {
      list = block;
    }
    if (list == null) return [];
    return list.whereType<Map>().map((e) => _mapBundleItemToCard(Map<String, dynamic>.from(e))).where((e) => (e['id'] ?? '').toString().isNotEmpty).toList();
  }

  Future<void> _onFollowPressed() async {
    final id = _mongoUserId;
    if (id == null || _followActionLoading) return;
    setState(() => _followActionLoading = true);
    final was = _isFollowedByMe;
    try {
      final isFollowing = was ? await _trainerRepo.unfollowUserRepo(id) : await _trainerRepo.followUserRepo(id);
      if (!mounted) return;
      setState(() => _isFollowedByMe = isFollowing);
      await _refreshProfileDetails();
      if (!mounted) return;
      Get.snackbar(
        isFollowing ? 'Following' : 'Unfollowed',
        isFollowing ? 'You are now following $_displayName' : 'You unfollowed $_displayName',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isFollowedByMe = was);
        Get.snackbar('Could not update', e.toString(), snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      if (mounted) setState(() => _followActionLoading = false);
    }
  }

  void _onMessagePressed() {
    final id = _mongoUserId ?? trainer['id']?.toString().trim();
    if (id == null || id.isEmpty) return;
    Get.toNamed(AppRoutes.chatRoom, arguments: <String, dynamic>{'trainerId': id, 'trainerName': _displayName});
  }

  Widget _buildFollowButton({bool compact = false}) {
    // Set a fixed width for both buttons
    final buttonWidth = 110.0;
    return SizedBox(
      width: buttonWidth,
      child: TextButton(
        onPressed: _followActionLoading ? null : _onFollowPressed,
        style: TextButton.styleFrom(
          backgroundColor: _isFollowedByMe ? AppColors.accent : AppColors.accent,
          foregroundColor: _isFollowedByMe ? AppColors.onSurface : AppColors.onAccent,
          padding: EdgeInsets.symmetric(horizontal: 0, vertical: 5),
          minimumSize: Size(buttonWidth, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: _followActionLoading
            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _isFollowedByMe ? AppColors.accent : AppColors.onAccent))
            : Text(
                _isFollowedByMe ? 'Unfollow' : 'Follow',
                style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildMessageButton({bool compact = false}) {
    // Set the same fixed width as the follow button
    final buttonWidth = 110.0;
    return SizedBox(
      width: buttonWidth,
      child: TextButton.icon(
        onPressed: _onMessagePressed,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.accent,
          padding: EdgeInsets.symmetric(horizontal: 0, vertical: 5),
          minimumSize: Size(buttonWidth, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.accent),
          ),
        ),
        icon: Icon(Icons.chat_bubble_outline_rounded, size: compact ? 16 : 18, color: AppColors.accent),
        label: Text(
          'Message',
          style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.accent),
        ),
      ),
    );
  }

  TextStyle _bioTextStyle() {
    return AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface.withOpacity(0.8), fontSize: 14, height: 1.4);
  }

  Widget _buildExpandableBio() {
    final bio = _displayBio.trim();
    if (bio.isEmpty) return const SizedBox.shrink();

    final textStyle = _bioTextStyle();
    final actionStyle = textStyle.copyWith(fontWeight: FontWeight.w700, color: AppColors.accent);

    return LayoutBuilder(
      builder: (context, constraints) {
        final overflowPainter = TextPainter(
          text: TextSpan(text: bio, style: textStyle),
          maxLines: _bioCollapsedMaxLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);

        final canExpand = overflowPainter.didExceedMaxLines;
        final showToggle = canExpand || _bioExpanded;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bio, maxLines: _bioExpanded ? null : _bioCollapsedMaxLines, overflow: _bioExpanded ? TextOverflow.visible : TextOverflow.ellipsis, style: textStyle),
            if (showToggle)
              GestureDetector(
                onTap: () => setState(() => _bioExpanded = !_bioExpanded),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_bioExpanded ? 'View less' : 'View more', style: actionStyle),
                ),
              ),
          ],
        );
      },
    );
  }

  int _statInt(dynamic key) {
    final v = trainer[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  void dispose() {
    _tabController.removeListener(_onProgramsTabShow);
    _tabController.dispose();
    super.dispose();
  }

  /// Pull-to-refresh for tab bodies; [AlwaysScrollableScrollPhysics] keeps overscroll when content is short.
  Widget _wrapTabRefresh({required Future<void> Function() onRefresh, required Widget child}) {
    return RefreshIndicator.adaptive(
      color: AppColors.accentVariant,
      backgroundColor: AppColors.background,
      displacement: 40,
      strokeWidth: 2.5,
      triggerMode: RefreshIndicatorTriggerMode.anywhere,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (Get.key.currentState?.canPop() ?? false) {
              Get.back();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primaryGrayLight.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.accent, size: 18),
          ),
        ),
        title: Text(_displayName, style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
        centerTitle: true,

        bottom: _showProgramsTrainingTabs
            ? PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: Container(
                  color: AppColors.background,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.accent,
                    indicatorWeight: 3,
                    labelColor: AppColors.accent,
                    unselectedLabelColor: const Color.fromARGB(179, 61, 61, 63),
                    labelStyle: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                    unselectedLabelStyle: AppTextStyles.titleSmall,
                    tabs: const [
                      Tab(text: 'Profile'),
                      Tab(text: 'Programs'),
                      Tab(text: 'Training'),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: TabBarView(controller: _tabController, children: _showProgramsTrainingTabs ? [_buildProfileTab(), _buildProgramsTab(), _buildTrainingTab()] : [_buildProfileTab()]),
    );
  }

  // Profile Tab
  Widget _buildProfileTab() {
    final postsCount = _statInt('postCount');
    final followers = _statInt('followersCount');
    final following = _statInt('followingCount');

    return _wrapTabRefresh(
      onRefresh: _loadProfileFromApi,
      child: Column(
        children: [
          if (_bootstrapLoading) const LinearProgressIndicator(minHeight: 2),
          if (_loadError != null && _mongoUserId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(_loadError!, style: AppTextStyles.bodySmall.copyWith(color: Colors.red.shade700)),
            ),
          const SizedBox(height: 20),
          // Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent, width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.surface,
                        backgroundImage: (_avatarNetworkUrl != null && _avatarNetworkUrl!.startsWith('http'))
                            ? NetworkImage(ImageUrlSanitizer.asHttpUrlOrFallback(_avatarNetworkUrl!))
                            : null,
                        child: (_avatarNetworkUrl == null || !_avatarNetworkUrl!.startsWith('http')) ? Icon(Icons.person, size: 40, color: AppColors.accent) : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                  ],
                ),
                const SizedBox(width: 20),
                _buildStatColumn(_mongoUserId != null ? '$postsCount' : '…', 'Posts'),
                _buildStatColumn(_mongoUserId != null ? '$followers' : '…', 'Followers'),
                _buildStatColumn(_mongoUserId != null ? '$following' : '…', 'Following'),
              ],
            ),
          ),
          // Bio Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        _displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold, fontSize: 17.sp),
                      ),
                    ),
                    if (_showFollowButton) ...[const SizedBox(width: 2), _buildFollowButton(compact: true), const SizedBox(width: 8), _buildMessageButton(compact: true)],
                  ],
                ),
                if (_displayBio.trim().isNotEmpty) ...[const SizedBox(height: 8), _buildExpandableBio()],
              ],
            ),
          ),

          const SizedBox(height: 24),
          // Posts Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Posts',
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildPostsGrid(),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: const Color.fromARGB(255, 55, 56, 58))),
      ],
    );
  }

  Widget _buildPostsGrid() {
    final posts = _mongoUserId != null ? _posts : _getMockPosts();
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(_mongoUserId != null ? 'No posts yet' : 'Loading…', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4, childAspectRatio: 1),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final id = (post['id'] ?? post['_id'])?.toString() ?? '';
        final thumbRaw = post['thumbnail']?.toString() ?? '';

        void openPost() {
          if (_mongoUserId != null && id.isNotEmpty) {
            Get.toNamed(AppRoutes.feedSingleReel, arguments: {'feedId': id});
          } else {
            Get.toNamed(AppRoutes.postDetail, arguments: post);
          }
        }

        return GestureDetector(
          onTap: openPost,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: thumbRaw.startsWith('http')
                    ? Image.network(
                        ImageUrlSanitizer.asHttpUrlOrFallback(thumbRaw),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.accent, AppColors.accent.withOpacity(0.6)]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.accent, AppColors.accent.withOpacity(0.6)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
              ),
              if (post['isVideo'] == true)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                    child: Icon(Icons.play_arrow, color: Colors.white.withOpacity(0.9), size: 28),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Programs Tab
  Widget _buildProgramsTab() {
    final id = _mongoUserId;
    if (id != null && _programsTabLoading && _programs.isEmpty && _bundles.isEmpty) {
      return _wrapTabRefresh(
        onRefresh: _loadProgramsAndBundles,
        child: const Center(
          child: Padding(padding: EdgeInsets.only(top: 48), child: CircularProgressIndicator()),
        ),
      );
    }

    final programsToShow = id != null ? _programs : _getMockPrograms('all');
    final bundlesToShow = id != null ? _bundles : _getMockBundles();

    return _wrapTabRefresh(
      onRefresh: () async {
        if (id != null) await _loadProgramsAndBundles();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          if (_programsLoadError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_programsLoadError!, style: AppTextStyles.bodySmall.copyWith(color: Colors.red.shade700)),
            ),
          // Bundles Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bundles',
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                ),
                if (_bundlesLoadError != null) Text(_bundlesLoadError!, style: AppTextStyles.bodySmall.copyWith(color: Colors.red.shade700)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200.h,
                  child: bundlesToShow.isEmpty
                      ? Center(
                          child: Text(id != null ? 'No bundles listed' : 'No bundles', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: bundlesToShow.length,
                          itemBuilder: (context, index) {
                            return _buildBundleCard(bundlesToShow[index]);
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Programs Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Programs',
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (programsToShow.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(id != null ? 'No programs listed' : '', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                    ),
                  )
                else
                  ...programsToShow.map((program) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildProgramCardVertical(program))),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBundleCard(Map<String, dynamic> bundle) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.bundleDetail, arguments: bundle),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  ImageUrlSanitizer.asHttpUrlOrFallback(bundle['imageUrl']?.toString()),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentVariant])),
                    child: const Center(child: Icon(Icons.fitness_center, size: 40, color: Colors.white)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bundle['title'],
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${bundle['price']}',
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramCardVertical(Map<String, dynamic> program) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.programDetail, arguments: program),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                ImageUrlSanitizer.asHttpUrlOrFallback(program['imageUrl']?.toString()),
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentVariant])),
                  child: const Center(child: Icon(Icons.fitness_center, size: 30, color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program['title'],
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(program['trainer'] ?? 'Trainer', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  const SizedBox(height: 8),
                  Text(
                    '\$${program['price']}',
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Training Tab
  Widget _buildTrainingTab() {
    return _wrapTabRefresh(
      onRefresh: _loadProfileFromApi,
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentVariant]),
                      boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Get.toNamed(AppRoutes.chatRoom, arguments: {'trainerId': trainer['id'], 'trainerName': trainer['name']});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.chat_bubble_rounded, size: 22),
                      label: Text(
                        'Message',
                        style: AppTextStyles.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accent, width: 2),
                      color: AppColors.surface,
                      boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Get.snackbar(
                          'Book Session',
                          'Hourly Rate: \$${trainer['hourlyRate']}',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppColors.accent.withOpacity(0.1),
                          colorText: AppColors.accent,
                          duration: const Duration(seconds: 2),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide.none,
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.accent),
                      label: Text(
                        '\$${trainer['hourlyRate']}/hr',
                        style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Stats Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildTrainingStatCard(Icons.star_rounded, '${trainer['rating']}', '${trainer['totalReviews']} reviews', AppColors.accent)),
                const SizedBox(width: 12),
                Expanded(child: _buildTrainingStatCard(Icons.people_rounded, '${trainer['students']}', 'Students', AppColors.accent)),
                const SizedBox(width: 12),
                Expanded(child: _buildTrainingStatCard(Icons.trending_up_rounded, '${trainer['yearsOfExperience']}', 'Years', AppColors.accent)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Premium Access Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentVariant], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: Icon(Icons.workspace_premium_rounded, color: AppColors.upcoming, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Premium Access',
                                    style: AppTextStyles.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Get direct contact details', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildPremiumBenefit(Icons.phone_rounded, 'Direct phone number'),
                        const SizedBox(height: 12),
                        _buildPremiumBenefit(Icons.email_rounded, 'Personal email address'),
                        const SizedBox(height: 12),
                        _buildPremiumBenefit(Icons.location_on_rounded, 'Training location details'),
                        const SizedBox(height: 12),
                        _buildPremiumBenefit(Icons.schedule_rounded, 'Priority booking access'),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6))],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showSubscriptionDialog(context, trainer),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.favorite_rounded, color: AppColors.accent, size: 24),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Subscribe for \$9.99/month',
                                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Location Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.2), AppColors.accentVariant.withOpacity(0.1)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.location_on_rounded, color: AppColors.accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Training Location',
                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, color: AppColors.accent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              trainer['location'] ?? '123 Fitness Street, Gym City, GC 12345',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentVariant]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // Open message with location info for in-person training booking
                              Get.toNamed(
                                AppRoutes.chatRoom,
                                arguments: {
                                  'trainerId': trainer['id'],
                                  'trainerName': trainer['name'],
                                  'initialMessage':
                                      'Hi! I\'m interested in booking an in-person training session. Can you tell me more about availability at ${trainer['location'] ?? 'your location'}?',
                                },
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.message_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Message About In-Person Training',
                                    style: AppTextStyles.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // About Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.2), AppColors.accentVariant.withOpacity(0.1)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.person_outline_rounded, color: AppColors.accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'About',
                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
                  ),
                  child: Text(
                    _displayBio.isEmpty ? '—' : _displayBio,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface.withOpacity(0.8), height: 1.7, letterSpacing: 0.3),
                  ),
                ),
              ],
            ),
          ),
          // Certifications Section (if available)
          if (trainer['certified'] == true && trainer['certifications'] != null) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.completed.withOpacity(0.2), AppColors.completed.withOpacity(0.1)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.verified_rounded, color: AppColors.completed, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Certifications',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...(trainer['certifications'] as List? ?? []).map<Widget>(
                    (cert) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.completed.withOpacity(0.3)),
                        boxShadow: [BoxShadow(color: AppColors.completed.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.completed.withOpacity(0.1), shape: BoxShape.circle),
                            child: Icon(Icons.workspace_premium_rounded, color: AppColors.completed, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              cert.toString(),
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                            ),
                          ),
                          Icon(Icons.check_circle_rounded, color: AppColors.completed, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTrainingStatCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 24),
          ),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: const Color.fromARGB(255, 54, 56, 59), fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBenefit(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ),
        Icon(Icons.check_circle_rounded, color: AppColors.upcoming, size: 20),
      ],
    );
  }

  static void _showSubscriptionDialog(BuildContext context, Map<String, dynamic> trainer) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentVariant], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: Icon(Icons.workspace_premium_rounded, color: AppColors.upcoming, size: 48),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Premium Subscription',
                      style: AppTextStyles.headlineSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get direct access to ${trainer['name']}',
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withOpacity(0.9)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$',
                          style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '9.99',
                          style: AppTextStyles.headlineLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 48),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('/month', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDialogBenefit('Direct phone number access'),
                    const SizedBox(height: 12),
                    _buildDialogBenefit('Personal email address'),
                    const SizedBox(height: 12),
                    _buildDialogBenefit('Training location details'),
                    const SizedBox(height: 12),
                    _buildDialogBenefit('Priority booking'),
                    const SizedBox(height: 12),
                    _buildDialogBenefit('Exclusive content access'),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.primaryGray.withOpacity(0.3)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppTextStyles.titleSmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentVariant]),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _showContactDetails(context, trainer);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                'Subscribe Now',
                                style: AppTextStyles.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildDialogBenefit(String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.completed.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.check_circle_rounded, color: AppColors.completed, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground)),
        ),
      ],
    );
  }

  static void _showContactDetails(BuildContext context, Map<String, dynamic> trainer) {
    Get.snackbar(
      'Subscription Activated! 🎉',
      'You now have access to ${trainer['name']}\'s contact details',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.completed,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentVariant]),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.contact_phone_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact Details',
                            style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                          ),
                          Text(trainer['name'], style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildContactCard(Icons.phone_rounded, 'Phone', '+1 (555) 123-4567', AppColors.accent),
                const SizedBox(height: 12),
                _buildContactCard(Icons.email_rounded, 'Email', '${trainer['name'].toString().toLowerCase().replaceAll(' ', '.')}@fitness.com', AppColors.accentVariant),
                const SizedBox(height: 12),
                _buildContactCard(Icons.location_on_rounded, 'Location', '123 Fitness Street, Gym City, GC 12345', AppColors.completed),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Close',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  static Widget _buildContactCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy_rounded, color: color),
            onPressed: () {
              Get.snackbar(
                'Copied!',
                '$label copied to clipboard',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: color.withOpacity(0.1),
                colorText: color,
                duration: const Duration(seconds: 2),
                margin: const EdgeInsets.all(16),
                borderRadius: 12,
              );
            },
          ),
        ],
      ),
    );
  }

  // Mock data
  static Map<String, dynamic> _getMockTrainerData() {
    return {
      'id': '1',
      'name': 'Sarah Johnson',
      'initials': 'SJ',
      'bio':
          'Certified personal trainer with over 8 years of experience helping clients achieve their fitness goals. Specializing in strength training, weight loss, and functional fitness. Passionate about creating sustainable lifestyle changes.',
      'specialties': ['Strength Training', 'Weight Loss', 'Functional Fitness', 'Nutrition Coaching'],
      'yearsOfExperience': 8,
      'certified': true,
      'certifications': ['NASM Certified Personal Trainer', 'Precision Nutrition Level 1', 'CrossFit Level 2 Trainer'],
      'hourlyRate': 75.0,
      'rating': 4.8,
      'totalReviews': 127,
      'students': 1250,
      'activePrograms': 5,
      'completedPrograms': 12,
      'totalPrograms': 17,
      'location': '123 Fitness Street, Gym City, GC 12345',
      'role': 'Trainer',
    };
  }

  List<Map<String, dynamic>> _getMockPosts() {
    return [
      {'id': '1', 'isVideo': true, 'thumbnail': 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=400'},
      {'id': '2', 'isVideo': false, 'thumbnail': 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400'},
      {'id': '3', 'isVideo': true, 'thumbnail': 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400'},
      {'id': '4', 'isVideo': false, 'thumbnail': 'https://images.unsplash.com/photo-1532029837206-abbe2b7620e3?w=400'},
      {'id': '5', 'isVideo': true, 'thumbnail': 'https://images.unsplash.com/photo-1549576490-b0b4831ef60a?w=400'},
      {'id': '6', 'isVideo': false, 'thumbnail': 'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=400'},
    ];
  }

  List<Map<String, dynamic>> _getMockBundles() {
    return [
      {'id': '1', 'title': 'Strength & Conditioning Bundle', 'price': 49.99, 'imageUrl': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop'},
      {'id': '2', 'title': 'Complete Fitness Package', 'price': 79.99, 'imageUrl': 'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=400&h=300&fit=crop'},
    ];
  }

  static List<Map<String, dynamic>> _getMockPrograms(String type) {
    final allPrograms = [
      {
        'title': 'Complete Strength Program',
        'description': 'Build muscle and strength with this comprehensive 12-week program',
        'trainer': 'Sarah Johnson',
        'price': 49.99,
        'duration': '12 weeks',
        'students': 1250,
        'rating': 4.8,
        'category': 'Strength',
        'certified': true,
        'imageUrl': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop',
        'status': 'active',
      },
      {
        'title': 'Weight Loss Challenge',
        'description': 'Transform your body with this intensive 8-week weight loss program',
        'trainer': 'Sarah Johnson',
        'price': 39.99,
        'duration': '8 weeks',
        'students': 890,
        'rating': 4.9,
        'category': 'Weight Loss',
        'certified': true,
        'imageUrl': 'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=400&h=300&fit=crop',
        'status': 'active',
      },
      {
        'title': 'Functional Fitness',
        'description': 'Improve everyday movement and build practical strength',
        'trainer': 'Sarah Johnson',
        'price': 44.99,
        'duration': '10 weeks',
        'students': 650,
        'rating': 4.7,
        'category': 'Functional',
        'certified': true,
        'imageUrl': 'https://images.unsplash.com/photo-1549060279-7e168fcee0c2?w=400&h=300&fit=crop',
        'status': 'active',
      },
    ];

    if (type == 'active') {
      return allPrograms.where((p) => p['status'] == 'active').toList();
    } else if (type == 'completed') {
      return allPrograms.where((p) => p['status'] == 'completed').toList();
    }
    return allPrograms;
  }
}
