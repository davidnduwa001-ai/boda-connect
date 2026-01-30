/// Service that provides category-specific configurations for package creation
/// This enforces domain consistency - once a category is selected, only that
/// category's options, suggestions, and fields are shown
class CategoryConfigService {
  /// Get configuration for a specific category
  static CategoryConfig getConfig(String category) {
    return _categoryConfigs[category] ?? _defaultConfig;
  }

  /// Get all available categories
  static List<CategoryInfo> get categories => _categories;

  static final List<CategoryInfo> _categories = [
    CategoryInfo(name: 'Catering', icon: '🍽️', color: 0xFFFFF3E0),
    CategoryInfo(name: 'Decoração', icon: '🎨', color: 0xFFE8F5E9),
    CategoryInfo(name: 'Fotografia', icon: '📸', color: 0xFFF3E5F5),
    CategoryInfo(name: 'Música & DJ', icon: '🎵', color: 0xFFFCE4EC),
    CategoryInfo(name: 'Local', icon: '🏛️', color: 0xFFE3F2FD),
    CategoryInfo(name: 'Vestuário', icon: '👔', color: 0xFFF5F5F5),
    CategoryInfo(name: 'Beleza & Makeup', icon: '💄', color: 0xFFFCE4EC),
    CategoryInfo(name: 'Transporte', icon: '🚗', color: 0xFFE0F7FA),
    CategoryInfo(name: 'Convites', icon: '💌', color: 0xFFFFEBEE),
    CategoryInfo(name: 'Bolo & Doces', icon: '🎂', color: 0xFFFFF8E1),
  ];

  static final CategoryConfig _defaultConfig = CategoryConfig(
    suggestedIncludes: ['Consulta inicial', 'Orçamento personalizado'],
    suggestedCustomizations: [],
    specificFields: [],
    pricingLabel: 'Preço base (AOA)',
    durationLabel: 'Duração do serviço',
    guestsLabel: 'Número máximo de convidados',
    showGuestsField: true,
    showDurationField: true,
  );

  static final Map<String, CategoryConfig> _categoryConfigs = {
    // ==================== FOTOGRAFIA ====================
    'Fotografia': CategoryConfig(
      suggestedIncludes: [
        'Cobertura completa do evento',
        'Álbum digital com todas as fotos',
        'Edição profissional',
        'Fotos em alta resolução',
        'Sessão pré-evento (ensaio)',
        'Entrega em pen drive',
        'Galeria online privada',
        'Fotos impressas (10x15)',
        'Segundo fotógrafo',
        'Drone para fotos aéreas',
      ],
      suggestedCustomizations: [
        CustomizationSuggestion(name: 'Álbum impresso premium', suggestedPrice: 75000),
        CustomizationSuggestion(name: 'Sessão trash the dress', suggestedPrice: 50000),
        CustomizationSuggestion(name: 'Vídeo highlights (3-5 min)', suggestedPrice: 100000),
        CustomizationSuggestion(name: 'Segundo fotógrafo', suggestedPrice: 80000),
        CustomizationSuggestion(name: 'Cobertura drone', suggestedPrice: 60000),
        CustomizationSuggestion(name: 'Fotos extras impressas (pacote 50)', suggestedPrice: 25000),
        CustomizationSuggestion(name: 'Quadro canvas 40x60', suggestedPrice: 45000),
        CustomizationSuggestion(name: 'Making of noiva', suggestedPrice: 40000),
      ],
      specificFields: [
        CategoryField(
          id: 'deliveryDays',
          label: 'Prazo de entrega (dias)',
          hint: 'Ex: 30 dias',
          type: FieldType.number,
          required: true,
        ),
        CategoryField(
          id: 'minPhotos',
          label: 'Quantidade mínima de fotos',
          hint: 'Ex: 300 fotos editadas',
          type: FieldType.number,
          required: true,
        ),
        CategoryField(
          id: 'equipmentIncluded',
          label: 'Equipamento incluído',
          hint: 'Ex: Câmera profissional, iluminação, flash',
          type: FieldType.text,
          required: false,
        ),
      ],
      pricingLabel: 'Preço do pacote (AOA)',
      durationLabel: 'Horas de cobertura',
      guestsLabel: 'Número de convidados',
      showGuestsField: false,
      showDurationField: true,
    ),

    // ==================== CATERING ====================
    'Catering': CategoryConfig(
      suggestedIncludes: [
        'Menu completo (entrada, prato principal, sobremesa)',
        'Bebidas (refrigerantes, sumos)',
        'Pessoal de serviço (garçons)',
        'Louça e talheres',
        'Toalhas de mesa',
        'Montagem e desmontagem',
        'Degustação prévia',
        'Bebidas alcoólicas',
        'Mesa de doces',
        'Estação de café',
      ],
      suggestedCustomizations: [
        CustomizationSuggestion(name: 'Open bar premium', suggestedPrice: 150000),
        CustomizationSuggestion(name: 'Menu vegetariano/vegano', suggestedPrice: 20000),
        CustomizationSuggestion(name: 'Estação de sushi', suggestedPrice: 80000),
        CustomizationSuggestion(name: 'Churrasqueira ao vivo', suggestedPrice: 100000),
        CustomizationSuggestion(name: 'Mesa de queijos e frios', suggestedPrice: 60000),
        CustomizationSuggestion(name: 'Fonte de chocolate', suggestedPrice: 45000),
        CustomizationSuggestion(name: 'Garçom extra', suggestedPrice: 25000),
        CustomizationSuggestion(name: 'Finger food (por pessoa)', suggestedPrice: 5000),
      ],
      specificFields: [
        CategoryField(
          id: 'pricePerPerson',
          label: 'Preço por pessoa (AOA)',
          hint: 'Ex: 15000',
          type: FieldType.number,
          required: true,
        ),
        CategoryField(
          id: 'menuType',
          label: 'Tipo de menu',
          hint: 'Selecione o tipo',
          type: FieldType.dropdown,
          options: ['Buffet', 'Empratado', 'Coquetel', 'Misto'],
          required: true,
        ),
        CategoryField(
          id: 'cuisineStyle',
          label: 'Estilo de cozinha',
          hint: 'Ex: Angolana, Internacional, Fusão',
          type: FieldType.text,
          required: false,
        ),
      ],
      pricingLabel: 'Preço base do pacote (AOA)',
      durationLabel: 'Duração do serviço',
      guestsLabel: 'Número mínimo de convidados',
      showGuestsField: true,
      showDurationField: true,
    ),

    // ==================== DECORAÇÃO ====================
    'Decoração': CategoryConfig(
      suggestedIncludes: [
        'Decoração completa do espaço',
        'Arranjos florais',
        'Iluminação decorativa',
        'Toalhas e guardanapos',
        'Centro de mesa',
        'Backdrop/painel de fotos',
        'Montagem e desmontagem',
        'Arco de flores',
        'Velas e castiçais',
        'Cortinas e tecidos',
      ],
      suggestedCustomizations: [
        CustomizationSuggestion(name: 'Flores naturais premium', suggestedPrice: 80000),
        CustomizationSuggestion(name: 'Iluminação LED extra', suggestedPrice: 50000),
        CustomizationSuggestion(name: 'Arco de flores natural', suggestedPrice: 120000),
        CustomizationSuggestion(name: 'Cortina de luzes', suggestedPrice: 35000),
        CustomizationSuggestion(name: 'Letras luminosas (LOVE/nomes)', suggestedPrice: 40000),
        CustomizationSuggestion(name: 'Tapete vermelho', suggestedPrice: 25000),
        CustomizationSuggestion(name: 'Pétalas para corredor', suggestedPrice: 15000),
        CustomizationSuggestion(name: 'Balões com gás hélio (pacote)', suggestedPrice: 30000),
      ],
      specificFields: [
        CategoryField(
          id: 'decorStyle',
          label: 'Estilo de decoração',
          hint: 'Selecione o estilo',
          type: FieldType.dropdown,
          options: ['Clássico', 'Rústico', 'Moderno', 'Romântico', 'Boho', 'Minimalista', 'Tropical'],
          required: true,
        ),
        CategoryField(
          id: 'colorPalette',
          label: 'Paleta de cores principal',
          hint: 'Ex: Dourado e branco, Rosa e verde',
          type: FieldType.text,
          required: false,
        ),
        CategoryField(
          id: 'includesFlowers',
          label: 'Inclui flores naturais?',
          hint: '',
          type: FieldType.checkbox,
          required: false,
        ),
      ],
      pricingLabel: 'Preço do pacote (AOA)',
      durationLabel: 'Tempo de montagem',
      guestsLabel: 'Capacidade do espaço',
      showGuestsField: true,
      showDurationField: false,
    ),

    // ==================== MÚSICA & DJ ====================
    'Música & DJ': CategoryConfig(
      suggestedIncludes: [
        'DJ profissional',
        'Equipamento de som completo',
        'Iluminação de pista',
        'Microfone sem fio',
        'Playlist personalizada',
        'MC/Animador',
        'Máquina de fumaça',
        'Colunas de som',
        'Mesa de mistura',
        'Efeitos especiais (laser)',
      ],
      suggestedCustomizations: [
        CustomizationSuggestion(name: 'Banda ao vivo (acústico)', suggestedPrice: 200000),
        CustomizationSuggestion(name: 'Saxofonista', suggestedPrice: 80000),
        CustomizationSuggestion(name: 'Hora extra de música', suggestedPrice: 50000),
        CustomizationSuggestion(name: 'Violinista para cerimónia', suggestedPrice: 60000),
        CustomizationSuggestion(name: 'Karaoke', suggestedPrice: 40000),
        CustomizationSuggestion(name: 'Iluminação robotizada extra', suggestedPrice: 45000),
        CustomizationSuggestion(name: 'Canhão de confetes', suggestedPrice: 25000),
        CustomizationSuggestion(name: 'Pista de dança LED', suggestedPrice: 150000),
      ],
      specificFields: [
        CategoryField(
          id: 'musicGenres',
          label: 'Géneros musicais',
          hint: 'Ex: Kizomba, Semba, Afrobeats, Internacional',
          type: FieldType.text,
          required: true,
        ),
        CategoryField(
          id: 'soundPower',
          label: 'Potência do som (watts)',
          hint: 'Ex: 5000W',
          type: FieldType.text,
          required: false,
        ),
      ],
      pricingLabel: 'Preço do pacote (AOA)',
      durationLabel: 'Horas de música',
      guestsLabel: 'Capacidade máxima do evento',
      showGuestsField: true,
      showDurationField: true,
    ),

    // ==================== LOCAL ====================
    'Local': CategoryConfig(
      suggestedIncludes: [
        'Aluguer do espaço',
        'Mesas e cadeiras',
        'Estacionamento',
        'Segurança',
        'Limpeza pós-evento',
        'Ar condicionado',
        'Casa de banho',
        'Cozinha de apoio',
        'Espaço para cerimónia',
        'Área externa/jardim',
      ],
      suggestedCustomizations: [
        CustomizationSuggestion(name: 'Hora extra de aluguer', suggestedPrice: 50000),
        CustomizationSuggestion(name: 'Gerador de emergência', suggestedPrice: 80000),
        CustomizationSuggestion(name: 'Tenda exterior', suggestedPrice: 100000),
        CustomizationSuggestion(name: 'Serviço de valet parking', suggestedPrice: 60000),
        CustomizationSuggestion(name: 'Suite nupcial', suggestedPrice: 120000),
        CustomizationSuggestion(name: 'Piscina (acesso)', suggestedPrice: 50000),
        CustomizationSuggestion(name: 'Segurança extra', suggestedPrice: 30000),
      ],
      specificFields: [
        CategoryField(
          id: 'venueType',
          label: 'Tipo de espaço',
          hint: 'Selecione o tipo',
          type: FieldType.dropdown,
          options: ['Salão de festas', 'Quinta', 'Hotel', 'Restaurante', 'Praia', 'Jardim', 'Rooftop'],
          required: true,
        ),
        CategoryField(
          id: 'hasOutdoorSpace',
          label: 'Possui espaço exterior?',
          hint: '',
          type: FieldType.checkbox,
          required: false,
        ),
        CategoryField(
          id: 'parkingSpaces',
          label: 'Lugares de estacionamento',
          hint: 'Ex: 50',
          type: FieldType.number,
          required: false,
        ),
      ],
      pricingLabel: 'Preço de aluguer (AOA)',
      durationLabel: 'Duração do aluguer (horas)',
      guestsLabel: 'Capacidade máxima',
      showGuestsField: true,
      showDurationField: true,
    ),

    // ==================== VESTUÁRIO ====================
    'Vestuário': CategoryConfig(
      suggestedIncludes: [
        'Vestido/Fato principal',
        'Ajustes e alterações',
        'Acessórios (véu, gravata)',
        'Prova de roupa',
        'Entrega e recolha',
        'Lavagem profissional',
        'Sapatos',
        'Joias/Bijuteria',
        'Roupa para padrinho/madrinha',
      ],
      suggestedCustomizations: [
        CustomizationSuggestion(name: 'Segundo vestido/traje', suggestedPrice: 150000),
        CustomizationSuggestion(name: 'Véu longo personalizado', suggestedPrice: 40000),
        CustomizationSuggestion(name: 'Sapatos de designer', suggestedPrice: 60000),
        CustomizationSuggestion(name: 'Coroa/Tiara', suggestedPrice: 35000),
        CustomizationSuggestion(name: 'Abotoaduras personalizadas', suggestedPrice: 20000),
        CustomizationSuggestion(name: 'Faixa/cinto bordado', suggestedPrice: 25000),
        CustomizationSuggestion(name: 'Robe de noiva', suggestedPrice: 30000),
      ],
      specificFields: [
        CategoryField(
          id: 'clothingType',
          label: 'Tipo de vestuário',
          hint: 'Selecione o tipo',
          type: FieldType.dropdown,
          options: ['Vestido de noiva', 'Fato de noivo', 'Vestido de cerimónia', 'Fato clássico', 'Traje tradicional', 'Aluguer'],
          required: true,
        ),
        CategoryField(
          id: 'isCustomMade',
          label: 'Feito sob medida?',
          hint: '',
          type: FieldType.checkbox,
          required: false,
        ),
        CategoryField(
          id: 'fittingsIncluded',
          label: 'Número de provas incluídas',
          hint: 'Ex: 3',
          type: FieldType.number,
          required: false,
        ),
      ],
      pricingLabel: 'Preço (AOA)',
      durationLabel: 'Prazo de preparação',
      guestsLabel: '',
      showGuestsField: false,
      showDurationField: false,
    ),

    // ==================== BELEZA & MAKEUP ====================
    'Beleza & Makeup': CategoryConfig(
      suggestedIncludes: [
        'Maquilhagem completa',
        'Penteado',
        'Prova de maquilhagem',
        'Retoque durante o evento',
        'Produtos de alta qualidade',
        'Cílios postiços',
        'Manicure',
        'Pedicure',
        'Tratamento facial pré-evento',
        'Maquilhagem para madrinhas',
      ],
      suggestedCustomizations: [
        CustomizationSuggestion(name: 'Maquilhagem para mãe da noiva', suggestedPrice: 35000),
        CustomizationSuggestion(name: 'Maquilhagem para madrinha', suggestedPrice: 25000),
        CustomizationSuggestion(name: 'Extensões de cabelo', suggestedPrice: 80000),
        CustomizationSuggestion(name: 'Manicure gel', suggestedPrice: 15000),
        CustomizationSuggestion(name: 'Tratamento spa pré-casamento', suggestedPrice: 60000),
        CustomizationSuggestion(name: 'Retoque extra (por hora)', suggestedPrice: 20000),
        CustomizationSuggestion(name: 'Cílios de mink premium', suggestedPrice: 25000),
        CustomizationSuggestion(name: 'Airbrush makeup', suggestedPrice: 40000),
      ],
      specificFields: [
        CategoryField(
          id: 'serviceType',
          label: 'Tipo de serviço',
          hint: 'Selecione os serviços',
          type: FieldType.dropdown,
          options: ['Maquilhagem', 'Penteado', 'Maquilhagem + Penteado', 'Pacote completo (noiva)'],
          required: true,
        ),
        CategoryField(
          id: 'includesTrial',
          label: 'Inclui prova?',
          hint: '',
          type: FieldType.checkbox,
          required: false,
        ),
        CategoryField(
          id: 'travelIncluded',
          label: 'Deslocação incluída?',
          hint: '',
          type: FieldType.checkbox,
          required: false,
        ),
      ],
      pricingLabel: 'Preço do serviço (AOA)',
      durationLabel: 'Duração do serviço',
      guestsLabel: '',
      showGuestsField: false,
      showDurationField: true,
    ),

    // ==================== TRANSPORTE ====================
    'Transporte': CategoryConfig(
      suggestedIncludes: [
        'Veículo decorado',
        'Motorista profissional',
        'Champanhe a bordo',
        'Água e bebidas',
        'Decoração floral',
        'Ar condicionado',
        'Sistema de som',
        'Transporte para convidados',
        'Tapete vermelho',
      ],
      suggestedCustomizations: [
        CustomizationSuggestion(name: 'Hora extra', suggestedPrice: 40000),
        CustomizationSuggestion(name: 'Decoração premium', suggestedPrice: 50000),
        CustomizationSuggestion(name: 'Segundo veículo', suggestedPrice: 120000),
        CustomizationSuggestion(name: 'Van para padrinhos', suggestedPrice: 80000),
        CustomizationSuggestion(name: 'Champanhe premium', suggestedPrice: 35000),
        CustomizationSuggestion(name: 'Fotógrafo a bordo', suggestedPrice: 60000),
      ],
      specificFields: [
        CategoryField(
          id: 'vehicleType',
          label: 'Tipo de veículo',
          hint: 'Selecione o tipo',
          type: FieldType.dropdown,
          options: ['Limousine', 'Carro clássico', 'SUV de luxo', 'Sedan executivo', 'Van', 'Carrinha vintage'],
          required: true,
        ),
        CategoryField(
          id: 'vehicleBrand',
          label: 'Marca/Modelo',
          hint: 'Ex: Mercedes S-Class, Rolls Royce',
          type: FieldType.text,
          required: false,
        ),
        CategoryField(
          id: 'passengerCapacity',
          label: 'Capacidade de passageiros',
          hint: 'Ex: 4',
          type: FieldType.number,
          required: true,
        ),
      ],
      pricingLabel: 'Preço do serviço (AOA)',
      durationLabel: 'Duração do aluguer (horas)',
      guestsLabel: '',
      showGuestsField: false,
      showDurationField: true,
    ),

    // ==================== CONVITES ====================
    'Convites': CategoryConfig(
      suggestedIncludes: [
        'Design personalizado',
        'Impressão de qualidade',
        'Envelopes',
        'Convites digitais',
        'RSVP online',
        'Mapa do local',
        'Save the date',
        'Menu impresso',
        'Etiquetas',
        'Cartões de agradecimento',
      ],
      suggestedCustomizations: [
        CustomizationSuggestion(name: 'Papel premium/texturizado', suggestedPrice: 15000),
        CustomizationSuggestion(name: 'Lacre de cera', suggestedPrice: 20000),
        CustomizationSuggestion(name: 'Fita de cetim', suggestedPrice: 10000),
        CustomizationSuggestion(name: 'Convite em caixa', suggestedPrice: 50000),
        CustomizationSuggestion(name: 'Impressão em relevo', suggestedPrice: 25000),
        CustomizationSuggestion(name: 'Website do casamento', suggestedPrice: 80000),
        CustomizationSuggestion(name: 'Vídeo convite digital', suggestedPrice: 60000),
      ],
      specificFields: [
        CategoryField(
          id: 'inviteStyle',
          label: 'Estilo do convite',
          hint: 'Selecione o estilo',
          type: FieldType.dropdown,
          options: ['Clássico', 'Moderno', 'Rústico', 'Minimalista', 'Floral', 'Tradicional angolano'],
          required: true,
        ),
        CategoryField(
          id: 'quantity',
          label: 'Quantidade de convites',
          hint: 'Ex: 100',
          type: FieldType.number,
          required: true,
        ),
        CategoryField(
          id: 'includesDigital',
          label: 'Inclui versão digital?',
          hint: '',
          type: FieldType.checkbox,
          required: false,
        ),
      ],
      pricingLabel: 'Preço por unidade (AOA)',
      durationLabel: 'Prazo de entrega (dias)',
      guestsLabel: '',
      showGuestsField: false,
      showDurationField: true,
    ),

    // ==================== BOLO & DOCES ====================
    'Bolo & Doces': CategoryConfig(
      suggestedIncludes: [
        'Bolo de casamento',
        'Decoração do bolo',
        'Entrega e montagem',
        'Suporte/base para bolo',
        'Faca decorada',
        'Doces tradicionais',
        'Cupcakes',
        'Mesa de doces completa',
        'Prova de sabores',
        'Bem-casados',
      ],
      suggestedCustomizations: [
        CustomizationSuggestion(name: 'Andar extra no bolo', suggestedPrice: 40000),
        CustomizationSuggestion(name: 'Flores de açúcar', suggestedPrice: 35000),
        CustomizationSuggestion(name: 'Topo personalizado', suggestedPrice: 20000),
        CustomizationSuggestion(name: 'Doces gourmet (por unidade)', suggestedPrice: 500),
        CustomizationSuggestion(name: 'Cascata de chocolate', suggestedPrice: 60000),
        CustomizationSuggestion(name: 'Naked cake upgrade', suggestedPrice: 30000),
        CustomizationSuggestion(name: 'Macarons (dúzia)', suggestedPrice: 15000),
        CustomizationSuggestion(name: 'Cake pops (dúzia)', suggestedPrice: 12000),
      ],
      specificFields: [
        CategoryField(
          id: 'cakeFlavor',
          label: 'Sabor principal',
          hint: 'Selecione o sabor',
          type: FieldType.dropdown,
          options: ['Baunilha', 'Chocolate', 'Red Velvet', 'Limão', 'Morango', 'Coco', 'Frutos tropicais'],
          required: true,
        ),
        CategoryField(
          id: 'cakeTiers',
          label: 'Número de andares',
          hint: 'Ex: 3',
          type: FieldType.number,
          required: true,
        ),
        CategoryField(
          id: 'servings',
          label: 'Porções (pessoas)',
          hint: 'Ex: 100',
          type: FieldType.number,
          required: true,
        ),
      ],
      pricingLabel: 'Preço do pacote (AOA)',
      durationLabel: 'Prazo de encomenda (dias)',
      guestsLabel: '',
      showGuestsField: false,
      showDurationField: true,
    ),
  };
}

/// Information about a category
class CategoryInfo {
  final String name;
  final String icon;
  final int color;

  const CategoryInfo({
    required this.name,
    required this.icon,
    required this.color,
  });
}

/// Configuration for a specific category
class CategoryConfig {
  /// Suggested items to include in the package
  final List<String> suggestedIncludes;

  /// Suggested customization options with prices
  final List<CustomizationSuggestion> suggestedCustomizations;

  /// Category-specific form fields
  final List<CategoryField> specificFields;

  /// Label for the pricing field
  final String pricingLabel;

  /// Label for the duration field
  final String durationLabel;

  /// Label for the guests field
  final String guestsLabel;

  /// Whether to show the guests field
  final bool showGuestsField;

  /// Whether to show the duration field
  final bool showDurationField;

  const CategoryConfig({
    required this.suggestedIncludes,
    required this.suggestedCustomizations,
    required this.specificFields,
    required this.pricingLabel,
    required this.durationLabel,
    required this.guestsLabel,
    required this.showGuestsField,
    required this.showDurationField,
  });
}

/// A suggested customization option
class CustomizationSuggestion {
  final String name;
  final int suggestedPrice;
  final String? description;

  const CustomizationSuggestion({
    required this.name,
    required this.suggestedPrice,
    this.description,
  });
}

/// A category-specific form field
class CategoryField {
  final String id;
  final String label;
  final String hint;
  final FieldType type;
  final List<String>? options;
  final bool required;

  const CategoryField({
    required this.id,
    required this.label,
    required this.hint,
    required this.type,
    this.options,
    required this.required,
  });
}

/// Type of form field
enum FieldType {
  text,
  number,
  dropdown,
  checkbox,
}
