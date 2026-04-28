import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/constants/app_constants.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/utils/customer_profile_enums.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_button.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Edit profile screen - Redesigned to match app theme
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const List<String> _fitnessLevelOptions = ['Beginner', 'Intermediate', 'Advanced', 'Professional'];

  static const List<Map<String, String>> _exerciseFrequencyOptions = [
    {'value': 'Daily', 'title': 'Daily'},
    {'value': 'Weekly', 'title': 'Weekly'},
    {'value': 'TwiceaWeek', 'title': 'Twice a Week'},
    {'value': 'ThreeTimesaWeek', 'title': 'Three Times a Week'},
    {'value': 'FourTimesaWeek', 'title': 'Four Times a Week'},
    {'value': 'FiveTimesaWeek', 'title': 'Five Times a Week'},
    {'value': 'SixTimesaWeek', 'title': 'Six Times a Week'},
  ];

  final _formKey = GlobalKey<FormState>();
  final _storageService = Get.find<StorageService>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _dobController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _medicalConditionsController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();

  String? _selectedGender;
  // Default to metric
  String? _profileImagePath;

  /// `GET /user/preferences` → [UserPreferenceOption.value] for `primaryFocus`.
  String? _primaryFocusValue;

  /// `GET /user/goals` → [UserGoalOption.value] slugs for `mainGoals`.
  final Set<String> _mainGoalSlugs = {};

  /// `GET /user/fitness-level` → [FitnessLevelOption.value].
  String? _fitnessLevelValue;

  /// `GET /user/exercise-plan` → [ExercisePlanOption.value].
  String? _exercisePlanValue;

  /// Remote avatar when no new local file is selected.
  String? _existingPhotoUrl;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Defer load: [fetchCustomerProfile] calls `AuthController.update()` which must not run during this route's first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSavedPreferences();
    });
  }

  Future<void> _loadSavedPreferences() async {
    setState(() => _isLoading = true);

    final auth = Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    if (auth != null) {
      await Future.wait([auth.fetchCustomerProfile(), auth.fetchPreferences(), auth.fetchGoals()]);
    }

    final p = auth?.customerProfile;

    final name = (p?.fullName != null && p!.fullName!.trim().isNotEmpty) ? p.fullName!.trim() : (_storageService.getName() ?? '');
    _firstNameController.text = name;

    final dob = p?.dateofbirth?.trim();
    _dobController.text = (dob != null && dob.isNotEmpty) ? dob : (_storageService.getString('user_date_of_birth') ?? '');

    final phone = p?.phoneNumber?.trim();
    _phoneController.text = (phone != null && phone.isNotEmpty) ? phone : (_storageService.getString('user_phone') ?? '');

    final bio = p?.bio?.trim();
    _bioController.text = (bio != null && bio.isNotEmpty) ? bio : (_storageService.getString('user_bio') ?? '');

    _selectedGender = p?.gender?.trim().isNotEmpty == true ? p!.gender!.trim() : _storageService.getString('user_gender');

    _primaryFocusValue = null;
    if (p?.primaryFocus != null && p!.primaryFocus!.trim().isNotEmpty) {
      final slug = p.primaryFocus!.trim();
      if (auth != null && auth.preferences.any((e) => e.value == slug)) {
        _primaryFocusValue = slug;
      } else if (CustomerProfileEnums.isValidPrimaryFocus(slug)) {
        _primaryFocusValue = slug;
      }
    }
    if (_primaryFocusValue == null && auth != null) {
      final stored = _storageService.getUserPreference();
      if (stored != null && stored.trim().isNotEmpty) {
        final s = CustomerProfileEnums.normalizePrimaryFocus(stored.trim());
        if (s != null && auth.preferences.any((e) => e.value == s)) {
          _primaryFocusValue = s;
        }
      }
    }

    _mainGoalSlugs.clear();
    if (p != null && p.mainGoals.isNotEmpty) {
      for (final raw in p.mainGoals) {
        final slug = raw.toString().trim();
        if (slug.isEmpty) continue;
        if (auth != null && auth.goals.any((g) => g.value == slug)) {
          _mainGoalSlugs.add(slug);
        } else if (CustomerProfileEnums.isValidMainGoal(slug)) {
          _mainGoalSlugs.add(slug);
        }
      }
    }
    if (_mainGoalSlugs.isEmpty && auth != null) {
      for (final name in _storageService.getUserGoals()) {
        final s = CustomerProfileEnums.normalizeMainGoal(name);
        if (s != null && auth.goals.any((g) => g.value == s)) {
          _mainGoalSlugs.add(s);
        }
      }
    }

    _fitnessLevelValue = p?.fitnessLevel?.trim();
    if (_fitnessLevelValue != null && _fitnessLevelValue!.isNotEmpty && !_fitnessLevelOptions.contains(_fitnessLevelValue)) {
      _fitnessLevelValue = null;
    }
    final storedFitnessLevel = _storageService.getFitnessLevel();
    if (_fitnessLevelValue == null && storedFitnessLevel != null && storedFitnessLevel.trim().isNotEmpty && _fitnessLevelOptions.contains(storedFitnessLevel.trim())) {
      _fitnessLevelValue = storedFitnessLevel.trim();
    }

    _exercisePlanValue = p?.exerciseFrequency?.trim();
    if (_exercisePlanValue != null && _exercisePlanValue!.isNotEmpty && !_exerciseFrequencyOptions.any((e) => e['value'] == _exercisePlanValue)) {
      _exercisePlanValue = null;
    }
    final storedExerciseFrequency = _storageService.getExerciseFrequency();
    if ((_exercisePlanValue == null || _exercisePlanValue!.isEmpty) && storedExerciseFrequency != null && storedExerciseFrequency.trim().isNotEmpty) {
      final t = storedExerciseFrequency.trim();
      if (_exerciseFrequencyOptions.any((e) => e['value'] == t)) {
        _exercisePlanValue = t;
      }
    }

    _existingPhotoUrl = p?.profilePictureUrl?.trim().isNotEmpty == true ? p!.profilePictureUrl!.trim() : null;

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _dobController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _medicalConditionsController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (!Get.isRegistered<AuthController>()) return;

    final auth = Get.find<AuthController>();
    final fullName = _firstNameController.text.trim();
    if (fullName.isEmpty) {
      Get.snackbar('Profile', 'Please enter your full name', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final mainSlugs = CustomerProfileEnums.filterMainGoals(_mainGoalSlugs);

    final ok = await auth.updateCustomerProfileFromEdit(
      fullName: fullName,
      dateofbirth: _dobController.text.trim().isEmpty ? null : _dobController.text.trim(),
      gender: _selectedGender,
      phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      primaryFocus: CustomerProfileEnums.isValidPrimaryFocus(_primaryFocusValue) ? _primaryFocusValue : null,
      mainGoals: mainSlugs.isEmpty ? null : mainSlugs,
      fitnessLevel: _fitnessLevelValue,
      exerciseFrequency: _exercisePlanValue,
      profilePicturePath: _profileImagePath,
    );

    if (!mounted) return;
    if (!ok) return;

    setState(() {
      _profileImagePath = null;
      _existingPhotoUrl = auth.customerProfile?.profilePictureUrl?.trim();
    });

    Get.snackbar(
      'Success',
      'Profile updated successfully!',
      backgroundColor: AppColors.accent,
      colorText: AppColors.onAccent,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
    Get.back(result: true);
  }

  void _pickProfileImage() {
    Get.dialog(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Profile Picture',
                style: AppTextStyles.headlineMedium.copyWith(color: AppColors.onBackground, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),

              // Gallery option
              InkWell(
                onTap: () async {
                  Get.back();
                  await _pickImageFromSource(ImageSource.gallery);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.photo_library_rounded, color: AppColors.accent, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gallery',
                              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text('Choose from your photos', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontSize: 13)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.primaryGray),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Camera option
              InkWell(
                onTap: () async {
                  Get.back();
                  await _pickImageFromSource(ImageSource.camera);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.camera_alt_rounded, color: AppColors.accent, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Camera',
                              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text('Take a new photo', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontSize: 13)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.primaryGray),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cancel button
              TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicturePicker() {
    return GestureDetector(
      onTap: _pickProfileImage,
      child: Stack(
        children: [
          Container(
            width: 100.w,
            height: 100.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 2),
              boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.1), blurRadius: 20, spreadRadius: 0, offset: const Offset(0, 8))],
            ),
            child: _profileImagePath != null
                ? ClipOval(
                    child: Image.file(
                      File(_profileImagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.person_outline_rounded, size: 50, color: AppColors.primaryGray);
                      },
                    ),
                  )
                : (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty)
                ? ClipOval(
                    child: Image.network(
                      _existingPhotoUrl!,
                      fit: BoxFit.cover,
                      width: 100.w,
                      height: 100.h,
                      errorBuilder: (_, __, ___) => Icon(Icons.add_a_photo_outlined, size: 30, color: AppColors.primaryGray),
                    ),
                  )
                : Icon(Icons.add_a_photo_outlined, size: 30, color: AppColors.primaryGray),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 18, color: AppColors.onAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      PermissionStatus status;
      if (source == ImageSource.camera) {
        status = await Permission.camera.request();
      } else {
        status = await Permission.photos.request();
        if (!status.isGranted && Platform.isAndroid) {
          status = await Permission.storage.request();
        }
      }

      if (!status.isGranted && !status.isLimited) {
        final shouldOpenSettings = status.isPermanentlyDenied || status.isRestricted;
        Get.snackbar(
          'Permission required',
          source == ImageSource.camera ? 'Camera permission is required to take a photo.' : 'Gallery permission is required to choose a photo.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          mainButton: shouldOpenSettings
              ? TextButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Settings', style: TextStyle(color: Colors.white)),
                )
              : null,
        );
        return;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);

      if (image != null) {
        setState(() {
          _profileImagePath = image.path;
        });

        Get.snackbar(
          'Success',
          'Profile picture selected',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.accent,
          colorText: AppColors.onAccent,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick image: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
        title: Text('Edit Profile', style: AppTextStyles.titleLarge.copyWith()),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Photo Section
                    Center(child: _buildProfilePicturePicker()),

                    const SizedBox(height: 32),

                    // Personal Information Section
                    _buildSectionHeader('Personal Information', Icons.person_outline),
                    const SizedBox(height: 16),

                    CustomTextField(controller: _firstNameController, labelText: 'Full Name', hintText: 'Enter your full name'),
                    const SizedBox(height: 16),
                    _buildSectionHeader('Date of Birth', Icons.cake_outlined),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _dobController.text.isNotEmpty ? DateTime.tryParse(_dobController.text) ?? DateTime(2000) : DateTime(2000),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _dobController.text = picked.toIso8601String().split('T').first;
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: CustomTextField(
                          controller: _dobController,
                          labelText: 'Date of Birth',
                          hintText: 'Date of Birth',
                          // validator: (value) {
                          //   if (value == null || value.isEmpty) {
                          //     return 'Date of Birth is required';
                          //   }
                          //   final date = DateTime.tryParse(value);
                          //   if (date == null) {
                          //     return 'Please enter a valid date';
                          //   }
                          //   if (date.isAfter(DateTime.now())) {
                          //     return 'Date of Birth cannot be in the future';
                          //   }
                          //   return null;
                          // },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionHeader('Contact Number', Icons.phone_outlined),
                    const SizedBox(height: 12),
                    // Phone Number
                    CustomTextField(controller: _phoneController, labelText: 'Contact Number', hintText: '+1 234 567 8900', keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildSectionHeader('Bio', Icons.edit_note),
                    const SizedBox(height: 12),
                    CustomTextField(controller: _bioController, labelText: 'Bio (Optional)', hintText: 'Tell us about yourself...', maxLines: 3),
                    const SizedBox(height: 32),

                    // Gender Selection
                    _buildSectionHeader('Gender', Icons.wc_outlined),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      label: 'Gender',
                      value: _selectedGender,
                      items: AppConstants.genderOptions,
                      icon: Icons.wc_outlined,
                      onChanged: (value) => setState(() => _selectedGender = value),
                    ),
                    const SizedBox(height: 32),

                    // Onboarding Questionnaire — data from GET /user/preferences, /user/goals, /user/fitness-level, /user/exercise-plan
                    _buildSectionHeader('Onboarding Preferences', Icons.quiz_outlined),
                    const SizedBox(height: 16),
                    if (Get.isRegistered<AuthController>())
                      GetBuilder<AuthController>(
                        builder: (auth) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'What\'s your preference?',
                                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text('Choose your primary focus to personalize your experience', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                              const SizedBox(height: 12),
                              _buildPreferenceDropdown(auth),
                              const SizedBox(height: 24),
                              Text(
                                'What\'s your main goal?',
                                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This helps us recommend the best features for you. Select all that apply',
                                style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
                              ),
                              const SizedBox(height: 12),
                              _buildGoalsChips(auth),
                              const SizedBox(height: 24),
                              Text(
                                'What\'s your fitness level?',
                                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text('We\'ll adjust recommendations based on your experience', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                              const SizedBox(height: 12),
                              _buildFitnessDropdown(auth),
                              const SizedBox(height: 24),
                              Text(
                                'How often do you plan to exercise?',
                                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text('This helps us create realistic goals for you', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                              const SizedBox(height: 12),
                              _buildExercisePlanDropdown(auth),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 32),

                    // Save Button
                    GetBuilder<AuthController>(
                      builder: (auth) => CustomButton(text: 'Save Changes', isLoading: auth.isLoading, onPressed: _saveProfile),
                    ),
                    const SizedBox(height: 16),

                    // Cancel Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryGray, width: 2),
                          foregroundColor: AppColors.onBackground,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        ),
                        child: Text('Cancel', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onBackground)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  String? _dropdownValueIfInList(String? value, List<DropdownMenuItem<String>> items) {
    if (value == null) return null;
    return items.any((e) => e.value == value) ? value : null;
  }

  Widget _buildValueDropdown({required String label, required String? value, required List<DropdownMenuItem<String>> items, required ValueChanged<String?> onChanged}) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('No options available', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
      );
    }
    final effective = _dropdownValueIfInList(value, items);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1.5),
      ),
      child: DropdownButtonFormField<String>(
        value: effective,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, fontSize: 15, fontWeight: FontWeight.w500),
          floatingLabelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontSize: 15, fontWeight: FontWeight.w500),
        dropdownColor: AppColors.surface,
        icon: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryGray),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPreferenceDropdown(AuthController auth) {
    if (auth.preferencesLoading && auth.preferences.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
        ),
      );
    }
    if (auth.preferencesError != null && auth.preferences.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(auth.preferencesError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
          TextButton(
            onPressed: () async {
              await auth.fetchPreferences();
              if (mounted) setState(() {});
            },
            child: Text(
              'Retry',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }
    final items = auth.preferences.map((e) => DropdownMenuItem<String>(value: e.value, child: Text(e.name))).toList();
    return _buildValueDropdown(label: 'Preference', value: _primaryFocusValue, items: items, onChanged: (v) => setState(() => _primaryFocusValue = v));
  }

  Widget _buildGoalsChips(AuthController auth) {
    if (auth.goalsLoading && auth.goals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
        ),
      );
    }
    if (auth.goalsError != null && auth.goals.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(auth.goalsError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
          TextButton(
            onPressed: () async {
              await auth.fetchGoals();
              if (mounted) setState(() {});
            },
            child: Text(
              'Retry',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }
    if (auth.goals.isEmpty) {
      return Text('No goals available', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray));
    }
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.18), width: 1),
        boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: auth.goals.map((g) {
          final isSelected = _mainGoalSlugs.contains(g.value);
          return FilterChip(
            label: Text(g.name),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _mainGoalSlugs.add(g.value);
                } else {
                  _mainGoalSlugs.remove(g.value);
                }
              });
            },
            selectedColor: AppColors.accent.withOpacity(0.18),
            labelStyle: TextStyle(color: AppColors.onBackground, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500),
            backgroundColor: AppColors.accent.withOpacity(0.08),
            checkmarkColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
              side: BorderSide(color: isSelected ? AppColors.accent : AppColors.primaryGray.withOpacity(0.25), width: 1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFitnessDropdown(AuthController auth) {
    final items = _fitnessLevelOptions.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList();
    return _buildValueDropdown(label: 'Fitness Level', value: _fitnessLevelValue, items: items, onChanged: (v) => setState(() => _fitnessLevelValue = v));
  }

  Widget _buildExercisePlanDropdown(AuthController auth) {
    final items = _exerciseFrequencyOptions.map((e) => DropdownMenuItem<String>(value: e['value'], child: Text(e['title'] ?? e['value'] ?? ''))).toList();
    return _buildValueDropdown(label: 'Exercise Frequency', value: _exercisePlanValue, items: items, onChanged: (v) => setState(() => _exercisePlanValue = v));
  }

  Widget _buildDropdownField({required String label, required String? value, required List<String> items, required IconData icon, required ValueChanged<String?> onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1.5),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, fontSize: 15, fontWeight: FontWeight.w500),
          floatingLabelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontSize: 15, fontWeight: FontWeight.w500),
        dropdownColor: AppColors.surface,
        icon: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryGray),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        // Container(
        //   padding: const EdgeInsets.all(8),
        //   decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
        //   child: Icon(icon, color: AppColors.accent, size: 20),
        // ),
        Text(title, style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
      ],
    );
  }
}
