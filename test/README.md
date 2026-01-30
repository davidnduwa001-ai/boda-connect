# Test Suite Documentation

This folder contains all tests for the BODA CONNECT application following Clean Architecture principles.

## Test Structure

```
test/
├── unit/                    # Unit tests for business logic
│   ├── domain/              # Domain layer tests
│   │   ├── entities/        # Entity tests
│   │   └── usecases/        # Use case tests
│   ├── data/                # Data layer tests
│   │   ├── repositories/    # Repository implementation tests
│   │   └── datasources/     # Data source tests
│   └── core/                # Core utilities tests
│       ├── services/        # Service tests
│       └── providers/       # Riverpod provider tests
├── widget/                  # Widget tests for UI components
│   ├── auth/                # Auth screen tests
│   ├── supplier/            # Supplier feature tests
│   ├── client/              # Client feature tests
│   └── chat/                # Chat feature tests
├── integration/             # Integration tests for user flows
├── helpers/                 # Test helpers and utilities
└── fixtures/                # Test data fixtures
```

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run Specific Test File
```bash
flutter test test/unit/core/services/auth_service_test.dart
```

### Run Tests with Coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### Run Integration Tests
```bash
flutter test integration_test/
```

## Test Helpers

### Test Helpers (`helpers/test_helpers.dart`)
Common utilities for setting up mocks and test environment:

```dart
// Create fake Firestore
final firestore = createFakeFirestore();

// Create mock Auth
final auth = createMockAuth(signedIn: true);

// Create test provider container
final container = createTestProviderContainer(
  overrides: [
    authServiceProvider.overrideWithValue(mockAuthService),
  ],
);
```

### Mock Data (`helpers/test_helpers.dart`)
Predefined test data:

```dart
MockData.testUserId
MockData.testUserData
MockData.testSupplierData
MockData.testPackageData
MockData.testMessageData
MockData.testBookingData
```

### Pump App Helper (`helpers/pump_app.dart`)
Widget testing utilities:

```dart
// Pump a widget with MaterialApp
await tester.pumpApp(MyWidget());

// Pump with provider overrides
await tester.pumpApp(
  MyWidget(),
  overrides: [
    myProvider.overrideWithValue(mockValue),
  ],
);
```

## Writing Tests

### Unit Test Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

class MockRepository extends Mock implements MyRepository {}

void main() {
  late MyUseCase useCase;
  late MockRepository mockRepository;

  setUp(() {
    mockRepository = MockRepository();
    useCase = MyUseCase(mockRepository);
  });

  group('MyUseCase', () {
    test('should return data from repository', () async {
      // Arrange
      final expected = MyEntity(id: '1', name: 'Test');
      when(() => mockRepository.getData())
          .thenAnswer((_) async => Right(expected));

      // Act
      final result = await useCase(NoParams());

      // Assert
      expect(result, Right(expected));
      verify(() => mockRepository.getData()).called(1);
    });

    test('should return failure when repository fails', () async {
      // Arrange
      const failure = ServerFailure();
      when(() => mockRepository.getData())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(NoParams());

      // Assert
      expect(result, const Left(failure));
    });
  });
}
```

### Widget Test Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../docs/helpers/pump_app.dart';

void main() {
  testWidgets('MyWidget displays correctly', (tester) async {
    // Arrange & Act
    await tester.pumpApp(MyWidget());

    // Assert
    expect(find.text('Expected Text'), findsOneWidget);
    expect(find.byType(MyButton), findsOneWidget);
  });

  testWidgets('MyWidget interacts correctly', (tester) async {
    // Arrange
    await tester.pumpApp(MyWidget());

    // Act
    await tester.tap(find.byType(MyButton));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('After Click Text'), findsOneWidget);
  });
}
```

### Integration Test Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:boda_connect/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow', () {
    testWidgets('complete login flow', (tester) async {
      // Start app
      app.main();
      await tester.pumpAndSettle();

      // Enter phone number
      await tester.enterText(
        find.byType(TextField),
        '+244912345678',
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      // Enter OTP
      await tester.enterText(find.byType(TextField).first, '1');
      await tester.enterText(find.byType(TextField).at(1), '2');
      // ... enter all 6 digits

      // Verify navigation to home
      await tester.pumpAndSettle();
      expect(find.text('Bem-vindo'), findsOneWidget);
    });
  });
}
```

## Mocking Strategies

### Firebase Auth Mocking
```dart
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

final mockAuth = MockFirebaseAuth(
  signedIn: true,
  mockUser: MockUser(
    uid: 'test-uid',
    phoneNumber: '+244912345678',
  ),
);
```

### Firestore Mocking
```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

final fakeFirestore = FakeFirebaseFirestore();

// Add test data
await fakeFirestore.collection('users').doc('test-uid').set({
  'name': 'Test User',
  'phone': '+244912345678',
});
```

### Riverpod Provider Mocking
```dart
final container = ProviderContainer(
  overrides: [
    authProvider.overrideWith((ref) => MockAuthNotifier()),
    supplierProvider.overrideWith((ref) => MockSupplierNotifier()),
  ],
);
```

## Test Coverage Goals

- **Unit Tests**: 80%+ coverage for domain and data layers
- **Widget Tests**: All critical UI components
- **Integration Tests**: Major user flows (auth, booking, chat)

## Best Practices

1. **Arrange-Act-Assert (AAA)**: Structure tests clearly
2. **One assertion per test**: Keep tests focused
3. **Descriptive names**: Test names should describe behavior
4. **Mock external dependencies**: Don't rely on real Firebase
5. **Test edge cases**: Not just happy paths
6. **Use test helpers**: DRY principle for test setup
7. **Clean up**: Dispose mocks and containers in tearDown

## CI/CD Integration

Tests run automatically on:
- Every commit (GitHub Actions)
- Pull requests
- Pre-deployment checks

### GitHub Actions Workflow
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test --coverage
      - run: flutter test integration_test/
```

## Troubleshooting

### Common Issues

**Firebase initialization errors**:
```dart
// Use fake instances in tests, never initialize real Firebase
setupFirebaseAuthMocks();
setUpAll(() async {
  TestWidgetsFlutterBinding.ensureInitialized();
});
```

**Provider state not updating**:
```dart
// Always use pumpAndSettle() after state changes
await tester.tap(button);
await tester.pumpAndSettle(); // Wait for all animations
```

**Async test timeout**:
```dart
testWidgets('my test', (tester) async {
  // Increase timeout if needed
}, timeout: Timeout(Duration(minutes: 2)));
```

## Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Riverpod Testing](https://riverpod.dev/docs/cookbooks/testing)
- [Mocktail Package](https://pub.dev/packages/mocktail)
- [Integration Testing](https://docs.flutter.dev/testing/integration-tests)
