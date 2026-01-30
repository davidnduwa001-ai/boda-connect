# Payment Methods Security Documentation

## Overview

This document outlines the enterprise-grade security measures implemented for the BODA CONNECT payment methods system, specifically designed for Angola payment providers (Visa/Mastercard, Multicaixa Express, and Bank Transfers).

## Security Architecture

### 1. Encryption Service (`lib/core/services/encryption_service.dart`)

#### AES-256 Encryption
- **Algorithm**: AES (Advanced Encryption Standard) with 256-bit keys
- **Mode**: CBC (Cipher Block Chaining)
- **Key Management**: Secure storage using `FlutterSecureStorage`
- **IV (Initialization Vector)**: 16-byte random IV generated per encryption instance

#### Key Security Features:
- **Secure Key Generation**: Uses cryptographically secure random number generation
- **Key Persistence**: Keys stored in platform-specific secure storage:
  - **iOS**: Keychain
  - **Android**: KeyStore
  - **Windows**: Credential Manager
- **Automatic Initialization**: Keys generated on first use and persisted securely

#### Data Protection:
```dart
// Encrypt sensitive data before storage
final encrypted = await _encryptionService.encrypt(sensitiveData);

// Decrypt when needed for display
final decrypted = await _encryptionService.decrypt(encrypted);
```

### 2. Payment Method Validation

#### Credit Card Validation
- **Luhn Algorithm**: Full implementation for card number validation
- **Format Validation**: Checks card number length (13-19 digits)
- **CVV Validation**: 3-4 digit verification code validation
- **Expiry Validation**: MM/YY format with automatic formatting

```dart
bool isValid = _encryptionService.validateCardNumber(cardNumber);
```

#### Multicaixa Express Validation
- **Phone Number Format**: Angola-specific format (+244 9XX XXX XXX)
- **Length Validation**: Exactly 9 digits
- **Prefix Validation**: Must start with '9'

#### Bank Transfer Validation
- **IBAN Validation**: Angola-specific IBAN format (AO06 + 21 digits)
- **Account Number Validation**: Minimum 10 digits
- **Bank Validation**: Only approved Angola banks (BAI, BFA, BIC, Atlântico)

### 3. Data Masking

All sensitive payment information is masked when displayed:

#### Credit Cards
```
Display: **** **** **** 4532
Stored: Last 4 digits only
```

#### Multicaixa Express
```
Display: +244 923 *** ***
Stored: Full phone number (encrypted)
```

#### Bank Accounts
```
Display: ****.1234
Stored: Full account number (encrypted)
```

### 4. Firestore Security Rules

Comprehensive security rules ensure payment methods are protected at the database level:

#### Access Control
- **Read**: Only the supplier owner can read their payment methods
- **Create**: Only authenticated users who own the supplier profile
- **Update**: Only the supplier owner, with validation
- **Delete**: Only the supplier owner

#### Data Validation Rules
```javascript
// Required fields validation
request.resource.data.keys().hasAll([
  'supplierId',
  'type',
  'displayName',
  'details',
  'isDefault',
  'createdAt',
  'updatedAt'
])

// Type validation
request.resource.data.type in ['creditCard', 'multicaixaExpress', 'bankTransfer']

// Prevent supplierId tampering
request.resource.data.supplierId == resource.data.supplierId
```

#### Helper Functions
```javascript
function ownsPaymentMethod() {
  return request.auth != null &&
    exists(/databases/$(database)/documents/suppliers/$(resource.data.supplierId)) &&
    isSupplierOwner(resource.data.supplierId);
}
```

### 5. Application-Level Security

#### State Management Protection
- **Riverpod StateNotifier**: Immutable state management
- **Error Handling**: Comprehensive try-catch blocks
- **Loading States**: Prevents race conditions
- **Validation**: All operations validated before execution

#### Network Security
- **HTTPS Only**: All Firebase communication over TLS 1.3
- **Certificate Pinning**: Firebase SDK handles certificate validation
- **Token Refresh**: Automatic Firebase Auth token refresh

#### UI Security Measures
- **CVV Obscuring**: CVV field uses `obscureText: true`
- **No Autocomplete**: Sensitive fields disable autocomplete
- **Input Formatters**: Automatic formatting prevents invalid input
- **Real-time Validation**: Immediate feedback on invalid input

### 6. Data Storage Security

#### What Gets Stored

**Credit Cards**:
```dart
{
  'lastFour': '4532',           // Last 4 digits only
  'cardType': 'Visa',           // Card brand
  'expiryMonth': '12',          // Expiry month
  'expiryYear': '25'            // Expiry year (2-digit)
}
// Full card number is NEVER stored
```

**Multicaixa Express**:
```dart
{
  'phone': '923456789',         // Full phone (can be encrypted)
  'accountName': 'João Silva'   // Account holder name
}
```

**Bank Transfer**:
```dart
{
  'bankName': 'BAI',            // Bank name
  'accountNumber': 'xxx',       // Full account (can be encrypted)
  'accountName': 'João Silva',  // Account holder name
  'iban': 'AO06xxx'            // IBAN if provided (optional)
}
```

#### What's NEVER Stored
- **Full credit card numbers** (only last 4 digits)
- **CVV codes** (never stored anywhere)
- **Full PIN codes**
- **Passwords or access codes**

### 7. PCI DSS Compliance Considerations

While BODA CONNECT doesn't directly process payments, the implementation follows PCI DSS principles:

#### Requirement 1: Install and maintain network security
✅ Firebase provides enterprise-grade network security

#### Requirement 2: Don't use vendor-supplied defaults
✅ All Firebase security rules are custom-configured

#### Requirement 3: Protect stored cardholder data
✅ Only last 4 digits stored, full numbers never persisted
✅ Encryption for sensitive data
✅ Data masking in UI

#### Requirement 4: Encrypt transmission of cardholder data
✅ TLS 1.3 for all network communication
✅ Firebase handles encryption in transit

#### Requirement 5: Use and regularly update anti-virus software
⚠️ User device responsibility

#### Requirement 6: Develop and maintain secure systems
✅ Regular Flutter/Firebase SDK updates
✅ Comprehensive input validation
✅ Secure coding practices

#### Requirement 7: Restrict access to cardholder data
✅ Firestore security rules enforce access control
✅ Only supplier owner can access their payment methods

#### Requirement 8: Assign unique ID to each person with access
✅ Firebase Authentication provides unique UIDs

#### Requirement 9: Restrict physical access to cardholder data
⚠️ User device security responsibility

#### Requirement 10: Track and monitor all access
✅ Firebase Firestore audit logs
✅ Debug logging for development

#### Requirement 11: Regularly test security systems
⚠️ Requires ongoing security audits

#### Requirement 12: Maintain information security policy
✅ This documentation serves as security policy

### 8. Security Best Practices Implemented

#### Input Sanitization
```dart
// Remove all non-digit characters from card numbers
final cleaned = cardNumber.replaceAll(RegExp(r'\D'), '');

// Limit input length
LengthLimitingTextInputFormatter(16)

// Only allow specific characters
FilteringTextInputFormatter.digitsOnly
```

#### Secure Form Handling
```dart
// Form validation before submission
if (!_formKey.currentState!.validate()) return;

// Loading state prevents double submission
setState(() => _isLoading = true);

// Always check mounted before showing UI feedback
if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```

#### Error Handling
```dart
try {
  // Operation
} catch (e) {
  debugPrint('❌ Error: $e');
  // Never expose internal errors to users
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Erro ao processar')),
  );
}
```

### 9. Security Checklist for Deployment

Before production deployment, ensure:

- [ ] Firebase Security Rules deployed to production
- [ ] `flutter_secure_storage` tested on all platforms
- [ ] Encryption service properly initialized on app start
- [ ] All API keys stored in environment variables (not hardcoded)
- [ ] Firebase App Check enabled for abuse prevention
- [ ] Rate limiting configured in Firebase
- [ ] Backup and recovery procedures tested
- [ ] Security audit performed
- [ ] Privacy policy updated to reflect payment data handling
- [ ] Terms of service include payment security disclaimers

### 10. Ongoing Security Maintenance

#### Regular Updates
- Update Flutter SDK monthly
- Update Firebase packages with security patches
- Review and update Firestore security rules quarterly

#### Monitoring
- Monitor Firebase Console for suspicious activity
- Review Firestore usage patterns
- Check for failed authentication attempts
- Monitor error logs for security issues

#### Incident Response
1. Identify and isolate the issue
2. Revoke compromised credentials immediately
3. Notify affected users
4. Document the incident
5. Update security measures
6. Post-incident review

### 11. Additional Security Recommendations

#### For Production
1. **Enable Firebase App Check**: Prevents abuse from unauthorized clients
2. **Implement Rate Limiting**: Prevent brute force attacks
3. **Add 2FA for Sensitive Operations**: Optional PIN for payment method changes
4. **Regular Security Audits**: Hire security professionals
5. **Bug Bounty Program**: Encourage responsible disclosure
6. **DDoS Protection**: Use Cloudflare or similar
7. **Logging and Alerting**: Real-time security event monitoring

#### For Users
1. **Strong Password Requirements**: Enforce minimum password complexity
2. **Session Management**: Automatic logout after inactivity
3. **Device Verification**: Optional device registration
4. **Email Notifications**: Alert on payment method changes
5. **Biometric Authentication**: Optional fingerprint/face unlock

## Contact

For security concerns or to report vulnerabilities:
- Email: security@bodaconnect.ao
- Please allow 48 hours for response
- Use responsible disclosure practices

---

**Last Updated**: 2026-01-21
**Version**: 1.0
**Reviewed By**: Development Team
