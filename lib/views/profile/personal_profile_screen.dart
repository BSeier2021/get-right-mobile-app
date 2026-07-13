import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/models/customer_profile_dto.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/utils/customer_profile_enums.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/chat/chat_list_screen.dart';

/// Personal Profile screen – loads `GET /customer/profile` via [AuthController.fetchCustomerProfile].
class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({super.key});

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  final _storageService = Get.find<StorageService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<AuthController>()) {
        Get.find<AuthController>().fetchCustomerProfile();
      }
    });
  }

  String _formatSlugLabel(String slug) {
    final t = slug.trim();
    if (t.isEmpty) return '';
    if (!t.contains('_')) {
      return t.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    }
    return t.split('_').where((s) => s.isNotEmpty).map((s) => '${s[0].toUpperCase()}${s.length > 1 ? s.substring(1).toLowerCase() : ''}').join(' ');
  }

  String _displayName(CustomerProfileDto? p) {
    final n = p?.fullName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final local = _storageService.getName();
    if (local != null && local.trim().isNotEmpty) return local.trim();
    return 'Demo User';
  }

  String _displayEmail(CustomerProfileDto? p) {
    if (p != null) {
      final e = p.email.trim();
      if (e.isNotEmpty) return e;
    }
    return _storageService.getEmail()?.trim() ?? '';
  }

  String _displayDob(CustomerProfileDto? p) {
    final d = p?.dateofbirth?.trim();
    if (d != null && d.isNotEmpty) return d;
    return _storageService.getString('user_date_of_birth') ?? 'Not Set';
  }

  String _displayPhone(CustomerProfileDto? p) {
    final ph = p?.phoneNumber?.trim();
    if (ph != null && ph.isNotEmpty) return ph;
    return _storageService.getString('user_phone') ?? '+1234 567 8900';
  }

  String _displayGender(CustomerProfileDto? p) {
    final g = p?.gender?.trim();
    final raw = (g != null && g.isNotEmpty) ? g : _storageService.getString('user_gender');
    final api = GenderEnums.normalize(raw) ?? GenderEnums.male;
    return GenderEnums.displayForApi(api);
  }

  String _formatWeightValue(double value) {
    final formatted = value % 1 == 0 ? value.toInt().toString() : value.toString();
    return '$formatted kg';
  }

  String _displayWeight(CustomerProfileDto? p) {
    final w = p?.weight;
    if (w != null && w > 0) return _formatWeightValue(w);
    final local = _storageService.getString('user_weight');
    if (local != null && local.trim().isNotEmpty) {
      final parsed = double.tryParse(local.trim());
      if (parsed != null && parsed > 0) return _formatWeightValue(parsed);
    }
    return 'Not Set';
  }

  String _displayBio(CustomerProfileDto? p) {
    final b = p?.bio?.trim();
    if (b != null && b.isNotEmpty) return b;
    final local = _storageService.getString('user_bio');
    if (local != null && local.trim().isNotEmpty) return local.trim();
    return 'No Bio Added Yet';
  }

  /// When [profile] is non-null we already loaded `GET /customer/profile` successfully —
  /// onboarding rows must reflect the API only. Falling back to [StorageService] here made
  /// stale onboarding answers show even when the server returned empty `goals: []` etc.
  String _displayPreference(CustomerProfileDto? profile) {
    if (profile != null) {
      final prefName = profile.preferencesName?.trim();
      final prefDesc = profile.preferencesDescription?.trim();
      if (prefName != null && prefName.isNotEmpty) {
        if (prefDesc != null && prefDesc.isNotEmpty) return '$prefName\n$prefDesc';
        return prefName;
      }
      if (prefDesc != null && prefDesc.isNotEmpty) return prefDesc;
      final pf = profile.primaryFocus?.trim();
      if (pf != null && pf.isNotEmpty) return _formatSlugLabel(pf);
      return 'Not Set';
    }
    final local = _storageService.getUserPreference();
    if (local != null && local.trim().isNotEmpty) return local.trim();
    return 'Not Set';
  }

  String _displayGoals(CustomerProfileDto? profile) {
    if (profile != null) {
      if (profile.mainGoals.isNotEmpty) {
        return profile.mainGoals.map((g) => _formatSlugLabel(g)).join(', ');
      }
      return 'Not Set';
    }
    final local = _storageService.getUserGoals();
    if (local.isNotEmpty) return local.join(', ');
    return 'Not Set';
  }

  String _displayFitness(CustomerProfileDto? profile) {
    if (profile != null) {
      final f = profile.fitnessLevel?.trim();
      return (f != null && f.isNotEmpty) ? f : 'Not Set';
    }
    return _storageService.getFitnessLevel() ?? 'Not Set';
  }

  String _displayExerciseFreq(CustomerProfileDto? profile) {
    if (profile != null) {
      final x = profile.exerciseFrequency?.trim();
      if (x != null && x.isNotEmpty) {
        return CustomerProfileEnums.exerciseFrequencyDisplayFromApi(x);
      }
      return 'Not Set';
    }
    final local = _storageService.getExerciseFrequency();
    if (local != null && local.trim().isNotEmpty) {
      return CustomerProfileEnums.exerciseFrequencyDisplayFromApi(local.trim());
    }
    return 'Not Set';
  }

  bool _onboardingSectionHasAnyValue(CustomerProfileDto? profile) {
    if (profile == null) return false;
    final pref = _displayPreference(profile);
    final goals = _displayGoals(profile);
    final fit = _displayFitness(profile);
    final freq = _displayExerciseFreq(profile);
    return pref != 'Not Set' || goals != 'Not Set' || fit != 'Not Set' || freq != 'Not Set';
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
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Profile',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: GetBuilder<AuthController>(
        builder: (auth) {
          if (auth.customerProfileLoading && auth.customerProfile == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
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
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.85)),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => auth.fetchCustomerProfile(),
                      child: Text(
                        'Retry',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final p = auth.customerProfile;

          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () => auth.fetchCustomerProfile(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildProfileHeader(p),
                  const SizedBox(height: 28),
                  _sectionLabel('Personal Information'),
                  const SizedBox(height: 12),
                  _infoCard([
                    _infoRow('assets/images/profile00.png', 'Full Name', _displayName(p)),
                    _infoRow('assets/images/calendar-222.png', 'Date of Birth', _displayDob(p)),
                    _infoRow('assets/images/call.png', 'Contact Number', _displayPhone(p)),
                    _infoRow('assets/images/people22.png', 'Gender', _displayGender(p)),
                    _infoRow('assets/images/Vector.png', 'Weight', _displayWeight(p)),
                    _infoRow('assets/images/clipboard-text.png', 'Bio', _displayBio(p)),
                  ]),
                  if (_onboardingSectionHasAnyValue(p)) ...[
                    const SizedBox(height: 24),
                    _sectionLabel('Onboarding Preferences'),
                    const SizedBox(height: 12),
                    _infoCard([
                      _infoRow('assets/images/runing.png', 'Preferences', _displayPreference(p)),
                      _infoRow('assets/images/flag.png', 'Main goals', _displayGoals(p)),
                      _infoRow('assets/images/diagram.png', 'Fitness level', _displayFitness(p)),
                      _infoRow('assets/images/calendar-222.png', 'Exercise frequency', _displayExerciseFreq(p)),
                    ]),
                  ],
                  const SizedBox(height: 24),
                  _sectionLabel('Menu'),
                  const SizedBox(height: 12),
                  _menuRow(icon: Icons.favorite_outline, title: 'Favorites', subtitle: 'View your favorite posts and users', onTap: () => Get.toNamed(AppRoutes.favorites)),
                  _menuRow(icon: Icons.chat_bubble_outline, title: 'Chat', subtitle: 'View your conversations', onTap: () => Get.to(() => const ChatListScreen())),
                  _menuRow(
                    icon: Icons.receipt_long_outlined,
                    title: 'Transaction History',
                    subtitle: 'View your payment history',
                    onTap: () => Get.toNamed(AppRoutes.transactionHistory),
                  ),
                  const SizedBox(height: 8),
                  _logoutRow(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(CustomerProfileDto? p) {
    final url = p?.profilePictureUrl?.trim();
    final email = _displayEmail(p);

    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            width: 100.w,
            height: 100.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 2),
            ),
            child: ClipOval(
              child: url != null && url.isNotEmpty
                  ? Image.network(url, width: 92, height: 92, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset('assets/images/profile00.png', width: 48, height: 48))
                  : Image.asset('assets/images/profile00.png', width: 48, height: 48),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _displayName(p),
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.black, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(email.isNotEmpty ? email : '—', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Get.toNamed(AppRoutes.editProfile);
                if (result == true && Get.isRegistered<AuthController>()) {
                  await Get.find<AuthController>().fetchCustomerProfile();
                }
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

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w700, fontSize: 15),
    );
  }

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
                onPressed: () async {
                  Get.back();
                  final authController = Get.find<AuthController>();
                  await authController.logout();
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
