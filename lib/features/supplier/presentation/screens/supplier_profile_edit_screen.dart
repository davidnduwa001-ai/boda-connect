import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/angola_locations.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/supplier_provider.dart';
import '../../../../core/services/category_validation_service.dart';
import '../../../../core/services/location_service.dart';

class SupplierProfileEditScreen extends ConsumerStatefulWidget {
  const SupplierProfileEditScreen({super.key});

  @override
  ConsumerState<SupplierProfileEditScreen> createState() => _SupplierProfileEditScreenState();
}

class _SupplierProfileEditScreenState extends ConsumerState<SupplierProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _yearsExperienceController = TextEditingController();
  final _teamSizeController = TextEditingController();
  final _specialtiesController = TextEditingController();

  // Location dropdowns
  String? _selectedProvince;
  String? _selectedCity;
  List<String> _availableCities = [];

  // Category & Specialty (locked after initial selection)
  String? _selectedCategory;
  List<String> _selectedSubcategories = [];
  List<String> _availableSubcategories = [];
  final List<CategoryModel> _categories = getDefaultCategories();
  String? _categoryValidationError;

  ({XFile file, Uint8List bytes})? _selectedImage;
  bool _isLoading = false;
  bool _instantBooking = false;
  bool _customPackages = true;
  String _responseTime = 'Rápido';
  bool _isDetectingLocation = false;
  Position? _currentPosition;
  final LocationService _locationService = LocationService();

  // Languages selection
  List<String> _selectedLanguages = ['pt']; // Default to Portuguese

  // Business hours
  Map<String, Map<String, dynamic>> _workingHours = {
    'monday': {'isOpen': true, 'openTime': '08:00', 'closeTime': '18:00'},
    'tuesday': {'isOpen': true, 'openTime': '08:00', 'closeTime': '18:00'},
    'wednesday': {'isOpen': true, 'openTime': '08:00', 'closeTime': '18:00'},
    'thursday': {'isOpen': true, 'openTime': '08:00', 'closeTime': '18:00'},
    'friday': {'isOpen': true, 'openTime': '08:00', 'closeTime': '18:00'},
    'saturday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '13:00'},
    'sunday': {'isOpen': false, 'openTime': '08:00', 'closeTime': '18:00'},
  };

  static const List<Map<String, String>> _weekDays = [
    {'key': 'monday', 'name': 'Segunda-feira'},
    {'key': 'tuesday', 'name': 'Terça-feira'},
    {'key': 'wednesday', 'name': 'Quarta-feira'},
    {'key': 'thursday', 'name': 'Quinta-feira'},
    {'key': 'friday', 'name': 'Sexta-feira'},
    {'key': 'saturday', 'name': 'Sábado'},
    {'key': 'sunday', 'name': 'Domingo'},
  ];

  // Available languages
  static const List<Map<String, String>> _availableLanguages = [
    {'code': 'pt', 'name': 'Português', 'flag': '🇵🇹'},
    {'code': 'en', 'name': 'Inglês', 'flag': '🇬🇧'},
    {'code': 'fr', 'name': 'Francês', 'flag': '🇫🇷'},
    {'code': 'es', 'name': 'Espanhol', 'flag': '🇪🇸'},
    {'code': 'zh', 'name': 'Chinês', 'flag': '🇨🇳'},
    {'code': 'ar', 'name': 'Árabe', 'flag': '🇸🇦'},
    {'code': 'ru', 'name': 'Russo', 'flag': '🇷🇺'},
    {'code': 'de', 'name': 'Alemão', 'flag': '🇩🇪'},
    {'code': 'it', 'name': 'Italiano', 'flag': '🇮🇹'},
    {'code': 'umbundu', 'name': 'Umbundu', 'flag': '🇦🇴'},
    {'code': 'kimbundu', 'name': 'Kimbundu', 'flag': '🇦🇴'},
    {'code': 'kikongo', 'name': 'Kikongo', 'flag': '🇦🇴'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSupplierData();
  }

  /// Detect current location using GPS with reverse geocoding
  Future<void> _detectCurrentLocation() async {
    setState(() => _isDetectingLocation = true);

    try {
      final hasPermission = await _locationService.checkLocationPermission();

      if (!hasPermission) {
        if (mounted) {
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permissão de Localização'),
              content: const Text(
                'Para detectar sua localização automaticamente, '
                'precisamos de permissão de acesso à localização. '
                'Deseja abrir as configurações?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Abrir Configurações'),
                ),
              ],
            ),
          );

          if (shouldOpenSettings == true) {
            await _locationService.openAppSettings();
          }
        }
        return;
      }

      // Get location with reverse geocoding
      final result = await _locationService.getCurrentLocationWithAddress();

      if (result != null && mounted) {
        final position = result.position;
        final geocodedAddress = result.address;

        setState(() {
          _currentPosition = position;
        });

        // Use reverse geocoded province if available, otherwise fall back to coordinate matching
        String? detectedProvince;
        String? detectedCity;
        String? detectedNeighborhood;

        if (geocodedAddress != null) {
          detectedProvince = geocodedAddress.province;
          detectedCity = geocodedAddress.city;
          detectedNeighborhood = geocodedAddress.neighborhood ?? geocodedAddress.address;
        }

        // Fall back to coordinate-based detection if geocoding didn't return province
        if (detectedProvince == null || !AngolaLocations.provinceNames.contains(detectedProvince)) {
          detectedProvince = _getProvinceFromCoordinates(position.latitude, position.longitude);
        }

        if (detectedProvince != null && AngolaLocations.provinceNames.contains(detectedProvince)) {
          setState(() {
            _selectedProvince = detectedProvince;
            _availableCities = AngolaLocations.getCitiesForProvince(detectedProvince!);

            // Set city if available and valid
            if (detectedCity != null && _availableCities.contains(detectedCity)) {
              _selectedCity = detectedCity;
            } else if (_availableCities.isNotEmpty) {
              // Try to find a matching city or use first available
              _selectedCity = _availableCities.first;
            }

            // Auto-fill address/neighborhood field
            if (detectedNeighborhood != null && detectedNeighborhood.isNotEmpty) {
              _addressController.text = detectedNeighborhood;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Localização detectada: $_selectedProvince${_selectedCity != null ? ', $_selectedCity' : ''}',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          // Check if user is outside Angola
          final isOutsideAngola = geocodedAddress != null && !geocodedAddress.isInAngola;
          final locationInfo = geocodedAddress?.rawProvince ?? geocodedAddress?.city;

          String message;
          if (isOutsideAngola) {
            message = 'Está fora de Angola${locationInfo != null ? ' ($locationInfo)' : ''}. Selecione uma província angolana para o seu negócio.';
          } else {
            message = 'Coordenadas detectadas. Selecione sua província manualmente.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível obter sua localização'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error detecting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao detectar localização: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  String? _getProvinceFromCoordinates(double lat, double lng) {
    final provinceCoordinates = {
      'Luanda': {'lat': -8.839, 'lng': 13.289},
      'Benguela': {'lat': -12.578, 'lng': 13.405},
      'Huambo': {'lat': -12.776, 'lng': 15.739},
      'Cabinda': {'lat': -5.55, 'lng': 12.20},
      'Huíla': {'lat': -14.916, 'lng': 13.536},
      'Cunene': {'lat': -16.533, 'lng': 16.033},
      'Namibe': {'lat': -15.196, 'lng': 12.152},
      'Bié': {'lat': -12.383, 'lng': 17.667},
      'Moxico': {'lat': -11.433, 'lng': 22.333},
      'Cuando Cubango': {'lat': -15.75, 'lng': 18.50},
      'Lunda Norte': {'lat': -8.417, 'lng': 19.917},
      'Lunda Sul': {'lat': -10.717, 'lng': 20.400},
      'Malanje': {'lat': -9.540, 'lng': 16.341},
      'Kwanza Norte': {'lat': -9.133, 'lng': 14.983},
      'Kwanza Sul': {'lat': -11.083, 'lng': 14.917},
      'Uíge': {'lat': -7.609, 'lng': 15.062},
      'Zaire': {'lat': -6.133, 'lng': 14.233},
      'Bengo': {'lat': -8.45, 'lng': 13.55},
    };

    String? closestProvince;
    double minDistance = double.infinity;

    for (final entry in provinceCoordinates.entries) {
      final pLat = entry.value['lat']!;
      final pLng = entry.value['lng']!;
      final distance = ((lat - pLat).abs() + (lng - pLng).abs());

      if (distance < minDistance) {
        minDistance = distance;
        closestProvince = entry.key;
      }
    }

    if (minDistance < 3.0) {
      return closestProvince;
    }

    return null;
  }

  void _loadSupplierData() {
    final supplier = ref.read(supplierProvider).currentSupplier;
    if (supplier != null) {
      // Basic info
      _businessNameController.text = supplier.businessName;
      _descriptionController.text = supplier.description;

      // Contact info
      _phoneController.text = supplier.phone ?? '';
      _whatsappController.text = supplier.whatsapp ?? '';
      _emailController.text = supplier.email ?? '';
      _addressController.text = supplier.location?.address ?? '';

      // Load location - validate values exist in dropdown lists
      final province = supplier.location?.province;
      if (province != null && AngolaLocations.provinceNames.contains(province)) {
        _selectedProvince = province;
        _availableCities = AngolaLocations.getCitiesForProvince(province);
        // Only set city if it exists in available cities
        final city = supplier.location?.city;
        if (city != null && _availableCities.contains(city)) {
          _selectedCity = city;
        }
      }

      // Load category and subcategories
      if (supplier.category.isNotEmpty) {
        final category = _categories.firstWhere(
          (c) => c.name == supplier.category || c.id == supplier.category,
          orElse: () => _categories.first,
        );
        _selectedCategory = category.id;
        _availableSubcategories = category.subcategories;
        _selectedSubcategories = supplier.subcategories
            .where((s) => _availableSubcategories.contains(s))
            .toList();
      }

      // Business info fields
      if (supplier.yearsExperience != null && supplier.yearsExperience! > 0) {
        _yearsExperienceController.text = supplier.yearsExperience.toString();
      }
      if (supplier.teamSize != null && supplier.teamSize! > 0) {
        _teamSizeController.text = supplier.teamSize.toString();
      }
      if (supplier.specialties.isNotEmpty) {
        _specialtiesController.text = supplier.specialties.join(', ');
      }

      // Service settings
      _instantBooking = supplier.instantBooking;
      _customPackages = supplier.customPackages;
      _responseTime = supplier.responseTime ?? 'Rápido';

      // Languages
      if (supplier.languages.isNotEmpty) {
        _selectedLanguages = List<String>.from(supplier.languages);
      }

      // Working hours
      if (supplier.workingHours != null) {
        for (final entry in supplier.workingHours!.schedule.entries) {
          final dayHours = entry.value;
          _workingHours[entry.key] = {
            'isOpen': dayHours.isOpen,
            'openTime': dayHours.openTime ?? '08:00',
            'closeTime': dayHours.closeTime ?? '18:00',
          };
        }
      }
    }
  }

  /// Validate category selection - ensures no category clashing
  bool _validateCategorySelection() {
    if (_selectedCategory == null) {
      _categoryValidationError = 'Selecione uma categoria';
      return false;
    }
    if (_selectedSubcategories.isEmpty) {
      _categoryValidationError = 'Selecione pelo menos uma especialidade';
      return false;
    }

    // Validate using CategoryValidationService
    final validation = CategoryValidationService.validateCategories([_selectedCategory!]);
    if (!validation.isValid) {
      _categoryValidationError = validation.errorMessage;
      return false;
    }

    _categoryValidationError = null;
    return true;
  }

  /// Handle category change - updates available subcategories
  void _onCategoryChanged(String? categoryId) {
    if (categoryId == null) return;

    final category = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => _categories.first,
    );

    setState(() {
      _selectedCategory = categoryId;
      _availableSubcategories = category.subcategories;
      // Clear subcategories when category changes (mutually exclusive)
      _selectedSubcategories = [];
      _categoryValidationError = null;
    });
  }

  /// Toggle subcategory selection
  void _onSubcategoryToggled(String subcategory) {
    setState(() {
      if (_selectedSubcategories.contains(subcategory)) {
        _selectedSubcategories.remove(subcategory);
      } else {
        _selectedSubcategories.add(subcategory);
      }
      _categoryValidationError = null;
    });
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = (file: image, bytes: bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate category selection before saving
    if (!_validateCategorySelection()) {
      setState(() {}); // Trigger rebuild to show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_categoryValidationError ?? 'Erro de validação de categoria'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supplier = ref.read(supplierProvider).currentSupplier;
      if (supplier == null) return;

      // Upload profile image if selected
      String? newPhotoUrl;
      if (_selectedImage != null) {
        newPhotoUrl = await ref.read(supplierProvider.notifier).uploadProfileImage(_selectedImage!.file);
      }

      // Build location data with optional geopoint
      final locationData = <String, dynamic>{
        'city': _selectedCity ?? supplier.location?.city ?? '',
        'province': _selectedProvince ?? supplier.location?.province ?? 'Luanda',
        'address': _addressController.text.trim(),
        'country': 'Angola',
      };

      // Include geopoint if we have GPS coordinates
      if (_currentPosition != null) {
        locationData['geopoint'] = GeoPoint(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        locationData['lastUpdated'] = FieldValue.serverTimestamp();
      }

      // Get category name from ID
      final selectedCategoryModel = _categories.firstWhere(
        (c) => c.id == _selectedCategory,
        orElse: () => _categories.first,
      );

      // Update supplier data
      final updateData = <String, dynamic>{
        'businessName': _businessNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'phone': _phoneController.text.trim(),
        'category': selectedCategoryModel.name,
        'subcategories': _selectedSubcategories,
        'whatsapp': _whatsappController.text.trim().isNotEmpty
            ? _whatsappController.text.trim()
            : _phoneController.text.trim(),
        'email': _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        'location': locationData,
      };

      // Add profile features
      if (_yearsExperienceController.text.trim().isNotEmpty) {
        updateData['yearsExperience'] = int.tryParse(_yearsExperienceController.text.trim()) ?? 0;
      }

      if (_teamSizeController.text.trim().isNotEmpty) {
        updateData['teamSize'] = int.tryParse(_teamSizeController.text.trim()) ?? 1;
      }

      if (_specialtiesController.text.trim().isNotEmpty) {
        updateData['specialties'] = _specialtiesController.text.trim().split(',').map((s) => s.trim()).toList();
      }

      // Service settings
      updateData['instantBooking'] = _instantBooking;
      updateData['customPackages'] = _customPackages;
      updateData['responseTime'] = _responseTime;

      // Languages
      updateData['languages'] = _selectedLanguages;

      // Working hours
      final workingHoursData = <String, dynamic>{};
      _workingHours.forEach((day, hours) {
        workingHoursData[day] = {
          'isOpen': hours['isOpen'],
          'openTime': hours['openTime'],
          'closeTime': hours['closeTime'],
        };
      });
      updateData['workingHours'] = workingHoursData;

      if (newPhotoUrl != null) {
        final currentPhotos = supplier.photos;
        if (currentPhotos.isEmpty) {
          updateData['photos'] = [newPhotoUrl];
        } else {
          // Replace first photo (profile photo)
          updateData['photos'] = [newPhotoUrl, ...currentPhotos.skip(1).toList()];
        }
      }

      await ref.read(supplierProvider.notifier).updateSupplier(updateData);

      // Refresh auth provider to update UI immediately
      await ref.read(authProvider.notifier).refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar perfil: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplier = ref.watch(supplierProvider).currentSupplier;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Guardar', style: TextStyle(color: AppColors.peach, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.md),
          children: [
            // Profile Image
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.peach.withAlpha((0.2 * 255).toInt()),
                    backgroundImage: _selectedImage != null
                        ? MemoryImage(_selectedImage!.bytes) as ImageProvider
                        : (supplier?.photos.isNotEmpty ?? false)
                            ? NetworkImage(supplier!.photos.first) as ImageProvider
                            : null,
                    child: _selectedImage == null && (supplier?.photos.isEmpty ?? true)
                        ? const Icon(Icons.business, size: 48, color: AppColors.peach)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.peach,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Business Name
            Text('Nome do Negócio', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _businessNameController,
              decoration: const InputDecoration(
                hintText: 'Ex: Elegância Eventos',
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 20),

            // Description
            Text('Descrição', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Descreva seu negócio, serviços e diferenciais...',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 24),

            // CATEGORY & SPECIALTY SECTION
            Text(
              'CATEGORIA E ESPECIALIDADES',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A categoria determina como os clientes encontram seu negócio. Só pode selecionar especialidades dentro da mesma categoria.',
              style: AppTextStyles.caption.copyWith(color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            Text('Categoria Principal *', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.category_rounded),
                hintText: 'Selecione a categoria',
                errorText: _categoryValidationError != null && _selectedCategory == null
                    ? _categoryValidationError
                    : null,
              ),
              items: _categories.map((category) => DropdownMenuItem(
                value: category.id,
                child: Row(
                  children: [
                    Text(category.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(category.name),
                  ],
                ),
              )).toList(),
              onChanged: _onCategoryChanged,
            ),
            const SizedBox(height: 20),

            // Subcategories / Specialties (Multi-select chips)
            if (_availableSubcategories.isNotEmpty) ...[
              Text('Especialidades *', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Selecione todos os serviços que oferece dentro desta categoria',
                style: AppTextStyles.caption.copyWith(color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableSubcategories.map((subcategory) {
                  final isSelected = _selectedSubcategories.contains(subcategory);
                  return FilterChip(
                    label: Text(subcategory),
                    selected: isSelected,
                    onSelected: (_) => _onSubcategoryToggled(subcategory),
                    selectedColor: AppColors.peach.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.peach,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.peachDark : AppColors.gray700,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppColors.peach : AppColors.gray300,
                    ),
                  );
                }).toList(),
              ),
              if (_categoryValidationError != null && _selectedSubcategories.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _categoryValidationError!,
                    style: AppTextStyles.caption.copyWith(color: AppColors.error),
                  ),
                ),
              const SizedBox(height: 24),
            ],

            // CONTACT INFO SECTION
            Text(
              'INFORMAÇÕES DE CONTACTO',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),

            // Phone
            Text('Telefone', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+244 923 456 789',
                prefixIcon: Icon(Icons.phone),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 20),

            // WhatsApp
            Text('WhatsApp', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _whatsappController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+244 923 456 789',
                prefixIcon: Icon(Icons.chat),
                helperText: 'Se diferente do telefone principal',
              ),
            ),
            const SizedBox(height: 20),

            // Email
            Text('Email', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'seu@email.com',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 24),

            // LOCATION SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LOCALIZAÇÃO',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    letterSpacing: 1.2,
                  ),
                ),
                // Detect Location Button
                TextButton.icon(
                  onPressed: _isDetectingLocation ? null : _detectCurrentLocation,
                  icon: _isDetectingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.peach,
                          ),
                        )
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(_isDetectingLocation ? 'Detectando...' : 'Usar GPS'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.peach,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Province Dropdown
            Text('Província', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              // Safety check: only use value if it exists in items list
              value: (_selectedProvince != null && AngolaLocations.provinceNames.contains(_selectedProvince))
                  ? _selectedProvince
                  : null,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.map),
                hintText: 'Selecione a província',
              ),
              items: AngolaLocations.provinceNames
                  .map((province) => DropdownMenuItem(
                        value: province,
                        child: Text(province),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProvince = value;
                  _selectedCity = null;
                  _availableCities = value != null
                      ? AngolaLocations.getCitiesForProvince(value)
                      : [];
                });
              },
            ),
            const SizedBox(height: 20),

            // City Dropdown
            Text('Cidade', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              // Safety check: only use value if it exists in items list
              value: (_selectedCity != null && _availableCities.contains(_selectedCity))
                  ? _selectedCity
                  : null,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_city),
                hintText: 'Selecione a cidade',
              ),
              items: _availableCities
                  .map((city) => DropdownMenuItem(
                        value: city,
                        child: Text(city),
                      ))
                  .toList(),
              onChanged: _selectedProvince == null
                  ? null
                  : (value) {
                      setState(() {
                        _selectedCity = value;
                      });
                    },
            ),
            const SizedBox(height: 20),

            // Address
            Text('Endereço', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                hintText: 'Rua, Bairro',
                prefixIcon: Icon(Icons.location_on_rounded),
                helperText: 'Área de atuação principal',
              ),
            ),
            const SizedBox(height: 24),

            // BUSINESS INFO SECTION
            Text(
              'INFORMAÇÕES DO NEGÓCIO',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),

            // Years of Experience
            Text('Anos de Experiência', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _yearsExperienceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Ex: 5',
                prefixIcon: Icon(Icons.work_history_rounded),
                suffixText: 'anos',
                helperText: 'Demonstra sua experiência aos clientes',
              ),
            ),
            const SizedBox(height: 20),

            // Team Size
            Text('Tamanho da Equipe', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _teamSizeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Ex: 10',
                prefixIcon: Icon(Icons.people_rounded),
                suffixText: 'pessoas',
                helperText: 'Quantas pessoas trabalham com você?',
              ),
            ),
            const SizedBox(height: 20),

            // Specialties
            Text('Especialidades', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _specialtiesController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ex: Casamentos, Eventos Corporativos, Festas',
                prefixIcon: Icon(Icons.star_rounded),
                helperText: 'Separe por vírgulas',
              ),
            ),
            const SizedBox(height: 24),

            // Service Settings Section
            Text(
              'CONFIGURAÇÕES DE SERVIÇO',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),

            // Instant Booking
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.peach, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reserva Instantânea',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Clientes podem reservar diretamente',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _instantBooking,
                    onChanged: (value) => setState(() => _instantBooking = value),
                    activeColor: AppColors.peach,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Custom Packages
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, color: AppColors.peach, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pacotes Personalizados',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aceitar pedidos de personalização',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _customPackages,
                    onChanged: (value) => setState(() => _customPackages = value),
                    activeColor: AppColors.peach,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Response Time
            Text('Tempo de Resposta Típico', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _responseTime,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.access_time_rounded),
                helperText: 'Quanto tempo leva para responder mensagens',
              ),
              items: const [
                DropdownMenuItem(value: 'Muito Rápido', child: Text('Muito Rápido (< 1 hora)')),
                DropdownMenuItem(value: 'Rápido', child: Text('Rápido (1-3 horas)')),
                DropdownMenuItem(value: 'Moderado', child: Text('Moderado (3-6 horas)')),
                DropdownMenuItem(value: 'Lento', child: Text('Lento (6-24 horas)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _responseTime = value);
                }
              },
            ),
            const SizedBox(height: 24),

            // Languages Section
            Text(
              'IDIOMAS',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selecione os idiomas em que pode atender clientes',
              style: AppTextStyles.caption.copyWith(color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableLanguages.map((lang) {
                final isSelected = _selectedLanguages.contains(lang['code']);
                return FilterChip(
                  avatar: Text(lang['flag']!, style: const TextStyle(fontSize: 16)),
                  label: Text(lang['name']!),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedLanguages.add(lang['code']!);
                      } else {
                        // Ensure at least one language is selected
                        if (_selectedLanguages.length > 1) {
                          _selectedLanguages.remove(lang['code']);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Deve ter pelo menos um idioma selecionado'),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        }
                      }
                    });
                  },
                  selectedColor: AppColors.peach.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.peach,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.peachDark : AppColors.gray700,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.peach : AppColors.gray300,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // BUSINESS HOURS SECTION
            Text(
              'HORÁRIO DE FUNCIONAMENTO',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Defina os dias e horários em que está disponível para atender clientes',
              style: AppTextStyles.caption.copyWith(color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),

            // Business hours list
            ..._weekDays.map((day) => _buildDayHoursRow(day['key']!, day['name']!)),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDayHoursRow(String dayKey, String dayName) {
    final dayData = _workingHours[dayKey]!;
    final isOpen = dayData['isOpen'] as bool;
    final openTime = dayData['openTime'] as String;
    final closeTime = dayData['closeTime'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOpen ? Colors.white : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOpen ? AppColors.peach.withValues(alpha: 0.3) : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          // Day toggle
          SizedBox(
            width: 130,
            child: Row(
              children: [
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: isOpen,
                    onChanged: (value) {
                      setState(() {
                        _workingHours[dayKey]!['isOpen'] = value;
                      });
                    },
                    activeColor: AppColors.peach,
                  ),
                ),
                Expanded(
                  child: Text(
                    dayName,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isOpen ? AppColors.textPrimary : Colors.grey[400],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Time selectors (only show when open)
          if (isOpen) ...[
            const SizedBox(width: 8),
            // Open time
            _buildTimeSelector(
              value: openTime,
              onChanged: (time) {
                setState(() {
                  _workingHours[dayKey]!['openTime'] = time;
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('às', style: AppTextStyles.caption.copyWith(color: Colors.grey[500])),
            ),
            // Close time
            _buildTimeSelector(
              value: closeTime,
              onChanged: (time) {
                setState(() {
                  _workingHours[dayKey]!['closeTime'] = time;
                });
              },
            ),
          ] else ...[
            const Spacer(),
            Text(
              'Fechado',
              style: AppTextStyles.caption.copyWith(
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeSelector({
    required String value,
    required Function(String) onChanged,
  }) {
    // Generate time options from 06:00 to 23:00
    final timeOptions = <String>[];
    for (int hour = 6; hour <= 23; hour++) {
      timeOptions.add('${hour.toString().padLeft(2, '0')}:00');
      if (hour < 23) {
        timeOptions.add('${hour.toString().padLeft(2, '0')}:30');
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.peach.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.peach.withValues(alpha: 0.3)),
      ),
      child: DropdownButton<String>(
        value: timeOptions.contains(value) ? value : timeOptions.first,
        underline: const SizedBox(),
        isDense: true,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.peachDark,
          fontWeight: FontWeight.w600,
        ),
        icon: const Icon(Icons.arrow_drop_down, color: AppColors.peach, size: 20),
        items: timeOptions.map((time) => DropdownMenuItem(
          value: time,
          child: Text(time),
        )).toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _yearsExperienceController.dispose();
    _teamSizeController.dispose();
    _specialtiesController.dispose();
    super.dispose();
  }
}
