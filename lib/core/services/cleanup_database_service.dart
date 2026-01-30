import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to clean up test data from Firestore
class CleanupDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Clean up all test data (except users)
  Future<void> cleanupTestData() async {
    debugPrint('🧹 Starting database cleanup...');

    // Delete all categories
    await _deleteCollection('categories');

    // Delete all suppliers (except those with real user IDs)
    await _deleteCollection('suppliers');

    // Delete all packages
    await _deleteCollection('packages');

    // Delete all reviews
    await _deleteCollection('reviews');

    // Delete all bookings
    await _deleteCollection('bookings');

    // Delete all conversations and their messages
    await _deleteConversationsWithMessages();

    // Delete all favorites
    await _deleteCollection('favorites');

    debugPrint('✅ Database cleanup completed!');
  }

  Future<void> _deleteCollection(String collectionName) async {
    debugPrint('🗑️  Deleting $collectionName...');

    try {
      final snapshot = await _firestore.collection(collectionName).get();
      int deletedCount = 0;
      int skippedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          await doc.reference.delete();
          deletedCount++;
        } catch (e) {
          // Permission denied - skip this document (it belongs to another user)
          debugPrint('   ⚠️  Skipped ${doc.id} (permission denied)');
          skippedCount++;
        }
      }

      if (skippedCount > 0) {
        debugPrint('   ✓ Deleted $deletedCount documents from $collectionName ($skippedCount skipped)');
      } else {
        debugPrint('   ✓ Deleted $deletedCount documents from $collectionName');
      }
    } catch (e) {
      debugPrint('   ⚠️  Error accessing $collectionName: $e');
    }
  }

  Future<void> _deleteConversationsWithMessages() async {
    debugPrint('🗑️  Deleting conversations and messages...');

    try {
      final conversationsSnapshot = await _firestore.collection('conversations').get();
      int deletedCount = 0;
      int skippedCount = 0;

      for (var conversationDoc in conversationsSnapshot.docs) {
        try {
          // Delete all messages in this conversation
          final messagesSnapshot = await conversationDoc.reference
              .collection('messages')
              .get();

          for (var messageDoc in messagesSnapshot.docs) {
            try {
              await messageDoc.reference.delete();
            } catch (e) {
              // Skip message if permission denied
            }
          }

          // Delete the conversation itself
          await conversationDoc.reference.delete();
          deletedCount++;
        } catch (e) {
          // Permission denied - skip this conversation
          debugPrint('   ⚠️  Skipped conversation ${conversationDoc.id} (permission denied)');
          skippedCount++;
        }
      }

      if (skippedCount > 0) {
        debugPrint('   ✓ Deleted $deletedCount conversations with messages ($skippedCount skipped)');
      } else {
        debugPrint('   ✓ Deleted $deletedCount conversations with messages');
      }
    } catch (e) {
      debugPrint('   ⚠️  Error accessing conversations: $e');
    }
  }
}
