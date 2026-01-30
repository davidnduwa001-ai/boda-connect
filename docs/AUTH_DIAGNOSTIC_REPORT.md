# 🔍 Authentication Diagnostic Report

## Issue Reported
User cannot connect with any authentication method.

---

## 🔥 Firebase Configuration Check

### 1. Firebase Initialization ✅
**Location**: `lib/main.dart:19-21`
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```
**Status**: ✅ Properly initialized before app runs

### 2. Firebase Options File ✅
**Location**: `lib/firebase_options.dart`
**Status**: ✅ File exists and configured for Android/iOS

### 3. Firestore Settings ✅
**Location**: `lib/main.dart:26-29`
```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```
**Status**: ✅ Offline persistence enabled

---

## 📱 Authentication Methods Analysis

### 1. Phone Authentication (SMS OTP) ⚠️

**Implementation**: `lib/features/auth/presentation/screens/phone_number_input_screen.dart:100-124`

**Code**:
```dart
await FirebaseAuth.instance.verifyPhoneNumber(
  phoneNumber: fullPhoneNumber,  // e.g., "+244923456789"
  timeout: const Duration(seconds: 60),
  verificationCompleted: (PhoneAuthCredential credential) async {
    await FirebaseAuth.instance.signInWithCredential(credential);
  },
  verificationFailed: (FirebaseAuthException e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message ?? 'SMS verification failed')),
    );
  },
  codeSent: (String verificationId, int? resendToken) {
    // Navigate to OTP screen
  },
  codeAutoRetrievalTimeout: (_) {},
);
```

**Potential Issues**:
- ❌ **Firebase Console**: Phone authentication may not be enabled
- ❌ **Test Phone Numbers**: No test numbers configured for development
- ❌ **App Verification**: SafetyNet/reCAPTCHA not configured
- ❌ **Quota**: SMS quota may be exhausted

**Firebase Console Requirements**:
1. Go to Firebase Console → Authentication → Sign-in method
2. Enable "Phone" provider
3. Add test phone numbers for development (e.g., +244923456789 with code 123456)
4. For Android: Add SHA-1/SHA-256 fingerprints in Project Settings
5. For iOS: Ensure APNs certificates are configured

---

### 2. WhatsApp Authentication (Twilio) ⚠️

**Implementation**: `lib/features/auth/presentation/screens/phone_number_input_screen.dart:78-94`

**Code**:
```dart
final success = await ref
    .read(whatsAppOTPProvider.notifier)
    .sendOTP(phone: fullPhoneNumber);
```

**Provider**: `lib/core/providers/whatsapp_auth_provider.dart`

**Potential Issues**:
- ❌ **Twilio Account**: Not configured or credentials missing
- ❌ **Twilio WhatsApp Sandbox**: Not activated
- ❌ **Cloud Functions**: Backend endpoint not deployed
- ❌ **API Keys**: Missing or expired Twilio credentials

**Twilio Requirements**:
1. Create Twilio account at twilio.com
2. Set up WhatsApp sandbox
3. Add test numbers to sandbox
4. Deploy Cloud Functions with Twilio credentials
5. Configure environment variables

---

### 3. Email Authentication ⚠️

**Service**: `lib/core/services/email_auth_service.dart`

**Sign Up Code**:
```dart
final userCredential = await _auth.createUserWithEmailAndPassword(
  email: email.trim(),
  password: password,
);

await user.updateDisplayName(name);
await user.sendEmailVerification();

await _firestore.collection('users').doc(user.uid).set({
  'email': email.trim(),
  'name': name,
  'authMethod': 'email',
  'emailVerified': false,
  'isActive': true,
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
});
```

**Sign In Code**:
```dart
final userCredential = await _auth.signInWithEmailAndPassword(
  email: email.trim(),
  password: password,
);
```

**Potential Issues**:
- ❌ **Firebase Console**: Email/Password authentication may not be enabled
- ❌ **Email Templates**: Verification emails not configured
- ❌ **SMTP**: Email delivery may be blocked

**Firebase Console Requirements**:
1. Go to Firebase Console → Authentication → Sign-in method
2. Enable "Email/Password" provider
3. Customize email templates in Authentication → Templates
4. Ensure authorized domains include your app domain

---

## 🚨 Common Issues & Solutions

### Issue 1: "User Not Found" After OTP Verification

**Root Cause**: User document not created in Firestore after authentication

**Solution**: The app creates user documents after successful authentication, but there's no explicit check in the current flow.

**Fix Needed**: Update OTP verification screen to ensure user document creation:

```dart
// After successful OTP verification
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  if (!userDoc.exists) {
    // Create user document
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'phone': widget.phone,
      'userType': widget.userType?.name ?? 'client',
      'authMethod': widget.isWhatsApp ? 'whatsapp' : 'phone',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
```

---

### Issue 2: "Network Error" or Timeout

**Root Causes**:
- Poor internet connection
- Firebase project not set up correctly
- API keys expired or invalid

**Solutions**:
1. Check internet connection
2. Verify Firebase project configuration
3. Regenerate `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
4. Run `flutter clean && flutter pub get`

---

### Issue 3: "Invalid Phone Number Format"

**Root Cause**: Phone number not formatted correctly for Firebase

**Current Implementation**: ✅ Already handles this correctly
```dart
String _normalizePhoneNumber() {
  final raw = _phoneController.text.trim();
  final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
  return '$_selectedCountryCode$digitsOnly';  // e.g., "+244923456789"
}
```

---

### Issue 4: "SMS Not Received"

**Root Causes**:
- SMS quota exhausted in Firebase (free tier: 10 SMS/day)
- Phone number blocked or invalid
- Test phone numbers not configured

**Solutions**:
1. Add test phone numbers in Firebase Console for development
2. Upgrade to Blaze plan for production SMS
3. Use WhatsApp authentication instead (no SMS quota)

---

## 🔧 Immediate Action Items

### Priority 1: Enable Authentication Methods in Firebase Console ⚠️

**Steps**:
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **boda-connect** (or similar)
3. Go to **Build → Authentication**
4. Click **Sign-in method** tab
5. Enable these providers:
   - ✅ Email/Password
   - ✅ Phone
6. For Phone authentication:
   - Click "Phone" → Enable
   - Add test phone number: `+244923456789` with code `123456`
   - Add test phone number: `+351923456789` with code `123456`

### Priority 2: Add SHA Fingerprints (Android) ⚠️

**Get Debug SHA-1**:
```bash
cd android
./gradlew signingReport
```

**Add to Firebase**:
1. Firebase Console → Project Settings → Your apps
2. Select Android app
3. Add SHA-1 and SHA-256 fingerprints
4. Download new `google-services.json`
5. Replace `android/app/google-services.json`

### Priority 3: Test with Test Phone Numbers First ✅

Before testing with real phone numbers, use Firebase test numbers:
1. In Firebase Console → Authentication → Sign-in method → Phone
2. Scroll to "Phone numbers for testing"
3. Add: `+244923456789` → Code: `123456`
4. Use this number in the app to bypass SMS

### Priority 4: Check Firebase Project Region ⚠️

Your Firestore is in **africa-south1** (Johannesburg), which is correct. Ensure:
1. Firebase Authentication is also using the same project
2. No region conflicts in configuration

---

## 📊 Authentication Flow Verification

### Current Flow (Phone/WhatsApp):

```
1. User enters phone number
   ↓
2. App calls Firebase.verifyPhoneNumber() or Twilio API
   ↓
3. SMS/WhatsApp sent to user
   ↓
4. User enters OTP code
   ↓
5. App verifies code with Firebase
   ↓
6. Firebase returns UserCredential
   ↓
7. ❌ MISSING: Check if user doc exists in Firestore
   ↓
8. ❌ MISSING: Create user doc if doesn't exist
   ↓
9. Navigate to home screen
```

### ⚠️ Critical Gap: User Document Creation

The OTP verification screen doesn't create the user document in Firestore after successful authentication. This is why you might see authentication success but then app crashes or shows errors.

---

## 🧪 Testing Checklist

### Email Authentication Test:
- [ ] Sign up with test email (e.g., `test@example.com`)
- [ ] Check Firebase Console → Authentication → Users
- [ ] Verify email sent (check spam folder)
- [ ] Sign in with same email
- [ ] Check Firestore → `users` collection for user document

### Phone Authentication Test (with test numbers):
- [ ] Enter test phone: `+244923456789`
- [ ] Enter test OTP: `123456`
- [ ] Check Firebase Console → Authentication → Users
- [ ] Check Firestore → `users` collection for user document

### WhatsApp Authentication Test:
- [ ] Ensure Twilio is configured
- [ ] Ensure Cloud Functions deployed
- [ ] Test with sandbox number
- [ ] Check logs in Cloud Functions console

---

## 🛠️ Recommended Fixes

### Fix 1: Update OTP Verification Screen

**File**: `lib/features/auth/presentation/screens/otp_verification_screen.dart`

**Add this after successful OTP verification**:

```dart
Future<void> _handleSuccessfulAuth() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    // Check if user document exists
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      // Create user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'phone': widget.phone,
        'userType': widget.userType?.name ?? 'client',
        'authMethod': widget.isWhatsApp ? 'whatsapp' : 'phone',
        'phoneVerified': true,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ User document created: ${user.uid}');
    } else {
      print('✅ User document already exists: ${user.uid}');
    }

    // Navigate to home or next screen
    if (mounted) {
      context.go('/home');  // or wherever you need to go
    }
  } catch (e) {
    print('❌ Error creating user document: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar perfil: $e')),
      );
    }
  }
}
```

### Fix 2: Add Proper Error Messages

**Current Issue**: Generic error messages don't help debug

**Solution**: Add specific error handling:

```dart
void _handleAuthError(FirebaseAuthException e) {
  String message;
  switch (e.code) {
    case 'invalid-verification-code':
      message = 'Código inválido. Verifique e tente novamente.';
      break;
    case 'invalid-phone-number':
      message = 'Número de telefone inválido.';
      break;
    case 'quota-exceeded':
      message = 'Limite de SMS excedido. Use números de teste ou tente mais tarde.';
      break;
    case 'captcha-check-failed':
      message = 'Verificação de segurança falhou. Tente novamente.';
      break;
    case 'too-many-requests':
      message = 'Muitas tentativas. Aguarde alguns minutos.';
      break;
    default:
      message = 'Erro: ${e.message}';
  }

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // Also log to console for debugging
  print('🔴 Auth Error [${e.code}]: ${e.message}');
}
```

---

## 📝 Quick Start Guide for Testing

### Option 1: Test with Email (Easiest)

1. Enable Email/Password in Firebase Console
2. Run the app
3. Go to Login → Email
4. Sign up with: `test@example.com` / `Test123!`
5. Check if you can sign in

### Option 2: Test with Phone (Test Numbers)

1. Enable Phone in Firebase Console
2. Add test phone: `+244923456789` → Code: `123456`
3. Run the app
4. Go to Login → Phone
5. Enter: `+244` and `923456789`
6. Enter OTP: `123456`
7. Should work without sending real SMS

### Option 3: Check Logs

Run the app with verbose logging:
```bash
flutter run -v
```

Watch for errors like:
- `[firebase_auth] Network error`
- `[firebase_auth] Invalid configuration`
- `[firebase_auth] User not found`

---

## 🎯 Most Likely Issues (Based on Symptoms)

### If you see "Network Error":
1. Check internet connection
2. Verify Firebase project is active
3. Check if API keys are valid
4. Regenerate Firebase config files

### If you see "Invalid Phone Number":
1. Ensure phone starts with `+` and country code
2. Check format: `+244923456789` (no spaces)
3. Verify country code is supported

### If you see "User Not Found" after login:
1. User document not created in Firestore
2. Apply Fix 1 above to create user documents

### If SMS never arrives:
1. Use test phone numbers (no SMS needed)
2. Check SMS quota in Firebase Console
3. Upgrade to Blaze plan for production

### If app crashes after authentication:
1. User document missing in Firestore
2. Missing fields in user model
3. Navigation error (check routes)

---

## 📞 Support Resources

- **Firebase Auth Docs**: https://firebase.google.com/docs/auth
- **Phone Auth Guide**: https://firebase.google.com/docs/auth/android/phone-auth
- **Common Errors**: https://firebase.google.com/docs/auth/admin/errors
- **Twilio WhatsApp**: https://www.twilio.com/docs/whatsapp

---

**Next Steps**:
1. Check Firebase Console configuration
2. Enable authentication methods
3. Add test phone numbers
4. Test with test numbers first
5. Apply Fix 1 if needed
6. Check logs for specific errors

Let me know what specific error messages you're seeing and I can provide more targeted solutions!
