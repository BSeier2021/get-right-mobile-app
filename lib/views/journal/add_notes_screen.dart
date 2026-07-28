import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

class AddNotesScreen extends StatefulWidget {
  const AddNotesScreen({super.key});
  @override
  State<AddNotesScreen> createState() => _AddNotesScreenState();
}

class _AddNotesScreenState extends State<AddNotesScreen> {
  final TextEditingController _notesController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      _notesController.text = args['existingNotes'] ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSave() => Get.back(result: {'notes': _notesController.text.trim()});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text('Add Notes', style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notes',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                focusNode: _focusNode,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Add notes for this day...',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.6)),
                  ),
                ),
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentVariant,
                    foregroundColor: AppColors.onAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    elevation: 0,
                  ),
                  child: Text('Save', style: AppTextStyles.buttonLarge),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.6), width: 1.5),
                    foregroundColor: AppColors.onBackground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  ),
                  child: Text('Cancel', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onBackground)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
