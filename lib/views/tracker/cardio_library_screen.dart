import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_right/data/gr_cardio_catalog.dart';
import 'package:get_right/models/gr_cardio_entry.dart';
import 'package:get_right/models/planned_route_model.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

const Color _kScreenBg = Color(0xFFFAFFEF);
const Color _kCardBg = Color(0xFFFFFFFF);
const Color _kCardBorder = Color(0xFFE2EBD8);
const Color _kMutedText = Color(0xFF6B7A6E);
const Color _kIconCircle = Color(0xFFE8F0E4);
const Color _kTagBg = Color(0xFFE8F0E4);

/// Cardio Library — sourced from GR `CardioList.json`.
class CardioLibraryScreen extends StatefulWidget {
  const CardioLibraryScreen({super.key});

  @override
  State<CardioLibraryScreen> createState() => _CardioLibraryScreenState();
}

class _CardioLibraryScreenState extends State<CardioLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  final Set<String> _activeFilters = {};
  PlannedRouteModel? _plannedRoute;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args['plannedRoute'] != null) {
      _plannedRoute = args['plannedRoute'] as PlannedRouteModel;
    }
    _searchController.addListener(_onSearchChanged);
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await GrCardioCatalog.instance.ensureLoaded();
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.trim());
  }

  List<GrCardioEntry> get _visibleEntries {
    var list = _searchQuery.isEmpty
        ? GrCardioCatalog.instance.all
        : GrCardioCatalog.instance.search(_searchQuery);
    if (_activeFilters.isNotEmpty) {
      list = list.where((e) => e.tags.any(_activeFilters.contains)).toList(growable: false);
    }
    return list;
  }

  void _onFilterTap() {
    final tags = GrCardioCatalog.instance.availableTags.toList()..sort();
    if (tags.isEmpty) return;

    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
          decoration: BoxDecoration(
            color: _kScreenBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filters',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: tags.map((tag) {
                      final selected = _activeFilters.contains(tag);
                      return FilterChip(
                        label: Text(tag[0].toUpperCase() + tag.substring(1)),
                        selected: selected,
                        onSelected: (value) {
                          setSheetState(() {
                            if (value) {
                              _activeFilters.add(tag);
                            } else {
                              _activeFilters.remove(tag);
                            }
                          });
                          setState(() {});
                        },
                        selectedColor: AppColors.accent.withValues(alpha: 0.15),
                        checkmarkColor: AppColors.accent,
                        labelStyle: AppTextStyles.labelMedium.copyWith(
                          color: selected ? AppColors.accent : _kMutedText,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(color: selected ? AppColors.accent : _kCardBorder),
                        backgroundColor: _kCardBg,
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setSheetState(() => _activeFilters.clear());
                          setState(() {});
                        },
                        child: Text('Clear', style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent)),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => Get.back(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _openCardio(GrCardioEntry entry) {
    final args = <String, dynamic>{
      'activityType': entry.activityType,
      'cardioId': entry.id,
      'cardioName': entry.name,
      'trackingMode': entry.trackingMode,
    };
    if (_plannedRoute != null) {
      args['plannedRoute'] = _plannedRoute;
    }
    Get.toNamed(AppRoutes.runTracking, arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleEntries;

    return Scaffold(
      backgroundColor: _kScreenBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8.w, 4.h, 16.w, 0),
              child: IconButton(
                onPressed: () => Get.back(),
                icon: Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 20.sp),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 0),
              child: Text(
                'Cardio Library',
                style: GoogleFonts.libreBaskerville(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 32.sp,
                  height: 1.15,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 16.h),
              child: Text(
                'Choose the type of cardio you want to log.',
                style: AppTextStyles.bodyMedium.copyWith(color: _kMutedText, height: 1.4),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.black),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _kCardBg,
                        hintText: 'Search cardio workouts...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: _kMutedText),
                        prefixIcon: Icon(Icons.search, color: _kMutedText, size: 22.sp),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: _kMutedText, size: 20.sp),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _kCardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _kCardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Material(
                    color: _kCardBg,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _onFilterTap,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 52.h,
                        padding: EdgeInsets.symmetric(horizontal: 14.w),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _activeFilters.isNotEmpty ? AppColors.accent : _kCardBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune, color: AppColors.accent, size: 18.sp),
                            SizedBox(width: 6.w),
                            Text(
                              'Filters',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _error != null
                      ? _buildError()
                      : visible.isEmpty
                          ? _buildEmpty()
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
                              itemCount: visible.length,
                              separatorBuilder: (_, __) => SizedBox(height: 12.h),
                              itemBuilder: (context, index) => _CardioListTile(
                                entry: visible[index],
                                onTap: () => _openCardio(visible[index]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Couldn’t load cardio workouts',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: _kMutedText), textAlign: TextAlign.center),
            SizedBox(height: 16.h),
            TextButton(onPressed: _loadCatalog, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Text(
          _searchQuery.isNotEmpty || _activeFilters.isNotEmpty
              ? 'No cardio workouts match your search.'
              : 'No cardio workouts in CardioList yet.',
          style: AppTextStyles.bodyMedium.copyWith(color: _kMutedText),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _CardioListTile extends StatelessWidget {
  final GrCardioEntry entry;
  final VoidCallback onTap;

  const _CardioListTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kCardBg,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kCardBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: const BoxDecoration(color: _kIconCircle, shape: BoxShape.circle),
                child: Icon(entry.iconData, color: AppColors.accent, size: 24.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      entry.description,
                      style: AppTextStyles.bodySmall.copyWith(color: _kMutedText, height: 1.3),
                    ),
                    if (entry.metrics.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 6.h,
                        children: entry.metrics.map((metric) {
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: _kTagBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              metric,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.sp,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(Icons.chevron_right, color: _kMutedText, size: 22.sp),
            ],
          ),
        ),
      ),
    );
  }
}
