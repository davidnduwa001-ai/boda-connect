import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/angola_locations.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/services/logger_service.dart';

class SupplierBasicDataScreen extends ConsumerStatefulWidget {
  const SupplierBasicDataScreen({super.key});

  @override
  ConsumerState<SupplierBasicDataScreen> createState() => _SupplierBasicDataScreenState();
}

class _SupplierBasicDataScreenState extends ConsumerState<SupplierBasicDataScreen> {
  ({XFile file, Uint8List bytes})? _profileImage;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();

  // Location dropdowns
  String? _selectedProvince;
  String? _selectedCity;
  List<String> _availableCities = [];

  // Form validity notifier - avoids rebuilding entire widget on every keystroke
  final _formValidNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    // Add listeners to update form validity without rebuilding entire widget
    _nameController.addListener(_updateFormValidity);
    _businessNameController.addListener(_updateFormValidity);
    _phoneController.addListener(_updateFormValidity);
    _loadExistingData();
  }

  void _updateFormValidity() {
    _formValidNotifier.value = _nameController.text.isNotEmpty &&
        _businessNameController.text.isNotEmpty &&
        _phoneController.text.isNotEmpty &&
        _selectedProvince != null &&
        _selectedCity != null;
  }

  /// Load existing data from Firebase Auth and Firestore
  Future<void> _loadExistingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Pre-fill from Firebase Auth
    if (user.email != null) {
      _emailController.text = user.email!;
    }
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      _nameController.text = user.displayName!;
    }
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      _phoneController.text = user.phoneNumber!;
    }

    // Load existing data from Firestore user document
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        if (data != null) {
          setState(() {
            if (_nameController.text.isEmpty && data['name'] != null) {
              _nameController.text = data['name'];
            }
            if (_phoneController.text.isEmpty && data['phone'] != null) {
              _phoneController.text = data['phone'];
            }
            if (_emailController.text.isEmpty && data['email'] != null) {
              _emailController.text = data['email'];
            }
          });
        }
      }

      // Also check if supplier profile already exists
      final supplierQuery = await FirebaseFirestore.instance
          .collection('suppliers')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (supplierQuery.docs.isNotEmpty && mounted) {
        final supplierData = supplierQuery.docs.first.data();
        setState(() {
          if (supplierData['businessName'] != null) {
            _businessNameController.text = supplierData['businessName'];
          }
          if (supplierData['phone'] != null && _phoneController.text.isEmpty) {
            _phoneController.text = supplierData['phone'];
          }
          if (supplierData['whatsapp'] != null) {
            _whatsappController.text = supplierData['whatsapp'];
          }
          if (supplierData['email'] != null && _emailController.text.isEmpty) {
            _emailController.text = supplierData['email'];
          }
          if (supplierData['location'] != null) {
            final location = supplierData['location'] as Map<String, dynamic>;
            if (location['province'] != null) {
              final province = location['province'] as String;
              // Verify province exists in our list before setting
              if (AngolaLocations.provinceNames.contains(province)) {
                _selectedProvince = province;
                _availableCities = AngolaLocations.getCitiesForProvince(province);
                if (location['city'] != null) {
                  final city = location['city'] as String;
                  // Only set city if it exists in available cities list
                  if (_availableCities.contains(city)) {
                    _selectedCity = city;
                  }
                }
              }
            }
          }
        });
        // Update form validity after loading data
        _updateFormValidity();
      }
    } catch (e) {
      Log.fail('Error loading existing data: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _profileImage = (file: image, bytes: bytes);
      });
    }
  }

  Future<void> _saveAndContinue() async {
    if (!_formValidNotifier.value) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // 1. Update user document in Firestore
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userDocRef.set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        'phone': _phoneController.text.trim(),
        'userType': 'supplier',
        'location': {
          'province': _selectedProvince,
          'city': _selectedCity,
          'country': 'Angola',
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Create or update supplier document
      final supplierQuery = await FirebaseFirestore.instance
          .collection('suppliers')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      final supplierData = {
        'userId': user.uid,
        'businessName': _businessNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'whatsapp': _whatsappController.text.trim().isNotEmpty ? _whatsappController.text.trim() : _phoneController.text.trim(),
        'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        'location': {
          'province': _selectedProvince,
          'city': _selectedCity,
          'country': 'Angola',
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (supplierQuery.docs.isEmpty) {
        // Create new supplier with PENDING_REVIEW status for admin approval
        supplierData['category'] = '';
        supplierData['subcategories'] = [];
        supplierData['description'] = '';
        supplierData['photos'] = [];
        supplierData['videos'] = [];
        supplierData['rating'] = 0.0;
        supplierData['reviewCount'] = 0;
        supplierData['isVerified'] = false;
        supplierData['isActive'] = false; // Not active until approved
        supplierData['isFeatured'] = false;
        supplierData['responseRate'] = 0.0;
        supplierData['languages'] = ['pt'];
        supplierData['createdAt'] = FieldValue.serverTimestamp();
        supplierData['accountStatus'] = 'pendingReview'; // Requires admin approval

        await FirebaseFirestore.instance.collection('suppliers').add(supplierData);
        Log.success('Created new supplier profile with PENDING_REVIEW status');
      } else {
        // Update existing supplier
        await supplierQuery.docs.first.reference.update(supplierData);
        Log.success('Updated existing supplier profile');
      }

      // Update Firebase Auth display name
      await user.updateDisplayName(_nameController.text.trim());

      // Refresh auth provider state with updated user data
      await ref.read(authProvider.notifier).refreshUser();

      if (mounted) {
        // Navigate to document verification step
        context.go(Routes.supplierDocumentVerification);
      }
    } catch (e) {
      Log.fail('Error saving supplier data: $e');
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
    _nameController.removeListener(_updateFormValidity);
    _businessNameController.removeListener(_updateFormValidity);
    _phoneController.removeListener(_updateFormValidity);
    _nameController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _formValidNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.screenPaddingHorizontal,
        ),
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
                      value: 0.2,
                      backgroundColor: AppColors.gray200,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.peach),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '20%',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Title
            const Text(
              'Dados Básicos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'Preencha suas informações principais',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 24),

            // Photo picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.peach.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                  border: Border.all(
                    color: AppColors.peach.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.peach.withValues(alpha: 0.15),
                      backgroundImage:
                          _profileImage != null ? MemoryImage(_profileImage!.bytes) : null,
                      child: _profileImage == null
                          ? const Icon(
                              Icons.camera_alt,
                              size: 28,
                              color: AppColors.peach,
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _profileImage == null ? 'Adicionar foto' : 'Alterar foto',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.peach,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Escolha uma foto profissional. Máximo 5MB',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Form fields
            _buildInputField(
              label: 'Nome completo *',
              hint: 'Ex: João Manuel Silva',
              controller: _nameController,
            ),

            _buildInputField(
              label: 'Nome do negócio / marca *',
              hint: 'Ex: Silva Events',
              controller: _businessNameController,
            ),

            _buildInputField(
              label: 'Número de telefone *',
              hint: '+244 923 456 789',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
            ),

            _buildInputField(
              label: 'WhatsApp',
              hint: '+244 923 456 789',
              controller: _whatsappController,
              keyboardType: TextInputType.phone,
              helper: 'Se diferente do telefone principal',
            ),

            _buildInputField(
              label: 'Email',
              hint: 'seu@email.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),

            // Province Dropdown
            _buildDropdownField(
              label: 'Província *',
              hint: 'Selecione a província',
              value: _selectedProvince,
              items: AngolaLocations.provinceNames,
              onChanged: (value) {
                setState(() {
                  _selectedProvince = value;
                  _selectedCity = null;
                  _availableCities = value != null
                      ? AngolaLocations.getCitiesForProvince(value)
                      : [];
                });
                _updateFormValidity();
              },
            ),

            // City Dropdown
            _buildDropdownField(
              label: 'Cidade *',
              hint: 'Selecione a cidade',
              value: _selectedCity,
              items: _availableCities,
              onChanged: _selectedProvince == null
                  ? null
                  : (value) {
                      setState(() {
                        _selectedCity = value;
                      });
                      _updateFormValidity();
                    },
            ),

            const SizedBox(height: 32),

            // Continue button - uses ValueListenableBuilder to avoid full rebuilds
            ValueListenableBuilder<bool>(
              valueListenable: _formValidNotifier,
              builder: (context, isFormValid, child) {
                return SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: isFormValid && !_isSaving ? _saveAndContinue : null,
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
                );
              },
            ),

            const SizedBox(height: 24),
          ],
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

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
  }) {
    // Safety check: only use value if it exists in items list
    final safeValue = (value != null && items.contains(value)) ? value : null;

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
          DropdownButtonFormField<String>(
            value: safeValue,
            items: items
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(item),
                    ))
                .toList(),
            onChanged: onChanged,
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
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
