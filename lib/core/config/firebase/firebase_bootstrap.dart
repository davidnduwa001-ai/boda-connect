import 'package:boda_connect/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseBootstrap {
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized successfully');
    } catch (e, stack) {
      debugPrint('❌ Firebase init failed');
      debugPrint(e.toString());
      debugPrint(stack.toString());
      rethrow;
    }
  }
}
