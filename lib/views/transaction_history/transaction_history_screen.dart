import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/transaction_model.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:intl/intl.dart';

/// Transaction History Screen
class TransactionHistoryScreen extends StatelessWidget {
  TransactionHistoryScreen({super.key});

  // Mock transaction data
  final List<TransactionModel> _transactions = [
    TransactionModel(
      id: 'txn_1',
      userId: 'user_1',
      type: TransactionType.purchase,
      amount: 49.99,
      status: TransactionStatus.completed,
      transactionDate: DateTime(2026, 1, 15),
      description: 'Program Purchase',
      programId: 'prog_1',
      programTitle: 'Complete Strength Program',
      trainerId: 'trainer_1',
      trainerName: 'Sarah Johnson',
      paymentMethod: 'Credit Card',
      transactionReference: 'TXN-2026-001',
    ),
    TransactionModel(
      id: 'txn_2',
      userId: 'user_1',
      type: TransactionType.refund,
      amount: 59.99,
      status: TransactionStatus.completed,
      transactionDate: DateTime(2026, 1, 20),
      description: 'Program Refund',
      programId: 'prog_4',
      programTitle: 'Marathon Prep',
      trainerId: 'trainer_4',
      trainerName: 'Lisa Thompson',
      paymentMethod: 'Credit Card',
      transactionReference: 'TXN-2026-002',
      refundReason: 'Program cancelled by user',
      refundedAt: DateTime(2026, 1, 20),
    ),
    TransactionModel(
      id: 'txn_3',
      userId: 'user_1',
      type: TransactionType.purchase,
      amount: 29.99,
      status: TransactionStatus.completed,
      transactionDate: DateTime(2026, 2, 1),
      description: 'Program Purchase',
      programId: 'prog_2',
      programTitle: 'Cardio Blast Challenge',
      trainerId: 'trainer_2',
      trainerName: 'Mike Chen',
      paymentMethod: 'Credit Card',
      transactionReference: 'TXN-2026-003',
    ),
    TransactionModel(
      id: 'txn_4',
      userId: 'user_1',
      type: TransactionType.refund,
      amount: 39.99,
      status: TransactionStatus.completed,
      transactionDate: DateTime(2026, 2, 10),
      description: 'Program Refund',
      programId: 'prog_3',
      programTitle: 'Yoga For Athletes',
      trainerId: 'trainer_3',
      trainerName: 'Emma Davis',
      paymentMethod: 'Credit Card',
      transactionReference: 'TXN-2026-004',
      refundReason: 'Schedule conflict - program cancelled',
      refundedAt: DateTime(2026, 2, 10),
    ),
  ];

  void _viewTransactionDetails(TransactionModel transaction) {
    Get.toNamed(AppRoutes.transactionDetail, arguments: transaction);
  }

  @override
  Widget build(BuildContext context) {
    // Filter to show only refunded transactions
    final refundedTransactions = _transactions.where((t) => t.type == TransactionType.refund).toList();
    // Sort by date (newest first)
    refundedTransactions.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

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
          'Transaction History',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: refundedTransactions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: AppColors.primaryGray.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('No Transactions', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
                  const SizedBox(height: 8),
                  Text("You don't have any refunded transactions", style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                ],
              ),
            )
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: refundedTransactions.length,
              itemBuilder: (context, index) {
                final transaction = refundedTransactions[index];
                return _buildTransactionCard(transaction);
              },
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
          // ── Title row + Refund pill ─────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.programTitle ?? transaction.description ?? 'Transaction',
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (transaction.trainerName != null) Text('by ${transaction.trainerName}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: AppColors.accent.withOpacity(0.25), width: 1),
                ),
                child: Text(
                  isRefund ? 'Refund' : 'Purchase',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Amount + Date row ───────────────────────────────
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
                    '\$${transaction.amount.toStringAsFixed(2)}',
                    style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 26),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Date', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(transaction.transactionDate),
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── View Details button ─────────────────────────────
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
}
