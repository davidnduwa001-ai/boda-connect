import 'dart:typed_data';
import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/models/package_model.dart';
import 'package:boda_connect/core/providers/supplier_provider.dart';
import 'package:boda_connect/core/services/category_config_service.dart';
import 'package:boda_connect/core/models/supplier_model.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class SupplierCreateServiceScreen extends ConsumerStatefulWidget {
  final PackageModel? packageToEdit;

  const SupplierCreateServiceScreen({super.key, this.packageToEdit});

  @override
  ConsumerState<SupplierCreateServiceScreen> createState() =>
      _SupplierCreateServiceScreenState();
}

class _SupplierCreateServiceScreenState
    extends ConsumerState<SupplierCreateServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _guestsController = TextEditingController();
  final _durationController = TextEditingController();

  String? _selectedCategory;
  CategoryConfig? _categoryConfig;
  final List<String> _includedItems = [];
  final List<Map<String, dynamic>> _customizations = [];
  final _includedItemController = TextEditingController();

  // Category-specific field values
  final Map<String, dynamic> _categoryFieldValues = {};
  final Map<String, TextEditingController> _categoryFieldControllers = {};

  // Image picker
  final ImagePicker _picker = ImagePicker();
  final List<({XFile file, Uint8List bytes})> _selectedImages = [];
  bool _isUploading = false;

  // Editing mode
  PackageModel? _editingPackage;
  bool get _isEditing => _editingPackage != null;
  List<String> _existingPhotoUrls = [];

  @override
  void initState() {
    super.initState();
    // Load supplier profile and auto-select their category
    Future.microtask(() async {
      await ref.read(supplierProvider.notifier).loadCurrentSupplier();

      // Check if supplier is validated before allowing service creation
      final supplier = ref.read(supplierProvider).currentSupplier;
      if (supplier != null &&
          supplier.accountStatus != SupplierAccountStatus.active) {
        // Redirect to verification pending screen - can't create services until validated
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Você precisa ter sua conta validada para criar pacotes.'),
              backgroundColor: Colors.orange,
            ),
          );
          context.go(Routes.supplierVerificationPending);
        }
        return;
      }

      _autoSelectSupplierCategory();

      // Check if editing an existing package (from widget parameter or router extra)
      final packageFromWidget = widget.packageToEdit;
      final routerExtra = GoRouterState.of(context).extra;
      final packageToEdit = packageFromWidget ?? (routerExtra is PackageModel ? routerExtra : null);

      if (packageToEdit != null && mounted) {
        _populateFormForEditing(packageToEdit);
      }
    });
  }

  /// Populate form fields with existing package data for editing
  void _populateFormForEditing(PackageModel package) {
    setState(() {
      _editingPackage = package;
      _nameController.text = package.name;
      _descriptionController.text = package.description;
      _priceController.text = package.price.toString();
      _durationController.text = package.duration;

      // Populate included items
      _includedItems.clear();
      _includedItems.addAll(package.includes);

      // Populate customizations
      _customizations.clear();
      for (final customization in package.customizations) {
        _customizations.add({
          'name': customization.name,
          'price': customization.price,
          'description': customization.description,
        });
      }

      // Store existing photo URLs
      _existingPhotoUrls = List.from(package.photos);
    });
  }

  /// Auto-select the supplier's category from their profile
  /// This enforces the business rule that packages must match supplier category
  void _autoSelectSupplierCategory() {
    final supplier = ref.read(supplierProvider).currentSupplier;
    if (supplier != null && supplier.category.isNotEmpty) {
      // Auto-select and lock to supplier's category
      _onCategorySelected(supplier.category);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _guestsController.dispose();
    _durationController.dispose();
    _includedItemController.dispose();
    // Dispose category-specific field controllers
    for (final controller in _categoryFieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Pick images from gallery
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty && mounted) {
        // Read bytes for each image (cross-platform compatible)
        final imagesToAdd = <({XFile file, Uint8List bytes})>[];
        for (final xFile in images) {
          final bytes = await xFile.readAsBytes();
          imagesToAdd.add((file: xFile, bytes: bytes));
        }
        setState(() {
          _selectedImages.addAll(imagesToAdd);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar imagens: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Remove image
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.peachLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.add_box_outlined,
                  color: AppColors.peach, size: 16),
            ),
            const SizedBox(width: 8),
          ],
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildBasicInfoSection(),
              _buildPricingSection(),
              if (_categoryConfig != null && _categoryConfig!.specificFields.isNotEmpty)
                _buildCategorySpecificFieldsSection(),
              _buildPhotosSection(),
              _buildIncludedSection(),
              _buildCustomizationsSection(),
              SizedBox(height: MediaQuery.of(context).size.height * 0.12),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildSubmitButton(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      color: AppColors.white,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.peachLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: const Icon(Icons.add_business, color: AppColors.peach),
          ),
          const SizedBox(width: AppDimensions.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEditing ? 'Editar Serviço' : 'Criar Serviço', style: AppTextStyles.h3),
              Text(_isEditing ? 'Atualize os detalhes do serviço' : 'Configure seu novo serviço',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informações Básicas',
              style: AppTextStyles.bodyLarge
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDimensions.md),
          Text('Nome do serviço *',
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Ex: Pacote Casamento Premium',
              hintStyle: AppTextStyles.body.copyWith(color: AppColors.gray400),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.peach)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              Text('Categoria',
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 12, color: AppColors.gray700),
                    const SizedBox(width: 4),
                    Text(
                      'Bloqueada',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.gray700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildLockedCategoryDisplay(),
          const SizedBox(height: AppDimensions.md),
          Text('Descrição do serviço *',
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Descreva os detalhes do seu serviço...',
              hintStyle: AppTextStyles.body.copyWith(color: AppColors.gray400),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.peach)),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  /// Displays the supplier's locked category (cannot be changed)
  /// This enforces the business rule: packages must match supplier category
  Widget _buildLockedCategoryDisplay() {
    final supplierState = ref.watch(supplierProvider);
    final supplier = supplierState.currentSupplier;

    // Find the category info for the icon and color
    final categories = CategoryConfigService.categories;
    final categoryInfo = _selectedCategory != null
        ? categories.where((c) => c.name == _selectedCategory).firstOrNull
        : null;

    if (supplier == null || _selectedCategory == null) {
      // Loading state
      return Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.peach,
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Text(
              'A carregar categoria do perfil...',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.peach.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.peach, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected category display
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: categoryInfo != null
                      ? Color(categoryInfo.color)
                      : AppColors.peachLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  categoryInfo?.icon ?? '📦',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedCategory!,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.peachDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Categoria do seu perfil de fornecedor',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.peach,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.check, size: 20, color: AppColors.white),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          // Info message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.sm,
              horizontal: AppDimensions.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Os pacotes são automaticamente associados à categoria do seu perfil. Para alterar, edite seu perfil de fornecedor.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onCategorySelected(String categoryName) {
    setState(() {
      _selectedCategory = categoryName;
      _categoryConfig = CategoryConfigService.getConfig(categoryName);
      // Clear previous category-specific data
      _includedItems.clear();
      _customizations.clear();
      _categoryFieldValues.clear();
      // Dispose old controllers
      for (final controller in _categoryFieldControllers.values) {
        controller.dispose();
      }
      _categoryFieldControllers.clear();
      // Create new controllers for category-specific fields
      if (_categoryConfig != null) {
        for (final field in _categoryConfig!.specificFields) {
          if (field.type == FieldType.text || field.type == FieldType.number) {
            _categoryFieldControllers[field.id] = TextEditingController();
          }
        }
      }
    });
  }

  Widget _buildPricingSection() {
    final config = _categoryConfig;
    final pricingLabel = config?.pricingLabel ?? 'Preço base (AOA)';
    final durationLabel = config?.durationLabel ?? 'Duração (horas)';
    final guestsLabel = config?.guestsLabel ?? 'Número máximo de convidados';
    final showGuests = config?.showGuestsField ?? true;
    final showDuration = config?.showDurationField ?? true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money, color: AppColors.peach),
              const SizedBox(width: 8),
              Text('Preços & Detalhes',
                  style: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Text('$pricingLabel *',
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Ex: 150000',
              hintStyle: AppTextStyles.body.copyWith(color: AppColors.gray400),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.peach)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          if (showGuests && guestsLabel.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.md),
            Text(guestsLabel,
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _guestsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Ex: 100',
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.gray400),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.peach)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ],
          if (showDuration) ...[
            const SizedBox(height: AppDimensions.md),
            Text(durationLabel,
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _durationController,
              decoration: InputDecoration(
                hintText: 'Ex: 4 horas',
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.gray400),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.peach),),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategorySpecificFieldsSection() {
    if (_categoryConfig == null || _categoryConfig!.specificFields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: AppColors.peach),
              const SizedBox(width: 8),
              Text('Detalhes de $_selectedCategory',
                  style: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          ..._categoryConfig!.specificFields.map((field) => _buildCategoryField(field)),
        ],
      ),
    );
  }

  Widget _buildCategoryField(CategoryField field) {
    final isRequired = field.required;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${field.label}${isRequired ? ' *' : ''}',
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          _buildFieldInput(field),
        ],
      ),
    );
  }

  Widget _buildFieldInput(CategoryField field) {
    switch (field.type) {
      case FieldType.text:
      case FieldType.number:
        return TextFormField(
          controller: _categoryFieldControllers[field.id],
          keyboardType: field.type == FieldType.number
              ? TextInputType.number
              : TextInputType.text,
          decoration: InputDecoration(
            hintText: field.hint,
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.gray400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.peach),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );

      case FieldType.dropdown:
        return DropdownButtonFormField<String>(
          value: _categoryFieldValues[field.id] as String?,
          decoration: InputDecoration(
            hintText: field.hint,
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.gray400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.peach),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: field.options?.map((option) => DropdownMenuItem(
            value: option,
            child: Text(option),
          )).toList() ?? [],
          onChanged: (value) {
            setState(() {
              _categoryFieldValues[field.id] = value;
            });
          },
        );

      case FieldType.checkbox:
        return Row(
          children: [
            Checkbox(
              value: _categoryFieldValues[field.id] as bool? ?? false,
              activeColor: AppColors.peach,
              onChanged: (value) {
                setState(() {
                  _categoryFieldValues[field.id] = value ?? false;
                });
              },
            ),
            Expanded(
              child: Text(
                field.label,
                style: AppTextStyles.body,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildPhotosSection() {
    final totalPhotos = _existingPhotoUrls.length + _selectedImages.length;

    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined, color: AppColors.peach),
              const SizedBox(width: 8),
              Text('Fotos do Serviço ${_isEditing ? '' : '*'}',
                  style: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // Existing photos grid (when editing)
          if (_existingPhotoUrls.isNotEmpty) ...[
            Text('Fotos existentes',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _existingPhotoUrls.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _existingPhotoUrls[index],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.gray200,
                          child: const Icon(Icons.broken_image, color: AppColors.gray400),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _existingPhotoUrls.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
          ],

          // Selected new images grid
          if (_selectedImages.isNotEmpty) ...[
            if (_existingPhotoUrls.isNotEmpty)
              Text('Novas fotos',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            if (_existingPhotoUrls.isNotEmpty) const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _selectedImages[index].bytes,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
          ],

          // Upload button
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.peachLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                    color: AppColors.peach,
                    style: BorderStyle.solid,
                    width: 1.5),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_upload_outlined,
                        color: AppColors.peach, size: 36),
                    const SizedBox(height: 8),
                    Text('Adicionar fotos',
                        style: AppTextStyles.body.copyWith(
                            color: AppColors.peachDark,
                            fontWeight: FontWeight.w500)),
                    Text('Até 5MB cada',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncludedSection() {
    final suggestedIncludes = _categoryConfig?.suggestedIncludes ?? [];
    // Filter out already added items
    final availableSuggestions = suggestedIncludes
        .where((item) => !_includedItems.contains(item))
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('O que está incluído? *',
              style: AppTextStyles.bodyLarge
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDimensions.md),

          // Selected included items
          if (_includedItems.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _includedItems
                  .map((item) => Chip(
                        label: Text(item),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () =>
                            setState(() => _includedItems.remove(item)),
                        backgroundColor: AppColors.peachLight,
                        labelStyle: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.peachDark,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppDimensions.md),
          ],

          // Category-specific suggestions
          if (availableSuggestions.isNotEmpty) ...[
            Text('Sugestões para $_selectedCategory:',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableSuggestions.take(6).map((suggestion) =>
                GestureDetector(
                  onTap: () => setState(() => _includedItems.add(suggestion)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: AppColors.gray700),
                        const SizedBox(width: 4),
                        Text(
                          suggestion,
                          style: AppTextStyles.caption.copyWith(color: AppColors.gray700),
                        ),
                      ],
                    ),
                  ),
                ),
              ).toList(),
            ),
            const SizedBox(height: AppDimensions.md),
          ],

          // Manual entry field
          TextFormField(
            controller: _includedItemController,
            decoration: InputDecoration(
              hintText: _categoryConfig != null
                  ? 'Ou adicione um item personalizado...'
                  : 'Ex: Decoração completa',
              hintStyle: AppTextStyles.body.copyWith(color: AppColors.gray400),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.peach)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onFieldSubmitted: (_) => _addIncludedItem(),
          ),
          const SizedBox(height: AppDimensions.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addIncludedItem,
              icon: const Icon(Icons.add, color: AppColors.peach),
              label: Text('Adicionar item personalizado',
                  style: TextStyle(color: AppColors.peach)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AppColors.peach, style: BorderStyle.solid),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationsSection() {
    final suggestedCustomizations = _categoryConfig?.suggestedCustomizations ?? [];
    // Filter out already added customizations
    final addedNames = _customizations.map((c) => c['name'] as String).toSet();
    final availableSuggestions = suggestedCustomizations
        .where((c) => !addedNames.contains(c.name))
        .toList();

    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personalizações disponíveis',
              style: AppTextStyles.bodyLarge
                  .copyWith(fontWeight: FontWeight.w600)),
          Text('Opções extras que podem ser adicionadas (opcional)',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppDimensions.md),

          // Added customizations
          if (_customizations.isNotEmpty) ...[
            ..._customizations.map((c) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.peachLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.peach.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(c['name'], style: AppTextStyles.body)),
                      Text('+${_formatPrice(c['price'] as int)} AOA',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.peachDark,
                              fontWeight: FontWeight.w600)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: AppColors.peachDark),
                        onPressed: () =>
                            setState(() => _customizations.remove(c)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: AppDimensions.sm),
          ],

          // Category-specific customization suggestions
          if (availableSuggestions.isNotEmpty) ...[
            Text('Sugestões para $_selectedCategory:',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ...availableSuggestions.take(4).map((suggestion) =>
              GestureDetector(
                onTap: () => _addSuggestedCustomization(suggestion),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 20, color: AppColors.peach),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(suggestion.name, style: AppTextStyles.body)),
                      Text('+${_formatPrice(suggestion.suggestedPrice)} AOA',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.gray700,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
          ],

          const SizedBox(height: AppDimensions.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAddCustomizationDialog(),
              icon: const Icon(Icons.add, color: AppColors.peach),
              label: Text('Adicionar personalização',
                  style: TextStyle(color: AppColors.peach)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AppColors.peach, style: BorderStyle.solid),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppDimensions.md,
          AppDimensions.md,
          AppDimensions.md,
          AppDimensions.md + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isUploading ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.peach,
            disabledBackgroundColor: AppColors.peach.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
          ),
          child: _isUploading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(_isEditing ? 'A atualizar serviço...' : 'A criar serviço...',
                        style: AppTextStyles.button.copyWith(color: AppColors.white)),
                  ],
                )
              : Text(_isEditing ? 'Atualizar Serviço' : 'Criar Serviço',
                  style: AppTextStyles.button.copyWith(color: AppColors.white)),
        ),
      ),
    );
  }

  void _addIncludedItem() {
    if (_includedItemController.text.trim().isNotEmpty) {
      setState(() {
        _includedItems.add(_includedItemController.text.trim());
        _includedItemController.clear();
      });
    }
  }

  void _addSuggestedCustomization(CustomizationSuggestion suggestion) {
    setState(() {
      _customizations.add({
        'name': suggestion.name,
        'price': suggestion.suggestedPrice,
      });
    });
  }

  String _formatPrice(int price) {
    // Format price with thousands separator
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  void _showAddCustomizationDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adicionar Personalização', style: AppTextStyles.h3),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Nome',
                hintText: 'Ex: Flores premium',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Preço adicional (AOA)',
                hintText: 'Ex: 50000',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      priceController.text.isNotEmpty) {
                    setState(() {
                      _customizations.add({
                        'name': nameController.text,
                        'price': int.tryParse(priceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
                      });
                    });
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.peach,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Adicionar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    // Basic field validation
    if (_nameController.text.isEmpty ||
        _selectedCategory == null ||
        _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, preencha todos os campos obrigatórios')),
      );
      return;
    }

    // CRITICAL: Validate that package category matches supplier's profile category
    // This enforces the business rule preventing category mismatch
    final supplier = ref.read(supplierProvider).currentSupplier;
    if (supplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro: Perfil de fornecedor não encontrado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (supplier.category != _selectedCategory) {
      // Security check: category was somehow changed (shouldn't happen with locked UI)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro: A categoria do pacote deve corresponder à sua categoria de fornecedor (${supplier.category})',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      // Reset to correct category
      _onCategorySelected(supplier.category);
      return;
    }

    // Show loading
    setState(() {
      _isUploading = true;
    });

    try {
      // Parse price
      final price = int.tryParse(_priceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      String packageId;

      if (_isEditing) {
        // Update existing package
        packageId = _editingPackage!.id;
        final success = await ref.read(supplierProvider.notifier).updatePackage(packageId, {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': price,
          'duration': _durationController.text.trim(),
          'includes': _includedItems,
          'customizations': _customizations.map((c) => {
            'name': c['name'] ?? '',
            'price': (c['price'] as num?)?.toInt() ?? 0,
            'description': c['description'] as String?,
          }).toList(),
        });

        if (!success) {
          throw Exception('Falha ao atualizar pacote');
        }
      } else {
        // Create new package in Firestore first
        final newPackageId = await ref.read(supplierProvider.notifier).createPackage(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          price: price,
          duration: _durationController.text.trim(),
          includes: _includedItems,
          customizations: _customizations.map((c) => PackageCustomization(
            name: c['name'] ?? '',
            price: (c['price'] as num?)?.toInt() ?? 0,
            description: c['description'] as String?,
          )).toList(),
        );

        if (newPackageId == null) {
          throw Exception('Falha ao criar pacote');
        }
        packageId = newPackageId;
      }

      // Upload new images to Firebase Storage using package ID
      List<String> newPhotoUrls = [];
      if (_selectedImages.isNotEmpty) {
        final repository = ref.read(supplierRepositoryProvider);
        for (final imageData in _selectedImages) {
          try {
            final url = await repository.uploadPackagePhoto(packageId, imageData.file);
            newPhotoUrls.add(url);
          } catch (e) {
            debugPrint('Error uploading photo: $e');
          }
        }
      }

      // Combine existing and new photo URLs
      final allPhotoUrls = [..._existingPhotoUrls, ...newPhotoUrls];

      // Update package with all photo URLs if there are any changes
      if (newPhotoUrls.isNotEmpty || (_isEditing && allPhotoUrls.length != _editingPackage!.photos.length)) {
        await ref.read(supplierProvider.notifier).updatePackage(packageId, {
          'photos': allPhotoUrls,
        });
      }

      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: AppColors.success, size: 48),
                ),
                const SizedBox(height: 24),
                Text(_isEditing ? 'Serviço Atualizado!' : 'Serviço Criado!', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                Text(
                  _isEditing
                      ? 'Seu serviço foi atualizado com sucesso.'
                      : 'Seu novo serviço foi adicionado com sucesso.',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.pop();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach),
                  child: const Text('Continuar'),
                ),
              ),
            ],
          ),
        );
      } else {
        throw Exception(_isEditing ? 'Falha ao atualizar serviço' : 'Falha ao criar serviço');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Erro ao atualizar serviço: $e' : 'Erro ao criar serviço: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
