import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/models/support_ticket.dart';
import 'package:get_right/repo/support_ticket_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/support_ticket_email.dart';
import 'package:get_right/widgets/common/custom_button.dart';
import 'package:intl/intl.dart';

/// Paginated support ticket list — `GET /user/support-tickets`.
class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> with SingleTickerProviderStateMixin {
  final SupportTicketRepository _repo = SupportTicketRepository();
  final ScrollController _scrollController = ScrollController();
  late final TabController _tabController;

  final List<SupportTicket> _tickets = [];
  String? _email;
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNext = true;
  int _page = 1;
  bool _accountBlocked = false;

  static const int _limit = 10;
  static const _tabs = ['All', 'Open', 'In Progress', 'Closed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _init();
  }

  Future<void> _init() async {
    final args = Get.arguments;
    if (args is Map) {
      _accountBlocked = args['accountBlocked'] == true;
    }
    _email = await resolveSupportTicketEmail(
      overrideEmail: args is Map ? args['email']?.toString() : null,
    );
    if (!mounted) return;
    if (_email == null || _email!.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Enter your account email to view support tickets.';
      });
      return;
    }
    await _load(reset: true);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _load(reset: true);
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore || !_hasNext) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _load(reset: false);
    }
  }

  String? get _statusFilter {
    switch (_tabController.index) {
      case 1:
        return 'Open';
      case 2:
        return 'InProgress';
      case 3:
        return 'Closed';
      default:
        return null;
    }
  }

  Future<void> _load({required bool reset}) async {
    final email = _email;
    if (email == null || email.isEmpty) return;

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
        _tickets.clear();
      } else {
        _loadingMore = true;
      }
    });

    final pageToFetch = reset ? 1 : _page;

    try {
      final result = await _repo.fetchTickets(
        email: email,
        page: pageToFetch,
        limit: _limit,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _tickets
            ..clear()
            ..addAll(result.tickets);
        } else {
          final existing = _tickets.map((t) => t.id).toSet();
          for (final ticket in result.tickets) {
            if (!existing.contains(ticket.id)) _tickets.add(ticket);
          }
        }
        _hasNext = result.hasNextPage;
        _page = pageToFetch + 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _openCreate() async {
    final created = await Get.toNamed(AppRoutes.createSupportTicket, arguments: {'email': _email});
    if (created == true) {
      await _load(reset: true);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return const Color(0xFF5A9BD5);
      case 'inprogress':
        return const Color(0xFFD4A24C);
      case 'closed':
        return AppColors.primaryGray;
      default:
        return AppColors.accent;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'inprogress':
        return 'In Progress';
      default:
        return status;
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
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text('Support Tickets', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.h),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: EdgeInsets.only(left: 8.w),
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.primaryGray,
              indicatorColor: AppColors.accent,
              dividerColor: Colors.transparent,
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_accountBlocked)
            Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCC80)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFE65100), size: 20),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Your account was blocked by an administrator. You can still contact support here.',
                      style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF5D4037)),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildBody()),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 12.h),
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          border: Border(top: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.12))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: CustomButton(
          text: 'New Ticket',
          onPressed: _openCreate,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _tickets.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_error != null && _tickets.isEmpty) {
      return _buildMessageState(
        icon: Icons.error_outline,
        message: _error!,
        actionLabel: 'Retry',
        onAction: () => _load(reset: true),
      );
    }

    if (_email == null || _email!.isEmpty) {
      return _buildMessageState(
        icon: Icons.email_outlined,
        message: 'Sign in or enter your registered email to view tickets.',
        actionLabel: 'Create Ticket',
        onAction: _openCreate,
      );
    }

    if (_tickets.isEmpty) {
      return _buildMessageState(
        icon: Icons.support_agent_outlined,
        message: 'No support tickets yet.',
        actionLabel: 'Contact Support',
        onAction: _openCreate,
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
        itemCount: _tickets.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (context, index) {
          if (index >= _tickets.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
            );
          }
          final ticket = _tickets[index];
          return _buildTicketCard(ticket);
        },
      ),
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    final date = ticket.lastMessageAt ?? ticket.updatedAt ?? ticket.createdAt;
    final dateLabel = date != null ? DateFormat('MMM d, yyyy · h:mm a').format(date.toLocal()) : '';

    return Material(
      color: const Color(0xFFF8FFE9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final updated = await Get.toNamed(
            AppRoutes.supportTicketDetail,
            arguments: {'ticketId': ticket.id},
          );
          if (updated == true) await _load(reset: true);
        },
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6F0DA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.title,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.onPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: _statusColor(ticket.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(ticket.status),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: _statusColor(ticket.status),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (dateLabel.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Text(dateLabel, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: AppColors.primaryGray),
            SizedBox(height: 16.h),
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                elevation: 0,
              ),
              child: Text(actionLabel, style: AppTextStyles.buttonMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
