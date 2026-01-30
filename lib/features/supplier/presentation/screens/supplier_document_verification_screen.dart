import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/models/supplier_model.dart';
import '../../../../core/providers/supplier_registration_provider.dart';
import '../../../../core/routing/route_names.dart';

class SupplierDocumentVerificationScreen extends ConsumerStatefulWidget {
  const SupplierDocumentVerificationScreen({super.key});

  @override
  ConsumerState<SupplierDocumentVerificationScreen> createState() =>
      _SupplierDocumentVerificationScreenState();
}

class _SupplierDocumentVerificationScreenState
    extends ConsumerState<SupplierDocumentVerificationScreen> {
  // Entity Type
  SupplierEntityType _entityType = SupplierEntityType.individual;

  // NIF
  final _nifController = TextEditingController();

  // Identity Document
  IdentityDocumentType _idDocumentType = IdentityDocumentType.bilheteIdentidade;
  final _idDocumentNumberController = TextEditingController();
  ({XFile file, Uint8List bytes})? _idDocumentFile;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    final registrationData = ref.read(supplierRegistrationProvider);
    setState(() {
      _entityType = registrationData.entityType;
      if (registrationData.nif != null) {
        _nifController.text = registrationData.nif!;
      }
      if (registrationData.idDocumentType != null) {
        _idDocumentType = registrationData.idDocumentType!;
      }
      if (registrationData.idDocumentNumber != null) {
        _idDocumentNumberController.text = registrationData.idDocumentNumber!;
      }
      if (registrationData.idDocumentFile != null) {
        // Read bytes for display (async)
        registrationData.idDocumentFile!.readAsBytes().then((bytes) {
          if (mounted) {
            setState(() {
              _idDocumentFile = (file: registrationData.idDocumentFile!, bytes: bytes);
            });
          }
        });
      }
    });
  }

  bool get _isFormValid {
    // NIF is required for both individual and empresa
    if (_nifController.text.trim().isEmpty) return false;

    // Document number is required
    if (_idDocumentNumberController.text.trim().isEmpty) return false;

    // Document file is required
    if (_idDocumentFile == null) return false;

    return true;
  }

  Future<void> _pickDocument() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _idDocumentFile = (file: image, bytes: bytes);
      });
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _idDocumentFile = (file: image, bytes: bytes);
      });
    }
  }

  void _showDocumentPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Carregar Documento',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPickerOption(
                    icon: Icons.camera_alt,
                    label: 'Tirar Foto',
                    onTap: () {
                      Navigator.pop(context);
                      _takePhoto();
                    },
                  ),
                  _buildPickerOption(
                    icon: Icons.photo_library,
                    label: 'Galeria',
                    onTap: () {
                      Navigator.pop(context);
                      _pickDocument();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.peachLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.peach, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndContinue() async {
    if (!_isFormValid) return;

    setState(() => _isSaving = true);

    try {
      // Update registration data
      ref.read(supplierRegistrationProvider.notifier).updateEntityInfo(
            entityType: _entityType,
            nif: _nifController.text.trim(),
          );

      ref.read(supplierRegistrationProvider.notifier).updateIdentityDocument(
            idDocumentType: _idDocumentType,
            idDocumentNumber: _idDocumentNumberController.text.trim(),
            idDocumentFile: _idDocumentFile?.file,
          );

      if (mounted) {
        // Navigate to next step (service type selection)
        context.go(Routes.supplierServiceType);
      }
    } catch (e) {
      debugPrint('Error saving document data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar dados: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nifController.dispose();
    _idDocumentNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = AppDimensions.getHorizontalPadding(context);
    final maxWidth = AppDimensions.getMaxContentWidth(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth > 500 ? 500 : maxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: 0.3,
                            backgroundColor: AppColors.gray200,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.peach),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '30%',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Entity Type Section
                  const Text(
                    'Tipo de Entidade',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Selecione se você é um fornecedor individual ou uma empresa',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Entity Type Selection
                  const Text(
                    'Você é *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildEntityTypeCard(
                          type: SupplierEntityType.individual,
                          icon: Icons.person,
                          label: 'Individual',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildEntityTypeCard(
                          type: SupplierEntityType.empresa,
                          icon: Icons.business,
                          label: 'Empresa',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // NIF Field
                  _buildInputField(
                    label: 'NIF (Número de Identificação Fiscal) *',
                    hint: _entityType == SupplierEntityType.empresa
                        ? 'NIF da sua empresa registada'
                        : 'Seu NIF individual',
                    controller: _nifController,
                    keyboardType: TextInputType.number,
                    helper: _entityType == SupplierEntityType.empresa
                        ? 'NIF da sua empresa registada'
                        : 'Seu NIF individual',
                  ),

                  const SizedBox(height: 24),

                  // Identity Document Section
                  const Text(
                    'Documento de Identificação',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Para sua segurança e dos clientes, precisamos validar sua identidade',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Document Type Selection
                  const Text(
                    'Tipo de documento *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDocumentTypeCard(
                          type: IdentityDocumentType.bilheteIdentidade,
                          label: 'Bilhete de Identidade',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDocumentTypeCard(
                          type: IdentityDocumentType.passaporte,
                          label: 'Passaporte',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Document Number Field
                  _buildInputField(
                    label: _idDocumentType == IdentityDocumentType.bilheteIdentidade
                        ? 'Número do Bilhete de Identidade *'
                        : 'Número do Passaporte *',
                    hint: _idDocumentType == IdentityDocumentType.bilheteIdentidade
                        ? 'Ex: 000123456LA789'
                        : 'Ex: N12345678',
                    controller: _idDocumentNumberController,
                    keyboardType: TextInputType.text,
                  ),

                  const SizedBox(height: 16),

                  // Document Upload
                  Text(
                    _idDocumentType == IdentityDocumentType.bilheteIdentidade
                        ? 'Upload do Bilhete de Identidade *'
                        : 'Upload do Passaporte *',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showDocumentPickerOptions,
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppColors.peach.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                        border: Border.all(
                          color: AppColors.peach.withValues(alpha: 0.5),
                          style: BorderStyle.solid,
                          width: 2,
                        ),
                      ),
                      child: _idDocumentFile != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppDimensions.cardRadius - 2),
                                  child: Image.memory(
                                    _idDocumentFile!.bytes,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _idDocumentFile = null;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
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
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check, color: Colors.white, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          'Documento carregado',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.upload_file,
                                  size: 40,
                                  color: AppColors.peach.withValues(alpha: 0.7),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _idDocumentType == IdentityDocumentType.bilheteIdentidade
                                      ? 'Upload do Bilhete de Identidade *'
                                      : 'Upload do Passaporte *',
                                  style: TextStyle(
                                    color: AppColors.peach.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Toque para selecionar ou tirar foto',
                                  style: TextStyle(
                                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.info,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Certifique-se de que o documento está legível e todas as informações estão visíveis.',
                            style: TextStyle(
                              color: AppColors.info,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _isFormValid && !_isSaving ? _saveAndContinue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.peach,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: AppColors.gray200,
                        disabledForegroundColor: AppColors.textTertiary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Continuar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntityTypeCard({
    required SupplierEntityType type,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _entityType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _entityType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.peach : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(
            color: isSelected ? AppColors.peach : AppColors.gray200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? Colors.white : AppColors.gray700,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTypeCard({
    required IdentityDocumentType type,
    required String label,
  }) {
    final isSelected = _idDocumentType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _idDocumentType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.peach : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(
            color: isSelected ? AppColors.peach : AppColors.gray200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: AppColors.gray50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
                borderSide: const BorderSide(
                  color: AppColors.peach,
                  width: 2,
                ),
              ),
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(
              helper,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
