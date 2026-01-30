import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'audit_service.dart';

/// Device fingerprinting service for tracking trusted devices
/// Helps detect account takeover and unauthorized access
class DeviceFingerprintService {
  static final DeviceFingerprintService _instance =
      DeviceFingerprintService._internal();
  factory DeviceFingerprintService() => _instance;
  DeviceFingerprintService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final AuditService _auditService = AuditService();

  static const String _deviceIdKey = 'boda_device_id';
  static const String _deviceFingerprintKey = 'boda_device_fingerprint';

  String? _cachedDeviceId;
  DeviceFingerprint? _cachedFingerprint;

  /// Get or generate unique device ID
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    try {
      // Try to read existing device ID
      String? storedId = await _secureStorage.read(key: _deviceIdKey);

      if (storedId != null && storedId.isNotEmpty) {
        _cachedDeviceId = storedId;
        return storedId;
      }

      // Generate new device ID
      final fingerprint = await getDeviceFingerprint();
      final newId = _generateDeviceId(fingerprint);

      await _secureStorage.write(key: _deviceIdKey, value: newId);
      _cachedDeviceId = newId;

      return newId;
    } catch (e) {
      debugPrint('❌ Failed to get device ID: $e');
      // Generate a fallback ID
      final fallbackId =
          'fallback_${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().hashCode}';
      return fallbackId;
    }
  }

  /// Generate device fingerprint from hardware/software characteristics
  Future<DeviceFingerprint> getDeviceFingerprint() async {
    if (_cachedFingerprint != null) return _cachedFingerprint!;

    try {
      final packageInfo = await PackageInfo.fromPlatform();

      DeviceFingerprint fingerprint;

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        fingerprint = DeviceFingerprint(
          platform: 'android',
          model: androidInfo.model,
          manufacturer: androidInfo.manufacturer,
          brand: androidInfo.brand,
          device: androidInfo.device,
          osVersion: androidInfo.version.release,
          sdkVersion: androidInfo.version.sdkInt.toString(),
          isPhysicalDevice: androidInfo.isPhysicalDevice,
          androidId: androidInfo.id,
          appVersion: packageInfo.version,
          appBuildNumber: packageInfo.buildNumber,
          screenResolution: null, // Add if needed
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        fingerprint = DeviceFingerprint(
          platform: 'ios',
          model: iosInfo.model,
          manufacturer: 'Apple',
          brand: 'Apple',
          device: iosInfo.name,
          osVersion: iosInfo.systemVersion,
          sdkVersion: null,
          isPhysicalDevice: iosInfo.isPhysicalDevice,
          androidId: null,
          iosIdentifier: iosInfo.identifierForVendor,
          appVersion: packageInfo.version,
          appBuildNumber: packageInfo.buildNumber,
          screenResolution: null,
        );
      } else if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        fingerprint = DeviceFingerprint(
          platform: 'web',
          model: webInfo.browserName.name,
          manufacturer: webInfo.vendor ?? 'Unknown',
          brand: webInfo.browserName.name,
          device: webInfo.platform ?? 'Unknown',
          osVersion: webInfo.appVersion ?? 'Unknown',
          sdkVersion: null,
          isPhysicalDevice: true,
          androidId: null,
          userAgent: webInfo.userAgent,
          appVersion: packageInfo.version,
          appBuildNumber: packageInfo.buildNumber,
          screenResolution: null,
        );
      } else {
        fingerprint = DeviceFingerprint(
          platform: 'unknown',
          model: 'Unknown',
          manufacturer: 'Unknown',
          brand: 'Unknown',
          device: 'Unknown',
          osVersion: 'Unknown',
          sdkVersion: null,
          isPhysicalDevice: true,
          androidId: null,
          appVersion: packageInfo.version,
          appBuildNumber: packageInfo.buildNumber,
          screenResolution: null,
        );
      }

      _cachedFingerprint = fingerprint;
      return fingerprint;
    } catch (e) {
      debugPrint('❌ Failed to get device fingerprint: $e');
      return DeviceFingerprint.unknown();
    }
  }

  /// Generate unique device ID from fingerprint
  String _generateDeviceId(DeviceFingerprint fingerprint) {
    final data = '${fingerprint.platform}_${fingerprint.model}_'
        '${fingerprint.manufacturer}_${fingerprint.device}_'
        '${fingerprint.androidId ?? fingerprint.iosIdentifier ?? ''}_'
        '${DateTime.now().millisecondsSinceEpoch}';

    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 32);
  }

  /// Register device as trusted for a user
  Future<TrustedDevice> registerTrustedDevice({
    required String userId,
    String? deviceName,
  }) async {
    try {
      final deviceId = await getDeviceId();
      final fingerprint = await getDeviceFingerprint();

      final trustedDevice = TrustedDevice(
        deviceId: deviceId,
        userId: userId,
        deviceName: deviceName ?? _generateDeviceName(fingerprint),
        fingerprint: fingerprint,
        registeredAt: DateTime.now(),
        lastUsedAt: DateTime.now(),
        isTrusted: true,
      );

      await _firestore
          .collection('trusted_devices')
          .doc('${userId}_$deviceId')
          .set(trustedDevice.toMap());

      await _auditService.logSecurityEvent(
        userId: userId,
        eventType: SecurityEventType.multipleDeviceLogin,
        description: 'New trusted device registered: ${trustedDevice.deviceName}',
        metadata: {
          'deviceId': deviceId,
          'platform': fingerprint.platform,
          'model': fingerprint.model,
        },
        severity: SecuritySeverity.info,
      );

      debugPrint('✅ Trusted device registered: $deviceId');
      return trustedDevice;
    } catch (e) {
      debugPrint('❌ Failed to register trusted device: $e');
      rethrow;
    }
  }

  /// Check if current device is trusted for user
  Future<bool> isDeviceTrusted(String userId) async {
    try {
      final deviceId = await getDeviceId();
      final doc = await _firestore
          .collection('trusted_devices')
          .doc('${userId}_$deviceId')
          .get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      return data['isTrusted'] as bool? ?? false;
    } catch (e) {
      debugPrint('❌ Failed to check trusted device: $e');
      return false;
    }
  }

  /// Get all trusted devices for a user
  Future<List<TrustedDevice>> getTrustedDevices(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('trusted_devices')
          .where('userId', isEqualTo: userId)
          .where('isTrusted', isEqualTo: true)
          .orderBy('lastUsedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => TrustedDevice.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('❌ Failed to get trusted devices: $e');
      return [];
    }
  }

  /// Remove trusted device
  Future<void> removeTrustedDevice({
    required String userId,
    required String deviceId,
  }) async {
    try {
      await _firestore
          .collection('trusted_devices')
          .doc('${userId}_$deviceId')
          .update({
        'isTrusted': false,
        'revokedAt': FieldValue.serverTimestamp(),
      });

      await _auditService.logSecurityEvent(
        userId: userId,
        eventType: SecurityEventType.multipleDeviceLogin,
        description: 'Trusted device removed',
        metadata: {'deviceId': deviceId},
        severity: SecuritySeverity.info,
      );

      debugPrint('✅ Trusted device removed: $deviceId');
    } catch (e) {
      debugPrint('❌ Failed to remove trusted device: $e');
      rethrow;
    }
  }

  /// Update device last used timestamp
  Future<void> updateDeviceActivity({
    required String userId,
  }) async {
    try {
      final deviceId = await getDeviceId();
      await _firestore
          .collection('trusted_devices')
          .doc('${userId}_$deviceId')
          .update({
        'lastUsedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Failed to update device activity: $e');
    }
  }

  /// Check for device anomalies (fingerprint mismatch)
  Future<bool> hasDeviceAnomaly({
    required String userId,
  }) async {
    try {
      final deviceId = await getDeviceId();
      final currentFingerprint = await getDeviceFingerprint();

      final doc = await _firestore
          .collection('trusted_devices')
          .doc('${userId}_$deviceId')
          .get();

      if (!doc.exists) return false;

      final storedFingerprint =
          DeviceFingerprint.fromMap(doc.data()!['fingerprint'] as Map<String, dynamic>);

      // Check for significant changes
      if (storedFingerprint.platform != currentFingerprint.platform ||
          storedFingerprint.model != currentFingerprint.model ||
          storedFingerprint.manufacturer != currentFingerprint.manufacturer) {
        await _auditService.logSecurityEvent(
          userId: userId,
          eventType: SecurityEventType.suspiciousLogin,
          description: 'Device fingerprint mismatch detected',
          metadata: {
            'storedPlatform': storedFingerprint.platform,
            'currentPlatform': currentFingerprint.platform,
            'storedModel': storedFingerprint.model,
            'currentModel': currentFingerprint.model,
          },
          severity: SecuritySeverity.warning,
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Failed to check device anomaly: $e');
      return false;
    }
  }

  /// Generate human-readable device name
  String _generateDeviceName(DeviceFingerprint fingerprint) {
    if (fingerprint.platform == 'ios') {
      return '${fingerprint.model} (iOS ${fingerprint.osVersion})';
    } else if (fingerprint.platform == 'android') {
      return '${fingerprint.brand} ${fingerprint.model}';
    } else if (fingerprint.platform == 'web') {
      return '${fingerprint.brand} Browser';
    }
    return 'Unknown Device';
  }

  /// Clear cached data
  void clearCache() {
    _cachedDeviceId = null;
    _cachedFingerprint = null;
  }
}

/// Device fingerprint data
class DeviceFingerprint {
  final String platform;
  final String model;
  final String manufacturer;
  final String brand;
  final String device;
  final String osVersion;
  final String? sdkVersion;
  final bool isPhysicalDevice;
  final String? androidId;
  final String? iosIdentifier;
  final String? userAgent;
  final String appVersion;
  final String appBuildNumber;
  final String? screenResolution;

  DeviceFingerprint({
    required this.platform,
    required this.model,
    required this.manufacturer,
    required this.brand,
    required this.device,
    required this.osVersion,
    this.sdkVersion,
    required this.isPhysicalDevice,
    this.androidId,
    this.iosIdentifier,
    this.userAgent,
    required this.appVersion,
    required this.appBuildNumber,
    this.screenResolution,
  });

  factory DeviceFingerprint.unknown() => DeviceFingerprint(
        platform: 'unknown',
        model: 'Unknown',
        manufacturer: 'Unknown',
        brand: 'Unknown',
        device: 'Unknown',
        osVersion: 'Unknown',
        isPhysicalDevice: true,
        appVersion: '0.0.0',
        appBuildNumber: '0',
      );

  Map<String, dynamic> toMap() => {
        'platform': platform,
        'model': model,
        'manufacturer': manufacturer,
        'brand': brand,
        'device': device,
        'osVersion': osVersion,
        'sdkVersion': sdkVersion,
        'isPhysicalDevice': isPhysicalDevice,
        'androidId': androidId,
        'iosIdentifier': iosIdentifier,
        'userAgent': userAgent,
        'appVersion': appVersion,
        'appBuildNumber': appBuildNumber,
        'screenResolution': screenResolution,
      };

  factory DeviceFingerprint.fromMap(Map<String, dynamic> map) => DeviceFingerprint(
        platform: map['platform'] as String? ?? 'unknown',
        model: map['model'] as String? ?? 'Unknown',
        manufacturer: map['manufacturer'] as String? ?? 'Unknown',
        brand: map['brand'] as String? ?? 'Unknown',
        device: map['device'] as String? ?? 'Unknown',
        osVersion: map['osVersion'] as String? ?? 'Unknown',
        sdkVersion: map['sdkVersion'] as String?,
        isPhysicalDevice: map['isPhysicalDevice'] as bool? ?? true,
        androidId: map['androidId'] as String?,
        iosIdentifier: map['iosIdentifier'] as String?,
        userAgent: map['userAgent'] as String?,
        appVersion: map['appVersion'] as String? ?? '0.0.0',
        appBuildNumber: map['appBuildNumber'] as String? ?? '0',
        screenResolution: map['screenResolution'] as String?,
      );
}

/// Trusted device record
class TrustedDevice {
  final String deviceId;
  final String userId;
  final String deviceName;
  final DeviceFingerprint fingerprint;
  final DateTime registeredAt;
  final DateTime lastUsedAt;
  final bool isTrusted;

  TrustedDevice({
    required this.deviceId,
    required this.userId,
    required this.deviceName,
    required this.fingerprint,
    required this.registeredAt,
    required this.lastUsedAt,
    required this.isTrusted,
  });

  Map<String, dynamic> toMap() => {
        'deviceId': deviceId,
        'userId': userId,
        'deviceName': deviceName,
        'fingerprint': fingerprint.toMap(),
        'registeredAt': Timestamp.fromDate(registeredAt),
        'lastUsedAt': Timestamp.fromDate(lastUsedAt),
        'isTrusted': isTrusted,
      };

  factory TrustedDevice.fromMap(Map<String, dynamic> map) => TrustedDevice(
        deviceId: map['deviceId'] as String,
        userId: map['userId'] as String,
        deviceName: map['deviceName'] as String? ?? 'Unknown Device',
        fingerprint:
            DeviceFingerprint.fromMap(map['fingerprint'] as Map<String, dynamic>),
        registeredAt: (map['registeredAt'] as Timestamp).toDate(),
        lastUsedAt: (map['lastUsedAt'] as Timestamp).toDate(),
        isTrusted: map['isTrusted'] as bool? ?? false,
      );
}
