# Chat Feature - Domain Layer

This directory contains the domain layer for the Chat feature, following Clean Architecture principles. The domain layer is completely independent of any framework, UI, or data source implementation.

## Architecture Overview

The domain layer follows these Clean Architecture principles:

- **Pure Dart**: No dependencies on Flutter, Firebase, or any external frameworks
- **Business Logic**: Contains the core business rules and entities
- **Framework Independent**: Can be reused across different platforms and frameworks
- **Testable**: Easy to unit test without mocking external dependencies

## Directory Structure

```
domain/
├── entities/          # Pure business objects
├── repositories/      # Abstract repository interfaces
├── usecases/         # Application-specific business rules
└── README.md         # This file
```

## Entities

Entities are pure business objects that encapsulate the most general and high-level business rules.

### ConversationEntity / ChatEntity

**Location**: `entities/conversation_entity.dart` and `entities/chat_entity.dart`

Represents a chat conversation between a client and a supplier.

**Key Properties:**
- `id`: Unique identifier for the conversation
- `participants`: List of user IDs participating in the conversation
- `clientId` & `supplierId`: Specific role-based participant IDs
- `clientName` & `supplierName`: Display names for participants
- `clientPhoto` & `supplierPhoto`: Profile photo URLs
- `lastMessage`: Preview of the most recent message
- `lastMessageAt`: Timestamp of the last message
- `lastMessageSenderId`: Who sent the last message
- `unreadCount`: Map of unread counts per user
- `isActive`: Whether the conversation is active
- `createdAt` & `updatedAt`: Timestamps

**Helper Methods:**
- `getUnreadCountFor(userId)`: Get unread count for a specific user
- `getOtherParticipantId(currentUserId)`: Get the other participant's ID
- `getOtherParticipantName(currentUserId)`: Get the other participant's name
- `getOtherParticipantPhoto(currentUserId)`: Get the other participant's photo

**Note**: `ChatEntity` is a type alias for `ConversationEntity`, allowing you to use either term based on your preference.

### MessageEntity

**Location**: `entities/message_entity.dart`

Represents a message within a conversation.

**Key Properties:**
- `id`: Unique identifier for the message
- `conversationId`: The conversation this message belongs to
- `senderId` & `receiverId`: Sender and receiver IDs
- `senderName`: Display name of the sender
- `type`: Type of message (text, image, file, quote, booking, system)
- `text`: Text content of the message
- `imageUrl`: URL for image messages
- `fileUrl` & `fileName`: File attachment details
- `quoteData`: Structured quote/proposal data
- `bookingReference`: Reference to a booking
- `isRead`: Whether the message has been read
- `timestamp`: When the message was sent
- `readAt`: When the message was read
- `isDeleted`: Soft delete flag

### MessageType

**Location**: `entities/message_type.dart`

Enum defining all supported message types.

**Types:**
- `text`: Plain text messages
- `image`: Image attachments
- `file`: File attachments (PDFs, documents, etc.)
- `quote`: Pricing proposals from suppliers
- `booking`: References to bookings
- `system`: System-generated messages (cannot be sent by users)

**Extension Methods:**
- `displayName`: Human-readable type name
- `requiresMedia`: True for image and file types
- `requiresStructuredData`: True for quote and booking types
- `canBeSentByUser`: False only for system messages

### QuoteDataEntity

**Location**: `entities/message_entity.dart` (embedded)

Represents a pricing proposal attached to a quote message.

**Key Properties:**
- `packageId`: ID of the package being quoted
- `packageName`: Name of the package
- `price`: Price in smallest currency unit
- `currency`: Currency code (default: 'AOA')
- `notes`: Optional terms and conditions
- `validUntil`: Expiration date for the quote
- `status`: Quote status (pending, accepted, rejected)

### BookingReferenceEntity

**Location**: `entities/message_entity.dart` (embedded)

Represents a reference to a booking in a message.

**Key Properties:**
- `bookingId`: ID of the referenced booking
- `eventName`: Name of the event
- `eventDate`: Date of the event
- `status`: Current booking status

## Repository

### ChatRepository

**Location**: `repositories/chat_repository.dart`

Abstract repository interface defining all chat operations. The data layer must implement this interface.

**Conversation Operations:**
- `getConversations(userId)`: Stream of conversations for a user
- `getConversation(conversationId)`: Get a specific conversation
- `createConversation(...)`: Create a new conversation
- `getOrCreateConversation(...)`: Get existing or create new conversation
- `deleteConversation(conversationId)`: Delete a conversation

**Message Operations:**
- `getMessages(conversationId)`: Stream of messages in a conversation
- `sendMessage(...)`: Send a text message
- `sendImageMessage(...)`: Send an image message
- `sendFileMessage(...)`: Send a file message
- `sendQuoteMessage(...)`: Send a quote/proposal
- `sendBookingMessage(...)`: Send a booking reference
- `markMessageAsRead(...)`: Mark a specific message as read
- `markConversationAsRead(...)`: Mark all messages in a conversation as read
- `deleteMessage(...)`: Delete a message (soft delete)

**Utility Operations:**
- `getUnreadCount(userId)`: Get total unread count for a user
- `getConversationUnreadCount(...)`: Get unread count for a specific conversation

## Use Cases

Use cases encapsulate application-specific business rules. Each use case performs a single action.

### CreateConversation

**Location**: `usecases/create_conversation.dart`

Creates a new conversation between a client and supplier, or retrieves an existing one.

**Usage:**
```dart
final createConversation = CreateConversation(repository);

final result = await createConversation(
  CreateConversationParams(
    clientId: 'client_123',
    supplierId: 'supplier_456',
    clientName: 'John Doe',
    supplierName: 'Jane Photography',
    getOrCreate: true, // Returns existing if found
  ),
);
```

### GetConversations / GetChats

**Location**: `usecases/get_conversations.dart` and `usecases/get_chats.dart`

Retrieves all conversations for a user with real-time updates.

**Usage:**
```dart
final getChats = GetChats(repository);

final stream = getChats('user_123');

stream.listen((result) {
  result.fold(
    (failure) => print('Error: ${failure.message}'),
    (conversations) => print('Loaded ${conversations.length} chats'),
  );
});
```

**Note**: `GetChats` is an alias for `GetConversations`.

### GetMessages

**Location**: `usecases/get_messages.dart`

Retrieves all messages in a conversation with real-time updates.

**Usage:**
```dart
final getMessages = GetMessages(repository);

final stream = getMessages('conversation_123');

stream.listen((result) {
  result.fold(
    (failure) => print('Error: ${failure.message}'),
    (messages) => print('Loaded ${messages.length} messages'),
  );
});
```

### SendMessage

**Location**: `usecases/send_message.dart`

Sends a message in a conversation. Supports all message types.

**Usage:**
```dart
final sendMessage = SendMessage(repository);

// Send text message
final result = await sendMessage(
  SendMessageParams.text(
    conversationId: 'conv_123',
    senderId: 'user_123',
    receiverId: 'user_456',
    text: 'Hello, how are you?',
    senderName: 'John',
  ),
);

// Send image message
final imageResult = await sendMessage(
  SendMessageParams.image(
    conversationId: 'conv_123',
    senderId: 'user_123',
    receiverId: 'user_456',
    imageUrl: 'https://example.com/image.jpg',
    text: 'Check out this photo!',
    senderName: 'John',
  ),
);

// Send quote message
final quoteResult = await sendMessage(
  SendMessageParams.quote(
    conversationId: 'conv_123',
    senderId: 'supplier_456',
    receiverId: 'client_123',
    quoteData: QuoteDataEntity(
      packageId: 'pkg_789',
      packageName: 'Premium Package',
      price: 150000,
      currency: 'AOA',
      notes: 'Includes photography and editing',
      validUntil: DateTime.now().add(Duration(days: 30)),
    ),
    text: 'Here is my proposal for your event',
    senderName: 'Jane Photography',
  ),
);
```

### SendProposal

**Location**: `usecases/send_proposal.dart`

Specialized use case for suppliers to send booking proposals (quotes) to clients. This is a convenience wrapper around `SendMessage` with a business-focused interface.

**Usage:**
```dart
final sendProposal = SendProposal(repository);

final result = await sendProposal(
  SendProposalParams(
    conversationId: 'conv_123',
    supplierId: 'supplier_456',
    clientId: 'client_789',
    packageId: 'pkg_abc',
    packageName: 'Premium Wedding Package',
    price: 150000,
    currency: 'AOA',
    notes: 'This package includes photography, videography, and editing.',
    message: 'I would love to work with you on your special day!',
    validUntil: DateTime.now().add(Duration(days: 30)),
    supplierName: 'João Photography',
  ),
);

result.fold(
  (failure) => print('Failed to send proposal: ${failure.message}'),
  (message) => print('Proposal sent successfully!'),
);
```

### MarkAsRead

**Location**: `usecases/mark_as_read.dart`

Marks messages as read in a conversation.

**Usage:**
```dart
final markAsRead = MarkAsRead(repository);

// Mark a specific message as read
await markAsRead(
  MarkAsReadParams.single(
    conversationId: 'conv_123',
    messageId: 'msg_456',
    userId: 'user_123',
  ),
);

// Mark all messages in a conversation as read
await markAsRead(
  MarkAsReadParams.all(
    conversationId: 'conv_123',
    userId: 'user_123',
  ),
);
```

### DeleteMessage

**Location**: `usecases/delete_message.dart`

Deletes (soft delete) a message from a conversation.

**Usage:**
```dart
final deleteMessage = DeleteMessage(repository);

final result = await deleteMessage(
  DeleteMessageParams(
    conversationId: 'conv_123',
    messageId: 'msg_456',
  ),
);
```

## Type Definitions

The domain layer uses these common type definitions from `core/utils/typedefs.dart`:

- `ResultFuture<T>`: `Future<Either<Failure, T>>` - Async operation that can fail
- `ResultFutureVoid`: `Future<Either<Failure, void>>` - Async void operation that can fail
- `DataMap`: `Map<String, dynamic>` - JSON data structure

## Error Handling

All operations return `Either<Failure, T>` using the `dartz` package:

- **Left (Failure)**: Operation failed - contains error information
- **Right (Success)**: Operation succeeded - contains the result

**Example:**
```dart
final result = await sendMessage(params);

result.fold(
  (failure) {
    // Handle error
    print('Error: ${failure.message}');
    if (failure is ServerFailure) {
      // Handle server error
    } else if (failure is NetworkFailure) {
      // Handle network error
    }
  },
  (message) {
    // Handle success
    print('Message sent: ${message.id}');
  },
);
```

## Streams vs Futures

- **Streams**: Used for operations that need real-time updates (conversations, messages)
- **Futures**: Used for one-time operations (sending messages, creating conversations)

**Stream Example:**
```dart
final stream = getMessages('conv_123');
final subscription = stream.listen((result) {
  result.fold(
    (failure) => handleError(failure),
    (messages) => updateUI(messages),
  );
});

// Don't forget to cancel when done
subscription.cancel();
```

## Testing

The domain layer is designed to be easily testable:

```dart
// Mock the repository
class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late MockChatRepository mockRepository;
  late SendMessage useCase;

  setUp(() {
    mockRepository = MockChatRepository();
    useCase = SendMessage(mockRepository);
  });

  test('should send text message successfully', () async {
    // Arrange
    final params = SendMessageParams.text(
      conversationId: 'conv_123',
      senderId: 'user_123',
      receiverId: 'user_456',
      text: 'Hello',
    );

    final expectedMessage = MessageEntity(/* ... */);

    when(() => mockRepository.sendMessage(
      conversationId: any(named: 'conversationId'),
      senderId: any(named: 'senderId'),
      receiverId: any(named: 'receiverId'),
      text: any(named: 'text'),
    )).thenAnswer((_) async => Right(expectedMessage));

    // Act
    final result = await useCase(params);

    // Assert
    expect(result, Right(expectedMessage));
    verify(() => mockRepository.sendMessage(
      conversationId: 'conv_123',
      senderId: 'user_123',
      receiverId: 'user_456',
      text: 'Hello',
    )).called(1);
  });
}
```

## Integration with Other Layers

### Data Layer

The data layer implements the `ChatRepository` interface:

```
lib/features/chat/data/
├── models/              # Data transfer objects (DTOs)
├── datasources/         # Firebase, API, or local data sources
└── repositories/        # Repository implementations
```

### Presentation Layer

The presentation layer uses the domain layer through dependency injection:

```
lib/features/chat/presentation/
├── providers/           # Riverpod providers
├── screens/            # UI screens
└── widgets/            # Reusable widgets
```

**Example Provider:**
```dart
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(
    remoteDataSource: ref.watch(chatRemoteDataSourceProvider),
  );
});

final sendMessageProvider = Provider<SendMessage>((ref) {
  return SendMessage(ref.watch(chatRepositoryProvider));
});

final getChatsProvider = Provider<GetChats>((ref) {
  return GetChats(ref.watch(chatRepositoryProvider));
});
```

## Best Practices

1. **Keep entities pure**: No external dependencies, only business logic
2. **One use case, one responsibility**: Each use case should do one thing
3. **Use value objects**: Leverage `Equatable` for value equality
4. **Immutability**: All entities should be immutable with `copyWith` methods
5. **Type safety**: Use strong typing and enums instead of strings
6. **Documentation**: Document all public APIs with clear examples
7. **Error handling**: Always use `Either<Failure, T>` for error handling

## Future Enhancements

Potential future additions to the domain layer:

- **Message reactions**: Support for emoji reactions on messages
- **Message threading**: Reply to specific messages
- **Typing indicators**: Real-time typing status
- **Message search**: Search within conversations
- **Message forwarding**: Forward messages to other conversations
- **Voice messages**: Support for audio messages
- **Video messages**: Support for video messages
- **Read receipts**: More detailed read status tracking
- **Message editing**: Edit sent messages
- **Pinned messages**: Pin important messages in conversations

## Questions or Issues?

For questions about the domain layer architecture or to report issues, please contact the development team or create an issue in the project repository.

---

**Last Updated**: 2026-01-21
**Version**: 1.0.0
**Maintainer**: Development Team
