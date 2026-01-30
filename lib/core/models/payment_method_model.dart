import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentMethodType {
  creditCard, // Cartão de Crédito/Débito (Visa, Mastercard)
  multicaixaExpress, // Multicaixa Express
  bankTransfer, // Transferência Bancária
}

class PaymentMethodModel {
  final String id;
  final String supplierId;
  final PaymentMethodType type;
  final String displayName;
  final Map<String, dynamic> details;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentMethodModel({
    required this.id,
    required this.supplierId,
    required this.type,
    required this.displayName,
    required this.details,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentMethodModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentMethodModel(
      id: doc.id,
      supplierId: data['supplierId'] ?? '',
      type: _parsePaymentType(data['type'] ?? 'creditCard'),
      displayName: data['displayName'] ?? '',
      details: Map<String, dynamic>.from(data['details'] ?? {}),
      isDefault: data['isDefault'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'supplierId': supplierId,
      'type': _paymentTypeToString(type),
      'displayName': displayName,
      'details': details,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static PaymentMethodType _parsePaymentType(String type) {
    switch (type) {
      case 'creditCard':
        return PaymentMethodType.creditCard;
      case 'multicaixaExpress':
        return PaymentMethodType.multicaixaExpress;
      case 'bankTransfer':
        return PaymentMethodType.bankTransfer;
      default:
        return PaymentMethodType.creditCard;
    }
  }

  static String _paymentTypeToString(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.creditCard:
        return 'creditCard';
      case PaymentMethodType.multicaixaExpress:
        return 'multicaixaExpress';
      case PaymentMethodType.bankTransfer:
        return 'bankTransfer';
    }
  }

  String get typeLabel {
    switch (type) {
      case PaymentMethodType.creditCard:
        return 'Cartão de Crédito/Débito';
      case PaymentMethodType.multicaixaExpress:
        return 'Multicaixa Express';
      case PaymentMethodType.bankTransfer:
        return 'Transferência Bancária';
    }
  }

  String get typeSubtitle {
    switch (type) {
      case PaymentMethodType.creditCard:
        return 'Visa, Mastercard';
      case PaymentMethodType.multicaixaExpress:
        return 'Pagamento instantâneo via telemóvel';
      case PaymentMethodType.bankTransfer:
        return 'BAI, BFA, BIC, Atlântico';
    }
  }

  // Masked display for security
  String get maskedInfo {
    switch (type) {
      case PaymentMethodType.creditCard:
        final lastFour = details['lastFour'] ?? '****';
        return '**** **** **** $lastFour';
      case PaymentMethodType.multicaixaExpress:
        final phone = details['phone'] ?? '';
        if (phone.length >= 4) {
          return '+244 ${phone.substring(0, 3)} *** ***';
        }
        return phone;
      case PaymentMethodType.bankTransfer:
        final accountNumber = details['accountNumber'] ?? '';
        if (accountNumber.length >= 4) {
          final last4 = accountNumber.substring(accountNumber.length - 4);
          return '****.$last4';
        }
        return accountNumber;
    }
  }

  PaymentMethodModel copyWith({
    String? id,
    String? supplierId,
    PaymentMethodType? type,
    String? displayName,
    Map<String, dynamic>? details,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentMethodModel(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      details: details ?? this.details,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Helper class for creating payment method details
class PaymentMethodDetails {
  // Credit/Debit Card
  static Map<String, dynamic> creditCard({
    required String lastFour,
    required String cardType, // 'Visa', 'Mastercard'
    String? expiryMonth,
    String? expiryYear,
  }) {
    return {
      'lastFour': lastFour,
      'cardType': cardType,
      'expiryMonth': expiryMonth,
      'expiryYear': expiryYear,
    };
  }

  // Multicaixa Express
  static Map<String, dynamic> multicaixaExpress({
    required String phone,
    String? accountName,
  }) {
    return {
      'phone': phone,
      'accountName': accountName,
    };
  }

  // Bank Transfer
  static Map<String, dynamic> bankTransfer({
    required String bankName, // 'BAI', 'BFA', 'BIC', 'Atlântico'
    required String accountNumber,
    required String accountName,
    String? iban,
  }) {
    return {
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'iban': iban,
    };
  }
}
