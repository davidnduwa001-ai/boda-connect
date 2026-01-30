import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:boda_connect/features/supplier/data/models/day_hours_model.dart';
import 'package:boda_connect/core/utils/typedefs.dart';

/// Model class for WorkingHours that extends the domain entity
/// Handles conversion between Firestore data and domain WorkingHoursEntity
class WorkingHoursModel extends WorkingHoursEntity {
  const WorkingHoursModel({
    required super.schedule,
  });

  /// Create WorkingHoursModel from domain entity
  factory WorkingHoursModel.fromEntity(WorkingHoursEntity entity) {
    final schedule = <String, DayHoursEntity>{};
    entity.schedule.forEach((key, value) {
      schedule[key] = DayHoursModel.fromEntity(value);
    });

    return WorkingHoursModel(schedule: schedule);
  }

  /// Create WorkingHoursModel from Firestore map
  factory WorkingHoursModel.fromFirestore(DataMap map) {
    final schedule = <String, DayHoursEntity>{};

    map.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        schedule[key] = DayHoursModel.fromFirestore(value);
      }
    });

    return WorkingHoursModel(schedule: schedule);
  }

  /// Convert to Firestore map
  DataMap toFirestore() {
    final scheduleMap = <String, dynamic>{};

    schedule.forEach((key, value) {
      scheduleMap[key] = DayHoursModel.fromEntity(value).toFirestore();
    });

    return scheduleMap;
  }

  /// Convert to domain entity
  WorkingHoursEntity toEntity() {
    return WorkingHoursEntity(schedule: schedule);
  }

  @override
  WorkingHoursModel copyWith({
    Map<String, DayHoursEntity>? schedule,
  }) {
    return WorkingHoursModel(
      schedule: schedule ?? this.schedule,
    );
  }
}
