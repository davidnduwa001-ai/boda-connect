import 'package:cloud_firestore/cloud_firestore.dart';

class CartItem {
  final String id;
  final String packageId;
  final String packageName;
  final String supplierId;
  final String supplierName;
  final DateTime selectedDate;
  final int guestCount;
  final List<String> selectedCustomizations;
  final int basePrice;
  final int customizationsPrice;
  final int totalPrice;
  final String? packageImage;
  final DateTime addedAt;

  const CartItem({
    required this.id,
    required this.packageId,
    required this.packageName,
    required this.supplierId,
    required this.supplierName,
    required this.selectedDate,
    required this.guestCount,
    required this.selectedCustomizations,
    required this.basePrice,
    required this.customizationsPrice,
    required this.totalPrice,
    this.packageImage,
    required this.addedAt,
  });

  factory CartItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final customizationsRaw = data['selectedCustomizations'];
    final customizations = <String>[];
    if (customizationsRaw is List) {
      for (final item in customizationsRaw) {
        if (item is String) {
          customizations.add(item);
        }
      }
    }

    return CartItem(
      id: doc.id,
      packageId: data['packageId'] as String? ?? '',
      packageName: data['packageName'] as String? ?? '',
      supplierId: data['supplierId'] as String? ?? '',
      supplierName: data['supplierName'] as String? ?? '',
      selectedDate: _parseTimestamp(data['selectedDate']) ?? DateTime.now(),
      guestCount: (data['guestCount'] as num?)?.toInt() ?? 0,
      selectedCustomizations: customizations,
      basePrice: (data['basePrice'] as num?)?.toInt() ?? 0,
      customizationsPrice: (data['customizationsPrice'] as num?)?.toInt() ?? 0,
      totalPrice: (data['totalPrice'] as num?)?.toInt() ?? 0,
      packageImage: data['packageImage'] as String?,
      addedAt: _parseTimestamp(data['addedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'packageId': packageId,
      'packageName': packageName,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'selectedDate': Timestamp.fromDate(selectedDate),
      'guestCount': guestCount,
      'selectedCustomizations': selectedCustomizations,
      'basePrice': basePrice,
      'customizationsPrice': customizationsPrice,
      'totalPrice': totalPrice,
      'packageImage': packageImage,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }

  CartItem copyWith({
    String? id,
    String? packageId,
    String? packageName,
    String? supplierId,
    String? supplierName,
    DateTime? selectedDate,
    int? guestCount,
    List<String>? selectedCustomizations,
    int? basePrice,
    int? customizationsPrice,
    int? totalPrice,
    String? packageImage,
    DateTime? addedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      selectedDate: selectedDate ?? this.selectedDate,
      guestCount: guestCount ?? this.guestCount,
      selectedCustomizations: selectedCustomizations ?? this.selectedCustomizations,
      basePrice: basePrice ?? this.basePrice,
      customizationsPrice: customizationsPrice ?? this.customizationsPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      packageImage: packageImage ?? this.packageImage,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class Cart {
  final List<CartItem> items;

  const Cart(this.items);

  int get itemCount => items.length;

  int get totalPrice => items.fold(0, (sum, item) => sum + item.totalPrice);

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  List<String> get supplierIds => items.map((item) => item.supplierId).toSet().toList();

  int get uniqueSuppliers => supplierIds.length;

  List<CartItem> getItemsBySupplier(String supplierId) {
    return items.where((item) => item.supplierId == supplierId).toList();
  }
}
