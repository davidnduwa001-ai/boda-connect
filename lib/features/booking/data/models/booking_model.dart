import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_entity.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_status.dart';

/// Data model for Booking that extends the domain entity
/// Handles serialization/deserialization for Firestore
class BookingModel extends BookingEntity {
  const BookingModel({
    required super.id,
    required super.clientId,
    required super.supplierId,
    required super.packageId,
    super.packageName,
    required super.eventName,
    super.eventType,
    required super.eventDate,
    super.eventTime,
    super.eventLocation,
    super.eventLatitude,
    super.eventLongitude,
    super.status,
    required super.totalAmount,
    super.paidAmount,
    super.currency,
    super.payments,
    super.notes,
    super.clientNotes,
    super.supplierNotes,
    super.selectedCustomizations,
    super.guestCount,
    super.proposalId,
    required super.createdAt,
    required super.updatedAt,
    super.confirmedAt,
    super.completedAt,
    super.cancelledAt,
    super.cancellationReason,
    super.cancelledBy,
  });

  /// Creates a BookingModel from a domain BookingEntity
  factory BookingModel.fromEntity(BookingEntity entity) {
    return BookingModel(
      id: entity.id,
      clientId: entity.clientId,
      supplierId: entity.supplierId,
      packageId: entity.packageId,
      packageName: entity.packageName,
      eventName: entity.eventName,
      eventType: entity.eventType,
      eventDate: entity.eventDate,
      eventTime: entity.eventTime,
      eventLocation: entity.eventLocation,
      eventLatitude: entity.eventLatitude,
      eventLongitude: entity.eventLongitude,
      status: entity.status,
      totalAmount: entity.totalAmount,
      paidAmount: entity.paidAmount,
      currency: entity.currency,
      payments: entity.payments,
      notes: entity.notes,
      clientNotes: entity.clientNotes,
      supplierNotes: entity.supplierNotes,
      selectedCustomizations: entity.selectedCustomizations,
      guestCount: entity.guestCount,
      proposalId: entity.proposalId,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      confirmedAt: entity.confirmedAt,
      completedAt: entity.completedAt,
      cancelledAt: entity.cancelledAt,
      cancellationReason: entity.cancellationReason,
      cancelledBy: entity.cancelledBy,
    );
  }

  /// Creates a BookingModel from Firestore DocumentSnapshot
  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as DataMap;
    return BookingModel.fromMap(data, doc.id);
  }

  /// Creates a BookingModel from a Map with an optional ID
  factory BookingModel.fromMap(DataMap map, [String? id]) {
    return BookingModel(
      id: id ?? map['id'] as String,
      clientId: map['clientId'] as String,
      supplierId: map['supplierId'] as String,
      packageId: map['packageId'] as String,
      packageName: map['packageName'] as String?,
      eventName: map['eventName'] as String,
      eventType: map['eventType'] as String?,
      eventDate: (map['eventDate'] as Timestamp).toDate(),
      eventTime: map['eventTime'] as String?,
      eventLocation: map['eventLocation'] as String?,
      eventLatitude: map['eventLatitude'] as double?,
      eventLongitude: map['eventLongitude'] as double?,
      status: _parseStatus(map['status'] as String?),
      totalAmount: map['totalAmount'] as int,
      paidAmount: (map['paidAmount'] as int?) ?? 0,
      currency: (map['currency'] as String?) ?? 'AOA',
      payments: _parsePayments(map['payments'] as List?),
      notes: map['notes'] as String?,
      clientNotes: map['clientNotes'] as String?,
      supplierNotes: map['supplierNotes'] as String?,
      selectedCustomizations: _parseStringList(map['selectedCustomizations'] as List?),
      guestCount: map['guestCount'] as int?,
      proposalId: map['proposalId'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      confirmedAt: map['confirmedAt'] != null ? (map['confirmedAt'] as Timestamp).toDate() : null,
      completedAt: map['completedAt'] != null ? (map['completedAt'] as Timestamp).toDate() : null,
      cancelledAt: map['cancelledAt'] != null ? (map['cancelledAt'] as Timestamp).toDate() : null,
      cancellationReason: map['cancellationReason'] as String?,
      cancelledBy: map['cancelledBy'] as String?,
    );
  }

  /// Creates a BookingModel from Cloud Function response
  /// Cloud Functions return ISO date strings instead of Firestore Timestamps
  factory BookingModel.fromCloudFunction(DataMap data) {
    return BookingModel(
      id: data['id'] as String? ?? '',
      clientId: data['clientId'] as String? ?? '',
      supplierId: data['supplierId'] as String? ?? '',
      packageId: data['packageId'] as String? ?? '',
      packageName: data['packageName'] as String?,
      eventName: data['eventName'] as String? ?? '',
      eventType: data['eventType'] as String?,
      eventDate: _parseIsoDate(data['eventDate']) ?? DateTime.now(),
      eventTime: data['eventTime'] as String?,
      eventLocation: data['eventLocation'] as String?,
      eventLatitude: (data['eventLatitude'] as num?)?.toDouble(),
      eventLongitude: (data['eventLongitude'] as num?)?.toDouble(),
      status: _parseStatus(data['status'] as String?),
      totalAmount: (data['totalPrice'] as num?)?.toInt() ?? (data['totalAmount'] as num?)?.toInt() ?? 0,
      paidAmount: (data['paidAmount'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'AOA',
      payments: _parsePaymentsFromCloudFunction(data['payments'] as List?),
      notes: data['notes'] as String?,
      clientNotes: data['clientNotes'] as String?,
      supplierNotes: data['supplierNotes'] as String?,
      selectedCustomizations: _parseStringList(data['selectedCustomizations'] as List?),
      guestCount: (data['guestCount'] as num?)?.toInt(),
      proposalId: data['proposalId'] as String?,
      createdAt: _parseIsoDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseIsoDate(data['updatedAt']) ?? DateTime.now(),
      confirmedAt: _parseIsoDate(data['confirmedAt']),
      completedAt: _parseIsoDate(data['completedAt']),
      cancelledAt: _parseIsoDate(data['cancelledAt']),
      cancellationReason: data['cancellationReason'] as String?,
      cancelledBy: data['cancelledBy'] as String?,
    );
  }

  /// Parse ISO date string from Cloud Function response
  static DateTime? _parseIsoDate(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }

  /// Parse payments from Cloud Function response (ISO date strings)
  static List<BookingPaymentEntity> _parsePaymentsFromCloudFunction(List? payments) {
    if (payments == null) return const [];

    return payments.map((p) {
      if (p is! Map) return null;
      final map = Map<String, dynamic>.from(p);
      return BookingPaymentEntity(
        id: map['id'] as String? ?? '',
        amount: (map['amount'] as num?)?.toInt() ?? 0,
        method: map['method'] as String? ?? '',
        reference: map['reference'] as String?,
        paidAt: _parseIsoDate(map['paidAt']) ?? DateTime.now(),
        notes: map['notes'] as String?,
      );
    }).whereType<BookingPaymentEntity>().toList();
  }

  /// Converts the BookingModel to a Map for Firestore
  DataMap toFirestore() {
    return {
      'id': id,
      'clientId': clientId,
      'supplierId': supplierId,
      'packageId': packageId,
      'packageName': packageName,
      'eventName': eventName,
      'eventType': eventType,
      'eventDate': Timestamp.fromDate(eventDate),
      'eventTime': eventTime,
      'eventLocation': eventLocation,
      'eventLatitude': eventLatitude,
      'eventLongitude': eventLongitude,
      'status': status.name,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'currency': currency,
      'payments': payments.map((p) => BookingPaymentModel.fromEntity(p).toMap()).toList(),
      'notes': notes,
      'clientNotes': clientNotes,
      'supplierNotes': supplierNotes,
      'selectedCustomizations': selectedCustomizations,
      'guestCount': guestCount,
      'proposalId': proposalId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'confirmedAt': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
    };
  }

  /// Converts the BookingModel to a domain BookingEntity
  BookingEntity toEntity() {
    return BookingEntity(
      id: id,
      clientId: clientId,
      supplierId: supplierId,
      packageId: packageId,
      packageName: packageName,
      eventName: eventName,
      eventType: eventType,
      eventDate: eventDate,
      eventTime: eventTime,
      eventLocation: eventLocation,
      eventLatitude: eventLatitude,
      eventLongitude: eventLongitude,
      status: status,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      currency: currency,
      payments: payments,
      notes: notes,
      clientNotes: clientNotes,
      supplierNotes: supplierNotes,
      selectedCustomizations: selectedCustomizations,
      guestCount: guestCount,
      proposalId: proposalId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      confirmedAt: confirmedAt,
      completedAt: completedAt,
      cancelledAt: cancelledAt,
      cancellationReason: cancellationReason,
      cancelledBy: cancelledBy,
    );
  }

  /// Creates a copy of this BookingModel with the given fields replaced
  BookingModel copyWith({
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
    return BookingModel(
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

  /// Helper method to parse BookingStatus from string
  static BookingStatus _parseStatus(String? status) {
    if (status == null) return BookingStatus.pending;

    try {
      return BookingStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => BookingStatus.pending,
      );
    } catch (e) {
      return BookingStatus.pending;
    }
  }

  /// Helper method to parse payment list
  static List<BookingPaymentEntity> _parsePayments(List? payments) {
    if (payments == null) return const [];

    return payments
        .map((p) => BookingPaymentModel.fromMap(p as DataMap))
        .toList();
  }

  /// Helper method to parse string list
  static List<String> _parseStringList(List? list) {
    if (list == null) return const [];
    return list.map((e) => e.toString()).toList();
  }
}

/// Data model for BookingPayment
class BookingPaymentModel extends BookingPaymentEntity {
  const BookingPaymentModel({
    required super.id,
    required super.amount,
    required super.method,
    super.reference,
    required super.paidAt,
    super.notes,
  });

  /// Creates a BookingPaymentModel from a domain BookingPaymentEntity
  factory BookingPaymentModel.fromEntity(BookingPaymentEntity entity) {
    return BookingPaymentModel(
      id: entity.id,
      amount: entity.amount,
      method: entity.method,
      reference: entity.reference,
      paidAt: entity.paidAt,
      notes: entity.notes,
    );
  }

  /// Creates a BookingPaymentModel from a Map
  factory BookingPaymentModel.fromMap(DataMap map) {
    return BookingPaymentModel(
      id: map['id'] as String,
      amount: map['amount'] as int,
      method: map['method'] as String,
      reference: map['reference'] as String?,
      paidAt: (map['paidAt'] as Timestamp).toDate(),
      notes: map['notes'] as String?,
    );
  }

  /// Converts the BookingPaymentModel to a Map
  DataMap toMap() {
    return {
      'id': id,
      'amount': amount,
      'method': method,
      'reference': reference,
      'paidAt': Timestamp.fromDate(paidAt),
      'notes': notes,
    };
  }

  /// Converts the BookingPaymentModel to a domain BookingPaymentEntity
  BookingPaymentEntity toEntity() {
    return BookingPaymentEntity(
      id: id,
      amount: amount,
      method: method,
      reference: reference,
      paidAt: paidAt,
      notes: notes,
    );
  }
}
