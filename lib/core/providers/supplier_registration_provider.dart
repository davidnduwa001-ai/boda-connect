import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/supplier_model.dart';
import '../repositories/supplier_repository.dart';
import '../services/category_validation_service.dart';
import 'auth_provider.dart';
import 'supplier_provider.dart';

/// Supplier Registration Data Model
class SupplierRegistrationData {
  // Step 1: Basic Data
  String? name;
  String? businessName;
  String? phone;
  String? whatsapp;
  String? email;
  String? province;
  String? city;
  XFile? profileImage;

  // Step 2: Entity Type & Fiscal Info (NEW - from Figma)
  SupplierEntityType entityType;
  String? nif; // Número de Identificação Fiscal

  // Step 3: Identity Document (NEW - from Figma)
  IdentityDocumentType? idDocumentType;
  String? idDocumentNumber;
  XFile? idDocumentFile;

  // Step 4: Service Type
  String? serviceType;
  List<String>? eventTypes;

  // Step 5: Service Description
  String? description;
  List<String>? features;

  // Step 6: Upload Content
  List<XFile>? portfolioImages;
  XFile? videoFile;

  // Step 7: Pricing & Availability
  Map<String, dynamic>? packages;
  Map<String, dynamic>? availability;
  String? minPrice;
  String? maxPrice;

  SupplierRegistrationData({
    this.name,
    this.businessName,
    this.phone,
    this.whatsapp,
    this.email,
    this.province,
    this.city,
    this.profileImage,
    this.entityType = SupplierEntityType.individual,
    this.nif,
    this.idDocumentType,
    this.idDocumentNumber,
    this.idDocumentFile,
    this.serviceType,
    this.eventTypes,
    this.description,
    this.features,
    this.portfolioImages,
    this.videoFile,
    this.packages,
    this.availability,
    this.minPrice,
    this.maxPrice,
  });

  SupplierRegistrationData copyWith({
    String? name,
    String? businessName,
    String? phone,
    String? whatsapp,
    String? email,
    String? province,
    String? city,
    XFile? profileImage,
    SupplierEntityType? entityType,
    String? nif,
    IdentityDocumentType? idDocumentType,
    String? idDocumentNumber,
    XFile? idDocumentFile,
    String? serviceType,
    List<String>? eventTypes,
    String? description,
    List<String>? features,
    List<XFile>? portfolioImages,
    XFile? videoFile,
    Map<String, dynamic>? packages,
    Map<String, dynamic>? availability,
    String? minPrice,
    String? maxPrice,
  }) {
    return SupplierRegistrationData(
      name: name ?? this.name,
      businessName: businessName ?? this.businessName,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      province: province ?? this.province,
      city: city ?? this.city,
      profileImage: profileImage ?? this.profileImage,
      entityType: entityType ?? this.entityType,
      nif: nif ?? this.nif,
      idDocumentType: idDocumentType ?? this.idDocumentType,
      idDocumentNumber: idDocumentNumber ?? this.idDocumentNumber,
      idDocumentFile: idDocumentFile ?? this.idDocumentFile,
      serviceType: serviceType ?? this.serviceType,
      eventTypes: eventTypes ?? this.eventTypes,
      description: description ?? this.description,
      features: features ?? this.features,
      portfolioImages: portfolioImages ?? this.portfolioImages,
      videoFile: videoFile ?? this.videoFile,
      packages: packages ?? this.packages,
      availability: availability ?? this.availability,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
    );
  }

  /// Calculate completion percentage
  double get completionPercentage {
    int completed = 0;
    int total = 7; // 7 steps (updated with entity & document steps)

    // Step 1: Basic Data (required fields)
    if (name != null && businessName != null && phone != null && province != null && city != null) {
      completed++;
    }

    // Step 2: Entity Type & Fiscal Info (NEW - from Figma)
    if (isEntityInfoComplete) {
      completed++;
    }

    // Step 3: Identity Document (NEW - from Figma)
    if (isIdentityDocumentComplete) {
      completed++;
    }

    // Step 4: Service Type
    if (serviceType != null) {
      completed++;
    }

    // Step 5: Service Description
    if (description != null) {
      completed++;
    }

    // Step 6: Upload Content (at least one image)
    if (portfolioImages != null && portfolioImages!.isNotEmpty) {
      completed++;
    }

    // Step 7: Pricing
    if (minPrice != null || packages != null) {
      completed++;
    }

    return completed / total;
  }

  /// Check if basic data step is complete
  bool get isBasicDataComplete {
    return name != null &&
        businessName != null &&
        phone != null &&
        province != null &&
        city != null;
  }

  /// Check if service type step is complete
  bool get isServiceTypeComplete {
    return serviceType != null;
  }

  /// Check if description step is complete
  bool get isDescriptionComplete {
    return description != null && description!.isNotEmpty;
  }

  /// Check if upload step is complete
  bool get isUploadComplete {
    return portfolioImages != null && portfolioImages!.isNotEmpty;
  }

  /// Check if pricing step is complete
  bool get isPricingComplete {
    return minPrice != null;
  }

  /// Check if entity info step is complete (NEW - from Figma)
  /// Entity type is always set (defaults to individual), NIF required for empresa
  bool get isEntityInfoComplete {
    if (entityType == SupplierEntityType.empresa) {
      return nif != null && nif!.isNotEmpty;
    }
    return true; // Individual doesn't require NIF
  }

  /// Check if identity document step is complete (NEW - from Figma)
  bool get isIdentityDocumentComplete {
    return idDocumentType != null &&
        idDocumentNumber != null &&
        idDocumentNumber!.isNotEmpty &&
        idDocumentFile != null;
  }

  /// Check if all required data is complete
  bool get isComplete {
    return isBasicDataComplete &&
        isEntityInfoComplete &&
        isIdentityDocumentComplete &&
        isServiceTypeComplete &&
        isDescriptionComplete &&
        isUploadComplete &&
        isPricingComplete;
  }
}

/// Supplier Registration State Notifier
class SupplierRegistrationNotifier extends StateNotifier<SupplierRegistrationData> {
  final SupplierRepository _repository;
  final Ref _ref;

  SupplierRegistrationNotifier(this._repository, this._ref) : super(SupplierRegistrationData());

  /// Update basic data (Step 1)
  void updateBasicData({
    String? name,
    String? businessName,
    String? phone,
    String? whatsapp,
    String? email,
    String? province,
    String? city,
    XFile? profileImage,
  }) {
    state = state.copyWith(
      name: name,
      businessName: businessName,
      phone: phone,
      whatsapp: whatsapp,
      email: email,
      province: province,
      city: city,
      profileImage: profileImage,
    );
  }

  /// Update service type (Step 2)
  void updateServiceType({
    String? serviceType,
    List<String>? eventTypes,
  }) {
    state = state.copyWith(
      serviceType: serviceType,
      eventTypes: eventTypes,
    );
  }

  /// Update description (Step 3)
  void updateDescription({
    String? description,
    List<String>? features,
  }) {
    state = state.copyWith(
      description: description,
      features: features,
    );
  }

  /// Update upload content (Step 4)
  void updateUploadContent({
    List<XFile>? portfolioImages,
    XFile? videoFile,
  }) {
    state = state.copyWith(
      portfolioImages: portfolioImages,
      videoFile: videoFile,
    );
  }

  /// Update pricing & availability (Step 5)
  void updatePricing({
    Map<String, dynamic>? packages,
    Map<String, dynamic>? availability,
    String? minPrice,
    String? maxPrice,
  }) {
    state = state.copyWith(
      packages: packages,
      availability: availability,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
  }

  /// Update entity type & fiscal info (Step 2 - NEW from Figma)
  void updateEntityInfo({
    SupplierEntityType? entityType,
    String? nif,
  }) {
    state = state.copyWith(
      entityType: entityType,
      nif: nif,
    );
  }

  /// Update identity document info (Step 3 - NEW from Figma)
  void updateIdentityDocument({
    IdentityDocumentType? idDocumentType,
    String? idDocumentNumber,
    XFile? idDocumentFile,
  }) {
    state = state.copyWith(
      idDocumentType: idDocumentType,
      idDocumentNumber: idDocumentNumber,
      idDocumentFile: idDocumentFile,
    );
  }

  /// Reset all data
  void reset() {
    state = SupplierRegistrationData();
  }

  /// Get current completion percentage
  double get completionPercentage => state.completionPercentage;

  /// Validate complete registration before submission
  /// Returns null if valid, or error message if invalid
  String? validateRegistration() {
    final validation = SupplierRegistrationValidator.validateCompleteRegistration(
      name: state.name,
      businessName: state.businessName,
      phone: state.phone,
      province: state.province,
      city: state.city,
      category: state.serviceType,
      subcategories: state.eventTypes,
      description: state.description,
      photos: state.portfolioImages,
      price: state.minPrice,
      priceOnRequest: false,
    );

    if (!validation.isValid) {
      return validation.errorSummary;
    }
    return null;
  }

  /// Complete registration - save to Firestore
  /// GATEKEEPING: Will NOT create supplier if validation fails
  Future<String?> completeRegistration() async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;

    // HARD VALIDATION: Check all required fields before creating supplier
    final validationError = validateRegistration();
    if (validationError != null) {
      debugPrint('❌ Registration validation failed: $validationError');
      return null;
    }

    if (userId == null || !state.isComplete) {
      debugPrint('❌ Cannot complete registration: userId=$userId, isComplete=${state.isComplete}');
      return null;
    }

    try {
      debugPrint('🔵 Starting supplier registration...');
      debugPrint('📝 Business Name: ${state.businessName}');
      debugPrint('📝 Description: ${state.description}');
      debugPrint('📝 Category: ${state.serviceType}');
      debugPrint('📸 Profile Image: ${state.profileImage != null}');
      debugPrint('📸 Portfolio Images: ${state.portfolioImages?.length ?? 0}');

      // Get city and province from state
      final city = state.city;
      final province = state.province ?? 'Luanda';

      // Create supplier profile FIRST (without photos)
      debugPrint('📤 Creating supplier document...');
      final supplierId = await _ref.read(supplierProvider.notifier).createSupplier(
        businessName: state.businessName!,
        category: state.serviceType ?? 'Outro',
        description: state.description!,
        subcategories: state.eventTypes ?? [],
        phone: state.phone,
        email: state.email,
        city: city,
        province: province,
      );

      if (supplierId == null) {
        debugPrint('❌ Failed to create supplier document');
        return null;
      }
      debugPrint('✅ Supplier document created with ID: $supplierId');

      // NOW upload photos with the correct supplier ID
      List<String> photoUrls = [];
      if (state.profileImage != null) {
        debugPrint('📤 Uploading profile image...');
        final urls = await _repository.uploadSupplierPhotos(
          supplierId, // ✅ Use actual supplier ID, not temp
          [state.profileImage!],
        );
        photoUrls.addAll(urls);
        debugPrint('✅ Profile image uploaded: ${urls.first}');
      }

      // Upload portfolio images
      if (state.portfolioImages != null && state.portfolioImages!.isNotEmpty) {
        debugPrint('📤 Uploading ${state.portfolioImages!.length} portfolio images...');
        final urls = await _repository.uploadSupplierPhotos(
          supplierId, // ✅ Use actual supplier ID
          state.portfolioImages!,
        );
        photoUrls.addAll(urls);
        debugPrint('✅ Portfolio images uploaded: ${urls.length} photos');
      }

      // Upload identity document file if provided
      String? idDocumentUrl;
      if (state.idDocumentFile != null) {
        debugPrint('📤 Uploading identity document...');
        final docUrls = await _repository.uploadSupplierPhotos(
          supplierId,
          [state.idDocumentFile!],
        );
        if (docUrls.isNotEmpty) {
          idDocumentUrl = docUrls.first;
          debugPrint('✅ Identity document uploaded: $idDocumentUrl');
        }
      }

      // Update supplier with photos and additional data
      final updateData = <String, dynamic>{
        // 🔵 ONBOARDING: Set account status to PENDING_REVIEW (Uber-style workflow)
        'accountStatus': SupplierAccountStatus.pendingReview.name,
        'entityType': state.entityType.name,
      };

      // Add NIF if provided (required for empresa)
      if (state.nif != null && state.nif!.isNotEmpty) {
        updateData['nif'] = state.nif;
      }

      // Add identity document info
      if (state.idDocumentType != null) {
        updateData['idDocumentType'] = state.idDocumentType!.name;
      }
      if (state.idDocumentNumber != null && state.idDocumentNumber!.isNotEmpty) {
        updateData['idDocumentNumber'] = state.idDocumentNumber;
      }
      if (idDocumentUrl != null) {
        updateData['idDocumentUrl'] = idDocumentUrl;
      }

      if (photoUrls.isNotEmpty) {
        updateData['photos'] = photoUrls;
        debugPrint('📸 Total photos to save: ${photoUrls.length}');
      }
      if (state.whatsapp != null && state.whatsapp!.isNotEmpty) {
        updateData['whatsapp'] = state.whatsapp;
      }
      if (state.minPrice != null) {
        updateData['minPrice'] = int.tryParse(state.minPrice!) ?? 0;
      }
      if (state.maxPrice != null) {
        updateData['maxPrice'] = int.tryParse(state.maxPrice!) ?? 0;
      }

      debugPrint('📤 Updating supplier with onboarding data...');
      debugPrint('📋 Update fields: ${updateData.keys.join(', ')}');
      debugPrint('🔵 Account Status: PENDING_REVIEW');
      await _repository.updateSupplier(supplierId, updateData);
      debugPrint('✅ Supplier updated successfully with PENDING_REVIEW status');

      // Clear registration data
      reset();

      debugPrint('🎉 ✅ Supplier registration completed successfully!');
      debugPrint('🆔 Supplier ID: $supplierId');
      debugPrint('📸 Photos saved: ${photoUrls.length}');
      return supplierId;
    } catch (e, stackTrace) {
      debugPrint('❌ Error completing registration: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
}

/// Supplier Registration Provider
final supplierRegistrationProvider =
    StateNotifierProvider<SupplierRegistrationNotifier, SupplierRegistrationData>(
  (ref) {
    final repository = ref.watch(supplierRepositoryProvider);
    return SupplierRegistrationNotifier(repository, ref);
  },
);
