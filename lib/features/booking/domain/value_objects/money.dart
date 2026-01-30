import 'package:equatable/equatable.dart';

/// Value Object representing monetary value
///
/// This encapsulates the amount and currency, ensuring that money is always
/// handled consistently throughout the application. It prevents mixing different
/// currencies and provides utility methods for common operations.
///
/// Following Domain-Driven Design principles, this is an immutable value object.
class Money extends Equatable {
  /// The amount in the smallest currency unit (e.g., cents, centavos)
  /// For AOA (Angolan Kwanza), this represents centimos
  final int amount;

  /// The currency code (ISO 4217 standard)
  /// Default is 'AOA' (Angolan Kwanza)
  final String currency;

  const Money({
    required this.amount,
    this.currency = 'AOA',
  });

  /// Creates a Money object with zero amount
  const Money.zero({String currency = 'AOA'})
      : amount = 0,
        currency = currency;

  /// Creates Money from a decimal value
  ///
  /// Example:
  /// ```dart
  /// final price = Money.fromDecimal(100.50); // 100.50 AOA = 10050 centimos
  /// ```
  factory Money.fromDecimal(double value, {String currency = 'AOA'}) {
    return Money(
      amount: (value * 100).round(),
      currency: currency,
    );
  }

  /// Convert to decimal representation
  ///
  /// Example:
  /// ```dart
  /// final money = Money(amount: 10050, currency: 'AOA');
  /// print(money.toDecimal()); // 100.50
  /// ```
  double toDecimal() => amount / 100.0;

  /// Check if this amount is zero
  bool get isZero => amount == 0;

  /// Check if this amount is positive
  bool get isPositive => amount > 0;

  /// Check if this amount is negative
  bool get isNegative => amount < 0;

  /// Add two Money values
  ///
  /// Throws [ArgumentError] if currencies don't match
  Money operator +(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Cannot add different currencies: $currency and ${other.currency}',
      );
    }
    return Money(amount: amount + other.amount, currency: currency);
  }

  /// Subtract two Money values
  ///
  /// Throws [ArgumentError] if currencies don't match
  Money operator -(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Cannot subtract different currencies: $currency and ${other.currency}',
      );
    }
    return Money(amount: amount - other.amount, currency: currency);
  }

  /// Multiply money by a scalar value
  Money operator *(num multiplier) {
    return Money(
      amount: (amount * multiplier).round(),
      currency: currency,
    );
  }

  /// Divide money by a scalar value
  Money operator /(num divisor) {
    if (divisor == 0) {
      throw ArgumentError('Cannot divide by zero');
    }
    return Money(
      amount: (amount / divisor).round(),
      currency: currency,
    );
  }

  /// Compare if this Money is greater than another
  bool operator >(Money other) {
    _ensureSameCurrency(other);
    return amount > other.amount;
  }

  /// Compare if this Money is greater than or equal to another
  bool operator >=(Money other) {
    _ensureSameCurrency(other);
    return amount >= other.amount;
  }

  /// Compare if this Money is less than another
  bool operator <(Money other) {
    _ensureSameCurrency(other);
    return amount < other.amount;
  }

  /// Compare if this Money is less than or equal to another
  bool operator <=(Money other) {
    _ensureSameCurrency(other);
    return amount <= other.amount;
  }

  /// Ensure both Money objects have the same currency
  void _ensureSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Cannot compare different currencies: $currency and ${other.currency}',
      );
    }
  }

  /// Format money as a readable string
  ///
  /// Example:
  /// ```dart
  /// final money = Money(amount: 10050, currency: 'AOA');
  /// print(money.format()); // "100.50 AOA"
  /// ```
  String format({bool showCurrency = true}) {
    final decimal = toDecimal();
    final formatted = decimal.toStringAsFixed(2);
    return showCurrency ? '$formatted $currency' : formatted;
  }

  /// Format with compact notation for large amounts
  ///
  /// Example:
  /// ```dart
  /// final money = Money(amount: 150000000, currency: 'AOA');
  /// print(money.formatCompact()); // "1.5M AOA"
  /// ```
  String formatCompact() {
    final decimal = toDecimal();
    if (decimal >= 1000000) {
      return '${(decimal / 1000000).toStringAsFixed(1)}M $currency';
    } else if (decimal >= 1000) {
      return '${(decimal / 1000).toStringAsFixed(0)}K $currency';
    }
    return format();
  }

  @override
  List<Object?> get props => [amount, currency];

  @override
  String toString() => format();

  /// Copy this Money with optional parameter changes
  Money copyWith({
    int? amount,
    String? currency,
  }) {
    return Money(
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
    );
  }
}
