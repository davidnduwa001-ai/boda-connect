import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/models/supplier_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/supplier_onboarding_service.dart';
import '../../../../core/utils/eligibility_messaging.dart';
import '../widgets/identity_verification_panel.dart';

/// Admin screen for reviewing supplier onboarding applications
/// Uber-style approval workflow: PENDING_REVIEW → ACTIVE / NEEDS_CLARIFICATION / REJECTED
class AdminOnboardingQueueScreen extends ConsumerStatefulWidget {
  const AdminOnboardingQueueScreen({super.key});

  @override
  ConsumerState<AdminOnboardingQueueScreen> createState() =>
      _AdminOnboardingQueueScreenState();
}

class _AdminOnboardingQueueScreenState
    extends ConsumerState<AdminOnboardingQueueScreen>
    with SingleTickerProviderStateMixin {
  final _onboardingService = SupplierOnboardingService();
  late TabController _tabController;
  OnboardingStats? _stats;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final stats = await _onboardingService.getOnboardingStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Supplier Onboarding'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.peach,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.peach,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pendentes'),
            Tab(text: 'Alterações'),
            Tab(text: 'Aprovados'),
            Tab(text: 'Rejeitados'),
            Tab(text: 'Estatísticas'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadStats();
              setState(() {}); // Refresh stream
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingReviewTab(),
          _buildNeedsClarificationTab(),
          _buildApprovedTab(),
          _buildRejectedTab(),
          _buildStatsTab(),
        ],
      ),
    );
  }

  Widget _buildPendingReviewTab() {
    return StreamBuilder<List<SupplierOnboardingStatus>>(
      stream: _onboardingService.streamPendingReviewSuppliers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.peach),
          );
        }

        if (snapshot.hasError) {
          return _buildEmptyState(
            'Error loading queue',
            'Please try again',
            Icons.error_outline,
          );
        }

        final suppliers = snapshot.data ?? [];

        if (suppliers.isEmpty) {
          return _buildEmptyState(
            'No pending applications',
            'All supplier applications have been reviewed',
            Icons.check_circle_outline,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.md),
          itemCount: suppliers.length,
          itemBuilder: (context, index) {
            return _buildSupplierCard(suppliers[index]);
          },
        );
      },
    );
  }

  Widget _buildNeedsClarificationTab() {
    return StreamBuilder<List<SupplierOnboardingStatus>>(
      stream: _onboardingService.streamSuppliersByStatus(SupplierAccountStatus.needsClarification),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.peach),
          );
        }

        final suppliers = snapshot.data ?? [];

        if (suppliers.isEmpty) {
          return _buildEmptyState(
            'Nenhuma alteração pendente',
            'Não há fornecedores aguardando resposta',
            Icons.check_circle_outline,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.md),
          itemCount: suppliers.length,
          itemBuilder: (context, index) {
            return _buildSupplierCard(suppliers[index]);
          },
        );
      },
    );
  }

  Widget _buildApprovedTab() {
    return StreamBuilder<List<SupplierOnboardingStatus>>(
      stream: _onboardingService.streamSuppliersByStatus(SupplierAccountStatus.active),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.peach),
          );
        }

        final suppliers = snapshot.data ?? [];

        if (suppliers.isEmpty) {
          return _buildEmptyState(
            'Nenhum fornecedor aprovado',
            'Ainda não há fornecedores aprovados',
            Icons.store_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.md),
          itemCount: suppliers.length,
          itemBuilder: (context, index) {
            return _buildSupplierCard(suppliers[index]);
          },
        );
      },
    );
  }

  Widget _buildRejectedTab() {
    return StreamBuilder<List<SupplierOnboardingStatus>>(
      stream: _onboardingService.streamSuppliersByStatus(SupplierAccountStatus.rejected),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.peach),
          );
        }

        final suppliers = snapshot.data ?? [];

        if (suppliers.isEmpty) {
          return _buildEmptyState(
            'Nenhum fornecedor rejeitado',
            'Não há fornecedores rejeitados',
            Icons.cancel_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.md),
          itemCount: suppliers.length,
          itemBuilder: (context, index) {
            return _buildSupplierCard(suppliers[index]);
          },
        );
      },
    );
  }

  Widget _buildSupplierCard(SupplierOnboardingStatus supplier) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with profile photo
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.peach.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppDimensions.radiusMd),
                topRight: Radius.circular(AppDimensions.radiusMd),
              ),
            ),
            child: Row(
              children: [
                // Profile photo or placeholder
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.peach.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    image: supplier.photos.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(supplier.photos.first),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: supplier.photos.isEmpty
                      ? const Icon(Icons.store, color: AppColors.peach)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.businessName ?? 'Sem Nome',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.peach.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              supplier.category ?? 'Categoria desconhecida',
                              style: const TextStyle(
                                color: AppColors.peach,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (supplier.subcategories.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              '+${supplier.subcategories.length}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(supplier.accountStatus),
              ],
            ),
          ),

          // Portfolio Photos Gallery
          if (supplier.allPhotos.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.photo_library, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'Fotos do Portfolio (${supplier.allPhotos.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: supplier.allPhotos.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _showPhotoGallery(supplier.allPhotos, index),
                          child: Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: NetworkImage(supplier.allPhotos[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Description
          if (supplier.description != null && supplier.description!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      const Text(
                        'Descrição do Serviço',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      supplier.description!,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Details Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),

                // Business Info Row
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        Icons.business,
                        'Tipo',
                        supplier.entityTypeText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoCard(
                        Icons.attach_money,
                        'Preço',
                        supplier.priceDisplay,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Location Row
                if (supplier.city != null || supplier.province != null)
                  _buildDetailRow(
                    Icons.location_on,
                    'Localização',
                    [supplier.address, supplier.city, supplier.province]
                        .where((e) => e != null && e.isNotEmpty)
                        .join(', '),
                  ),
                const SizedBox(height: 8),

                // Contact Info Section
                const Row(
                  children: [
                    Icon(Icons.contact_phone, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text(
                      'Informações de Contacto',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (supplier.phone != null)
                      _buildContactChip(Icons.phone, supplier.phone!),
                    if (supplier.whatsapp != null)
                      _buildContactChip(Icons.message, supplier.whatsapp!, isWhatsapp: true),
                    if (supplier.email != null)
                      _buildContactChip(Icons.email, supplier.email!),
                    if (supplier.website != null)
                      _buildContactChip(Icons.language, supplier.website!),
                  ],
                ),
                const SizedBox(height: 12),

                // NIF (if empresa)
                if (supplier.entityType == SupplierEntityType.empresa &&
                    supplier.nif != null) ...[
                  _buildDetailRow(Icons.badge, 'NIF', supplier.nif!),
                  const SizedBox(height: 8),
                ],

                // Identity Document
                if (supplier.idDocumentType != null) ...[
                  _buildDetailRow(
                    Icons.credit_card,
                    'Documento de Identidade',
                    '${_getDocumentTypeName(supplier.idDocumentType!)} - ${supplier.idDocumentNumber ?? 'N/A'}',
                  ),
                  const SizedBox(height: 8),
                ],

                // Submitted date
                if (supplier.createdAt != null)
                  _buildDetailRow(
                    Icons.calendar_today,
                    'Data de Candidatura',
                    DateFormat('dd/MM/yyyy HH:mm').format(supplier.createdAt!),
                  ),

                // Document verification section - CRITICAL FOR ADMIN REVIEW
                _buildDocumentVerificationSection(supplier),
                const SizedBox(height: 8),

                // Identity Verification Panel (SEPARATE from onboarding)
                _buildIdentityVerificationSection(supplier),

                // Eligibility Status Card
                _buildEligibilityCard(supplier),
              ],
            ),
          ),

          // Actions
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRejectDialog(supplier),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Rejeitar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRequestChangesDialog(supplier),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning),
                    ),
                    child: const Text('Alterações'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveSupplier(supplier),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Aprovar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build the document verification section - CRITICAL for admin review
  Widget _buildDocumentVerificationSection(SupplierOnboardingStatus supplier) {
    final hasDocument = supplier.idDocumentUrl != null;
    final hasDocumentInfo = supplier.idDocumentType != null || supplier.idDocumentNumber != null;

    if (!hasDocument && !hasDocumentInfo) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.error, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ATENÇÃO: Nenhum documento de identificação enviado',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_user, color: AppColors.info, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DOCUMENTOS DE VERIFICAÇÃO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.info,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Verificar antes de aprovar',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasDocument)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Enviado',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Document details
          if (hasDocumentInfo) ...[
            // Document type and number row
            Row(
              children: [
                Expanded(
                  child: _buildDocumentDetailItem(
                    Icons.badge,
                    'Tipo de Documento',
                    supplier.idDocumentType != null
                        ? _getDocumentTypeName(supplier.idDocumentType!)
                        : 'Não especificado',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDocumentDetailItem(
                    Icons.numbers,
                    'Número do Documento',
                    supplier.idDocumentNumber ?? 'Não informado',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // NIF if empresa
          if (supplier.entityType == SupplierEntityType.empresa && supplier.nif != null) ...[
            _buildDocumentDetailItem(
              Icons.business_center,
              'NIF (Número de Identificação Fiscal)',
              supplier.nif!,
            ),
            const SizedBox(height: 12),
          ],

          // Document preview/download buttons
          if (hasDocument) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showDocumentPreview(
                      supplier.idDocumentUrl!,
                      title: 'Documento de Identidade',
                      documentType: supplier.idDocumentType != null
                          ? _getDocumentTypeName(supplier.idDocumentType!)
                          : null,
                    ),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Ver Documento'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openInBrowser(supplier.idDocumentUrl!),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Descarregar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.info,
                      side: const BorderSide(color: AppColors.info),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ficheiro do documento não enviado. Verifique os dados informados.',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build the Identity Verification section using IdentityVerificationPanel
  Widget _buildIdentityVerificationSection(SupplierOnboardingStatus supplier) {
    // Get current admin ID
    final adminId = FirebaseAuth.instance.currentUser?.uid ??
                    ref.read(authProvider).firebaseUser?.uid ?? 'admin';

    return IdentityVerificationPanel(
      supplier: supplier,
      adminId: adminId,
      onStatusChanged: () {
        // Refresh the list when status changes
        setState(() {});
        _loadStats();
      },
    );
  }

  /// Build the Eligibility Card showing booking eligibility status
  Widget _buildEligibilityCard(SupplierOnboardingStatus supplier) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AdminEligibilityCard(status: supplier),
    );
  }

  Widget _buildDocumentDetailItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactChip(IconData icon, String value, {bool isWhatsapp = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isWhatsapp ? const Color(0xFF25D366).withValues(alpha: 0.1) : AppColors.gray100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWhatsapp ? const Color(0xFF25D366).withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isWhatsapp ? const Color(0xFF25D366) : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: isWhatsapp ? const Color(0xFF25D366) : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoGallery(List<String> photos, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  child: Center(
                    child: Image.network(
                      photos[index],
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${initialIndex + 1} / ${photos.length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(SupplierAccountStatus status) {
    Color color;
    String text;

    switch (status) {
      case SupplierAccountStatus.pendingReview:
        color = AppColors.info;
        text = 'Pendente';
        break;
      case SupplierAccountStatus.active:
        color = AppColors.success;
        text = 'Activo';
        break;
      case SupplierAccountStatus.needsClarification:
        color = AppColors.warning;
        text = 'Alteracoes';
        break;
      case SupplierAccountStatus.rejected:
        color = AppColors.error;
        text = 'Rejeitado';
        break;
      case SupplierAccountStatus.suspended:
        color = AppColors.error;
        text = 'Suspenso';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  String _getDocumentTypeName(IdentityDocumentType type) {
    switch (type) {
      case IdentityDocumentType.bilheteIdentidade:
        return 'Bilhete de Identidade';
      case IdentityDocumentType.passaporte:
        return 'Passaporte';
    }
  }

  Widget _buildStatsTab() {
    if (_isLoadingStats) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.peach),
      );
    }

    if (_stats == null) {
      return _buildEmptyState(
        'Error loading statistics',
        'Please try again',
        Icons.error_outline,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Onboarding Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Stats grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Pending Review',
                  _stats!.pendingReview.toString(),
                  Icons.hourglass_top,
                  AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active',
                  _stats!.active.toString(),
                  Icons.check_circle,
                  AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Needs Changes',
                  _stats!.needsClarification.toString(),
                  Icons.edit_note,
                  AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Rejected',
                  _stats!.rejected.toString(),
                  Icons.cancel,
                  AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Suspended',
                  _stats!.suspended.toString(),
                  Icons.block,
                  Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Suppliers',
                  _stats!.total.toString(),
                  Icons.people,
                  AppColors.peach,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showDocumentPreview(String url, {String? title, String? documentType}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with title and actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.peach,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title ?? 'Documento de Verificação',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (documentType != null)
                          Text(
                            documentType,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Download button
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    tooltip: 'Descarregar documento',
                    onPressed: () => _downloadDocument(url),
                  ),
                  // Open in new tab button
                  IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.white),
                    tooltip: 'Abrir em nova aba',
                    onPressed: () => _openInBrowser(url),
                  ),
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Document preview
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: AppColors.peach),
                          const SizedBox(height: 16),
                          Text(
                            'A carregar documento... ${((loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)) * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error loading document: $error');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                            const SizedBox(height: 16),
                            const Text(
                              'Erro ao carregar documento',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'O documento pode estar indisponível ou o formato não é suportado.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _openInBrowser(url),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Abrir no navegador'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.peach,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Footer with instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text(
                    'Use dois dedos para ampliar • Arraste para mover',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadDocument(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível descarregar o documento'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error downloading document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao descarregar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível abrir o documento'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening document: $e');
    }
  }

  Future<void> _approveSupplier(SupplierOnboardingStatus supplier) async {
    // Use FirebaseAuth directly as primary source - more reliable than provider state
    final adminId = FirebaseAuth.instance.currentUser?.uid ??
                    ref.read(authProvider).firebaseUser?.uid;
    debugPrint('🔍 _approveSupplier: adminId=$adminId, supplierId=${supplier.supplierId}');

    if (adminId == null) {
      debugPrint('❌ _approveSupplier: Admin not authenticated');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro: Administrador não autenticado'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _CertificationChecklistDialog(supplier: supplier),
    );

    if (confirmed != true) return;

    debugPrint('📤 Approving supplier ${supplier.supplierId}...');
    final success = await _onboardingService.approveSupplier(
      supplierId: supplier.supplierId,
      adminId: adminId,
    );
    debugPrint('📥 Approve result: $success');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Fornecedor aprovado com sucesso!'
                : 'Erro ao aprovar fornecedor',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
      if (success) _loadStats();
    }
  }

  Future<void> _showRequestChangesDialog(SupplierOnboardingStatus supplier) async {
    // Use FirebaseAuth directly as primary source - more reliable than provider state
    final adminId = FirebaseAuth.instance.currentUser?.uid ??
                    ref.read(authProvider).firebaseUser?.uid;
    debugPrint('🔍 _showRequestChangesDialog: adminId=$adminId, supplierId=${supplier.supplierId}');

    if (adminId == null) {
      debugPrint('❌ _showRequestChangesDialog: Admin not authenticated');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro: Administrador não autenticado'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitar Alteracoes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Descreva as alteracoes necessarias para "${supplier.businessName}":',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Ex: Por favor, envie uma foto mais clara do documento de identidade...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (result == null || result.trim().isEmpty) return;

    debugPrint('📤 Requesting changes for supplier ${supplier.supplierId}...');
    final success = await _onboardingService.requestChanges(
      supplierId: supplier.supplierId,
      adminId: adminId,
      clarificationRequest: result,
    );
    debugPrint('📥 Request changes result: $success');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Pedido de alteracoes enviado!'
                : 'Erro ao enviar pedido',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
      if (success) _loadStats();
    }
  }

  Future<void> _showRejectDialog(SupplierOnboardingStatus supplier) async {
    // Use FirebaseAuth directly as primary source - more reliable than provider state
    final adminId = FirebaseAuth.instance.currentUser?.uid ??
                    ref.read(authProvider).firebaseUser?.uid;
    debugPrint('🔍 _showRejectDialog: adminId=$adminId, supplierId=${supplier.supplierId}');

    if (adminId == null) {
      debugPrint('❌ _showRejectDialog: Admin not authenticated');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro: Administrador não autenticado'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeitar Candidatura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Indique o motivo da rejeicao para "${supplier.businessName}":',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Ex: A categoria de servico nao e suportada pela plataforma...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );

    if (result == null || result.trim().isEmpty) return;

    debugPrint('📤 Rejecting supplier ${supplier.supplierId}...');
    final success = await _onboardingService.rejectSupplier(
      supplierId: supplier.supplierId,
      adminId: adminId,
      rejectionReason: result,
    );
    debugPrint('📥 Reject result: $success');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Candidatura rejeitada'
                : 'Erro ao rejeitar candidatura',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
      if (success) _loadStats();
    }
  }
}

extension on SupplierOnboardingStatus {
  String get entityTypeText {
    switch (entityType) {
      case SupplierEntityType.individual:
        return 'Individual';
      case SupplierEntityType.empresa:
        return 'Empresa';
    }
  }
}

/// Certification Checklist Dialog for Admin to verify supplier meets all criteria
class _CertificationChecklistDialog extends StatefulWidget {
  final SupplierOnboardingStatus supplier;

  const _CertificationChecklistDialog({required this.supplier});

  @override
  State<_CertificationChecklistDialog> createState() =>
      _CertificationChecklistDialogState();
}

class _CertificationChecklistDialogState
    extends State<_CertificationChecklistDialog> {
  // Required criteria
  bool _identityVerified = false;
  bool _businessRegistration = false;
  bool _portfolioQuality = false;
  bool _serviceDescription = false;
  bool _contactVerified = false;
  bool _bankAccountValid = false;

  // Optional criteria
  bool _categoryExperience = false;
  bool _insuranceProvided = false;

  bool get _allRequiredMet =>
      _identityVerified &&
      _businessRegistration &&
      _portfolioQuality &&
      _serviceDescription &&
      _contactVerified &&
      _bankAccountValid;

  int get _requiredCount => [
        _identityVerified,
        _businessRegistration,
        _portfolioQuality,
        _serviceDescription,
        _contactVerified,
        _bankAccountValid,
      ].where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.peach.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.verified_user, color: AppColors.peach),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Checklist de Certificação',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Supplier info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.store, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.supplier.businessName ?? 'Sem Nome',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            widget.supplier.category ?? 'Categoria desconhecida',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Progress indicator
              Row(
                children: [
                  Text(
                    'Critérios: $_requiredCount/6',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _requiredCount / 6,
                      backgroundColor: AppColors.gray200,
                      valueColor: AlwaysStoppedAnimation(
                        _allRequiredMet ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Required Criteria Section
              const Text(
                'CRITÉRIOS OBRIGATÓRIOS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              _buildCheckItem(
                icon: Icons.badge,
                title: 'Documento de Identidade',
                description: 'BI ou Passaporte válido e legível',
                value: _identityVerified,
                onChanged: (v) => setState(() => _identityVerified = v ?? false),
                required: true,
              ),

              _buildCheckItem(
                icon: Icons.business,
                title: 'Registo Comercial',
                description: 'NIF válido ou Alvará Comercial (para empresas)',
                value: _businessRegistration,
                onChanged: (v) =>
                    setState(() => _businessRegistration = v ?? false),
                required: true,
              ),

              _buildCheckItem(
                icon: Icons.photo_library,
                title: 'Qualidade do Portfólio',
                description: 'Mínimo 5 fotos de trabalhos anteriores',
                value: _portfolioQuality,
                onChanged: (v) => setState(() => _portfolioQuality = v ?? false),
                required: true,
              ),

              _buildCheckItem(
                icon: Icons.description,
                title: 'Descrição de Serviços',
                description: 'Descrição completa com preços definidos',
                value: _serviceDescription,
                onChanged: (v) =>
                    setState(() => _serviceDescription = v ?? false),
                required: true,
              ),

              _buildCheckItem(
                icon: Icons.phone,
                title: 'Contactos Verificados',
                description: 'Telefone e email válidos e confirmados',
                value: _contactVerified,
                onChanged: (v) => setState(() => _contactVerified = v ?? false),
                required: true,
              ),

              _buildCheckItem(
                icon: Icons.account_balance,
                title: 'Conta Bancária',
                description: 'IBAN válido para receber pagamentos Multicaixa',
                value: _bankAccountValid,
                onChanged: (v) => setState(() => _bankAccountValid = v ?? false),
                required: true,
              ),

              const SizedBox(height: 20),

              // Optional Criteria Section
              const Text(
                'CRITÉRIOS OPCIONAIS (BÓNUS)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.info,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              _buildCheckItem(
                icon: Icons.workspace_premium,
                title: 'Experiência Comprovada',
                description: 'Prova de experiência na categoria selecionada',
                value: _categoryExperience,
                onChanged: (v) =>
                    setState(() => _categoryExperience = v ?? false),
                required: false,
              ),

              _buildCheckItem(
                icon: Icons.security,
                title: 'Seguro de Responsabilidade',
                description: 'Para serviços de alto risco (catering, pirotecnia)',
                value: _insuranceProvided,
                onChanged: (v) =>
                    setState(() => _insuranceProvided = v ?? false),
                required: false,
              ),

              const SizedBox(height: 16),

              // Warning if not all required
              if (!_allRequiredMet)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: AppColors.warning),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Todos os critérios obrigatórios devem ser verificados antes de aprovar.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _allRequiredMet ? () => Navigator.pop(context, true) : null,
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Aprovar Fornecedor'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.gray300,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckItem({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required bool required,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: value ? AppColors.success.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.success,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        dense: true,
        title: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: value ? TextDecoration.lineThrough : null,
                  color: value ? AppColors.textSecondary : AppColors.textPrimary,
                ),
              ),
            ),
            if (required)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Obrigatório',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 26, top: 2),
          child: Text(
            description,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
