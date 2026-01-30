import 'package:equatable/equatable.dart';

/// Base class for all failures in the application
/// Failures represent errors that can occur in the domain and data layers
abstract class Failure extends Equatable {
  const Failure(this.message, [this.code]);

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

// ==================== GENERAL FAILURES ====================

/// Failure when there's no internet connection
class NetworkFailure extends Failure {
  const NetworkFailure([
    String message = 'Sem conexão com a internet',
    String? code,
  ]) : super(message, code);
}

/// Failure when server returns an error
class ServerFailure extends Failure {
  const ServerFailure([
    String message = 'Erro no servidor',
    String? code,
  ]) : super(message, code);
}

/// Failure when local cache has issues
class CacheFailure extends Failure {
  const CacheFailure([
    String message = 'Erro ao acessar dados locais',
    String? code,
  ]) : super(message, code);
}

/// Failure for validation errors
class ValidationFailure extends Failure {
  const ValidationFailure([
    String message = 'Dados inválidos',
    String? code,
  ]) : super(message, code);
}

/// Failure when requested resource is not found
class NotFoundFailure extends Failure {
  const NotFoundFailure([
    String message = 'Recurso não encontrado',
    String? code,
  ]) : super(message, code);
}

/// Failure when user doesn't have permission
class PermissionFailure extends Failure {
  const PermissionFailure([
    String message = 'Sem permissão para esta operação',
    String? code,
  ]) : super(message, code);
}

// ==================== AUTH FAILURES ====================

/// Failure during authentication operations
class AuthFailure extends Failure {
  const AuthFailure([
    String message = 'Erro de autenticação',
    String? code,
  ]) : super(message, code);
}

/// Failure when user is not authenticated
class UnauthenticatedFailure extends AuthFailure {
  const UnauthenticatedFailure([
    String message = 'Usuário não autenticado',
    String? code,
  ]) : super(message, code);
}

/// Failure when credentials are invalid
class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure([
    String message = 'Credenciais inválidas',
    String? code,
  ]) : super(message, code);
}

/// Failure when user already exists
class UserAlreadyExistsFailure extends AuthFailure {
  const UserAlreadyExistsFailure([
    String message = 'Usuário já existe',
    String? code,
  ]) : super(message, code);
}

/// Failure when OTP verification fails
class OTPVerificationFailure extends AuthFailure {
  const OTPVerificationFailure([
    String message = 'Código de verificação inválido',
    String? code,
  ]) : super(message, code);
}

// ==================== SUPPLIER FAILURES ====================

/// Failure during supplier operations
class SupplierFailure extends Failure {
  const SupplierFailure([
    String message = 'Erro ao processar fornecedor',
    String? code,
  ]) : super(message, code);
}

/// Failure when supplier is not found
class SupplierNotFoundFailure extends SupplierFailure {
  const SupplierNotFoundFailure([
    String message = 'Fornecedor não encontrado',
    String? code,
  ]) : super(message, code);
}

/// Failure when package operations fail
class PackageFailure extends Failure {
  const PackageFailure([
    String message = 'Erro ao processar pacote',
    String? code,
  ]) : super(message, code);
}

// ==================== BOOKING FAILURES ====================

/// Failure during booking operations
class BookingFailure extends Failure {
  const BookingFailure([
    String message = 'Erro ao processar reserva',
    String? code,
  ]) : super(message, code);
}

/// Failure when booking is not found
class BookingNotFoundFailure extends BookingFailure {
  const BookingNotFoundFailure([
    String message = 'Reserva não encontrada',
    String? code,
  ]) : super(message, code);
}

/// Failure when booking conflicts with existing booking
class BookingConflictFailure extends BookingFailure {
  const BookingConflictFailure([
    String message = 'Conflito de horário na reserva',
    String? code,
  ]) : super(message, code);
}

/// Failure when supplier is not available
class SupplierUnavailableFailure extends BookingFailure {
  const SupplierUnavailableFailure([
    String message = 'Fornecedor não disponível nesta data',
    String? code,
  ]) : super(message, code);
}

// ==================== CHAT FAILURES ====================

/// Failure during chat operations
class ChatFailure extends Failure {
  const ChatFailure([
    String message = 'Erro no chat',
    String? code,
  ]) : super(message, code);
}

/// Failure when message fails to send
class MessageSendFailure extends ChatFailure {
  const MessageSendFailure([
    String message = 'Erro ao enviar mensagem',
    String? code,
  ]) : super(message, code);
}

/// Failure when conversation is not found
class ConversationNotFoundFailure extends ChatFailure {
  const ConversationNotFoundFailure([
    String message = 'Conversa não encontrada',
    String? code,
  ]) : super(message, code);
}

// ==================== PAYMENT FAILURES ====================

/// Failure during payment operations
class PaymentFailure extends Failure {
  const PaymentFailure([
    String message = 'Erro no pagamento',
    String? code,
  ]) : super(message, code);
}

/// Failure when payment is declined
class PaymentDeclinedFailure extends PaymentFailure {
  const PaymentDeclinedFailure([
    String message = 'Pagamento recusado',
    String? code,
  ]) : super(message, code);
}

/// Failure when insufficient funds
class InsufficientFundsFailure extends PaymentFailure {
  const InsufficientFundsFailure([
    String message = 'Saldo insuficiente',
    String? code,
  ]) : super(message, code);
}

// ==================== STORAGE FAILURES ====================

/// Failure during file upload/download
class StorageFailure extends Failure {
  const StorageFailure([
    String message = 'Erro ao processar arquivo',
    String? code,
  ]) : super(message, code);
}

/// Failure when file upload fails
class FileUploadFailure extends StorageFailure {
  const FileUploadFailure([
    String message = 'Erro ao enviar arquivo',
    String? code,
  ]) : super(message, code);
}

/// Failure when file is too large
class FileTooLargeFailure extends StorageFailure {
  const FileTooLargeFailure([
    String message = 'Arquivo muito grande',
    String? code,
  ]) : super(message, code);
}
