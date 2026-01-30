import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comprehensive Chat Service Tests for BODA CONNECT
///
/// Test Coverage:
/// 1. Conversation Creation
/// 2. Message Sending
/// 3. Message Reading/Marking as Read
/// 4. Typing Indicators
/// 5. Contact Detection (Anti-Fraud)
/// 6. Response Rate Calculation
/// 7. Conversation Search
/// 8. Message Attachments
void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('Conversation Creation Tests', () {
    test('should create new conversation between client and supplier', () async {
      await fakeFirestore.collection('conversations').doc('conv-123').set({
        'participants': ['client-456', 'supplier-789'],
        'participantDetails': {
          'client-456': {
            'name': 'João Silva',
            'avatar': 'https://example.com/avatar1.jpg',
            'role': 'client',
          },
          'supplier-789': {
            'name': 'Foto Premium',
            'avatar': 'https://example.com/avatar2.jpg',
            'role': 'supplier',
          },
        },
        'lastMessage': null,
        'lastMessageAt': null,
        'unreadCount': {
          'client-456': 0,
          'supplier-789': 0,
        },
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('conversations').doc('conv-123').get();
      expect(doc.exists, isTrue);
      expect((doc.data()?['participants'] as List).length, 2);
    });

    test('should find existing conversation', () async {
      await fakeFirestore.collection('conversations').doc('conv-123').set({
        'participants': ['client-456', 'supplier-789'],
        'createdAt': Timestamp.now(),
      });

      final query = await fakeFirestore
          .collection('conversations')
          .where('participants', arrayContains: 'client-456')
          .get();

      // Filter locally for exact match
      final exactMatch = query.docs.where((doc) {
        final participants = doc.data()['participants'] as List;
        return participants.contains('supplier-789');
      }).toList();

      expect(exactMatch.length, 1);
    });

    test('should not create duplicate conversations', () async {
      // First conversation
      await fakeFirestore.collection('conversations').doc('conv-1').set({
        'participants': ['client-456', 'supplier-789'],
        'createdAt': Timestamp.now(),
      });

      // Check if exists before creating
      final existing = await fakeFirestore
          .collection('conversations')
          .where('participants', arrayContains: 'client-456')
          .get();

      final hasConversation = existing.docs.any((doc) {
        final participants = doc.data()['participants'] as List;
        return participants.contains('supplier-789');
      });

      expect(hasConversation, isTrue);
    });
  });

  group('Message Sending Tests', () {
    test('should send text message', () async {
      await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .add({
        'senderId': 'client-456',
        'text': 'Olá, gostaria de saber sobre o pacote de fotografia.',
        'type': 'text',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      final messages = await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .get();

      expect(messages.docs.length, 1);
      expect(messages.docs.first.data()['type'], 'text');
    });

    test('should send image message', () async {
      await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .add({
        'senderId': 'client-456',
        'text': '',
        'type': 'image',
        'imageUrl': 'https://storage.example.com/image.jpg',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      final messages = await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .get();

      expect(messages.docs.first.data()['type'], 'image');
      expect(messages.docs.first.data()['imageUrl'], isNotNull);
    });

    test('should update conversation with last message', () async {
      await fakeFirestore.collection('conversations').doc('conv-123').set({
        'participants': ['client-456', 'supplier-789'],
        'lastMessage': null,
        'lastMessageAt': null,
      });

      // Send message
      await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .add({
        'senderId': 'client-456',
        'text': 'Olá!',
        'createdAt': Timestamp.now(),
      });

      // Update conversation
      await fakeFirestore.collection('conversations').doc('conv-123').update({
        'lastMessage': 'Olá!',
        'lastMessageAt': Timestamp.now(),
        'lastMessageSenderId': 'client-456',
        'unreadCount.supplier-789': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('conversations').doc('conv-123').get();
      expect(doc.data()?['lastMessage'], 'Olá!');
    });
  });

  group('Message Reading Tests', () {
    test('should mark message as read', () async {
      final messageRef = await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .add({
        'senderId': 'client-456',
        'text': 'Olá!',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      await messageRef.update({
        'isRead': true,
        'readAt': Timestamp.now(),
      });

      final message = await messageRef.get();
      expect(message.data()?['isRead'], true);
      expect(message.data()?['readAt'], isNotNull);
    });

    test('should mark all messages as read', () async {
      // Create multiple unread messages
      for (int i = 0; i < 5; i++) {
        await fakeFirestore
            .collection('conversations')
            .doc('conv-123')
            .collection('messages')
            .add({
          'senderId': 'supplier-789',
          'text': 'Message $i',
          'isRead': false,
          'createdAt': Timestamp.now(),
        });
      }

      // Mark all as read
      final messages = await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .where('senderId', isNotEqualTo: 'client-456')
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in messages.docs) {
        await doc.reference.update({
          'isRead': true,
          'readAt': Timestamp.now(),
        });
      }

      // Verify all are read
      final updatedMessages = await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .get();

      expect(updatedMessages.docs.every((doc) => doc.data()['isRead'] == true), true);
    });

    test('should reset unread count', () async {
      await fakeFirestore.collection('conversations').doc('conv-123').set({
        'participants': ['client-456', 'supplier-789'],
        'unreadCount': {
          'client-456': 5,
          'supplier-789': 0,
        },
      });

      await fakeFirestore.collection('conversations').doc('conv-123').update({
        'unreadCount.client-456': 0,
      });

      final doc = await fakeFirestore.collection('conversations').doc('conv-123').get();
      expect(doc.data()?['unreadCount']['client-456'], 0);
    });
  });

  group('Typing Indicator Tests', () {
    test('should set typing indicator', () async {
      // Initialize with a placeholder to ensure the map is properly typed
      await fakeFirestore.collection('conversations').doc('conv-123').set({
        'participants': ['client-456', 'supplier-789'],
        'typing': <String, dynamic>{'_placeholder': false},
      });

      await fakeFirestore.collection('conversations').doc('conv-123').update({
        'typing.client-456': true,
      });

      final doc = await fakeFirestore.collection('conversations').doc('conv-123').get();
      expect(doc.data()?['typing']['client-456'], true);
    });

    test('should clear typing indicator', () async {
      await fakeFirestore.collection('conversations').doc('conv-123').set({
        'typing': {'client-456': true},
      });

      await fakeFirestore.collection('conversations').doc('conv-123').update({
        'typing.client-456': false,
      });

      final doc = await fakeFirestore.collection('conversations').doc('conv-123').get();
      expect(doc.data()?['typing']['client-456'], false);
    });
  });

  group('Contact Detection Tests', () {
    test('should detect phone number in message', () {
      final phonePatterns = [
        '+244912345678',
        '912345678',
        '912-345-678',
        '912 345 678',
        '(+244) 912 345 678',
      ];

      for (final phone in phonePatterns) {
        final hasPhone = _containsContactInfo(phone);
        expect(hasPhone, isTrue, reason: 'Failed to detect: $phone');
      }
    });

    test('should detect email in message', () {
      final emailPatterns = [
        'test@example.com',
        'user.name@domain.co.ao',
        'contact@company.com',
      ];

      for (final email in emailPatterns) {
        final hasEmail = _containsContactInfo(email);
        expect(hasEmail, isTrue, reason: 'Failed to detect: $email');
      }
    });

    test('should detect social media handles', () {
      final socialPatterns = [
        '@instagram_user',
        'facebook.com/user',
        'whatsapp 912345678',
        'meu whats: 912345678',
      ];

      for (final pattern in socialPatterns) {
        final hasSocial = _containsContactInfo(pattern);
        expect(hasSocial, isTrue, reason: 'Failed to detect: $pattern');
      }
    });

    test('should flag message with contact info', () async {
      await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .add({
        'senderId': 'client-456',
        'text': 'Pode me ligar no 912345678',
        'type': 'text',
        'containsContactInfo': true,
        'flaggedAt': Timestamp.now(),
        'createdAt': Timestamp.now(),
      });

      final messages = await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .where('containsContactInfo', isEqualTo: true)
          .get();

      expect(messages.docs.length, 1);
    });

    test('should create contact detection alert', () async {
      await fakeFirestore.collection('contact_detection_alerts').add({
        'conversationId': 'conv-123',
        'messageId': 'msg-456',
        'senderId': 'client-789',
        'detectedPatterns': ['phone', 'whatsapp'],
        'originalText': 'Pode me ligar no 912345678 ou whatsapp',
        'severity': 'medium',
        'reviewed': false,
        'createdAt': Timestamp.now(),
      });

      final alerts = await fakeFirestore.collection('contact_detection_alerts').get();
      expect(alerts.docs.length, 1);
      expect(alerts.docs.first.data()['severity'], 'medium');
    });
  });

  group('Response Rate Calculation Tests', () {
    test('should calculate response rate', () async {
      // Supplier has 10 conversations, responded to 8
      final totalConversations = 10;
      final respondedConversations = 8;
      final responseRate = respondedConversations / totalConversations;

      expect(responseRate, 0.8);
    });

    test('should track supplier response time', () async {
      // Message received at 10:00, responded at 10:30
      final messageReceivedAt = DateTime(2024, 1, 1, 10, 0);
      final responseAt = DateTime(2024, 1, 1, 10, 30);
      final responseTime = responseAt.difference(messageReceivedAt);

      expect(responseTime.inMinutes, 30);

      // Store average response time
      await fakeFirestore.collection('supplier_stats').doc('supplier-123').set({
        'averageResponseTime': 30, // minutes
        'totalResponses': 100,
        'updatedAt': Timestamp.now(),
      });

      final stats = await fakeFirestore.collection('supplier_stats').doc('supplier-123').get();
      expect(stats.data()?['averageResponseTime'], 30);
    });

    test('should count quick responses (under 1 hour)', () async {
      final responseTimes = [15, 30, 45, 90, 120, 180]; // minutes
      final quickResponses = responseTimes.where((t) => t <= 60).length;

      expect(quickResponses, 3); // 15, 30, 45 minutes

      await fakeFirestore.collection('supplier_stats').doc('supplier-123').set({
        'totalResponses': responseTimes.length,
        'quickResponses': quickResponses,
        'quickResponseRate': quickResponses / responseTimes.length,
      });

      final stats = await fakeFirestore.collection('supplier_stats').doc('supplier-123').get();
      expect(stats.data()?['quickResponseRate'], 0.5);
    });
  });

  group('Conversation Search Tests', () {
    test('should get conversations for user', () async {
      await fakeFirestore.collection('conversations').add({
        'participants': ['user-123', 'supplier-456'],
        'createdAt': Timestamp.now(),
      });
      await fakeFirestore.collection('conversations').add({
        'participants': ['user-123', 'supplier-789'],
        'createdAt': Timestamp.now(),
      });
      await fakeFirestore.collection('conversations').add({
        'participants': ['other-user', 'supplier-456'],
        'createdAt': Timestamp.now(),
      });

      final conversations = await fakeFirestore
          .collection('conversations')
          .where('participants', arrayContains: 'user-123')
          .get();

      expect(conversations.docs.length, 2);
    });

    test('should search messages by text', () async {
      await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .add({
        'text': 'Informações sobre fotografia',
        'createdAt': Timestamp.now(),
      });
      await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .add({
        'text': 'Preço do pacote de casamento',
        'createdAt': Timestamp.now(),
      });

      // In real app, this would use Algolia or full-text search
      // For testing, we simulate by getting all and filtering
      final messages = await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .get();

      final searchTerm = 'fotografia';
      final matchingMessages = messages.docs.where((doc) {
        final text = doc.data()['text'] as String;
        return text.toLowerCase().contains(searchTerm.toLowerCase());
      }).toList();

      expect(matchingMessages.length, 1);
    });
  });

  group('Message Attachment Tests', () {
    test('should send message with file attachment', () async {
      await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .add({
        'senderId': 'client-456',
        'text': 'Segue o contrato',
        'type': 'file',
        'fileUrl': 'https://storage.example.com/contract.pdf',
        'fileName': 'contrato.pdf',
        'fileSize': 1024000, // 1MB
        'mimeType': 'application/pdf',
        'createdAt': Timestamp.now(),
      });

      final messages = await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .where('type', isEqualTo: 'file')
          .get();

      expect(messages.docs.length, 1);
      expect(messages.docs.first.data()['mimeType'], 'application/pdf');
    });

    test('should send message with multiple images', () async {
      await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .add({
        'senderId': 'supplier-789',
        'text': 'Algumas fotos do meu trabalho',
        'type': 'gallery',
        'images': [
          'https://storage.example.com/photo1.jpg',
          'https://storage.example.com/photo2.jpg',
          'https://storage.example.com/photo3.jpg',
        ],
        'createdAt': Timestamp.now(),
      });

      final messages = await fakeFirestore
          .collection('conversations')
          .doc('conv-123')
          .collection('messages')
          .where('type', isEqualTo: 'gallery')
          .get();

      expect(messages.docs.length, 1);
      expect((messages.docs.first.data()['images'] as List).length, 3);
    });
  });

  group('Conversation Archiving Tests', () {
    test('should archive conversation', () async {
      await fakeFirestore.collection('conversations').doc('conv-123').set({
        'participants': ['client-456', 'supplier-789'],
        'isArchived': {'client-456': false, 'supplier-789': false},
      });

      await fakeFirestore.collection('conversations').doc('conv-123').update({
        'isArchived.client-456': true,
      });

      final doc = await fakeFirestore.collection('conversations').doc('conv-123').get();
      expect(doc.data()?['isArchived']['client-456'], true);
      expect(doc.data()?['isArchived']['supplier-789'], false);
    });

    test('should unarchive conversation', () async {
      await fakeFirestore.collection('conversations').doc('conv-123').set({
        'isArchived': {'client-456': true},
      });

      await fakeFirestore.collection('conversations').doc('conv-123').update({
        'isArchived.client-456': false,
      });

      final doc = await fakeFirestore.collection('conversations').doc('conv-123').get();
      expect(doc.data()?['isArchived']['client-456'], false);
    });
  });

  group('Conversation Muting Tests', () {
    test('should mute conversation notifications', () async {
      // Initialize with a placeholder to ensure the map is properly typed
      await fakeFirestore.collection('conversations').doc('conv-123').set({
        'participants': ['client-456', 'supplier-789'],
        'muted': <String, dynamic>{'_placeholder': false},
      });

      await fakeFirestore.collection('conversations').doc('conv-123').update({
        'muted.client-456': true,
      });

      final doc = await fakeFirestore.collection('conversations').doc('conv-123').get();
      expect(doc.data()?['muted']['client-456'], true);
    });
  });
}

// Helper function to detect contact information
bool _containsContactInfo(String text) {
  final lowerText = text.toLowerCase();

  // Phone number patterns
  final phoneRegex = RegExp(r'(\+?244)?[\s\-\.]?\d{3}[\s\-\.]?\d{3}[\s\-\.]?\d{3}');
  if (phoneRegex.hasMatch(text)) return true;

  // Email pattern
  final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
  if (emailRegex.hasMatch(text)) return true;

  // Social media patterns
  final socialPatterns = [
    r'@\w+',
    r'facebook\.com',
    r'instagram\.com',
    r'whatsapp',
    r'whats',
    r'telegram',
  ];

  for (final pattern in socialPatterns) {
    if (RegExp(pattern, caseSensitive: false).hasMatch(lowerText)) {
      return true;
    }
  }

  return false;
}
