import 'package:boda_connect/core/errors/failures.dart';
import 'package:boda_connect/features/supplier/data/datasources/supplier_remote_datasource.dart';
import 'package:boda_connect/features/supplier/data/models/package_model.dart';
import 'package:boda_connect/features/supplier/data/models/supplier_model.dart';
import 'package:boda_connect/features/supplier/data/repositories/supplier_repository_impl.dart';
import 'package:boda_connect/features/supplier/domain/entities/package_entity.dart';
import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockSupplierRemoteDataSource extends Mock
    implements SupplierRemoteDataSource {}

void main() {
  late SupplierRepositoryImpl repository;
  late MockSupplierRemoteDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockSupplierRemoteDataSource();
    repository = SupplierRepositoryImpl(mockDataSource);
  });

  group('SupplierRepositoryImpl', () {
    final testDateTime = DateTime(2024, 1, 15);

    SupplierModel createTestSupplierModel() {
      return SupplierModel(
        id: 'supplier-1',
        userId: 'user-1',
        businessName: 'Photography Pro',
        category: 'fotografia',
        subcategories: const ['casamento'],
        description: 'Professional photography',
        photos: const ['photo1.jpg'],
        videos: const [],
        location: null,
        rating: 4.5,
        reviewCount: 10,
        isVerified: true,
        isActive: true,
        isFeatured: false,
        responseRate: 95.0,
        responseTime: '< 1 hour',
        phone: null,
        email: null,
        website: null,
        socialLinks: null,
        languages: const ['pt'],
        workingHours: null,
        createdAt: testDateTime,
        updatedAt: testDateTime,
      );
    }

    PackageModel createTestPackageModel() {
      return PackageModel(
        id: 'package-1',
        supplierId: 'supplier-1',
        name: 'Wedding Package',
        description: 'Full day coverage',
        price: 50000,
        currency: 'KES',
        duration: '8 hours',
        includes: const ['Photos', 'Album'],
        customizations: const [],
        photos: const ['package1.jpg'],
        isActive: true,
        isFeatured: false,
        bookingCount: 5,
        createdAt: testDateTime,
        updatedAt: testDateTime,
      );
    }

    group('getSupplierById', () {
      test('should return SupplierEntity when data source call succeeds', () async {
        // Arrange
        final testModel = createTestSupplierModel();
        when(() => mockDataSource.getSupplierById('supplier-1'))
            .thenAnswer((_) async => testModel);

        // Act
        final result = await repository.getSupplierById('supplier-1');

        // Assert
        expect(result, isA<Right<Failure, SupplierEntity>>());
        result.fold(
          (failure) => fail('Should return Right'),
          (supplier) {
            expect(supplier, isA<SupplierEntity>());
            expect(supplier.id, equals('supplier-1'));
            expect(supplier.businessName, equals('Photography Pro'));
          },
        );
        verify(() => mockDataSource.getSupplierById('supplier-1')).called(1);
      });

      test('should return SupplierNotFoundFailure when supplier not found',
          () async {
        // Arrange
        when(() => mockDataSource.getSupplierById('nonexistent'))
            .thenThrow(Exception('Supplier not found'));

        // Act
        final result = await repository.getSupplierById('nonexistent');

        // Assert
        expect(result, isA<Left<Failure, SupplierEntity>>());
        result.fold(
          (failure) {
            expect(failure, isA<SupplierNotFoundFailure>());
            expect(failure.message, contains('não encontrado'));
          },
          (supplier) => fail('Should return Left'),
        );
      });

      test('should return SupplierFailure for generic exceptions', () async {
        // Arrange
        when(() => mockDataSource.getSupplierById('error'))
            .thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.getSupplierById('error');

        // Assert
        expect(result, isA<Left<Failure, SupplierEntity>>());
        result.fold(
          (failure) => expect(failure, isA<SupplierFailure>()),
          (supplier) => fail('Should return Left'),
        );
      });

      test('should return PermissionFailure for permission-denied Firebase error',
          () async {
        // Arrange
        when(() => mockDataSource.getSupplierById('forbidden')).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'permission-denied',
            message: 'Permission denied',
          ),
        );

        // Act
        final result = await repository.getSupplierById('forbidden');

        // Assert
        expect(result, isA<Left<Failure, SupplierEntity>>());
        result.fold(
          (failure) {
            expect(failure, isA<PermissionFailure>());
            expect(failure.message, contains('permissão'));
          },
          (supplier) => fail('Should return Left'),
        );
      });

      test('should return NotFoundFailure for not-found Firebase error',
          () async {
        // Arrange
        when(() => mockDataSource.getSupplierById('missing')).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'not-found',
            message: 'Not found',
          ),
        );

        // Act
        final result = await repository.getSupplierById('missing');

        // Assert
        result.fold(
          (failure) => expect(failure, isA<NotFoundFailure>()),
          (supplier) => fail('Should return Left'),
        );
      });

      test('should return NetworkFailure for unavailable Firebase error',
          () async {
        // Arrange
        when(() => mockDataSource.getSupplierById('unavailable')).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'unavailable',
          ),
        );

        // Act
        final result = await repository.getSupplierById('unavailable');

        // Assert
        result.fold(
          (failure) => expect(failure, isA<NetworkFailure>()),
          (supplier) => fail('Should return Left'),
        );
      });
    });

    group('getSuppliersByCategory', () {
      test('should return list of SupplierEntity when successful', () async {
        // Arrange
        final testModels = [
          createTestSupplierModel(),
          createTestSupplierModel().copyWith(id: 'supplier-2'),
        ];
        when(() => mockDataSource.getSuppliersByCategory(
              category: 'fotografia',
              subcategory: null,
              limit: null,
            )).thenAnswer((_) async => testModels);

        // Act
        final result = await repository.getSuppliersByCategory(
          category: 'fotografia',
        );

        // Assert
        expect(result, isA<Right<Failure, List<SupplierEntity>>>());
        result.fold(
          (failure) => fail('Should return Right'),
          (suppliers) {
            expect(suppliers.length, equals(2));
            expect(suppliers[0], isA<SupplierEntity>());
            expect(suppliers[1].id, equals('supplier-2'));
          },
        );
      });

      test('should pass subcategory and limit parameters', () async {
        // Arrange
        when(() => mockDataSource.getSuppliersByCategory(
              category: 'fotografia',
              subcategory: 'casamento',
              limit: 10,
            )).thenAnswer((_) async => []);

        // Act
        await repository.getSuppliersByCategory(
          category: 'fotografia',
          subcategory: 'casamento',
          limit: 10,
        );

        // Assert
        verify(() => mockDataSource.getSuppliersByCategory(
              category: 'fotografia',
              subcategory: 'casamento',
              limit: 10,
            )).called(1);
      });

      test('should return SupplierFailure on exception', () async {
        // Arrange
        when(() => mockDataSource.getSuppliersByCategory(
              category: any(named: 'category'),
              subcategory: any(named: 'subcategory'),
              limit: any(named: 'limit'),
            )).thenThrow(Exception('Error'));

        // Act
        final result = await repository.getSuppliersByCategory(
          category: 'fotografia',
        );

        // Assert
        result.fold(
          (failure) => expect(failure, isA<SupplierFailure>()),
          (suppliers) => fail('Should return Left'),
        );
      });

      test('should return empty list when no suppliers found', () async {
        // Arrange
        when(() => mockDataSource.getSuppliersByCategory(
              category: any(named: 'category'),
              subcategory: any(named: 'subcategory'),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => []);

        // Act
        final result = await repository.getSuppliersByCategory(
          category: 'nonexistent',
        );

        // Assert
        result.fold(
          (failure) => fail('Should return Right'),
          (suppliers) => expect(suppliers, isEmpty),
        );
      });
    });

    group('searchSuppliers', () {
      test('should return filtered suppliers when successful', () async {
        // Arrange
        final testModels = [createTestSupplierModel()];
        when(() => mockDataSource.searchSuppliers(
              query: 'photography',
              category: null,
              city: null,
              limit: null,
            )).thenAnswer((_) async => testModels);

        // Act
        final result = await repository.searchSuppliers(query: 'photography');

        // Assert
        result.fold(
          (failure) => fail('Should return Right'),
          (suppliers) {
            expect(suppliers.length, equals(1));
            expect(suppliers[0].businessName, equals('Photography Pro'));
          },
        );
      });

      test('should pass all search parameters', () async {
        // Arrange
        when(() => mockDataSource.searchSuppliers(
              query: 'test',
              category: 'fotografia',
              city: 'Luanda',
              limit: 5,
            )).thenAnswer((_) async => []);

        // Act
        await repository.searchSuppliers(
          query: 'test',
          category: 'fotografia',
          city: 'Luanda',
          limit: 5,
        );

        // Assert
        verify(() => mockDataSource.searchSuppliers(
              query: 'test',
              category: 'fotografia',
              city: 'Luanda',
              limit: 5,
            )).called(1);
      });

      test('should return SupplierFailure on exception', () async {
        // Arrange
        when(() => mockDataSource.searchSuppliers(
              query: any(named: 'query'),
              category: any(named: 'category'),
              city: any(named: 'city'),
              limit: any(named: 'limit'),
            )).thenThrow(Exception('Search error'));

        // Act
        final result = await repository.searchSuppliers(query: 'test');

        // Assert
        result.fold(
          (failure) => expect(failure, isA<SupplierFailure>()),
          (suppliers) => fail('Should return Left'),
        );
      });
    });

    group('getFeaturedSuppliers', () {
      test('should return featured suppliers when successful', () async {
        // Arrange
        final testModels = [
          createTestSupplierModel().copyWith(isFeatured: true),
        ];
        when(() => mockDataSource.getFeaturedSuppliers(limit: null))
            .thenAnswer((_) async => testModels);

        // Act
        final result = await repository.getFeaturedSuppliers();

        // Assert
        result.fold(
          (failure) => fail('Should return Right'),
          (suppliers) {
            expect(suppliers.length, equals(1));
            expect(suppliers[0].isFeatured, isTrue);
          },
        );
      });

      test('should pass limit parameter', () async {
        // Arrange
        when(() => mockDataSource.getFeaturedSuppliers(limit: 10))
            .thenAnswer((_) async => []);

        // Act
        await repository.getFeaturedSuppliers(limit: 10);

        // Assert
        verify(() => mockDataSource.getFeaturedSuppliers(limit: 10)).called(1);
      });

      test('should return SupplierFailure on exception', () async {
        // Arrange
        when(() => mockDataSource.getFeaturedSuppliers(limit: any(named: 'limit')))
            .thenThrow(Exception('Error'));

        // Act
        final result = await repository.getFeaturedSuppliers();

        // Assert
        result.fold(
          (failure) => expect(failure, isA<SupplierFailure>()),
          (suppliers) => fail('Should return Left'),
        );
      });
    });

    group('getVerifiedSuppliers', () {
      test('should return verified suppliers when successful', () async {
        // Arrange
        final testModels = [
          createTestSupplierModel().copyWith(isVerified: true),
        ];
        when(() => mockDataSource.getVerifiedSuppliers(
              category: null,
              limit: null,
            )).thenAnswer((_) async => testModels);

        // Act
        final result = await repository.getVerifiedSuppliers();

        // Assert
        result.fold(
          (failure) => fail('Should return Right'),
          (suppliers) {
            expect(suppliers.length, equals(1));
            expect(suppliers[0].isVerified, isTrue);
          },
        );
      });

      test('should pass category and limit parameters', () async {
        // Arrange
        when(() => mockDataSource.getVerifiedSuppliers(
              category: 'fotografia',
              limit: 20,
            )).thenAnswer((_) async => []);

        // Act
        await repository.getVerifiedSuppliers(
          category: 'fotografia',
          limit: 20,
        );

        // Assert
        verify(() => mockDataSource.getVerifiedSuppliers(
              category: 'fotografia',
              limit: 20,
            )).called(1);
      });

      test('should return SupplierFailure on exception', () async {
        // Arrange
        when(() => mockDataSource.getVerifiedSuppliers(
              category: any(named: 'category'),
              limit: any(named: 'limit'),
            )).thenThrow(Exception('Error'));

        // Act
        final result = await repository.getVerifiedSuppliers();

        // Assert
        result.fold(
          (failure) => expect(failure, isA<SupplierFailure>()),
          (suppliers) => fail('Should return Left'),
        );
      });
    });

    group('updateSupplierProfile', () {
      test('should return updated SupplierEntity when successful', () async {
        // Arrange
        final updatedModel = createTestSupplierModel()
            .copyWith(businessName: 'Updated Name');
        when(() => mockDataSource.updateSupplierProfile(
              supplierId: 'supplier-1',
              updates: any(named: 'updates'),
            )).thenAnswer((_) async => updatedModel);

        // Act
        final result = await repository.updateSupplierProfile(
          supplierId: 'supplier-1',
          businessName: 'Updated Name',
        );

        // Assert
        result.fold(
          (failure) => fail('Should return Right'),
          (supplier) {
            expect(supplier.businessName, equals('Updated Name'));
          },
        );
        verify(() => mockDataSource.updateSupplierProfile(
              supplierId: 'supplier-1',
              updates: any(named: 'updates'),
            )).called(1);
      });

      test('should include all non-null fields in updates', () async {
        // Arrange
        final updatedModel = createTestSupplierModel();
        when(() => mockDataSource.updateSupplierProfile(
              supplierId: any(named: 'supplierId'),
              updates: any(named: 'updates'),
            )).thenAnswer((_) async => updatedModel);

        // Act
        await repository.updateSupplierProfile(
          supplierId: 'supplier-1',
          businessName: 'New Name',
          description: 'New Description',
          phone: '+244912345678',
        );

        // Assert
        final captured = verify(() => mockDataSource.updateSupplierProfile(
              supplierId: 'supplier-1',
              updates: captureAny(named: 'updates'),
            )).captured;
        final updates = captured.first as Map<String, dynamic>;
        expect(updates['businessName'], equals('New Name'));
        expect(updates['description'], equals('New Description'));
        expect(updates['phone'], equals('+244912345678'));
      });

      test('should convert location entity to model before updating', () async {
        // Arrange
        final updatedModel = createTestSupplierModel();
        const location = LocationEntity(city: 'Luanda', province: 'Luanda');
        when(() => mockDataSource.updateSupplierProfile(
              supplierId: any(named: 'supplierId'),
              updates: any(named: 'updates'),
            )).thenAnswer((_) async => updatedModel);

        // Act
        await repository.updateSupplierProfile(
          supplierId: 'supplier-1',
          location: location,
        );

        // Assert
        final captured = verify(() => mockDataSource.updateSupplierProfile(
              supplierId: 'supplier-1',
              updates: captureAny(named: 'updates'),
            )).captured;
        final updates = captured.first as Map<String, dynamic>;
        expect(updates.containsKey('location'), isTrue);
        expect(updates['location'], isA<Map<String, dynamic>>());
      });

      test('should return SupplierNotFoundFailure when supplier not found',
          () async {
        // Arrange
        when(() => mockDataSource.updateSupplierProfile(
              supplierId: any(named: 'supplierId'),
              updates: any(named: 'updates'),
            )).thenThrow(Exception('Supplier not found'));

        // Act
        final result = await repository.updateSupplierProfile(
          supplierId: 'nonexistent',
          businessName: 'Name',
        );

        // Assert
        result.fold(
          (failure) => expect(failure, isA<SupplierNotFoundFailure>()),
          (supplier) => fail('Should return Left'),
        );
      });

      test('should return appropriate failure for Firebase exceptions',
          () async {
        // Arrange
        when(() => mockDataSource.updateSupplierProfile(
              supplierId: any(named: 'supplierId'),
              updates: any(named: 'updates'),
            )).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'permission-denied',
          ),
        );

        // Act
        final result = await repository.updateSupplierProfile(
          supplierId: 'supplier-1',
          businessName: 'Name',
        );

        // Assert
        result.fold(
          (failure) => expect(failure, isA<PermissionFailure>()),
          (supplier) => fail('Should return Left'),
        );
      });
    });

    group('toggleSupplierStatus', () {
      test('should return updated supplier when toggling status', () async {
        // Arrange
        final updatedModel = createTestSupplierModel().copyWith(isActive: false);
        when(() => mockDataSource.toggleSupplierStatus(
              supplierId: 'supplier-1',
              isActive: false,
            )).thenAnswer((_) async => updatedModel);

        // Act
        final result = await repository.toggleSupplierStatus(
          supplierId: 'supplier-1',
          isActive: false,
        );

        // Assert
        result.fold(
          (failure) => fail('Should return Right'),
          (supplier) {
            expect(supplier.isActive, isFalse);
          },
        );
      });

      test('should return SupplierNotFoundFailure when supplier not found',
          () async {
        // Arrange
        when(() => mockDataSource.toggleSupplierStatus(
              supplierId: any(named: 'supplierId'),
              isActive: any(named: 'isActive'),
            )).thenThrow(Exception('not found'));

        // Act
        final result = await repository.toggleSupplierStatus(
          supplierId: 'nonexistent',
          isActive: false,
        );

        // Assert
        result.fold(
          (failure) => expect(failure, isA<SupplierNotFoundFailure>()),
          (supplier) => fail('Should return Left'),
        );
      });
    });

    group('getSupplierPackages', () {
      test('should return list of PackageEntity when successful', () async {
        // Arrange
        final testPackages = [
          createTestPackageModel(),
          createTestPackageModel().copyWith(id: 'package-2'),
        ];
        when(() => mockDataSource.getSupplierPackages('supplier-1'))
            .thenAnswer((_) async => testPackages);

        // Act
        final result = await repository.getSupplierPackages('supplier-1');

        // Assert
        result.fold(
          (failure) => fail('Should return Right'),
          (packages) {
            expect(packages.length, equals(2));
            expect(packages[0], isA<PackageEntity>());
            expect(packages[1].id, equals('package-2'));
          },
        );
      });

      test('should return PackageFailure on exception', () async {
        // Arrange
        when(() => mockDataSource.getSupplierPackages(any()))
            .thenThrow(Exception('Error'));

        // Act
        final result = await repository.getSupplierPackages('supplier-1');

        // Assert
        result.fold(
          (failure) => expect(failure, isA<PackageFailure>()),
          (packages) => fail('Should return Left'),
        );
      });

      test('should return empty list when no packages found', () async {
        // Arrange
        when(() => mockDataSource.getSupplierPackages(any()))
            .thenAnswer((_) async => []);

        // Act
        final result = await repository.getSupplierPackages('supplier-1');

        // Assert
        result.fold(
          (failure) => fail('Should return Right'),
          (packages) => expect(packages, isEmpty),
        );
      });
    });

    group('getPackageById', () {
      test('should return PackageEntity when found', () async {
        // Arrange
        final testPackage = createTestPackageModel();
        when(() => mockDataSource.getPackageById('package-1'))
            .thenAnswer((_) async => testPackage);

        // Act
        final result = await repository.getPackageById('package-1');

        // Assert
        result.fold(
          (failure) => fail('Should return Right'),
          (package) {
            expect(package, isA<PackageEntity>());
            expect(package.id, equals('package-1'));
            expect(package.name, equals('Wedding Package'));
          },
        );
      });

      test('should return PackageFailure when not found', () async {
        // Arrange
        when(() => mockDataSource.getPackageById(any()))
            .thenThrow(Exception('Package not found'));

        // Act
        final result = await repository.getPackageById('nonexistent');

        // Assert
        result.fold(
          (failure) => expect(failure, isA<PackageFailure>()),
          (package) => fail('Should return Left'),
        );
      });

      test('should handle Firebase exceptions', () async {
        // Arrange
        when(() => mockDataSource.getPackageById(any())).thenThrow(
          FirebaseException(plugin: 'firestore', code: 'not-found'),
        );

        // Act
        final result = await repository.getPackageById('package-1');

        // Assert
        result.fold(
          (failure) => expect(failure, isA<NotFoundFailure>()),
          (package) => fail('Should return Left'),
        );
      });
    });

    group('createPackage', () {
      test('should return created PackageEntity when successful', () async {
        // Arrange
        final entity = PackageEntity(
          id: 'temp-id',
          supplierId: 'supplier-1',
          name: 'New Package',
          description: 'Description',
          price: 30000,
          currency: 'KES',
          duration: '4 hours',
          includes: const [],
          customizations: const [],
          photos: const [],
          isActive: true,
          isFeatured: false,
          bookingCount: 0,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        );
        final createdModel = createTestPackageModel().copyWith(
          id: 'package-new',
          name: 'New Package',
        );
        when(() => mockDataSource.createPackage(any()))
            .thenAnswer((_) async => createdModel);

        // Act
        final result = await repository.createPackage(entity);

        // Assert
        result.fold(
          (failure) => fail('Should return Right'),
          (package) {
            expect(package.id, equals('package-new'));
            expect(package.name, equals('New Package'));
          },
        );
      });

      test('should convert entity to Firestore data before creating', () async {
        // Arrange
        final entity = PackageEntity(
          id: 'temp-id',
          supplierId: 'supplier-1',
          name: 'Package',
          description: 'Desc',
          price: 10000,
          currency: 'KES',
          duration: '2 hours',
          includes: const ['Item 1'],
          customizations: const [],
          photos: const [],
          isActive: true,
          isFeatured: false,
          bookingCount: 0,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        );
        final createdModel = createTestPackageModel();
        when(() => mockDataSource.createPackage(any()))
            .thenAnswer((_) async => createdModel);

        // Act
        await repository.createPackage(entity);

        // Assert
        final captured = verify(() => mockDataSource.createPackage(captureAny()))
            .captured;
        final data = captured.first as Map<String, dynamic>;
        expect(data.containsKey('id'), isFalse);
        expect(data['supplierId'], equals('supplier-1'));
        expect(data['name'], equals('Package'));
      });

      test('should return PackageFailure on exception', () async {
        // Arrange
        final entity = PackageEntity(
          id: 'id',
          supplierId: 'supplier-1',
          name: 'Package',
          description: 'Desc',
          price: 10000,
          currency: 'KES',
          duration: '2 hours',
          includes: const [],
          customizations: const [],
          photos: const [],
          isActive: true,
          isFeatured: false,
          bookingCount: 0,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        );
        when(() => mockDataSource.createPackage(any()))
            .thenThrow(Exception('Error'));

        // Act
        final result = await repository.createPackage(entity);

        // Assert
        result.fold(
          (failure) => expect(failure, isA<PackageFailure>()),
          (package) => fail('Should return Left'),
        );
      });
    });

    group('updatePackage', () {
      test('should return updated PackageEntity when successful', () async {
        // Arrange
        final entity = createTestPackageModel().toEntity();
        final updatedModel = createTestPackageModel()
            .copyWith(name: 'Updated Package');
        when(() => mockDataSource.updatePackage(
              packageId: any(named: 'packageId'),
              updates: any(named: 'updates'),
            )).thenAnswer((_) async => updatedModel);

        // Act
        final result = await repository.updatePackage(entity);

        // Assert
        result.fold(
          (failure) => fail('Should return Right'),
          (package) {
            expect(package.name, equals('Updated Package'));
          },
        );
      });

      test('should exclude id and supplierId from updates', () async {
        // Arrange
        final entity = createTestPackageModel().toEntity();
        final updatedModel = createTestPackageModel();
        when(() => mockDataSource.updatePackage(
              packageId: any(named: 'packageId'),
              updates: any(named: 'updates'),
            )).thenAnswer((_) async => updatedModel);

        // Act
        await repository.updatePackage(entity);

        // Assert
        final captured = verify(() => mockDataSource.updatePackage(
              packageId: any(named: 'packageId'),
              updates: captureAny(named: 'updates'),
            )).captured;
        final updates = captured.first as Map<String, dynamic>;
        expect(updates.containsKey('id'), isFalse);
        expect(updates.containsKey('supplierId'), isFalse);
      });

      test('should return PackageFailure when not found', () async {
        // Arrange
        final entity = createTestPackageModel().toEntity();
        when(() => mockDataSource.updatePackage(
              packageId: any(named: 'packageId'),
              updates: any(named: 'updates'),
            )).thenThrow(Exception('Package not found'));

        // Act
        final result = await repository.updatePackage(entity);

        // Assert
        result.fold(
          (failure) => expect(failure, isA<PackageFailure>()),
          (package) => fail('Should return Left'),
        );
      });
    });

    group('deletePackage', () {
      test('should return Right(null) when deletion succeeds', () async {
        // Arrange
        when(() => mockDataSource.deletePackage('package-1'))
            .thenAnswer((_) async {});

        // Act
        final result = await repository.deletePackage('package-1');

        // Assert
        expect(result.isRight(), isTrue);
        verify(() => mockDataSource.deletePackage('package-1')).called(1);
      });

      test('should return PackageFailure on exception', () async {
        // Arrange
        when(() => mockDataSource.deletePackage(any()))
            .thenThrow(Exception('Error'));

        // Act
        final result = await repository.deletePackage('package-1');

        // Assert
        result.fold(
          (failure) => expect(failure, isA<PackageFailure>()),
          (value) => fail('Should return Left'),
        );
      });

      test('should handle Firebase exceptions', () async {
        // Arrange
        when(() => mockDataSource.deletePackage(any())).thenThrow(
          FirebaseException(plugin: 'firestore', code: 'permission-denied'),
        );

        // Act
        final result = await repository.deletePackage('package-1');

        // Assert
        result.fold(
          (failure) => expect(failure, isA<PermissionFailure>()),
          (value) => fail('Should return Left'),
        );
      });
    });

    group('togglePackageStatus', () {
      test('should return updated package when toggling status', () async {
        // Arrange
        final updatedModel = createTestPackageModel().copyWith(isActive: false);
        when(() => mockDataSource.togglePackageStatus(
              packageId: 'package-1',
              isActive: false,
            )).thenAnswer((_) async => updatedModel);

        // Act
        final result = await repository.togglePackageStatus(
          packageId: 'package-1',
          isActive: false,
        );

        // Assert
        result.fold(
          (failure) => fail('Should return Right'),
          (package) {
            expect(package.isActive, isFalse);
          },
        );
      });

      test('should return PackageFailure when not found', () async {
        // Arrange
        when(() => mockDataSource.togglePackageStatus(
              packageId: any(named: 'packageId'),
              isActive: any(named: 'isActive'),
            )).thenThrow(Exception('not found'));

        // Act
        final result = await repository.togglePackageStatus(
          packageId: 'nonexistent',
          isActive: false,
        );

        // Assert
        result.fold(
          (failure) => expect(failure, isA<PackageFailure>()),
          (package) => fail('Should return Left'),
        );
      });
    });
  });
}
