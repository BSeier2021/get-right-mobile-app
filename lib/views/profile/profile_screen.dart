import 'dart:async' show unawaited;
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
import 'package:get_right/utils/profile_contact_fields.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get_right/views/home/dashboard_screen.dart';
import 'package:get_right/views/marketplace/program_hls_player_screen.dart';
import 'package:get_right/widgets/safe_network_image.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get_right/models/feed_multipart_init_model.dart';
import 'package:video_player/video_player.dart';

List<String> _parseFeedTagsForApi(String raw) {
  return raw.split(RegExp(r'\s+')).map((t) => t.replaceFirst(RegExp(r'^#+'), '').trim()).where((t) => t.isNotEmpty).toList();
}

/// One image slot while editing a photo post (existing URL and/or new local file).
class _EditFeedImage {
  const _EditFeedImage({this.serverId, this.networkUrl, this.localPath});

  final String? serverId;
  final String? networkUrl;
  final String? localPath;

  bool get isNew => localPath != null && localPath!.isNotEmpty;

  String get snapshotKey => localPath ?? networkUrl ?? serverId ?? '';
}

List<_EditFeedImage> _editFeedImagesFromPost(Map<String, dynamic> post) {
  List<_EditFeedImage> parseImageNodes(List<dynamic> raw) {
    final out = <_EditFeedImage>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final url = ImageUrlSanitizer.asHttpUrlOrNull(feedMediaUrlFromApiNode(m) ?? (m['url'] ?? '').toString());
      if (url == null) continue;
      final id = (m['_id'] ?? m['id'] ?? '').toString().trim();
      out.add(_EditFeedImage(serverId: id.isEmpty ? null : id, networkUrl: url));
    }
    return out;
  }

  final apiImages = post['images'];
  if (apiImages is List) {
    final parsed = parseImageNodes(apiImages);
    if (parsed.isNotEmpty) return parsed;
  }

  final raw = post['feedImages'];
  if (raw is List) {
    final out = <_EditFeedImage>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final url = ImageUrlSanitizer.asHttpUrlOrNull((m['url'] ?? '').toString());
      if (url == null) continue;
      final id = (m['_id'] ?? m['id'] ?? '').toString().trim();
      out.add(_EditFeedImage(serverId: id.isEmpty ? null : id, networkUrl: url));
    }
    if (out.isNotEmpty) return out;
  }

  final urls = post['imageUrls'];
  if (urls is List) {
    final out = <_EditFeedImage>[];
    for (final item in urls) {
      final url = ImageUrlSanitizer.asHttpUrlOrNull(item?.toString());
      if (url != null) out.add(_EditFeedImage(networkUrl: url));
    }
    if (out.isNotEmpty) return out;
  }

  final single = ImageUrlSanitizer.asHttpUrlOrNull((post['imageUrl'] ?? post['thumbnail'] ?? '').toString());
  if (single != null) return [_EditFeedImage(networkUrl: single)];
  return const [];
}

List<Map<String, String>> _feedImagesMetaFromApi(dynamic images) {
  if (images is! List) return const [];
  final seenUrls = <String>{};
  final out = <Map<String, String>>[];
  for (final item in images) {
    final url = feedMediaUrlFromApiNode(item);
    if (url == null) continue;
    final normalized = url.trim();
    if (normalized.isEmpty || seenUrls.contains(normalized)) continue;
    seenUrls.add(normalized);
    final entry = <String, String>{'url': normalized};
    if (item is Map) {
      final id = (item['_id'] ?? item['id'] ?? '').toString().trim();
      if (id.isNotEmpty) entry['id'] = id;
    }
    out.add(entry);
  }
  return out;
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

  factory PersonalRecord.fromApi(Map<String, dynamic> json) {
    final id = (json['_id'] ?? json['id'] ?? '').toString();
    final valueRaw = json['value'];
    final valueStr = valueRaw is num ? (valueRaw == valueRaw.roundToDouble() ? valueRaw.round().toString() : valueRaw.toString()) : (valueRaw?.toString() ?? '');
    final dateStr = json['date']?.toString();
    var date = DateTime.now();
    if (dateStr != null && dateStr.isNotEmpty) {
      date = DateTime.tryParse(dateStr)?.toLocal() ?? date;
    }
    return PersonalRecord(
      id: id,
      liftName: (json['name'] ?? '').toString(),
      value: valueStr,
      unit: (json['unit'] ?? '').toString(),
      date: date,
      displayPublicly: json['isPublic'] == true,
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
  final Set<String> _personalRecordBusyIds = {};
  final FeedRepository _feedRepo = FeedRepository();
  final TrainerProfileRepository _profileRepo = TrainerProfileRepository();
  List<Map<String, dynamic>> _myFeedPosts = [];
  bool _myFeedsLoading = true;
  String? _myFeedsError;
  int? _postCount;
  int? _followersCount;
  int? _followingCount;
  Map<String, dynamic> _profileContact = {};
  bool _bioExpanded = false;
  Worker? _profileTabWorker;
  bool _lazyBootstrapped = false;

  static const int _bioCollapsedMaxLines = 2;

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
                final unreadCount = notificationController.unreadCount.value;
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

  TextStyle _profileBioTextStyle() {
    return AppTextStyles.bodyMedium.copyWith(color: _kProfileForestGreen.withOpacity(0.8), fontSize: 14, height: 1.4);
  }

  Widget _buildExpandableBio(String bio) {
    final text = bio.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    final textStyle = _profileBioTextStyle();
    final actionStyle = textStyle.copyWith(fontWeight: FontWeight.w700, color: _kProfileForestGreen);

    return LayoutBuilder(
      builder: (context, constraints) {
        final overflowPainter = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          maxLines: _bioCollapsedMaxLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);

        final canExpand = overflowPainter.didExceedMaxLines;
        final showToggle = canExpand || _bioExpanded;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, maxLines: _bioExpanded ? null : _bioCollapsedMaxLines, overflow: _bioExpanded ? TextOverflow.visible : TextOverflow.ellipsis, style: textStyle),
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

  Widget _buildProfileStatColumn(String count, String label, {VoidCallback? onTap}) {
    final column = Column(
      children: [
        Text(
          count,
          style: AppTextStyles.titleLarge.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: _kProfileForestGreen.withOpacity(0.65))),
      ],
    );
    if (onTap == null) return column;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: column);
  }

  Widget _buildEditProfileButton() {
    return SizedBox(
      width: 110,
      child: TextButton.icon(
        onPressed: () => Get.toNamed(AppRoutes.editProfile),
        style: TextButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _kProfileForestGreen,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          minimumSize: const Size(88, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _kProfileForestGreen.withOpacity(0.35)),
          ),
        ),
        icon: Icon(Icons.edit_outlined, size: 16, color: _kProfileForestGreen),
        label: Text(
          'Edit',
          style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700, color: _kProfileForestGreen),
        ),
      ),
    );
  }

  String _normalizeSocialPlatformKey(String platform) {
    final p = platform.toLowerCase().trim().replaceAll(RegExp(r'[\s_-]+'), '');
    if (p.isEmpty) return '';
    if (p.contains('instagram') || p == 'ig') return 'instagram';
    if (p.contains('facebook') || p == 'fb') return 'facebook';
    if (p.contains('linkedin')) return 'linkedin';
    if (p.contains('twitter') || p == 'x') return 'x';
    if (p.contains('tiktok')) return 'tiktok';
    if (p.contains('youtube') || p == 'yt') return 'youtube';
    if (p.contains('snapchat') || p == 'snap') return 'snapchat';
    if (p.contains('website') || p == 'web' || p == 'url' || p == 'site' || p == 'homepage') return 'website';
    return p;
  }

  String? _socialPlatformAsset(String platform) {
    switch (_normalizeSocialPlatformKey(platform)) {
      case 'facebook':
        return 'assets/images/facebook-logo-facebook-icon-transparent-free-png.webp';
      case 'x':
        return 'assets/images/new-twitter-x-logo-twitter-icon-x-social-media-icon-free-png.webp';
      case 'tiktok':
        return 'assets/images/tiktok-icon-free-png.webp';
      case 'instagram':
        return 'assets/images/images.jfif';
      default:
        return null;
    }
  }

  IconData _socialPlatformIcon(String platform) {
    switch (_normalizeSocialPlatformKey(platform)) {
      case 'instagram':
        return Icons.photo_camera_outlined;
      case 'facebook':
        return Icons.groups_outlined;
      case 'linkedin':
        return Icons.business_center_outlined;
      case 'x':
        return Icons.close_rounded;
      case 'tiktok':
        return Icons.music_video_outlined;
      case 'youtube':
        return Icons.play_circle_outline_rounded;
      case 'website':
        return Icons.language_rounded;
      case 'snapchat':
        return Icons.bolt_outlined;
      default:
        return Icons.link_rounded;
    }
  }

  Widget _socialPlatformLeading(String platform, {double size = 30}) {
    final asset = _socialPlatformAsset(platform);
    if (asset != null) {
      return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
    }
    return Icon(_socialPlatformIcon(platform), color: _kProfileForestGreen, size: size);
  }

  Widget _buildSocialLinkChip(String platform, String url) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final uri = Uri.tryParse(url);
          if (uri != null) _launchExternalUri(uri);
        },
        onLongPress: () => _copyToClipboard(_normalizeSocialPlatformKey(platform), url),
        borderRadius: BorderRadius.circular(20),
        child: _socialPlatformLeading(platform),
      ),
    );
  }

  Widget _buildSocialAccountsCompact() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kProfileForestGreen.withOpacity(0.15)),
      ),
      child: Wrap(spacing: 8, runSpacing: 8, children: _socialAccounts.entries.map((e) => _buildSocialLinkChip(e.key, e.value)).toList()),
    );
  }

  Widget _buildProfileDetailsSection() {
    if (!_hasSocialAccounts) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasAddress) ...[
          Text(
            'Address',
            style: AppTextStyles.titleMedium.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kProfileForestGreen.withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.completed.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.location_on_rounded, color: AppColors.completed, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _displayAddress!,
                    style: AppTextStyles.bodyMedium.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.w600, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_hasAddress && _hasSocialAccounts) const SizedBox(height: 20),
        if (_hasSocialAccounts) ...[
          Text(
            'Social Accounts',
            style: AppTextStyles.titleMedium.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildSocialAccountsCompact(),
        ],
      ],
    );
  }

  Widget _buildPublicProfile(AuthController auth) {
    final p = auth.customerProfile;
    var displayName = 'Your profile';
    String? photoUrl;
    if (p != null) {
      photoUrl = p.profilePictureUrl;
      final n = p.fullName?.trim();
      if (n != null && n.isNotEmpty) {
        displayName = n;
      } else if (p.email.isNotEmpty) {
        displayName = p.email.split('@').first;
      }
    }
    final bioLine = p?.bio?.trim() ?? '';
    final userId = _resolvedUserId();
    final hasStats = userId != null;

    return Column(
      children: [
        if (auth.customerProfileLoading && auth.customerProfile != null) const LinearProgressIndicator(minHeight: 2, color: _kProfileForestGreen),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _kProfileForestGreen, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(ImageUrlSanitizer.asHttpUrlOrFallback(photoUrl)) : null,
                      child: (photoUrl == null || photoUrl.isEmpty) ? Icon(Icons.person, size: 40, color: _kProfileForestGreen.withOpacity(0.45)) : null,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: GestureDetector(
                      onTap: () => Get.toNamed(AppRoutes.editProfile),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _kProfileForestGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: _kProfileCream, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              _buildProfileStatColumn(hasStats ? _formatProfileStat(_postCount) : '…', 'Posts'),
              _buildProfileStatColumn(
                hasStats ? _formatProfileStat(_followersCount) : '…',
                'Followers',
                onTap: hasStats ? () => Get.toNamed(AppRoutes.followers, arguments: <String, dynamic>{'userId': userId!, 'profileName': displayName}) : null,
              ),
              _buildProfileStatColumn(
                hasStats ? _formatProfileStat(_followingCount) : '…',
                'Following',
                onTap: hasStats ? () => Get.toNamed(AppRoutes.following, arguments: <String, dynamic>{'userId': userId!, 'profileName': displayName}) : null,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleLarge.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.bold, fontSize: 17.sp),
                    ),
                  ),
                  _buildEditProfileButton(),
                ],
              ),
              if (bioLine.isNotEmpty) ...[const SizedBox(height: 8), _buildExpandableBio(bioLine)],
              if (_profileMetaLine(p).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _profileMetaLine(p),
                  style: AppTextStyles.labelSmall.copyWith(color: _kProfileForestGreen.withOpacity(0.75), fontWeight: FontWeight.w600, height: 1.4),
                ),
              ],
              if (_hasProfileDetails) ...[const SizedBox(height: 20), _buildProfileDetailsSection()],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Personal records section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Personal Records',
                    style: AppTextStyles.titleMedium.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.w700),
                  ),

                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _kProfileForestGreen, width: 2),
                    ),
                    child: IconButton(
                      icon: Icon(_personalRecords.isEmpty ? Icons.add : Icons.edit_note_rounded, color: _kProfileForestGreen, size: 26),
                      onPressed: _personalRecords.isEmpty ? () => _showRecordFormDialog() : _showEditPersonalRecordsDialog,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ),
                ],
              ),
              if (_personalRecords.isNotEmpty) ...[const SizedBox(height: 8), _buildPersonalRecordsGrid()],
            ],
          ),
        ),
        const SizedBox(height: 28),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Posts',
                    style: AppTextStyles.titleMedium.copyWith(color: _kProfileForestGreen, fontWeight: FontWeight.bold),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showCreatePostOptions,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 30,
                        height: 30,
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
    final profile = u['profile'] is Map ? Map<String, dynamic>.from(u['profile'] as Map) : <String, dynamic>{};
    final contact = extractProfileContactFields(profile: profile, user: u);
    final recordsRaw = u['personalRecords'];
    final records = recordsRaw is List
        ? recordsRaw.whereType<Map>().map((e) => PersonalRecord.fromApi(Map<String, dynamic>.from(e))).where((r) => r.id.isNotEmpty && r.liftName.isNotEmpty).toList()
        : <PersonalRecord>[];
    setState(() {
      _postCount = _statIntFrom(u['postCount']);
      _followersCount = _statIntFrom(u['followersCount']);
      _followingCount = _statIntFrom(u['followingCount']);
      _profileContact = contact;
      _personalRecords = records;
    });
  }

  Map<String, String> get _socialAccounts => socialAccountsFromContactFields(_profileContact);

  bool get _hasSocialAccounts => hasSocialAccountsInContactFields(_profileContact);

  bool get _hasAddress => addressFromContactFields(_profileContact) != null;

  bool get _hasProfileDetails => _hasSocialAccounts;

  String? get _displayAddress => addressFromContactFields(_profileContact);

  Future<void> _launchExternalUri(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        Get.snackbar('Open link', 'Could not open link.', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      Get.snackbar('Open link', 'Could not open link.', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    Get.snackbar(
      'Copied!',
      '$label copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: _kProfileForestGreen.withOpacity(0.1),
      colorText: _kProfileForestGreen,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
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
    final imageUrls = allFeedImageUrlsFromApiList(m['images']);
    final feedImages = _feedImagesMetaFromApi(m['images']);
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
      'imageUrls': imageUrls,
      'feedImages': feedImages,
      if (m['images'] is List) 'images': m['images'],
      if (!isVideo && imageUrls.isNotEmpty) 'imageUrl': imageUrls.first,
      if (!isVideo && imageUrls.isEmpty && thumb.isNotEmpty) 'imageUrl': thumb,
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
                  if ((post['status'] ?? '').toString().toLowerCase() == 'draft')
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.upcoming.withOpacity(0.92), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          'Draft',
                          style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10),
                        ),
                      ),
                    ),
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
    final status = (post['status'] ?? '').toString().trim().toLowerCase();
    if (status == 'draft') {
      unawaited(_openCreatePost(<String, dynamic>{'post': post}));
      return;
    }
    Get.toNamed(AppRoutes.feedSingleReel, arguments: <String, dynamic>{'feedId': id});
  }

  Future<void> _openCreatePost(Map<String, dynamic>? arguments) async {
    await Get.toNamed(AppRoutes.createPost, arguments: arguments);
    if (!mounted) return;
    await Future.wait([_fetchProfileStats(), _fetchMyFeeds()]);
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
                  unawaited(_openCreatePost(<String, dynamic>{'type': 'record'}));
                },
              ),
              _buildCreatePostOption(
                icon: Icons.video_library,
                title: 'Upload Video',
                subtitle: 'Choose a video from your gallery',
                gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_openCreatePost(<String, dynamic>{'type': 'video'}));
                },
              ),
              _buildCreatePostOption(
                icon: Icons.image,
                title: 'Upload Photo',
                subtitle: 'Share a photo from your gallery',
                gradient: const LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)]),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_openCreatePost(<String, dynamic>{'type': 'image'}));
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
                  child: _personalRecords.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Text(
                            'No records yet. Add your first personal record below.',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
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
                        _showRecordFormDialog();
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
    final busy = _personalRecordBusyIds.contains(record.id);
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text(
                      '${record.displayPublicly ? '${record.value} ${record.unit}' : 'Hidden'} • ${dateFormat.format(record.date)}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
              else ...[
                Switch(
                  value: record.displayPublicly,
                  onChanged: (value) async {
                    final ok = await _updatePersonalRecordOnServer(record: record, isPublic: value);
                    if (ok && mounted) setDialogState(() {});
                  },
                  activeColor: AppColors.white,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.accent, size: 20),
                  onPressed: () {
                    Navigator.pop(context);
                    _showRecordFormDialog(record: record);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error, size: 20),
                  onPressed: () async {
                    final ok = await _deletePersonalRecord(record, index);
                    if (ok && mounted) setDialogState(() {});
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  PersonalRecord? _personalRecordFromApiResponse(dynamic raw, {required String fallbackMessage}) {
    if (raw is! Map<String, dynamic> || raw['success'] != true) {
      final msg = raw is Map ? raw['message']?.toString() : null;
      throw Exception(msg ?? fallbackMessage);
    }
    final data = raw['data'];
    if (data is! Map || data['personalRecord'] is! Map) {
      throw Exception('Invalid response from server');
    }
    return PersonalRecord.fromApi(Map<String, dynamic>.from(data['personalRecord'] as Map));
  }

  void _showPersonalRecordMessage(String title, String message, {bool isError = false}) {
    Get.snackbar(title, message, backgroundColor: isError ? AppColors.error : _kProfileForestGreen, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
  }

  Future<bool> _updatePersonalRecordOnServer({required PersonalRecord record, String? name, String? valueText, String? unit, DateTime? date, bool? isPublic}) async {
    final parsedValue = num.tryParse((valueText ?? record.value).trim());
    if (parsedValue == null) {
      _showPersonalRecordMessage('Error', 'Please enter a valid numeric value', isError: true);
      return false;
    }

    setState(() => _personalRecordBusyIds.add(record.id));
    try {
      final raw = await _profileRepo.updatePersonalRecordRepo(
        recordId: record.id,
        name: (name ?? record.liftName).trim(),
        value: parsedValue,
        unit: (unit ?? record.unit).trim(),
        date: _personalRecordDateIso(date ?? record.date),
        isPublic: isPublic ?? record.displayPublicly,
      );
      final updated = _personalRecordFromApiResponse(raw, fallbackMessage: 'Could not update personal record');
      if (updated == null || !mounted) return false;
      setState(() {
        final i = _personalRecords.indexWhere((r) => r.id == record.id);
        if (i >= 0) _personalRecords[i] = updated;
      });
      _showPersonalRecordMessage('Success', raw['message']?.toString() ?? 'Personal record updated successfully');
      return true;
    } catch (e) {
      _showPersonalRecordMessage('Error', e.toString().replaceFirst('Exception: ', ''), isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _personalRecordBusyIds.remove(record.id));
    }
  }

  Future<bool> _deletePersonalRecord(PersonalRecord record, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text('Remove "${record.liftName}" from your personal records?'),
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
    if (confirmed != true) return false;

    setState(() => _personalRecordBusyIds.add(record.id));
    try {
      final raw = await _profileRepo.deletePersonalRecordRepo(record.id);
      if (raw is! Map<String, dynamic> || raw['success'] != true) {
        final msg = raw is Map ? raw['message']?.toString() : null;
        throw Exception(msg ?? 'Could not delete personal record');
      }
      if (!mounted) return false;
      setState(() {
        if (index >= 0 && index < _personalRecords.length && _personalRecords[index].id == record.id) {
          _personalRecords.removeAt(index);
        } else {
          _personalRecords.removeWhere((r) => r.id == record.id);
        }
      });
      _showPersonalRecordMessage('Success', raw['message']?.toString() ?? 'Personal record deleted successfully');
      return true;
    } catch (e) {
      _showPersonalRecordMessage('Error', e.toString().replaceFirst('Exception: ', ''), isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _personalRecordBusyIds.remove(record.id));
    }
  }

  String _personalRecordDateIso(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day, 10, 30).toIso8601String();
  }

  Future<bool> _submitPersonalRecord({
    required String liftName,
    required String valueText,
    required String unit,
    required DateTime date,
    required bool displayPublicly,
    PersonalRecord? existingRecord,
  }) async {
    if (existingRecord != null) {
      return _updatePersonalRecordOnServer(record: existingRecord, name: liftName, valueText: valueText, unit: unit, date: date, isPublic: displayPublicly);
    }

    final parsedValue = num.tryParse(valueText.trim());
    if (parsedValue == null) {
      _showPersonalRecordMessage('Error', 'Please enter a valid numeric value', isError: true);
      return false;
    }

    try {
      final raw = await _profileRepo.addPersonalRecordRepo(name: liftName, value: parsedValue, unit: unit, date: _personalRecordDateIso(date), isPublic: displayPublicly);
      final record = _personalRecordFromApiResponse(raw, fallbackMessage: 'Could not add personal record');
      if (record == null || !mounted) return false;
      setState(() => _personalRecords = [..._personalRecords, record]);
      _showPersonalRecordMessage('Success', raw['message']?.toString() ?? 'Personal record added successfully');
      return true;
    } catch (e) {
      _showPersonalRecordMessage('Error', e.toString().replaceFirst('Exception: ', ''), isError: true);
      return false;
    }
  }

  void _showRecordFormDialog({PersonalRecord? record}) {
    final liftNameController = TextEditingController(text: record?.liftName ?? '');
    final valueController = TextEditingController(text: record?.value ?? '');
    final unitController = TextEditingController(text: record?.unit ?? 'kg');
    DateTime selectedDate = record?.date ?? DateTime.now();
    bool displayPublicly = record?.displayPublicly ?? true;
    bool saving = false;
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
                        onPressed: saving
                            ? null
                            : () async {
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
                                setDialogState(() => saving = true);
                                final ok = await _submitPersonalRecord(
                                  liftName: liftNameController.text.trim(),
                                  valueText: valueController.text.trim(),
                                  unit: unitController.text.trim().isEmpty ? 'kg' : unitController.text.trim(),
                                  date: selectedDate,
                                  displayPublicly: displayPublicly,
                                  existingRecord: record,
                                );
                                if (!context.mounted) return;
                                if (ok) {
                                  Navigator.pop(context);
                                } else {
                                  setDialogState(() => saving = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: saving
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
                            : Text(isEditMode ? 'Save Changes' : 'Add Record', style: AppTextStyles.buttonLarge.copyWith(fontWeight: FontWeight.w700)),
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

  static const int _maxEditImages = 5;

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _replacementVideo;
  final List<_EditFeedImage> _editImages = [];
  late final List<String> _initialImageSnapshot;
  final Set<String> _removedServerImageIds = {};
  int _previewImageIndex = 0;
  final PageController _imagePageController = PageController();
  VideoPlayerController? _videoPreviewController;
  String? _videoPreviewPath;
  String? _videoPreviewInitError;

  bool get _isVideoPost => widget.post['isVideo'] == true;
  bool get _imagesDirty {
    final current = _editImages.map((e) => e.snapshotKey).toList();
    if (current.length != _initialImageSnapshot.length) return true;
    for (var i = 0; i < current.length; i++) {
      if (current[i] != _initialImageSnapshot[i]) return true;
    }
    return false;
  }

  void _restoreOriginalEditImages() {
    setState(() {
      _removedServerImageIds.clear();
      _editImages
        ..clear()
        ..addAll(_editFeedImagesFromPost(widget.post));
      _previewImageIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_editImages.isEmpty || !_imagePageController.hasClients) return;
      _imagePageController.jumpToPage(0);
    });
  }

  void _appendEditImages(List<_EditFeedImage> additions) {
    if (additions.isEmpty) return;
    final firstNewIndex = _editImages.length;
    setState(() {
      _editImages.addAll(additions);
      _previewImageIndex = firstNewIndex;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_editImages.isEmpty || !_imagePageController.hasClients) return;
      _imagePageController.animateToPage(_previewImageIndex, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

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

  Future<void> _pickEditImagesFromGallery() async {
    try {
      final picked = await _imagePicker.pickMultiImage(imageQuality: 88);
      if (!mounted || picked.isEmpty) return;

      final remainingSlots = _maxEditImages - _editImages.length;
      if (remainingSlots <= 0) {
        Get.snackbar(
          'Limit reached',
          'You can add up to $_maxEditImages images per post.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.upcoming,
          colorText: Colors.white,
        );
        return;
      }

      final next = picked.take(remainingSlots).map((image) => _EditFeedImage(localPath: image.path)).toList();
      _appendEditImages(next);
      if (picked.length > remainingSlots) {
        Get.snackbar(
          'Limit reached',
          'Only $remainingSlots more image${remainingSlots == 1 ? '' : 's'} could be added.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.upcoming,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', 'Could not pick images: $e', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
    }
  }

  Future<void> _pickEditImageFromCamera() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 88);
      if (!mounted || image == null) return;

      if (_editImages.length >= _maxEditImages) {
        Get.snackbar(
          'Limit reached',
          'You can add up to $_maxEditImages images per post.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.upcoming,
          colorText: Colors.white,
        );
        return;
      }

      _appendEditImages([_EditFeedImage(localPath: image.path)]);
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', 'Could not capture image: $e', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
    }
  }

  void _goToPreviewImage(int index) {
    if (index < 0 || index >= _editImages.length) return;
    setState(() => _previewImageIndex = index);
    if (_imagePageController.hasClients) {
      _imagePageController.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _openEditImagesFullScreen() {
    if (_editImages.isEmpty || _saving) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _EditPostImageViewerScreen(images: List<_EditFeedImage>.from(_editImages), initialIndex: _previewImageIndex),
      ),
    );
  }

  Future<void> _openEditVideoFullScreen() async {
    if (_saving) return;

    if (_replacementVideo != null) {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => _EditPostLocalVideoViewerScreen(path: _replacementVideo!.path)));
      return;
    }

    final rawUrl = (widget.post['videoUrl'] ?? '').toString().trim();
    final videoUrl = ImageUrlSanitizer.asHttpUrlOrNull(rawUrl) ?? rawUrl;
    final uri = Uri.tryParse(videoUrl);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      await Get.to<void>(() => ProgramHlsPlayerScreen(videoUri: uri, title: (widget.post['title'] ?? 'Video').toString()));
      return;
    }

    final feedId = (widget.post['id'] ?? '').toString().trim();
    if (feedId.isNotEmpty) {
      await Get.toNamed(AppRoutes.feedSingleReel, arguments: <String, dynamic>{'feedId': feedId});
    }
  }

  void _removeEditImageAt(int index) {
    if (index < 0 || index >= _editImages.length) return;
    if (_editImages.length <= 1) {
      Get.snackbar('Cannot remove', 'A post must have at least one image.', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.upcoming, colorText: Colors.white);
      return;
    }
    final removed = _editImages[index];
    final removedId = removed.serverId?.trim();
    if (removedId != null && removedId.isNotEmpty) {
      _removedServerImageIds.add(removedId);
    }
    setState(() {
      _editImages.removeAt(index);
      if (_previewImageIndex >= _editImages.length) {
        _previewImageIndex = _editImages.length - 1;
      } else if (_previewImageIndex > index) {
        _previewImageIndex--;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_editImages.isEmpty || !_imagePageController.hasClients) return;
      _imagePageController.jumpToPage(_previewImageIndex);
    });
  }

  Future<File?> _downloadNetworkImageToTemp(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/feed_edit_${DateTime.now().millisecondsSinceEpoch}_${url.hashCode.abs()}.jpg');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  List<String> _keptServerImageIds() {
    return _editImages.map((e) => e.serverId?.trim()).whereType<String>().where((id) => id.isNotEmpty).toList();
  }

  List<String> _deletedServerImageIds() {
    final currentIds = _keptServerImageIds().toSet();
    final fromInitial = _editFeedImagesFromPost(widget.post).map((e) => e.serverId?.trim()).whereType<String>().where((id) => id.isNotEmpty && !currentIds.contains(id));
    return {...fromInitial, ..._removedServerImageIds}.toList();
  }

  Future<List<File>> _collectNewLocalImageFiles() async {
    final files = <File>[];
    for (var i = 0; i < _editImages.length; i++) {
      final localPath = _editImages[i].localPath;
      if (localPath == null || localPath.isEmpty) continue;
      final file = File(localPath);
      if (!await file.exists() || await file.length() <= 0) {
        throw StateError('Image file ${i + 1} is missing or empty.');
      }
      files.add(file);
    }
    return files;
  }

  Future<List<File>> _collectOrphanNetworkImageFiles() async {
    final files = <File>[];
    for (var i = 0; i < _editImages.length; i++) {
      final img = _editImages[i];
      if (img.localPath != null && img.localPath!.isNotEmpty) continue;
      final serverId = img.serverId?.trim();
      if (serverId != null && serverId.isNotEmpty) continue;
      final url = img.networkUrl;
      if (url == null || url.isEmpty) continue;
      final file = await _downloadNetworkImageToTemp(url);
      if (file == null) throw StateError('Could not download image ${i + 1}.');
      files.add(file);
    }
    return files;
  }

  Future<void> _uploadEditedImages({required String feedId}) async {
    if (_editImages.isEmpty) {
      throw StateError('At least one image is required.');
    }

    if (mounted) {
      setState(() {
        _saveBusyLabel = 'Preparing images…';
        _saveUploadProgress = 0.15;
      });
    }

    final keptImageIds = _keptServerImageIds();
    final deletedImageIds = _deletedServerImageIds();
    final newFiles = await _collectNewLocalImageFiles();
    final orphanFiles = await _collectOrphanNetworkImageFiles();
    final uploadFiles = <File>[...newFiles, ...orphanFiles];

    if (mounted) {
      setState(() {
        _saveBusyLabel = uploadFiles.isEmpty ? 'Updating images…' : 'Uploading images…';
        _saveUploadProgress = 0.55;
      });
    }

    final raw = await widget.feedRepo.updateFeedWithImagesMultipartRepo(
      feedId: feedId,
      title: _titleController.text,
      description: _descriptionController.text,
      categoryId: (_categoryId ?? '').trim(),
      tags: _tagsForSave(),
      status: _status,
      imageFiles: uploadFiles,
      keptImageIds: keptImageIds,
      deletedImageIds: deletedImageIds,
    );

    if (mounted) setState(() => _saveUploadProgress = 1);

    if (raw is! Map || raw['success'] != true) {
      final msg = raw is Map ? raw['message']?.toString() : null;
      throw Exception(msg ?? 'Could not update images');
    }
  }

  Widget _buildEditImagePreview() {
    if (_editImages.isEmpty) {
      return const ColoredBox(
        color: AppColors.surface,
        child: Center(child: Icon(Icons.image_outlined, color: AppColors.primaryGray, size: 48)),
      );
    }

    return PageView.builder(
      controller: _imagePageController,
      itemCount: _editImages.length,
      onPageChanged: (index) => setState(() => _previewImageIndex = index),
      itemBuilder: (context, index) {
        final img = _editImages[index];
        if (img.localPath != null) {
          return Image.file(File(img.localPath!), fit: BoxFit.cover, width: double.infinity, height: double.infinity);
        }
        return Image.network(
          img.networkUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.primaryGray, size: 48)),
        );
      },
    );
  }

  Widget _buildEditImageThumbnails() {
    if (_editImages.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _editImages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final selected = index == _previewImageIndex;
          final img = _editImages[index];
          final thumb = img.localPath != null
              ? Image.file(File(img.localPath!), width: 72, height: 72, fit: BoxFit.cover)
              : Image.network(img.networkUrl!, width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined));

          return GestureDetector(
            onTap: () => _goToPreviewImage(index),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? _kProfileForestGreen : Colors.transparent, width: 2),
                  ),
                  child: ClipRRect(borderRadius: BorderRadius.circular(10), child: thumb),
                ),
                if (_editImages.length > 1)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () => _removeEditImageAt(index),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
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

    return Stack(
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
    if (!_isVideoPost) {
      _editImages.addAll(_editFeedImagesFromPost(p));
      _initialImageSnapshot = _editImages.map((e) => e.snapshotKey).toList();
    } else {
      _initialImageSnapshot = const [];
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _disposeVideoPreview();
    _imagePageController.dispose();
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
      final updatingImages = !_isVideoPost && _imagesDirty;

      dynamic raw;
      if (updatingImages) {
        await _uploadEditedImages(feedId: id);
        raw = <String, dynamic>{'success': true};
      } else {
        raw = await widget.feedRepo.updateFeedRepo(
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
      }

      await widget.onSaved();
      if (!mounted) return;
      Navigator.pop(context);

      final okMsg = raw is Map ? raw['message']?.toString() : null;
      final mediaNote = _isVideoPost && _replacementVideo != null
          ? ' New video is processing.'
          : updatingImages
          ? ' Images updated.'
          : '';
      Get.snackbar(
        'Saved',
        (okMsg != null && okMsg.isNotEmpty ? okMsg : 'Post updated') + mediaNote,
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

  TextStyle get _sectionLabelStyle => AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700);

  ButtonStyle get _mediaActionButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: _kProfileForestGreen,
    backgroundColor: AppColors.surface,
    side: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.35)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    visualDensity: VisualDensity.compact,
  );

  Widget _buildEditPostHeader() {
    return Column(
      children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Edit post',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.primaryGray),
              onPressed: _saving ? null : () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaStatusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: _kProfileForestGreen.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildMediaOpenHint() {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildMediaActionBar({
    required VoidCallback onGallery,
    required VoidCallback onCamera,
    required IconData galleryIcon,
    required IconData cameraIcon,
    VoidCallback? onReset,
    String? resetTooltip,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        border: Border(top: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.18))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(onPressed: onGallery, icon: Icon(galleryIcon, size: 18), label: const Text('Gallery'), style: _mediaActionButtonStyle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(onPressed: onCamera, icon: Icon(cameraIcon, size: 18), label: const Text('Camera'), style: _mediaActionButtonStyle),
          ),
          if (onReset != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: resetTooltip,
              onPressed: onReset,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.undo_rounded, color: AppColors.primaryGray.withValues(alpha: 0.9)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoMediaCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Media', style: _sectionLabelStyle),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.22)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              GestureDetector(
                onTap: _openEditVideoFullScreen,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Colors.black,
                        child: _replacementVideo != null
                            ? _buildReplacementVideoPreview()
                            : Image.network(
                                (widget.post['thumbnail'] ?? '').toString(),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 180,
                                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.videocam, color: Colors.white54, size: 48)),
                              ),
                      ),
                      if (_replacementVideo != null)
                        Positioned(top: 10, left: 10, child: _buildMediaStatusChip('New video selected'))
                      else
                        const Positioned.fill(
                          child: Center(child: Icon(Icons.play_circle_fill, color: Colors.white54, size: 44)),
                        ),
                      Positioned(bottom: 8, right: 8, child: _buildMediaOpenHint()),
                    ],
                  ),
                ),
              ),
              if (!_saving)
                _buildMediaActionBar(
                  onGallery: _pickReplacementVideoGallery,
                  onCamera: _pickReplacementVideoCamera,
                  galleryIcon: Icons.video_library_outlined,
                  cameraIcon: Icons.videocam_outlined,
                  onReset: _replacementVideo != null ? _clearReplacementVideo : null,
                  resetTooltip: 'Keep original video',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageMediaCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Media', style: _sectionLabelStyle),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.22)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              GestureDetector(
                onTap: _openEditImagesFullScreen,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildEditImagePreview(),
                      if (_editImages.length > 1)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              '${_previewImageIndex + 1}/${_editImages.length}',
                              style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      if (_imagesDirty) Positioned(top: 10, left: 10, child: _buildMediaStatusChip('Unsaved changes')),
                      if (_editImages.isNotEmpty) Positioned(bottom: 8, right: 8, child: _buildMediaOpenHint()),
                    ],
                  ),
                ),
              ),
              if (_editImages.length > 1) ...[
                Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(12, 10, 12, 0), color: AppColors.backgroundColor, child: _buildEditImageThumbnails()),
                const SizedBox(height: 10),
              ],
              if (!_saving)
                _buildMediaActionBar(
                  onGallery: _pickEditImagesFromGallery,
                  onCamera: _pickEditImageFromCamera,
                  galleryIcon: Icons.photo_library_outlined,
                  cameraIcon: Icons.photo_camera_outlined,
                  onReset: _imagesDirty ? _restoreOriginalEditImages : null,
                  resetTooltip: 'Keep original images',
                ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String label, {String? hint, String? helper}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _kProfileForestGreen, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),

          Material(
            color: AppColors.surface,
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.18))),
              ),
              padding: const EdgeInsets.fromLTRB(30, 12, 12, 12),
              child: _buildEditPostHeader(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isVideoPost) _buildVideoMediaCard() else _buildImageMediaCard(),
                  const SizedBox(height: 10),
                  Text('Details', style: _sectionLabelStyle),
                  const SizedBox(height: 8),
                  TextField(controller: _titleController, decoration: _fieldDecoration('Title'), onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus()),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: _fieldDecoration('Description'),
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                  const SizedBox(height: 10),
                  Text('Tags', style: _sectionLabelStyle),
                  const SizedBox(height: 8),
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
                      decoration: _fieldDecoration('Add tags', hint: 'Type a tag, then tap Done or Enter', helper: 'Multiple words add multiple tags. # prefix is optional.'),
                      textCapitalization: TextCapitalization.none,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      maxLines: 1,
                      onSubmitted: (_) => _commitTagsFromField(),
                      onEditingComplete: _commitTagsFromField,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Visibility', style: _sectionLabelStyle),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      side: WidgetStatePropertyAll(BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.35))),
                    ),
                    segments: const [
                      ButtonSegment(value: 'Draft', label: Text('Draft')),
                      ButtonSegment(value: 'Published', label: Text('Published')),
                    ],
                    selected: {_status},
                    onSelectionChanged: _saving ? null : (next) => setState(() => _status = next.first),
                  ),
                  const SizedBox(height: 10),
                  Text('Category', style: _sectionLabelStyle),
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
                      decoration: _fieldDecoration('Category').copyWith(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      hint: Text('Select category', style: categoryDropdownStyle.copyWith(color: AppColors.primaryGray)),
                      items: categoryItems,
                      onChanged: _saving ? null : (v) => setState(() => _categoryId = v),
                    ),
                ],
              ),
            ),
          ),
          Material(
            color: AppColors.surface,
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.2))),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_saving && _saveBusyLabel.isNotEmpty) ...[
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
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.onBackground,
                              backgroundColor: AppColors.surface,
                              side: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _saving ? null : () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: AppTextStyles.buttonMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.black),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _kProfileForestGreen,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _kProfileForestGreen.withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(
                                    'Save',
                                    style: AppTextStyles.buttonMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditPostImageViewerScreen extends StatefulWidget {
  const _EditPostImageViewerScreen({required this.images, this.initialIndex = 0});

  final List<_EditFeedImage> images;
  final int initialIndex;

  @override
  State<_EditPostImageViewerScreen> createState() => _EditPostImageViewerScreenState();
}

class _EditPostImageViewerScreenState extends State<_EditPostImageViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.images.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(count > 1 ? '${_currentIndex + 1} / $count' : 'Photo', style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: count,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final img = widget.images[index];
          return Center(child: InteractiveViewer(minScale: 0.5, maxScale: 4, child: _buildImage(img)));
        },
      ),
    );
  }

  Widget _buildImage(_EditFeedImage img) {
    final localPath = img.localPath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (!file.existsSync()) {
        return _imageError('Image file not found');
      }
      return Image.file(file, fit: BoxFit.contain);
    }

    final url = ImageUrlSanitizer.asHttpUrlOrNull(img.networkUrl ?? '');
    if (url == null) {
      return _imageError('Invalid image URL');
    }

    return SafeNetworkImage(url: url, fit: BoxFit.contain, fallback: _imageError('Failed to load image'));
  }

  Widget _imageError(String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image, color: Colors.white54, size: 64),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EditPostLocalVideoViewerScreen extends StatefulWidget {
  const _EditPostLocalVideoViewerScreen({required this.path});

  final String path;

  @override
  State<_EditPostLocalVideoViewerScreen> createState() => _EditPostLocalVideoViewerScreenState();
}

class _EditPostLocalVideoViewerScreenState extends State<_EditPostLocalVideoViewerScreen> {
  VideoPlayerController? _controller;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.file(File(widget.path));
    _controller = controller;
    controller.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() {});
    } catch (e) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _controller = null;
        _initError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final err = _initError;
    final c = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Video preview', style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
      ),
      body: GestureDetector(
        onTap: _togglePlayback,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: err != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    err,
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                )
              : c == null || !c.value.isInitialized
              ? const CircularProgressIndicator(color: Colors.white54)
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(aspectRatio: c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9, child: VideoPlayer(c)),
                    if (!c.value.isPlaying)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 50),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
