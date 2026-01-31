import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  confirmed,
  inProgress,
  completed,
  cancelled,
  rejected,
  disputed,
  refunded,
}

class BookingUIFlags {
  final bool canAccept;
  final bool canDecline;
  final bool canComplete;
  final bool canCancel;
  final bool canMessage;
  final bool canViewDetails;
  final bool showExpiringSoon;
  final bool showPaymentReceived;

  const BookingUIFlags({
    this.canAccept = false,
    this.canDecline = false,
    this.canComplete = false,
    this.canCancel = false,
    this.canMessage = true,
    this.canViewDetails = true,
    this.showExpiringSoon = false,
    this.showPaymentReceived = false,
  });

  factory BookingUIFlags.fromMap(Map<String, dynamic> data) {
    return BookingUIFlags(
      canAccept: data['canAccept'] as bool? ?? false,
      canDecline: data['canDecline'] as bool? ?? false,
      canComplete: data['canComplete'] as bool? ?? false,
      canCancel: data['canCancel'] as bool? ?? false,
      canMessage: data['canMessage'] as bool? ?? true,
      canViewDetails: data['canViewDetails'] as bool? ?? true,
      showExpiringSoon: data['showExpiringSoon'] as bool? ?? false,
      showPaymentReceived: data['showPaymentReceived'] as bool? ?? false,
    );
  }
}

class BookingModel {

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse status
    final statusStr = data['status'] as String?;
    final status = BookingStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => BookingStatus.pending,
    );

    // Parse payments list
    final paymentsRaw = data['payments'];
    final payments = <BookingPayment>[];
    if (paymentsRaw is List) {
      for (final item in paymentsRaw) {
        if (item is Map<String, dynamic>) {
          payments.add(BookingPayment.fromMap(item));
        }
      }
    }

    // Parse customizations list
    final customRaw = data['selectedCustomizations'];
    final customizations = <String>[];
    if (customRaw is List) {
      for (final item in customRaw) {
        if (item is String) {
          customizations.add(item);
        }
      }
    }

    // Parse GeoPoint
    final geoRaw = data['eventGeopoint'];
    final geoPoint = geoRaw is GeoPoint ? geoRaw : null;

    return BookingModel(
      id: doc.id,
      clientId: data['clientId'] as String? ?? '',
      clientName: data['clientName'] as String?,
      supplierId: data['supplierId'] as String? ?? '',
      supplierName: data['supplierName'] as String?,
      packageId: data['packageId'] as String? ?? '',
      packageName: data['packageName'] as String?,
      eventName: data['eventName'] as String? ?? '',
      eventType: data['eventType'] as String?,
      eventDate: _parseTimestamp(data['eventDate']) ?? DateTime.now(),
      eventTime: data['eventTime'] as String?,
      eventLocation: data['eventLocation'] as String?,
      eventGeopoint: geoPoint,
      status: status,
      // Support both totalPrice and totalAmount (backend uses totalAmount)
      totalPrice: (data['totalPrice'] as num?)?.toInt() ??
                  (data['totalAmount'] as num?)?.toInt() ?? 0,
      paidAmount: (data['paidAmount'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'AOA',
      payments: payments,
      notes: data['notes'] as String?,
      clientNotes: data['clientNotes'] as String?,
      supplierNotes: data['supplierNotes'] as String?,
      selectedCustomizations: customizations,
      guestCount: (data['guestCount'] as num?)?.toInt(),
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
      confirmedAt: _parseTimestamp(data['confirmedAt']),
      completedAt: _parseTimestamp(data['completedAt']),
      cancelledAt: _parseTimestamp(data['cancelledAt']),
      cancellationReason: data['cancellationReason'] as String?,
      cancelledBy: data['cancelledBy'] as String?,
    );
  }

  /// Create BookingModel from Cloud Function response
  /// Cloud Functions return ISO date strings instead of Firestore Timestamps
  factory BookingModel.fromCloudFunction(Map<String, dynamic> data) {
    // Parse status
    final statusStr = data['status'] as String?;
    final status = BookingStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => BookingStatus.pending,
    );

    // Parse payments list
    final paymentsRaw = data['payments'];
    final payments = <BookingPayment>[];
    if (paymentsRaw is List) {
      for (final item in paymentsRaw) {
        if (item is Map<String, dynamic>) {
          payments.add(BookingPayment.fromMap(item));
        }
      }
    }

    // Parse customizations list
    final customRaw = data['selectedCustomizations'];
    final customizations = <String>[];
    if (customRaw is List) {
      for (final item in customRaw) {
        if (item is String) {
          customizations.add(item);
        }
      }
    }

    // Parse UI flags from Cloud Function
    BookingUIFlags? uiFlags;
    if (data['uiFlags'] is Map<String, dynamic>) {
      uiFlags = BookingUIFlags.fromMap(data['uiFlags'] as Map<String, dynamic>);
    }

    return BookingModel(
      id: data['id'] as String? ?? '',
      clientId: data['clientId'] as String? ?? '',
      clientName: data['clientName'] as String?,
      supplierId: data['supplierId'] as String? ?? '',
      supplierName: data['supplierName'] as String?,
      packageId: data['packageId'] as String? ?? '',
      packageName: data['packageName'] as String?,
      eventName: data['eventName'] as String? ?? '',
      eventType: data['eventType'] as String?,
      eventDate: _parseIsoDate(data['eventDate']) ?? DateTime.now(),
      eventTime: data['eventTime'] as String?,
      eventLocation: data['eventLocation'] as String?,
      eventGeopoint: null, // GeoPoints not sent via Cloud Functions
      status: status,
      // Support both totalPrice and totalAmount (backend uses totalAmount)
      totalPrice: (data['totalPrice'] as num?)?.toInt() ??
                  (data['totalAmount'] as num?)?.toInt() ?? 0,
      paidAmount: (data['paidAmount'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'AOA',
      payments: payments,
      notes: data['notes'] as String?,
      clientNotes: data['clientNotes'] as String?,
      supplierNotes: data['supplierNotes'] as String?,
      selectedCustomizations: customizations,
      guestCount: (data['guestCount'] as num?)?.toInt(),
      createdAt: _parseIsoDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseIsoDate(data['updatedAt']) ?? DateTime.now(),
      confirmedAt: _parseIsoDate(data['confirmedAt']),
      completedAt: _parseIsoDate(data['completedAt']),
      cancelledAt: _parseIsoDate(data['cancelledAt']),
      cancellationReason: data['cancellationReason'] as String?,
      cancelledBy: data['cancelledBy'] as String?,
      uiFlags: uiFlags,
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
    return null;
  }

  final String id;
  final String clientId;
  final String? clientName;
  final String supplierId;
  final String? supplierName;
  final String packageId;
  final String? packageName;
  final String eventName;
  final String? eventType;
  final DateTime eventDate;
  final String? eventTime;
  final String? eventLocation;
  final GeoPoint? eventGeopoint;
  final BookingStatus status;
  final int totalPrice;
  final int paidAmount;
  final String currency;
  final List<BookingPayment> payments;
  final String? notes;
  final String? clientNotes;
  final String? supplierNotes;
  final List<String> selectedCustomizations;
  final int? guestCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? cancelledBy;
  final BookingUIFlags? uiFlags;

  const BookingModel({
    required this.id,
    required this.clientId,
    this.clientName,
    required this.supplierId,
    this.supplierName,
    required this.packageId,
    this.packageName,
    required this.eventName,
    this.eventType,
    required this.eventDate,
    this.eventTime,
    this.eventLocation,
    this.eventGeopoint,
    this.status = BookingStatus.pending,
    required this.totalPrice,
    this.paidAmount = 0,
    this.currency = 'AOA',
    this.payments = const [],
    this.notes,
    this.clientNotes,
    this.supplierNotes,
    this.selectedCustomizations = const [],
    this.guestCount,
    required this.createdAt,
    required this.updatedAt,
    this.confirmedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.cancelledBy,
    this.uiFlags,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'packageId': packageId,
      'packageName': packageName,
      'eventName': eventName,
      'eventType': eventType,
      'eventDate': Timestamp.fromDate(eventDate),
      'eventTime': eventTime,
      'eventLocation': eventLocation,
      'eventGeopoint': eventGeopoint,
      'status': status.name,
      'totalPrice': totalPrice,
      'paidAmount': paidAmount,
      'currency': currency,
      'payments': payments.map((p) => p.toMap()).toList(),
      'notes': notes,
      'clientNotes': clientNotes,
      'supplierNotes': supplierNotes,
      'selectedCustomizations': selectedCustomizations,
      'guestCount': guestCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'confirmedAt': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
    };
  }

  BookingModel copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? supplierId,
    String? supplierName,
    String? packageId,
    String? packageName,
    String? eventName,
    String? eventType,
    DateTime? eventDate,
    String? eventTime,
    String? eventLocation,
    GeoPoint? eventGeopoint,
    BookingStatus? status,
    int? totalPrice,
    int? paidAmount,
    String? currency,
    List<BookingPayment>? payments,
    String? notes,
    String? clientNotes,
    String? supplierNotes,
    List<String>? selectedCustomizations,
    int? guestCount,
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
      clientName: clientName ?? this.clientName,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      eventName: eventName ?? this.eventName,
      eventType: eventType ?? this.eventType,
      eventDate: eventDate ?? this.eventDate,
      eventTime: eventTime ?? this.eventTime,
      eventLocation: eventLocation ?? this.eventLocation,
      eventGeopoint: eventGeopoint ?? this.eventGeopoint,
      status: status ?? this.status,
      totalPrice: totalPrice ?? this.totalPrice,
      paidAmount: paidAmount ?? this.paidAmount,
      currency: currency ?? this.currency,
      payments: payments ?? this.payments,
      notes: notes ?? this.notes,
      clientNotes: clientNotes ?? this.clientNotes,
      supplierNotes: supplierNotes ?? this.supplierNotes,
      selectedCustomizations: selectedCustomizations ?? this.selectedCustomizations,
      guestCount: guestCount ?? this.guestCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
    );
  }

  int get remainingAmount => totalPrice - paidAmount;
  bool get isPaid => paidAmount >= totalPrice;
  bool get canCancel => 
      status == BookingStatus.pending || status == BookingStatus.confirmed;

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class BookingPayment {

  const BookingPayment({
    required this.id,
    required this.amount,
    required this.method,
    this.reference,
    required this.paidAt,
    this.notes,
  });

  factory BookingPayment.fromMap(Map<String, dynamic> map) {
    return BookingPayment(
      id: map['id'] as String? ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      method: map['method'] as String? ?? '',
      reference: map['reference'] as String?,
      paidAt: _parseTimestamp(map['paidAt']) ?? DateTime.now(),
      notes: map['notes'] as String?,
    );
  }
  final String id;
  final int amount;
  final String method;
  final String? reference;
  final DateTime paidAt;
  final String? notes;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'method': method,
      'reference': reference,
      'paidAt': Timestamp.fromDate(paidAt),
      'notes': notes,
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}