import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boda_connect/features/chat/data/models/conversation_model.dart';
import 'package:boda_connect/features/chat/domain/entities/conversation_entity.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late DateTime testCreatedAt;
  late DateTime testUpdatedAt;
  late DateTime testLastMessageAt;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    testCreatedAt = DateTime(2024, 1, 10, 9, 0);
    testUpdatedAt = DateTime(2024, 1, 15, 14, 30);
    testLastMessageAt = DateTime(2024, 1, 15, 14, 25);
  });

  group('ConversationModel -', () {
    group('fromFirestore -', () {
      test('should correctly parse conversation from DocumentSnapshot with all fields', () async {
        // Arrange
        final data = {
          'participants': ['user-1', 'user-2'],
          'clientId': 'user-1',
          'supplierId': 'user-2',
          'clientName': 'John Doe',
          'supplierName': 'ABC Photography',
          'clientPhoto': 'https://example.com/client.jpg',
          'supplierPhoto': 'https://example.com/supplier.jpg',
          'lastMessage': 'Hello, how are you?',
          'lastMessageAt': Timestamp.fromDate(testLastMessageAt),
          'lastMessageSenderId': 'user-1',
          'unreadCount': {
            'user-1': 0,
            'user-2': 3,
          },
          'isActive': true,
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        final doc = await fakeFirestore.collection('conversations').add(data);
        final snapshot = await doc.get();

        // Act
        final result = ConversationModel.fromFirestore(snapshot);

        // Assert
        expect(result.id, snapshot.id);
        expect(result.participants, ['user-1', 'user-2']);
        expect(result.clientId, 'user-1');
        expect(result.supplierId, 'user-2');
        expect(result.clientName, 'John Doe');
        expect(result.supplierName, 'ABC Photography');
        expect(result.clientPhoto, 'https://example.com/client.jpg');
        expect(result.supplierPhoto, 'https://example.com/supplier.jpg');
        expect(result.lastMessage, 'Hello, how are you?');
        expect(result.lastMessageAt, testLastMessageAt);
        expect(result.lastMessageSenderId, 'user-1');
        expect(result.unreadCount['user-1'], 0);
        expect(result.unreadCount['user-2'], 3);
        expect(result.isActive, true);
        expect(result.createdAt, testCreatedAt);
        expect(result.updatedAt, testUpdatedAt);
      });

      test('should correctly parse conversation with minimal required fields', () async {
        // Arrange
        final data = {
          'participants': ['user-1', 'user-2'],
          'clientId': 'user-1',
          'supplierId': 'user-2',
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        final doc = await fakeFirestore.collection('conversations').add(data);
        final snapshot = await doc.get();

        // Act
        final result = ConversationModel.fromFirestore(snapshot);

        // Assert
        expect(result.participants, ['user-1', 'user-2']);
        expect(result.clientId, 'user-1');
        expect(result.supplierId, 'user-2');
        expect(result.clientName, isNull);
        expect(result.supplierName, isNull);
        expect(result.clientPhoto, isNull);
        expect(result.supplierPhoto, isNull);
        expect(result.lastMessage, isNull);
        expect(result.lastMessageAt, isNull);
        expect(result.lastMessageSenderId, isNull);
        expect(result.unreadCount, isEmpty);
        expect(result.isActive, true); // default value
        expect(result.createdAt, testCreatedAt);
        expect(result.updatedAt, testUpdatedAt);
      });

      test('should handle null unreadCount correctly', () async {
        // Arrange
        final data = {
          'participants': ['user-1', 'user-2'],
          'clientId': 'user-1',
          'supplierId': 'user-2',
          'unreadCount': null,
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        final doc = await fakeFirestore.collection('conversations').add(data);
        final snapshot = await doc.get();

        // Act
        final result = ConversationModel.fromFirestore(snapshot);

        // Assert
        expect(result.unreadCount, isEmpty);
      });

      test('should handle empty unreadCount correctly', () async {
        // Arrange
        final data = {
          'participants': ['user-1', 'user-2'],
          'clientId': 'user-1',
          'supplierId': 'user-2',
          'unreadCount': {},
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        final doc = await fakeFirestore.collection('conversations').add(data);
        final snapshot = await doc.get();

        // Act
        final result = ConversationModel.fromFirestore(snapshot);

        // Assert
        expect(result.unreadCount, isEmpty);
      });

      test('should parse unreadCount with numeric keys correctly', () async {
        // Arrange - Firestore might return numeric keys
        final data = {
          'participants': ['user-1', 'user-2'],
          'clientId': 'user-1',
          'supplierId': 'user-2',
          'unreadCount': {
            'user-1': 5,
            'user-2': 10,
          },
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        final doc = await fakeFirestore.collection('conversations').add(data);
        final snapshot = await doc.get();

        // Act
        final result = ConversationModel.fromFirestore(snapshot);

        // Assert
        expect(result.unreadCount['user-1'], 5);
        expect(result.unreadCount['user-2'], 10);
      });

      test('should default isActive to true when not provided', () async {
        // Arrange
        final data = {
          'participants': ['user-1', 'user-2'],
          'clientId': 'user-1',
          'supplierId': 'user-2',
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        final doc = await fakeFirestore.collection('conversations').add(data);
        final snapshot = await doc.get();

        // Act
        final result = ConversationModel.fromFirestore(snapshot);

        // Assert
        expect(result.isActive, true);
      });

      test('should correctly parse inactive conversation', () async {
        // Arrange
        final data = {
          'participants': ['user-1', 'user-2'],
          'clientId': 'user-1',
          'supplierId': 'user-2',
          'isActive': false,
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        final doc = await fakeFirestore.collection('conversations').add(data);
        final snapshot = await doc.get();

        // Act
        final result = ConversationModel.fromFirestore(snapshot);

        // Assert
        expect(result.isActive, false);
      });
    });

    group('toFirestore -', () {
      test('should correctly convert conversation to Firestore map with all fields', () {
        // Arrange
        final conversation = ConversationModel(
          id: 'conv-123',
          participants: ['user-1', 'user-2'],
          clientId: 'user-1',
          supplierId: 'user-2',
          clientName: 'John Doe',
          supplierName: 'ABC Photography',
          clientPhoto: 'https://example.com/client.jpg',
          supplierPhoto: 'https://example.com/supplier.jpg',
          lastMessage: 'Hello, how are you?',
          lastMessageAt: testLastMessageAt,
          lastMessageSenderId: 'user-1',
          unreadCount: {
            'user-1': 0,
            'user-2': 3,
          },
          isActive: true,
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
        );

        // Act
        final result = conversation.toFirestore();

        // Assert
        expect(result['participants'], ['user-1', 'user-2']);
        expect(result['clientId'], 'user-1');
        expect(result['supplierId'], 'user-2');
        expect(result['clientName'], 'John Doe');
        expect(result['supplierName'], 'ABC Photography');
        expect(result['clientPhoto'], 'https://example.com/client.jpg');
        expect(result['supplierPhoto'], 'https://example.com/supplier.jpg');
        expect(result['lastMessage'], 'Hello, how are you?');
        expect(result['lastMessageAt'], Timestamp.fromDate(testLastMessageAt));
        expect(result['lastMessageSenderId'], 'user-1');
        expect(result['unreadCount'], {'user-1': 0, 'user-2': 3});
        expect(result['isActive'], true);
        expect(result['createdAt'], Timestamp.fromDate(testCreatedAt));
        expect(result['updatedAt'], Timestamp.fromDate(testUpdatedAt));
      });

      test('should correctly convert conversation with minimal fields to Firestore map', () {
        // Arrange
        final conversation = ConversationModel(
          id: 'conv-123',
          participants: ['user-1', 'user-2'],
          clientId: 'user-1',
          supplierId: 'user-2',
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
        );

        // Act
        final result = conversation.toFirestore();

        // Assert
        expect(result['participants'], ['user-1', 'user-2']);
        expect(result['clientId'], 'user-1');
        expect(result['supplierId'], 'user-2');
        expect(result['clientName'], isNull);
        expect(result['supplierName'], isNull);
        expect(result['clientPhoto'], isNull);
        expect(result['supplierPhoto'], isNull);
        expect(result['lastMessage'], isNull);
        expect(result['lastMessageAt'], isNull);
        expect(result['lastMessageSenderId'], isNull);
        expect(result['unreadCount'], isEmpty);
        expect(result['isActive'], true);
        expect(result['createdAt'], Timestamp.fromDate(testCreatedAt));
        expect(result['updatedAt'], Timestamp.fromDate(testUpdatedAt));
      });

      test('should convert null lastMessageAt to null Timestamp', () {
        // Arrange
        final conversation = ConversationModel(
          id: 'conv-123',
          participants: ['user-1', 'user-2'],
          clientId: 'user-1',
          supplierId: 'user-2',
          lastMessageAt: null,
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
        );

        // Act
        final result = conversation.toFirestore();

        // Assert
        expect(result['lastMessageAt'], isNull);
      });

      test('should preserve unreadCount map structure', () {
        // Arrange
        final conversation = ConversationModel(
          id: 'conv-123',
          participants: ['user-1', 'user-2'],
          clientId: 'user-1',
          supplierId: 'user-2',
          unreadCount: {
            'user-1': 5,
            'user-2': 10,
          },
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
        );

        // Act
        final result = conversation.toFirestore();

        // Assert
        expect(result['unreadCount'], isA<Map<String, int>>());
        expect(result['unreadCount']['user-1'], 5);
        expect(result['unreadCount']['user-2'], 10);
      });
    });

    group('toEntity -', () {
      test('should correctly convert ConversationModel to ConversationEntity', () {
        // Arrange
        final model = ConversationModel(
          id: 'conv-123',
          participants: ['user-1', 'user-2'],
          clientId: 'user-1',
          supplierId: 'user-2',
          clientName: 'John Doe',
          supplierName: 'ABC Photography',
          clientPhoto: 'https://example.com/client.jpg',
          supplierPhoto: 'https://example.com/supplier.jpg',
          lastMessage: 'Hello, how are you?',
          lastMessageAt: testLastMessageAt,
          lastMessageSenderId: 'user-1',
          unreadCount: {
            'user-1': 0,
            'user-2': 3,
          },
          isActive: true,
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
        );

        // Act
        final result = model.toEntity();

        // Assert
        expect(result, isA<ConversationEntity>());
        expect(result.id, 'conv-123');
        expect(result.participants, ['user-1', 'user-2']);
        expect(result.clientId, 'user-1');
        expect(result.supplierId, 'user-2');
        expect(result.clientName, 'John Doe');
        expect(result.supplierName, 'ABC Photography');
        expect(result.clientPhoto, 'https://example.com/client.jpg');
        expect(result.supplierPhoto, 'https://example.com/supplier.jpg');
        expect(result.lastMessage, 'Hello, how are you?');
        expect(result.lastMessageAt, testLastMessageAt);
        expect(result.lastMessageSenderId, 'user-1');
        expect(result.unreadCount['user-1'], 0);
        expect(result.unreadCount['user-2'], 3);
        expect(result.isActive, true);
        expect(result.createdAt, testCreatedAt);
        expect(result.updatedAt, testUpdatedAt);
      });

      test('should preserve all optional fields during conversion', () {
        // Arrange
        final model = ConversationModel(
          id: 'conv-123',
          participants: ['user-1', 'user-2'],
          clientId: 'user-1',
          supplierId: 'user-2',
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
        );

        // Act
        final result = model.toEntity();

        // Assert
        expect(result.clientName, isNull);
        expect(result.supplierName, isNull);
        expect(result.clientPhoto, isNull);
        expect(result.supplierPhoto, isNull);
        expect(result.lastMessage, isNull);
        expect(result.lastMessageAt, isNull);
        expect(result.lastMessageSenderId, isNull);
        expect(result.unreadCount, isEmpty);
      });
    });

    group('fromEntity -', () {
      test('should correctly convert ConversationEntity to ConversationModel', () {
        // Arrange
        final entity = ConversationEntity(
          id: 'conv-123',
          participants: ['user-1', 'user-2'],
          clientId: 'user-1',
          supplierId: 'user-2',
          clientName: 'John Doe',
          supplierName: 'ABC Photography',
          clientPhoto: 'https://example.com/client.jpg',
          supplierPhoto: 'https://example.com/supplier.jpg',
          lastMessage: 'Hello, how are you?',
          lastMessageAt: testLastMessageAt,
          lastMessageSenderId: 'user-1',
          unreadCount: {
            'user-1': 0,
            'user-2': 3,
          },
          isActive: true,
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
        );

        // Act
        final result = ConversationModel.fromEntity(entity);

        // Assert
        expect(result, isA<ConversationModel>());
        expect(result.id, 'conv-123');
        expect(result.participants, ['user-1', 'user-2']);
        expect(result.clientId, 'user-1');
        expect(result.supplierId, 'user-2');
        expect(result.clientName, 'John Doe');
        expect(result.supplierName, 'ABC Photography');
        expect(result.clientPhoto, 'https://example.com/client.jpg');
        expect(result.supplierPhoto, 'https://example.com/supplier.jpg');
        expect(result.lastMessage, 'Hello, how are you?');
        expect(result.lastMessageAt, testLastMessageAt);
        expect(result.lastMessageSenderId, 'user-1');
        expect(result.unreadCount['user-1'], 0);
        expect(result.unreadCount['user-2'], 3);
        expect(result.isActive, true);
        expect(result.createdAt, testCreatedAt);
        expect(result.updatedAt, testUpdatedAt);
      });

      test('should preserve all fields during entity conversion', () {
        // Arrange
        final entity = ConversationEntity(
          id: 'conv-123',
          participants: ['user-1', 'user-2'],
          clientId: 'user-1',
          supplierId: 'user-2',
          isActive: false,
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
        );

        // Act
        final result = ConversationModel.fromEntity(entity);

        // Assert
        expect(result.isActive, false);
        expect(result.unreadCount, isEmpty);
      });
    });

    group('copyWith -', () {
      test('should create a copy with updated fields', () {
        // Arrange
        final original = ConversationModel(
          id: 'conv-123',
          participants: ['user-1', 'user-2'],
          clientId: 'user-1',
          supplierId: 'user-2',
          lastMessage: 'Original message',
          isActive: true,
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
        );

        // Act
        final result = original.copyWith(
          lastMessage: 'Updated message',
          lastMessageAt: testLastMessageAt,
          lastMessageSenderId: 'user-2',
          isActive: false,
        );

        // Assert
        expect(result.lastMessage, 'Updated message');
        expect(result.lastMessageAt, testLastMessageAt);
        expect(result.lastMessageSenderId, 'user-2');
        expect(result.isActive, false);
        // Unchanged fields
        expect(result.id, 'conv-123');
        expect(result.participants, ['user-1', 'user-2']);
        expect(result.clientId, 'user-1');
      });

      test('should create a copy with updated unreadCount', () {
        // Arrange
        final original = ConversationModel(
          id: 'conv-123',
          participants: ['user-1', 'user-2'],
          clientId: 'user-1',
          supplierId: 'user-2',
          unreadCount: {'user-1': 0, 'user-2': 3},
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
        );

        // Act
        final result = original.copyWith(
          unreadCount: {'user-1': 5, 'user-2': 0},
        );

        // Assert
        expect(result.unreadCount['user-1'], 5);
        expect(result.unreadCount['user-2'], 0);
      });
    });
  });
}
