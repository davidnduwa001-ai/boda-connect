import '../models/supplier_model.dart';

/// Service to calculate profile completeness score for suppliers
class ProfileCompletenessService {
  /// Calculate overall profile completeness percentage
  static ProfileCompletenessResult calculateCompleteness(SupplierModel supplier, {int packageCount = 0}) {
    final items = <CompletenessItem>[];

    // Required fields (higher weight)
    items.add(CompletenessItem(
      field: 'businessName',
      label: 'Nome do negócio',
      weight: 10,
      isComplete: supplier.businessName.isNotEmpty,
      tip: 'Adicione o nome do seu negócio',
    ));

    items.add(CompletenessItem(
      field: 'description',
      label: 'Descrição',
      weight: 10,
      isComplete: supplier.description.isNotEmpty && supplier.description.length >= 50,
      tip: 'Escreva uma descrição detalhada (mín. 50 caracteres)',
    ));

    items.add(CompletenessItem(
      field: 'category',
      label: 'Categoria',
      weight: 10,
      isComplete: supplier.category.isNotEmpty,
      tip: 'Selecione sua categoria de serviço',
    ));

    items.add(CompletenessItem(
      field: 'phone',
      label: 'Telefone',
      weight: 10,
      isComplete: supplier.phone != null && supplier.phone!.isNotEmpty,
      tip: 'Adicione seu número de telefone',
    ));

    items.add(CompletenessItem(
      field: 'location',
      label: 'Localização',
      weight: 10,
      isComplete: supplier.location?.province != null && supplier.location!.province!.isNotEmpty,
      tip: 'Defina sua localização (província e cidade)',
    ));

    // Important fields (medium weight)
    items.add(CompletenessItem(
      field: 'photos',
      label: 'Foto de perfil',
      weight: 8,
      isComplete: supplier.photos.isNotEmpty,
      tip: 'Adicione uma foto de perfil profissional',
    ));

    items.add(CompletenessItem(
      field: 'portfolioPhotos',
      label: 'Portfólio',
      weight: 8,
      isComplete: supplier.portfolioPhotos.length >= 3,
      tip: 'Adicione pelo menos 3 fotos do seu trabalho',
    ));

    items.add(CompletenessItem(
      field: 'packages',
      label: 'Pacotes',
      weight: 10,
      isComplete: packageCount >= 1,
      tip: 'Crie pelo menos 1 pacote de serviços',
    ));

    items.add(CompletenessItem(
      field: 'subcategories',
      label: 'Especialidades',
      weight: 6,
      isComplete: supplier.subcategories.isNotEmpty,
      tip: 'Selecione suas especialidades',
    ));

    items.add(CompletenessItem(
      field: 'workingHours',
      label: 'Horário de funcionamento',
      weight: 5,
      isComplete: supplier.workingHours != null && supplier.workingHours!.schedule.isNotEmpty,
      tip: 'Defina seu horário de atendimento',
    ));

    // Optional but recommended (lower weight)
    items.add(CompletenessItem(
      field: 'email',
      label: 'Email',
      weight: 4,
      isComplete: supplier.email != null && supplier.email!.isNotEmpty,
      tip: 'Adicione um email de contacto',
    ));

    items.add(CompletenessItem(
      field: 'whatsapp',
      label: 'WhatsApp',
      weight: 4,
      isComplete: supplier.whatsapp != null && supplier.whatsapp!.isNotEmpty,
      tip: 'Adicione seu número de WhatsApp',
    ));

    items.add(CompletenessItem(
      field: 'yearsExperience',
      label: 'Anos de experiência',
      weight: 3,
      isComplete: supplier.yearsExperience != null && supplier.yearsExperience! > 0,
      tip: 'Informe seus anos de experiência',
    ));

    items.add(CompletenessItem(
      field: 'teamSize',
      label: 'Tamanho da equipe',
      weight: 2,
      isComplete: supplier.teamSize != null && supplier.teamSize! > 0,
      tip: 'Informe o tamanho da sua equipe',
    ));

    // Calculate totals
    int totalWeight = 0;
    int completedWeight = 0;
    final missingItems = <CompletenessItem>[];

    for (final item in items) {
      totalWeight += item.weight;
      if (item.isComplete) {
        completedWeight += item.weight;
      } else {
        missingItems.add(item);
      }
    }

    final percentage = totalWeight > 0 ? (completedWeight / totalWeight * 100).round() : 0;

    // Sort missing items by weight (most important first)
    missingItems.sort((a, b) => b.weight.compareTo(a.weight));

    return ProfileCompletenessResult(
      percentage: percentage,
      items: items,
      missingItems: missingItems,
      nextTip: missingItems.isNotEmpty ? missingItems.first.tip : null,
    );
  }

  /// Get the color for a completeness percentage
  static CompletenessLevel getLevel(int percentage) {
    if (percentage >= 90) {
      return CompletenessLevel.excellent;
    } else if (percentage >= 70) {
      return CompletenessLevel.good;
    } else if (percentage >= 50) {
      return CompletenessLevel.fair;
    } else {
      return CompletenessLevel.needsWork;
    }
  }
}

/// Result of profile completeness calculation
class ProfileCompletenessResult {
  final int percentage;
  final List<CompletenessItem> items;
  final List<CompletenessItem> missingItems;
  final String? nextTip;

  const ProfileCompletenessResult({
    required this.percentage,
    required this.items,
    required this.missingItems,
    this.nextTip,
  });

  CompletenessLevel get level => ProfileCompletenessService.getLevel(percentage);

  bool get isComplete => percentage >= 100;
}

/// Individual item in completeness check
class CompletenessItem {
  final String field;
  final String label;
  final int weight;
  final bool isComplete;
  final String tip;

  const CompletenessItem({
    required this.field,
    required this.label,
    required this.weight,
    required this.isComplete,
    required this.tip,
  });
}

/// Level of profile completeness
enum CompletenessLevel {
  excellent,
  good,
  fair,
  needsWork;

  String get label {
    switch (this) {
      case CompletenessLevel.excellent:
        return 'Excelente';
      case CompletenessLevel.good:
        return 'Bom';
      case CompletenessLevel.fair:
        return 'Razoável';
      case CompletenessLevel.needsWork:
        return 'Precisa melhorar';
    }
  }

  String get emoji {
    switch (this) {
      case CompletenessLevel.excellent:
        return '🌟';
      case CompletenessLevel.good:
        return '👍';
      case CompletenessLevel.fair:
        return '📝';
      case CompletenessLevel.needsWork:
        return '⚠️';
    }
  }
}
