import 'package:boda_connect/core/services/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Provider for LocationService
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Provider for current location permission status
final locationPermissionProvider = FutureProvider<LocationPermission>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  return await locationService.requestLocationPermission();
});

/// Provider for current device position
final currentPositionProvider = FutureProvider<Position?>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  return await locationService.getCurrentLocation();
});

/// Provider for checking if location services are available
final hasLocationPermissionProvider = FutureProvider<bool>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  return await locationService.checkLocationPermission();
});
