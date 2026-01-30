import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/models/verification_document_model.dart';
import '../../../../core/providers/verification_provider.dart';
import '../../../../core/services/supplier_onboarding_service.dart';
import '../../../../core/utils/eligibility_messaging.dart';
import '../widgets/identity_verification_panel.dart';

/// Admin screen for managing supplier verification queue
class AdminVerificationScreen extends ConsumerStatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  ConsumerState<AdminVerificationScreen> createState() => _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends ConsumerState<AdminVerificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminVerificationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Verification Queue'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.peach,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.peach,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pending Documents'),
                  const SizedBox(width: 8),
                  if (adminState.pendingDocuments.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${adminState.pendingDocuments.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            const Tab(text: 'Pending Suppliers'),
            const Tab(text: 'Statistics'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminVerificationProvider.notifier).refresh(),
          ),
        ],
      ),
      body: adminState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.peach))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingDocumentsTab(adminState),
                _buildPendingSuppliersTab(adminState),
                _buildStatsTab(adminState),
              ],
            ),
    );
  }

  Widget _buildPendingDocumentsTab(AdminVerificationState state) {
    if (state.pendingDocuments.isEmpty) {
      return _buildEmptyState(
        'No pending documents',
        'All documents have been reviewed',
        Icons.verified_outlined,
      );
    }

    // Group documents by supplier
    final Map<String, List<VerificationDocument>> groupedDocs = {};
    for (final doc in state.pendingDocuments) {
      groupedDocs.putIfAbsent(doc.supplierId, () => []).add(doc);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: groupedDocs.length,
      itemBuilder: (context, index) {
        final supplierId = groupedDocs.keys.elementAt(index);
        final docs = groupedDocs[supplierId]!;

        return _buildSupplierDocumentGroup(supplierId, docs, state);
      },
    );
  }

  Widget _buildSupplierDocumentGroup(
    String supplierId,
    List<VerificationDocument> docs,
    AdminVerificationState state,
  ) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('suppliers').doc(supplierId).get(),
      builder: (context, snapshot) {
        final supplierName = snapshot.hasData && snapshot.data!.exists
            ? (snapshot.data!.data() as Map<String, dynamic>)['businessName'] ?? 'Supplier'
            : 'Loading...';

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
              // Supplier Header
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusMd),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.peach.withValues(alpha: 0.1),
                      child: const Icon(Icons.store, color: AppColors.peach),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplierName,
                            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${docs.length} document(s) pending',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _approveAllDocuments(supplierId),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Approve All'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.success),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Documents List
              ...docs.map((doc) => _buildDocumentItem(doc, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentItem(VerificationDocument doc, AdminVerificationState state) {
    final isProcessing = state.processingDocumentId == doc.id;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Document Type Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getDocumentTypeColor(doc.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getDocumentTypeIcon(doc.type),
              color: _getDocumentTypeColor(doc.type),
            ),
          ),
          const SizedBox(width: 12),
          // Document Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.typeName,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  doc.fileName,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Uploaded ${_formatDate(doc.uploadedAt)}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
                ),
              ],
            ),
          ),
          // Actions
          if (isProcessing)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // View Document
                IconButton(
                  onPressed: () => _viewDocument(doc),
                  icon: const Icon(Icons.visibility_outlined),
                  color: AppColors.peach,
                  tooltip: 'View Document',
                ),
                // Approve
                IconButton(
                  onPressed: () => _approveDocument(doc.id),
                  icon: const Icon(Icons.check_circle_outline),
                  color: AppColors.success,
                  tooltip: 'Approve',
                ),
                // Reject
                IconButton(
                  onPressed: () => _showRejectDialog(doc.id),
                  icon: const Icon(Icons.cancel_outlined),
                  color: AppColors.error,
                  tooltip: 'Reject',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPendingSuppliersTab(AdminVerificationState state) {
    if (state.pendingSuppliers.isEmpty) {
      return _buildEmptyState(
        'No pending suppliers',
        'All suppliers have been verified',
        Icons.how_to_reg_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: state.pendingSuppliers.length,
      itemBuilder: (context, index) {
        final supplier = state.pendingSuppliers[index];
        return _buildSupplierCard(supplier);
      },
    );
  }

  Widget _buildSupplierCard(Map<String, dynamic> supplier) {
    final supplierId = supplier['id'] as String? ?? '';
    final name = supplier['businessName'] as String? ?? 'Unknown';
    final email = supplier['email'] as String? ?? '';
    final pendingDocs = supplier['pendingDocuments'] as int? ?? 0;
    final totalDocs = supplier['totalDocuments'] as int? ?? 0;
    final createdAt = supplier['createdAt'] as DateTime?;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.warning.withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      email,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _buildVerificationProgress(pendingDocs, totalDocs),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Documents: $totalDocs submitted, $pendingDocs pending',
                      style: AppTextStyles.caption,
                    ),
                    if (createdAt != null)
                      Text(
                        'Registered: ${_formatDate(createdAt)}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
                      ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _viewSupplierDetails(supplierId),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationProgress(int pending, int total) {
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('No docs', style: TextStyle(fontSize: 12)),
      );
    }

    final approved = total - pending;
    final progress = approved / total;
    final color = pending == 0 ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$approved/$total',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab(AdminVerificationState state) {
    final stats = state.stats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Overview
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Pending Documents',
                  '${stats['pendingDocuments'] ?? 0}',
                  Icons.pending_outlined,
                  AppColors.warning,
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: _buildStatCard(
                  'Pending Suppliers',
                  '${stats['pendingSuppliers'] ?? 0}',
                  Icons.people_outline,
                  AppColors.peach,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Verified Today',
                  '${stats['verifiedToday'] ?? 0}',
                  Icons.verified_outlined,
                  AppColors.success,
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: _buildStatCard(
                  'Rejected Today',
                  '${stats['rejectedToday'] ?? 0}',
                  Icons.cancel_outlined,
                  AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),

          // Document Type Breakdown
          Text(
            'Documents by Type',
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppDimensions.md),
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Column(
              children: DocumentType.values.map((type) {
                final count = stats['type_${type.name}'] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _getDocumentTypeColor(type).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getDocumentTypeIcon(type),
                          color: _getDocumentTypeColor(type),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getDocumentTypeName(type),
                          style: AppTextStyles.body,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gray100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count pending',
                          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: AppColors.success),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // Helper Methods

  Color _getDocumentTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.businessLicense:
        return Colors.blue;
      case DocumentType.identityDocument:
        return Colors.purple;
      case DocumentType.portfolio:
        return AppColors.peach;
      case DocumentType.insurance:
        return Colors.teal;
      case DocumentType.bankAccount:
        return Colors.green;
      case DocumentType.other:
        return AppColors.gray400;
    }
  }

  IconData _getDocumentTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.businessLicense:
        return Icons.business;
      case DocumentType.identityDocument:
        return Icons.badge;
      case DocumentType.portfolio:
        return Icons.photo_library;
      case DocumentType.insurance:
        return Icons.security;
      case DocumentType.bankAccount:
        return Icons.account_balance;
      case DocumentType.other:
        return Icons.description;
    }
  }

  String _getDocumentTypeName(DocumentType type) {
    switch (type) {
      case DocumentType.businessLicense:
        return 'Business License (CNPJ)';
      case DocumentType.identityDocument:
        return 'Identity Document';
      case DocumentType.portfolio:
        return 'Portfolio';
      case DocumentType.insurance:
        return 'Insurance';
      case DocumentType.bankAccount:
        return 'Bank Account';
      case DocumentType.other:
        return 'Other';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today at ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  // Actions

  void _viewDocument(VerificationDocument doc) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getDocumentTypeIcon(doc.type),
                      color: _getDocumentTypeColor(doc.type),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.typeName,
                            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            doc.fileName,
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // Document Preview
              Expanded(
                child: doc.isImage
                    ? Image.network(
                        doc.fileUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stack) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                                const SizedBox(height: 16),
                                Text('Failed to load image', style: AppTextStyles.body),
                              ],
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              doc.isPdf ? Icons.picture_as_pdf : Icons.description,
                              size: 64,
                              color: AppColors.peach,
                            ),
                            const SizedBox(height: 16),
                            Text(doc.fileName, style: AppTextStyles.body),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                // Open in browser
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open in browser'),
                            ),
                          ],
                        ),
                      ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showRejectDialog(doc.id);
                      },
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _approveDocument(doc.id);
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveDocument(String documentId) async {
    // Get current admin ID (in real app, get from auth)
    const adminId = 'admin_user';

    await ref.read(adminVerificationProvider.notifier).approveDocument(
          documentId: documentId,
          adminId: adminId,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document approved'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _showRejectDialog(String documentId) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.isNotEmpty && mounted) {
      const adminId = 'admin_user';

      await ref.read(adminVerificationProvider.notifier).rejectDocument(
            documentId: documentId,
            adminId: adminId,
            reason: reasonController.text,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document rejected'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    reasonController.dispose();
  }

  Future<void> _approveAllDocuments(String supplierId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve All Documents'),
        content: const Text(
          'Are you sure you want to approve all pending documents for this supplier?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      const adminId = 'admin_user';

      await ref.read(adminVerificationProvider.notifier).approveAllDocuments(
            supplierId: supplierId,
            adminId: adminId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All documents approved'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  void _viewSupplierDetails(String supplierId) {
    final onboardingService = SupplierOnboardingService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: FutureBuilder<SupplierOnboardingStatus?>(
            future: onboardingService.getOnboardingStatus(supplierId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.peach),
                );
              }

              if (!snapshot.hasData || snapshot.data == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      const Text('Supplier not found'),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }

              final supplier = snapshot.data!;
              final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';

              // ASSERTION: Ensure we have full SupplierOnboardingStatus data
              // This prevents regressions if someone refactors to pass partial data
              assert(
                supplier.supplierId.isNotEmpty,
                'Admin supplier details must use full SupplierOnboardingStatus with valid supplierId',
              );
              debugPrint(
                '🔍 _viewSupplierDetails: supplierId=${supplier.supplierId}, '
                'identityVerificationStatus=${supplier.identityVerificationStatus.name}, '
                'accountStatus=${supplier.accountStatus.name}, '
                'isEligibleForBookings=${supplier.isEligibleForBookings}',
              );

              return Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.gray300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.peach.withValues(alpha: 0.1),
                          radius: 24,
                          child: Text(
                            (supplier.businessName ?? 'S')[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.peach,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                supplier.businessName ?? 'Unknown Supplier',
                                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                supplier.category ?? 'No category',
                                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Eligibility Card
                          AdminEligibilityCard(status: supplier),
                          const SizedBox(height: 16),

                          // Identity Verification Panel - THE KEY SECTION
                          IdentityVerificationPanel(
                            supplier: supplier,
                            adminId: adminId,
                            onStatusChanged: () {
                              // Refresh the bottom sheet
                              Navigator.pop(context);
                              _viewSupplierDetails(supplierId);
                              // Also refresh the main list
                              ref.read(adminVerificationProvider.notifier).refresh();
                            },
                          ),
                          const SizedBox(height: 16),

                          // Contact Information
                          _buildSupplierDetailSection(
                            title: 'Contact Information',
                            icon: Icons.contact_phone,
                            children: [
                              if (supplier.phone != null)
                                _buildDetailRow('Phone', supplier.phone!),
                              if (supplier.email != null)
                                _buildDetailRow('Email', supplier.email!),
                              if (supplier.whatsapp != null)
                                _buildDetailRow('WhatsApp', supplier.whatsapp!),
                              if (supplier.website != null)
                                _buildDetailRow('Website', supplier.website!),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Location
                          if (supplier.city != null || supplier.province != null)
                            _buildSupplierDetailSection(
                              title: 'Location',
                              icon: Icons.location_on,
                              children: [
                                if (supplier.address != null)
                                  _buildDetailRow('Address', supplier.address!),
                                if (supplier.city != null)
                                  _buildDetailRow('City', supplier.city!),
                                if (supplier.province != null)
                                  _buildDetailRow('Province', supplier.province!),
                              ],
                            ),
                          const SizedBox(height: 16),

                          // Business Info
                          _buildSupplierDetailSection(
                            title: 'Business Information',
                            icon: Icons.business,
                            children: [
                              _buildDetailRow('Entity Type', supplier.entityType.name),
                              if (supplier.nif != null)
                                _buildDetailRow('NIF', supplier.nif!),
                              if (supplier.idDocumentType != null)
                                _buildDetailRow('Document Type', supplier.idDocumentType!.name),
                              if (supplier.idDocumentNumber != null)
                                _buildDetailRow('Document Number', supplier.idDocumentNumber!),
                              _buildDetailRow('Pricing', supplier.priceDisplay),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
