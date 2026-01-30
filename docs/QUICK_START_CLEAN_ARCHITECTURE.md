# 🚀 Quick Start: Clean Architecture in BODA CONNECT

## Overview

This project now follows **Clean Architecture** with clear separation between:
- **Domain** - Business logic (pure Dart, no dependencies)
- **Data** - Implementation details (Firebase, APIs)
- **Presentation** - UI and state management (Flutter, Riverpod)

---

## 📁 File Organization

```
lib/features/[feature]/
├── domain/              ← BUSINESS LOGIC (Pure Dart)
│   ├── entities/       ← Business objects
│   ├── repositories/   ← Interfaces (contracts)
│   └── usecases/       ← Business operations
├── data/               ← IMPLEMENTATION (Firebase, API)
│   ├── datasources/    ← Firebase/API calls
│   ├── models/         ← JSON serialization
│   └── repositories/   ← Concrete implementations
└── presentation/        ← UI (Flutter, Riverpod)
    ├── screens/
    ├── widgets/
    └── controllers/
```

---

## 🎯 Quick Examples

### Creating a New Feature

**1. Start with Domain Layer:**

```dart
// domain/entities/product_entity.dart
class ProductEntity extends Equatable {
  final String id;
  final String name;
  final double price;

  const ProductEntity({
    required this.id,
    required this.name,
    required this.price,
  });

  @override
  List<Object?> get props => [id, name, price];
}
```

**2. Define Repository Interface:**

```dart
// domain/repositories/product_repository.dart
abstract class ProductRepository {
  ResultFuture<ProductEntity> getProductById(String id);
  ResultFuture<List<ProductEntity>> getProducts();
  ResultFuture<ProductEntity> createProduct(ProductEntity product);
}
```

**3. Create Use Case:**

```dart
// domain/usecases/get_product_by_id.dart
class GetProductById {
  const GetProductById(this._repository);

  final ProductRepository _repository;

  ResultFuture<ProductEntity> call(String productId) {
    return _repository.getProductById(productId);
  }
}
```

**4. Implement Data Layer:**

```dart
// data/repositories/product_repository_impl.dart
class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remoteDataSource;

  ProductRepositoryImpl({required this.remoteDataSource});

  @override
  ResultFuture<ProductEntity> getProductById(String id) async {
    try {
      final product = await remoteDataSource.getProductById(id);
      return Right(product.toEntity());
    } on FirebaseException catch (e) {
      return Left(ServerFailure(e.message ?? 'Server error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
```

---

## 🔄 Error Handling Pattern

### Using Either<Failure, Success>

```dart
// In your provider/controller
final result = await getProductById('product-123');

result.fold(
  // Left = Failure
  (failure) {
    // Handle error
    state = state.copyWith(
      isLoading: false,
      error: failure.message,
    );
  },
  // Right = Success
  (product) {
    // Handle success
    state = state.copyWith(
      isLoading: false,
      product: product,
    );
  },
);
```

---

## 🧪 Testing Pattern

```dart
// test/unit/domain/usecases/get_product_by_id_test.dart
void main() {
  late GetProductById usecase;
  late MockProductRepository mockRepository;

  setUp(() {
    mockRepository = MockProductRepository();
    usecase = GetProductById(mockRepository);
  });

  test('should return product from repository', () async {
    // Arrange
    final product = ProductEntity(id: '1', name: 'Test', price: 99.99);
    when(() => mockRepository.getProductById('1'))
        .thenAnswer((_) async => Right(product));

    // Act
    final result = await usecase('1');

    // Assert
    expect(result, Right(product));
    verify(() => mockRepository.getProductById('1')).called(1);
  });

  test('should return failure when repository fails', () async {
    // Arrange
    const failure = ServerFailure('Not found');
    when(() => mockRepository.getProductById('1'))
        .thenAnswer((_) async => const Left(failure));

    // Act
    final result = await usecase('1');

    // Assert
    expect(result, const Left(failure));
  });
}
```

---

## 📝 Common Patterns

### Pattern 1: Simple UseCase (No Params)

```dart
class GetCurrentUser extends UseCaseWithoutParams<UserEntity> {
  final AuthRepository _repository;

  GetCurrentUser(this._repository);

  @override
  ResultFuture<UserEntity> call() {
    return _repository.getCurrentUser();
  }
}
```

### Pattern 2: UseCase with Params

```dart
class UpdateUserProfile extends UseCase<UserEntity, UpdateUserParams> {
  final UserRepository _repository;

  UpdateUserProfile(this._repository);

  @override
  ResultFuture<UserEntity> call(UpdateUserParams params) {
    return _repository.updateProfile(
      userId: params.userId,
      name: params.name,
      email: params.email,
    );
  }
}

class UpdateUserParams extends Equatable {
  final String userId;
  final String? name;
  final String? email;

  const UpdateUserParams({
    required this.userId,
    this.name,
    this.email,
  });

  @override
  List<Object?> get props => [userId, name, email];
}
```

### Pattern 3: Stream-based UseCase (Real-time)

```dart
class WatchMessages extends StreamUseCase<List<MessageEntity>, String> {
  final ChatRepository _repository;

  WatchMessages(this._repository);

  @override
  Stream<Either<Failure, List<MessageEntity>>> call(String conversationId) {
    return _repository.getMessages(conversationId);
  }
}
```

---

## 🎨 Available Failure Classes

```dart
// General
NetworkFailure()           // No internet
ServerFailure()            // Server error
CacheFailure()             // Local storage error
ValidationFailure()        // Input validation failed
NotFoundFailure()          // Resource not found
PermissionFailure()        // Unauthorized

// Auth
AuthFailure()
UnauthenticatedFailure()
InvalidCredentialsFailure()
UserAlreadyExistsFailure()
OTPVerificationFailure()

// Supplier
SupplierFailure()
SupplierNotFoundFailure()
PackageFailure()

// Booking
BookingFailure()
BookingNotFoundFailure()
BookingConflictFailure()
SupplierUnavailableFailure()

// Chat
ChatFailure()
MessageSendFailure()
ConversationNotFoundFailure()

// Payment
PaymentFailure()
PaymentDeclinedFailure()
InsufficientFundsFailure()

// Storage
StorageFailure()
FileUploadFailure()
FileTooLargeFailure()
```

---

## 🔧 Using in Riverpod

### Provider Setup

```dart
// Providers
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final dataSource = ProductRemoteDataSource(
    firestore: FirebaseFirestore.instance,
  );
  return ProductRepositoryImpl(remoteDataSource: dataSource);
});

final getProductByIdProvider = Provider<GetProductById>((ref) {
  return GetProductById(ref.read(productRepositoryProvider));
});
```

### StateNotifier Usage

```dart
class ProductNotifier extends StateNotifier<ProductState> {
  final GetProductById _getProductById;

  ProductNotifier(this._getProductById) : super(ProductState.initial());

  Future<void> loadProduct(String id) async {
    state = state.copyWith(isLoading: true);

    final result = await _getProductById(id);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
      (product) => state = state.copyWith(
        isLoading: false,
        product: product,
        error: null,
      ),
    );
  }
}

final productProvider = StateNotifierProvider<ProductNotifier, ProductState>(
  (ref) => ProductNotifier(ref.read(getProductByIdProvider)),
);
```

---

## 📚 Resources

- **Full Architecture Summary:** [ARCHITECTURE_UPGRADE_SUMMARY.md](ARCHITECTURE_UPGRADE_SUMMARY.md)
- **Testing Guide:** [test/README.md](test/README.md)
- **Existing Examples:**
  - Supplier: [lib/features/supplier/domain/](lib/features/supplier/domain/)
  - Chat: [lib/features/chat/domain/](lib/features/chat/domain/)
  - Booking: [lib/features/booking/domain/](lib/features/booking/domain/)

---

## ✅ Checklist for New Features

- [ ] Create `domain/entities/` - Business objects
- [ ] Create `domain/repositories/` - Interface definition
- [ ] Create `domain/usecases/` - Business operations
- [ ] Write unit tests for use cases
- [ ] Implement `data/datasources/` - Firebase/API calls
- [ ] Implement `data/models/` - JSON models
- [ ] Implement `data/repositories/` - Concrete repository
- [ ] Write tests for repository
- [ ] Create `presentation/controllers/` - Riverpod notifiers
- [ ] Create `presentation/screens/` - UI
- [ ] Write widget tests
- [ ] Write integration tests

---

**Remember:** Domain layer should have **zero dependencies** on Flutter, Firebase, or any external packages (except Equatable and Dartz).

🎯 **Happy coding with Clean Architecture!**
