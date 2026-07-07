import 'package:get_right/app_url.dart';
import 'package:get_right/models/support_ticket.dart';
import 'package:get_right/network/network_services.dart';

class SupportTicketRepository {
  final _network = NetworkApiService();

  static Map<String, String> get _authHeaders => {
        'skipAuth': 'true',
        'Authorization': NetworkApiService.guestAuthToken,
      };

  /// `POST /user/support-tickets`
  Future<String> createTicket({
    required String email,
    required String title,
    required String body,
  }) async {
    final raw = await _network.post(
      AppUrl.userSupportTickets,
      {
        'email': email.trim(),
        'title': title.trim(),
        'body': body.trim(),
      },
      headers: _authHeaders,
    );
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not create support ticket');
    }
    final data = _dataMap(raw);
    final ticketId = data['ticketId']?.toString().trim();
    if (ticketId == null || ticketId.isEmpty) {
      throw Exception('Ticket created but no ticket id returned');
    }
    return ticketId;
  }

  /// `GET /user/support-tickets`
  Future<SupportTicketsPage> fetchTickets({
    required String email,
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    final raw = await _network.get(
      AppUrl.userSupportTicketsList(email: email, page: page, limit: limit, status: status),
      headers: _authHeaders,
    );
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load support tickets');
    }
    return SupportTicketsPage.fromApiResponse(raw);
  }

  /// `GET /user/support-tickets/{ticketId}`
  Future<SupportTicket> fetchTicketDetail(String ticketId) async {
    final raw = await _network.get(
      AppUrl.userSupportTicketById(ticketId),
      headers: _authHeaders,
    );
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load ticket');
    }
    final data = _dataMap(raw);
    final ticketNode = data['ticket'];
    if (ticketNode is Map) {
      return SupportTicket.fromJson(Map<String, dynamic>.from(ticketNode));
    }
    throw Exception('Ticket not found');
  }

  /// `GET /user/support-tickets/{ticketId}/messages`
  Future<SupportMessagesPage> fetchMessages({
    required String ticketId,
    int page = 1,
    int limit = 50,
  }) async {
    final raw = await _network.get(
      AppUrl.userSupportTicketMessages(ticketId, page: page, limit: limit),
      headers: _authHeaders,
    );
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load messages');
    }
    return SupportMessagesPage.fromApiResponse(raw);
  }

  /// `POST /user/support-tickets/{ticketId}/messages`
  Future<void> replyToTicket({
    required String ticketId,
    required String body,
  }) async {
    final raw = await _network.post(
      AppUrl.userSupportTicketReply(ticketId),
      {'body': body.trim()},
      headers: _authHeaders,
    );
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not send reply');
    }
  }

  static bool _isOk(dynamic response) {
    if (response is! Map) return false;
    final m = Map<String, dynamic>.from(response);
    if (m['success'] == true || m['success'] == 1) return true;
    final st = m['status'];
    return st == 200 || st == '200' || st == 201 || st == '201';
  }

  static String? _messageFrom(dynamic response) {
    if (response is! Map) return null;
    final message = Map<String, dynamic>.from(response)['message'];
    if (message is String && message.trim().isNotEmpty) return message;
    return null;
  }

  static Map<String, dynamic> _dataMap(dynamic response) {
    if (response is! Map) return {};
    final root = Map<String, dynamic>.from(response);
    final data = root['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return root;
  }
}
