import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/support_ticket_model.dart';

/// Service for managing support tickets
class SupportTicketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _ticketsRef => _firestore.collection('support_tickets');
  CollectionReference get _cannedResponsesRef =>
      _firestore.collection('canned_responses');

  // ==================== USER FUNCTIONS ====================

  /// Create a new support ticket
  Future<SupportTicket?> createTicket({
    required String userId,
    required String userEmail,
    required String userName,
    required String userRole,
    required TicketCategory category,
    required String subject,
    required String description,
    List<String> attachmentUrls = const [],
    String? bookingId,
    String? supplierId,
    TicketPriority priority = TicketPriority.medium,
  }) async {
    try {
      final now = DateTime.now();

      final ticketData = {
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'userRole': userRole,
        'category': category.name,
        'priority': priority.name,
        'subject': subject,
        'description': description,
        'attachmentUrls': attachmentUrls,
        'status': TicketStatus.open.name,
        'bookingId': bookingId,
        'supplierId': supplierId,
        'createdAt': Timestamp.fromDate(now),
        'lastUpdatedAt': Timestamp.fromDate(now),
        'tags': [],
      };

      final docRef = await _ticketsRef.add(ticketData);

      debugPrint('Support ticket created: ${docRef.id}');

      return SupportTicket(
        id: docRef.id,
        userId: userId,
        userEmail: userEmail,
        userName: userName,
        userRole: userRole,
        category: category,
        priority: priority,
        subject: subject,
        description: description,
        attachmentUrls: attachmentUrls,
        status: TicketStatus.open,
        bookingId: bookingId,
        supplierId: supplierId,
        createdAt: now,
        lastUpdatedAt: now,
      );
    } catch (e) {
      debugPrint('Error creating support ticket: $e');
      return null;
    }
  }

  /// Get user's tickets
  Future<List<SupportTicket>> getUserTickets(String userId) async {
    try {
      final snapshot = await _ticketsRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SupportTicket.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting user tickets: $e');
      return [];
    }
  }

  /// Stream user's tickets
  Stream<List<SupportTicket>> streamUserTickets(String userId) {
    return _ticketsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SupportTicket.fromFirestore(doc))
            .toList());
  }

  /// Get a single ticket
  Future<SupportTicket?> getTicket(String ticketId) async {
    try {
      final doc = await _ticketsRef.doc(ticketId).get();
      if (!doc.exists) return null;
      return SupportTicket.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting ticket: $e');
      return null;
    }
  }

  /// Stream a single ticket
  Stream<SupportTicket?> streamTicket(String ticketId) {
    return _ticketsRef.doc(ticketId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SupportTicket.fromFirestore(doc);
    });
  }

  /// Add a message to a ticket
  Future<TicketMessage?> addMessage({
    required String ticketId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String content,
    List<String> attachmentUrls = const [],
    bool isInternal = false,
  }) async {
    try {
      final now = DateTime.now();

      final messageData = {
        'ticketId': ticketId,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'content': content,
        'attachmentUrls': attachmentUrls,
        'isInternal': isInternal,
        'createdAt': Timestamp.fromDate(now),
      };

      final docRef = await _ticketsRef
          .doc(ticketId)
          .collection('messages')
          .add(messageData);

      // Update ticket's last updated time
      await _ticketsRef.doc(ticketId).update({
        'lastUpdatedAt': Timestamp.fromDate(now),
      });

      // If admin is responding for the first time, set firstResponseAt
      if (senderRole == 'admin') {
        final ticket = await getTicket(ticketId);
        if (ticket != null && ticket.firstResponseAt == null) {
          await _ticketsRef.doc(ticketId).update({
            'firstResponseAt': Timestamp.fromDate(now),
            'status': TicketStatus.inProgress.name,
          });
        }
      } else {
        // User responded, update status if it was awaiting response
        final ticket = await getTicket(ticketId);
        if (ticket?.status == TicketStatus.awaitingUserResponse) {
          await _ticketsRef.doc(ticketId).update({
            'status': TicketStatus.inProgress.name,
          });
        }
      }

      return TicketMessage(
        id: docRef.id,
        ticketId: ticketId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        content: content,
        attachmentUrls: attachmentUrls,
        isInternal: isInternal,
        createdAt: now,
      );
    } catch (e) {
      debugPrint('Error adding ticket message: $e');
      return null;
    }
  }

  /// Get messages for a ticket
  Future<List<TicketMessage>> getTicketMessages(
    String ticketId, {
    bool includeInternal = false,
  }) async {
    try {
      Query query = _ticketsRef
          .doc(ticketId)
          .collection('messages')
          .orderBy('createdAt', descending: false);

      if (!includeInternal) {
        query = query.where('isInternal', isEqualTo: false);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => TicketMessage.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting ticket messages: $e');
      return [];
    }
  }

  /// Stream messages for a ticket
  Stream<List<TicketMessage>> streamTicketMessages(
    String ticketId, {
    bool includeInternal = false,
  }) {
    Query query = _ticketsRef
        .doc(ticketId)
        .collection('messages')
        .orderBy('createdAt', descending: false);

    if (!includeInternal) {
      query = query.where('isInternal', isEqualTo: false);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => TicketMessage.fromFirestore(doc)).toList());
  }

  // ==================== ADMIN FUNCTIONS ====================

  /// Get all tickets (admin)
  Future<List<SupportTicket>> getAllTickets({
    TicketStatus? status,
    TicketCategory? category,
    TicketPriority? priority,
    String? assignedAdminId,
    int limit = 50,
  }) async {
    try {
      Query query = _ticketsRef.orderBy('createdAt', descending: true);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }
      if (category != null) {
        query = query.where('category', isEqualTo: category.name);
      }
      if (priority != null) {
        query = query.where('priority', isEqualTo: priority.name);
      }
      if (assignedAdminId != null) {
        query = query.where('assignedAdminId', isEqualTo: assignedAdminId);
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs
          .map((doc) => SupportTicket.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting all tickets: $e');
      return [];
    }
  }

  /// Get open tickets (admin)
  Future<List<SupportTicket>> getOpenTickets() async {
    try {
      final snapshot = await _ticketsRef
          .where('status', whereIn: [
            TicketStatus.open.name,
            TicketStatus.inProgress.name,
            TicketStatus.assigned.name,
          ])
          .orderBy('priority', descending: true)
          .orderBy('createdAt', descending: false)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => SupportTicket.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting open tickets: $e');
      return [];
    }
  }

  /// Assign ticket to admin
  Future<void> assignTicket({
    required String ticketId,
    required String adminId,
    required String adminName,
  }) async {
    try {
      await _ticketsRef.doc(ticketId).update({
        'assignedAdminId': adminId,
        'assignedAdminName': adminName,
        'status': TicketStatus.assigned.name,
        'lastUpdatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error assigning ticket: $e');
      rethrow;
    }
  }

  /// Update ticket status
  Future<void> updateTicketStatus({
    required String ticketId,
    required TicketStatus status,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status.name,
        'lastUpdatedAt': Timestamp.now(),
      };

      if (status == TicketStatus.resolved || status == TicketStatus.closed) {
        updates['resolvedAt'] = Timestamp.now();
      }

      await _ticketsRef.doc(ticketId).update(updates);
    } catch (e) {
      debugPrint('Error updating ticket status: $e');
      rethrow;
    }
  }

  /// Update ticket priority
  Future<void> updateTicketPriority({
    required String ticketId,
    required TicketPriority priority,
  }) async {
    try {
      await _ticketsRef.doc(ticketId).update({
        'priority': priority.name,
        'lastUpdatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating ticket priority: $e');
      rethrow;
    }
  }

  /// Add tags to ticket
  Future<void> addTags({
    required String ticketId,
    required List<String> tags,
  }) async {
    try {
      await _ticketsRef.doc(ticketId).update({
        'tags': FieldValue.arrayUnion(tags),
        'lastUpdatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error adding tags: $e');
      rethrow;
    }
  }

  /// Get ticket statistics (admin dashboard)
  Future<Map<String, dynamic>> getTicketStats() async {
    try {
      final openCount = await _ticketsRef
          .where('status', isEqualTo: TicketStatus.open.name)
          .count()
          .get();

      final inProgressCount = await _ticketsRef
          .where('status', isEqualTo: TicketStatus.inProgress.name)
          .count()
          .get();

      final urgentCount = await _ticketsRef
          .where('priority', isEqualTo: TicketPriority.urgent.name)
          .where('status', whereIn: [
            TicketStatus.open.name,
            TicketStatus.inProgress.name,
          ])
          .count()
          .get();

      // Get resolved tickets from last 7 days
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final resolvedThisWeek = await _ticketsRef
          .where('status', isEqualTo: TicketStatus.resolved.name)
          .where('resolvedAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .count()
          .get();

      // Calculate average response time from recent tickets
      final recentResolved = await _ticketsRef
          .where('status', isEqualTo: TicketStatus.resolved.name)
          .where('firstResponseAt', isNull: false)
          .orderBy('firstResponseAt', descending: true)
          .limit(50)
          .get();

      double avgResponseTimeHours = 0;
      if (recentResolved.docs.isNotEmpty) {
        double totalHours = 0;
        int count = 0;
        for (final doc in recentResolved.docs) {
          final ticket = SupportTicket.fromFirestore(doc);
          if (ticket.responseTimeHours != null) {
            totalHours += ticket.responseTimeHours!;
            count++;
          }
        }
        if (count > 0) {
          avgResponseTimeHours = totalHours / count;
        }
      }

      return {
        'open': openCount.count ?? 0,
        'inProgress': inProgressCount.count ?? 0,
        'urgent': urgentCount.count ?? 0,
        'resolvedThisWeek': resolvedThisWeek.count ?? 0,
        'avgResponseTimeHours': avgResponseTimeHours,
      };
    } catch (e) {
      debugPrint('Error getting ticket stats: $e');
      return {
        'open': 0,
        'inProgress': 0,
        'urgent': 0,
        'resolvedThisWeek': 0,
        'avgResponseTimeHours': 0.0,
      };
    }
  }

  // ==================== CANNED RESPONSES ====================

  /// Get all canned responses
  Future<List<CannedResponse>> getCannedResponses() async {
    try {
      final snapshot =
          await _cannedResponsesRef.orderBy('usageCount', descending: true).get();

      if (snapshot.docs.isEmpty) {
        // Return defaults if none exist
        return DefaultCannedResponses.responses;
      }

      return snapshot.docs
          .map((doc) => CannedResponse.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting canned responses: $e');
      return DefaultCannedResponses.responses;
    }
  }

  /// Create a canned response
  Future<void> createCannedResponse(CannedResponse response) async {
    try {
      await _cannedResponsesRef.add(response.toMap());
    } catch (e) {
      debugPrint('Error creating canned response: $e');
      rethrow;
    }
  }

  /// Increment canned response usage count
  Future<void> incrementCannedResponseUsage(String responseId) async {
    try {
      await _cannedResponsesRef.doc(responseId).update({
        'usageCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing canned response usage: $e');
    }
  }

  /// Delete a canned response
  Future<void> deleteCannedResponse(String responseId) async {
    try {
      await _cannedResponsesRef.doc(responseId).delete();
    } catch (e) {
      debugPrint('Error deleting canned response: $e');
      rethrow;
    }
  }
}
