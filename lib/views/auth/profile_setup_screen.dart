import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get_right/constants/app_constants.dart';
import 'package:get_right/utils/customer_profile_enums.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/no_emoji_input_formatter.dart';
import 'package:get_right/widgets/common/custom_button.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';

/// Profile Setup screen - post-signup profile completion
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> with SingleTickerProviderStateMixin {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _weightController = TextEditingController();
  final _bioController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _profileImageFile;

  DateTime? _dateOfBirth;
  String? _selectedGender;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _weightController.dispose();
    _bioController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.accent, onPrimary: AppColors.onAccent, surface: Colors.white, onSurface: AppColors.onBackground),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  Future<void> _continue() async {
    final name = _fullNameController.text.trim();
    if (name.isEmpty) {
      Get.snackbar('Profile', 'Please enter your full name', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_dateOfBirth == null) {
      Get.snackbar('Profile', 'Please select your date of birth', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (!GenderEnums.isValid(_selectedGender)) {
      Get.snackbar('Profile', 'Please select your gender', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      Get.snackbar('Profile', 'Please enter your phone number', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (!RegExp(r'^\d+$').hasMatch(phone)) {
      Get.snackbar('Profile', 'Phone number must contain digits only', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (phone.length < 8 || phone.length > 15) {
      Get.snackbar('Profile', 'Phone number must be between 8 and 15 digits', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final weightText = _weightController.text.trim();
    if (weightText.isEmpty) {
      Get.snackbar('Profile', 'Please enter your weight', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final weight = double.tryParse(weightText);
    if (weight == null || weight <= 0) {
      Get.snackbar('Profile', 'Please enter a valid weight', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (weight < 20 || weight > 500) {
      Get.snackbar('Profile', 'Please enter a weight between 20 and 500 kg', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final dob = DateFormat('yyyy-MM-dd').format(_dateOfBirth!);
    final authController = Get.find<AuthController>();
    final bio = _bioController.text.trim();
    await authController.createProfile(
      fullName: name,
      dateofbirth: dob,
      gender: _selectedGender!,
      phoneNumber: phone,
      weight: weight % 1 == 0 ? weight.toInt() : weight,
      bio: bio.isNotEmpty ? bio : null,
      profilePicture: _profileImageFile,
    );
  }

  Future<void> _showImageSourceDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Image'),
          content: const Text('Choose image source'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _pickProfileImage(ImageSource.camera);
              },
              child: const Text('Camera'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _pickProfileImage(ImageSource.gallery);
              },
              child: const Text('Gallery'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickProfileImage(ImageSource source) async {
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
        if (!mounted) return;
        final shouldOpenSettings = status.isPermanentlyDenied || status.isRestricted;
        Get.snackbar(
          'Permission required',
          source == ImageSource.camera ? 'Camera permission is required to take a photo.' : 'Gallery permission is required to choose a photo.',
          snackPosition: SnackPosition.BOTTOM,
          mainButton: shouldOpenSettings ? TextButton(onPressed: () => openAppSettings(), child: const Text('Settings')) : null,
        );
        return;
      }

      final XFile? image = await _imagePicker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (image == null) return;
      if (!mounted) return;
      setState(() {
        _profileImageFile = File(image.path);
      });
    } catch (_) {
      if (!mounted) return;
      Get.snackbar('Error', 'Unable to pick image. Please try again.', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _handleBack() {
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
      return;
    }
    Get.offAllNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _handleBack(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 16.w, top: 8),
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
                          ),
                          onPressed: _handleBack,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            'Welcome to\nGetRight',
                            style: AppTextStyles.headlineLarge.copyWith(color: AppColors.onBackground, fontSize: 35.sp, fontWeight: FontWeight.w600, height: 1.05),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Create an account to access your personal fitness\njournal, workout programs, and more.',
                            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onBackground.withValues(alpha: 0.8), fontSize: 14.sp, fontWeight: FontWeight.w400, height: 1.35),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          _buildAvatarSection(),
                          const SizedBox(height: 16),
                          _buildSimpleLabel('Full Name'),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: _fullNameController,
                            hintText: 'Enter your full name',
                            suffixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.onBackground, size: 21),
                            inputFormatters: kNoEmojiInputFormatters,
                          ),
                          const SizedBox(height: 12),
                          _buildSimpleLabel('Date Of Birth'),
                          const SizedBox(height: 8),
                          _buildDateOfBirthField(),
                          const SizedBox(height: 12),
                          _buildSimpleLabel('Phone Number'),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: _phoneController,
                            hintText: 'Enter your phone number',
                            keyboardType: TextInputType.phone,
                            suffixIcon: const Icon(Icons.phone_outlined, color: AppColors.onBackground, size: 21),
                            inputFormatters: kNoEmojiInputFormatters,
                          ),
                          const SizedBox(height: 12),
                          _buildSimpleLabel('Gender'),
                          const SizedBox(height: 8),
                          _buildDropdownField(
                            label: null,
                            value: _selectedGender,
                            items: AppConstants.genderOptions,
                            icon: null,
                            itemLabel: GenderEnums.displayForApi,
                            onChanged: (value) => setState(() => _selectedGender = value),
                          ),
                          const SizedBox(height: 12),
                          _buildSimpleLabel('Weight (kg)'),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: _weightController,
                            hintText: 'Enter your weight',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            suffixIcon: const Icon(Icons.monitor_weight_outlined, color: AppColors.onBackground, size: 21),
                            inputFormatters: [
                              ...kNoEmojiInputFormatters,
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSimpleLabel('Bio (Optional)'),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: _bioController,
                            hintText: 'Tell us about yourself...',
                            maxLines: 3,
                            inputFormatters: kNoEmojiInputFormatters,
                          ),
                          const SizedBox(height: 20),
                          GetBuilder<AuthController>(
                            builder: (controller) {
                              return CustomButton(
                                text: 'Continue',
                                onPressed: _continue,
                                isLoading: controller.isLoading,
                                backgroundColor: AppColors.accent,
                                textColor: AppColors.onAccent,
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontSize: 15.sp, fontWeight: FontWeight.w600),
      ),
    ).paddingSymmetric(horizontal: 20.w);
  }

  Widget _buildAvatarSection() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 85.w,
          height: 85.h,
          decoration: BoxDecoration(
            color: const Color(0xFFF6FFE9),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE4F2D8), width: 1.2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Padding(
            padding: _profileImageFile != null ? EdgeInsets.zero : EdgeInsets.all(20.r),
            child: _profileImageFile != null
                ? ClipOval(
                    child: Image.file(_profileImageFile!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                  )
                : Image.asset('assets/images/profile00.png', fit: BoxFit.contain, width: 20.w),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: GestureDetector(
            onTap: _showImageSourceDialog,
            child: Container(
              width: 30.w,
              height: 30.h,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 13.sp),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateOfBirthField() {
    return InkWell(
      onTap: _selectDateOfBirth,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.white,
          border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.35), width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _dateOfBirth != null ? DateFormat('MMMM dd, yyyy').format(_dateOfBirth!) : 'Select your date of birth',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _dateOfBirth != null ? AppColors.onBackground : AppColors.onBackground.withValues(alpha: 0.6),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Image.asset('assets/images/calendar-2.png', width: 19, height: 19, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? label,
    required String? value,
    required List<String> items,
    required IconData? icon,
    required ValueChanged<String?> onChanged,
    String Function(String value)? itemLabel,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.35), width: 1.2),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 16, right: 12),
                  child: Icon(icon, color: AppColors.primaryGray, size: 22),
                )
              : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
        style: AppTextStyles.bodyMedium.copyWith(
          color: value != null ? AppColors.onBackground : AppColors.onBackground.withValues(alpha: 0.6),
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        dropdownColor: AppColors.surface,
        icon: const Padding(
          padding: EdgeInsets.only(right: 16),
          child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.onBackground, size: 22),
        ),
        hint: Text(
          'Select gender',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withValues(alpha: 0.6), fontSize: 15, fontWeight: FontWeight.w400),
        ),
        items: items.map((String item) {
          final label = itemLabel != null ? itemLabel(item) : item;
          return DropdownMenuItem<String>(value: item, child: Text(label));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
