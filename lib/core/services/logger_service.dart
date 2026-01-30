import 'package:flutter/foundation.dart';

class Log {
  static void d(String message) => debugPrint('[DEBUG] $message');
  static void e(String message) => debugPrint('[ERROR] $message');
}
