import 'package:boda_connect/features/booking/domain/entities/booking_entity.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_status.dart';
import 'package:boda_connect/features/booking/domain/value_objects/booking_date.dart';
import 'package:boda_connect/features/booking/domain/value_objects/money.dart';
import 'package:boda_connect/features/booking/domain/value_objects/payment_status.dart';
import 'package:boda_connect/core/models/supplier_model.dart';
import 'package:boda_connect/core/services/tier_service.dart';

/// Domain Service for complex booking business logic
///
/// Domain services contain business logic that doesn't naturally fit within
/// a single entity or value object. They operate on multiple entities or
/// perform calculations that span domain concepts.
///
/// This is different from use cases - domain services contain pure business
/// logic, while use cases orchestrate operations and interact with repositories.
class BookingDomainService {
  /// Calculate refund amount based on cancellation timing
  ///
  /// Business rules:
  /// - More than 30 days before event: 100% refund
  /// - 15-30 days before event: 75% refund
  /// - 7-14 days before event: 50% refund
  /// - Less than 7 days: 25% refund
  /// - Same day or past: No refund
  ///
  /// Returns the refund amount as Money
  Money calculateRefundAmount(BookingEntity booking) {
    final bookingDate = BookingDate(eventDate: booking.eventDate);
    final paidAmount = Money(amount: booking.paidAmount, currency: booking.currency);

    // No refund if event has passed
    if (bookingDate.isPast || bookingDate.isToday) {
      return Money.zero(currency: booking.currency);
    }

    final daysUntilEvent = bookingDate.daysUntilEvent;

    // Calculate refund percentage based on days until event
    final refundPercentage = _getRefundPercentage(daysUntilEvent);

    // Calculate refund amount
    return paidAmount * (refundPercentage / 100);
  }

  /// Get refund percentage based on days until event
  double _getRefundPercentage(int daysUntilEvent) {
    if (daysUntilEvent > 30) return 100.0;
    if (daysUntilEvent >= 15) return 75.0;
    if (daysUntilEvent >= 7) return 50.0;
    if (daysUntilEvent >= 1) return 25.0;
    return 0.0;
  }

  /// Calculate penalty fee for cancellation
  ///
  /// Returns the penalty amount (amount that won't be refunded)
  Money calculateCancellationPenalty(BookingEntity booking) {
    final paidAmount = Money(amount: booking.paidAmount, currency: booking.currency);
    final refundAmount = calculateRefundAmount(booking);
    return paidAmount - refundAmount;
  }

  /// Determine if automatic confirmation should occur
  ///
  /// Business rule: Automatically confirm bookings when:
  /// 1. Payment is >= 30% of total
  /// 2. Booking is still in pending status
  /// 3. Event date is more than 7 days away
  bool shouldAutoConfirm(BookingEntity booking) {
    // Must be pending
    if (booking.status != BookingStatus.pending) {
      return false;
    }

    // Check payment threshold
    final paymentStatus = PaymentStatus(
      totalAmount: Money(amount: booking.totalAmount, currency: booking.currency),
      paidAmount: Money(amount: booking.paidAmount, currency: booking.currency),
    );

    if (paymentStatus.completionPercentage < 30.0) {
      return false;
    }

    // Check date
    final bookingDate = BookingDate(eventDate: booking.eventDate);
    return bookingDate.daysUntilEvent > 7;
  }

  /// Calculate suggested deposit amount (30% of total)
  Money calculateSuggestedDeposit(BookingEntity booking) {
    final totalAmount = Money(amount: booking.totalAmount, currency: booking.currency);
    return totalAmount * 0.30;
  }

  /// Calculate final payment amount (remaining balance)
  Money calculateFinalPayment(BookingEntity booking) {
    final paymentStatus = PaymentStatus(
      totalAmount: Money(amount: booking.totalAmount, currency: booking.currency),
      paidAmount: Money(amount: booking.paidAmount, currency: booking.currency),
    );
    return paymentStatus.remainingAmount;
  }

  /// Determine if booking is at risk of cancellation
  ///
  /// A booking is at risk if:
  /// 1. Status is pending and event is less than 30 days away
  /// 2. Status is confirmed but less than 70% paid and event is less than 14 days away
  bool isAtRiskOfCancellation(BookingEntity booking) {
    final bookingDate = BookingDate(eventDate: booking.eventDate);

    // Pending bookings close to event date
    if (booking.status == BookingStatus.pending && bookingDate.daysUntilEvent < 30) {
      return true;
    }

    // Confirmed but underpaid close to event date
    if (booking.status == BookingStatus.confirmed && bookingDate.daysUntilEvent < 14) {
      final paymentStatus = PaymentStatus(
        totalAmount: Money(amount: booking.totalAmount, currency: booking.currency),
        paidAmount: Money(amount: booking.paidAmount, currency: booking.currency),
      );
      return paymentStatus.completionPercentage < 70.0;
    }

    return false;
  }

  /// Generate payment schedule recommendations
  ///
  /// Suggests when payments should be made based on event date
  List<PaymentMilestone> generatePaymentSchedule(BookingEntity booking) {
    final bookingDate = BookingDate(eventDate: booking.eventDate);
    final totalAmount = Money(amount: booking.totalAmount, currency: booking.currency);
    final daysUntilEvent = bookingDate.daysUntilEvent;

    final milestones = <PaymentMilestone>[];

    // Immediate: 30% deposit
    milestones.add(PaymentMilestone(
      dueDate: DateTime.now(),
      amount: totalAmount * 0.30,
      description: 'Depósito inicial (30%)',
      isRequired: true,
    ));

    // Mid-point: Additional 40% (total 70%)
    if (daysUntilEvent > 30) {
      final midpointDate = booking.eventDate.subtract(Duration(days: daysUntilEvent ~/ 2));
      milestones.add(PaymentMilestone(
        dueDate: midpointDate,
        amount: totalAmount * 0.40,
        description: 'Pagamento intermediário (40%)',
        isRequired: false,
      ));
    }

    // Final: Remaining 30% (7 days before event)
    final finalPaymentDate = booking.eventDate.subtract(const Duration(days: 7));
    final remainingPercentage = 0.30;

    milestones.add(PaymentMilestone(
      dueDate: finalPaymentDate,
      amount: totalAmount * remainingPercentage,
      description: 'Pagamento final (${(remainingPercentage * 100).toInt()}%)',
      isRequired: true,
    ));

    return milestones;
  }

  /// Calculate commission for the platform based on supplier tier
  ///
  /// Commission rates based on tier:
  /// - Starter: 15%
  /// - Pro: 12%
  /// - Elite: 10%
  /// - Diamond: 8%
  Money calculatePlatformCommission(BookingEntity booking, {SupplierTier tier = SupplierTier.starter}) {
    if (booking.status != BookingStatus.completed) {
      return Money.zero(currency: booking.currency);
    }

    final totalAmount = Money(amount: booking.totalAmount, currency: booking.currency);
    final commissionRate = TierBenefits.forTier(tier).commissionRate / 100;
    return totalAmount * commissionRate;
  }

  /// Calculate supplier earnings (total minus commission)
  Money calculateSupplierEarnings(BookingEntity booking, {SupplierTier tier = SupplierTier.starter}) {
    final totalAmount = Money(amount: booking.totalAmount, currency: booking.currency);
    final commission = calculatePlatformCommission(booking, tier: tier);
    return totalAmount - commission;
  }

  /// Get commission rate for a supplier tier (as percentage)
  double getCommissionRateForTier(SupplierTier tier) {
    return TierBenefits.forTier(tier).commissionRate;
  }

  /// Determine urgency level of a booking
  ///
  /// Returns a value from 0-4:
  /// 0 = Low urgency
  /// 1 = Normal
  /// 2 = Important
  /// 3 = Urgent
  /// 4 = Critical
  int calculateUrgencyLevel(BookingEntity booking) {
    final bookingDate = BookingDate(eventDate: booking.eventDate);
    final daysUntilEvent = bookingDate.daysUntilEvent;

    // Critical: Event is today or tomorrow
    if (daysUntilEvent <= 1) return 4;

    // Urgent: Event is within 3 days
    if (daysUntilEvent <= 3) return 3;

    // Important: Event is within 7 days
    if (daysUntilEvent <= 7) return 2;

    // Normal: Event is within 30 days
    if (daysUntilEvent <= 30) return 1;

    // Low: Event is more than 30 days away
    return 0;
  }

  /// Get urgency label in Portuguese
  String getUrgencyLabel(int urgencyLevel) {
    switch (urgencyLevel) {
      case 4:
        return 'Crítico';
      case 3:
        return 'Urgente';
      case 2:
        return 'Importante';
      case 1:
        return 'Normal';
      default:
        return 'Baixa Prioridade';
    }
  }

  /// @deprecated Server-side state machine is now authoritative.
  /// Status transitions are validated by Cloud Functions.
  /// This method is kept for backward compatibility but always returns true.
  /// The actual validation happens server-side in updateBookingStatus CF.
  ///
  /// DO NOT use this for security-critical decisions.
  @Deprecated('Server-side state machine is now authoritative. Use Cloud Functions.')
  bool isValidStatusTransition({
    required BookingStatus currentStatus,
    required BookingStatus newStatus,
  }) {
    // Server-side Cloud Function is now authoritative for status transitions.
    // Client validation is removed to prevent inconsistency.
    // The Cloud Function will reject invalid transitions.
    return true;
  }

  /// Compare two bookings by priority
  ///
  /// Returns negative if a has higher priority than b
  /// Returns positive if b has higher priority than a
  /// Returns 0 if equal priority
  int compareByPriority(BookingEntity a, BookingEntity b) {
    // First: Compare by urgency level (higher urgency = higher priority)
    final urgencyA = calculateUrgencyLevel(a);
    final urgencyB = calculateUrgencyLevel(b);

    if (urgencyA != urgencyB) {
      return urgencyB - urgencyA; // Higher urgency first
    }

    // Second: Compare by status priority
    final statusPriority = _getStatusPriority(a.status) - _getStatusPriority(b.status);
    if (statusPriority != 0) return statusPriority;

    // Third: Compare by event date (earlier first)
    return a.eventDate.compareTo(b.eventDate);
  }

  /// Get priority value for a status (lower = higher priority)
  int _getStatusPriority(BookingStatus status) {
    switch (status) {
      case BookingStatus.inProgress:
        return 1; // Highest priority
      case BookingStatus.confirmed:
        return 2;
      case BookingStatus.pending:
        return 3;
      case BookingStatus.disputed:
        return 4; // Disputes need attention
      case BookingStatus.completed:
        return 5;
      case BookingStatus.cancelled:
        return 6;
      case BookingStatus.rejected:
        return 6; // Same priority as cancelled
      case BookingStatus.refunded:
        return 7; // Lowest priority
    }
  }
}

/// Represents a payment milestone in the payment schedule
class PaymentMilestone {
  /// When this payment is due
  final DateTime dueDate;

  /// Amount to be paid
  final Money amount;

  /// Description of this milestone
  final String description;

  /// Whether this payment is required
  final bool isRequired;

  const PaymentMilestone({
    required this.dueDate,
    required this.amount,
    required this.description,
    this.isRequired = false,
  });

  /// Check if this milestone is overdue
  bool get isOverdue => DateTime.now().isAfter(dueDate);

  /// Days until this milestone is due
  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  @override
  String toString() {
    final date = BookingDate(eventDate: dueDate);
    return '$description - ${amount.format()} - Vence em ${date.formatDate()}';
  }
}
