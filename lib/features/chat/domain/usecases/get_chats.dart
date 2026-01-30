/// Get Chats Use Case - Export file for get conversations use case
///
/// This file provides an alias to the GetConversations use case for improved
/// naming consistency across the application. "GetChats" and "GetConversations"
/// refer to the same operation.
///
/// Usage:
/// ```dart
/// import 'package:boda_connect/features/chat/domain/usecases/get_chats.dart';
///
/// // GetChats is now an alias for GetConversations
/// final getChats = GetChats(repository);
/// final chatsStream = getChats(userId);
/// ```
library get_chats;

import 'get_conversations.dart';

export 'get_conversations.dart' show GetConversations;

/// Type alias for improved semantics
///
/// GetChats is semantically identical to GetConversations.
/// This alias allows developers to use either term based on context:
/// - Use "GetChats" when referring to the feature from a user perspective
/// - Use "GetConversations" when referring to the technical implementation
typedef GetChats = GetConversations;
