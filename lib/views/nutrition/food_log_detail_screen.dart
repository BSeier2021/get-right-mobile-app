import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/models/food_log_detail.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:intl/intl.dart';

/// Food log detail — loads `GET /customer/food-logs/:foodLogId`.
class FoodLogDetailScreen extends StatefulWidget {
  final String foodLogId;

  const FoodLogDetailScreen({super.key, required this.foodLogId});

  @override
  State<FoodLogDetailScreen> createState() => _FoodLogDetailScreenState();
}

class _FoodLogDetailScreenState extends State<FoodLogDetailScreen> {
  FoodLogDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!Get.isRegistered<AuthController>()) {
      setState(() {
        _loading = false;
        _error = 'Sign in to view food log';
      });
      return;
    }
    final detail = await Get.find<AuthController>().fetchFoodLogDetail(widget.foodLogId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _detail = detail;
      _error = detail == null ? 'Could not load food log' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        centerTitle: true,
        elevation: 0,
        title: Text('Food Log', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final log = _detail!;
    final loggedLocal = log.loggedAt.toLocal();
    final dateLabel = DateFormat('EEEE, MMM d, yyyy').format(loggedLocal);
    final timeLabel = DateFormat('h:mm a').format(loggedLocal);
    final servingsLabel = log.servings % 1 == 0 ? log.servings.toStringAsFixed(0) : log.servings.toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            log.meal.name,
            style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.restaurant_menu_outlined, log.mealType),
              _chip(Icons.schedule_outlined, '$dateLabel · $timeLabel'),
              _chip(Icons.scale_outlined, '$servingsLabel serving${log.servings == 1 ? '' : 's'}'),
            ],
          ),
          if (log.notes != null && log.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes', style: AppTextStyles.labelMedium.copyWith(color: AppColors.mediumGray, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(log.notes!.trim(), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Nutrition (logged)', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
          const SizedBox(height: 12),
          _nutritionCard(
            calories: log.calories,
            protein: log.protein,
            carbs: log.carbs,
            fats: log.fats,
          ),
          const SizedBox(height: 24),
          Text('Food info', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightGray),
            ),
            child: Column(
              children: [
                _infoRow('Serving size', '${log.meal.nutritionApiServingSize?.toStringAsFixed(0) ?? '—'} ${log.meal.nutritionApiServingUnit ?? log.meal.servingUnit ?? ''}'.trim()),
                const Divider(height: 20, color: AppColors.lightGray),
                _infoRow('Per serving calories', '${log.meal.calories.toStringAsFixed(0)} kcal'),
                const Divider(height: 20, color: AppColors.lightGray),
                _infoRow('Type', log.meal.isNutritionApiCustom ? 'Custom' : 'Saved'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _nutritionCard({
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F4CC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBDE2B7)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _macroTile('Calories', '${calories.toStringAsFixed(0)}', 'kcal', const Color(0xFF2F7D32)),
              ),
              Expanded(
                child: _macroTile('Protein', protein.toStringAsFixed(1), 'g', AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _macroTile('Carbs', carbs.toStringAsFixed(1), 'g', const Color(0xFFE67E22)),
              ),
              Expanded(
                child: _macroTile('Fats', fats.toStringAsFixed(1), 'g', const Color(0xFF3498DB)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroTile(String label, String value, String unit, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.mediumGray)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          Text(unit, style: AppTextStyles.labelSmall.copyWith(color: AppColors.mediumGray)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray))),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
