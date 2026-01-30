import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'audit_service.dart';

/// Geolocation-based security service for detecting impossible travel
/// and suspicious login locations - Enterprise security feature
class GeolocationSecurityService {
  static final GeolocationSecurityService _instance =
      GeolocationSecurityService._internal();
  factory GeolocationSecurityService() => _instance;
  GeolocationSecurityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditService _auditService = AuditService();

  // Configuration
  static const double maxTravelSpeedKmh = 900; // Max realistic speed (airplane)
  static const int recentLoginWindowHours = 24;
  static const double suspiciousDistanceKm = 500; // Alert if >500km in short time

  /// Record login location for a user
  Future<void> recordLoginLocation({
    required String userId,
    required String sessionId,
    String? ipAddress,
    Position? position,
    String? country,
    String? city,
  }) async {
    try {
      final locationData = {
        'userId': userId,
        'sessionId': sessionId,
        'ipAddress': ipAddress,
        'latitude': position?.latitude,
        'longitude': position?.longitude,
        'accuracy': position?.accuracy,
        'country': country,
        'city': city,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('login_locations').add(locationData);
      debugPrint('📍 Login location recorded for user $userId');
    } catch (e) {
      debugPrint('❌ Failed to record login location: $e');
    }
  }

  /// Check for impossible travel (login from distant location in short time)
  Future<ImpossibleTravelResult> checkImpossibleTravel({
    required String userId,
    required double currentLatitude,
    required double currentLongitude,
  }) async {
    try {
      // Get recent login locations
      final recentLogins = await _firestore
          .collection('login_locations')
          .where('userId', isEqualTo: userId)
          .where('latitude', isNotEqualTo: null)
          .orderBy('latitude')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      if (recentLogins.docs.isEmpty) {
        return ImpossibleTravelResult(
          isSuspicious: false,
          reason: 'First login location recorded',
        );
      }

      for (final doc in recentLogins.docs) {
        final data = doc.data();
        final previousLat = data['latitude'] as double?;
        final previousLng = data['longitude'] as double?;
        final timestamp = data['timestamp'] as Timestamp?;

        if (previousLat == null || previousLng == null || timestamp == null) {
          continue;
        }

        final previousTime = timestamp.toDate();
        final timeDifferenceHours =
            DateTime.now().difference(previousTime).inMinutes / 60.0;

        if (timeDifferenceHours > recentLoginWindowHours) {
          continue; // Skip old logins
        }

        // Calculate distance using Haversine formula
        final distanceKm = _calculateDistanceKm(
          currentLatitude,
          currentLongitude,
          previousLat,
          previousLng,
        );

        // Calculate required speed
        final double requiredSpeedKmh =
            timeDifferenceHours > 0 ? distanceKm / timeDifferenceHours : 0.0;

        // Check if travel is impossible
        if (requiredSpeedKmh > maxTravelSpeedKmh) {
          final result = ImpossibleTravelResult(
            isSuspicious: true,
            reason:
                'Impossible travel detected: ${distanceKm.toStringAsFixed(0)}km in ${timeDifferenceHours.toStringAsFixed(1)}h (${requiredSpeedKmh.toStringAsFixed(0)}km/h required)',
            distanceKm: distanceKm,
            timeDifferenceHours: timeDifferenceHours,
            requiredSpeedKmh: requiredSpeedKmh,
            previousLocation: GeoPoint(previousLat, previousLng),
            previousCity: data['city'] as String?,
            previousCountry: data['country'] as String?,
          );

          // Log security event
          await _auditService.logSecurityEvent(
            userId: userId,
            eventType: SecurityEventType.suspiciousLogin,
            description: result.reason!,
            metadata: {
              'distanceKm': distanceKm,
              'timeDifferenceHours': timeDifferenceHours,
              'requiredSpeedKmh': requiredSpeedKmh,
              'previousLat': previousLat,
              'previousLng': previousLng,
              'currentLat': currentLatitude,
              'currentLng': currentLongitude,
            },
            severity: SecuritySeverity.critical,
          );

          return result;
        }

        // Check for suspicious but not impossible distance
        if (distanceKm > suspiciousDistanceKm && timeDifferenceHours < 2) {
          await _auditService.logSecurityEvent(
            userId: userId,
            eventType: SecurityEventType.suspiciousLogin,
            description:
                'Suspicious location change: ${distanceKm.toStringAsFixed(0)}km in ${timeDifferenceHours.toStringAsFixed(1)}h',
            metadata: {
              'distanceKm': distanceKm,
              'timeDifferenceHours': timeDifferenceHours,
            },
            severity: SecuritySeverity.warning,
          );

          return ImpossibleTravelResult(
            isSuspicious: true,
            reason:
                'Suspicious location change detected. Please verify your identity.',
            distanceKm: distanceKm,
            timeDifferenceHours: timeDifferenceHours,
            requiresVerification: true,
          );
        }
      }

      return ImpossibleTravelResult(
        isSuspicious: false,
        reason: 'Location check passed',
      );
    } catch (e) {
      debugPrint('❌ Failed to check impossible travel: $e');
      return ImpossibleTravelResult(
        isSuspicious: false,
        reason: 'Unable to verify location',
      );
    }
  }

  /// Get user's known locations (for profile display)
  Future<List<KnownLocation>> getKnownLocations(String userId) async {
    try {
      final locations = await _firestore
          .collection('login_locations')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      // Group by city/country and count
      final Map<String, KnownLocation> locationMap = {};

      for (final doc in locations.docs) {
        final data = doc.data();
        final city = data['city'] as String? ?? 'Unknown';
        final country = data['country'] as String? ?? 'Unknown';
        final key = '$city, $country';

        if (locationMap.containsKey(key)) {
          locationMap[key]!.loginCount++;
          final timestamp = data['timestamp'] as Timestamp?;
          if (timestamp != null &&
              timestamp.toDate().isAfter(locationMap[key]!.lastSeen)) {
            locationMap[key]!.lastSeen = timestamp.toDate();
          }
        } else {
          locationMap[key] = KnownLocation(
            city: city,
            country: country,
            latitude: data['latitude'] as double?,
            longitude: data['longitude'] as double?,
            firstSeen: (data['timestamp'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            lastSeen: (data['timestamp'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            loginCount: 1,
          );
        }
      }

      return locationMap.values.toList()
        ..sort((a, b) => b.loginCount.compareTo(a.loginCount));
    } catch (e) {
      debugPrint('❌ Failed to get known locations: $e');
      return [];
    }
  }

  /// Check if location is new for user
  Future<bool> isNewLocation({
    required String userId,
    required String? city,
    required String? country,
  }) async {
    if (city == null && country == null) return false;

    try {
      Query query = _firestore
          .collection('login_locations')
          .where('userId', isEqualTo: userId);

      if (city != null) {
        query = query.where('city', isEqualTo: city);
      }
      if (country != null) {
        query = query.where('country', isEqualTo: country);
      }

      final existing = await query.limit(1).get();
      return existing.docs.isEmpty;
    } catch (e) {
      debugPrint('❌ Failed to check new location: $e');
      return false;
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  double _calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Get current position with permission handling
  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('📍 Location services disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('📍 Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('📍 Location permission permanently denied');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('❌ Failed to get current position: $e');
      return null;
    }
  }
}

/// Result of impossible travel check
class ImpossibleTravelResult {
  final bool isSuspicious;
  final String? reason;
  final double? distanceKm;
  final double? timeDifferenceHours;
  final double? requiredSpeedKmh;
  final GeoPoint? previousLocation;
  final String? previousCity;
  final String? previousCountry;
  final bool requiresVerification;

  ImpossibleTravelResult({
    required this.isSuspicious,
    this.reason,
    this.distanceKm,
    this.timeDifferenceHours,
    this.requiredSpeedKmh,
    this.previousLocation,
    this.previousCity,
    this.previousCountry,
    this.requiresVerification = false,
  });
}

/// Known location for a user
class KnownLocation {
  final String city;
  final String country;
  final double? latitude;
  final double? longitude;
  final DateTime firstSeen;
  DateTime lastSeen;
  int loginCount;

  KnownLocation({
    required this.city,
    required this.country,
    this.latitude,
    this.longitude,
    required this.firstSeen,
    required this.lastSeen,
    required this.loginCount,
  });
}

/// GeoPoint for location data
class GeoPoint {
  final double latitude;
  final double longitude;

  GeoPoint(this.latitude, this.longitude);
}
