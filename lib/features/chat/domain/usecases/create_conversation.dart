import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/chat/domain/entities/conversation_entity.dart';
import 'package:boda_connect/features/chat/domain/repositories/chat_repository.dart';
import 'package:equatable/equatable.dart';

/// UseCase to create a new conversation
class CreateConversation {
  const CreateConversation(this._repository);

  final ChatRepository _repository;

  /// Create a new conversation or get existing one
  /// If getOrCreate is true, will return existing conversation if found
  ResultFuture<ConversationEntity> call(CreateConversationParams params) {
    if (params.getOrCreate) {
      return _repository.getOrCreateConversation(
        clientId: params.clientId,
        supplierId: params.supplierId,
        clientName: params.clientName,
        supplierName: params.supplierName,
        clientPhoto: params.clientPhoto,
        supplierPhoto: params.supplierPhoto,
        supplierAuthUid: params.supplierAuthUid,
      );
    } else {
      return _repository.createConversation(
        clientId: params.clientId,
        supplierId: params.supplierId,
        clientName: params.clientName,
        supplierName: params.supplierName,
        clientPhoto: params.clientPhoto,
        supplierPhoto: params.supplierPhoto,
      );
    }
  }
}

/// Parameters for creating a conversation
class CreateConversationParams extends Equatable {
  final String clientId;
  final String supplierId;
  final String? clientName;
  final String? supplierName;
  final String? clientPhoto;
  final String? supplierPhoto;
  final String? supplierAuthUid;
  final bool getOrCreate;

  const CreateConversationParams({
    required this.clientId,
    required this.supplierId,
    this.clientName,
    this.supplierName,
    this.clientPhoto,
    this.supplierPhoto,
    this.supplierAuthUid,
    this.getOrCreate = true,
  });

  @override
  List<Object?> get props => [
        clientId,
        supplierId,
        clientName,
        supplierName,
        clientPhoto,
        supplierPhoto,
        supplierAuthUid,
        getOrCreate,
      ];
}
