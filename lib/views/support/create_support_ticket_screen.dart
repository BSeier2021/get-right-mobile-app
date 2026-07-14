import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/repo/support_ticket_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/no_emoji_input_formatter.dart';
import 'package:get_right/utils/support_ticket_email.dart';
import 'package:get_right/widgets/common/custom_button.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';

/// Create support ticket — `POST /user/support-tickets`.
class CreateSupportTicketScreen extends StatefulWidget {
  const CreateSupportTicketScreen({super.key});

  @override
  State<CreateSupportTicketScreen> createState() => _CreateSupportTicketScreenState();
}

class _CreateSupportTicketScreenState extends State<CreateSupportTicketScreen> {
  final SupportTicketRepository _repo = SupportTicketRepository();
  final _emailController = TextEditingController();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _loading = false;
  bool _emailLocked = false;

  @override
  void initState() {
    super.initState();
    _prefillEmail();
  }

  Future<void> _prefillEmail() async {
    final args = Get.arguments;
    final fromArgs = args is Map ? args['email']?.toString() : null;
    final email = await resolveSupportTicketEmail(overrideEmail: fromArgs);
    if (!mounted) return;
    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
      _emailLocked = true;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      Get.snackbar('Support', 'Please enter a valid registered email', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (title.isEmpty) {
      Get.snackbar('Support', 'Please enter a subject', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (body.isEmpty) {
      Get.snackbar('Support', 'Please enter issue details', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _loading = true);
    try {
      final ticketId = await _repo.createTicket(email: email, title: title, body: body);

      StorageService? storage;
      if (Get.isRegistered<StorageService>()) {
        storage = Get.find<StorageService>();
      } else {
        storage = await StorageService.getInstance();
      }
      await storage.saveSupportTicketEmail(email);

      if (!mounted) return;
      Get.back(result: true);
      Get.toNamed(AppRoutes.supportTicketDetail, arguments: {'ticketId': ticketId});
      Get.snackbar('Support', 'Ticket created successfully', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Support', e.toString().replaceFirst('Exception: ', ''), snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text('Contact Support', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tell us what went wrong and our team will get back to you by email.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
            ),
            SizedBox(height: 20.h),
            CustomTextField(
              controller: _emailController,
              labelText: 'Email',
              hintText: 'your@email.com',
              keyboardType: TextInputType.emailAddress,
              readOnly: _emailLocked,
              inputFormatters: [NoEmojiInputFormatter()],
            ),
            SizedBox(height: 16.h),
            CustomTextField(
              controller: _titleController,
              labelText: 'Subject',
              hintText: 'Enter the subject of your support request',
              maxLength: 255,
              inputFormatters: [NoEmojiInputFormatter()],
            ),
            SizedBox(height: 16.h),
            CustomTextField(
              controller: _bodyController,
              labelText: 'Issue details',
              hintText: 'Describe your issue in detail',
              maxLines: 6,
              maxLength: 5000,
              inputFormatters: [NoEmojiInputFormatter()],
            ),
            SizedBox(height: 28.h),
            CustomButton(text: 'Submit Ticket', onPressed: _submit, isLoading: _loading),
          ],
        ),
      ),
    );
  }
}
