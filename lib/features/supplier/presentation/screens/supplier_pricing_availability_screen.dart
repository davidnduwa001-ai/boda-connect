import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/providers/supplier_registration_provider.dart';
import '../../../../core/repositories/supplier_repository.dart';
import '../../../../core/routing/route_names.dart';

class SupplierPricingAvailabilityScreen extends ConsumerStatefulWidget {
  const SupplierPricingAvailabilityScreen({super.key});

  @override
  ConsumerState<SupplierPricingAvailabilityScreen> createState() =>
      _SupplierPricingAvailabilityScreenState();
}

class _SupplierPricingAvailabilityScreenState
    extends ConsumerState<SupplierPricingAvailabilityScreen> {
  bool _priceOnRequest = false;
  bool _isSaving = false;
  final TextEditingController _priceController =
      TextEditingController(text: '50.000');

  final List<String> _days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  final Set<String> _selectedDays = {};

  bool get _canSubmit => (_priceOnRequest || _priceController.text.isNotEmpty) && !_isSaving;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _selectAllDays() {
    setState(() {
      _selectedDays.addAll(_days);
    });
  }

  void _clearDays() {
    setState(() {
      _selectedDays.clear();
    });
  }

  /// Notify admins about new supplier registration
  Future<void> _notifyAdminsNewSupplier({
    required String supplierId,
    required String businessName,
    required String category,
  }) async {
    // Create admin notification in Firestore
    await FirebaseFirestore.instance.collection('admin_notifications').add({
      'type': 'new_supplier_registration',
      'supplierId': supplierId,
      'businessName': businessName,
      'category': category,
      'message': 'Novo fornecedor aguardando aprovação: $businessName ($category)',
      'isRead': false,
      'priority': 'high',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Also add to onboarding queue for admin dashboard
    await FirebaseFirestore.instance.collection('onboarding_queue').doc(supplierId).set({
      'supplierId': supplierId,
      'businessName': businessName,
      'category': category,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _finalizeRegistration() async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // Get registration data from provider
      final registrationData = ref.read(supplierRegistrationProvider);

      // Find the supplier document
      final supplierQuery = await FirebaseFirestore.instance
          .collection('suppliers')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (supplierQuery.docs.isEmpty) {
        throw Exception('Supplier profile not found');
      }

      final supplierDoc = supplierQuery.docs.first;
      final supplierId = supplierDoc.id;

      // Parse price
      final priceText = _priceController.text.replaceAll('.', '').replaceAll(',', '');
      final minPrice = int.tryParse(priceText) ?? 0;

      // Build update data with all registration info
      final updateData = <String, dynamic>{
        'accountStatus': 'pendingReview',
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add pricing data
      if (_priceOnRequest) {
        updateData['priceOnRequest'] = true;
      } else {
        updateData['minPrice'] = minPrice;
        updateData['priceOnRequest'] = false;
      }

      // Add availability
      if (_selectedDays.isNotEmpty) {
        updateData['availableDays'] = _selectedDays.toList();
      }

      // Add entity type and NIF from registration provider
      updateData['entityType'] = registrationData.entityType.name;
      if (registrationData.nif != null && registrationData.nif!.isNotEmpty) {
        updateData['nif'] = registrationData.nif;
      }

      // Add identity document info
      if (registrationData.idDocumentType != null) {
        updateData['idDocumentType'] = registrationData.idDocumentType!.name;
      }
      if (registrationData.idDocumentNumber != null && registrationData.idDocumentNumber!.isNotEmpty) {
        updateData['idDocumentNumber'] = registrationData.idDocumentNumber;
      }

      // Add service type/category
      if (registrationData.serviceType != null) {
        updateData['category'] = registrationData.serviceType;
      }
      if (registrationData.eventTypes != null && registrationData.eventTypes!.isNotEmpty) {
        updateData['subcategories'] = registrationData.eventTypes;
      }

      // Add description
      if (registrationData.description != null && registrationData.description!.isNotEmpty) {
        updateData['description'] = registrationData.description;
      }

      debugPrint('📤 Finalizing supplier registration...');
      debugPrint('📋 Update fields: ${updateData.keys.join(', ')}');

      // Upload photos if provided
      final repository = SupplierRepository();
      List<String> photoUrls = [];

      // Upload profile image
      if (registrationData.profileImage != null) {
        debugPrint('📸 Uploading profile image...');
        final profileUrl = await repository.uploadSupplierPhoto(supplierId, registrationData.profileImage!);
        photoUrls.add(profileUrl);
        debugPrint('✅ Profile image uploaded: $profileUrl');
      }

      // Upload portfolio images
      if (registrationData.portfolioImages != null && registrationData.portfolioImages!.isNotEmpty) {
        debugPrint('📸 Uploading ${registrationData.portfolioImages!.length} portfolio images...');
        final portfolioUrls = await repository.uploadSupplierPhotos(supplierId, registrationData.portfolioImages!);
        photoUrls.addAll(portfolioUrls);
        debugPrint('✅ Portfolio images uploaded: ${portfolioUrls.length} photos');
      }

      // Add photos to update data
      if (photoUrls.isNotEmpty) {
        updateData['photos'] = photoUrls;
        debugPrint('📸 Total photos to save: ${photoUrls.length}');
      }

      // Upload identity document file if provided
      if (registrationData.idDocumentFile != null) {
        debugPrint('📄 Uploading identity document...');
        final docUrl = await repository.uploadSupplierPhoto(supplierId, registrationData.idDocumentFile!);
        updateData['idDocumentUrl'] = docUrl;
        debugPrint('✅ Identity document uploaded: $docUrl');
      }

      // Update supplier document
      await supplierDoc.reference.update(updateData);

      debugPrint('✅ Supplier registration finalized with PENDING_REVIEW status');
      debugPrint('📸 Photos saved: ${photoUrls.length}');

      // Notify admins about new supplier registration
      try {
        await _notifyAdminsNewSupplier(
          supplierId: supplierId,
          businessName: registrationData.businessName ?? 'Novo Fornecedor',
          category: registrationData.serviceType ?? 'Não especificado',
        );
        debugPrint('📢 Admin notification sent for new supplier');
      } catch (e) {
        // Don't fail registration if notification fails
        debugPrint('⚠️ Failed to notify admins: $e');
      }

      // Clear registration data
      ref.read(supplierRegistrationProvider.notifier).reset();

      if (mounted) {
        context.go(Routes.registerCompleted);
      }
    } catch (e) {
      debugPrint('❌ Error finalizing registration: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao finalizar registo: ${e.toString()}'),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                      value: 0.9,
                      backgroundColor: AppColors.gray200,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.peach),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '90%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Title
            const Text(
              'Preços & Disponibilidade',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'Configure suas condições comerciais',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 24),

            // Price input
            const Text(
              'Preço inicial',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _priceController,
              enabled: !_priceOnRequest,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: TextStyle(
                fontSize: 16,
                color: _priceOnRequest ? AppColors.textTertiary : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '50.000',
                suffixText: 'Kz',
                suffixStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: _priceOnRequest ? AppColors.gray100 : AppColors.gray50,
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

            const SizedBox(height: 4),

            const Text(
              'Valor base do seu serviço',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 12),

            // Price on request checkbox
            GestureDetector(
              onTap: () {
                setState(() {
                  _priceOnRequest = !_priceOnRequest;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: _priceOnRequest
                            ? AppColors.peach
                            : Colors.transparent,
                        border: Border.all(
                          color: _priceOnRequest
                              ? AppColors.peach
                              : AppColors.gray300,
                          width: 2,
                        ),
                      ),
                      child: _priceOnRequest
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Preço sob consulta',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Availability section
            const Text(
              'Disponibilidade *',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'Em que dias da semana você pode atender eventos?',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 12),

            // Day selector
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _days.map((day) {
                final isSelected = _selectedDays.contains(day);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedDays.remove(day);
                      } else {
                        _selectedDays.add(day);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.peach : AppColors.gray300,
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? AppColors.peach.withValues(alpha: 0.08)
                          : Colors.white,
                    ),
                    child: Text(
                      day,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isSelected ? AppColors.peach : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Select all / Clear buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectAllDays,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.peach,
                      side: const BorderSide(color: AppColors.peach),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                      ),
                    ),
                    child: const Text(
                      'Selecionar todos',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearDays,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.gray300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                      ),
                    ),
                    child: const Text(
                      'Limpar',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Tip box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: AppColors.success,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Você poderá ajustar preços e disponibilidade específicos para cada evento no chat com os clientes.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Finalize button
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton(
                onPressed: _canSubmit ? _finalizeRegistration : null,
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
                        'Finalizar registo',
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
    );
  }
}
