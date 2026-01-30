import 'package:cloud_firestore/cloud_firestore.dart';

/// Support ticket categories
enum TicketCategory {
  /// Account-related issues (login, password, etc.)
  accountIssue,

  /// Payment problems (failed payments, refunds)
  paymentProblem,

  /// Technical bugs or errors
  technicalBug,

  /// Suggestions for new features
  featureRequest,

  /// Help with bookings
  bookingHelp,

  /// Help with verification process
  verificationHelp,

  /// General questions
  general,
}

/// Ticket priority levels
enum TicketPriority {
  low,
  medium,
  high,
  urgent,
}

/// Ticket status
enum TicketStatus {
  /// Newly created, not yet assigned
  open,

  /// Assigned to an admin
  assigned,

  /// Waiting for user response
  awaitingUserResponse,

  /// Being worked on
  inProgress,

  /// Resolved and closed
  resolved,

  /// Closed without resolution
  closed,
}

/// Model for support tickets
class SupportTicket {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String userRole; // 'client' or 'supplier'

  // Classification
  final TicketCategory category;
  final TicketPriority priority;

  // Content
  final String subject;
  final String description;
  final List<String> attachmentUrls;

  // Assignment
  final String? assignedAdminId;
  final String? assignedAdminName;
  final TicketStatus status;

  // Related entities
  final String? bookingId;
  final String? supplierId;
  final String? disputeId;

  // Timestamps
  final DateTime createdAt;
  final DateTime? firstResponseAt;
  final DateTime? resolvedAt;
  final DateTime? lastUpdatedAt;

  // Tags
  final List<String> tags;

  const SupportTicket({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.userRole,
    required this.category,
    this.priority = TicketPriority.medium,
    required this.subject,
    required this.description,
    this.attachmentUrls = const [],
    this.assignedAdminId,
    this.assignedAdminName,
    this.status = TicketStatus.open,
    this.bookingId,
    this.supplierId,
    this.disputeId,
    required this.createdAt,
    this.firstResponseAt,
    this.resolvedAt,
    this.lastUpdatedAt,
    this.tags = const [],
  });

  /// Get category display name
  String get categoryName {
    switch (category) {
      case TicketCategory.accountIssue:
        return 'Problema com Conta';
      case TicketCategory.paymentProblem:
        return 'Problema com Pagamento';
      case TicketCategory.technicalBug:
        return 'Bug Técnico';
      case TicketCategory.featureRequest:
        return 'Sugestão de Funcionalidade';
      case TicketCategory.bookingHelp:
        return 'Ajuda com Reserva';
      case TicketCategory.verificationHelp:
        return 'Ajuda com Verificação';
      case TicketCategory.general:
        return 'Pergunta Geral';
    }
  }

  /// Get priority display name
  String get priorityName {
    switch (priority) {
      case TicketPriority.low:
        return 'Baixa';
      case TicketPriority.medium:
        return 'Média';
      case TicketPriority.high:
        return 'Alta';
      case TicketPriority.urgent:
        return 'Urgente';
    }
  }

  /// Get status display name
  String get statusName {
    switch (status) {
      case TicketStatus.open:
        return 'Aberto';
      case TicketStatus.assigned:
        return 'Atribuído';
      case TicketStatus.awaitingUserResponse:
        return 'Aguardando Resposta';
      case TicketStatus.inProgress:
        return 'Em Andamento';
      case TicketStatus.resolved:
        return 'Resolvido';
      case TicketStatus.closed:
        return 'Fechado';
    }
  }

  /// Check if ticket is closed
  bool get isClosed =>
      status == TicketStatus.resolved || status == TicketStatus.closed;

  /// Calculate response time in hours
  double? get responseTimeHours {
    if (firstResponseAt == null) return null;
    return firstResponseAt!.difference(createdAt).inMinutes / 60;
  }

  /// Calculate resolution time in hours
  double? get resolutionTimeHours {
    if (resolvedAt == null) return null;
    return resolvedAt!.difference(createdAt).inMinutes / 60;
  }

  factory SupportTicket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SupportTicket.fromMap(data, doc.id);
  }

  factory SupportTicket.fromMap(Map<String, dynamic> data, String id) {
    return SupportTicket(
      id: id,
      userId: data['userId'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      userRole: data['userRole'] as String? ?? 'client',
      category: TicketCategory.values.firstWhere(
        (e) => e.name == (data['category'] as String? ?? 'general'),
        orElse: () => TicketCategory.general,
      ),
      priority: TicketPriority.values.firstWhere(
        (e) => e.name == (data['priority'] as String? ?? 'medium'),
        orElse: () => TicketPriority.medium,
      ),
      subject: data['subject'] as String? ?? '',
      description: data['description'] as String? ?? '',
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      assignedAdminId: data['assignedAdminId'] as String?,
      assignedAdminName: data['assignedAdminName'] as String?,
      status: TicketStatus.values.firstWhere(
        (e) => e.name == (data['status'] as String? ?? 'open'),
        orElse: () => TicketStatus.open,
      ),
      bookingId: data['bookingId'] as String?,
      supplierId: data['supplierId'] as String?,
      disputeId: data['disputeId'] as String?,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      firstResponseAt: _parseTimestamp(data['firstResponseAt']),
      resolvedAt: _parseTimestamp(data['resolvedAt']),
      lastUpdatedAt: _parseTimestamp(data['lastUpdatedAt']),
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'userRole': userRole,
      'category': category.name,
      'priority': priority.name,
      'subject': subject,
      'description': description,
      'attachmentUrls': attachmentUrls,
      'assignedAdminId': assignedAdminId,
      'assignedAdminName': assignedAdminName,
      'status': status.name,
      'bookingId': bookingId,
      'supplierId': supplierId,
      'disputeId': disputeId,
      'createdAt': Timestamp.fromDate(createdAt),
      'firstResponseAt':
          firstResponseAt != null ? Timestamp.fromDate(firstResponseAt!) : null,
      'resolvedAt':
          resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'lastUpdatedAt':
          lastUpdatedAt != null ? Timestamp.fromDate(lastUpdatedAt!) : null,
      'tags': tags,
    };
  }

  SupportTicket copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? userName,
    String? userRole,
    TicketCategory? category,
    TicketPriority? priority,
    String? subject,
    String? description,
    List<String>? attachmentUrls,
    String? assignedAdminId,
    String? assignedAdminName,
    TicketStatus? status,
    String? bookingId,
    String? supplierId,
    String? disputeId,
    DateTime? createdAt,
    DateTime? firstResponseAt,
    DateTime? resolvedAt,
    DateTime? lastUpdatedAt,
    List<String>? tags,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      assignedAdminId: assignedAdminId ?? this.assignedAdminId,
      assignedAdminName: assignedAdminName ?? this.assignedAdminName,
      status: status ?? this.status,
      bookingId: bookingId ?? this.bookingId,
      supplierId: supplierId ?? this.supplierId,
      disputeId: disputeId ?? this.disputeId,
      createdAt: createdAt ?? this.createdAt,
      firstResponseAt: firstResponseAt ?? this.firstResponseAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      tags: tags ?? this.tags,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Model for ticket messages/replies
class TicketMessage {
  final String id;
  final String ticketId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'user', 'admin'
  final String content;
  final List<String> attachmentUrls;
  final bool isInternal; // Admin-only notes
  final DateTime createdAt;

  const TicketMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    this.attachmentUrls = const [],
    this.isInternal = false,
    required this.createdAt,
  });

  factory TicketMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TicketMessage.fromMap(data, doc.id);
  }

  factory TicketMessage.fromMap(Map<String, dynamic> data, String id) {
    return TicketMessage(
      id: id,
      ticketId: data['ticketId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      senderRole: data['senderRole'] as String? ?? 'user',
      content: data['content'] as String? ?? '',
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      isInternal: data['isInternal'] as bool? ?? false,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ticketId': ticketId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'content': content,
      'attachmentUrls': attachmentUrls,
      'isInternal': isInternal,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Canned response templates for admin
class CannedResponse {
  final String id;
  final String title;
  final String content;
  final TicketCategory? category;
  final List<String> tags;
  final int usageCount;

  const CannedResponse({
    required this.id,
    required this.title,
    required this.content,
    this.category,
    this.tags = const [],
    this.usageCount = 0,
  });

  factory CannedResponse.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CannedResponse(
      id: doc.id,
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      category: data['category'] != null
          ? TicketCategory.values.firstWhere(
              (e) => e.name == data['category'],
              orElse: () => TicketCategory.general,
            )
          : null,
      tags: List<String>.from(data['tags'] ?? []),
      usageCount: (data['usageCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'category': category?.name,
      'tags': tags,
      'usageCount': usageCount,
    };
  }
}

/// Default canned responses
class DefaultCannedResponses {
  static const List<CannedResponse> responses = [
    CannedResponse(
      id: 'welcome',
      title: 'Boas-vindas',
      content:
          'Olá! Obrigado por entrar em contato com o suporte da Boda Connect. '
          'Estamos aqui para ajudá-lo. Por favor, forneça mais detalhes sobre sua solicitação.',
    ),
    CannedResponse(
      id: 'verification_pending',
      title: 'Verificação em Andamento',
      content:
          'Seu pedido de verificação está sendo analisado por nossa equipe. '
          'O processo geralmente leva de 1 a 3 dias úteis. Você receberá uma notificação assim que for concluído.',
      category: TicketCategory.verificationHelp,
    ),
    CannedResponse(
      id: 'payment_processing',
      title: 'Pagamento em Processamento',
      content:
          'Entendemos sua preocupação com o pagamento. Por favor, aguarde até 24 horas para o processamento completo. '
          'Se o problema persistir, envie o comprovante de pagamento para análise.',
      category: TicketCategory.paymentProblem,
    ),
    CannedResponse(
      id: 'bug_received',
      title: 'Bug Reportado',
      content:
          'Obrigado por reportar este problema. Nossa equipe técnica foi notificada e está investigando. '
          'Atualizaremos você assim que tivermos mais informações.',
      category: TicketCategory.technicalBug,
    ),
    CannedResponse(
      id: 'resolved',
      title: 'Ticket Resolvido',
      content:
          'Seu ticket foi resolvido. Se você tiver mais dúvidas ou precisar de assistência adicional, '
          'sinta-se à vontade para abrir um novo ticket. Agradecemos sua paciência!',
    ),
  ];
}
