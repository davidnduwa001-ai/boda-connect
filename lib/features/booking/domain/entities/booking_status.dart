/// Enum representing the various states of a booking throughout its lifecycle
enum BookingStatus {
  /// Booking has been created but not yet confirmed by supplier
  pending,

  /// Supplier has confirmed the booking
  confirmed,

  /// Booking is currently in progress (event is happening)
  inProgress,

  /// Booking has been completed successfully
  completed,

  /// Booking has been cancelled by either party
  cancelled,

  /// Booking is under dispute (issue raised by either party)
  disputed,

  /// Payment has been refunded to the client
  refunded,
}

/// Extension to get display names and check states
extension BookingStatusExtension on BookingStatus {
  /// Get human-readable display name
  String get displayName {
    switch (this) {
      case BookingStatus.pending:
        return 'Pendente';
      case BookingStatus.confirmed:
        return 'Confirmado';
      case BookingStatus.inProgress:
        return 'Em Andamento';
      case BookingStatus.completed:
        return 'Concluído';
      case BookingStatus.cancelled:
        return 'Cancelado';
      case BookingStatus.disputed:
        return 'Em Disputa';
      case BookingStatus.refunded:
        return 'Reembolsado';
    }
  }

  /// Check if booking can be cancelled
  bool get canBeCancelled {
    return this == BookingStatus.pending || this == BookingStatus.confirmed;
  }

  /// Check if booking can be modified
  bool get canBeModified {
    return this == BookingStatus.pending || this == BookingStatus.confirmed;
  }

  /// Check if booking is in a final state
  bool get isFinal {
    return this == BookingStatus.completed ||
           this == BookingStatus.cancelled ||
           this == BookingStatus.disputed ||
           this == BookingStatus.refunded;
  }

  /// Check if booking is active
  bool get isActive {
    return this == BookingStatus.confirmed || this == BookingStatus.inProgress;
  }
}
