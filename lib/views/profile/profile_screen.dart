import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/controllers/feed_publish_controller.dart';
import 'package:get_right/controllers/feed_video_upload_controller.dart';
import 'package:get_right/models/customer_profile_dto.dart';
import 'package:get_right/models/feed_category_model.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/repo/feed_repo.dart';
import 'package:get_right/repo/trainer_profile_repo.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/customer_profile_enums.dart';
import 'package:get_right/utils/feed_post_mapper.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:get_right/views/home/dashboard_screen.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:get_right/models/feed_multipart_init_model.dart';
import 'package:video_player/video_player.dart';

List<String> _parseFeedTagsForApi(String raw) {
  return raw.split(RegExp(r'\s+')).map((t) => t.replaceFirst(RegExp(r'^#+'), '').trim()).where((t) => t.isNotEmpty).toList();
}

String _normalizeFeedPostStatus(String? raw) {
  final s = (raw ?? '').trim().toLowerCase();
  if (s == 'published') return 'Published';
  return 'Draft';
}

/// Profile screen visual tokens (cream + forest green mockup).
const Color _kProfileCream = Color(0xFFF9FAF0);
const Color _kProfileForestGreen = Color(0xFF2D4635);
const Color _kRecordPink = Color(0xFFF4CCE9);
const Color _kRecordBlue = Color(0xFFB6D7E8);
const Color _kStatPostsOrange = Color(0xFFEA580C);
const Color _kStatFollowersBlue = Color(0xFF2563EB);
const Color _kStatFollowingGreen = Color(0xFF16A34A);

/// Personal Record model
class PersonalRecord {
  final String id;
  final String liftName;
  final String value;
  final String unit;
  final DateTime date;
  final bool displayPublicly;

  PersonalRecord({required this.id, required this.liftName, required this.value, required this.unit, required this.date, this.displayPublicly = true});

  PersonalRecord copyWith({String? id, String? liftName, String? value, String? unit, DateTime? date, bool? displayPublicly}) {
    return PersonalRecord(
      id: id ?? this.id,
      liftName: liftName ?? this.liftName,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      date: date ?? this.date,
      displayPublicly: displayPublicly ?? this.displayPublicly,
    );
  }
}

/// Profile screen - Social media style profile
class ProfileScreen extends StatefulWidget {
  final bool hideAppBar;

  const ProfileScreen({super.key, this.hideAppBar = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<PersonalRecord> _personalRecords = [];
  final FeedRepository _feedRepo = FeedRepository();
  final TrainerProfileRepository _profileRepo = TrainerProfileRepository();
  List<Map<String, dynamic>> _myFeedPosts = [];
  bool _myFeedsLoading = true;
  String? _myFeedsError;
  int? _postCount;
  int? _followersCount;
  int? _followingCount;
  Worker? _profileTabWorker;
  bool _lazyBootstrapped = false;

  @override
  void initState() {
    super.initState();
    // IMPORTANT: HomeScreen uses IndexedStack, so initState runs right after login.
    // We only want to hit profile API when the user actually opens the Profile tab.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Get.isRegistered<HomeNavigationController>()) {
        final nav = Get.find<HomeNavigationController>();
        _profileTabWorker = ever<int>(nav.currentIndexRx, (idx) {
          if (!mounted) return;
          if (idx == 4) _bootstrapIfNeeded();
        });
        if (nav.currentIndex == 4) {
          _bootstrapIfNeeded();
        }
      } else {
        // Fallback: if ProfileScreen is pushed as a route (not via bottom tabs), load immediately.
        _bootstrapIfNeeded();
      }
    });
    _personalRecords = [
      PersonalRecord(id: '1', liftName: 'Bench Press', value: '315', unit: 'lbs', date: DateTime(2024, 12, 12), displayPublicly: true),
      PersonalRecord(id: '2', liftName: 'Squat', value: '405', unit: 'lbs', date: DateTime(2024, 12, 12), displayPublicly: true),
    ];
  }

  void _bootstrapIfNeeded() {
    if (_lazyBootstrapped) return;
    _lazyBootstrapped = true;
    if (Get.isRegistered<AuthController>()) {
      Get.find<AuthController>().fetchCustomerProfile();
    }
    _fetchProfileStats();
    _fetchMyFeeds();
  }

  @override
  void dispose() {
    _profileTabWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kProfileCream,
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              backgroundColor: _kProfileCream,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: const IconThemeData(color: _kProfileForestGreen),
              leading: Obx(() {
                final notificationController = Get.find<NotificationController>();
                final unreadCount = notificationController.unreadCount;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: ColorFiltered(
                        colorFilter: const ColorFilter.mode(_kProfileForestGreen, BlendMode.srcIn),
                        child: Image.asset('assets/images/humburger.png', width: 25.w),
                      ),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ).paddingOnly(left: 10),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.0),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              }),
              title: Text(
                'Profile',
                style: AppTextStyles.titleLarge.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.w700),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: _kProfileForestGreen),
                  onPressed: () => Get.toNamed(AppRoutes.settings),
                ),
              ],
            ),
      body: GetBuilder<AuthController>(
        builder: (auth) {
          if (auth.customerProfileLoading && auth.customerProfile == null) {
            return const Center(child: CircularProgressIndicator(color: _kProfileForestGreen));
          }
          if (auth.customerProfileError != null && auth.customerProfile == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      auth.customerProfileError!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(color: _kProfileForestGreen.withOpacity(0.85)),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => auth.fetchCustomerProfile(),
                      child: Text(
                        'Retry',
                        style: AppTextStyles.bodyMedium.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: _kProfileForestGreen,
            onRefresh: () async {
              if (Get.isRegistered<AuthController>()) {
                await Get.find<AuthController>().fetchCustomerProfile();
              }
              await _fetchProfileStats();
              await _fetchMyFeeds();
            },
            child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: _buildPublicProfile(auth)),
          );
        },
      ),
    );
  }

  String _formatSlugLabel(String slug) {
    final t = slug.trim();
    if (t.isEmpty) return '';
    if (!t.contains('_')) return t;
    return t.split('_').where((s) => s.isNotEmpty).map((s) => '${s[0].toUpperCase()}${s.length > 1 ? s.substring(1).toLowerCase() : ''}').join(' ');
  }

  Widget _buildPublicProfile(AuthController auth) {
    final p = auth.customerProfile;
    var displayName = 'Your profile';
    var email = '';
    String? photoUrl;
    if (p != null) {
      email = p.email;
      photoUrl = p.profilePictureUrl;
      final n = p.fullName?.trim();
      if (n != null && n.isNotEmpty) {
        displayName = n;
      } else if (p.email.isNotEmpty) {
        displayName = p.email.split('@').first;
      }
    }
    var bioLine = p?.bio?.trim();
    if (bioLine != null && bioLine.isEmpty) bioLine = null;

    return Column(
      children: [
        if (auth.customerProfileLoading && auth.customerProfile != null) const LinearProgressIndicator(minHeight: 2, color: _kProfileForestGreen),
        const SizedBox(height: 8),
        // Centered avatar + camera (mockup)
        Center(
          child: SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: _kProfileForestGreen.withOpacity(0.08),
                    child: photoUrl != null && photoUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              photoUrl,
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.person, size: 52, color: _kProfileForestGreen.withOpacity(0.45)),
                            ),
                          )
                        : Icon(Icons.person, size: 52, color: _kProfileForestGreen.withOpacity(0.45)),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: GestureDetector(
                    onTap: () => Get.toNamed(AppRoutes.editProfile),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _kProfileForestGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: _kProfileCream, width: 3),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineSmall.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.w800, fontSize: 22),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(color: _kProfileForestGreen.withOpacity(0.65), fontSize: 14),
                ),
              ],
              if (bioLine != null) ...[
                const SizedBox(height: 8),
                Text(
                  bioLine,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(color: _kProfileForestGreen.withOpacity(0.8), height: 1.35),
                ),
              ],
              if (_profileMetaLine(p).isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _profileMetaLine(p),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(color: _kProfileForestGreen.withOpacity(0.75), fontWeight: FontWeight.w600, height: 1.4),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Stat cards row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(child: _buildStatCard(_formatProfileStat(_postCount), 'Posts', _kStatPostsOrange)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCard(_formatProfileStat(_followersCount), 'Followers', _kStatFollowersBlue, onTap: () => Get.toNamed(AppRoutes.followers))),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCard(_formatProfileStat(_followingCount), 'Following', _kStatFollowingGreen, onTap: () => Get.toNamed(AppRoutes.following))),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Nutrition / records section (label matches mockup)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nutrition (per serving)',
                    style: AppTextStyles.titleMedium.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_note_rounded, color: _kProfileForestGreen, size: 26),
                    onPressed: _showEditPersonalRecordsDialog,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _personalRecords.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
                        border: Border.all(color: _kProfileForestGreen.withOpacity(0.08)),
                      ),
                      child: Center(
                        child: Text(
                          'No personal records yet.\nTap edit to add your records.',
                          style: AppTextStyles.bodyMedium.copyWith(color: _kProfileForestGreen.withOpacity(0.55)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _buildPersonalRecordsGrid(),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Posts Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Posts',
                    style: AppTextStyles.titleMedium.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.w700),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showCreatePostOptions,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _kProfileForestGreen, width: 2),
                        ),
                        child: Icon(Icons.add, color: _kProfileForestGreen, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildPostsGrid(),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  String _profileMetaLine(CustomerProfileDto? profile) {
    if (profile == null) return '';
    final parts = <String>[];
    final pf = profile.primaryFocus?.trim();
    if (pf != null && pf.isNotEmpty) parts.add(_formatSlugLabel(pf));
    final fl = profile.fitnessLevel?.trim();
    if (fl != null && fl.isNotEmpty) parts.add(fl);
    final ex = profile.exerciseFrequency?.trim();
    if (ex != null && ex.isNotEmpty) {
      parts.add(CustomerProfileEnums.exerciseFrequencyDisplayFromApi(ex));
    }
    if (profile.mainGoals.isNotEmpty) {
      parts.add(profile.mainGoals.map(_formatSlugLabel).join(' · '));
    }
    return parts.join(' · ');
  }

  Widget _buildStatCard(String count, String label, Color countColor, {VoidCallback? onTap}) {
    final card = Container(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: AppTextStyles.titleLarge.copyWith(color: countColor, fontWeight: FontWeight.w800, fontSize: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: card),
      );
    }
    return card;
  }

  Widget _buildPersonalRecordsGrid() {
    // Create rows of 2 items
    final rows = <List<PersonalRecord>>[];
    for (int i = 0; i < _personalRecords.length; i += 2) {
      if (i + 1 < _personalRecords.length) {
        rows.add([_personalRecords[i], _personalRecords[i + 1]]);
      } else {
        rows.add([_personalRecords[i]]);
      }
    }

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: EdgeInsets.only(bottom: rows.indexOf(row) < rows.length - 1 ? 12 : 0),
          child: Row(
            children: [
              Expanded(child: _buildPersonalRecordCard(row[0])),
              if (row.length > 1) ...[const SizedBox(width: 12), Expanded(child: _buildPersonalRecordCard(row[1]))],
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _recordCardTint(PersonalRecord record) {
    final n = record.liftName.toLowerCase();
    if (n.contains('bench')) return _kRecordPink;
    if (n.contains('squat')) return _kRecordBlue;
    return _kRecordPink;
  }

  Widget _buildPersonalRecordCard(PersonalRecord record) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final displayValue = record.displayPublicly ? '${record.value} ${record.unit}' : 'Hidden';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _recordCardTint(record), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.liftName,
            style: AppTextStyles.titleSmall.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            displayValue,
            style: AppTextStyles.headlineSmall.copyWith(
              color: record.displayPublicly ? _kProfileForestGreen : _kProfileForestGreen.withOpacity(0.4),
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dateFormat.format(record.date),
            style: AppTextStyles.labelSmall.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String? _resolvedUserId() {
    if (Get.isRegistered<AuthController>()) {
      final id = Get.find<AuthController>().customerProfile?.userId.trim();
      if (id != null && id.isNotEmpty) return id;
    }
    if (Get.isRegistered<StorageService>()) {
      final id = Get.find<StorageService>().getUserId()?.trim();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  static int _statIntFrom(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  void _applyUserStatsFromResponse(dynamic raw) {
    if (raw is! Map) return;
    final data = raw['data'];
    if (data is! Map) return;
    final user = data['user'];
    if (user is! Map) return;
    final u = Map<String, dynamic>.from(user);
    setState(() {
      _postCount = _statIntFrom(u['postCount']);
      _followersCount = _statIntFrom(u['followersCount']);
      _followingCount = _statIntFrom(u['followingCount']);
    });
  }

  String _formatProfileStat(int? value) => value != null ? '$value' : '…';

  /// Loads `postCount`, `followersCount`, `followingCount` from profile API (`data.user`).
  Future<void> _fetchProfileStats() async {
    final id = _resolvedUserId();
    if (id == null) return;
    try {
      final raw = await _profileRepo.getProfileDetailsRepo(id);
      if (!mounted) return;
      _applyUserStatsFromResponse(raw);
    } catch (_) {
      try {
        final raw = await _profileRepo.getProfilePostsRepo(id, page: 1, limit: 1);
        if (!mounted) return;
        _applyUserStatsFromResponse(raw);
      } catch (_) {
        /* keep previous counts or placeholder */
      }
    }
  }

  Future<void> _fetchMyFeeds() async {
    setState(() {
      _myFeedsLoading = true;
      _myFeedsError = null;
    });
    try {
      final raw = await _feedRepo.getMyFeedsRepo(page: 1, limit: 10);
      final data = (raw is Map && raw['data'] is Map) ? Map<String, dynamic>.from(raw['data']) : <String, dynamic>{};
      final feedsRaw = (data['feeds'] is List) ? List.from(data['feeds']) : const [];
      final mapped = feedsRaw.map((e) => _mapMineFeedToGridItem(Map<String, dynamic>.from(e as Map))).where((p) => (p['id'] ?? '').toString().isNotEmpty).toList();

      if (!mounted) return;
      setState(() {
        _myFeedPosts = mapped;
        _myFeedsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _myFeedsError = e.toString();
        _myFeedsLoading = false;
      });
    }
  }

  Map<String, dynamic> _mapMineFeedToGridItem(Map<String, dynamic> m) {
    final id = (m['_id'] ?? '').toString();
    final creator = (m['creator'] is Map) ? Map<String, dynamic>.from(m['creator']) : <String, dynamic>{};
    final profile = (creator['profile'] is Map) ? Map<String, dynamic>.from(creator['profile']) : <String, dynamic>{};
    final fullName = (profile['fullName'] ?? '').toString().trim();
    final creatorName = fullName.isEmpty ? (creator['email'] ?? 'You').toString() : fullName;
    final initials = creatorName.isEmpty ? 'U' : creatorName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();

    final video = (m['video'] is Map) ? Map<String, dynamic>.from(m['video']) : <String, dynamic>{};
    final meta = (video['metadata'] is Map) ? Map<String, dynamic>.from(video['metadata']) : <String, dynamic>{};
    final category = (m['category'] is Map) ? Map<String, dynamic>.from(m['category']) : <String, dynamic>{};
    final categoryName = (category['name'] ?? '').toString();
    final categoryId = (category['_id'] ?? category['id'] ?? '').toString();

    final thumbRaw = extractFeedThumbnailUrl(m, video: video).trim();
    final thumb = ImageUrlSanitizer.asHttpUrlOrNull(thumbRaw) ?? '';
    final videoUrl = extractFeedVideoUrl(m, video) ?? '';
    final isVideo = videoUrl.isNotEmpty;

    final tagsRaw = (m['tags'] is List) ? List.from(m['tags']) : const [];
    final tags = tagsRaw.map((e) {
      final s = e.toString();
      return s.startsWith('#') ? s : '#$s';
    }).toList();

    double? ds = (m['duration'] is num) ? (m['duration'] as num).toDouble() : (meta['duration'] is num ? (meta['duration'] as num).toDouble() : null);
    String? durationLabel;
    if (ds != null) {
      durationLabel = ds >= 60
          ? '${ds ~/ 60}:${(ds % 60).round().toString().padLeft(2, '0')}'
          : ds >= 10
          ? '${ds.round()}s'
          : '${ds.toStringAsFixed(1)}s';
    }

    String timestamp = '';
    final created = m['createdAt']?.toString();
    if (created != null && created.isNotEmpty) {
      try {
        timestamp = DateFormat.yMMMd().add_jm().format(DateTime.parse(created).toLocal());
      } catch (_) {
        timestamp = created;
      }
    }

    final likes = (m['likesCount'] is num) ? (m['likesCount'] as num).toInt() : 0;
    final comments = (m['commentsCount'] is num) ? (m['commentsCount'] as num).toInt() : 0;
    final saves = (m['savesCount'] is num) ? (m['savesCount'] as num).toInt() : 0;
    final shares = (m['sharesCount'] is num) ? (m['sharesCount'] as num).toInt() : 0;

    return <String, dynamic>{
      'id': id,
      'isVideo': isVideo,
      'thumbnail': thumb,
      if (!isVideo && thumb.isNotEmpty) 'imageUrl': thumb,
      'videoUrl': videoUrl,
      'title': (m['title'] ?? '').toString(),
      'description': (m['description'] ?? '').toString(),
      'likes': likes,
      'comments': comments,
      'saves': saves,
      'shares': shares,
      if (durationLabel != null) 'duration': durationLabel,
      'timestamp': timestamp,
      'tags': tags,
      'creator': creatorName,
      'creatorInitials': initials,
      'categoryId': categoryId,
      if (categoryName.isNotEmpty) 'categoryName': categoryName,
      'status': (m['status'] ?? '').toString(),
      'videoProcessingStatus': (m['videoProcessingStatus'] ?? '').toString(),
    };
  }

  Widget _buildPostGridThumbnailPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_kProfileForestGreen.withOpacity(0.35), _kProfileForestGreen.withOpacity(0.15)]),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildPostGridThumbnail(Map<String, dynamic> post) {
    final thumbUrl = ImageUrlSanitizer.asHttpUrlOrNull((post['thumbnail'] ?? '').toString());
    if (thumbUrl == null) {
      return _buildPostGridThumbnailPlaceholder();
    }
    return Image.network(thumbUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _buildPostGridThumbnailPlaceholder());
  }

  Widget _buildPostsGrid() {
    if (_myFeedsLoading && _myFeedPosts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator(color: _kProfileForestGreen)),
      );
    }

    if (_myFeedsError != null && _myFeedPosts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              _myFeedsError!,
              style: AppTextStyles.bodySmall.copyWith(color: _kProfileForestGreen.withOpacity(0.85)),
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: _fetchMyFeeds,
              child: Text(
                'Retry',
                style: AppTextStyles.bodyMedium.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    if (_myFeedPosts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No posts yet',
            style: AppTextStyles.titleSmall.copyWith(color: _kProfileForestGreen.withOpacity(0.65), fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    final posts = _myFeedPosts;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 1),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            GestureDetector(
              onTap: () => _navigateToPostDetail(post),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Post thumbnail from API (`thumbnail.url`, video thumb, or `images[0]`).
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: _buildPostGridThumbnail(post)),
                  // Gradient overlay for engagement row
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.35)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  // Video play icon (white, mockup)
                  if (post['isVideo'] as bool) Padding(padding: const EdgeInsets.all(40.0), child: Image.asset('assets/images/playbutton.png')),
                  // Engagement stats overlay
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 14,
                          shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)],
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _formatCount(post['likes'] as int),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(top: 0, right: 0, child: _buildPostGridOverflowMenu(post)),
          ],
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  /// Overflow menu — **Edit** uses `PATCH /user/feed/:id`; **Delete** uses `DELETE /user/feed/:id`.
  Widget _buildPostGridOverflowMenu(Map<String, dynamic> post) {
    return PopupMenuButton<String>(
      tooltip: 'Post options',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 36),
      color: AppColors.surface,
      icon: const Icon(Icons.more_horiz, color: Colors.white, size: 25), // Changed to horizontal 3 dots
      onSelected: (value) {
        if (value == 'edit') {
          _showEditPostBottomSheet(post);
        } else if (value == 'delete') {
          _confirmDeletePost(post);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: _kProfileForestGreen),
              const SizedBox(width: 10),
              Text('Edit', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: AppColors.error),
              const SizedBox(width: 10),
              Text('Delete', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showEditPostBottomSheet(Map<String, dynamic> post) async {
    final id = (post['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: _ProfileEditPostSheet(
            post: post,
            feedRepo: _feedRepo,
            onSaved: () async {
              await Future.wait([_fetchProfileStats(), _fetchMyFeeds()]);
            },
          ),
        );
      },
    );
  }

  /// Confirms then `DELETE` `…/user/feed/:id` (same resource as get-by-id).
  Future<void> _confirmDeletePost(Map<String, dynamic> post) async {
    final id = (post['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete post?', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
        content: Text('This removes the post from your profile. This cannot be undone.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
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

    if (confirmed != true || !mounted) return;

    try {
      await _feedRepo.deleteFeedRepo(id);
      await Future.wait([_fetchProfileStats(), _fetchMyFeeds()]);
      if (!mounted) return;
      Get.snackbar('Deleted', 'Post removed', snackPosition: SnackPosition.BOTTOM, backgroundColor: _kProfileForestGreen, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Could not delete', e.toString(), snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
    }
  }

  void _navigateToPostDetail(Map<String, dynamic> post) {
    final id = (post['id'] ?? '').toString().trim();
    if (id.isEmpty) return;
    Get.toNamed(AppRoutes.feedSingleReel, arguments: <String, dynamic>{'feedId': id});
  }

  void _showCreatePostOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent.withOpacity(0.8)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_photo_alternate, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Create Post',
                      style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Options
              _buildCreatePostOption(
                icon: Icons.videocam,
                title: 'Record Video',
                subtitle: 'Capture a new video with your camera',
                gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                onTap: () {
                  Navigator.pop(context);
                  Get.toNamed(AppRoutes.createPost, arguments: {'type': 'record'});
                },
              ),
              _buildCreatePostOption(
                icon: Icons.video_library,
                title: 'Upload Video',
                subtitle: 'Choose a video from your gallery',
                gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
                onTap: () {
                  Navigator.pop(context);
                  Get.toNamed(AppRoutes.createPost, arguments: {'type': 'video'});
                },
              ),
              _buildCreatePostOption(
                icon: Icons.image,
                title: 'Upload Photo',
                subtitle: 'Share a photo from your gallery',
                gradient: const LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)]),
                onTap: () {
                  Navigator.pop(context);
                  Get.toNamed(AppRoutes.createPost, arguments: {'type': 'image'});
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatePostOption({required IconData icon, required String title, required String subtitle, required Gradient gradient, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryGray.withOpacity(0.2), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: gradient.colors.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Icon(icon, color: Color(0xFFF8FFE9), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: AppColors.primaryGray, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditPersonalRecordsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, -5))],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent.withOpacity(0.8)]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.fitness_center, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Personal Records',
                            style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.primaryGray),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Records list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _personalRecords.length,
                    itemBuilder: (context, index) {
                      final record = _personalRecords[index];
                      return _buildRecordListItem(record, index, setDialogState);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Add button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddRecordDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add, size: 20),
                      label: Text('Add Record', style: AppTextStyles.buttonLarge.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordListItem(PersonalRecord record, int index, StateSetter setDialogState) {
    final dateFormat = DateFormat('MMM d, yyyy');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.liftName,
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('${record.value} ${record.unit} • ${dateFormat.format(record.date)}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ),
              Row(
                children: [
                  // Display publicly toggle
                  Switch(
                    value: record.displayPublicly,
                    onChanged: (value) {
                      setState(() {
                        _personalRecords[index] = record.copyWith(displayPublicly: value);
                      });
                      setDialogState(() {}); // Trigger dialog rebuild
                    },
                    activeColor: AppColors.white,
                  ),
                  const SizedBox(width: 8),
                  // Edit button
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.accent, size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddRecordDialog(record: record, index: index);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.error, size: 20),
                    onPressed: () {
                      setState(() {
                        _personalRecords.removeAt(index);
                      });
                      setDialogState(() {}); // Trigger dialog rebuild
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddRecordDialog({PersonalRecord? record, int? index}) {
    final liftNameController = TextEditingController(text: record?.liftName ?? '');
    final valueController = TextEditingController(text: record?.value ?? '');
    final unitController = TextEditingController(text: record?.unit ?? 'lbs');
    DateTime selectedDate = record?.date ?? DateTime.now();
    bool displayPublicly = record?.displayPublicly ?? true;
    final isEditMode = record != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, -5))],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditMode ? 'Edit Record' : 'Add Record',
                          style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.primaryGray),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          CustomTextField(
                            controller: liftNameController,
                            labelText: 'Lift Name',
                            hintText: 'e.g., Bench Press',
                            prefixIcon: const Icon(Icons.fitness_center, color: AppColors.accent),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: CustomTextField(
                                  controller: valueController,
                                  labelText: 'Value',
                                  hintText: 'e.g., 315',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                  prefixIcon: const Icon(Icons.numbers, color: AppColors.accent),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CustomTextField(
                                  controller: unitController,
                                  labelText: 'Unit',
                                  hintText: 'lbs',
                                  prefixIcon: const Icon(Icons.straighten, color: AppColors.accent),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: AppColors.accent,
                                        onPrimary: AppColors.onAccent,
                                        surface: AppColors.surface,
                                        onSurface: AppColors.onSurface,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (date != null) {
                                setDialogState(() {
                                  selectedDate = date;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, color: AppColors.accent, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Date', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                                        const SizedBox(height: 4),
                                        Text(DateFormat('MMM d, yyyy').format(selectedDate), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: AppColors.primaryGray),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Display Publicly',
                                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Show this record on your public profile', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: displayPublicly,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      displayPublicly = value;
                                    });
                                  },
                                  activeColor: AppColors.white,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (liftNameController.text.trim().isEmpty || valueController.text.trim().isEmpty) {
                            Get.snackbar(
                              'Error',
                              'Please fill in all required fields',
                              backgroundColor: AppColors.error,
                              colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM,
                            );
                            return;
                          }
                          setState(() {
                            final newRecord = PersonalRecord(
                              id: record?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                              liftName: liftNameController.text.trim(),
                              value: valueController.text.trim(),
                              unit: unitController.text.trim(),
                              date: selectedDate,
                              displayPublicly: displayPublicly,
                            );
                            if (isEditMode && index != null) {
                              _personalRecords[index] = newRecord;
                            } else {
                              _personalRecords.add(newRecord);
                            }
                          });
                          Navigator.pop(context); // Close add/edit dialog
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isEditMode ? 'Save Changes' : 'Add Record', style: AppTextStyles.buttonLarge.copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Edit sheet for `PATCH /user/feed/:id` (title, description, tags, category, status).
class _ProfileEditPostSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  final FeedRepository feedRepo;
  final Future<void> Function() onSaved;

  const _ProfileEditPostSheet({required this.post, required this.feedRepo, required this.onSaved});

  @override
  State<_ProfileEditPostSheet> createState() => _ProfileEditPostSheetState();
}

class _ProfileEditPostSheetState extends State<_ProfileEditPostSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;

  /// Tags from the post + user commits (Done / Enter); same pattern as [CreatePostScreen].
  final List<String> _committedTags = [];

  late String _status;
  String? _categoryId;

  List<FeedCategory> _categories = [];
  bool _loadingCategories = true;
  String? _categoriesError;

  bool _saving = false;
  String _saveBusyLabel = '';
  double _saveUploadProgress = 0;

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _replacementVideo;
  VideoPlayerController? _videoPreviewController;
  String? _videoPreviewPath;
  String? _videoPreviewInitError;

  bool get _isVideoPost => widget.post['isVideo'] == true;

  void _videoPreviewListener() {
    if (!mounted) return;
    final c = _videoPreviewController;
    if (c == null || !c.value.isInitialized) return;
    setState(() {});
  }

  void _disposeVideoPreview() {
    final c = _videoPreviewController;
    _videoPreviewController = null;
    _videoPreviewPath = null;
    _videoPreviewInitError = null;
    if (c != null) {
      c.removeListener(_videoPreviewListener);
      c.dispose();
    }
  }

  Future<void> _startVideoPreviewForPath(String path) async {
    final old = _videoPreviewController;
    if (old != null) {
      old.removeListener(_videoPreviewListener);
      await old.dispose();
    }
    _videoPreviewController = null;
    _videoPreviewPath = path;
    _videoPreviewInitError = null;

    final controller = VideoPlayerController.file(File(path));
    _videoPreviewController = controller;
    controller.addListener(_videoPreviewListener);

    try {
      await controller.initialize();
      if (!mounted || _videoPreviewPath != path || _videoPreviewController != controller) {
        controller.removeListener(_videoPreviewListener);
        await controller.dispose();
        if (_videoPreviewController == controller) _videoPreviewController = null;
        return;
      }
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() {});
    } catch (e) {
      controller.removeListener(_videoPreviewListener);
      await controller.dispose();
      if (!mounted) return;
      if (_videoPreviewController == controller) _videoPreviewController = null;
      _videoPreviewPath = null;
      _videoPreviewInitError = e.toString();
      setState(() {});
    }
  }

  Future<void> _pickReplacementVideoGallery() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (!mounted || video == null) return;
      setState(() => _replacementVideo = video);
      await _startVideoPreviewForPath(video.path);
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', 'Could not pick video: $e', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
    }
  }

  Future<void> _pickReplacementVideoCamera() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(source: ImageSource.camera);
      if (!mounted || video == null) return;
      setState(() => _replacementVideo = video);
      await _startVideoPreviewForPath(video.path);
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', 'Could not record video: $e', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
    }
  }

  void _clearReplacementVideo() {
    _disposeVideoPreview();
    setState(() => _replacementVideo = null);
  }

  FeedVideoUploadController _resolveVideoUploader() {
    if (Get.isRegistered<FeedVideoUploadController>()) {
      return Get.find<FeedVideoUploadController>();
    }
    return Get.put(FeedVideoUploadController());
  }

  Future<void> _uploadReplacementVideo({required String feedId, required String mediaPath}) async {
    final file = File(mediaPath);
    if (!await file.exists()) {
      throw StateError('Video file not found.');
    }
    final fileSize = await file.length();
    if (fileSize <= 0) {
      throw StateError('Video file is empty.');
    }

    final contentType = guessVideoContentType(mediaPath);

    if (mounted) {
      setState(() {
        _saveBusyLabel = 'Preparing upload…';
        _saveUploadProgress = 0.08;
      });
    }

    final initRaw = await widget.feedRepo.initVideoMultipartRepo(feedId: feedId, contentType: contentType, fileSize: fileSize);

    final init = FeedMultipartInitData.tryParse(initRaw);
    if (init == null) {
      throw StateError('Invalid multipart init response.');
    }

    if (mounted) {
      setState(() {
        _saveBusyLabel = 'Uploading video…';
        _saveUploadProgress = 0.12;
      });
    }

    final videoUpload = _resolveVideoUploader();
    final uploaded = await videoUpload.runMultipartUpload(
      file: file,
      fileSize: fileSize,
      init: init,
      contentType: contentType,
      onOverallProgress: (raw) {
        if (!mounted) return;
        setState(() {
          _saveUploadProgress = 0.12 + raw * 0.78;
        });
      },
    );

    if (mounted) {
      setState(() {
        _saveBusyLabel = 'Finishing…';
        _saveUploadProgress = 0.92;
      });
    }

    await widget.feedRepo.completeVideoMultipartRepo(feedId: feedId, key: init.key, uploadId: init.uploadId, parts: uploaded.map((e) => e.toCompleteApiJson()).toList());

    if (mounted) {
      setState(() => _saveUploadProgress = 1);
    }
  }

  Widget _buildReplacementVideoPreview() {
    final err = _videoPreviewInitError;
    if (err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            err,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
          ),
        ),
      );
    }

    final c = _videoPreviewController;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white54));
    }

    final v = c.value;
    final w = v.size.width;
    final h = v.size.height;

    final Widget core;
    if (w > 0 && h > 0) {
      core = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: w, height: h, child: VideoPlayer(c)),
      );
    } else {
      final ar = v.aspectRatio;
      core = AspectRatio(aspectRatio: ar > 0 && !ar.isNaN ? ar : 16 / 9, child: VideoPlayer(c));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (c.value.isPlaying) {
          c.pause();
        } else {
          c.play();
        }
        setState(() {});
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: core),
          if (!v.isPlaying)
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    _titleController = TextEditingController(text: (p['title'] ?? '').toString());
    _descriptionController = TextEditingController(text: (p['description'] ?? '').toString());
    _committedTags
      ..clear()
      ..addAll((p['tags'] as List<dynamic>?)?.map((e) => e.toString().replaceFirst(RegExp(r'^#+'), '').trim()).where((t) => t.isNotEmpty).toList() ?? const <String>[]);
    _tagsController = TextEditingController();
    _status = _normalizeFeedPostStatus(p['status']?.toString());
    final cid = (p['categoryId'] ?? '').toString().trim();
    _categoryId = cid.isEmpty ? null : cid;
    _loadCategories();
  }

  @override
  void dispose() {
    _disposeVideoPreview();
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _commitTagsFromField() {
    final parsed = _parseFeedTagsForApi(_tagsController.text);
    if (parsed.isEmpty) return;
    setState(() {
      for (final t in parsed) {
        final exists = _committedTags.any((x) => x.toLowerCase() == t.toLowerCase());
        if (!exists) _committedTags.add(t);
      }
      _tagsController.clear();
    });
  }

  /// API tags: chips plus any text still in the field.
  List<String> _tagsForSave() {
    final fromField = _parseFeedTagsForApi(_tagsController.text);
    final seen = <String>{};
    final out = <String>[];
    void add(String t) {
      final key = t.toLowerCase();
      if (seen.contains(key)) return;
      seen.add(key);
      out.add(t);
    }

    for (final t in _committedTags) {
      add(t);
    }
    for (final t in fromField) {
      add(t);
    }
    return out;
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoriesError = null;
    });
    try {
      final raw = await widget.feedRepo.getFeedCategoriesRepo();
      final list = FeedCategory.listFromResponse(raw);
      if (!mounted) return;
      setState(() {
        _categories = list;
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCategories = false;
        _categoriesError = e.toString();
      });
    }
  }

  Future<void> _save() async {
    final id = (widget.post['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final catId = (_categoryId ?? '').trim();
    if (catId.isEmpty) {
      Get.snackbar('Category required', 'Please select a category.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() {
      _saving = true;
      _saveBusyLabel = 'Saving…';
      _saveUploadProgress = 0;
    });
    try {
      final raw = await widget.feedRepo.updateFeedRepo(
        feedId: id,
        title: _titleController.text,
        description: _descriptionController.text,
        categoryId: catId,
        tags: _tagsForSave(),
        status: _status,
      );

      if (raw is! Map || raw['success'] != true) {
        final msg = raw is Map ? raw['message']?.toString() : null;
        throw Exception(msg ?? 'Could not update post');
      }

      if (_isVideoPost && _replacementVideo != null) {
        await _uploadReplacementVideo(feedId: id, mediaPath: _replacementVideo!.path);
      }

      await widget.onSaved();
      if (!mounted) return;
      Navigator.pop(context);

      final okMsg = raw['message']?.toString();
      final videoNote = _isVideoPost && _replacementVideo != null ? ' New video is processing.' : '';
      Get.snackbar(
        'Saved',
        (okMsg != null && okMsg.isNotEmpty ? okMsg : 'Post updated') + videoNote,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _kProfileForestGreen,
        colorText: Colors.white,
      );
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Could not update', e.toString(), snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveBusyLabel = '';
          _saveUploadProgress = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12));

    final categoryDropdownStyle = AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontSize: 15, fontWeight: FontWeight.w400, height: 1.2);

    final categoryItems = <DropdownMenuItem<String>>[];
    if (_categoryId != null && _categoryId!.isNotEmpty && !_categories.any((c) => c.id == _categoryId)) {
      final name = (widget.post['categoryName'] ?? _categoryId).toString();
      categoryItems.add(
        DropdownMenuItem(
          value: _categoryId,
          child: Text(name, style: categoryDropdownStyle),
        ),
      );
    }
    categoryItems.addAll(
      _categories.map(
        (c) => DropdownMenuItem(
          value: c.id,
          child: Text(c.name, style: categoryDropdownStyle),
        ),
      ),
    );

    final validCategoryValue = _categoryId != null && categoryItems.any((i) => i.value == _categoryId) ? _categoryId : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Edit post',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (_isVideoPost) ...[
            Text('Video', style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: ColoredBox(
                  color: Colors.black,
                  child: _replacementVideo != null
                      ? _buildReplacementVideoPreview()
                      : Image.network(
                          (widget.post['thumbnail'] ?? '').toString(),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 200,
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.videocam, color: Colors.white54, size: 48)),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!_saving) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickReplacementVideoGallery,
                      icon: const Icon(Icons.video_library, size: 18),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(foregroundColor: _kProfileForestGreen),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickReplacementVideoCamera,
                      icon: const Icon(Icons.videocam, size: 18),
                      label: const Text('Camera'),
                      style: OutlinedButton.styleFrom(foregroundColor: _kProfileForestGreen),
                    ),
                  ),
                  if (_replacementVideo != null)
                    IconButton(
                      tooltip: 'Keep original video',
                      onPressed: _clearReplacementVideo,
                      icon: Icon(Icons.undo, color: AppColors.primaryGray.withValues(alpha: 0.95)),
                    ),
                ],
              ),
              Text(
                _replacementVideo != null ? 'New video selected. Tap Save to upload.' : 'Replace video from gallery or camera.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontSize: 12, fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 8),
            ],
          ],
          TextField(
            controller: _titleController,
            decoration: InputDecoration(labelText: 'Title', border: border),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(labelText: 'Description', alignLabelWithHint: true, border: border),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
          const SizedBox(height: 12),
          if (_committedTags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _committedTags
                  .map(
                    (t) => InputChip(
                      label: Text('#$t', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontSize: 15)),
                      deleteIconColor: AppColors.primaryGray,
                      backgroundColor: _kProfileForestGreen.withValues(alpha: 0.12),
                      side: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.25)),
                      onDeleted: () => setState(() => _committedTags.remove(t)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          Focus(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                _commitTagsFromField();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _tagsController,
              decoration: InputDecoration(
                labelText: 'Tags',
                hintText: 'Type a tag, then tap Done or Enter',
                helperText: 'Multiple words add multiple tags. # prefix is optional.',
                border: border,
              ),
              textCapitalization: TextCapitalization.none,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              maxLines: 1,
              onSubmitted: (_) => _commitTagsFromField(),
              onEditingComplete: _commitTagsFromField,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            ),
          ),
          const SizedBox(height: 12),
          Text('Visibility', style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Draft', label: Text('Draft')),
              ButtonSegment(value: 'Published', label: Text('Published')),
            ],
            selected: {_status},
            onSelectionChanged: (next) => setState(() => _status = next.first),
          ),
          const SizedBox(height: 16),
          Text('Category', style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface)),
          const SizedBox(height: 8),
          if (_loadingCategories)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(color: _kProfileForestGreen)),
            )
          else if (_categoriesError != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _categoriesError!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w400),
                ),
                TextButton(
                  onPressed: _loadCategories,
                  child: const Text('Retry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400)),
                ),
              ],
            )
          else if (categoryItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No categories available.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontSize: 13, fontWeight: FontWeight.w400),
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: validCategoryValue,
              style: categoryDropdownStyle,
              decoration: InputDecoration(border: border, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              hint: Text('Select category', style: categoryDropdownStyle.copyWith(color: AppColors.primaryGray)),
              items: categoryItems,
              onChanged: (v) => setState(() => _categoryId = v),
            ),

          if (_saving && _saveBusyLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _saveBusyLabel,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _saveUploadProgress <= 0 ? null : _saveUploadProgress.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: AppColors.primaryGray.withValues(alpha: 0.22),
                color: _kProfileForestGreen,
              ),
            ),
          ],

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 44.h,
                width: 160.w,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(88, 44),
                    side: BorderSide(color: AppColors.primaryGray.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  ),
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              SizedBox(width: 12),
              SizedBox(
                height: 44.h,
                width: 160.w,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 44),
                    backgroundColor: _kProfileForestGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
