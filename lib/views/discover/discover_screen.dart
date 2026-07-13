import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/models/discover_user.dart';
import 'package:get_right/repo/discover_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/safe_circle_network_avatar.dart';

/// Discover users — `GET /user/discover`.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final DiscoverRepository _repo = DiscoverRepository();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<DiscoverUser> _users = [];
  Timer? _searchDebounce;

  DiscoverSort _sort = DiscoverSort.newest;
  String? _roleFilter;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNext = true;
  int _page = 1;
  int _totalDocs = 0;
  String? _error;

  static const int _limit = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore || !_hasNext) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _load(reset: false);
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      if (_loadingMore) return;
    } else {
      if (_loadingMore || !_hasNext) return;
    }

    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
        _page = 1;
        _hasNext = true;
        _users.clear();
      } else {
        _loadingMore = true;
      }
    });

    final pageToFetch = reset ? 1 : _page;

    try {
      final result = await _repo.fetchDiscoverUsers(
        search: _searchController.text.trim(),
        role: _roleFilter,
        sort: _sort,
        page: pageToFetch,
        limit: _limit,
      );
      if (!mounted) return;

      setState(() {
        if (reset) {
          _users
            ..clear()
            ..addAll(result.users);
        } else {
          final existing = _users.map((u) => u.id).toSet();
          _users.addAll(result.users.where((u) => !existing.contains(u.id)));
        }
        _totalDocs = result.totalDocs;
        _hasNext = result.hasNextPage;
        _page = result.currentPage + 1;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (reset) {
          _error = e.toString().replaceFirst('Exception: ', '');
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _openProfile(DiscoverUser user) {
    Get.toNamed(AppRoutes.trainerProfile, arguments: user.toProfileArgs());
  }

  Future<void> _openSortSheet() async {
    final picked = await showModalBottomSheet<DiscoverSort>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.35), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text('Sort by', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final option in DiscoverSort.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(option.label, style: AppTextStyles.bodyMedium),
                    trailing: _sort == option ? const Icon(Icons.check_rounded, color: AppColors.accent) : null,
                    onTap: () => Navigator.pop(context, option),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null || picked == _sort) return;
    setState(() => _sort = picked);
    _load(reset: true);
  }

  Widget _buildSortButton({EdgeInsetsGeometry? margin}) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: OutlinedButton.icon(
        onPressed: _openSortSheet,
        icon: const Icon(Icons.sort_rounded, size: 18, color: AppColors.accent),
        label: Text(
          _sort.label,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCDE7C8)),
          backgroundColor: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Text('Discover', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        actions: [
          _buildSortButton(margin: const EdgeInsets.only(right: 12)),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search people...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryGray),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.primaryGray),
                        onPressed: () {
                          _searchController.clear();
                          _load(reset: true);
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCDE7C8))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCDE7C8))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _roleChip('All', null),
                  _roleChip('Trainers', 'Trainer'),
                  _roleChip('Customers', 'Customer'),
                ],
              ),
            ),
          ),
          if (_totalDocs > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$_totalDocs result${_totalDocs == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _roleChip(String label, String? role) {
    final selected = _roleFilter == role;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          if (_roleFilter == role) return;
          setState(() => _roleFilter = role);
          _load(reset: true);
        },
        selectedColor: AppColors.accent.withOpacity(0.15),
        checkmarkColor: AppColors.accent,
        labelStyle: AppTextStyles.labelSmall.copyWith(
          color: selected ? AppColors.accent : AppColors.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(color: selected ? AppColors.accent.withOpacity(0.45) : const Color(0xFFCDE7C8)),
        backgroundColor: AppColors.surface,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_error != null && _users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search_outlined, size: 64, color: AppColors.accent.withOpacity(0.6)),
              const SizedBox(height: 16),
              Text('No users found', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Try a different search or filter.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _users.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _users.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
              ),
            );
          }
          return _buildUserCard(_users[index]);
        },
      ),
    );
  }

  Widget _buildUserCard(DiscoverUser user) {
    final initials = user.name.isNotEmpty
        ? user.name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join()
        : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCDE7C8)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openProfile(user),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SafeCircleNetworkAvatar(
                  radius: 28,
                  imageUrl: user.avatarUrl,
                  backgroundColor: AppColors.accent.withOpacity(0.15),
                  fallback: Text(initials, style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _metaChip(user.role.isNotEmpty ? user.role : 'User'),
                          if (user.isTrainer) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.people_outline, size: 14, color: AppColors.primaryGray),
                            const SizedBox(width: 2),
                            Text('${user.followersCount}', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                          ],
                        ],
                      ),
                      if (user.avgRating > 0 || user.totalReviews > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.star_rounded, size: 16, color: AppColors.upcoming),
                            const SizedBox(width: 2),
                            Text(
                              user.avgRating.toStringAsFixed(user.avgRating % 1 == 0 ? 0 : 1),
                              style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface),
                            ),
                            if (user.totalReviews > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${user.totalReviews} review${user.totalReviews == 1 ? '' : 's'})',
                                style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.primaryGray),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 11.sp),
      ),
    );
  }
}
