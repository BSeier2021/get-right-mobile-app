import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Manual run logging screen for journal entries
class LogRunScreen extends StatefulWidget {
  const LogRunScreen({super.key});

  @override
  State<LogRunScreen> createState() => _LogRunScreenState();
}

class _LogRunScreenState extends State<LogRunScreen> {
  final _formKey = GlobalKey<FormState>();
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedIntensity = 'Moderate';

  final List<String> _intensityLevels = ['Easy', 'Moderate', 'Hard', 'Very Hard'];

  @override
  void dispose() {
    _distanceController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveRun() {
    if (_formKey.currentState!.validate()) {
      // TODO: Save to storage service
      Get.back();
      Get.snackbar(
        'Run Logged',
        'Your run has been added to your journal',
        backgroundColor: AppColors.completed,
        colorText: AppColors.onAccent,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
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
        title: Text('Log Run', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGray.withOpacity(0.6)),
                  boxShadow: [BoxShadow(color: AppColors.blackOverlay.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: AppColors.completed.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.directions_run, color: AppColors.completed, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manual Run Entry',
                            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text('Log a run you commented', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Date & Time
              Text(
                'Date & Time',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPillSelector(
                      label: 'Date',
                      value: DateFormat('MMM dd, yyyy').format(_selectedDate),
                      hint: 'Select date',
                      onTap: () async {
                        final date = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (date != null) {
                          setState(() => _selectedDate = date);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPillSelector(
                      label: 'Time',
                      value: _selectedTime.format(context),
                      hint: 'Select time',
                      onTap: () async {
                        final time = await showTimePicker(context: context, initialTime: _selectedTime);
                        if (time != null) {
                          setState(() => _selectedTime = time);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Distance
              Text(
                'Distance',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _distanceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter distance',
                  suffixText: 'km',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),

                    borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.4)),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter distance';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Duration
              Text(
                'Duration',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.text,

                decoration: InputDecoration(
                  hintText: 'Enter duration',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.4)),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter duration';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Intensity
              Text(
                'Intensity',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _intensityLevels.map((intensity) {
                  final isSelected = _selectedIntensity == intensity;
                  return ChoiceChip(
                    label: Text(intensity),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedIntensity = intensity);
                    },
                    selectedColor: AppColors.accent,
                    backgroundColor: AppColors.white,
                    shape: StadiumBorder(side: BorderSide(color: isSelected ? AppColors.accent : AppColors.primaryGray.withOpacity(0.4))),
                    labelStyle: AppTextStyles.labelMedium.copyWith(
                      color: isSelected ? AppColors.onAccent : AppColors.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Notes
              Text(
                'Notes (Optional)',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'How did you feel? Any observations?',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.4)),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveRun,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  ),
                  child: Text('Save Run', style: AppTextStyles.buttonLarge),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillSelector({required String label, required String value, required String hint, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: AppColors.primaryGray.withOpacity(0.4)),
              ),
              child: Text(value.isEmpty ? hint : value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
            ),
          ],
        ),
      ),
    );
  }
}
