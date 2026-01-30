import 'package:boda_connect/features/auth/domain/entities/app_user.dart';

class AppUserModel extends AppUser {
  const AppUserModel({
    required super.id,
    required super.role,
    super.phone,
  });

  factory AppUserModel.fromMap(Map<String, dynamic> map, String id) {
    return AppUserModel(
      id: id,
      role: (map['role'] as String?) ?? 'client',
      phone: map['phone'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'role': role,
        'phone': phone,
      };
}
