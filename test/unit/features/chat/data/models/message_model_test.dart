import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/chat/data/models/message_model.dart';
import 'package:boda_connect/features/chat/domain/entities/message_entity.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late DateTime testTimestamp;
  late DateTime testReadAt;
  late DateTime testValidUntil;
  late DateTime testEventDate;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    testTimestamp = DateTime(2024, 1, 15, 10, 30);
    testReadAt = DateTime(2024, 1, 15, 11, 0);
    testValidUntil = DateTime(2024, 2, 15, 10, 30);
    testEventDate = DateTime(2024, 3, 20, 14, 0);
  });

  group('MessageModel -', () {
    group('fromFirestore -', () {
      test('should correctly parse text message from DocumentSnapshot', () async {
        // Arrange
        final data = {
          'conversationId': 'conv-123',
          'senderId': 'user-1',
          'receiverId': 'user-2',
          'senderName': 'John Doe',
          'type': 'text',
          'text': 'Hello, how are you?',
          'imageUrl': null,
          'fileUrl': null,
          'fileName': null,
          'quoteData': null,
          'bookingReference': null,
          'isRead': false,
          'timestamp': Timestamp.fromDate(testTimestamp),
          'readAt': null,
          'isDeleted': false,
        };

        final doc = await fakeFirestore.collection('messages').add(data);
        final snapshot = await doc.get();

        // Act
        final result = MessageModel.fromFirestore(snapshot);

        // Assert
        expect(result.id, snapshot.id);
        expect(result.conversationId, 'conv-123');
        expect(result.senderId, 'user-1');
        expect(result.receiverId, 'user-2');
        expect(result.senderName, 'John Doe');
        expect(result.type, MessageType.text);
        expect(result.text, 'Hello, how are you?');
        expect(result.imageUrl, isNull);
        expect(result.fileUrl, isNull);
        expect(result.fileName, isNull);
        expect(result.quoteData, isNull);
        expect(result.bookingReference, isNull);
        expect(result.isRead, false);
        expect(result.timestamp, testTimestamp);
        expect(result.readAt, isNull);
        expect(result.isDeleted, false);
      });

      test('should correctly parse image message from DocumentSnapshot', () async {
        // Arrange
        final data = {
          'conversationId': 'conv-123',
          'senderId': 'user-1',
          'receiverId': 'user-2',
          'senderName': 'John Doe',
          'type': 'image',
          'text': 'Check this out!',
          'imageUrl': 'https://example.com/image.jpg',
          'fileUrl': null,
          'fileName': null,
          'quoteData': null,
          'bookingReference': null,
          'isRead': true,
          'timestamp': Timestamp.fromDate(testTimestamp),
          'readAt': Timestamp.fromDate(testReadAt),
          'isDeleted': false,
        };

        final doc = await fakeFirestore.collection('messages').add(data);
        final snapshot = await doc.get();

        // Act
        final result = MessageModel.fromFirestore(snapshot);

        // Assert
        expect(result.type, MessageType.image);
        expect(result.text, 'Check this out!');
        expect(result.imageUrl, 'https://example.com/image.jpg');
        expect(result.isRead, true);
        expect(result.readAt, testReadAt);
      });

      test('should correctly parse file message from DocumentSnapshot', () async {
        // Arrange
        final data = {
          'conversationId': 'conv-123',
          'senderId': 'user-1',
          'receiverId': 'user-2',
          'senderName': 'John Doe',
          'type': 'file',
          'text': 'Here is the document',
          'imageUrl': null,
          'fileUrl': 'https://example.com/document.pdf',
          'fileName': 'contract.pdf',
          'quoteData': null,
          'bookingReference': null,
          'isRead': false,
          'timestamp': Timestamp.fromDate(testTimestamp),
          'readAt': null,
          'isDeleted': false,
        };

        final doc = await fakeFirestore.collection('messages').add(data);
        final snapshot = await doc.get();

        // Act
        final result = MessageModel.fromFirestore(snapshot);

        // Assert
        expect(result.type, MessageType.file);
        expect(result.fileUrl, 'https://example.com/document.pdf');
        expect(result.fileName, 'contract.pdf');
      });

      test('should correctly parse quote message with QuoteData', () async {
        // Arrange
        final data = {
          'conversationId': 'conv-123',
          'senderId': 'user-1',
          'receiverId': 'user-2',
          'senderName': 'Supplier',
          'type': 'quote',
          'text': 'Here is your quote',
          'imageUrl': null,
          'fileUrl': null,
          'fileName': null,
          'quoteData': {
            'packageId': 'pkg-123',
            'packageName': 'Premium Photography',
            'price': 50000,
            'currency': 'AOA',
            'notes': 'Special discount applied',
            'validUntil': Timestamp.fromDate(testValidUntil),
            'status': 'pending',
          },
          'bookingReference': null,
          'isRead': false,
          'timestamp': Timestamp.fromDate(testTimestamp),
          'readAt': null,
          'isDeleted': false,
        };

        final doc = await fakeFirestore.collection('messages').add(data);
        final snapshot = await doc.get();

        // Act
        final result = MessageModel.fromFirestore(snapshot);

        // Assert
        expect(result.type, MessageType.quote);
        expect(result.quoteData, isNotNull);
        expect(result.quoteData!.packageId, 'pkg-123');
        expect(result.quoteData!.packageName, 'Premium Photography');
        expect(result.quoteData!.price, 50000);
        expect(result.quoteData!.currency, 'AOA');
        expect(result.quoteData!.notes, 'Special discount applied');
        expect(result.quoteData!.validUntil, testValidUntil);
        expect(result.quoteData!.status, 'pending');
      });

      test('should correctly parse booking message with BookingReference', () async {
        // Arrange
        final data = {
          'conversationId': 'conv-123',
          'senderId': 'user-1',
          'receiverId': 'user-2',
          'senderName': 'Client',
          'type': 'booking',
          'text': 'Booking confirmed',
          'imageUrl': null,
          'fileUrl': null,
          'fileName': null,
          'quoteData': null,
          'bookingReference': {
            'bookingId': 'booking-456',
            'eventName': 'Wedding Photography',
            'eventDate': Timestamp.fromDate(testEventDate),
            'status': 'confirmed',
          },
          'isRead': false,
          'timestamp': Timestamp.fromDate(testTimestamp),
          'readAt': null,
          'isDeleted': false,
        };

        final doc = await fakeFirestore.collection('messages').add(data);
        final snapshot = await doc.get();

        // Act
        final result = MessageModel.fromFirestore(snapshot);

        // Assert
        expect(result.type, MessageType.booking);
        expect(result.bookingReference, isNotNull);
        expect(result.bookingReference!.bookingId, 'booking-456');
        expect(result.bookingReference!.eventName, 'Wedding Photography');
        expect(result.bookingReference!.eventDate, testEventDate);
        expect(result.bookingReference!.status, 'confirmed');
      });

      test('should correctly parse system message', () async {
        // Arrange
        final data = {
          'conversationId': 'conv-123',
          'senderId': 'system',
          'receiverId': 'user-2',
          'senderName': null,
          'type': 'system',
          'text': 'User joined the conversation',
          'imageUrl': null,
          'fileUrl': null,
          'fileName': null,
          'quoteData': null,
          'bookingReference': null,
          'isRead': true,
          'timestamp': Timestamp.fromDate(testTimestamp),
          'readAt': null,
          'isDeleted': false,
        };

        final doc = await fakeFirestore.collection('messages').add(data);
        final snapshot = await doc.get();

        // Act
        final result = MessageModel.fromFirestore(snapshot);

        // Assert
        expect(result.type, MessageType.system);
        expect(result.text, 'User joined the conversation');
        expect(result.senderName, isNull);
      });

      test('should handle null optional fields with default values', () async {
        // Arrange - minimal required fields
        final data = {
          'conversationId': 'conv-123',
          'senderId': 'user-1',
          'receiverId': 'user-2',
          'type': 'text',
          'timestamp': Timestamp.fromDate(testTimestamp),
        };

        final doc = await fakeFirestore.collection('messages').add(data);
        final snapshot = await doc.get();

        // Act
        final result = MessageModel.fromFirestore(snapshot);

        // Assert
        expect(result.senderName, isNull);
        expect(result.text, isNull);
        expect(result.imageUrl, isNull);
        expect(result.fileUrl, isNull);
        expect(result.fileName, isNull);
        expect(result.quoteData, isNull);
        expect(result.bookingReference, isNull);
        expect(result.isRead, false); // default value
        expect(result.readAt, isNull);
        expect(result.isDeleted, false); // default value
      });

      test('should handle unknown message type and default to text', () async {
        // Arrange
        final data = {
          'conversationId': 'conv-123',
          'senderId': 'user-1',
          'receiverId': 'user-2',
          'type': 'unknown_type',
          'timestamp': Timestamp.fromDate(testTimestamp),
        };

        final doc = await fakeFirestore.collection('messages').add(data);
        final snapshot = await doc.get();

        // Act
        final result = MessageModel.fromFirestore(snapshot);

        // Assert
        expect(result.type, MessageType.text);
      });
    });

    group('toFirestore -', () {
      test('should correctly convert text message to Firestore map', () {
        // Arrange
        final message = MessageModel(
          id: 'msg-123',
          conversationId: 'conv-123',
          senderId: 'user-1',
          receiverId: 'user-2',
          senderName: 'John Doe',
          type: MessageType.text,
          text: 'Hello, how are you?',
          isRead: false,
          timestamp: testTimestamp,
        );

        // Act
        final result = message.toFirestore();

        // Assert
        expect(result['conversationId'], 'conv-123');
        expect(result['senderId'], 'user-1');
        expect(result['receiverId'], 'user-2');
        expect(result['senderName'], 'John Doe');
        expect(result['type'], 'text');
        expect(result['text'], 'Hello, how are you?');
        expect(result['imageUrl'], isNull);
        expect(result['fileUrl'], isNull);
        expect(result['fileName'], isNull);
        expect(result['quoteData'], isNull);
        expect(result['bookingReference'], isNull);
        expect(result['isRead'], false);
        expect(result['timestamp'], Timestamp.fromDate(testTimestamp));
        expect(result['readAt'], isNull);
        expect(result['isDeleted'], false);
      });

      test('should correctly convert image message to Firestore map', () {
        // Arrange
        final message = MessageModel(
          id: 'msg-123',
          conversationId: 'conv-123',
          senderId: 'user-1',
          receiverId: 'user-2',
          type: MessageType.image,
          imageUrl: 'https://example.com/image.jpg',
          text: 'Check this out!',
          isRead: true,
          timestamp: testTimestamp,
          readAt: testReadAt,
        );

        // Act
        final result = message.toFirestore();

        // Assert
        expect(result['type'], 'image');
        expect(result['imageUrl'], 'https://example.com/image.jpg');
        expect(result['isRead'], true);
        expect(result['readAt'], Timestamp.fromDate(testReadAt));
      });

      test('should correctly convert file message to Firestore map', () {
        // Arrange
        final message = MessageModel(
          id: 'msg-123',
          conversationId: 'conv-123',
          senderId: 'user-1',
          receiverId: 'user-2',
          type: MessageType.file,
          fileUrl: 'https://example.com/document.pdf',
          fileName: 'contract.pdf',
          isRead: false,
          timestamp: testTimestamp,
        );

        // Act
        final result = message.toFirestore();

        // Assert
        expect(result['type'], 'file');
        expect(result['fileUrl'], 'https://example.com/document.pdf');
        expect(result['fileName'], 'contract.pdf');
      });

      test('should correctly convert quote message with QuoteData to Firestore map', () {
        // Arrange
        final quoteData = QuoteDataEntity(
          packageId: 'pkg-123',
          packageName: 'Premium Photography',
          price: 50000,
          currency: 'AOA',
          notes: 'Special discount applied',
          validUntil: testValidUntil,
          status: 'pending',
        );

        final message = MessageModel(
          id: 'msg-123',
          conversationId: 'conv-123',
          senderId: 'user-1',
          receiverId: 'user-2',
          type: MessageType.quote,
          quoteData: quoteData,
          isRead: false,
          timestamp: testTimestamp,
        );

        // Act
        final result = message.toFirestore();

        // Assert
        expect(result['type'], 'quote');
        expect(result['quoteData'], isNotNull);
        final quoteMap = result['quoteData'] as DataMap;
        expect(quoteMap['packageId'], 'pkg-123');
        expect(quoteMap['packageName'], 'Premium Photography');
        expect(quoteMap['price'], 50000);
        expect(quoteMap['currency'], 'AOA');
        expect(quoteMap['notes'], 'Special discount applied');
        expect(quoteMap['validUntil'], Timestamp.fromDate(testValidUntil));
        expect(quoteMap['status'], 'pending');
      });

      test('should correctly convert booking message with BookingReference to Firestore map', () {
        // Arrange
        final bookingReference = BookingReferenceEntity(
          bookingId: 'booking-456',
          eventName: 'Wedding Photography',
          eventDate: testEventDate,
          status: 'confirmed',
        );

        final message = MessageModel(
          id: 'msg-123',
          conversationId: 'conv-123',
          senderId: 'user-1',
          receiverId: 'user-2',
          type: MessageType.booking,
          bookingReference: bookingReference,
          isRead: false,
          timestamp: testTimestamp,
        );

        // Act
        final result = message.toFirestore();

        // Assert
        expect(result['type'], 'booking');
        expect(result['bookingReference'], isNotNull);
        final bookingMap = result['bookingReference'] as DataMap;
        expect(bookingMap['bookingId'], 'booking-456');
        expect(bookingMap['eventName'], 'Wedding Photography');
        expect(bookingMap['eventDate'], Timestamp.fromDate(testEventDate));
        expect(bookingMap['status'], 'confirmed');
      });
    });

    group('toEntity -', () {
      test('should correctly convert MessageModel to MessageEntity', () {
        // Arrange
        final model = MessageModel(
          id: 'msg-123',
          conversationId: 'conv-123',
          senderId: 'user-1',
          receiverId: 'user-2',
          senderName: 'John Doe',
          type: MessageType.text,
          text: 'Hello, how are you?',
          isRead: false,
          timestamp: testTimestamp,
        );

        // Act
        final result = model.toEntity();

        // Assert
        expect(result, isA<MessageEntity>());
        expect(result.id, 'msg-123');
        expect(result.conversationId, 'conv-123');
        expect(result.senderId, 'user-1');
        expect(result.receiverId, 'user-2');
        expect(result.senderName, 'John Doe');
        expect(result.type, MessageType.text);
        expect(result.text, 'Hello, how are you?');
        expect(result.isRead, false);
        expect(result.timestamp, testTimestamp);
      });

      test('should preserve all nested entities during conversion', () {
        // Arrange
        final quoteData = QuoteDataEntity(
          packageId: 'pkg-123',
          packageName: 'Premium Photography',
          price: 50000,
        );

        final bookingReference = BookingReferenceEntity(
          bookingId: 'booking-456',
          eventName: 'Wedding Photography',
          eventDate: testEventDate,
          status: 'confirmed',
        );

        final model = MessageModel(
          id: 'msg-123',
          conversationId: 'conv-123',
          senderId: 'user-1',
          receiverId: 'user-2',
          type: MessageType.quote,
          quoteData: quoteData,
          bookingReference: bookingReference,
          isRead: true,
          timestamp: testTimestamp,
          readAt: testReadAt,
        );

        // Act
        final result = model.toEntity();

        // Assert
        expect(result.quoteData, quoteData);
        expect(result.bookingReference, bookingReference);
        expect(result.readAt, testReadAt);
      });
    });

    group('fromEntity -', () {
      test('should correctly convert MessageEntity to MessageModel', () {
        // Arrange
        final entity = MessageEntity(
          id: 'msg-123',
          conversationId: 'conv-123',
          senderId: 'user-1',
          receiverId: 'user-2',
          senderName: 'John Doe',
          type: MessageType.text,
          text: 'Hello, how are you?',
          isRead: false,
          timestamp: testTimestamp,
        );

        // Act
        final result = MessageModel.fromEntity(entity);

        // Assert
        expect(result, isA<MessageModel>());
        expect(result.id, 'msg-123');
        expect(result.conversationId, 'conv-123');
        expect(result.senderId, 'user-1');
        expect(result.receiverId, 'user-2');
        expect(result.senderName, 'John Doe');
        expect(result.type, MessageType.text);
        expect(result.text, 'Hello, how are you?');
        expect(result.isRead, false);
        expect(result.timestamp, testTimestamp);
      });

      test('should preserve all fields during entity conversion', () {
        // Arrange
        final entity = MessageEntity(
          id: 'msg-123',
          conversationId: 'conv-123',
          senderId: 'user-1',
          receiverId: 'user-2',
          type: MessageType.image,
          imageUrl: 'https://example.com/image.jpg',
          isRead: true,
          timestamp: testTimestamp,
          readAt: testReadAt,
          isDeleted: true,
        );

        // Act
        final result = MessageModel.fromEntity(entity);

        // Assert
        expect(result.imageUrl, 'https://example.com/image.jpg');
        expect(result.isRead, true);
        expect(result.readAt, testReadAt);
        expect(result.isDeleted, true);
      });
    });

    group('copyWith -', () {
      test('should create a copy with updated fields', () {
        // Arrange
        final original = MessageModel(
          id: 'msg-123',
          conversationId: 'conv-123',
          senderId: 'user-1',
          receiverId: 'user-2',
          type: MessageType.text,
          text: 'Original message',
          isRead: false,
          timestamp: testTimestamp,
        );

        // Act
        final result = original.copyWith(
          text: 'Updated message',
          isRead: true,
          readAt: testReadAt,
        );

        // Assert
        expect(result.text, 'Updated message');
        expect(result.isRead, true);
        expect(result.readAt, testReadAt);
        // Unchanged fields
        expect(result.id, 'msg-123');
        expect(result.conversationId, 'conv-123');
        expect(result.senderId, 'user-1');
      });
    });
  });

  group('QuoteDataModel -', () {
    group('fromMap -', () {
      test('should correctly parse QuoteData from map', () {
        // Arrange
        final map = {
          'packageId': 'pkg-123',
          'packageName': 'Premium Photography',
          'price': 50000,
          'currency': 'AOA',
          'notes': 'Special discount',
          'validUntil': Timestamp.fromDate(testValidUntil),
          'status': 'pending',
        };

        // Act
        final result = QuoteDataModel.fromMap(map);

        // Assert
        expect(result.packageId, 'pkg-123');
        expect(result.packageName, 'Premium Photography');
        expect(result.price, 50000);
        expect(result.currency, 'AOA');
        expect(result.notes, 'Special discount');
        expect(result.validUntil, testValidUntil);
        expect(result.status, 'pending');
      });

      test('should use default values for optional fields', () {
        // Arrange - minimal required fields
        final map = {
          'packageId': 'pkg-123',
          'packageName': 'Premium Photography',
          'price': 50000,
        };

        // Act
        final result = QuoteDataModel.fromMap(map);

        // Assert
        expect(result.currency, 'AOA'); // default
        expect(result.notes, isNull);
        expect(result.validUntil, isNull);
        expect(result.status, 'pending'); // default
      });
    });

    group('toMap -', () {
      test('should correctly convert QuoteData to map', () {
        // Arrange
        final quoteData = QuoteDataModel(
          packageId: 'pkg-123',
          packageName: 'Premium Photography',
          price: 50000,
          currency: 'AOA',
          notes: 'Special discount',
          validUntil: testValidUntil,
          status: 'pending',
        );

        // Act
        final result = quoteData.toMap();

        // Assert
        expect(result['packageId'], 'pkg-123');
        expect(result['packageName'], 'Premium Photography');
        expect(result['price'], 50000);
        expect(result['currency'], 'AOA');
        expect(result['notes'], 'Special discount');
        expect(result['validUntil'], Timestamp.fromDate(testValidUntil));
        expect(result['status'], 'pending');
      });

      test('should handle null optional fields', () {
        // Arrange
        final quoteData = QuoteDataModel(
          packageId: 'pkg-123',
          packageName: 'Premium Photography',
          price: 50000,
        );

        // Act
        final result = quoteData.toMap();

        // Assert
        expect(result['notes'], isNull);
        expect(result['validUntil'], isNull);
      });
    });

    group('toEntity -', () {
      test('should correctly convert to QuoteDataEntity', () {
        // Arrange
        final model = QuoteDataModel(
          packageId: 'pkg-123',
          packageName: 'Premium Photography',
          price: 50000,
        );

        // Act
        final result = model.toEntity();

        // Assert
        expect(result, isA<QuoteDataEntity>());
        expect(result.packageId, 'pkg-123');
        expect(result.packageName, 'Premium Photography');
        expect(result.price, 50000);
      });
    });

    group('fromEntity -', () {
      test('should correctly convert from QuoteDataEntity', () {
        // Arrange
        final entity = QuoteDataEntity(
          packageId: 'pkg-123',
          packageName: 'Premium Photography',
          price: 50000,
        );

        // Act
        final result = QuoteDataModel.fromEntity(entity);

        // Assert
        expect(result, isA<QuoteDataModel>());
        expect(result.packageId, 'pkg-123');
        expect(result.packageName, 'Premium Photography');
        expect(result.price, 50000);
      });
    });
  });

  group('BookingReferenceModel -', () {
    group('fromMap -', () {
      test('should correctly parse BookingReference from map', () {
        // Arrange
        final map = {
          'bookingId': 'booking-456',
          'eventName': 'Wedding Photography',
          'eventDate': Timestamp.fromDate(testEventDate),
          'status': 'confirmed',
        };

        // Act
        final result = BookingReferenceModel.fromMap(map);

        // Assert
        expect(result.bookingId, 'booking-456');
        expect(result.eventName, 'Wedding Photography');
        expect(result.eventDate, testEventDate);
        expect(result.status, 'confirmed');
      });
    });

    group('toMap -', () {
      test('should correctly convert BookingReference to map', () {
        // Arrange
        final bookingReference = BookingReferenceModel(
          bookingId: 'booking-456',
          eventName: 'Wedding Photography',
          eventDate: testEventDate,
          status: 'confirmed',
        );

        // Act
        final result = bookingReference.toMap();

        // Assert
        expect(result['bookingId'], 'booking-456');
        expect(result['eventName'], 'Wedding Photography');
        expect(result['eventDate'], Timestamp.fromDate(testEventDate));
        expect(result['status'], 'confirmed');
      });
    });

    group('toEntity -', () {
      test('should correctly convert to BookingReferenceEntity', () {
        // Arrange
        final model = BookingReferenceModel(
          bookingId: 'booking-456',
          eventName: 'Wedding Photography',
          eventDate: testEventDate,
          status: 'confirmed',
        );

        // Act
        final result = model.toEntity();

        // Assert
        expect(result, isA<BookingReferenceEntity>());
        expect(result.bookingId, 'booking-456');
        expect(result.eventName, 'Wedding Photography');
        expect(result.eventDate, testEventDate);
        expect(result.status, 'confirmed');
      });
    });

    group('fromEntity -', () {
      test('should correctly convert from BookingReferenceEntity', () {
        // Arrange
        final entity = BookingReferenceEntity(
          bookingId: 'booking-456',
          eventName: 'Wedding Photography',
          eventDate: testEventDate,
          status: 'confirmed',
        );

        // Act
        final result = BookingReferenceModel.fromEntity(entity);

        // Assert
        expect(result, isA<BookingReferenceModel>());
        expect(result.bookingId, 'booking-456');
        expect(result.eventName, 'Wedding Photography');
        expect(result.eventDate, testEventDate);
        expect(result.status, 'confirmed');
      });
    });
  });
}
