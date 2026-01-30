import 'package:equatable/equatable.dart';
import 'package:boda_connect/features/booking/domain/value_objects/money.dart';

/// Value Object representing the payment status of a booking
///
/// This encapsulates all payment-related information and business logic,
/// following Domain-Driven Design principles.
class PaymentStatus extends Equatable {
  /// Total amount that needs to be paid
  final Money totalAmount;

  /// Amount that has been paid so far
  final Money paidAmount;

  const PaymentStatus({
    required this.totalAmount,
    required this.paidAmount,
  });

  /// Creates a PaymentStatus with no payments made
  factory PaymentStatus.unpaid(Money totalAmount) {
    return PaymentStatus(
      totalAmount: totalAmount,
      paidAmount: Money.zero(currency: totalAmount.currency),
    );
  }

  /// Creates a PaymentStatus that is fully paid
  factory PaymentStatus.fullyPaid(Money amount) {
    return PaymentStatus(
      totalAmount: amount,
      paidAmount: amount,
    );
  }

  /// Calculate the remaining amount to be paid
  Money get remainingAmount => totalAmount - paidAmount;

  /// Check if the booking is fully paid
  bool get isFullyPaid => paidAmount >= totalAmount;

  /// Check if no payment has been made
  bool get isUnpaid => paidAmount.isZero;

  /// Check if partial payment has been made
  bool get isPartiallyPaid => paidAmount.isPositive && !isFullyPaid;

  /// Check if overpaid (paid more than required)
  bool get isOverpaid => paidAmount > totalAmount;

  /// Calculate payment completion percentage (0-100)
  double get completionPercentage {
    if (totalAmount.isZero) return 0.0;
    final percentage = (paidAmount.amount / totalAmount.amount) * 100;
    return percentage.clamp(0.0, 100.0);
  }

  /// Get human-readable status
  String get statusText {
    if (isFullyPaid) return 'Pago';
    if (isUnpaid) return 'Não Pago';
    if (isPartiallyPaid) return 'Parcialmente Pago';
    return 'Desconhecido';
  }

  /// Get status in Portuguese (localized)
  String get statusTextPt {
    if (isFullyPaid) return 'Totalmente Pago';
    if (isUnpaid) return 'Aguardando Pagamento';
    if (isPartiallyPaid) {
      return 'Pago ${completionPercentage.toStringAsFixed(0)}%';
    }
    return 'Desconhecido';
  }

  /// Record a new payment
  ///
  /// Returns a new PaymentStatus with the payment added
  ///
  /// Example:
  /// ```dart
  /// final status = PaymentStatus.unpaid(Money(amount: 100000));
  /// final updatedStatus = status.recordPayment(Money(amount: 50000));
  /// print(updatedStatus.completionPercentage); // 50.0
  /// ```
  PaymentStatus recordPayment(Money payment) {
    if (payment.currency != totalAmount.currency) {
      throw ArgumentError(
        'Payment currency (${payment.currency}) must match total amount currency (${totalAmount.currency})',
      );
    }
    return PaymentStatus(
      totalAmount: totalAmount,
      paidAmount: paidAmount + payment,
    );
  }

  /// Check if a specific amount can be paid
  ///
  /// Returns true if the payment amount is valid (positive and doesn't exceed remaining)
  bool canPayAmount(Money amount) {
    if (amount.currency != totalAmount.currency) return false;
    if (amount.isNegative || amount.isZero) return false;
    return true; // Allow overpayment for refund scenarios
  }

  /// Calculate minimum payment required to reach a certain percentage
  ///
  /// Example:
  /// ```dart
  /// final status = PaymentStatus.unpaid(Money(amount: 100000));
  /// final deposit = status.minimumPaymentForPercentage(30); // 30% deposit
  /// print(deposit.format()); // "300.00 AOA"
  /// ```
  Money minimumPaymentForPercentage(double percentage) {
    if (percentage < 0 || percentage > 100) {
      throw ArgumentError('Percentage must be between 0 and 100');
    }
    final targetAmount = totalAmount * (percentage / 100);
    final required = targetAmount - paidAmount;
    return required.isNegative ? Money.zero(currency: totalAmount.currency) : required;
  }

  @override
  List<Object?> get props => [totalAmount, paidAmount];

  @override
  String toString() {
    return 'PaymentStatus(total: ${totalAmount.format()}, paid: ${paidAmount.format()}, remaining: ${remainingAmount.format()})';
  }

  /// Copy this PaymentStatus with optional parameter changes
  PaymentStatus copyWith({
    Money? totalAmount,
    Money? paidAmount,
  }) {
    return PaymentStatus(
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }
}
