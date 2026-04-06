import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _personalRecords = [
      PersonalRecord(id: '1', liftName: 'Bench Press', value: '315', unit: 'lbs', date: DateTime(2024, 12, 12), displayPublicly: true),
      PersonalRecord(id: '2', liftName: 'Squat', value: '405', unit: 'lbs', date: DateTime(2024, 12, 12), displayPublicly: true),
    ];
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
      body: _buildPublicProfile(),
    );
  }

  Widget _buildPublicProfile() {
    return SingleChildScrollView(
      child: Column(
        children: [
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
                      child: Icon(Icons.person, size: 52, color: _kProfileForestGreen.withOpacity(0.45)),
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
          const SizedBox(height: 20),
          // Stat cards row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(child: _buildStatCard('06', 'Posts', _kStatPostsOrange)),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard('1247', 'Followers', _kStatFollowersBlue, onTap: () => Get.toNamed(AppRoutes.followers))),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard('342', 'Following', _kStatFollowingGreen, onTap: () => Get.toNamed(AppRoutes.following))),
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
      ),
    );
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

  Widget _buildPostsGrid() {
    // Mock posts data with more realistic content
    final posts = [
      {
        'id': '1',
        'isVideo': true,
        'thumbnail': 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=400',
        'title': 'Perfect Squat Form',
        'description': 'Master your squat technique with these tips!',
        'likes': 315,
        'comments': 42,
        'saves': 89,
        'shares': 23,
        'duration': '1:24',
        'timestamp': '2 days ago',
        'tags': ['#fitness', '#squat', '#formcheck'],
      },
      {
        'id': '2',
        'isVideo': false,
        'thumbnail': 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400',
        'title': 'Gym Progress',
        'description': '6 months of consistent training!',
        'likes': 428,
        'comments': 67,
        'saves': 124,
        'shares': 31,
        'timestamp': '5 days ago',
        'tags': ['#progress', '#transformation', '#dedication'],
      },
      {
        'id': '3',
        'isVideo': true,
        'thumbnail': 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400',
        'title': 'Deadlift PR',
        'description': 'New personal record: 405 lbs!',
        'likes': 892,
        'comments': 134,
        'saves': 267,
        'shares': 89,
        'duration': '0:45',
        'timestamp': '1 week ago',
        'tags': ['#deadlift', '#pr', '#powerlifting'],
      },
      {
        'id': '4',
        'isVideo': false,
        'thumbnail': 'https://images.unsplash.com/photo-1532029837206-abbe2b7620e3?w=400',
        'title': 'Meal Prep Sunday',
        'description': 'High protein meals for the week',
        'likes': 234,
        'comments': 28,
        'saves': 156,
        'shares': 45,
        'timestamp': '1 week ago',
        'tags': ['#mealprep', '#nutrition', '#healthy'],
      },
      {
        'id': '5',
        'isVideo': true,
        'thumbnail': 'https://images.unsplash.com/photo-1549576490-b0b4831ef60a?w=400',
        'title': 'Morning Cardio',
        'description': 'Starting the day right!',
        'likes': 167,
        'comments': 19,
        'saves': 43,
        'shares': 12,
        'duration': '2:15',
        'timestamp': '2 weeks ago',
        'tags': ['#cardio', '#morning', '#running'],
      },
      {
        'id': '6',
        'isVideo': false,
        'thumbnail': 'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=400',
        'title': 'Gym Selfie',
        'description': 'Post-workout pump!',
        'likes': 521,
        'comments': 89,
        'saves': 78,
        'shares': 23,
        'timestamp': '2 weeks ago',
        'tags': ['#fitness', '#gym', '#motivation'],
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 1),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return GestureDetector(
          onTap: () => _navigateToPostDetail(post),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Post Image/Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  post['thumbnail'] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_kProfileForestGreen.withOpacity(0.35), _kProfileForestGreen.withOpacity(0.15)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
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

  void _navigateToPostDetail(Map<String, dynamic> post) {
    // Add creator info to post data
    final postWithCreator = {...post, 'creator': 'brogan seier', 'creatorInitials': 'BS', 'isLiked': false, 'isSaved': false};
    Get.toNamed(AppRoutes.postDetail, arguments: postWithCreator);
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
