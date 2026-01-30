import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:boda_connect/core/utils/typedefs.dart';

/// Model class for DayHours that extends the domain entity
/// Handles conversion between Firestore data and domain DayHoursEntity
class DayHoursModel extends DayHoursEntity {
  const DayHoursModel({
    required super.isOpen,
    super.openTime,
    super.closeTime,
  });

  /// Create DayHoursModel from domain entity
  factory DayHoursModel.fromEntity(DayHoursEntity entity) {
    return DayHoursModel(
      isOpen: entity.isOpen,
      openTime: entity.openTime,
      closeTime: entity.closeTime,
    );
  }

  /// Create DayHoursModel from Firestore map
  factory DayHoursModel.fromFirestore(DataMap map) {
    return DayHoursModel(
      isOpen: map['isOpen'] as bool? ?? false,
      openTime: map['openTime'] as String?,
      closeTime: map['closeTime'] as String?,
    );
  }

  /// Convert to Firestore map
  DataMap toFirestore() {
    return {
      'isOpen': isOpen,
      if (openTime != null) 'openTime': openTime,
      if (closeTime != null) 'closeTime': closeTime,
    };
  }

  /// Convert to domain entity
  DayHoursEntity toEntity() {
    return DayHoursEntity(
      isOpen: isOpen,
      openTime: openTime,
      closeTime: closeTime,
    );
  }

  @override
  DayHoursModel copyWith({
    bool? isOpen,
    String? openTime,
    String? closeTime,
  }) {
    return DayHoursModel(
      isOpen: isOpen ?? this.isOpen,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
    );
  }
}
