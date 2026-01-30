import 'package:equatable/equatable.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_status.dart';

/// Pure Dart entity representing a booking/reservation in the domain layer
/// This entity contains no Firebase or external dependencies
class BookingEntity extends Equatable {
  const BookingEntity({
    required this.id,
    required this.clientId,
    required this.supplierId,
    required this.packageId,
    this.packageName,
    required this.eventName,
    this.eventType,
    required this.eventDate,
    this.eventTime,
    this.eventLocation,
    this.eventLatitude,
    this.eventLongitude,
    this.status = BookingStatus.pending,
    required this.totalAmount,
    this.paidAmount = 0,
    this.currency = 'AOA',
    this.payments = const [],
    this.notes,
    this.clientNotes,
    this.supplierNotes,
    this.selectedCustomizations = const [],
    this.guestCount,
    this.proposalId,
    required this.createdAt,
    required this.updatedAt,
    this.confirmedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.cancelledBy,
  });

  /// Unique identifier for the booking
  final String id;

  /// ID of the client who made the booking
  final String clientId;

  /// ID of the supplier providing the service
  final String supplierId;

  /// ID of the package being booked
  final String packageId;

  /// Name of the package (denormalized for quick access)
  final String? packageName;

  /// Name of the event
  final String eventName;

  /// Type of event (e.g., wedding, birthday, corporate)
  final String? eventType;

  /// Date when the event will take place
  final DateTime eventDate;

  /// Time when the event will start
  final String? eventTime;

  /// Location where the event will take place
  final String? eventLocation;

  /// Latitude of event location
  final double? eventLatitude;

  /// Longitude of event location
  final double? eventLongitude;

  /// Current status of the booking
  final BookingStatus status;

  /// Total amount to be paid for the booking
  final int totalAmount;

  /// Amount already paid
  final int paidAmount;

  /// Currency code (default: AOA - Angolan Kwanza)
  final String currency;

  /// List of payments made for this booking
  final List<BookingPaymentEntity> payments;

  /// General notes about the booking
  final String? notes;

  /// Notes added by the client
  final String? clientNotes;

  /// Notes added by the supplier
  final String? supplierNotes;

  /// List of selected customization IDs
  final List<String> selectedCustomizations;

  /// Number of guests expected
  final int? guestCount;

  /// ID of the proposal this booking originated from (if applicable)
  final String? proposalId;

  /// Timestamp when the booking was created
  final DateTime createdAt;

  /// Timestamp when the booking was last updated
  final DateTime updatedAt;

  /// Timestamp when the booking was confirmed
  final DateTime? confirmedAt;

  /// Timestamp when the booking was completed
  final DateTime? completedAt;

  /// Timestamp when the booking was cancelled
  final DateTime? cancelledAt;

  /// Reason for cancellation
  final String? cancellationReason;

  /// ID of user who cancelled (clientId or supplierId)
  final String? cancelledBy;

  @override
  List<Object?> get props => [
        id,
        clientId,
        supplierId,
        packageId,
        packageName,
        eventName,
        eventType,
        eventDate,
        eventTime,
        eventLocation,
        eventLatitude,
        eventLongitude,
        status,
        totalAmount,
        paidAmount,
        currency,
        payments,
        notes,
        clientNotes,
        supplierNotes,
        selectedCustomizations,
        guestCount,
        proposalId,
        createdAt,
        updatedAt,
        confirmedAt,
        completedAt,
        cancelledAt,
        cancellationReason,
        cancelledBy,
      ];

  /// Calculate remaining amount to be paid
  int get remainingAmount => totalAmount - paidAmount;

  /// Check if booking is fully paid
  bool get isPaid => paidAmount >= totalAmount;

  /// Check if booking can be cancelled
  bool get canCancel => status.canBeCancelled;

  /// Check if booking can be modified
  bool get canModify => status.canBeModified;

  /// Check if booking is in a final state
  bool get isFinal => status.isFinal;

  /// Check if booking is active
  bool get isActive => status.isActive;

  /// Copy method for creating modified instances
  BookingEntity copyWith({
    String? id,
    String? clientId,
    String? supplierId,
    String? packageId,
    String? packageName,
    String? eventName,
    String? eventType,
    DateTime? eventDate,
    String? eventTime,
    String? eventLocation,
    double? eventLatitude,
    double? eventLongitude,
    BookingStatus? status,
    int? totalAmount,
    int? paidAmount,
    String? currency,
    List<BookingPaymentEntity>? payments,
    String? notes,
    String? clientNotes,
    String? supplierNotes,
    List<String>? selectedCustomizations,
    int? guestCount,
    String? proposalId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? confirmedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    String? cancelledBy,
  }) {
    return BookingEntity(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      supplierId: supplierId ?? this.supplierId,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      eventName: eventName ?? this.eventName,
      eventType: eventType ?? this.eventType,
      eventDate: eventDate ?? this.eventDate,
      eventTime: eventTime ?? this.eventTime,
      eventLocation: eventLocation ?? this.eventLocation,
      eventLatitude: eventLatitude ?? this.eventLatitude,
      eventLongitude: eventLongitude ?? this.eventLongitude,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      currency: currency ?? this.currency,
      payments: payments ?? this.payments,
      notes: notes ?? this.notes,
      clientNotes: clientNotes ?? this.clientNotes,
      supplierNotes: supplierNotes ?? this.supplierNotes,
      selectedCustomizations: selectedCustomizations ?? this.selectedCustomizations,
      guestCount: guestCount ?? this.guestCount,
      proposalId: proposalId ?? this.proposalId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
    );
  }
}

/// Entity representing a payment made for a booking
class BookingPaymentEntity extends Equatable {
  const BookingPaymentEntity({
    required this.id,
    required this.amount,
    required this.method,
    this.reference,
    required this.paidAt,
    this.notes,
  });

  /// Unique identifier for the payment
  final String id;

  /// Amount paid
  final int amount;

  /// Payment method (e.g., 'cash', 'transfer', 'card')
  final String method;

  /// Payment reference/transaction ID
  final String? reference;

  /// Timestamp when payment was made
  final DateTime paidAt;

  /// Additional notes about the payment
  final String? notes;

  @override
  List<Object?> get props => [id, amount, method, reference, paidAt, notes];

  /// Copy method for creating modified instances
  BookingPaymentEntity copyWith({
    String? id,
    int? amount,
    String? method,
    String? reference,
    DateTime? paidAt,
    String? notes,
  }) {
    return BookingPaymentEntity(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      reference: reference ?? this.reference,
      paidAt: paidAt ?? this.paidAt,
      notes: notes ?? this.notes,
    );
  }
}
