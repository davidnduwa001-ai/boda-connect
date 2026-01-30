import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierAvailabilityModel {
  final String id;
  final String supplierId;
  final DateTime date;
  final int maxBookings;
  final int currentBookings;
  final bool isAvailable;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupplierAvailabilityModel({
    required this.id,
    required this.supplierId,
    required this.date,
    required this.maxBookings,
    required this.currentBookings,
    required this.isAvailable,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isFullyBooked => currentBookings >= maxBookings;
  bool get isPartiallyBooked => currentBookings > 0 && currentBookings < maxBookings;
  bool get hasAvailability => isAvailable && currentBookings < maxBookings;
  int get remainingSlots => maxBookings - currentBookings;

  factory SupplierAvailabilityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return SupplierAvailabilityModel(
      id: doc.id,
      supplierId: data['supplierId'] as String? ?? '',
      date: _parseTimestamp(data['date']) ?? DateTime.now(),
      maxBookings: (data['maxBookings'] as num?)?.toInt() ?? 1,
      currentBookings: (data['currentBookings'] as num?)?.toInt() ?? 0,
      isAvailable: data['isAvailable'] as bool? ?? true,
      notes: data['notes'] as String?,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'supplierId': supplierId,
      'date': Timestamp.fromDate(date),
      'maxBookings': maxBookings,
      'currentBookings': currentBookings,
      'isAvailable': isAvailable,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SupplierAvailabilityModel copyWith({
    String? id,
    String? supplierId,
    DateTime? date,
    int? maxBookings,
    int? currentBookings,
    bool? isAvailable,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplierAvailabilityModel(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      date: date ?? this.date,
      maxBookings: maxBookings ?? this.maxBookings,
      currentBookings: currentBookings ?? this.currentBookings,
      isAvailable: isAvailable ?? this.isAvailable,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class SupplierAvailabilityCollection {
  final List<SupplierAvailabilityModel> availabilities;

  const SupplierAvailabilityCollection(this.availabilities);

  SupplierAvailabilityModel? getAvailability(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return availabilities.cast<SupplierAvailabilityModel?>().firstWhere(
      (a) {
        if (a == null) return false;
        final availDateOnly = DateTime(a.date.year, a.date.month, a.date.day);
        return availDateOnly == dateOnly;
      },
      orElse: () => null,
    );
  }

  bool isDateAvailable(DateTime date) {
    final availability = getAvailability(date);
    return availability?.hasAvailability ?? true; // Default to available if no data
  }

  bool isDateFullyBooked(DateTime date) {
    final availability = getAvailability(date);
    return availability?.isFullyBooked ?? false;
  }

  bool isDatePartiallyBooked(DateTime date) {
    final availability = getAvailability(date);
    return availability?.isPartiallyBooked ?? false;
  }
}
