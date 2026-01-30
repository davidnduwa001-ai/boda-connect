import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for calculating and updating supplier response times
/// Based on actual chat message timestamps
class ResponseTimeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate average response time for a supplier
  /// Returns the formatted response time string (e.g., "30 min", "2 horas", "1 dia")
  Future<String?> calculateResponseTime(String supplierId) async {
    try {
      // Get all chats where this supplier is involved
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('supplierId', isEqualTo: supplierId)
          .get();

      if (chatsSnapshot.docs.isEmpty) {
        debugPrint('No chats found for supplier $supplierId');
        return null;
      }

      final responseTimes = <Duration>[];

      for (final chatDoc in chatsSnapshot.docs) {
        final chatId = chatDoc.id;
        final chatData = chatDoc.data();
        final clientId = chatData['clientId'] as String?;

        if (clientId == null) continue;

        // Get first client message in this chat
        final clientMessagesSnapshot = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('senderId', isEqualTo: clientId)
            .orderBy('createdAt', descending: false)
            .limit(1)
            .get();

        if (clientMessagesSnapshot.docs.isEmpty) continue;

        final firstClientMessage = clientMessagesSnapshot.docs.first;
        final clientMessageTime = (firstClientMessage.data()['createdAt'] as Timestamp?)?.toDate();

        if (clientMessageTime == null) continue;

        // Get first supplier response after the client's message
        final supplierMessagesSnapshot = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('senderId', isEqualTo: supplierId)
            .where('createdAt', isGreaterThan: Timestamp.fromDate(clientMessageTime))
            .orderBy('createdAt', descending: false)
            .limit(1)
            .get();

        // Also check if supplier is the userId (not the document ID)
        if (supplierMessagesSnapshot.docs.isEmpty) {
          // Try with supplier's userId
          final supplierDoc = await _firestore.collection('suppliers').doc(supplierId).get();
          final supplierUserId = supplierDoc.data()?['userId'] as String?;

          if (supplierUserId != null) {
            final altSupplierMessagesSnapshot = await _firestore
                .collection('chats')
                .doc(chatId)
                .collection('messages')
                .where('senderId', isEqualTo: supplierUserId)
                .where('createdAt', isGreaterThan: Timestamp.fromDate(clientMessageTime))
                .orderBy('createdAt', descending: false)
                .limit(1)
                .get();

            if (altSupplierMessagesSnapshot.docs.isNotEmpty) {
              final supplierMessageTime = (altSupplierMessagesSnapshot.docs.first.data()['createdAt'] as Timestamp?)?.toDate();
              if (supplierMessageTime != null) {
                final responseTime = supplierMessageTime.difference(clientMessageTime);
                responseTimes.add(responseTime);
              }
            }
          }
          continue;
        }

        final supplierMessageTime = (supplierMessagesSnapshot.docs.first.data()['createdAt'] as Timestamp?)?.toDate();

        if (supplierMessageTime != null) {
          final responseTime = supplierMessageTime.difference(clientMessageTime);
          responseTimes.add(responseTime);
        }
      }

      if (responseTimes.isEmpty) {
        debugPrint('No response times calculated for supplier $supplierId');
        return null;
      }

      // Calculate average
      final totalMinutes = responseTimes.fold<int>(
        0,
        (sum, duration) => sum + duration.inMinutes,
      );
      final averageMinutes = totalMinutes ~/ responseTimes.length;

      // Format the response time
      final formattedTime = _formatResponseTime(averageMinutes);

      debugPrint('Average response time for $supplierId: $averageMinutes minutes ($formattedTime)');
      return formattedTime;
    } catch (e) {
      debugPrint('Error calculating response time: $e');
      return null;
    }
  }

  /// Format response time in minutes to a human-readable string
  String _formatResponseTime(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    } else if (minutes < 1440) { // Less than 24 hours
      final hours = minutes ~/ 60;
      return hours == 1 ? '1 hora' : '$hours horas';
    } else {
      final days = minutes ~/ 1440;
      return days == 1 ? '1 dia' : '$days dias';
    }
  }

  /// Update supplier's response time in Firestore
  Future<void> updateSupplierResponseTime(String supplierId) async {
    try {
      final responseTime = await calculateResponseTime(supplierId);

      if (responseTime != null) {
        await _firestore.collection('suppliers').doc(supplierId).update({
          'responseTime': responseTime,
          'updatedAt': Timestamp.now(),
        });
        debugPrint('Updated response time for $supplierId: $responseTime');
      }
    } catch (e) {
      debugPrint('Error updating response time: $e');
    }
  }

  /// Calculate and update response rate (percentage of chats with responses)
  Future<double> calculateResponseRate(String supplierId) async {
    try {
      // Get all chats
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('supplierId', isEqualTo: supplierId)
          .get();

      if (chatsSnapshot.docs.isEmpty) return 0.0;

      int chatsWithResponse = 0;

      // Get supplier's userId for message checking
      final supplierDoc = await _firestore.collection('suppliers').doc(supplierId).get();
      final supplierUserId = supplierDoc.data()?['userId'] as String?;

      for (final chatDoc in chatsSnapshot.docs) {
        final chatId = chatDoc.id;

        // Check if supplier has sent any messages in this chat
        final supplierMessagesSnapshot = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('senderId', whereIn: [supplierId, if (supplierUserId != null) supplierUserId])
            .limit(1)
            .get();

        if (supplierMessagesSnapshot.docs.isNotEmpty) {
          chatsWithResponse++;
        }
      }

      final responseRate = chatsSnapshot.docs.isEmpty
          ? 0.0
          : (chatsWithResponse / chatsSnapshot.docs.length) * 100;

      // Update in Firestore
      await _firestore.collection('suppliers').doc(supplierId).update({
        'responseRate': responseRate,
        'updatedAt': Timestamp.now(),
      });

      debugPrint('Response rate for $supplierId: $responseRate%');
      return responseRate;
    } catch (e) {
      debugPrint('Error calculating response rate: $e');
      return 0.0;
    }
  }

  /// Update both response time and rate
  Future<void> updateAllResponseMetrics(String supplierId) async {
    await updateSupplierResponseTime(supplierId);
    await calculateResponseRate(supplierId);
  }

  /// Update response time when a new message is sent by supplier
  /// Call this from chat service when supplier sends a message
  Future<void> onSupplierMessageSent({
    required String chatId,
    required String supplierId,
    required DateTime messageTime,
  }) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final chatData = chatDoc.data();
      if (chatData == null) return;

      final clientId = chatData['clientId'] as String?;
      if (clientId == null) return;

      // Get the last unanswered client message
      final supplierDoc = await _firestore.collection('suppliers').doc(supplierId).get();
      final supplierUserId = supplierDoc.data()?['userId'] as String?;

      // Find the most recent client message before this supplier message
      final clientMessagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: clientId)
          .where('createdAt', isLessThan: Timestamp.fromDate(messageTime))
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (clientMessagesSnapshot.docs.isEmpty) return;

      final lastClientMessage = clientMessagesSnapshot.docs.first;
      final lastClientMessageTime = (lastClientMessage.data()['createdAt'] as Timestamp?)?.toDate();

      if (lastClientMessageTime == null) return;

      // Check if there was already a supplier response after that client message
      final existingResponseSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', whereIn: [supplierId, if (supplierUserId != null) supplierUserId])
          .where('createdAt', isGreaterThan: Timestamp.fromDate(lastClientMessageTime))
          .where('createdAt', isLessThan: Timestamp.fromDate(messageTime))
          .limit(1)
          .get();

      // If there was already a response, don't update response time
      if (existingResponseSnapshot.docs.isNotEmpty) return;

      // This is the first response - recalculate average response time
      await updateSupplierResponseTime(supplierId);
    } catch (e) {
      debugPrint('Error updating response time on message: $e');
    }
  }
}
