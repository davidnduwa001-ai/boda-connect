/// Platform-aware file upload helper
/// Uses conditional imports to select IO or Web implementation
///
/// Usage:
/// ```dart
/// final helper = fileUploadHelper;
/// final uploadTask = await helper.uploadXFile(ref: storageRef, file: xFile);
/// ```
library;

export 'file_upload_interface.dart';

import 'file_upload_interface.dart';
import 'file_upload_stub.dart'
    if (dart.library.io) 'file_upload_io.dart'
    if (dart.library.html) 'file_upload_web.dart';

/// Global singleton instance of the platform-specific file upload helper
final FileUploadHelper fileUploadHelper = createFileUploadHelper();
