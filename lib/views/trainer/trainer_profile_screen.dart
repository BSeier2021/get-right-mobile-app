import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Trainer Profile Screen with Tabs
class TrainerProfileScreen extends StatefulWidget {
  const TrainerProfileScreen({super.key});

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, dynamic> trainer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    trainer = Get.arguments ?? _getMockTrainerData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: Text(trainer['name'], style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: PreferredSize(
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
        ),
      ),
      body: TabBarView(controller: _tabController, children: [_buildProfileTab(), _buildProgramsTab(), _buildTrainingTab()]),
    );
  }

  final _storageService = Get.find<StorageService>();

  String? _fullName;
  String? _dateOfBirth;
  String? _contactNumber;
  String? _bio;
  String? _gender;
  String? _preference;
  List<String> _goals = [];
  String? _fitnessLevel;
  String? _exerciseFrequency;

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

  // Profile Tab
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
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
                        radius: 45,
                        backgroundColor: AppColors.surface,
                        child: Icon(Icons.person, size: 50, color: AppColors.accent),
                      ),
                    ),
                    const SizedBox(height: 5),
                  ],
                ),
                const SizedBox(width: 20),
                _buildStatColumn('17', 'Posts'),
                _buildStatColumn('1250', 'Followers'),
                _buildStatColumn('342', 'Following'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Bio Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trainer['name'],
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(trainer['bio'], style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface.withOpacity(0.8), height: 1.6)),
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
    final posts = _getMockPosts();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4, childAspectRatio: 1),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return GestureDetector(
          onTap: () => Get.toNamed(AppRoutes.postDetail, arguments: post),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post['thumbnail'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.accent, AppColors.accent.withOpacity(0.6)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (post['isVideo'] as bool)
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
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
                const SizedBox(height: 12),
                SizedBox(
                  height: 200.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _getMockBundles().length,
                    itemBuilder: (context, index) {
                      return _buildBundleCard(_getMockBundles()[index]);
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
                ..._getMockPrograms('all').map((program) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildProgramCardVertical(program))),
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
      onTap: () => Get.toNamed(AppRoutes.programDetail, arguments: bundle),
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
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                bundle['imageUrl'],
                width: double.infinity,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentVariant])),
                  child: const Center(child: Icon(Icons.fitness_center, size: 40, color: Colors.white)),
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
                program['imageUrl'],
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
    return SingleChildScrollView(
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
                  child: Text(trainer['bio'], style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface.withOpacity(0.8), height: 1.7, letterSpacing: 0.3)),
                ),
              ],
            ),
          ),
          // Certifications Section (if available)
          if (trainer['certified'] && trainer['certifications'] != null) ...[
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
