import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/transaction_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:intl/intl.dart';

/// Transaction Detail Screen
class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final transaction = Get.arguments as TransactionModel?;
    if (transaction == null) {
      Get.back();
      return const SizedBox.shrink();
    }

    final isRefund = transaction.type == TransactionType.refund;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withOpacity(0.15), width: 1),
            ),
            child: const Icon(Icons.chevron_left, color: AppColors.accent, size: 20),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Transaction Details',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header card ───────────────────────────────────
            _buildHeader(transaction, isRefund),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE6F0DA), thickness: 1),
            const SizedBox(height: 16),

            // ── Transaction Information ───────────────────────
            _buildSectionTitle('Transaction Information'),
            const SizedBox(height: 12),
            _buildInfoCard(transaction, isRefund),
            const SizedBox(height: 24),

            // ── Program Information ───────────────────────────
            if (transaction.programTitle != null) ...[
              _buildSectionTitle('Transaction Information'),
              const SizedBox(height: 12),
              _buildProgramCard(transaction),
              const SizedBox(height: 24),
            ],

            // ── Refund Information ────────────────────────────
            if (isRefund && transaction.refundReason != null && transaction.refundReason!.isNotEmpty) ...[
              _buildSectionTitle('Refund Information'),
              const SizedBox(height: 12),
              _buildRefundCard(transaction),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────
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
          // Green circle chevron
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withOpacity(0.25), width: 1),
            ),
            child: const Icon(Icons.chevron_left, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 14),
          // Text column
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isRefund ? 'Refund' : 'Purchase',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${transaction.amount.toStringAsFixed(2)}',
                style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                ),
                child: Text(
                  transaction.status.toString().toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(color: statusColor, fontWeight: FontWeight.w600, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section title ──────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
    );
  }

  // ── Info card with rows ────────────────────────────────────
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
          _buildInfoRow('Transaction ID', transaction.transactionReference ?? transaction.id),
          _divider(),
          _buildInfoRow('Type', isRefund ? 'Refund' : 'Purchase'),
          _divider(),
          _buildInfoRow('Amount', '\$${transaction.amount.toStringAsFixed(2)}'),
          _divider(),
          _buildInfoRow('Date', DateFormat('MMM dd, yyyy').format(transaction.transactionDate)),
          _divider(),
          _buildInfoRow('Time', DateFormat('hh:mm a').format(transaction.transactionDate)),
          if (transaction.paymentMethod != null) ...[_divider(), _buildInfoRow('Payment Method', transaction.paymentMethod!)],
          _divider(),
          _buildInfoRow('Status', transaction.status.toString().toUpperCase()),
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
      children: [
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.black, fontSize: 14)),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // ── Program card (left accent border) ──────────────────────
  Widget _buildProgramCard(TransactionModel transaction) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6F0DA), width: 1),
      ),
      child: Row(
        children: [
          // Left green accent stripe
          Container(
            width: 4,
            height: 60,
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
                    transaction.programTitle ?? 'Program',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (transaction.trainerName != null) ...[
                    const SizedBox(height: 4),
                    Text('by ${transaction.trainerName}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Refund card (left accent border) ───────────────────────
  Widget _buildRefundCard(TransactionModel transaction) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6F0DA), width: 1),
      ),
      child: Row(
        children: [
          // Left green accent stripe
          Container(
            width: 4,
            height: 60,
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
                    'Refund Reason',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(transaction.refundReason ?? 'No reason provided', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
    }
  }
}
