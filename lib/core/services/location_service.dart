import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Reverse geocoding result containing address components
class ReverseGeocodingResult {
  final String? address;
  final String? city;
  final String? province;
  final String? neighborhood;
  final String? country;
  final String? displayName;
  final String? rawProvince; // Original province/state from API before normalization

  const ReverseGeocodingResult({
    this.address,
    this.city,
    this.province,
    this.neighborhood,
    this.country,
    this.displayName,
    this.rawProvince,
  });

  /// Check if location is in Angola
  bool get isInAngola => country?.toLowerCase().contains('angola') ?? false;

  @override
  String toString() => displayName ?? '$city, $province, $country';
}

/// Service for handling real-time location updates for users
class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if location services are enabled and permissions are granted
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Check permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Request location permission from the user
  Future<LocationPermission> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  /// Get the current device location
  Future<Position?> getCurrentLocation() async {
    final hasPermission = await checkLocationPermission();
    if (!hasPermission) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Update user location in Firestore (for clients)
  Future<bool> updateUserLocation() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final position = await getCurrentLocation();
      if (position == null) return false;

      await _firestore.collection('users').doc(userId).update({
        'location.geopoint': GeoPoint(
          position.latitude,
          position.longitude,
        ),
        'location.lastUpdated': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating user location: $e');
      return false;
    }
  }

  /// Update supplier location in Firestore
  Future<bool> updateSupplierLocation() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final position = await getCurrentLocation();
      if (position == null) return false;

      await _firestore.collection('suppliers').doc(userId).update({
        'location.geopoint': GeoPoint(
          position.latitude,
          position.longitude,
        ),
        'location.lastUpdated': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating supplier location: $e');
      return false;
    }
  }

  /// Calculate distance between two GeoPoints in meters
  double calculateDistance(GeoPoint point1, GeoPoint point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Calculate distance between two GeoPoints and return formatted string
  String getFormattedDistance(GeoPoint point1, GeoPoint point2) {
    final distanceInMeters = calculateDistance(point1, point2);

    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)}m';
    } else {
      final distanceInKm = distanceInMeters / 1000;
      return '${distanceInKm.toStringAsFixed(1)}km';
    }
  }

  /// Open app settings for location permissions
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings page
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Stream of position updates (for real-time tracking)
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100, // Update every 100 meters
      ),
    );
  }

  /// Check if user is within a certain radius of a location (in meters)
  bool isWithinRadius(GeoPoint userLocation, GeoPoint targetLocation, double radiusInMeters) {
    final distance = calculateDistance(userLocation, targetLocation);
    return distance <= radiusInMeters;
  }

  /// Reverse geocode coordinates to get address components
  /// Uses OpenStreetMap Nominatim API (free, no API key required)
  Future<ReverseGeocodingResult?> reverseGeocode(double latitude, double longitude) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&addressdetails=1&accept-language=pt',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'BodaConnect/1.0 (contact@bodaconnect.ao)',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        debugPrint('🗺️ Nominatim raw response: ${json.encode(address)}');

        if (address != null) {
          // Extract Angola-specific address components
          final city = address['city'] as String? ??
              address['town'] as String? ??
              address['municipality'] as String? ??
              address['village'] as String?;

          // Try multiple fields for province - Nominatim returns different fields for different locations
          final rawProvince = address['state'] as String? ??
              address['province'] as String? ??
              address['region'] as String? ??
              address['state_district'] as String? ??
              address['county'] as String?;

          debugPrint('🗺️ Raw province value: "$rawProvince"');

          final neighborhood = address['suburb'] as String? ??
              address['neighbourhood'] as String? ??
              address['district'] as String?;

          final road = address['road'] as String?;
          final country = address['country'] as String?;

          final normalizedProvince = _normalizeProvinceName(rawProvince);
          debugPrint('🗺️ Normalized province: "$normalizedProvince"');
          debugPrint('🗺️ Country: "$country"');

          return ReverseGeocodingResult(
            address: road,
            city: city,
            province: normalizedProvince,
            neighborhood: neighborhood,
            country: country,
            displayName: data['display_name'] as String?,
            rawProvince: rawProvince, // Keep original for debugging/display
          );
        }
      }

      debugPrint('Reverse geocoding failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
      return null;
    }
  }

  /// Normalize province name to match Angola's official province names
  String? _normalizeProvinceName(String? province) {
    if (province == null || province.isEmpty) return null;

    // Official Angola province names for matching
    final officialProvinces = [
      'Bengo',
      'Benguela',
      'Bié',
      'Cabinda',
      'Cuando Cubango',
      'Cunene',
      'Huambo',
      'Huíla',
      'Kwanza Norte',
      'Kwanza Sul',
      'Luanda',
      'Lunda Norte',
      'Lunda Sul',
      'Malanje',
      'Moxico',
      'Namibe',
      'Uíge',
      'Zaire',
    ];

    // Map common variations to official names (lowercase keys)
    final normalizations = {
      'luanda': 'Luanda',
      'benguela': 'Benguela',
      'huambo': 'Huambo',
      'huíla': 'Huíla',
      'huila': 'Huíla',
      'cabinda': 'Cabinda',
      'cunene': 'Cunene',
      'namibe': 'Namibe',
      'moçâmedes': 'Namibe',
      'mossamedes': 'Namibe',
      'bié': 'Bié',
      'bie': 'Bié',
      'moxico': 'Moxico',
      'cuando cubango': 'Cuando Cubango',
      'kuando kubango': 'Cuando Cubango',
      'cuando-cubango': 'Cuando Cubango',
      'lunda norte': 'Lunda Norte',
      'lunda-norte': 'Lunda Norte',
      'lunda sul': 'Lunda Sul',
      'lunda-sul': 'Lunda Sul',
      'malanje': 'Malanje',
      'malange': 'Malanje',
      'kwanza norte': 'Kwanza Norte',
      'kwanza-norte': 'Kwanza Norte',
      'cuanza norte': 'Kwanza Norte',
      'cuanza-norte': 'Kwanza Norte',
      'kwanza sul': 'Kwanza Sul',
      'kwanza-sul': 'Kwanza Sul',
      'cuanza sul': 'Kwanza Sul',
      'cuanza-sul': 'Kwanza Sul',
      'uíge': 'Uíge',
      'uige': 'Uíge',
      'zaire': 'Zaire',
      'bengo': 'Bengo',
    };

    // Clean and normalize input
    String cleaned = province.toLowerCase().trim();

    // Remove common prefixes that Nominatim might add
    final prefixesToRemove = [
      'província de ',
      'provincia de ',
      'province of ',
      'província do ',
      'provincia do ',
      'province ',
      'província ',
      'provincia ',
    ];

    for (final prefix in prefixesToRemove) {
      if (cleaned.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length).trim();
        break;
      }
    }

    // Try exact match first
    if (normalizations.containsKey(cleaned)) {
      return normalizations[cleaned];
    }

    // Try to find a matching official province by checking if the cleaned name contains it
    for (final official in officialProvinces) {
      final officialLower = official.toLowerCase();
      if (cleaned.contains(officialLower) || officialLower.contains(cleaned)) {
        return official;
      }
    }

    // Try removing diacritics for comparison
    final cleanedNoDiacritics = _removeDiacritics(cleaned);
    for (final entry in normalizations.entries) {
      if (_removeDiacritics(entry.key) == cleanedNoDiacritics) {
        return entry.value;
      }
    }

    debugPrint('⚠️ Province not normalized: "$province" (cleaned: "$cleaned")');
    return null; // Return null if we can't match to force manual selection
  }

  /// Remove diacritics from a string for fuzzy matching
  String _removeDiacritics(String input) {
    const diacritics = 'àáâãäåèéêëìíîïòóôõöùúûüýÿñç';
    const replacements = 'aaaaaaeeeeiiiiooooouuuuyync';

    String result = input;
    for (int i = 0; i < diacritics.length; i++) {
      result = result.replaceAll(diacritics[i], replacements[i]);
    }
    return result;
  }

  /// Get current location with reverse geocoding
  Future<({Position position, ReverseGeocodingResult? address})?> getCurrentLocationWithAddress() async {
    final position = await getCurrentLocation();
    if (position == null) return null;

    final address = await reverseGeocode(position.latitude, position.longitude);
    return (position: position, address: address);
  }
}
