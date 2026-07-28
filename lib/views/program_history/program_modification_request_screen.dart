import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/enrolled_program_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:intl/intl.dart';

/// Program Modification Request Screen
class ProgramModificationRequestScreen extends StatefulWidget {
  const ProgramModificationRequestScreen({super.key});

  @override
  State<ProgramModificationRequestScreen> createState() => _ProgramModificationRequestScreenState();
}

class _ProgramModificationRequestScreenState extends State<ProgramModificationRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _timeController = TextEditingController();

  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final program = Get.arguments as EnrolledProgramModel?;
    final initialDate = program?.startDate ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(primary: AppColors.accent, onPrimary: AppColors.onAccent, surface: AppColors.surface, onSurface: AppColors.onSurface),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedStartDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final program = Get.arguments as EnrolledProgramModel?;
    final initialDate = program?.endDate ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _selectedStartDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(primary: AppColors.accent, onPrimary: AppColors.onAccent, surface: AppColors.surface, onSurface: AppColors.onSurface),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedEndDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(primary: AppColors.accent, onPrimary: AppColors.onAccent, surface: AppColors.surface, onSurface: AppColors.onSurface),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = picked.format(context);
      });
    }
  }

  void _submitRequest() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedStartDate == null || _selectedEndDate == null) {
      Get.snackbar('Missing Information', 'Please select both start and end dates', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // TODO: Submit modification request to backend
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isSubmitting = false;
      });

      Get.snackbar(
        'Request Sent',
        'Your modification request has been sent to the trainer',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.completed,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      Get.back();
    });
  }

  @override
  Widget build(BuildContext context) {
    final program = Get.arguments as EnrolledProgramModel?;
    if (program == null) {
      Get.back();
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: Text('Request Modification', style: AppTextStyles.titleLarge.copyWith()), centerTitle: true),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Program Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.programTitle,
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('by ${program.trainerName}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildDateInfo('Current Start', DateFormat('MMM dd, yyyy').format(program.startDate))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDateInfo('Current End', DateFormat('MMM dd, yyyy').format(program.endDate))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // New Schedule Section
              Text(
                'New Schedule',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // New Start Date
              _buildDatePickerField(label: 'New Start Date', value: _selectedStartDate, onTap: () => _selectStartDate(context)),
              const SizedBox(height: 16),

              // New End Date
              _buildDatePickerField(label: 'New End Date', value: _selectedEndDate, onTap: () => _selectEndDate(context)),
              const SizedBox(height: 16),

              // New Time
              _buildTimePickerField(label: 'Preferred Time', controller: _timeController, onTap: () => _selectTime(context)),
              const SizedBox(height: 24),

              // Reason Section
              Text(
                'Reason for Modification',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                maxLines: 4,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Please explain why you need to modify the program schedule...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.accent, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a reason for the modification';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Additional Notes
              Text(
                'Additional Notes (Optional)',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Any additional information you\'d like to share...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.accent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : Text(
                          'Send Modification Request',
                          style: AppTextStyles.buttonMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateInfo(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField({required String label, required DateTime? value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGray)),
                const SizedBox(height: 4),
                Text(
                  value != null ? DateFormat('MMM dd, yyyy').format(value) : 'Select date',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: value != null ? AppColors.onSurface : AppColors.primaryGray,
                    fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
            Icon(Icons.calendar_today, color: AppColors.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerField({required String label, required TextEditingController controller, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGray)),
                const SizedBox(height: 4),
                Text(
                  controller.text.isEmpty ? 'Select time' : controller.text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: controller.text.isNotEmpty ? AppColors.onSurface : AppColors.primaryGray,
                    fontWeight: controller.text.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
            Icon(Icons.access_time, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
