import 'package:flutter/foundation.dart';

/// Production-ready logger that only outputs in debug mode
///
/// All debug/info logs are stripped in release builds.
/// Error logs can optionally be sent to a crash reporting service.
class Log {
  /// Enable/disable verbose logging (useful for specific debugging)
  static bool verbose = false;

  /// Debug log - only in debug mode
  static void d(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }

  /// Info log - only in debug mode
  static void i(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  /// Warning log - only in debug mode
  static void w(String message) {
    if (kDebugMode) {
      debugPrint('[WARN] $message');
    }
  }

  /// Error log - always log errors, could be sent to crash reporting
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) debugPrint('  Error: $error');
      if (stackTrace != null) debugPrint('  Stack: $stackTrace');
    }
    // TODO: In production, send to crash reporting service (e.g., Firebase Crashlytics)
    // if (kReleaseMode) {
    //   FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
    // }
  }

  /// Verbose log - only when verbose mode is enabled in debug
  static void v(String message) {
    if (kDebugMode && verbose) {
      debugPrint('[VERBOSE] $message');
    }
  }

  /// Log a success message with emoji
  static void success(String message) {
    if (kDebugMode) {
      debugPrint('✅ $message');
    }
  }

  /// Log a warning message with emoji
  static void warn(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ $message');
    }
  }

  /// Log an error message with emoji
  static void fail(String message) {
    if (kDebugMode) {
      debugPrint('❌ $message');
    }
  }
}
