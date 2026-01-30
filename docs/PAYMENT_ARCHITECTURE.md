# Payment Architecture - BODA CONNECT

## Overview

BODA CONNECT implements an **Uber/Lyft-style payment architecture** where payments are held in escrow and released to suppliers only after successful service completion. This ensures security and fairness for both clients and suppliers.

---

## 🏗️ Architecture Principles

### 1. **Escrow-Based Payment Flow**
Similar to Uber, Lyft, and Airbnb:
- **Payment Capture**: Client's payment is authorized but NOT immediately charged
- **Escrow Holding**: Funds are held securely during the booking period
- **Service Completion**: Payment is released to supplier after event completion
- **Dispute Resolution**: Funds remain in escrow during dispute resolution

### 2. **Multi-Stage Payment Support**
- **Deposit Payment**: Initial payment to secure booking (e.g., 30%)
- **Milestone Payments**: Additional payments before the event
- **Final Payment**: Remaining balance before or at event completion
- **Refund Handling**: Automated refunds for cancellations based on policy

### 3. **Security & Compliance**
- PCI DSS compliant payment processing
- Encryption of sensitive payment data
- Secure payment gateway integration
- Transaction logging and audit trail

---

## 📊 Payment Flow Diagram

```
CLIENT                    PLATFORM                  SUPPLIER
  |                          |                         |
  | 1. Request Booking       |                         |
  |------------------------->|                         |
  |                          |                         |
  | 2. Authorize Payment     |                         |
  |------------------------->|                         |
  |                          | [ESCROW]                |
  |                          | Funds Held              |
  |                          |                         |
  |                          | 3. Booking Confirmed    |
  |                          |------------------------>|
  |                          |                         |
  |                          | 4. Event Completed      |
  |                          |<------------------------|
  |                          |                         |
  |                          | 5. Release Payment      |
  |                          |------------------------>|
  |                          |                         |
  | 6. Review & Rate         |                         |
  |------------------------->|                         |
```

---

## 💳 Data Models

### BookingModel
Located in: `lib/core/models/booking_model.dart`

```dart
class BookingModel {
  final int totalPrice;           // Total booking price
  final int paidAmount;            // Amount paid so far
  final String currency;           // Currency (e.g., 'AOA', 'USD')
  final List<BookingPayment> payments;  // Payment history
  final BookingStatus status;      // Booking status
  // ... other fields
}
```

### BookingPayment
```dart
class BookingPayment {
  final String id;                 // Unique payment ID
  final int amount;                // Payment amount
  final String method;             // Payment method (card, mobile money, etc.)
  final String? reference;         // Transaction reference
  final DateTime paidAt;           // Payment timestamp
  final String? notes;             // Additional notes
}
```

### PaymentStatus (Value Object)
Located in: `lib/features/booking/domain/value_objects/payment_status.dart`

```dart
class PaymentStatus {
  final Money totalAmount;         // Total amount to be paid
  final Money paidAmount;          // Amount paid so far

  // Computed properties
  Money get remainingAmount;       // totalAmount - paidAmount
  bool get isFullyPaid;           // paidAmount >= totalAmount
  bool get isUnpaid;              // paidAmount == 0
  bool get isPartiallyPaid;       // 0 < paidAmount < totalAmount
  double get completionPercentage; // (paidAmount / totalAmount) * 100
}
```

---

## 🔄 Payment States & Transitions

### Booking Status Flow
```
PENDING
  ↓
  | Supplier confirms booking
  ↓
CONFIRMED
  ↓
  | Payment authorized (held in escrow)
  ↓
IN_PROGRESS
  ↓
  | Event completed successfully
  ↓
COMPLETED → [Release payment to supplier]
  ↓
  | Client reviews & rates
  ↓
FINALIZED
```

### Cancellation & Refund Flow
```
CONFIRMED/PENDING
  ↓
  | Client/Supplier cancels
  ↓
CANCELLED
  ↓
  | Check cancellation policy
  ↓
[Calculate refund amount]
  ↓
[Process refund to client]
  ↓
[Pay cancellation fee to supplier if applicable]
```

---

## 💰 Payment Methods

### Supported Methods
1. **Credit/Debit Cards** (Visa, Mastercard)
2. **Mobile Money** (M-Pesa, TigoPesa, etc.)
3. **Bank Transfer**
4. **USSD**
5. **Digital Wallets**

### Payment Method Model
Located in: `lib/core/models/payment_method_model.dart`

```dart
class PaymentMethodModel {
  final String id;
  final String supplierId;
  final PaymentMethodType type;    // card, mobile_money, bank_transfer
  final String displayName;
  final bool isDefault;
  final bool isVerified;
  // ... method-specific fields
}
```

---

## 🛡️ Escrow Implementation

### Key Features

1. **Payment Authorization (Not Capture)**
   - When booking is confirmed, payment is **authorized** but not charged
   - Funds are reserved on client's payment method
   - No money moves until event completion

2. **Holding Period**
   - Funds remain in escrow during booking period
   - Platform acts as intermediary
   - Both parties protected during this time

3. **Release Triggers**
   - **Automatic**: Event marked as completed + X days grace period
   - **Manual**: Admin review for disputed bookings
   - **Split Release**: Partial payments for milestone events

4. **Refund Scenarios**
   - **Full Refund**: Cancellation within policy window
   - **Partial Refund**: Late cancellation based on terms
   - **No Refund**: No-show or very late cancellation
   - **Dispute Refund**: Admin-decided amount

---

## 📋 Implementation Checklist

### Current Implementation ✅
- ✅ Booking model with payment fields
- ✅ Payment history tracking (BookingPayment list)
- ✅ PaymentStatus value object with business logic
- ✅ Payment method management for suppliers
- ✅ Booking status enum (pending, confirmed, completed, etc.)
- ✅ Multi-stage payment support (deposit, partial, full)

### To Be Implemented 🚧

#### High Priority
- [ ] **Payment Gateway Integration**
  - Integrate with payment provider (e.g., Stripe, PayStack, Flutterwave)
  - Implement payment authorization (not capture)
  - Add webhook handling for payment events

- [ ] **Escrow Service**
  - Create payment escrow service
  - Implement hold/capture/release logic
  - Add scheduled tasks for automatic release

- [ ] **Refund System**
  - Implement cancellation policy rules
  - Create refund calculation service
  - Add refund processing workflow

#### Medium Priority
- [ ] **Payment Security**
  - Add payment tokenization
  - Implement 3D Secure authentication
  - Add fraud detection rules

- [ ] **Payout System**
  - Create supplier payout schedule
  - Implement batch payout processing
  - Add payout notifications

- [ ] **Dispute Resolution**
  - Create dispute management system
  - Add admin dispute review interface
  - Implement evidence collection

#### Low Priority
- [ ] **Analytics & Reporting**
  - Payment success/failure rates
  - Revenue analytics dashboard
  - Supplier payout reports

- [ ] **Advanced Features**
  - Split payments (multiple cards)
  - Payment plans/installments
  - Currency conversion support

---

## 🔐 Security Considerations

### Data Protection
1. **Never store raw card numbers** - Use tokenization
2. **Encrypt sensitive data** - Payment references, bank details
3. **Use HTTPS only** - All payment API calls
4. **Log all transactions** - Audit trail for compliance

### Fraud Prevention
1. **Verify payment methods** - Micro-deposits or verification charges
2. **Rate limiting** - Prevent payment attempt abuse
3. **Suspicious activity detection** - Flag unusual patterns
4. **Two-factor authentication** - For large transactions

### Compliance
1. **PCI DSS Compliance** - Use certified payment gateways
2. **GDPR Compliance** - Handle payment data according to regulations
3. **Local Regulations** - Comply with Angolan financial laws
4. **Terms of Service** - Clear payment and refund policies

---

## 🔌 Payment Gateway Integration

### Recommended Providers for Angola

1. **Flutterwave**
   - Strong presence in Africa
   - Supports AOA (Angolan Kwanza)
   - Mobile money integration
   - Good developer docs

2. **PayStack**
   - Popular in African markets
   - Easy integration
   - Good fraud prevention
   - Supports multiple payment methods

3. **Stripe** (with Stripe Connect)
   - Global standard
   - Excellent documentation
   - Built-in escrow with Connect
   - May require currency conversion

### Integration Pattern
```dart
// Example payment authorization
Future<PaymentResult> authorizePayment({
  required String bookingId,
  required Money amount,
  required PaymentMethod method,
}) async {
  try {
    // 1. Create payment intent with gateway
    final intent = await paymentGateway.createPaymentIntent(
      amount: amount.cents,
      currency: amount.currency,
      metadata: {'bookingId': bookingId},
      captureMethod: 'manual', // Don't capture immediately
    );

    // 2. Confirm payment with client
    final result = await paymentGateway.confirmPayment(
      paymentIntentId: intent.id,
      paymentMethod: method.token,
    );

    // 3. Store payment record
    await bookingRepository.recordPayment(
      bookingId: bookingId,
      payment: BookingPayment(
        id: result.id,
        amount: amount.cents,
        method: method.type,
        reference: result.reference,
        paidAt: DateTime.now(),
      ),
    );

    return PaymentResult.success(result);
  } catch (e) {
    return PaymentResult.failure(e.toString());
  }
}

// Example payment release to supplier
Future<void> releasePaymentToSupplier({
  required String bookingId,
  required String supplierId,
}) async {
  // 1. Get payment intent
  final booking = await bookingRepository.getBooking(bookingId);
  final paymentIntent = booking.payments.last.reference;

  // 2. Capture payment
  await paymentGateway.capturePayment(paymentIntent);

  // 3. Transfer to supplier account
  await paymentGateway.createTransfer(
    destination: supplier.stripeAccountId,
    amount: calculateSupplierAmount(booking), // After platform fee
    currency: booking.currency,
  );

  // 4. Update booking status
  await bookingRepository.updateBooking(
    bookingId,
    {'status': BookingStatus.finalized},
  );
}
```

---

## 📊 Platform Revenue Model

### Commission Structure
- **Platform Fee**: 10-15% of booking total
- **Payment Processing Fee**: ~2.9% + fixed fee (gateway)
- **Supplier Receives**: 85-90% of booking total

### Fee Calculation
```dart
Money calculateSupplierPayout(Money totalAmount) {
  final platformFeePercentage = 0.12; // 12%
  final platformFee = totalAmount * platformFeePercentage;
  return totalAmount - platformFee;
}
```

---

## 📝 Testing Strategy

### Unit Tests
- Payment status calculations
- Refund amount calculations
- Commission calculations
- Payment validation logic

### Integration Tests
- Payment gateway integration
- Webhook handling
- Database transactions
- Payment state transitions

### Manual Testing
- End-to-end booking with payment
- Cancellation and refund flow
- Dispute resolution process
- Payout processing

---

## 🎯 Summary

The BODA CONNECT payment architecture follows industry best practices from companies like Uber, Lyft, and Airbnb:

1. **Escrow-based payments** protect both clients and suppliers
2. **Multi-stage payments** allow flexibility (deposits, installments)
3. **Automated payouts** after event completion
4. **Clear refund policies** based on cancellation timing
5. **Secure payment processing** with tokenization and encryption
6. **Comprehensive audit trail** for all transactions

This architecture ensures:
- ✅ Client protection until service delivery
- ✅ Supplier payment guarantee after completion
- ✅ Platform revenue through transparent fees
- ✅ Compliance with financial regulations
- ✅ Scalability for future growth

---

## 📚 Related Files

### Models
- `lib/core/models/booking_model.dart` - Booking and payment data
- `lib/core/models/payment_method_model.dart` - Payment methods
- `lib/features/booking/domain/value_objects/payment_status.dart` - Payment status logic
- `lib/features/booking/domain/value_objects/money.dart` - Money value object

### Repositories
- `lib/core/repositories/payment_method_repository.dart` - Payment method CRUD

### Providers
- `lib/core/providers/booking_provider.dart` - Booking state management
- `lib/core/providers/payment_method_provider.dart` - Payment method state

### Screens
- `lib/features/supplier/presentation/screens/payment_methods_screen.dart` - Manage payment methods
- `lib/features/supplier/presentation/screens/supplier_revenue_screen.dart` - Revenue tracking

---

**Last Updated**: 2026-01-21
**Version**: 1.0
**Status**: Architecture Defined - Implementation In Progress
