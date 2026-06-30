import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/transaction_model.dart';
import 'package:get_right/repo/transaction_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/safe_network_image.dart';
import 'package:intl/intl.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  static const int _pageSize = 10;

  final TransactionRepository _repo = TransactionRepository();
  final List<TransactionModel> _transactions = [];

  bool _loading = true;
  bool _loadingMore = false;
  String? _loadError;
  int _page = 1;
  bool _hasMore = false;
  TransactionSummary? _summary;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _page = 1;
      _hasMore = false;
      _transactions.clear();
    });

    try {
      final results = await Future.wait([
        _repo.fetchSummary(),
        _repo.fetchTransactions(page: 1, limit: _pageSize),
      ]);
      if (!mounted) return;
      final summary = results[0] as TransactionSummary;
      final page = results[1] as TransactionsListPage;
      setState(() {
        _summary = summary;
        _transactions.addAll(page.transactions);
        _hasMore = page.hasMore;
        _page = 1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final page = await _repo.fetchTransactions(page: nextPage, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _transactions.addAll(page.transactions);
        _hasMore = page.hasMore;
        _page = nextPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _viewTransactionDetails(TransactionModel transaction) {
    Get.toNamed(AppRoutes.transactionDetail, arguments: transaction.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
       leading: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ).paddingAll(8),
        ),
        title: Text(
          'Transaction History',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentVariant));
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _loadError!,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadInitial, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return RefreshIndicator(
        color: AppColors.accentVariant,
        onRefresh: _loadInitial,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_summary != null) _buildSummaryCard(_summary!),
            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
            Icon(Icons.receipt_long, size: 80, color: AppColors.primaryGray.withOpacity(0.5)),
            const SizedBox(height: 16),
            Center(child: Text('No Transactions', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray))),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Your purchase history will appear here',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accentVariant,
      onRefresh: _loadInitial,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 120) {
            _loadMore();
          }
          return false;
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: _transactions.length + 1 + (_loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _summary != null ? Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildSummaryCard(_summary!)) : const SizedBox.shrink();
            }
            final txIndex = index - 1;
            if (txIndex >= _transactions.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: AppColors.accentVariant)),
              );
            }
            return _buildTransactionCard(_transactions[txIndex]);
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(TransactionSummary summary) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6F0DA)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _summaryStatTile(
                  label: 'Total Spent',
                  value: summary.formattedTotalSpent,
                  highlight: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryStatTile(
                  label: 'Transactions',
                  value: '${summary.totalTransactions}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryStatTile(
                  label: 'Successful',
                  value: '${summary.successfulTransactions}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryStatTile(
                  label: 'Pending',
                  value: '${summary.byStatus['pending'] ?? 0}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStatTile({required String label, required String value, bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? AppColors.accentVariant.withOpacity(0.12) : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6F0DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.titleSmall.copyWith(
              color: highlight ? AppColors.accentVariant : AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction) {
    final isRefund = transaction.type == TransactionType.refund;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6F0DA), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (transaction.productImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SafeNetworkImage(
                    url: transaction.productImageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    fallback: _productPlaceholder(),
                  ),
                )
              else
                _productPlaceholder(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.programTitle ?? transaction.displayTypeLabel,
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (transaction.trainerName != null)
                      Text('by ${transaction.trainerName}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statusPill(transaction),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: AppColors.accent.withOpacity(0.25)),
                    ),
                    child: Text(
                      transaction.displayTypeLabel,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    transaction.formattedAmount,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: isRefund ? AppColors.missed : AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Date', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(transaction.transactionDate.toLocal()),
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _viewTransactionDetails(transaction),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentVariant,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                elevation: 0,
              ),
              child: Text(
                'View Details',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productPlaceholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.receipt_long, color: AppColors.accent, size: 24),
    );
  }

  Widget _statusPill(TransactionModel transaction) {
    final color = _statusColor(transaction.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        transaction.status.displayLabel.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 10),
      ),
    );
  }

  Color _statusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return AppColors.completed;
      case TransactionStatus.pending:
        return AppColors.upcoming;
      case TransactionStatus.failed:
      case TransactionStatus.cancelled:
        return AppColors.missed;
      case TransactionStatus.refunded:
        return AppColors.accent;
    }
  }
}
