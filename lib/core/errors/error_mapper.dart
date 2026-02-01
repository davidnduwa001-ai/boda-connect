import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Maps Cloud Function errors to user-friendly messages
///
/// This provides consistent, translated error messages for all
/// Cloud Function error codes without leaking internal details.
class ErrorMapper {
  /// Map a FirebaseFunctionsException to a user-friendly message
  static String mapFunctionsError(FirebaseFunctionsException error) {
    // Check if we have a custom message from the server
    final serverMessage = error.message;
    if (serverMessage != null && serverMessage.isNotEmpty) {
      // Use server-provided message if it looks user-friendly
      // (server already localizes messages in Portuguese)
      if (!_isInternalError(serverMessage)) {
        return serverMessage;
      }
    }

    // Map based on error code
    return _mapErrorCode(error.code);
  }

  /// Map generic exceptions to user-friendly messages
  static String mapGenericError(Object error) {
    if (error is FirebaseFunctionsException) {
      return mapFunctionsError(error);
    }

    // Check for Firebase App Check errors
    if (_isAppCheckError(error)) {
      return 'Erro de verificacao de seguranca. Reinicie o aplicativo.';
    }

    // Log the actual error for debugging
    debugPrint('Unmapped error: $error');

    // Return generic user-friendly message
    return 'Ocorreu um erro. Tente novamente.';
  }

  /// Check if error is related to Firebase App Check
  static bool _isAppCheckError(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('app check') ||
        errorString.contains('appcheck') ||
        errorString.contains('too many attempts') ||
        (error is FirebaseException && errorString.contains('appcheck'));
  }

  /// Check if message looks like an internal error (shouldn't show to user)
  static bool _isInternalError(String message) {
    final internalPatterns = [
      'internal',
      'error:',
      'exception',
      'failed to',
      'cannot read',
      'undefined',
      'null',
      'timeout',
      'network',
    ];

    final lowerMessage = message.toLowerCase();
    return internalPatterns.any((p) => lowerMessage.contains(p));
  }

  /// Map error code to user-friendly message
  static String _mapErrorCode(String code) {
    switch (code) {
      // Authentication errors
      case 'unauthenticated':
        return 'Sessao expirada. Por favor, faca login novamente.';
      case 'permission-denied':
        return 'Voce nao tem permissao para esta acao.';

      // Resource errors
      case 'not-found':
        return 'Recurso nao encontrado.';
      case 'already-exists':
        return 'Este recurso ja existe.';

      // Input errors
      case 'invalid-argument':
        return 'Dados invalidos. Verifique e tente novamente.';
      case 'failed-precondition':
        return 'Esta acao nao e permitida no momento.';

      // Rate limiting
      case 'resource-exhausted':
        return 'Muitas tentativas. Aguarde alguns minutos.';

      // Service availability
      case 'unavailable':
        return 'Servico temporariamente indisponivel. Tente novamente mais tarde.';

      // Payment specific (detected from details or context)
      case 'payment-unavailable':
        return 'Pagamentos temporariamente indisponiveis. Tente novamente mais tarde.';

      // Booking specific
      case 'booking-conflict':
        return 'Esta data ja esta reservada. Escolha outra data.';
      case 'booking-processed':
        return 'Reserva ja processada.';

      // Default
      case 'internal':
      case 'unknown':
      default:
        return 'Erro interno. Tente novamente.';
    }
  }

  /// Get contextual error messages for specific operations
  static String getContextualError(String operation, Object error) {
    final baseMessage = mapGenericError(error);

    // Add context-specific hints
    switch (operation) {
      case 'payment':
        if (_isAppCheckError(error)) {
          return 'Erro de verificacao de seguranca. Reinicie o aplicativo e tente novamente.';
        }
        if (_isRateLimitError(error)) {
          return 'Muitas tentativas de pagamento. Aguarde antes de tentar novamente.';
        }
        if (_isUnavailableError(error)) {
          return 'Sistema de pagamentos indisponivel. Entre em contato com o suporte.';
        }
        if (_isProviderNotConfiguredError(error)) {
          return 'Sistema de pagamentos nao configurado. Entre em contato com o suporte.';
        }
        return baseMessage;

      case 'booking':
        if (_isConflictError(error)) {
          return 'Esta data ja esta reservada com este fornecedor.';
        }
        if (_isRateLimitError(error)) {
          return 'Muitas reservas em pouco tempo. Aguarde alguns minutos.';
        }
        return baseMessage;

      case 'review':
        if (_isRateLimitError(error)) {
          return 'Aguarde um pouco antes de enviar outra avaliacao.';
        }
        return baseMessage;

      default:
        return baseMessage;
    }
  }

  // Helper methods for error type detection
  static bool _isRateLimitError(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.code == 'resource-exhausted';
    }
    return false;
  }

  static bool _isUnavailableError(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.code == 'unavailable';
    }
    return false;
  }

  static bool _isConflictError(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.code == 'already-exists';
    }
    return false;
  }

  static bool _isProviderNotConfiguredError(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('não está configurado') ||
        errorString.contains('not configured') ||
        errorString.contains('not enabled') ||
        errorString.contains('not available');
  }
}

/// Extension for easy error mapping on FirebaseFunctionsException
extension FirebaseFunctionsExceptionExt on FirebaseFunctionsException {
  /// Get user-friendly error message
  String get userMessage => ErrorMapper.mapFunctionsError(this);
}
