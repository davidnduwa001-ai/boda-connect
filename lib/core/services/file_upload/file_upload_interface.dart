import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Platform-agnostic file upload interface
/// Abstracts dart:io File usage for web compatibility
abstract class FileUploadHelper {
  /// Upload file from XFile (cross-platform)
  Future<UploadTask> uploadXFile({
    required Reference ref,
    required XFile file,
    SettableMetadata? metadata,
  });

  /// Upload bytes directly
  Future<UploadTask> uploadBytes({
    required Reference ref,
    required Uint8List bytes,
    SettableMetadata? metadata,
  });

  /// Get file size from XFile
  Future<int> getFileSize(XFile file);

  /// Read file as bytes
  Future<Uint8List> readAsBytes(XFile file);

  /// Compress image if supported on platform
  /// Returns compressed bytes or original if compression unavailable
  Future<Uint8List> compressImageBytes(
    Uint8List bytes, {
    int maxWidth = 1920,
    int maxHeight = 1920,
    int quality = 85,
  });

  /// Check if image compression is available on this platform
  bool get isCompressionSupported;
}
