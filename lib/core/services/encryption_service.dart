import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Enterprise-grade encryption service for sensitive payment data
/// Implements AES-256 encryption with secure key management
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _secureStorage = const FlutterSecureStorage();
  static const String _keyStorageKey = 'boda_connect_encryption_key';
  static const String _ivStorageKey = 'boda_connect_encryption_iv';

  enc.Encrypter? _encrypter;
  enc.IV? _iv;
  bool _isInitialized = false;

  /// Initialize encryption with secure key generation
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Try to load existing key
      String? storedKey = await _secureStorage.read(key: _keyStorageKey);
      String? storedIV = await _secureStorage.read(key: _ivStorageKey);

      if (storedKey == null || storedIV == null) {
        // Generate new encryption key and IV
        final key = enc.Key.fromSecureRandom(32); // AES-256
        _iv = enc.IV.fromSecureRandom(16);

        // Store securely
        await _secureStorage.write(
          key: _keyStorageKey,
          value: base64.encode(key.bytes),
        );
        await _secureStorage.write(
          key: _ivStorageKey,
          value: base64.encode(_iv!.bytes),
        );

        _encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      } else {
        // Load existing key
        _encrypter = enc.Encrypter(enc.AES(enc.Key.fromBase64(storedKey), mode: enc.AESMode.cbc));
        _iv = enc.IV.fromBase64(storedIV);
      }

      _isInitialized = true;
      debugPrint('✅ Encryption service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing encryption: $e');
      rethrow;
    }
  }

  /// Encrypt sensitive data
  Future<String> encrypt(String plainText) async {
    if (!_isInitialized) await initialize();

    try {
      final encrypted = _encrypter!.encrypt(plainText, iv: _iv!);
      return encrypted.base64;
    } catch (e) {
      debugPrint('❌ Encryption error: $e');
      throw EncryptionException('Failed to encrypt data');
    }
  }

  /// Decrypt sensitive data
  Future<String> decrypt(String encryptedText) async {
    if (!_isInitialized) await initialize();

    try {
      final decrypted = _encrypter!.decrypt64(encryptedText, iv: _iv!);
      return decrypted;
    } catch (e) {
      debugPrint('❌ Decryption error: $e');
      throw EncryptionException('Failed to decrypt data');
    }
  }

  /// Hash sensitive data (one-way, for verification)
  String hash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Mask card number (show only last 4 digits)
  String maskCardNumber(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length < 4) return '****';
    final last4 = cleaned.substring(cleaned.length - 4);
    return '**** **** **** $last4';
  }

  /// Mask phone number
  String maskPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length < 4) return phone;
    final first3 = cleaned.substring(0, min(3, cleaned.length));
    return '+244 $first3 *** ***';
  }

  /// Mask account number (show only last 4 digits)
  String maskAccountNumber(String accountNumber) {
    final cleaned = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length < 4) return '****';
    final last4 = cleaned.substring(cleaned.length - 4);
    return '****.$last4';
  }

  /// Validate card number using Luhn algorithm
  bool validateCardNumber(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(cleaned)) {
      return false;
    }

    int sum = 0;
    bool alternate = false;

    for (int i = cleaned.length - 1; i >= 0; i--) {
      int digit = int.parse(cleaned[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  /// Validate IBAN (basic validation)
  bool validateIBAN(String iban) {
    final cleaned = iban.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    // Angola IBAN format: AO06 followed by 21 digits
    return RegExp(r'^AO\d{23}$').hasMatch(cleaned);
  }

  /// Clear all encryption keys (on logout)
  Future<void> clearKeys() async {
    try {
      await _secureStorage.delete(key: _keyStorageKey);
      await _secureStorage.delete(key: _ivStorageKey);
      _encrypter = null;
      _iv = null;
      _isInitialized = false;
      debugPrint('✅ Encryption keys cleared');
    } catch (e) {
      debugPrint('❌ Error clearing encryption keys: $e');
    }
  }

  int min(int a, int b) => a < b ? a : b;
}

class EncryptionException implements Exception {
  final String message;
  EncryptionException(this.message);

  @override
  String toString() => 'EncryptionException: $message';
}
