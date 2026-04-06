import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get_right/models/run_model.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/journal/add_workout_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// Planner screen - workout plans and calendar with color-coded entries
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  final ImagePicker _imagePicker = ImagePicker();

  // Mock workout data for calendar (status: completed, incomplete, rest)
  final Map<DateTime, Map<String, dynamic>> _dayData = {
    // December 2025 mock data
    DateTime(2025, 12, 1): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': true,
      'workout': {'duration': '45:00', 'exercises': 5, 'sets': 15, 'calories': 450},
      'run': null,
      'nutrition': {'calories': '2100/2200', 'protein': '140g', 'carbs': '220g', 'fats': '65g'},
      'notes': 'Started new program',
    },
    DateTime(2025, 12, 2): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': null,
      'run': {'distance': '5.20 km', 'time': '28:00', 'pace': '5:23 /km', 'calories': 320},
      'nutrition': {'calories': '1950/2200', 'protein': '130g', 'carbs': '210g', 'fats': '58g'},
      'notes': 'Morning run',
    },
    DateTime(2025, 12, 3): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': true,
      'workout': {'duration': '30:00', 'exercises': 4, 'sets': 12, 'calories': 300},
      'run': null,
      'nutrition': {'calories': '1850/2200', 'protein': '145g', 'carbs': '195g', 'fats': '62g'},
      'notes': '',
    },
    DateTime(2025, 12, 4): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '60:00', 'exercises': 6, 'sets': 18, 'calories': 550},
      'run': null,
      'nutrition': {'calories': '2150/2200', 'protein': '155g', 'carbs': '230g', 'fats': '70g'},
      'notes': 'Leg day - intense session',
    },
    DateTime(2025, 12, 5): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': true,
      'workout': {'duration': '30:00', 'exercises': 4, 'sets': 12, 'calories': 300},
      'run': {'distance': '3.00 km', 'time': '20:00', 'pace': '4:00 /km', 'calories': 250},
      'nutrition': {'calories': '1800/2200', 'protein': '120g', 'carbs': '200g', 'fats': '60g'},
      'notes': 'Great workout today!',
    },
    DateTime(2025, 12, 6): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': null,
      'run': null,
      'nutrition': {'calories': '1900/2200', 'protein': '125g', 'carbs': '205g', 'fats': '63g'},
      'notes': '',
    },
    DateTime(2025, 12, 7): {
      'workoutStatus': 'rest',
      'hasProgressPhoto': false,
      'workout': null,
      'run': null,
      'nutrition': {'calories': '1600/2200', 'protein': '100g', 'carbs': '180g', 'fats': '55g'},
      'notes': 'Rest day - recovery',
    },
    DateTime(2025, 12, 8): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '40:00', 'exercises': 5, 'sets': 14, 'calories': 380},
      'run': null,
      'nutrition': {'calories': '2050/2200', 'protein': '150g', 'carbs': '215g', 'fats': '68g'},
      'notes': '',
    },
    DateTime(2025, 12, 9): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': true,
      'workout': null,
      'run': {'distance': '8.50 km', 'time': '45:00', 'pace': '5:18 /km', 'calories': 520},
      'nutrition': {'calories': '2250/2200', 'protein': '135g', 'carbs': '240g', 'fats': '72g'},
      'notes': 'Long run - feeling strong',
    },
    DateTime(2025, 12, 10): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '35:00', 'exercises': 4, 'sets': 13, 'calories': 330},
      'run': null,
      'nutrition': {'calories': '1950/2200', 'protein': '142g', 'carbs': '208g', 'fats': '64g'},
      'notes': '',
    },
    DateTime(2025, 12, 11): {
      'workoutStatus': 'incomplete',
      'hasProgressPhoto': false,
      'workout': {'duration': '30:00', 'exercises': 4, 'sets': 12, 'calories': 300},
      'run': null,
      'nutrition': null,
      'notes': 'Planned workout',
    },
    DateTime(2025, 12, 12): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '50:00', 'exercises': 6, 'sets': 16, 'calories': 480},
      'run': {'distance': '4.20 km', 'time': '22:00', 'pace': '4:14 /km', 'calories': 280},
      'nutrition': {'calories': '2200/2200', 'protein': '160g', 'carbs': '225g', 'fats': '75g'},
      'notes': 'Double session day',
    },
    DateTime(2025, 12, 13): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': true,
      'workout': {'duration': '38:00', 'exercises': 5, 'sets': 15, 'calories': 360},
      'run': null,
      'nutrition': {'calories': '1980/2200', 'protein': '148g', 'carbs': '212g', 'fats': '66g'},
      'notes': '',
    },
    DateTime(2025, 12, 14): {
      'workoutStatus': 'rest',
      'hasProgressPhoto': false,
      'workout': null,
      'run': null,
      'nutrition': {'calories': '1650/2200', 'protein': '105g', 'carbs': '185g', 'fats': '56g'},
      'notes': 'Active recovery - light walk',
    },
    DateTime(2025, 12, 15): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '42:00', 'exercises': 5, 'sets': 14, 'calories': 400},
      'run': null,
      'nutrition': {'calories': '2100/2200', 'protein': '152g', 'carbs': '218g', 'fats': '69g'},
      'notes': '',
    },
    DateTime(2025, 12, 16): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': null,
      'run': {'distance': '6.80 km', 'time': '36:00', 'pace': '5:18 /km', 'calories': 410},
      'nutrition': {'calories': '1920/2200', 'protein': '128g', 'carbs': '202g', 'fats': '61g'},
      'notes': 'Evening run',
    },
    DateTime(2025, 12, 17): {
      'workoutStatus': 'incomplete',
      'hasProgressPhoto': false,
      'workout': {'duration': '35:00', 'exercises': 4, 'sets': 13, 'calories': 340},
      'run': null,
      'nutrition': null,
      'notes': 'Scheduled workout',
    },
    DateTime(2025, 12, 18): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': true,
      'workout': {'duration': '55:00', 'exercises': 7, 'sets': 20, 'calories': 600},
      'run': null,
      'nutrition': {'calories': '2300/2200', 'protein': '165g', 'carbs': '245g', 'fats': '80g'},
      'notes': 'Weekend warrior session',
    },
    DateTime(2025, 12, 19): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': null,
      'run': {'distance': '10.00 km', 'time': '52:00', 'pace': '5:12 /km', 'calories': 620},
      'nutrition': {'calories': '2180/2200', 'protein': '138g', 'carbs': '235g', 'fats': '73g'},
      'notes': '10K milestone!',
    },
    DateTime(2025, 12, 20): {
      'workoutStatus': 'rest',
      'hasProgressPhoto': false,
      'workout': null,
      'run': null,
      'nutrition': {'calories': '1700/2200', 'protein': '110g', 'carbs': '190g', 'fats': '58g'},
      'notes': 'Rest day',
    },
    DateTime(2025, 12, 21): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '33:00', 'exercises': 4, 'sets': 12, 'calories': 310},
      'run': null,
      'nutrition': {'calories': '2000/2200', 'protein': '146g', 'carbs': '210g', 'fats': '65g'},
      'notes': '',
    },
    DateTime(2025, 12, 22): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '48:00', 'exercises': 6, 'sets': 17, 'calories': 470},
      'run': {'distance': '3.50 km', 'time': '18:00', 'pace': '3:51 /km', 'calories': 240},
      'nutrition': {'calories': '2250/2200', 'protein': '158g', 'carbs': '238g', 'fats': '76g'},
      'notes': 'Fast run today',
    },
    DateTime(2025, 12, 23): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': true,
      'workout': {'duration': '40:00', 'exercises': 5, 'sets': 15, 'calories': 390},
      'run': null,
      'nutrition': {'calories': '1950/2200', 'protein': '143g', 'carbs': '207g', 'fats': '64g'},
      'notes': '',
    },
    DateTime(2025, 12, 24): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': null,
      'run': {'distance': '5.00 km', 'time': '25:00', 'pace': '5:00 /km', 'calories': 310},
      'nutrition': {'calories': '2400/2200', 'protein': '120g', 'carbs': '280g', 'fats': '85g'},
      'notes': 'Christmas Eve run',
    },
    DateTime(2025, 12, 25): {
      'workoutStatus': 'rest',
      'hasProgressPhoto': false,
      'workout': null,
      'run': null,
      'nutrition': {'calories': '2500/2200', 'protein': '110g', 'carbs': '300g', 'fats': '90g'},
      'notes': 'Christmas - family time',
    },
    DateTime(2025, 12, 26): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '45:00', 'exercises': 5, 'sets': 16, 'calories': 440},
      'run': null,
      'nutrition': {'calories': '2050/2200', 'protein': '151g', 'carbs': '220g', 'fats': '68g'},
      'notes': 'Back to routine',
    },
    DateTime(2025, 12, 27): {
      'workoutStatus': 'incomplete',
      'hasProgressPhoto': false,
      'workout': {'duration': '30:00', 'exercises': 4, 'sets': 12, 'calories': 300},
      'run': null,
      'nutrition': null,
      'notes': 'Planned workout',
    },
    DateTime(2025, 12, 28): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '50:00', 'exercises': 6, 'sets': 18, 'calories': 500},
      'run': null,
      'nutrition': {'calories': '2120/2200', 'protein': '154g', 'carbs': '222g', 'fats': '71g'},
      'notes': '',
    },
    DateTime(2025, 12, 29): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': true,
      'workout': null,
      'run': {'distance': '7.20 km', 'time': '38:00', 'pace': '5:17 /km', 'calories': 450},
      'nutrition': {'calories': '1970/2200', 'protein': '132g', 'carbs': '209g', 'fats': '63g'},
      'notes': '',
    },
    DateTime(2025, 12, 30): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '43:00', 'exercises': 5, 'sets': 15, 'calories': 420},
      'run': null,
      'nutrition': {'calories': '2080/2200', 'protein': '149g', 'carbs': '216g', 'fats': '67g'},
      'notes': '',
    },
    DateTime(2025, 12, 31): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '60:00', 'exercises': 7, 'sets': 21, 'calories': 650},
      'run': {'distance': '5.50 km', 'time': '28:00', 'pace': '5:05 /km', 'calories': 340},
      'nutrition': {'calories': '2350/2200', 'protein': '162g', 'carbs': '248g', 'fats': '78g'},
      'notes': 'End of year challenge!',
    },

    // March 2026 mock data (matching calendar screenshot)
    DateTime(2026, 3, 3): {
      'workoutStatus': 'rest',
      'hasProgressPhoto': false,
      'workout': null,
      'run': null,
      'nutrition': {'calories': '1600/2200', 'protein': '100g', 'carbs': '180g', 'fats': '55g'},
      'notes': 'Rest day',
    },
    DateTime(2026, 3, 4): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '45:00', 'exercises': 5, 'sets': 15, 'calories': 450},
      'run': null,
      'nutrition': {'calories': '2100/2200', 'protein': '140g', 'carbs': '220g', 'fats': '65g'},
      'notes': '',
    },
    DateTime(2026, 3, 5): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '50:00', 'exercises': 6, 'sets': 18, 'calories': 520},
      'run': null,
      'nutrition': {'calories': '2000/2200', 'protein': '145g', 'carbs': '210g', 'fats': '68g'},
      'notes': '',
    },
    DateTime(2026, 3, 6): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': null,
      'run': {'distance': '5.00 km', 'time': '26:00', 'pace': '5:12 /km', 'calories': 310},
      'nutrition': {'calories': '1950/2200', 'protein': '130g', 'carbs': '200g', 'fats': '60g'},
      'notes': 'Morning run',
    },
    DateTime(2026, 3, 7): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '35:00', 'exercises': 4, 'sets': 12, 'calories': 340},
      'run': null,
      'nutrition': {'calories': '2050/2200', 'protein': '148g', 'carbs': '215g', 'fats': '66g'},
      'notes': '',
    },
    DateTime(2026, 3, 10): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '40:00', 'exercises': 5, 'sets': 14, 'calories': 400},
      'run': null,
      'nutrition': {'calories': '2100/2200', 'protein': '150g', 'carbs': '218g', 'fats': '67g'},
      'notes': '',
    },
    DateTime(2026, 3, 11): {
      'workoutStatus': 'rest',
      'hasProgressPhoto': false,
      'workout': null,
      'run': null,
      'nutrition': {'calories': '1650/2200', 'protein': '105g', 'carbs': '185g', 'fats': '56g'},
      'notes': 'Rest day - recovery',
    },
    DateTime(2026, 3, 12): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '55:00', 'exercises': 6, 'sets': 18, 'calories': 550},
      'run': null,
      'nutrition': {'calories': '2200/2200', 'protein': '155g', 'carbs': '230g', 'fats': '72g'},
      'notes': '',
    },
    DateTime(2026, 3, 13): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': null,
      'run': {'distance': '6.50 km', 'time': '34:00', 'pace': '5:14 /km', 'calories': 400},
      'nutrition': {'calories': '2050/2200', 'protein': '138g', 'carbs': '212g', 'fats': '64g'},
      'notes': '',
    },
    DateTime(2026, 3, 14): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '42:00', 'exercises': 5, 'sets': 15, 'calories': 420},
      'run': null,
      'nutrition': {'calories': '2150/2200', 'protein': '152g', 'carbs': '225g', 'fats': '70g'},
      'notes': '',
    },
    DateTime(2026, 3, 17): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '48:00', 'exercises': 6, 'sets': 16, 'calories': 470},
      'run': null,
      'nutrition': {'calories': '2100/2200', 'protein': '149g', 'carbs': '220g', 'fats': '69g'},
      'notes': '',
    },
    DateTime(2026, 3, 18): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '38:00', 'exercises': 5, 'sets': 14, 'calories': 380},
      'run': null,
      'nutrition': {'calories': '1980/2200', 'protein': '142g', 'carbs': '208g', 'fats': '65g'},
      'notes': '',
    },
    DateTime(2026, 3, 19): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': true,
      'workout': {'duration': '50:00', 'exercises': 6, 'sets': 18, 'calories': 500},
      'run': null,
      'nutrition': {'calories': '2250/2200', 'protein': '160g', 'carbs': '240g', 'fats': '75g'},
      'notes': 'Great progress!',
    },
    DateTime(2026, 3, 20): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': null,
      'run': {'distance': '8.00 km', 'time': '42:00', 'pace': '5:15 /km', 'calories': 490},
      'nutrition': {'calories': '2180/2200', 'protein': '136g', 'carbs': '232g', 'fats': '71g'},
      'notes': '',
    },

    // April 2026 mock data (current month)
    DateTime(2026, 4, 1): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '45:00', 'exercises': 5, 'sets': 15, 'calories': 440},
      'run': null,
      'nutrition': {'calories': '2100/2200', 'protein': '148g', 'carbs': '218g', 'fats': '67g'},
      'notes': 'New month, new goals',
    },
    DateTime(2026, 4, 2): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': null,
      'run': {'distance': '5.50 km', 'time': '28:00', 'pace': '5:05 /km', 'calories': 340},
      'nutrition': {'calories': '2000/2200', 'protein': '135g', 'carbs': '210g', 'fats': '63g'},
      'notes': '',
    },
    DateTime(2026, 4, 3): {
      'workoutStatus': 'rest',
      'hasProgressPhoto': false,
      'workout': null,
      'run': null,
      'nutrition': {'calories': '1700/2200', 'protein': '110g', 'carbs': '190g', 'fats': '58g'},
      'notes': 'Rest day',
    },
    DateTime(2026, 4, 4): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': true,
      'workout': {'duration': '55:00', 'exercises': 7, 'sets': 20, 'calories': 580},
      'run': null,
      'nutrition': {'calories': '2200/2200', 'protein': '158g', 'carbs': '228g', 'fats': '73g'},
      'notes': '',
    },
    DateTime(2026, 4, 5): {
      'workoutStatus': 'completed',
      'hasProgressPhoto': false,
      'workout': {'duration': '40:00', 'exercises': 5, 'sets': 14, 'calories': 400},
      'run': null,
      'nutrition': {'calories': '2050/2200', 'protein': '146g', 'carbs': '215g', 'fats': '66g'},
      'notes': '',
    },
  };

  String _formatRunTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatPace(double paceMinPerKm) {
    if (paceMinPerKm == 0 || paceMinPerKm.isInfinite || paceMinPerKm.isNaN) {
      return '--:-- /km';
    }
    final minutes = paceMinPerKm.floor();
    final seconds = ((paceMinPerKm - minutes) * 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} /km';
  }

  Map<String, dynamic>? _getDataForDate(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return _dayData[key];
  }

  Color _getDateColor(DateTime date) {
    final data = _getDataForDate(date);
    if (data == null) return Colors.transparent;

    final status = data['workoutStatus'];

    // Completed workouts: Green
    if (status == 'completed') return const Color(0xFF6FCF97);
    // Planned/incomplete workouts: Red
    if (status == 'incomplete') return const Color(0xFFE74C3C);
    // Rest day: Blue
    if (status == 'rest') return const Color(0xFF4A90E2);

    return Colors.transparent;
  }

  bool _hasProgressPhoto(DateTime date) {
    final data = _getDataForDate(date);
    return data?['hasProgressPhoto'] ?? false;
  }

  Future<void> _addProgressPhoto() async {
    // Check if selected date is in the future
    final now = DateTime.now();
    final selectedDateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final nowDateOnly = DateTime(now.year, now.month, now.day);

    if (selectedDateOnly.isAfter(nowDateOnly)) {
      Get.snackbar(
        'Invalid Date',
        'Progress photos are not allowed for future dates',
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Show options for front or side photo
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: AppColors.blackOverlay, blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Add Progress Photo',
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Choose front or side photo', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                const SizedBox(height: 24),
                _buildShareOptionTile(
                  icon: Icons.camera_front,
                  title: 'Front Photo',
                  subtitle: 'Capture from the front',
                  onTap: () {
                    Navigator.pop(context);
                    _capturePhoto('front');
                  },
                ),
                const SizedBox(height: 12),
                _buildShareOptionTile(
                  icon: Icons.camera_alt,
                  title: 'Side Photo',
                  subtitle: 'Capture from the side',
                  onTap: () {
                    Navigator.pop(context);
                    _capturePhoto('side');
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _capturePhoto(String type) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);

      if (photo != null) {
        // TODO: Upload photo to backend
        setState(() {
          final key = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
          if (_dayData[key] != null) {
            _dayData[key]!['hasProgressPhoto'] = true;
          } else {
            _dayData[key] = {'workoutStatus': null, 'hasProgressPhoto': true, 'workout': null, 'run': null, 'nutrition': null, 'notes': ''};
          }
        });

        Get.snackbar('Success', '$type photo added successfully', backgroundColor: AppColors.completed, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to capture photo: $e', backgroundColor: AppColors.error, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _showAddWorkoutDialog() {
    // Check if date is in the past or future for different options
    final now = DateTime.now();
    final selectedDateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final nowDateOnly = DateTime(now.year, now.month, now.day);

    final isFuture = selectedDateOnly.isAfter(nowDateOnly);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: AppColors.blackOverlay, blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Text(
                  isFuture ? 'Plan for ${_formatDate(_selectedDate)}' : 'Add to ${_formatDate(_selectedDate)}',
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(isFuture ? 'Schedule an activity' : 'Log something for this day', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                const SizedBox(height: 24),
                _buildShareOptionTile(
                  icon: Icons.fitness_center,
                  title: 'Add Workout',
                  subtitle: 'Log a gym or home workout',
                  onTap: () {
                    Get.back();
                    Get.to(AddWorkoutScreen());
                  },
                ),
                const SizedBox(height: 12),
                _buildShareOptionTile(
                  icon: Icons.directions_run,
                  title: 'Add Run',
                  subtitle: 'Log a run or outdoor activity',
                  onTap: () {
                    Navigator.pop(context);
                    Get.toNamed(AppRoutes.logRun, arguments: {'selectedDate': _selectedDate});
                  },
                ),
                if (!isFuture) ...[
                  const SizedBox(height: 12),
                  _buildShareOptionTile(
                    icon: Icons.camera_alt,
                    title: 'Add Progress Photo',
                    subtitle: 'Front or side progress photo',
                    onTap: () {
                      Navigator.pop(context);
                      _addProgressPhoto();
                    },
                  ),
                ],
                const SizedBox(height: 12),
                _buildShareOptionTile(
                  icon: Icons.note_alt_rounded,
                  title: 'Add Notes',
                  subtitle: 'Add notes for this day',
                  onTap: () {
                    Navigator.pop(context);
                    _showNotesDialog();
                  },
                ),
                if (isFuture) ...[
                  const SizedBox(height: 12),
                  _buildShareOptionTile(
                    icon: Icons.bedtime_rounded,
                    title: 'Mark as Rest Day',
                    subtitle: 'No workout planned',
                    onTap: () {
                      Navigator.pop(context);
                      _markAsRestDay();
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotesDialog() {
    final data = _getDataForDate(_selectedDate);
    final currentNotes = data?['notes'] ?? '';
    final notesController = TextEditingController(text: currentNotes);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Daily Notes', style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent)),
        content: TextField(
          controller: notesController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Add notes for this day...',
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primaryGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final key = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
                if (_dayData[key] != null) {
                  _dayData[key]!['notes'] = notesController.text;
                } else {
                  _dayData[key] = {'workoutStatus': null, 'hasProgressPhoto': false, 'workout': null, 'run': null, 'nutrition': null, 'notes': notesController.text};
                }
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.onAccent),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _markAsRestDay() {
    setState(() {
      final key = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      _dayData[key] = {'workoutStatus': 'rest', 'hasProgressPhoto': false, 'workout': null, 'run': null, 'nutrition': null, 'notes': _dayData[key]?['notes'] ?? ''};
    });

    Get.snackbar('Success', 'Day marked as rest day', backgroundColor: const Color(0xFF4A90E2), colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
  }

  void _showPhotoHistory() {
    // Get all dates with progress photos
    final photoDates = _dayData.entries.where((entry) => entry.value['hasProgressPhoto'] == true).map((entry) => entry.key).toList();

    if (photoDates.isEmpty) {
      Get.snackbar('No Photos', 'You haven\'t added any progress photos yet', backgroundColor: AppColors.error, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // Sort dates in descending order (newest first)
    photoDates.sort((a, b) => b.compareTo(a));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.onPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Progress Photo History',
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.onPrimary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // Photo Timeline
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: photoDates.length,
                itemBuilder: (context, index) {
                  final date = photoDates[index];
                  return _buildPhotoHistoryItem(date, index == 0);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoHistoryItem(DateTime date, bool isLatest) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLatest ? AppColors.accent : AppColors.primaryGray, width: isLatest ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                _formatDate(date),
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (isLatest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    'Latest',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _viewPhotoFullScreen(date, 'front');
                  },
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_front, size: 50, color: AppColors.primaryGray),
                        const SizedBox(height: 8),
                        Text('Front Photo', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                        const SizedBox(height: 4),
                        Text('Tap to view', style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _viewPhotoFullScreen(date, 'side');
                  },
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt, size: 50, color: AppColors.primaryGray),
                        const SizedBox(height: 8),
                        Text('Side Photo', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                        const SizedBox(height: 4),
                        Text('Tap to view', style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _viewPhotoFullScreen(DateTime date, String type) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.camera_alt, color: AppColors.onPrimary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${type == 'front' ? 'Front' : 'Side'} Photo',
                                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
                              ),
                              Text(_formatDate(date), style: AppTextStyles.labelSmall.copyWith(color: AppColors.onPrimary.withOpacity(0.8))),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.onPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Photo placeholder
                  Container(
                    height: 400,
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.primaryGrayLight, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(type == 'front' ? Icons.camera_front : Icons.camera_alt, size: 80, color: AppColors.primaryGray),
                        const SizedBox(height: 16),
                        Text('Photo Preview', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                        const SizedBox(height: 8),
                        Text('TODO: Load actual photo', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray.withOpacity(0.7))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareOptions() {
    final data = _getDataForDate(_selectedDate);
    if (data == null || (data['workout'] == null && data['run'] == null)) {
      Get.snackbar('No Data', 'No workout or run data to share for this date', backgroundColor: AppColors.error, colorText: AppColors.onError, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: AppColors.blackOverlay, blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Share Options',
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Choose how you want to share your activity', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                const SizedBox(height: 24),
                if (data['workout'] != null) ...[
                  _buildShareOptionTile(
                    icon: Icons.article_outlined,
                    title: 'Share Summary',
                    subtitle: 'Share workout summary to social media',
                    onTap: () {
                      Navigator.pop(context);
                      _showSharePreview('summary');
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildShareOptionTile(
                    icon: Icons.download_for_offline_outlined,
                    title: 'Share Workout Download',
                    subtitle: 'Share workout details with a friend',
                    onTap: () {
                      Navigator.pop(context);
                      _showSharePreview('download');
                    },
                  ),
                  if (data['run'] != null) const SizedBox(height: 12),
                ],
                if (data['run'] != null)
                  _buildShareOptionTile(
                    icon: Icons.directions_run,
                    title: 'Share Run Summary',
                    subtitle: 'Share run summary to social media',
                    onTap: () {
                      Navigator.pop(context);
                      _showSharePreview('run');
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareOptionTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: AppColors.blackOverlay.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.primaryGray, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  void _showSharePreview(String type) {
    final data = _getDataForDate(_selectedDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: AppColors.blackOverlay, blurRadius: 24, offset: Offset(0, -4))],
        ),
        child: Column(
          children: [
            // Handle + Header
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.close, color: AppColors.onBackground, size: 20),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          type == 'download' ? 'Workout Download Preview' : 'Share Preview',
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 56),
                    ],
                  ),
                ],
              ),
            ),
            // Preview Content
            Expanded(
              child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), child: _buildSharePreviewContent(type, data)),
            ),
            // Share Button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [BoxShadow(color: AppColors.blackOverlay.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -2))],
              ),
              child: SafeArea(
                top: false,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement actual sharing functionality
                    Navigator.pop(context);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!Get.isSnackbarOpen) {
                        Get.snackbar(
                          'Shared',
                          'Content shared successfully',
                          backgroundColor: AppColors.completed,
                          colorText: AppColors.onError,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      }
                    });
                  },
                  icon: const Icon(Icons.share_rounded, size: 22),
                  label: Text(type == 'download' ? 'Share Workout Download' : 'Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharePreviewContent(String type, Map<String, dynamic>? data) {
    if (type == 'download') {
      // Workout Download Preview
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.blackOverlay, blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center, color: AppColors.accent, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Workout',
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_formatDate(_selectedDate), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
            const SizedBox(height: 24),
            // Mock exercise details
            _buildExerciseDetail('Overhead Press', 'Set 1: Reps: 10 - Weight: 165'),
            _buildExerciseDetail('', 'Set 2: Reps: 12 - Weight: 165'),
            _buildExerciseDetail('', 'Set 3: Reps: 14 - Weight: 165'),
            const SizedBox(height: 16),
            const Divider(color: AppColors.primaryGray),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.timer, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Text('Duration: ${data?['workout']?['duration'] ?? 'N/A'}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.local_fire_department, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Text('Calories: ${data?['workout']?['calories'] ?? 'N/A'}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Recipients can import this workout into their calendar', style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (type == 'run') {
      // Run Summary Preview
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.blackOverlay, blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_run, color: AppColors.accent, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Running Summary',
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_formatDate(_selectedDate), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
            const SizedBox(height: 24),
            _buildRunStat(Icons.route, 'Distance', data?['run']?['distance'] ?? 'N/A'),
            const SizedBox(height: 16),
            _buildRunStat(Icons.timer, 'Time', data?['run']?['time'] ?? 'N/A'),
            const SizedBox(height: 16),
            _buildRunStat(Icons.speed, 'Pace', data?['run']?['pace'] ?? 'N/A'),
            const SizedBox(height: 16),
            _buildRunStat(Icons.local_fire_department, 'Calories', data?['run']?['calories'].toString() ?? 'N/A'),
          ],
        ),
      );
    } else {
      // Workout Summary Preview
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.blackOverlay, blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center, color: AppColors.accent, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Workout',
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_formatDate(_selectedDate), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
            const SizedBox(height: 24),
            _buildWorkoutStat('Duration', data?['workout']?['duration'] ?? 'N/A'),
            const SizedBox(height: 16),
            _buildWorkoutStat('Exercises', data?['workout']?['exercises'].toString() ?? 'N/A'),
            const SizedBox(height: 16),
            _buildWorkoutStat('Sets', data?['workout']?['sets'].toString() ?? 'N/A'),
            const SizedBox(height: 16),
            _buildWorkoutStat('Calories', data?['workout']?['calories'].toString() ?? 'N/A'),
          ],
        ),
      );
    }
  }

  Widget _buildExerciseDetail(String name, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (name.isNotEmpty) const Icon(Icons.fiber_manual_record, size: 8, color: AppColors.accent),
          if (name.isNotEmpty) const SizedBox(width: 8),
          if (name.isEmpty) const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty) Text(name, style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
                Text(detail, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunStat(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
              Text(value, style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutStat(String label, String value) {
    return Row(
      children: [
        Icon(
          label == 'Duration'
              ? Icons.timer
              : label == 'Exercises'
              ? Icons.fitness_center
              : label == 'Sets'
              ? Icons.repeat
              : Icons.local_fire_department,
          color: AppColors.accent,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
              Text(value, style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text('Calendar', style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent)),
        centerTitle: true,
        actions: const [],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(const Color(0xFFE74C3C), 'Incomplete'),
                  const SizedBox(width: 12),
                  _buildLegendItem(const Color(0xFF6FCF97), 'Completed'),
                  const SizedBox(width: 12),
                  _buildLegendItem(const Color(0xFF4A90E2), 'Rest Day'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Top: Year + Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppColors.onSurface),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year - 1, _focusedMonth.month);
                      });
                    },
                  ),
                  Text('${_focusedMonth.year}', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppColors.onSurface),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year + 1, _focusedMonth.month);
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.white,
                        hintText: 'Search exercise',
                        hintStyle: AppTextStyles.titleSmall.copyWith(color: AppColors.primaryGrayDark.withOpacity(0.6), fontSize: 14.sp),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide(color: AppColors.primaryGrayDark.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide(color: AppColors.primaryGrayDark.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide(color: AppColors.accent.withOpacity(0.3), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        suffixIcon: IconButton(
                          icon: SizedBox(width: 22, height: 22, child: SvgPicture.asset('assets/icons/search-normal.svg', width: 22, height: 22)),
                          onPressed: () => () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ).paddingOnly(right: 12),
                      ),
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Calendar
            Column(
              children: [
                // Month label (left-aligned like mock)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _getMonthName(_focusedMonth.month),
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                // Weekday headers
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                        .map(
                          (day) => SizedBox(
                            width: 40,
                            child: Center(
                              child: Text(day, style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGray)),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Calendar grid
                _buildCalendarGrid(),
                const SizedBox(height: 16),

                // Pagination dots below calendar
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.3), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.3), shape: BoxShape.circle),
                      ),
                    ],
                  ),
                ).paddingOnly(bottom: 16),
              ],
            ),
            const SizedBox(height: 24),

            // Selected date header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _formatDate(_selectedDate),
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // Day detail view
            _buildDayDetailView(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < 0) {
            // Swipe left → next month
            setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
            });
          } else if (details.primaryVelocity! > 0) {
            // Swipe right → previous month
            setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
            });
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.75),
          itemCount: firstWeekday + daysInMonth,
          itemBuilder: (context, index) {
            if (index < firstWeekday) return const SizedBox();

            final day = index - firstWeekday + 1;
            final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
            final isSelected = _selectedDate.year == date.year && _selectedDate.month == date.month && _selectedDate.day == date.day;
            final isToday = DateTime.now().year == date.year && DateTime.now().month == date.month && DateTime.now().day == date.day;
            final dateColor = _getDateColor(date);
            final hasPhoto = _hasProgressPhoto(date);

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = date;
                });
              },
              onLongPress: () {
                setState(() {
                  _selectedDate = date;
                });
                _showAddWorkoutDialog();
              },
              child: Builder(
                builder: (context) {
                  final int position = index - firstWeekday;
                  final int rowIndex = position >= 0 ? (position / 7).floor() : 0;
                  return Container(
                    // Vertical margin only so horizontal borders join seamlessly
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      border: rowIndex > 0 ? Border(top: BorderSide(color: AppColors.primaryGray.withOpacity(0.3), width: 1)) : null,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        // Keep today's outline as before
                        border: isToday && !isSelected ? Border.all(color: AppColors.accent, width: 1.6) : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Selected day circular highlight
                          if (isSelected)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(color: Color(0xFFE74C3C), shape: BoxShape.circle),
                            ),
                          Text(
                            '$day',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isSelected ? Colors.white : (isToday ? AppColors.onBackground : AppColors.onSurface),
                              fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (dateColor != Colors.transparent)
                            Positioned(
                              bottom: 6,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(color: dateColor, shape: BoxShape.circle),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDayDetailView() {
    final data = _getDataForDate(_selectedDate);

    if (data == null ||
        (data['workout'] == null && data['run'] == null && data['nutrition'] == null && (data['notes'] == null || data['notes'].toString().isEmpty) && !data['hasProgressPhoto'])) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.calendar_month_outlined, size: 60, color: AppColors.green),
              const SizedBox(height: 16),
              Text('No data for this day', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.green)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Data'),
                  onPressed: _showAddWorkoutDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Progress Photos Section with swipe hint
          if (data['hasProgressPhoto']) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Text('Swipe left for Progress Pictures', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray))],
            ),
            const SizedBox(height: 8),
            // Pagination dots for progress photos
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.3), shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.3), shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildProgressPhotosSection(),
            const SizedBox(height: 12),
          ],

          // Workout Summary
          if (data['workout'] != null) _buildWorkoutSummarySection(data['workout']),

          // Run Summary
          if (data['run'] != null) _buildRunSummarySection(data['run']),

          // Simple Calories Card (when only run calories available, no nutrition card)
          if (data['run'] != null && data['nutrition'] == null && data['workout'] == null) _buildSimpleCaloriesCard(data['run']),

          // Nutrition Summary
          if (data['nutrition'] != null) _buildNutritionSummarySection(data['nutrition']),

          // Notes Section
          if (data['notes'] != null && data['notes'].toString().isNotEmpty) _buildNotesSection(data['notes']),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showAddWorkoutDialog,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Add'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(color: AppColors.accent.withOpacity(0.8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showShareOptions,
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressPhotosSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: AppColors.blackOverlay.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress Pictures',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _showPhotoHistory,
                icon: const Icon(Icons.history, size: 16),
                label: const Text('History'),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _viewPhotoFullScreen(_selectedDate, 'front'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGrayLight.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_front_rounded, size: 36, color: AppColors.primaryGray),
                          const SizedBox(height: 8),
                          Text('Front Photo', style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface)),
                          const SizedBox(height: 2),
                          Text('Tap to view', style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _viewPhotoFullScreen(_selectedDate, 'side'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGrayLight.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded, size: 36, color: AppColors.primaryGray),
                          const SizedBox(height: 8),
                          Text('Side Photo', style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface)),
                          const SizedBox(height: 2),
                          Text('Tap to view', style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutSummarySection(Map<String, dynamic> workout) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.fitness_center, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Workout Summary',
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showShareOptions(),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.share_rounded, color: AppColors.accent, size: 22),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(Icons.timer, 'Duration', workout['duration'] ?? 'N/A'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildStatItem(Icons.fitness_center, 'Exercises', workout['exercises'].toString())),
              const SizedBox(width: 5),
              Expanded(child: _buildStatItem(Icons.repeat, 'Sets', workout['sets'].toString())),
              const SizedBox(width: 5),
              Expanded(child: _buildStatItem(Icons.local_fire_department, 'Calories', workout['calories'].toString())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleCaloriesCard(Map<String, dynamic> run) {
    final calories = run['calories']?.toString() ?? '0';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppColors.blackOverlay.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.local_fire_department, color: AppColors.primaryGray, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Calories', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
          const Spacer(),
          Text(
            calories,
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRunSummarySection(Map<String, dynamic> run) {
    return GestureDetector(
      onTap: () => _viewRunDetails(run),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withOpacity(0.4)),
          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.directions_run, color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Running Summary',
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showShareOptions(),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.share_rounded, color: AppColors.accent, size: 22),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.route, 'Distance', run['distance'] ?? '0 km'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.timer, 'Time', run['time'] ?? '0:00'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.speed, 'Pace', run['pace'] ?? '--:-- /km'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.local_fire_department, 'Calories', (run['calories'] ?? 0).toString()),
          ],
        ),
      ),
    );
  }

  void _viewRunDetails(Map<String, dynamic> runData) {
    try {
      // If we have the actual RunModel stored, use it directly
      if (runData['runModel'] != null && runData['runModel'] is RunModel) {
        Get.toNamed(AppRoutes.runDetail, arguments: runData['runModel'] as RunModel);
        return;
      }

      // Otherwise, parse the run data from planner format to RunModel
      // Parse distance (e.g., "3.00 km" -> 3000 meters)
      final distanceStr = runData['distance']?.toString() ?? '0 km';
      final distanceMatch = RegExp(r'([\d.]+)\s*km').firstMatch(distanceStr);
      final distanceKm = distanceMatch != null ? double.tryParse(distanceMatch.group(1) ?? '0') ?? 0.0 : 0.0;
      final distanceMeters = distanceKm * 1000;

      // Parse time (e.g., "20:00" -> Duration)
      final timeStr = runData['time']?.toString() ?? '0:00';
      final timeParts = timeStr.split(':');
      final minutes = timeParts.length >= 1 ? int.tryParse(timeParts[0]) ?? 0 : 0;
      final seconds = timeParts.length >= 2 ? int.tryParse(timeParts[1]) ?? 0 : 0;
      final duration = Duration(minutes: minutes, seconds: seconds);

      // Parse pace (e.g., "4:00 /km" -> averagePace in min/km)
      final paceStr = runData['pace']?.toString() ?? '0:00 /km';
      final paceMatch = RegExp(r'(\d+):(\d+)\s*\/km').firstMatch(paceStr);
      final paceMinutes = paceMatch != null ? int.tryParse(paceMatch.group(1) ?? '0') ?? 0 : 0;
      final paceSeconds = paceMatch != null ? int.tryParse(paceMatch.group(2) ?? '0') ?? 0 : 0;
      final averagePace = paceMinutes + (paceSeconds / 60.0);

      // Get calories
      final calories = runData['calories'] is int ? runData['calories'] as int : (runData['calories'] is String ? int.tryParse(runData['calories'].toString()) ?? 0 : 0);

      // Create RunModel from parsed data
      final runModel = RunModel(
        id: runData['id'] ?? 'planner_${_selectedDate.millisecondsSinceEpoch}',
        userId: 'current_user',
        activityType: 'run',
        distanceMeters: distanceMeters,
        duration: duration,
        startTime: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, DateTime.now().hour, DateTime.now().minute),
        endTime: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, DateTime.now().hour, DateTime.now().minute).add(duration),
        averagePace: averagePace,
        caloriesBurned: calories > 0 ? calories : null,
        createdAt: _selectedDate,
      );

      Get.toNamed(AppRoutes.runDetail, arguments: runModel);
    } catch (e) {
      Get.snackbar('Error', 'Unable to view run details: $e', backgroundColor: AppColors.error, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Widget _buildNutritionSummarySection(Map<String, dynamic> nutrition) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.upcoming.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: AppColors.upcoming.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.upcoming.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.restaurant_rounded, color: AppColors.upcoming, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Nutrition',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(Icons.local_fire_department, 'Calories', nutrition['calories']),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.fitness_center, 'Protein', nutrition['protein']),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.rice_bowl, 'Carbs', nutrition['carbs']),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.water_drop, 'Fats', nutrition['fats']),
        ],
      ),
    );
  }

  Widget _buildNotesSection(String notes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: AppColors.blackOverlay.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.note_alt_rounded, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Notes',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showNotesDialog,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.edit_rounded, size: 20, color: AppColors.primaryGray),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(notes, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryGray, size: 18),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return 'Today\'s Schedule';
    }
    // Format as "DEC 5, 2025" to match design
    final monthAbbrev = DateFormat('MMM').format(date).toUpperCase();
    return '$monthAbbrev ${date.day}, ${date.year}';
  }
}
