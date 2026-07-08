import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/models/exercise_detail.dart';
import 'package:get_right/repo/marketplace_repo.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/marketplace/program_hls_player_screen.dart';

/// Exercise detail screen — data from `GET /user/exercises/:exerciseId`.
class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({super.key});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  final MarketplaceRepository _repo = MarketplaceRepository();

  late Map<String, dynamic> _routeArgs;
  late String _exerciseId;

  ExerciseDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _routeArgs = Get.arguments as Map<String, dynamic>;
    _exerciseId = _routeArgs['_id']?.toString() ?? _routeArgs['id']?.toString() ?? '';
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (_exerciseId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Invalid exercise';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detail = await _repo.fetchExerciseDetail(_exerciseId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String get _displayName => _detail?.name ?? _routeArgs['name']?.toString() ?? '';

  bool get _showAddToWorkout {
    if (_routeArgs['fromLibrary'] == true) return false;
    if (_routeArgs['fromWorkout'] != true) return false;
    final added = _routeArgs['addedExerciseIds'];
    if (added is List) {
      final ids = added.map((e) => e.toString()).toSet();
      if (ids.contains(_exerciseId)) return false;
    }
    return true;
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return AppColors.accentVariant;
      case 'intermediate':
        return AppColors.upcoming;
      case 'advanced':
        return AppColors.error;
      default:
        return AppColors.primaryGray;
    }
  }

  double _getDifficultyValue(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return 0.33;
      case 'intermediate':
        return 0.66;
      case 'advanced':
        return 1.0;
      default:
        return 0.5;
    }
  }

  void _openVideo() {
    final url = _detail?.videoUrl;
    if (url == null || url.isEmpty) {
      Get.snackbar('Video unavailable', 'No video for this exercise.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      Get.snackbar('Video unavailable', 'Invalid video URL.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    Get.to<void>(() => ProgramHlsPlayerScreen(videoUri: uri, title: _displayName));
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
          _displayName,
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.onPrimary),
            onPressed: () {},
          ),
        ],
      ),
      // bottomNavigationBar: _detail == null || !_showAddToWorkout
      //     ? null
      //     : SafeArea(
      //         child: Padding(
      //           padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
      //           child: SizedBox(
      //             height: 52.h,
      //             child: ElevatedButton.icon(
      //               onPressed: () {
      //                 Get.snackbar(
      //                   'Added to Workout',
      //                   '$_displayName has been added to your workout',
      //                   backgroundColor: AppColors.completed,
      //                   colorText: Colors.white,
      //                   snackPosition: SnackPosition.BOTTOM,
      //                 );
      //               },
      //               style: ElevatedButton.styleFrom(
      //                 backgroundColor: AppColors.accentVariant,
      //                 foregroundColor: Colors.white,
      //                 elevation: 0,
      //                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      //               ),
      //               icon: const Icon(Icons.add_circle_outline, size: 22),
      //               label: Text(
      //                 'Add to Workout',
      //                 style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      //               ),
      //             ),
      //           ),
      //         ),
      //       ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Could not load exercise', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
                    SizedBox(height: 8.h),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                    ),
                    SizedBox(height: 16.h),
                    TextButton(onPressed: _loadDetail, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _buildContent(_detail!),
    );
  }

  Widget _buildContent(ExerciseDetail detail) {
    final difficulty = detail.difficultyLabel;
    final difficultyColor = _getDifficultyColor(difficulty);
    final difficultyValue = _getDifficultyValue(difficulty);
    final imageUrl = detail.displayImageUrl ?? detail.videoThumbnailUrl ?? detail.iconUrl ?? '';
    final rec = detail.recommendations ?? const ExerciseRecommendations();
    final whyText = detail.description?.isNotEmpty == true ? detail.description! : 'This exercise targets the ${detail.categoryLabel} muscles effectively.';

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8.h),
          GestureDetector(
            onTap: detail.videoUrl != null ? _openVideo : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: 200.h,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return _imagePlaceholder(showProgress: true);
                          },
                          errorBuilder: (c, e, s) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                  if (detail.videoUrl != null)
                    Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                      child: Image.asset('assets/images/playbutton.png', width: 24.w, height: 24.h),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: _buildInfoStatCard(assetImage: 'assets/images/clock333.png', label: detail.durationLabel),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildInfoStatCard(assetImage: 'assets/images/1. bench press.png', networkImageUrl: detail.iconUrl, label: detail.categoryLabel),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildInfoStatCard(assetImage: 'assets/images/intermidiate.png', label: difficulty, accentIcon: true),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Text('Difficulty Level', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(difficulty, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              Text('${(difficultyValue * 100).toInt()}%', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: difficultyValue,
              minHeight: 8,
              backgroundColor: AppColors.primaryGray.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(difficultyColor),
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Beginner', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
              Text('Advanced', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
            ],
          ),
          SizedBox(height: 28.h),
          Text('Why?', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
          SizedBox(height: 10.h),
          Text(whyText, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, height: 1.6)),
          SizedBox(height: 28.h),
          Text('Recommended Programming', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(child: _buildStatCard('assets/images/sets111.png', 'Sets', rec.setsLabel, const Color(0xFFF5E6C8))),
              SizedBox(width: 10.w),
              Expanded(child: _buildStatCard('assets/images/infinity.png', 'Reps', rec.repsLabel, const Color(0xFFCCDFF3))),
              SizedBox(width: 10.w),
              Expanded(child: _buildStatCard('assets/images/clock333.png', 'Rest Time', rec.restTimeLabel, const Color(0xFFD6E8D0))),
            ],
          ),
          if (rec.weightLabel != null) ...[
            SizedBox(height: 12.h),
            Text(
              'Suggested weight: ${rec.weightLabel}',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
            ),
          ],
          if (detail.formCues.isNotEmpty) ...[SizedBox(height: 28.h), _buildKeyFormCuesCard(detail.formCues)],
          SizedBox(height: 24.h),
          Text('Targeted Muscles', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Primary:',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.black, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6.h),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: detail.targetMuscles.isEmpty ? [_buildMuscleChip('—', true)] : detail.targetMuscles.map((m) => _buildMuscleChip(m, true)).toList(),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Secondary:',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.black, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6.h),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: detail.secondaryMuscles.isEmpty ? [_buildMuscleChip('—', false)] : detail.secondaryMuscles.map((m) => _buildMuscleChip(m, false)).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (detail.tagNames.isNotEmpty) ...[
            SizedBox(height: 20.h),
            Text('Equipment', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
            SizedBox(height: 10.h),
            Wrap(spacing: 6, runSpacing: 6, children: detail.tagNames.map((t) => _buildMuscleChip(t, false)).toList()),
          ],
          if (detail.proTips.isNotEmpty) ...[
            SizedBox(height: 28.h),
            Text('Pro Tips', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
            SizedBox(height: 10.h),
            ...detail.proTips.asMap().entries.map((e) => _buildTipItem(e.key + 1, e.value)),
          ],
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _imagePlaceholder({bool showProgress = false}) {
    return Container(
      width: double.infinity,
      height: 200.h,
      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
      child: Center(
        child: showProgress
            ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
            : const Icon(Icons.fitness_center, color: AppColors.accent, size: 40),
      ),
    );
  }

  static const Color _kInfoCardText = Color(0xFF3D3D3D);

  Widget _buildInfoStatCard({required String label, String? assetImage, String? networkImageUrl, bool accentIcon = false}) {
    final networkUrl = networkImageUrl?.trim();
    Widget iconWidget;
    if (networkUrl != null && networkUrl.isNotEmpty) {
      iconWidget = Image.network(
        networkUrl,
        fit: BoxFit.contain,
        width: 30.w,
        height: 30.h,
        errorBuilder: (_, __, ___) => assetImage != null
            ? Image.asset(assetImage, fit: BoxFit.contain, width: 30.w, height: 30.h)
            : Icon(Icons.fitness_center, size: 30.sp, color: accentIcon ? AppColors.accent : _kInfoCardText),
      );
    } else if (assetImage != null) {
      iconWidget = Image.asset(assetImage, fit: BoxFit.contain, width: 30.w, height: 30.h);
    } else {
      iconWidget = Icon(Icons.fitness_center, size: 30.sp, color: accentIcon ? AppColors.accent : _kInfoCardText);
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 6.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          SizedBox(height: 10.h),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w800, fontSize: 12.sp, color: _kInfoCardText, height: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String image, String label, String value, Color iconBg) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E0), width: 0.8),
      ),
      child: Column(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Padding(
              padding: EdgeInsets.all(10.w),
              child: Image.asset(image, fit: BoxFit.contain),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.onBackground, fontSize: 12.sp),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  static const Color _kFormCuesBg = Color(0xFFF8FFE9);
  static const Color _kFormCuesBorder = Color(0xFFE2ECD8);
  static const Color _kFormCuesTitle = Color(0xFF0D1B2A);
  static const Color _kFormCuesBody = Color(0xFF2D3436);

  Widget _buildKeyFormCuesCard(List<String> cues) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 20.h),
      decoration: BoxDecoration(
        color: _kFormCuesBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kFormCuesBorder, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Form Cues',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800, fontSize: 19.sp, color: _kFormCuesTitle, height: 1.2),
          ),
          SizedBox(height: 14.h),
          ...cues.asMap().entries.map((e) {
            final isLast = e.key == cues.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
              child: Text(
                e.value,
                style: AppTextStyles.bodyMedium.copyWith(color: _kFormCuesBody, fontSize: 15.sp, fontWeight: FontWeight.w400, height: 1.5),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTipItem(int index, String tip) {
    final numberStr = index.toString().padLeft(2, '0');
    final Color numberColor = _tipNumberColor(index);
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6F0DA), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            numberStr,
            style: AppTextStyles.titleMedium.copyWith(color: numberColor, fontWeight: FontWeight.w800),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(tip, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Color _tipNumberColor(int index) {
    const List<Color> palette = [Color(0xFFF39C12), Color(0xFF2E86DE), Color(0xFF27AE60), Color(0xFF8E44AD)];
    return palette[(index - 1) % palette.length];
  }

  Widget _buildMuscleChip(String muscle, bool isPrimary) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(color: const Color(0xFFE5F2CF), borderRadius: BorderRadius.circular(50)),
      child: Text(
        muscle,
        style: AppTextStyles.bodySmall.copyWith(color: isPrimary ? AppColors.accent : AppColors.black, fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500),
      ),
    );
  }
}
