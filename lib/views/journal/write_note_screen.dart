import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Note writing screen for journal entries
class WriteNoteScreen extends StatefulWidget {
  const WriteNoteScreen({super.key});

  @override
  State<WriteNoteScreen> createState() => _WriteNoteScreenState();
}

class _WriteNoteScreenState extends State<WriteNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedMood = 'Neutral';

  final List<Map<String, dynamic>> _moods = [
    {'label': 'Great', 'emoji': '😄', 'color': Color(0xFF4CAF50)},
    {'label': 'Good', 'emoji': '🙂', 'color': Color(0xFF8BC34A)},
    {'label': 'Neutral', 'emoji': '😐', 'color': Color(0xFFFFEB3B)},
    {'label': 'Tired', 'emoji': '😔', 'color': Color(0xFFFF9800)},
    {'label': 'Stressed', 'emoji': '😰', 'color': Color(0xFFF44336)},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveNote() {
    if (_formKey.currentState!.validate()) {
      // TODO: Save to storage service
      Get.back();
      Get.snackbar(
        'Note Saved',
        'Your note has been added to your journal',
        backgroundColor: const Color(0xFF9C27B0),
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
          icon: const Icon(Icons.close, color: AppColors.onPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text('Write Note', style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveNote,
            child: Text(
              'Save',
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0xFF9C27B0).withOpacity(0.15), AppColors.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(color: const Color(0xFF9C27B0).withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.notes, color: Color(0xFF9C27B0), size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Journal Note', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
                          const SizedBox(height: 4),
                          Text('Capture your thoughts', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Date
              Text(
                'Date',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: Color(0xFF9C27B0)),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDate),
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Mood
              Text(
                'How are you feeling?',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _moods.map((mood) {
                    final isSelected = _selectedMood == mood['label'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        onTap: () => setState(() => _selectedMood = mood['label']),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected ? mood['color'].withOpacity(0.2) : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? mood['color'] : AppColors.primaryGray.withOpacity(0.3), width: isSelected ? 2 : 1),
                          ),
                          child: Column(
                            children: [
                              Text(mood['emoji'], style: const TextStyle(fontSize: 32)),
                              const SizedBox(height: 8),
                              Text(
                                mood['label'],
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: isSelected ? mood['color'] : AppColors.onSurface,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Title',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Give your note a title',
                  prefixIcon: const Icon(Icons.title, color: Color(0xFF9C27B0)),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.3)),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Content
              Text(
                'Your Thoughts',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentController,
                maxLines: 12,
                decoration: InputDecoration(
                  hintText: 'Write your thoughts, reflections, goals, or anything on your mind...',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.3)),
                  ),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please write something';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Character count
              Align(
                alignment: Alignment.centerRight,
                child: Text('${_contentController.text.length} characters', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
              ),
              const SizedBox(height: 16),

              // Save Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveNote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    foregroundColor: AppColors.onAccent,
                    elevation: 4,
                    shadowColor: const Color(0xFF9C27B0).withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, size: 24),
                      const SizedBox(width: 8),
                      Text('Save Note', style: AppTextStyles.buttonLarge),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
