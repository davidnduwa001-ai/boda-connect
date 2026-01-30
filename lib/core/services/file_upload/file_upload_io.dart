import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'file_upload_interface.dart';

/// Factory function for conditional import
FileUploadHelper createFileUploadHelper() => FileUploadHelperIO();

/// IO (mobile) implementation of FileUploadHelper
/// Uses dart:io File and native compression
class FileUploadHelperIO implements FileUploadHelper {
  @override
  Future<UploadTask> uploadXFile({
    required Reference ref,
    required XFile file,
    SettableMetadata? metadata,
  }) async {
    final ioFile = File(file.path);
    return ref.putFile(ioFile, metadata);
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
    final ioFile = File(file.path);
    return await ioFile.length();
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
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxWidth,
        minHeight: maxHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      final ratio = (1 - (result.length / bytes.length)) * 100;
      debugPrint('✅ Image compressed: ${bytes.length ~/ 1024}KB -> ${result.length ~/ 1024}KB (${ratio.toStringAsFixed(1)}% reduction)');

      return result;
    } catch (e) {
      debugPrint('⚠️ Image compression failed, using original: $e');
      return bytes;
    }
  }

  @override
  bool get isCompressionSupported => true;

  /// Compress image file and return compressed File (IO-specific)
  /// Used for maintaining original mobile functionality
  Future<File?> compressImageFile(
    File file, {
    int maxWidth = 1920,
    int maxHeight = 1920,
    int quality = 85,
  }) async {
    try {
      final originalSize = await file.length();

      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: maxWidth,
        minHeight: maxHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        final compressedSize = await result.length();
        final ratio = (1 - (compressedSize / originalSize)) * 100;
        debugPrint('✅ Image compressed: ${originalSize ~/ 1024}KB -> ${compressedSize ~/ 1024}KB (${ratio.toStringAsFixed(1)}% reduction)');
        return File(result.path);
      }

      return file;
    } catch (e) {
      debugPrint('⚠️ Image compression failed, using original: $e');
      return file;
    }
  }
}
