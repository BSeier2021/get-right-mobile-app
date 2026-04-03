import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/chat/chat_list_screen.dart';

/// Personal Profile screen – matches the screenshot design
class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({super.key});

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  final _storageService = Get.find<StorageService>();

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
    _loadProfileData();
  }

  void _loadProfileData() {
    setState(() {
      _fullName = _storageService.getName();
      _dateOfBirth = _storageService.getString('user_date_of_birth');
      _contactNumber = _storageService.getString('user_phone');
      _bio = _storageService.getString('user_bio');
      _gender = _storageService.getString('user_gender');
      _preference = _storageService.getUserPreference();
      _goals = _storageService.getUserGoals();
      _fitnessLevel = _storageService.getFitnessLevel();
      _exerciseFrequency = _storageService.getExerciseFrequency();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withOpacity(0.15), width: 1),
            ),
            child: const Icon(Icons.chevron_left, color: AppColors.accent, size: 20),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Profile',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ── Profile Header ──────────────────────────────────
            _buildProfileHeader(),
            const SizedBox(height: 28),

            // ── Personal Information ────────────────────────────
            _sectionLabel('Personal Information'),
            const SizedBox(height: 12),
            _infoCard([
              _infoRow('assets/images/profile00.png', 'Full Name', _fullName ?? 'Demo User'),
              _infoRow('assets/images/calendar-222.png', 'Date of Birth', _dateOfBirth ?? 'Not Set'),
              _infoRow('assets/images/call.png', 'Contact Number', _contactNumber ?? '+1234 567 8900'),
              _infoRow('assets/images/people22.png', 'Gender', _gender ?? 'Male'),
              _infoRow('assets/images/clipboard-text.png', 'Bio', _bio != null && _bio!.isNotEmpty ? _bio! : 'No Bio Added Yet'),
            ]),
            const SizedBox(height: 24),

            // ── Onboarding Preferences ──────────────────────────
            _sectionLabel('Onboarding Preferences'),
            const SizedBox(height: 12),
            _infoCard([
              _infoRow('assets/images/Vector.png', 'Preference', _preference ?? 'Not Set'),
              _infoRow('assets/images/flag.png', 'Goals', _goals.isNotEmpty ? _goals.join(', ') : 'Not Set'),
              _infoRow('assets/images/diagram.png', 'Fitness Level', _fitnessLevel ?? 'Not Set'),
              _infoRow('assets/images/calendar-222.png', 'Exercise Frequency', _exerciseFrequency ?? 'Not Set'),
            ]),
            const SizedBox(height: 24),

            // ── Menu ─────────────────────────────────────────────
            _sectionLabel('Menu'),
            const SizedBox(height: 12),
            _menuRow(icon: Icons.favorite_outline, title: 'Favorites', subtitle: 'View your favorite posts and users', onTap: () => Get.toNamed(AppRoutes.favorites)),
            _menuRow(icon: Icons.bookmark_outline, title: 'Saved Posts', subtitle: 'Access your saved posts', onTap: () => Get.toNamed(AppRoutes.savedPosts)),
            _menuRow(icon: Icons.chat_bubble_outline, title: 'Chat', subtitle: 'View your conversations', onTap: () => Get.to(() => const ChatListScreen())),
            _menuRow(
              icon: Icons.receipt_long_outlined,
              title: 'Transaction History',
              subtitle: 'View your payment history',
              onTap: () => Get.toNamed(AppRoutes.transactionHistory),
            ),
            const SizedBox(height: 8),

            // ── Logout ────────────────────────────────────────────
            _logoutRow(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Profile Header: avatar + name + email + Edit Profile button
  // ────────────────────────────────────────────────────────────────
  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          // Avatar with camera badge
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 2),
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: const Color(0xFFE0F0D8),
                  child: Icon(Icons.person, size: 48, color: AppColors.accent),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () async {
                    final result = await Get.toNamed(AppRoutes.editProfile);
                    if (result == true) _loadProfileData();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.backgroundColor, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 14, color: AppColors.onAccent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _fullName ?? 'Billy Kane',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.black, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('billykane@domain.com', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
          const SizedBox(height: 16),
          // Edit Profile pill button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Get.toNamed(AppRoutes.editProfile);
                if (result == true) _loadProfileData();
              },
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentVariant,
                foregroundColor: AppColors.onAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                textStyle: AppTextStyles.buttonMedium.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Section label
  // ────────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w700, fontSize: 15),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Info card – groups rows inside a rounded container
  // ────────────────────────────────────────────────────────────────
  Widget _infoCard(List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6F0DA), width: 1),
      ),
      child: Column(children: rows),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Info row (image + label + value) — used inside _infoCard
  // ────────────────────────────────────────────────────────────────
  Widget _infoRow(String image, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), shape: BoxShape.circle),
            child: Image.asset(image),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 11.5)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Menu row (icon + title + subtitle + chevron)
  // ────────────────────────────────────────────────────────────────
  Widget _menuRow({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FFE9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6F0DA), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primaryGray, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Logout row
  // ────────────────────────────────────────────────────────────────
  Widget _logoutRow() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Get.dialog(
          AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Logout', style: AppTextStyles.titleLarge),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.onError,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0EE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE85050).withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: const Color(0xFFE85050).withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.logout, color: Color(0xFFE85050), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Logout',
                    style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFFE85050), fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text('Sign out of your account', style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFFE85050).withOpacity(0.7), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFE85050), size: 22),
          ],
        ),
      ),
    );
  }
}
