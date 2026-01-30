/// Service for validating supplier category/specialty selections
/// Implements mutually exclusive category groups to prevent category clashing
class CategoryValidationService {
  static final CategoryValidationService _instance = CategoryValidationService._();
  factory CategoryValidationService() => _instance;
  CategoryValidationService._();

  /// Industry groups - categories within each group are mutually exclusive with other groups
  /// A supplier can only select specialties from ONE industry group
  static const Map<String, List<String>> industryGroups = {
    // MEDIA INDUSTRY - Visual content creators
    'media': [
      'photography',   // Fotografia
      'music_dj',      // Música & DJ (includes videography aspects)
    ],

    // HOSPITALITY INDUSTRY - Food & Beverage
    'hospitality': [
      'catering',      // Catering
    ],

    // CREATIVE INDUSTRY - Design & Aesthetics
    'creative': [
      'decoration',    // Decoração
      'beauty',        // Beleza
    ],

    // VENUES INDUSTRY - Event spaces
    'venues': [
      'venue',         // Local
    ],

    // LOGISTICS INDUSTRY - Transportation & Support
    'logistics': [
      'transportation', // Transporte
    ],

    // ENTERTAINMENT INDUSTRY - Performance & Animation
    'entertainment': [
      'entertainment', // Entretenimento
    ],
  };

  /// Get the industry group for a given category ID
  static String? getIndustryGroupForCategory(String categoryId) {
    for (final entry in industryGroups.entries) {
      if (entry.value.contains(categoryId)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Get display name for industry group (Portuguese)
  static String getIndustryGroupDisplayName(String groupId) {
    switch (groupId) {
      case 'media':
        return 'Mídia';
      case 'hospitality':
        return 'Hospitalidade';
      case 'creative':
        return 'Criativo';
      case 'venues':
        return 'Espaços';
      case 'logistics':
        return 'Logística';
      case 'entertainment':
        return 'Entretenimento';
      default:
        return groupId;
    }
  }

  /// Check if two categories are compatible (in the same industry group)
  static bool areCategoriesCompatible(String categoryId1, String categoryId2) {
    final group1 = getIndustryGroupForCategory(categoryId1);
    final group2 = getIndustryGroupForCategory(categoryId2);

    if (group1 == null || group2 == null) {
      return false; // Unknown categories are incompatible
    }

    return group1 == group2;
  }

  /// Validate a list of selected categories - all must be in the same industry
  static CategoryValidationResult validateCategories(List<String> categoryIds) {
    if (categoryIds.isEmpty) {
      return CategoryValidationResult(
        isValid: false,
        errorMessage: 'Selecione pelo menos uma categoria.',
      );
    }

    final firstCategory = categoryIds.first;
    final industryGroup = getIndustryGroupForCategory(firstCategory);

    if (industryGroup == null) {
      return CategoryValidationResult(
        isValid: false,
        errorMessage: 'Categoria desconhecida: $firstCategory',
      );
    }

    // Check all categories belong to the same industry
    for (final categoryId in categoryIds.skip(1)) {
      final group = getIndustryGroupForCategory(categoryId);
      if (group != industryGroup) {
        final groupName1 = getIndustryGroupDisplayName(industryGroup);
        final groupName2 = group != null ? getIndustryGroupDisplayName(group) : 'Desconhecido';

        return CategoryValidationResult(
          isValid: false,
          errorMessage: 'Especialidades Incompatíveis: Não pode selecionar serviços '
              'de grupos diferentes ($groupName1 e $groupName2). '
              'Selecione apenas serviços dentro do mesmo grupo de categoria.',
          conflictingCategories: [firstCategory, categoryId],
        );
      }
    }

    return CategoryValidationResult(
      isValid: true,
      industryGroup: industryGroup,
    );
  }

  /// Get all categories available for a given industry group
  static List<String> getCategoriesForIndustry(String industryGroup) {
    return industryGroups[industryGroup] ?? [];
  }

  /// Get all category IDs that are incompatible with the given category
  static List<String> getIncompatibleCategories(String categoryId) {
    final currentGroup = getIndustryGroupForCategory(categoryId);
    if (currentGroup == null) return [];

    final incompatible = <String>[];
    for (final entry in industryGroups.entries) {
      if (entry.key != currentGroup) {
        incompatible.addAll(entry.value);
      }
    }
    return incompatible;
  }

  /// Check if adding a new category would be valid given current selections
  static bool canAddCategory(String newCategoryId, List<String> currentCategories) {
    if (currentCategories.isEmpty) return true;

    final currentGroup = getIndustryGroupForCategory(currentCategories.first);
    final newGroup = getIndustryGroupForCategory(newCategoryId);

    return currentGroup == newGroup;
  }
}

/// Result of category validation
class CategoryValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? industryGroup;
  final List<String>? conflictingCategories;

  CategoryValidationResult({
    required this.isValid,
    this.errorMessage,
    this.industryGroup,
    this.conflictingCategories,
  });
}

/// Supplier registration validation service
/// Ensures all required fields are present before allowing supplier creation
class SupplierRegistrationValidator {

  /// Required fields for supplier registration
  static const List<String> requiredBasicFields = [
    'businessName',
    'phone',
    'province',
    'city',
  ];

  static const List<String> requiredServiceFields = [
    'category',
    'subcategories',
  ];

  static const List<String> requiredContentFields = [
    'description',
    'photos',
  ];

  /// Validate Step 1: Basic Data
  static RegistrationValidationResult validateBasicData({
    required String? name,
    required String? businessName,
    required String? phone,
    required String? province,
    required String? city,
  }) {
    final errors = <String>[];

    if (name == null || name.trim().isEmpty) {
      errors.add('Nome é obrigatório');
    }

    if (businessName == null || businessName.trim().isEmpty) {
      errors.add('Nome do negócio é obrigatório');
    }

    if (phone == null || phone.trim().isEmpty) {
      errors.add('Telefone é obrigatório');
    } else if (!_isValidPhone(phone)) {
      errors.add('Formato de telefone inválido');
    }

    if (province == null || province.trim().isEmpty) {
      errors.add('Província é obrigatória');
    }

    if (city == null || city.trim().isEmpty) {
      errors.add('Cidade é obrigatória');
    }

    return RegistrationValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      step: 1,
      stepName: 'Dados Básicos',
    );
  }

  /// Validate Step 2: Service Type
  static RegistrationValidationResult validateServiceType({
    required String? category,
    required List<String>? subcategories,
  }) {
    final errors = <String>[];

    if (category == null || category.trim().isEmpty) {
      errors.add('Categoria principal é obrigatória');
    }

    if (subcategories == null || subcategories.isEmpty) {
      errors.add('Selecione pelo menos uma especialidade');
    }

    // Validate category compatibility if multiple subcategories
    if (category != null && subcategories != null && subcategories.isNotEmpty) {
      final validation = CategoryValidationService.validateCategories([category]);
      if (!validation.isValid) {
        errors.add(validation.errorMessage ?? 'Categoria inválida');
      }
    }

    return RegistrationValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      step: 2,
      stepName: 'Tipo de Serviço',
    );
  }

  /// Validate Step 3: Description
  static RegistrationValidationResult validateDescription({
    required String? description,
    int minLength = 50,
    int maxLength = 500,
  }) {
    final errors = <String>[];

    if (description == null || description.trim().isEmpty) {
      errors.add('Descrição é obrigatória');
    } else {
      final length = description.trim().length;
      if (length < minLength) {
        errors.add('Descrição deve ter pelo menos $minLength caracteres (atual: $length)');
      }
      if (length > maxLength) {
        errors.add('Descrição não pode exceder $maxLength caracteres');
      }
    }

    return RegistrationValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      step: 3,
      stepName: 'Descrição',
    );
  }

  /// Validate Step 4: Content Upload
  static RegistrationValidationResult validateContent({
    required List<dynamic>? photos,
    int minPhotos = 5,
    int maxPhotos = 10,
  }) {
    final errors = <String>[];

    if (photos == null || photos.isEmpty) {
      errors.add('Fotos são obrigatórias');
    } else if (photos.length < minPhotos) {
      errors.add('Adicione pelo menos $minPhotos fotos (atual: ${photos.length})');
    } else if (photos.length > maxPhotos) {
      errors.add('Máximo de $maxPhotos fotos permitidas');
    }

    return RegistrationValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      step: 4,
      stepName: 'Portfólio',
    );
  }

  /// Validate Step 5: Pricing
  static RegistrationValidationResult validatePricing({
    required String? price,
    required bool priceOnRequest,
  }) {
    final errors = <String>[];

    if (!priceOnRequest && (price == null || price.trim().isEmpty)) {
      errors.add('Preço é obrigatório ou selecione "Preço sob consulta"');
    }

    if (!priceOnRequest && price != null && price.isNotEmpty) {
      final numericPrice = double.tryParse(price.replaceAll(',', '.'));
      if (numericPrice == null || numericPrice <= 0) {
        errors.add('Preço inválido');
      }
    }

    return RegistrationValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      step: 5,
      stepName: 'Preços',
    );
  }

  /// Validate complete registration before final submission
  static RegistrationValidationResult validateCompleteRegistration({
    required String? name,
    required String? businessName,
    required String? phone,
    required String? province,
    required String? city,
    required String? category,
    required List<String>? subcategories,
    required String? description,
    required List<dynamic>? photos,
    required String? price,
    required bool priceOnRequest,
  }) {
    final allErrors = <String>[];
    var firstFailedStep = 0;
    var firstFailedStepName = '';

    // Validate each step
    final step1 = validateBasicData(
      name: name,
      businessName: businessName,
      phone: phone,
      province: province,
      city: city,
    );
    if (!step1.isValid) {
      allErrors.addAll(step1.errors);
      if (firstFailedStep == 0) {
        firstFailedStep = 1;
        firstFailedStepName = step1.stepName;
      }
    }

    final step2 = validateServiceType(
      category: category,
      subcategories: subcategories,
    );
    if (!step2.isValid) {
      allErrors.addAll(step2.errors);
      if (firstFailedStep == 0) {
        firstFailedStep = 2;
        firstFailedStepName = step2.stepName;
      }
    }

    final step3 = validateDescription(description: description);
    if (!step3.isValid) {
      allErrors.addAll(step3.errors);
      if (firstFailedStep == 0) {
        firstFailedStep = 3;
        firstFailedStepName = step3.stepName;
      }
    }

    final step4 = validateContent(photos: photos);
    if (!step4.isValid) {
      allErrors.addAll(step4.errors);
      if (firstFailedStep == 0) {
        firstFailedStep = 4;
        firstFailedStepName = step4.stepName;
      }
    }

    final step5 = validatePricing(price: price, priceOnRequest: priceOnRequest);
    if (!step5.isValid) {
      allErrors.addAll(step5.errors);
      if (firstFailedStep == 0) {
        firstFailedStep = 5;
        firstFailedStepName = step5.stepName;
      }
    }

    return RegistrationValidationResult(
      isValid: allErrors.isEmpty,
      errors: allErrors,
      step: firstFailedStep,
      stepName: firstFailedStepName,
    );
  }

  static bool _isValidPhone(String phone) {
    // Remove spaces and special characters for validation
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    // Angola phone numbers: 9 digits starting with 9
    // Or with country code: +244 followed by 9 digits
    return RegExp(r'^(244)?9\d{8}$').hasMatch(cleaned);
  }
}

/// Result of registration validation
class RegistrationValidationResult {
  final bool isValid;
  final List<String> errors;
  final int step;
  final String stepName;

  RegistrationValidationResult({
    required this.isValid,
    required this.errors,
    required this.step,
    required this.stepName,
  });

  String get errorSummary => errors.join('\n');

  String get stepErrorMessage => isValid
      ? ''
      : 'Passo $step ($stepName): ${errors.first}';
}
