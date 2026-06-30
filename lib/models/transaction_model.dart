import 'package:get_right/utils/image_url_sanitizer.dart';

/// Customer payment transaction from `GET /customer/transactions`.
class TransactionModel {
  final String id;
  final String userId;
  final TransactionType type;
  final double amount;
  final String currency;
  final TransactionStatus status;
  final DateTime transactionDate;
  final DateTime? paidAt;
  final String? description;
  final String? programId;
  final String? programTitle;
  final String? productImageUrl;
  final String? productDescription;
  final double? listPrice;
  final double? discount;
  final double? netPrice;
  final String? trainerId;
  final String? trainerName;
  final String? trainerImageUrl;
  final String? paymentMethod;
  final String? transactionReference;
  final String? refundReason;
  final DateTime? refundedAt;
  final bool isBundle;
  final String? productModel;
  final String? provider;
  final String? stripePaymentIntentId;
  final String? stripeCheckoutSessionId;
  final double? applicationFee;
  final double? applicationFeePercent;
  final double? vendorPayout;
  final String? paymentStatus;
  final List<String> enrollmentIds;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.currency = 'USD',
    required this.status,
    required this.transactionDate,
    this.paidAt,
    this.description,
    this.programId,
    this.programTitle,
    this.productImageUrl,
    this.productDescription,
    this.listPrice,
    this.discount,
    this.netPrice,
    this.trainerId,
    this.trainerName,
    this.trainerImageUrl,
    this.paymentMethod,
    this.transactionReference,
    this.refundReason,
    this.refundedAt,
    this.isBundle = false,
    this.productModel,
    this.provider,
    this.stripePaymentIntentId,
    this.stripeCheckoutSessionId,
    this.applicationFee,
    this.applicationFeePercent,
    this.vendorPayout,
    this.paymentStatus,
    this.enrollmentIds = const [],
  });

  factory TransactionModel.fromApiJson(Map<String, dynamic> json) {
    final product = json['product'];
    final trainer = json['trainer'];
    final metadata = json['metadata'];

    String? productTitle;
    String? productId;
    String? productImage;
    String? productDesc;
    double? price;
    double? discount;
    double? netPrice;

    if (product is Map) {
      final pm = Map<String, dynamic>.from(product);
      productTitle = pm['title']?.toString();
      productId = pm['_id']?.toString() ?? pm['id']?.toString();
      productDesc = pm['description']?.toString();
      price = _toDouble(pm['price']);
      discount = _toDouble(pm['discount']);
      netPrice = _toDouble(pm['netPrice']);
      final promo = pm['promoMedia'];
      if (promo is Map) {
        productImage = ImageUrlSanitizer.resolveMediaUrl(Map<String, dynamic>.from(promo)['url']?.toString());
      }
    }

    String? trainerName;
    String? trainerId;
    String? trainerPhoto;
    if (trainer is Map) {
      final tm = Map<String, dynamic>.from(trainer);
      trainerId = tm['_id']?.toString();
      final profile = tm['profile'];
      if (profile is Map) {
        final pf = Map<String, dynamic>.from(profile);
        trainerName = pf['fullName']?.toString();
        final pic = pf['profilePicture'];
        if (pic is Map) {
          trainerPhoto = ImageUrlSanitizer.resolveMediaUrl(Map<String, dynamic>.from(pic)['url']?.toString());
        }
      }
    }

    final apiType = json['type']?.toString() ?? '';
    final apiStatus = json['status']?.toString() ?? '';
    final isBundle = json['isBundle'] == true;
    final paidAtRaw = json['paidAt']?.toString();
    final createdRaw = json['createdAt']?.toString();
    final paidAt = paidAtRaw != null ? DateTime.tryParse(paidAtRaw) : null;
    final createdAt = createdRaw != null ? DateTime.tryParse(createdRaw) : null;

    String? paymentStatus;
    if (metadata is Map) {
      paymentStatus = Map<String, dynamic>.from(metadata)['paymentStatus']?.toString();
    }

    final enrollmentsRaw = json['enrollments'];
    final enrollments = enrollmentsRaw is List ? enrollmentsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : <String>[];

    return TransactionModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['customer']?.toString() ?? '',
      type: TransactionType.fromApi(apiType, status: apiStatus),
      amount: _toDouble(json['amount']) ?? 0,
      currency: (json['currency']?.toString() ?? 'usd').toUpperCase(),
      status: TransactionStatus.fromApi(apiStatus),
      transactionDate: paidAt ?? createdAt ?? DateTime.now(),
      paidAt: paidAt,
      description: _typeLabel(apiType, isBundle: isBundle, productModel: json['productModel']?.toString()),
      programId: productId,
      programTitle: productTitle,
      productImageUrl: productImage,
      productDescription: productDesc,
      listPrice: price,
      discount: discount,
      netPrice: netPrice,
      trainerId: trainerId,
      trainerName: trainerName,
      trainerImageUrl: trainerPhoto,
      paymentMethod: _providerLabel(json['provider']?.toString()),
      transactionReference: json['stripePaymentIntentId']?.toString() ?? json['_id']?.toString(),
      isBundle: isBundle,
      productModel: json['productModel']?.toString(),
      provider: json['provider']?.toString(),
      stripePaymentIntentId: json['stripePaymentIntentId']?.toString(),
      stripeCheckoutSessionId: json['stripeCheckoutSessionId']?.toString(),
      applicationFee: _toDouble(json['applicationFee']),
      applicationFeePercent: _toDouble(json['applicationFeePercent']),
      vendorPayout: _toDouble(json['vendorPayout']),
      paymentStatus: paymentStatus,
      enrollmentIds: enrollments,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String _providerLabel(String? provider) {
    if (provider == null || provider.trim().isEmpty) return 'Card';
    if (provider.toLowerCase() == 'stripe') return 'Stripe';
    return provider[0].toUpperCase() + provider.substring(1);
  }

  static String _typeLabel(String apiType, {required bool isBundle, String? productModel}) {
    if (apiType.toLowerCase().contains('refund')) return 'Refund';
    if (isBundle) return 'Bundle Purchase';
    if (productModel != null && productModel.toLowerCase().contains('bundle')) return 'Bundle Purchase';
    if (apiType.toLowerCase().contains('program')) return 'Program Purchase';
    if (apiType.isNotEmpty) {
      return apiType.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    }
    return 'Purchase';
  }

  String get displayTypeLabel => description ?? (type == TransactionType.refund ? 'Refund' : 'Purchase');

  String get formattedAmount {
    final symbol = currency.toUpperCase() == 'USD' ? '\$' : '$currency ';
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel.fromApiJson(json);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'transactionDate': transactionDate.toIso8601String(),
      'description': description,
      'programId': programId,
      'programTitle': programTitle,
      'trainerId': trainerId,
      'trainerName': trainerName,
    };
  }
}

/// Transaction summary from `GET /customer/transactions/summary`.
class TransactionSummary {
  final double totalSpent;
  final int totalTransactions;
  final int successfulTransactions;
  final String currency;
  final Map<String, int> byStatus;

  const TransactionSummary({
    required this.totalSpent,
    required this.totalTransactions,
    required this.successfulTransactions,
    required this.currency,
    required this.byStatus,
  });

  factory TransactionSummary.fromApiJson(Map<String, dynamic> json) {
    final byStatusRaw = json['byStatus'];
    final byStatus = <String, int>{};
    if (byStatusRaw is Map) {
      byStatusRaw.forEach((key, value) {
        byStatus[key.toString()] = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
      });
    }

    return TransactionSummary(
      totalSpent: TransactionModel._toDouble(json['totalSpent']) ?? 0,
      totalTransactions: (json['totalTransactions'] as num?)?.toInt() ?? 0,
      successfulTransactions: (json['successfulTransactions'] as num?)?.toInt() ?? 0,
      currency: (json['currency']?.toString() ?? 'usd').toUpperCase(),
      byStatus: byStatus,
    );
  }

  String get formattedTotalSpent {
    final symbol = currency.toUpperCase() == 'USD' ? '\$' : '$currency ';
    return '$symbol${totalSpent.toStringAsFixed(2)}';
  }
}

enum TransactionType {
  purchase,
  refund;

  static TransactionType fromApi(String value, {String? status}) {
    final normalized = value.toLowerCase();
    if (normalized.contains('refund') || status?.toLowerCase() == 'refunded') return TransactionType.refund;
    return TransactionType.purchase;
  }

  static TransactionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'refund':
        return TransactionType.refund;
      default:
        return TransactionType.purchase;
    }
  }
}

enum TransactionStatus {
  pending,
  completed,
  failed,
  cancelled,
  refunded;

  static TransactionStatus fromApi(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return TransactionStatus.pending;
      case 'succeeded':
      case 'completed':
      case 'paid':
        return TransactionStatus.completed;
      case 'failed':
        return TransactionStatus.failed;
      case 'cancelled':
      case 'canceled':
        return TransactionStatus.cancelled;
      case 'refunded':
        return TransactionStatus.refunded;
      default:
        return TransactionStatus.pending;
    }
  }

  static TransactionStatus fromString(String value) => fromApi(value);

  String get displayLabel {
    switch (this) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.completed:
        return 'Succeeded';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.cancelled:
        return 'Cancelled';
      case TransactionStatus.refunded:
        return 'Refunded';
    }
  }
}
