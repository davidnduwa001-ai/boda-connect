# BODA CONNECT — Flutter + Firebase Starter (Clean Architecture)

This starter is **mobile-first** and organized using **Clean Architecture + Feature-first**.

## What’s included
- Clean architecture folders (`core/`, `features/`, `shared/`)
- Riverpod state management wiring
- GoRouter navigation wiring
- Firebase initialization placeholder (you will add your Firebase config files)
- Example `auth` feature fully layered (domain + data + presentation)
- Placeholders for client/supplier/chat/notifications/profile features
- L10n folder and mock data folder

## What you must do on your side (required)
1. Install Flutter SDK (3.22+ recommended) and Dart (comes with Flutter)
2. Create a Firebase project and add Android + iOS apps
3. Add Firebase config files:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
4. Run FlutterFire to generate `firebase_options.dart` (recommended):
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
5. Install packages:
   ```bash
   flutter pub get
   ```
6. Run:
   ```bash
   flutter run
   ```

## Notes
- This zip intentionally does **not** include your Firebase credentials.
- You can generate full platform folders by running `flutter create .` inside this folder
  **if you want the default Android/iOS scaffolding regenerated**. But this starter already
  includes a minimal platform scaffold so you can place Firebase config files.
