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
    final color = isRefund ? AppColors.completed : AppColors.accent;

    return Scaffold(
      appBar: AppBar(title: Text('Transaction Details', style: AppTextStyles.titleLarge.copyWith()), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction Header
            _buildTransactionHeader(transaction, color, isRefund),
            const SizedBox(height: 24),

            // Transaction Info
            _buildSectionTitle('Transaction Information'),
            const SizedBox(height: 12),
            _buildInfoCard(transaction, isRefund),
            const SizedBox(height: 24),

            // Program Info (if applicable)
            if (transaction.programTitle != null) ...[
              _buildSectionTitle('Program Information'),
              const SizedBox(height: 12),
              _buildProgramInfoCard(transaction),
              const SizedBox(height: 24),
            ],

            // Refund Info (if applicable and has reason)
            if (isRefund && transaction.refundReason != null && transaction.refundReason!.isNotEmpty) ...[
              _buildSectionTitle('Refund Information'),
              const SizedBox(height: 12),
              _buildRefundInfoCard(transaction),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionHeader(TransactionModel transaction, Color color, bool isRefund) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(isRefund ? Icons.arrow_back : Icons.arrow_forward, color: color, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            isRefund ? 'Refund' : 'Purchase',
            style: AppTextStyles.headlineSmall.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${transaction.amount.toStringAsFixed(2)}',
            style: AppTextStyles.headlineMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _getStatusColor(transaction.status).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(
              transaction.status.toString().toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(color: _getStatusColor(transaction.status), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _buildInfoRow('Transaction ID', transaction.transactionReference ?? transaction.id),
          const Divider(color: AppColors.primaryGray, height: 24),
          _buildInfoRow('Type', isRefund ? 'Refund' : 'Purchase'),
          const Divider(color: AppColors.primaryGray, height: 24),
          _buildInfoRow('Amount', '\$${transaction.amount.toStringAsFixed(2)}'),
          const Divider(color: AppColors.primaryGray, height: 24),
          _buildInfoRow('Date', DateFormat('MMM dd, yyyy').format(transaction.transactionDate)),
          const Divider(color: AppColors.primaryGray, height: 24),
          _buildInfoRow('Time', DateFormat('hh:mm a').format(transaction.transactionDate)),
          if (transaction.paymentMethod != null) ...[const Divider(color: AppColors.primaryGray, height: 24), _buildInfoRow('Payment Method', transaction.paymentMethod!)],
          const Divider(color: AppColors.primaryGray, height: 24),
          _buildInfoRow('Status', transaction.status.toString().toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildProgramInfoCard(TransactionModel transaction) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            transaction.programTitle ?? 'Program',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
          ),
          if (transaction.trainerName != null) ...[
            const SizedBox(height: 8),
            Text('by ${transaction.trainerName}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
          ],
        ],
      ),
    );
  }

  Widget _buildRefundInfoCard(TransactionModel transaction) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.completed.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.completed, size: 20),
              const SizedBox(width: 8),
              Text(
                'Refund Reason',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(transaction.refundReason ?? 'No reason provided', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
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
