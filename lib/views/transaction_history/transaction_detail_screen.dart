import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/transaction_model.dart';
import 'package:get_right/repo/transaction_repo.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/safe_network_image.dart';
import 'package:intl/intl.dart';

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({super.key});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final TransactionRepository _repo = TransactionRepository();

  TransactionModel? _transaction;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  String? _resolveTransactionId() {
    final args = Get.arguments;
    if (args is TransactionModel && args.id.isNotEmpty) return args.id;
    if (args is String && args.trim().isNotEmpty) return args.trim();
    if (args is Map) {
      final map = Map<String, dynamic>.from(args);
      final id = map['id'] ?? map['_id'] ?? map['transactionId'];
      if (id != null && id.toString().trim().isNotEmpty) return id.toString().trim();
    }
    return null;
  }

  Future<void> _loadDetail() async {
    final id = _resolveTransactionId();
    if (id == null) {
      setState(() {
        _loading = false;
        _loadError = 'Transaction not found';
      });
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final transaction = await _repo.fetchTransactionDetail(id);
      if (!mounted) return;
      setState(() {
        _transaction = transaction;
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
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ).paddingAll(8),
        ),
        title: Text(
          'Transaction Details',
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

    if (_loadError != null || _transaction == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _loadError ?? 'Transaction not found',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadDetail, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final transaction = _transaction!;
    final isRefund = transaction.type == TransactionType.refund;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(transaction, isRefund),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE6F0DA), thickness: 1),
          const SizedBox(height: 16),
          _buildSectionTitle('Transaction Information'),
          const SizedBox(height: 12),
          _buildInfoCard(transaction, isRefund),
          const SizedBox(height: 24),
          if (transaction.programTitle != null) ...[
            _buildSectionTitle('Product Information'),
            const SizedBox(height: 12),
            _buildProductCard(transaction),
            const SizedBox(height: 24),
          ],
          if (transaction.applicationFee != null || transaction.vendorPayout != null) ...[
            _buildSectionTitle('Payment Breakdown'),
            const SizedBox(height: 12),
            _buildBreakdownCard(transaction),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(TransactionModel transaction, bool isRefund) {
    final statusColor = _getStatusColor(transaction.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6F0DA), width: 1),
      ),
      child: Row(
        children: [
          if (transaction.productImageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SafeNetworkImage(
                url: transaction.productImageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                fallback: _headerIcon(isRefund),
              ),
            )
          else
            _headerIcon(isRefund),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.displayTypeLabel,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.formattedAmount,
                  style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Text(
                    transaction.status.displayLabel.toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(color: statusColor, fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIcon(bool isRefund) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25), width: 1),
      ),
      child: Icon(isRefund ? Icons.replay_rounded : Icons.shopping_bag_outlined, color: AppColors.accent, size: 26),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildInfoCard(TransactionModel transaction, bool isRefund) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6F0DA), width: 1),
      ),
      child: Column(
        children: [
          _buildInfoRow('Transaction ID', _shortId(transaction.id)),
          _divider(),
          _buildInfoRow('Type', transaction.displayTypeLabel),
          _divider(),
          _buildInfoRow('Amount', transaction.formattedAmount),
          if (transaction.netPrice != null && transaction.netPrice != transaction.amount) ...[
            _divider(),
            _buildInfoRow('Net Price', _formatMoney(transaction.netPrice!, transaction.currency)),
          ],
          _divider(),
          _buildInfoRow('Date', DateFormat('MMM dd, yyyy').format(transaction.transactionDate.toLocal())),
          _divider(),
          _buildInfoRow('Time', DateFormat('hh:mm a').format(transaction.transactionDate.toLocal())),
          if (transaction.paymentMethod != null) ...[
            _divider(),
            _buildInfoRow('Payment Method', transaction.paymentMethod!),
          ],
          if (transaction.paymentStatus != null) ...[
            _divider(),
            _buildInfoRow('Payment Status', transaction.paymentStatus!.toUpperCase()),
          ],
          _divider(),
          _buildInfoRow('Status', transaction.status.displayLabel),
          if (transaction.stripePaymentIntentId != null) ...[
            _divider(),
            _buildInfoRow('Payment Intent', _shortId(transaction.stripePaymentIntentId!)),
          ],
        ],
      ),
    );
  }

  Widget _buildProductCard(TransactionModel transaction) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6F0DA), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.programTitle ?? 'Product',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (transaction.trainerName != null) ...[
                    const SizedBox(height: 4),
                    Text('by ${transaction.trainerName}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  ],
                  if (transaction.isBundle || transaction.productModel != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      transaction.isBundle ? 'Bundle' : transaction.productModel ?? '',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.accentVariant, fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (transaction.productDescription != null && transaction.productDescription!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      transaction.productDescription!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(TransactionModel transaction) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6F0DA), width: 1),
      ),
      child: Column(
        children: [
          if (transaction.listPrice != null) ...[
            _buildInfoRow('List Price', _formatMoney(transaction.listPrice!, transaction.currency)),
            _divider(),
          ],
          if (transaction.discount != null && transaction.discount! > 0) ...[
            _buildInfoRow('Discount', _formatMoney(transaction.discount!, transaction.currency)),
            _divider(),
          ],
          if (transaction.applicationFee != null) ...[
            _buildInfoRow(
              'Application Fee${transaction.applicationFeePercent != null ? ' (${transaction.applicationFeePercent!.toStringAsFixed(0)}%)' : ''}',
              _formatMoney(transaction.applicationFee!, transaction.currency),
            ),
            _divider(),
          ],
          if (transaction.vendorPayout != null)
            _buildInfoRow('Trainer Payout', _formatMoney(transaction.vendorPayout!, transaction.currency)),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(color: Color(0xFFE6F0DA), height: 24, thickness: 1);
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.black, fontSize: 14)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _shortId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 6)}…${id.substring(id.length - 4)}';
  }

  String _formatMoney(double amount, String currency) {
    final symbol = currency.toUpperCase() == 'USD' ? '\$' : '$currency ';
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  Color _getStatusColor(TransactionStatus status) {
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
