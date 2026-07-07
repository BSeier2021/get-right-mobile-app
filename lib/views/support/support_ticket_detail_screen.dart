import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/models/support_ticket.dart';
import 'package:get_right/repo/support_ticket_repo.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/no_emoji_input_formatter.dart';
import 'package:intl/intl.dart';

/// Ticket thread — detail + messages + reply.
class SupportTicketDetailScreen extends StatefulWidget {
  const SupportTicketDetailScreen({super.key});

  @override
  State<SupportTicketDetailScreen> createState() => _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends State<SupportTicketDetailScreen> {
  final SupportTicketRepository _repo = SupportTicketRepository();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  SupportTicket? _ticket;
  final List<SupportTicketMessage> _messages = [];
  String? _error;
  bool _loading = true;
  bool _sending = false;
  String? _ticketId;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    _ticketId = args is Map ? args['ticketId']?.toString() : null;
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ticketId = _ticketId;
    if (ticketId == null || ticketId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Invalid ticket';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ticket = await _repo.fetchTicketDetail(ticketId);
      final messagesPage = await _repo.fetchMessages(ticketId: ticketId, limit: 100);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _messages
          ..clear()
          ..addAll(messagesPage.messages);
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendReply() async {
    final ticket = _ticket;
    final ticketId = _ticketId;
    if (ticket == null || ticketId == null || ticket.isClosed) return;

    final body = _replyController.text.trim();
    if (body.isEmpty) {
      Get.snackbar('Support', 'Please enter a message', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _sending = true);
    try {
      await _repo.replyToTicket(ticketId: ticketId, body: body);
      _replyController.clear();
      await _load();
    } catch (e) {
      Get.snackbar('Support', e.toString().replaceFirst('Exception: ', ''), snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _sending = false);
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
    final ticket = _ticket;
    final isClosed = ticket?.isClosed ?? false;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(result: true),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ticket?.title ?? 'Support Ticket',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (ticket != null)
              Text(
                _statusLabel(ticket.status),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? _buildError()
              : Column(
                  children: [
                    if (isClosed) _buildClosedBanner(),
                    Expanded(child: _buildMessages()),
                    if (!isClosed) _buildComposer(),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.primaryGray),
            SizedBox(height: 16.h),
            Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      color: const Color(0xFFEEEEEE),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 18, color: AppColors.primaryGray),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'This ticket is closed. You cannot send new replies.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_messages.isEmpty) {
      return RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 120.h),
            Center(child: Text('No messages yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
        itemCount: _messages.length,
        itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
      ),
    );
  }

  Widget _buildMessageBubble(SupportTicketMessage message) {
    final isCustomer = message.isFromCustomer;
    final time = message.createdAt;
    final timeLabel = time != null ? DateFormat('MMM d · h:mm a').format(time.toLocal()) : '';

    return Align(
      alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        constraints: BoxConstraints(maxWidth: 0.82.sw),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isCustomer ? AppColors.accent : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isCustomer ? 16 : 4),
            bottomRight: Radius.circular(isCustomer ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCustomer ? 'You' : 'Support',
              style: AppTextStyles.labelSmall.copyWith(
                color: isCustomer ? Colors.white70 : AppColors.primaryGray,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              message.body,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isCustomer ? Colors.white : AppColors.onPrimary,
              ),
            ),
            if (timeLabel.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                timeLabel,
                style: AppTextStyles.labelSmall.copyWith(
                  color: isCustomer ? Colors.white60 : AppColors.primaryGray,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.primaryGray.withOpacity(0.15))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                maxLines: 4,
                minLines: 1,
                maxLength: 5000,
                inputFormatters: [NoEmojiInputFormatter()],
                decoration: InputDecoration(
                  hintText: 'Type your reply…',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8FFE9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            _sending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                  )
                : IconButton(
                    onPressed: _sendReply,
                    icon: const Icon(Icons.send_rounded, color: AppColors.accent),
                  ),
          ],
        ),
      ),
    );
  }
}
