import 'package:get_right/app_url.dart';
import 'package:get_right/models/transaction_model.dart';
import 'package:get_right/network/network_services.dart';

class TransactionsListPage {
  const TransactionsListPage({
    required this.transactions,
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
    this.summary,
  });

  final List<TransactionModel> transactions;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;
  final TransactionSummary? summary;
}

class TransactionRepository {
  final _network = NetworkApiService();

  /// `GET /customer/transactions` — paginated list with optional embedded summary.
  Future<TransactionsListPage> fetchTransactions({int page = 1, int limit = 10}) async {
    final raw = await _network.get(AppUrl.customerTransactionsList(page: page, limit: limit));
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load transactions');
    }
    return _parseListPage(raw, page: page, limit: limit);
  }

  /// `GET /customer/transactions/summary`
  Future<TransactionSummary> fetchSummary() async {
    final raw = await _network.get(AppUrl.customerTransactionsSummary);
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load transaction summary');
    }

    if (raw is Map) {
      final data = Map<String, dynamic>.from(raw)['data'];
      if (data is Map) {
        final dm = Map<String, dynamic>.from(data);
        final summary = dm['summary'];
        if (summary is Map) {
          return TransactionSummary.fromApiJson(Map<String, dynamic>.from(summary));
        }
      }
    }
    throw Exception('Invalid transaction summary response');
  }

  /// `GET /customer/transactions/:transactionId`
  Future<TransactionModel> fetchTransactionDetail(String transactionId) async {
    final id = transactionId.trim();
    if (id.isEmpty) throw Exception('Invalid transaction id');

    final raw = await _network.get(AppUrl.customerTransactionById(id));
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load transaction');
    }

    final transaction = _transactionFromDetailResponse(raw);
    if (transaction == null || transaction.id.isEmpty) {
      throw Exception('Transaction not found');
    }
    return transaction;
  }

  static TransactionsListPage _parseListPage(dynamic response, {required int page, required int limit}) {
    final transactions = <TransactionModel>[];
    var total = 0;
    var hasMore = false;
    TransactionSummary? summary;

    if (response is Map) {
      final root = Map<String, dynamic>.from(response);
      final data = root['data'];
      if (data is Map) {
        final dm = Map<String, dynamic>.from(data);
        total = (dm['totalDocs'] as num?)?.toInt() ?? 0;
        hasMore = dm['hasNextPage'] == true;

        final summaryRaw = dm['summary'];
        if (summaryRaw is Map) {
          summary = TransactionSummary.fromApiJson(Map<String, dynamic>.from(summaryRaw));
        }

        final items = dm['transactions'];
        if (items is List) {
          for (final item in items) {
            if (item is Map) {
              transactions.add(TransactionModel.fromApiJson(Map<String, dynamic>.from(item)));
            }
          }
        }

        if (total == 0) total = transactions.length;
        if (!hasMore && transactions.length == limit) {
          hasMore = page * limit < total;
        }
      }
    }

    return TransactionsListPage(
      transactions: transactions,
      page: page,
      limit: limit,
      total: total,
      hasMore: hasMore,
      summary: summary,
    );
  }

  static TransactionModel? _transactionFromDetailResponse(dynamic response) {
    if (response is! Map) return null;
    final root = Map<String, dynamic>.from(response);
    final data = root['data'];
    if (data is Map) {
      final dm = Map<String, dynamic>.from(data);
      final item = dm['transaction'] ?? dm['data'] ?? dm;
      if (item is Map) return TransactionModel.fromApiJson(Map<String, dynamic>.from(item));
    }
    if (root.containsKey('_id') || root.containsKey('amount')) {
      return TransactionModel.fromApiJson(root);
    }
    return null;
  }

  static bool _isOk(dynamic response) {
    if (response is! Map) return false;
    final m = Map<String, dynamic>.from(response);
    if (m['success'] == true || m['success'] == 1) return true;
    final st = m['status'];
    return st == 200 || st == '200';
  }

  static String? _messageFrom(dynamic response) {
    if (response is! Map) return null;
    return Map<String, dynamic>.from(response)['message']?.toString();
  }
}
