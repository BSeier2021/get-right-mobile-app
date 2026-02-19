import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';
import 'package:get_right/views/chat/chat_list_screen.dart';
import 'package:intl/intl.dart';

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
  final bool showOnlyPublic;

  const ProfileScreen({super.key, this.hideAppBar = false, this.showOnlyPublic = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _storageService = Get.find<StorageService>();
  List<PersonalRecord> _personalRecords = [];

  // Profile data
  String? _fullName;
  String? _dateOfBirth;
  String? _contactNumber;
  String? _bio;
  String? _gender;
  String? _preference;
  List<String> _goals = [];
  String? _fitnessLevel;
  String? _exerciseFrequency;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Initialize with default records
    _personalRecords = [
      PersonalRecord(id: '1', liftName: 'Bench Press', value: '315', unit: 'lbs', date: DateTime(2024, 12, 12), displayPublicly: true),
      PersonalRecord(id: '2', liftName: 'Squat', value: '405', unit: 'lbs', date: DateTime(2024, 12, 10), displayPublicly: true),
    ];
    _loadProfileData();
  }

  void _loadProfileData() {
    // Load profile data from StorageService
    // Note: Some fields like fullName, dateOfBirth, contactNumber, bio might need to be stored separately
    // For now, we'll load what's available from StorageService
    setState(() {
      _gender = _storageService.getString('user_gender');
      _preference = _storageService.getUserPreference();
      _goals = _storageService.getUserGoals();
      _fitnessLevel = _storageService.getFitnessLevel();
      _exerciseFrequency = _storageService.getExerciseFrequency();
      _bio = _storageService.getString('user_bio');
      _fullName = _storageService.getName();
      _dateOfBirth = _storageService.getString('user_date_of_birth');
      _contactNumber = _storageService.getString('user_phone');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabBar = Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.primaryGrayLight.withOpacity(0.3), borderRadius: BorderRadius.circular(14)),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent.withOpacity(0.85)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppColors.onAccent,
          unselectedLabelColor: AppColors.onSurface.withOpacity(0.6),
          labelStyle: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3),
          unselectedLabelStyle: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Public'),
            Tab(text: 'Personal'),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              leading: Obx(() {
                final notificationController = Get.find<NotificationController>();
                final unreadCount = notificationController.unreadCount;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 3,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(color: Color(0xFF29603C), borderRadius: BorderRadius.circular(2)),
                          ),
                          Container(
                            width: 25,
                            height: 3,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(color: Color(0xFF29603C), borderRadius: BorderRadius.circular(2)),
                          ),
                          Container(
                            width: 20,
                            height: 3,
                            decoration: BoxDecoration(color: Color(0xFF29603C), borderRadius: BorderRadius.circular(2)),
                          ),
                        ],
                      ),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ).paddingOnly(left: 10),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 8,
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
              title: Text('Profile', style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent)),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: AppColors.accent),
                  onPressed: () => Get.toNamed(AppRoutes.settings),
                ),
              ],
              bottom: PreferredSize(preferredSize: const Size.fromHeight(68), child: tabBar),
            ),
      body: widget.showOnlyPublic
          ? _buildPublicProfile()
          : Column(
              children: [
                if (widget.hideAppBar) tabBar,
                Expanded(
                  child: TabBarView(controller: _tabController, children: [_buildPublicProfile(), _buildPersonalProfile()]),
                ),
              ],
            ),
    );
  }

  Widget _buildPublicProfile() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Profile Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Profile Picture
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
                        radius: 45,
                        backgroundColor: AppColors.surface,
                        child: Icon(Icons.person, size: 50, color: AppColors.accent),
                      ),
                    ),
                    const SizedBox(height: 5),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await Get.toNamed(AppRoutes.editProfile);
                        if (result == true) _loadProfileData();
                      },
                      icon: const Icon(Icons.edit, size: 10),
                      label: Text('Edit Info', style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: const BorderSide(color: AppColors.accent, width: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                // Stats
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('6', 'Posts'),
                      _buildStatColumn('1247', 'Followers', onTap: () => Get.toNamed(AppRoutes.followers)),
                      _buildStatColumn('342', 'Following', onTap: () => Get.toNamed(AppRoutes.following)),
                    ],
                  ).paddingOnly(bottom: 30),
                ),
              ],
            ),
          ),

          // Personal Records Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Personal Records',
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.edit, color: AppColors.accent, size: 18),
                      ),
                      onPressed: _showEditPersonalRecordsDialog,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _personalRecords.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1),
                        ),
                        child: Center(
                          child: Text(
                            'No personal records yet.\nTap edit to add your records.',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _buildPersonalRecordsGrid(),
              ],
            ),
          ),
          const SizedBox(height: 24),

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
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 20),
                        onPressed: _showCreatePostOptions,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
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

  Widget _buildPersonalProfile() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Profile Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Profile Avatar
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent, width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.accent.withOpacity(0.2),
                        child: Icon(Icons.person, size: 50, color: AppColors.accent),
                      ),
                    ),

                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () async {
                          final result = await Get.toNamed(AppRoutes.editProfile);
                          if (result == true) {
                            // Reload profile data when returning from edit screen
                            _loadProfileData();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 2),
                          ),
                          child: const Icon(Icons.edit, size: 16, color: AppColors.onAccent),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(_fullName ?? "User Name", style: AppTextStyles.headlineMedium.copyWith(color: AppColors.onBackground)),
                const SizedBox(height: 4),
                Text(_storageService.getEmail() ?? "user@example.com", style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                const SizedBox(height: 16),
                SizedBox(
                  width: 180,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Get.toNamed(AppRoutes.editProfile);
                      if (result == true) {
                        // Reload profile data when returning from edit screen
                        _loadProfileData();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.onAccent, elevation: 0),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit Profile'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Personal Information Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Personal Information", style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGray, width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('Full Name', _fullName ?? 'Not set', Icons.person_outline),
                      const Divider(height: 24, color: AppColors.primaryGray),

                      _buildInfoRow('Date of Birth', _dateOfBirth ?? 'Not set', Icons.cake_outlined),
                      const Divider(height: 24, color: AppColors.primaryGray),
                      _buildInfoRow('Contact Number', _contactNumber ?? '52165168', Icons.phone_outlined),
                      const Divider(height: 24, color: AppColors.primaryGray),
                      _buildInfoRow('Gender', _gender ?? 'Male', Icons.wc),
                      const Divider(height: 24, color: AppColors.primaryGray),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Bio Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGray, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_note, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          Text('Bio', style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _bio ?? 'No bio added yet.',
                        style: AppTextStyles.bodyMedium.copyWith(color: _bio != null && _bio!.isNotEmpty ? AppColors.onSurface : AppColors.primaryGray),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Onboarding Preferences Card
                if (_preference != null || _goals.isNotEmpty || _fitnessLevel != null || _exerciseFrequency != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryGray, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.quiz_outlined, color: AppColors.accent, size: 20),
                            const SizedBox(width: 8),
                            Text('Onboarding Preferences', style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_preference != null) ...[_buildPreferenceInfoRow('Preference', _preference!, Icons.fitness_center), const SizedBox(height: 12)],
                        if (_goals.isNotEmpty) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.flag_outlined, color: AppColors.accent, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Goals', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                                    const SizedBox(height: 8),
                                    Wrap(spacing: 8, runSpacing: 8, children: _goals.map((goal) => _buildPreferenceChip(goal)).toList()),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_fitnessLevel != null) ...[_buildPreferenceInfoRow('Fitness Level', _fitnessLevel!, Icons.trending_up), const SizedBox(height: 12)],
                        if (_exerciseFrequency != null) _buildPreferenceInfoRow('Exercise Frequency', _exerciseFrequency!, Icons.calendar_today),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Menu Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text("Menu", style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
                const SizedBox(height: 12),
                _buildMenuCard(icon: Icons.favorite_outline, title: 'Favorites', subtitle: 'View your favorite posts and users', onTap: () => Get.toNamed(AppRoutes.favorites)),
                const SizedBox(height: 12),
                _buildMenuCard(icon: Icons.bookmark_outline, title: 'Saved Posts', subtitle: 'Access your saved posts', onTap: () => Get.toNamed(AppRoutes.savedPosts)),
                const SizedBox(height: 12),
                _buildMenuCard(icon: Icons.chat_bubble_outline, title: 'Chat', subtitle: 'View your conversations', onTap: () => Get.to(() => const ChatListScreen())),
                const SizedBox(height: 12),
                _buildMenuCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Transaction History',
                  subtitle: 'View your payment history',
                  onTap: () => Get.toNamed(AppRoutes.transactionHistory),
                ),
                const SizedBox(height: 24),
                _buildLogoutCard(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String count, String label, {VoidCallback? onTap}) {
    final widget = Column(
      children: [
        Text(
          count,
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
      ],
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: widget);
    }

    return widget;
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

  Widget _buildPersonalRecordCard(PersonalRecord record) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final displayValue = record.displayPublicly ? '${record.value} ${record.unit}' : 'Hidden';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.liftName,
            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            displayValue,
            style: AppTextStyles.headlineSmall.copyWith(color: record.displayPublicly ? AppColors.accent : AppColors.primaryGray, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(dateFormat.format(record.date), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4, childAspectRatio: 1),
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
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post['thumbnail'] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.accent, AppColors.accent.withOpacity(0.6)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              // Gradient overlay for better icon visibility
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.3)]),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              // Video play icon
              if (post['isVideo'] as bool)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                    child: Icon(Icons.play_arrow, color: Colors.white.withOpacity(0.9), size: 28),
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

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
              const SizedBox(height: 4),
              Text(value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent, width: 1),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMenuCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.primaryGray, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutCard() {
    return GestureDetector(
      onTap: () {
        Get.dialog(
          AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Logout', style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent)),
            content: Text('Are you sure you want to logout?', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Cancel', style: TextStyle(color: AppColors.primaryGray)),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  final authController = Get.find<AuthController>();
                  authController.logout();
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.onError),
                child: const Text('Logout'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.logout, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Logout', style: AppTextStyles.titleSmall.copyWith(color: AppColors.error)),
                  const SizedBox(height: 2),
                  Text('Sign out of your account', style: AppTextStyles.labelSmall.copyWith(color: AppColors.error.withOpacity(0.8))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.error, size: 24),
          ],
        ),
      ),
    );
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
                  child: Icon(icon, color: Colors.white, size: 28),
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
