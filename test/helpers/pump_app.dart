import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boda_connect/core/theme/app_theme.dart';

/// Helper extension for pumping widgets in tests
extension PumpApp on WidgetTester {
  /// Pumps a widget wrapped in MaterialApp with Riverpod
  Future<void> pumpApp(
    Widget widget, {
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: widget,
        ),
      ),
    );
  }

  /// Pumps a routed app for integration tests
  Future<void> pumpRoutedApp(
    Widget widget, {
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: widget),
        ),
      ),
    );
  }
}
