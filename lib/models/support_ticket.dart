class SupportTicket {
  final String id;
  final String email;
  final String title;
  final String status;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SupportTicket({
    required this.id,
    required this.email,
    required this.title,
    required this.status,
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isClosed => status.toLowerCase() == 'closed';

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['_id']?.toString() ?? json['ticketId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Open',
      lastMessageAt: _parseDate(json['lastMessageAt']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class SupportTicketMessage {
  final String id;
  final String ticketId;
  final String body;
  final String senderRole;
  final DateTime? createdAt;

  const SupportTicketMessage({
    required this.id,
    required this.ticketId,
    required this.body,
    required this.senderRole,
    this.createdAt,
  });

  bool get isFromCustomer => senderRole.toLowerCase() == 'customer';

  factory SupportTicketMessage.fromJson(Map<String, dynamic> json) {
    return SupportTicketMessage(
      id: json['_id']?.toString() ?? json['messageId']?.toString() ?? '',
      ticketId: json['ticket']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      senderRole: json['senderRole']?.toString() ?? 'Customer',
      createdAt: SupportTicket._parseDate(json['createdAt']),
    );
  }
}

class SupportTicketsPage {
  final List<SupportTicket> tickets;
  final int totalDocs;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  const SupportTicketsPage({
    required this.tickets,
    required this.totalDocs,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory SupportTicketsPage.fromApiResponse(dynamic raw) {
    final root = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final data = root['data'] is Map ? Map<String, dynamic>.from(root['data'] as Map) : root;
    final list = data['supportTickets'];
    final tickets = <SupportTicket>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          tickets.add(SupportTicket.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return SupportTicketsPage(
      tickets: tickets,
      totalDocs: (data['totalDocs'] as num?)?.toInt() ?? tickets.length,
      currentPage: (data['currentPage'] as num?)?.toInt() ?? 1,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
      hasNextPage: data['hasNextPage'] == true,
      hasPrevPage: data['hasPrevPage'] == true,
    );
  }
}

class SupportMessagesPage {
  final List<SupportTicketMessage> messages;
  final int totalDocs;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  const SupportMessagesPage({
    required this.messages,
    required this.totalDocs,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory SupportMessagesPage.fromApiResponse(dynamic raw) {
    final root = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final data = root['data'] is Map ? Map<String, dynamic>.from(root['data'] as Map) : root;
    final list = data['messages'];
    final messages = <SupportTicketMessage>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          messages.add(SupportTicketMessage.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return SupportMessagesPage(
      messages: messages,
      totalDocs: (data['totalDocs'] as num?)?.toInt() ?? messages.length,
      currentPage: (data['currentPage'] as num?)?.toInt() ?? 1,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
      hasNextPage: data['hasNextPage'] == true,
      hasPrevPage: data['hasPrevPage'] == true,
    );
  }
}
