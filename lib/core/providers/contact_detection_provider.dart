import 'package:boda_connect/core/services/contact_detection_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for ContactDetectionService
final contactDetectionServiceProvider = Provider<ContactDetectionService>((ref) {
  throw UnimplementedError('Use ContactDetectionService.analyzeMessage() directly');
});

/// Provider for analyzing a specific message
/// Usage: ref.read(analyzeMessageProvider('message text'))
final analyzeMessageProvider = Provider.family<ContactDetectionService, String>(
  (ref, message) {
    return ContactDetectionService.analyzeMessage(message);
  },
);
