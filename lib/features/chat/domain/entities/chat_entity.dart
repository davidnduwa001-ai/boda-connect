/// Chat Entity - Export file for conversation entity
///
/// This file provides an alias to the conversation entity for improved
/// naming consistency across the application. In this domain, "chat" and
/// "conversation" refer to the same concept.
///
/// Usage:
/// ```dart
/// import 'package:boda_connect/features/chat/domain/entities/chat_entity.dart';
///
/// // ChatEntity is now an alias for ConversationEntity
/// ChatEntity chat = ...;
/// ```
library chat_entity;

import 'conversation_entity.dart';

export 'conversation_entity.dart' show ConversationEntity;

/// Type alias for improved semantics
///
/// ChatEntity is semantically identical to ConversationEntity.
/// This alias allows developers to use either term based on context:
/// - Use "Chat" when referring to the feature or user-facing concept
/// - Use "Conversation" when referring to the technical implementation
typedef ChatEntity = ConversationEntity;
