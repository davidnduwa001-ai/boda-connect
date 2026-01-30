
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'file_upload_interface.dart';

/// Factory function for conditional import
FileUploadHelper createFileUploadHelper() => FileUploadHelperWeb();

/// Web implementation of FileUploadHelper
/// Uses bytes-based upload (putData) since dart:io File is unavailable
class FileUploadHelperWeb implements FileUploadHelper {
  @override
  Future<UploadTask> uploadXFile({
    required Reference ref,
    required XFile file,
    SettableMetadata? metadata,
  }) async {
    // On web, we must read as bytes and use putData
    final bytes = await file.readAsBytes();
    return ref.putData(bytes, metadata);
  }

  @override
  Future<UploadTask> uploadBytes({
    required Reference ref,
    required Uint8List bytes,
    SettableMetadata? metadata,
  }) async {
    return ref.putData(bytes, metadata);
  }

  @override
  Future<int> getFileSize(XFile file) async {
    final bytes = await file.readAsBytes();
    return bytes.length;
  }

  @override
  Future<Uint8List> readAsBytes(XFile file) async {
    return await file.readAsBytes();
  }

  @override
  Future<Uint8List> compressImageBytes(
    Uint8List bytes, {
    int maxWidth = 1920,
    int maxHeight = 1920,
    int quality = 85,
  }) async {
    // flutter_image_compress does not support web
    // Return original bytes - compression happens server-side or via canvas API if needed
    debugPrint('ℹ️ Image compression not available on web, using original size');
    return bytes;
  }

  @override
  bool get isCompressionSupported => false;
}
