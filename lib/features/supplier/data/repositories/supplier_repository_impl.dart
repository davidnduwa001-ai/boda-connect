import 'package:dartz/dartz.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boda_connect/core/errors/failures.dart';
import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:boda_connect/features/supplier/domain/entities/package_entity.dart';
import 'package:boda_connect/features/supplier/domain/repositories/supplier_repository.dart';
import 'package:boda_connect/features/supplier/data/datasources/supplier_remote_datasource.dart';
import 'package:boda_connect/features/supplier/data/models/package_model.dart';
import 'package:boda_connect/features/supplier/data/models/location_model.dart';
import 'package:boda_connect/features/supplier/data/models/working_hours_model.dart';

/// Implementation of SupplierRepository
/// Handles all supplier-related operations with proper error handling
/// Converts between domain entities and data models
class SupplierRepositoryImpl implements SupplierRepository {
  SupplierRepositoryImpl(this._dataSource);

  final SupplierRemoteDataSource _dataSource;

  // ==================== SUPPLIER OPERATIONS ====================

  @override
  ResultFuture<SupplierEntity> getSupplierById(String supplierId) async {
    try {
      final supplier = await _dataSource.getSupplierById(supplierId);
      return Right(supplier.toEntity());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } on Exception catch (e) {
      if (e.toString().contains('not found')) {
        return const Left(
          SupplierNotFoundFailure('Fornecedor não encontrado'),
        );
      }
      return Left(SupplierFailure(e.toString()));
    }
  }

  @override
  ResultFuture<List<SupplierEntity>> getSuppliersByCategory({
    required String category,
    String? subcategory,
    int? limit,
  }) async {
    try {
      final suppliers = await _dataSource.getSuppliersByCategory(
        category: category,
        subcategory: subcategory,
        limit: limit,
      );
      return Right(suppliers.map((s) => s.toEntity()).toList());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } on Exception catch (e) {
      return Left(SupplierFailure(e.toString()));
    }
  }

  @override
  ResultFuture<List<SupplierEntity>> searchSuppliers({
    required String query,
    String? category,
    String? city,
    int? limit,
  }) async {
    try {
      final suppliers = await _dataSource.searchSuppliers(
        query: query,
        category: category,
        city: city,
        limit: limit,
      );
      return Right(suppliers.map((s) => s.toEntity()).toList());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } on Exception catch (e) {
      return Left(SupplierFailure(e.toString()));
    }
  }

  @override
  ResultFuture<List<SupplierEntity>> getFeaturedSuppliers({
    int? limit,
  }) async {
    try {
      final suppliers = await _dataSource.getFeaturedSuppliers(limit: limit);
      return Right(suppliers.map((s) => s.toEntity()).toList());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } on Exception catch (e) {
      return Left(SupplierFailure(e.toString()));
    }
  }

  @override
  ResultFuture<List<SupplierEntity>> getVerifiedSuppliers({
    String? category,
    int? limit,
  }) async {
    try {
      final suppliers = await _dataSource.getVerifiedSuppliers(
        category: category,
        limit: limit,
      );
      return Right(suppliers.map((s) => s.toEntity()).toList());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } on Exception catch (e) {
      return Left(SupplierFailure(e.toString()));
    }
  }

  @override
  ResultFuture<SupplierEntity> updateSupplierProfile({
    required String supplierId,
    String? businessName,
    String? description,
    List<String>? subcategories,
    String? phone,
    String? email,
    String? website,
    Map<String, String>? socialLinks,
    List<String>? languages,
    LocationEntity? location,
    WorkingHoursEntity? workingHours,
    List<String>? photos,
    List<String>? videos,
  }) async {
    try {
      // Build updates map with only non-null values
      final updates = <String, dynamic>{};

      if (businessName != null) updates['businessName'] = businessName;
      if (description != null) updates['description'] = description;
      if (subcategories != null) updates['subcategories'] = subcategories;
      if (phone != null) updates['phone'] = phone;
      if (email != null) updates['email'] = email;
      if (website != null) updates['website'] = website;
      if (socialLinks != null) updates['socialLinks'] = socialLinks;
      if (languages != null) updates['languages'] = languages;
      if (photos != null) updates['photos'] = photos;
      if (videos != null) updates['videos'] = videos;

      if (location != null) {
        updates['location'] = LocationModel.fromEntity(location).toFirestore();
      }

      if (workingHours != null) {
        updates['workingHours'] =
            WorkingHoursModel.fromEntity(workingHours).toFirestore();
      }

      final supplier = await _dataSource.updateSupplierProfile(
        supplierId: supplierId,
        updates: updates,
      );

      return Right(supplier.toEntity());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } on Exception catch (e) {
      if (e.toString().contains('not found')) {
        return const Left(
          SupplierNotFoundFailure('Fornecedor não encontrado'),
        );
      }
      return Left(SupplierFailure(e.toString()));
    }
  }

  @override
  ResultFuture<SupplierEntity> toggleSupplierStatus({
    required String supplierId,
    required bool isActive,
  }) async {
    try {
      final supplier = await _dataSource.toggleSupplierStatus(
        supplierId: supplierId,
        isActive: isActive,
      );
      return Right(supplier.toEntity());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } on Exception catch (e) {
      if (e.toString().contains('not found')) {
        return const Left(
          SupplierNotFoundFailure('Fornecedor não encontrado'),
        );
      }
      return Left(SupplierFailure(e.toString()));
    }
  }

  // ==================== PACKAGE OPERATIONS ====================

  @override
  ResultFuture<List<PackageEntity>> getSupplierPackages(
    String supplierId,
  ) async {
    try {
      final packages = await _dataSource.getSupplierPackages(supplierId);
      return Right(packages.map((p) => p.toEntity()).toList());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } on Exception catch (e) {
      return Left(PackageFailure(e.toString()));
    }
  }

  @override
  ResultFuture<PackageEntity> getPackageById(String packageId) async {
    try {
      final package = await _dataSource.getPackageById(packageId);
      return Right(package.toEntity());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } on Exception catch (e) {
      if (e.toString().contains('not found')) {
        return const Left(
          PackageFailure('Pacote não encontrado'),
        );
      }
      return Left(PackageFailure(e.toString()));
    }
  }

  @override
  ResultFuture<PackageEntity> createPackage(PackageEntity package) async {
    try {
      // Convert entity to model and then to Firestore map
      final packageModel = PackageModel.fromEntity(package);
      final packageData = packageModel.toFirestore();

      // Remove id from the data as it will be auto-generated
      packageData.remove('id');

      final createdPackage = await _dataSource.createPackage(packageData);
      return Right(createdPackage.toEntity());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } on Exception catch (e) {
      return Left(PackageFailure(e.toString()));
    }
  }

  @override
  ResultFuture<PackageEntity> updatePackage(PackageEntity package) async {
    try {
      // Convert entity to model and then to Firestore map
      final packageModel = PackageModel.fromEntity(package);
      final packageData = packageModel.toFirestore();

      // Remove id and supplierId as they shouldn't be updated
      packageData.remove('id');
      packageData.remove('supplierId');

      final updatedPackage = await _dataSource.updatePackage(
        packageId: package.id,
        updates: packageData,
      );

      return Right(updatedPackage.toEntity());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } on Exception catch (e) {
      if (e.toString().contains('not found')) {
        return const Left(
          PackageFailure('Pacote não encontrado'),
        );
      }
      return Left(PackageFailure(e.toString()));
    }
  }

  @override
  ResultFutureVoid deletePackage(String packageId) async {
    try {
      await _dataSource.deletePackage(packageId);
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } on Exception catch (e) {
      return Left(PackageFailure(e.toString()));
    }
  }

  @override
  ResultFuture<PackageEntity> togglePackageStatus({
    required String packageId,
    required bool isActive,
  }) async {
    try {
      final package = await _dataSource.togglePackageStatus(
        packageId: packageId,
        isActive: isActive,
      );
      return Right(package.toEntity());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } on Exception catch (e) {
      if (e.toString().contains('not found')) {
        return const Left(
          PackageFailure('Pacote não encontrado'),
        );
      }
      return Left(PackageFailure(e.toString()));
    }
  }

  // ==================== ERROR HANDLING ====================

  /// Handle Firebase exceptions and convert to appropriate Failures
  Failure _handleFirebaseException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return PermissionFailure(
          'Sem permissão para esta operação',
          e.code,
        );
      case 'not-found':
        return const NotFoundFailure('Recurso não encontrado');
      case 'unavailable':
        return const NetworkFailure('Serviço temporariamente indisponível');
      case 'unauthenticated':
        return const UnauthenticatedFailure('Usuário não autenticado');
      case 'already-exists':
        return ServerFailure('Recurso já existe', e.code);
      case 'resource-exhausted':
        return ServerFailure('Limite de recursos excedido', e.code);
      case 'cancelled':
        return ServerFailure('Operação cancelada', e.code);
      case 'data-loss':
        return ServerFailure('Perda de dados detectada', e.code);
      case 'deadline-exceeded':
        return const NetworkFailure('Tempo limite excedido');
      case 'failed-precondition':
        return ValidationFailure('Condição prévia falhou', e.code);
      case 'aborted':
        return ServerFailure('Operação abortada', e.code);
      case 'out-of-range':
        return ValidationFailure('Valor fora do intervalo', e.code);
      case 'unimplemented':
        return ServerFailure('Operação não implementada', e.code);
      case 'internal':
        return ServerFailure('Erro interno do servidor', e.code);
      default:
        return ServerFailure(
          e.message ?? 'Erro desconhecido do servidor',
          e.code,
        );
    }
  }
}
