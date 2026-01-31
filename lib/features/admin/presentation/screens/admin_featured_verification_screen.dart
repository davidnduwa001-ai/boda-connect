import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/services/admin_management_service.dart';

/// Provider for admin management service
final adminManagementServiceProvider = Provider<AdminManagementService>((ref) {
  return AdminManagementService();
});

/// Admin screen for managing:
/// - Featured suppliers (Destaques)
/// - Verified badges for suppliers and clients
class AdminFeaturedVerificationScreen extends ConsumerStatefulWidget {
  const AdminFeaturedVerificationScreen({super.key});

  @override
  ConsumerState<AdminFeaturedVerificationScreen> createState() =>
      _AdminFeaturedVerificationScreenState();
}

class _AdminFeaturedVerificationScreenState
    extends ConsumerState<AdminFeaturedVerificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  Map<String, int> _stats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final service = ref.read(adminManagementServiceProvider);
    final stats = await service.getManagementStats();
    if (mounted) {
      setState(() => _stats = stats);
    }
  }

  String get _adminId => FirebaseAuth.instance.currentUser?.uid ?? 'admin';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Gestão de Destaques e Verificação'),
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
                  const Icon(Icons.star, size: 18),
                  const SizedBox(width: 4),
                  const Text('Destaques'),
                  if (_stats['featuredSuppliers'] != null &&
                      _stats['featuredSuppliers']! > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.peach,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_stats['featuredSuppliers']}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, size: 18),
                  const SizedBox(width: 4),
                  const Text('Fornecedores'),
                  if (_stats['verifiedSuppliers'] != null &&
                      _stats['verifiedSuppliers']! > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_stats['verifiedSuppliers']}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline, size: 18),
                  const SizedBox(width: 4),
                  const Text('Clientes'),
                  if (_stats['verifiedUsers'] != null &&
                      _stats['verifiedUsers']! > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.info,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_stats['verifiedUsers']}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(AppDimensions.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                filled: true,
                fillColor: AppColors.gray50,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          // Tab content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.peach))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFeaturedSuppliersTab(),
                      _buildVerifiedSuppliersTab(),
                      _buildVerifiedUsersTab(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.peach,
        icon: const Icon(Icons.add),
        label: Text(_getFloatingButtonLabel()),
      ),
    );
  }

  String _getFloatingButtonLabel() {
    switch (_tabController.index) {
      case 0:
        return 'Adicionar Destaque';
      case 1:
        return 'Verificar Fornecedor';
      case 2:
        return 'Verificar Cliente';
      default:
        return 'Adicionar';
    }
  }

  void _showAddDialog() {
    switch (_tabController.index) {
      case 0:
        _showAddFeaturedSupplierDialog();
        break;
      case 1:
        _showVerifySupplierDialog();
        break;
      case 2:
        _showVerifyUserDialog();
        break;
    }
  }

  // ==================== FEATURED SUPPLIERS TAB ====================

  Widget _buildFeaturedSuppliersTab() {
    final service = ref.watch(adminManagementServiceProvider);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: service.streamFeaturedSuppliers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.peach));
        }

        final suppliers = snapshot.data ?? [];
        final filtered = _searchQuery.isEmpty
            ? suppliers
            : suppliers.where((s) {
                final name =
                    (s['businessName'] as String? ?? '').toLowerCase();
                final category = (s['category'] as String? ?? '').toLowerCase();
                return name.contains(_searchQuery.toLowerCase()) ||
                    category.contains(_searchQuery.toLowerCase());
              }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(
            'Nenhum fornecedor em destaque',
            'Adicione fornecedores ao destaque para aparecerem na página inicial',
            Icons.star_outline,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.md),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final supplier = filtered[index];
            return _buildFeaturedSupplierCard(supplier);
          },
        );
      },
    );
  }

  Widget _buildFeaturedSupplierCard(Map<String, dynamic> supplier) {
    final id = supplier['id'] as String;
    final name = supplier['businessName'] as String? ?? 'Sem nome';
    final category = supplier['category'] as String? ?? '';
    final rating = (supplier['rating'] as num?)?.toDouble() ?? 5.0;
    final photoUrl = supplier['profileImage'] as String?;
    final featuredAt = supplier['featuredAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.peach.withValues(alpha: 0.1),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.peach, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.star, color: AppColors.warning, size: 16),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category),
            if (featuredAt != null)
              Text(
                'Em destaque desde ${_formatDate(featuredAt.toDate())}',
                style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.star, color: AppColors.warning, size: 14),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
              onPressed: () => _removeFeatured(id, name),
              tooltip: 'Remover do destaque',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeFeatured(String supplierId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover do Destaque'),
        content: Text('Remover "$name" dos destaques?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final service = ref.read(adminManagementServiceProvider);
      await service.setSupplierFeatured(
        supplierId: supplierId,
        isFeatured: false,
        adminId: _adminId,
      );
      await _loadStats();
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name removido dos destaques'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _showAddFeaturedSupplierDialog() async {
    final service = ref.read(adminManagementServiceProvider);
    final suppliers = await service.getActiveSuppliers();

    // Filter out already featured suppliers
    final availableSuppliers = suppliers.where((s) {
      final isFeatured = s['isFeatured'] as bool? ?? false;
      return !isFeatured;
    }).toList();

    if (!mounted) return;

    if (availableSuppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos os fornecedores ativos já estão em destaque'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => _SupplierSelectionDialog(
        title: 'Adicionar ao Destaque',
        suppliers: availableSuppliers,
        actionLabel: 'Destacar',
        actionColor: AppColors.warning,
        onSelect: (supplierId, name) async {
          setState(() => _isLoading = true);
          await service.setSupplierFeatured(
            supplierId: supplierId,
            isFeatured: true,
            adminId: _adminId,
          );
          await _loadStats();
          setState(() => _isLoading = false);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$name adicionado aos destaques'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  // ==================== VERIFIED SUPPLIERS TAB ====================

  Widget _buildVerifiedSuppliersTab() {
    final service = ref.watch(adminManagementServiceProvider);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: service.streamVerifiedSuppliers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.peach));
        }

        final suppliers = snapshot.data ?? [];
        final filtered = _searchQuery.isEmpty
            ? suppliers
            : suppliers.where((s) {
                final name =
                    (s['businessName'] as String? ?? '').toLowerCase();
                return name.contains(_searchQuery.toLowerCase());
              }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(
            'Nenhum fornecedor verificado',
            'Verifique fornecedores para conceder o selo de verificação',
            Icons.verified_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.md),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final supplier = filtered[index];
            return _buildVerifiedSupplierCard(supplier);
          },
        );
      },
    );
  }

  Widget _buildVerifiedSupplierCard(Map<String, dynamic> supplier) {
    final id = supplier['id'] as String;
    final name = supplier['businessName'] as String? ?? 'Sem nome';
    final category = supplier['category'] as String? ?? '';
    final photoUrl = supplier['profileImage'] as String?;
    final verifiedAt = supplier['verifiedAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.success.withValues(alpha: 0.1),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.success, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.verified, color: AppColors.info, size: 18),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category),
            if (verifiedAt != null)
              Text(
                'Verificado em ${_formatDate(verifiedAt.toDate())}',
                style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
          onPressed: () => _removeVerification(id, name, isSupplier: true),
          tooltip: 'Remover verificação',
        ),
      ),
    );
  }

  Future<void> _showVerifySupplierDialog() async {
    final service = ref.read(adminManagementServiceProvider);
    final suppliers = await service.getActiveSuppliers();

    // Filter out already verified suppliers
    final availableSuppliers = suppliers.where((s) {
      final isVerified = s['isVerified'] as bool? ?? false;
      return !isVerified;
    }).toList();

    if (!mounted) return;

    if (availableSuppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos os fornecedores ativos já estão verificados'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => _SupplierSelectionDialog(
        title: 'Verificar Fornecedor',
        suppliers: availableSuppliers,
        actionLabel: 'Verificar',
        actionColor: AppColors.success,
        onSelect: (supplierId, name) async {
          setState(() => _isLoading = true);
          await service.verifySupplier(
            supplierId: supplierId,
            isVerified: true,
            adminId: _adminId,
          );
          await _loadStats();
          setState(() => _isLoading = false);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$name foi verificado'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  // ==================== VERIFIED USERS TAB ====================

  Widget _buildVerifiedUsersTab() {
    final service = ref.watch(adminManagementServiceProvider);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: service.streamVerifiedUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.peach));
        }

        final users = snapshot.data ?? [];
        final filtered = _searchQuery.isEmpty
            ? users
            : users.where((u) {
                final name = (u['name'] as String? ?? '').toLowerCase();
                return name.contains(_searchQuery.toLowerCase());
              }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(
            'Nenhum cliente verificado',
            'Verifique clientes para conceder o selo de verificação',
            Icons.person_outline,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.md),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final user = filtered[index];
            return _buildVerifiedUserCard(user);
          },
        );
      },
    );
  }

  Widget _buildVerifiedUserCard(Map<String, dynamic> user) {
    final id = user['id'] as String;
    final name = user['name'] as String? ?? 'Sem nome';
    final email = user['email'] as String? ?? '';
    final photoUrl = user['photoUrl'] as String?;
    final verifiedAt = user['verifiedAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.info.withValues(alpha: 0.1),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.info, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.verified, color: AppColors.info, size: 18),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email),
            if (verifiedAt != null)
              Text(
                'Verificado em ${_formatDate(verifiedAt.toDate())}',
                style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
          onPressed: () => _removeVerification(id, name, isSupplier: false),
          tooltip: 'Remover verificação',
        ),
      ),
    );
  }

  Future<void> _showVerifyUserDialog() async {
    final service = ref.read(adminManagementServiceProvider);
    final users = await service.getUsers(userType: 'client');

    // Filter out already verified users
    final availableUsers = users.where((u) {
      final isVerified = u['isVerified'] as bool? ?? false;
      return !isVerified;
    }).toList();

    if (!mounted) return;

    if (availableUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos os clientes ativos já estão verificados'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => _UserSelectionDialog(
        title: 'Verificar Cliente',
        users: availableUsers,
        onSelect: (userId, name) async {
          setState(() => _isLoading = true);
          await service.verifyUser(
            userId: userId,
            isVerified: true,
            adminId: _adminId,
          );
          await _loadStats();
          setState(() => _isLoading = false);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$name foi verificado'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _removeVerification(String id, String name,
      {required bool isSupplier}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Verificação'),
        content: Text('Remover o selo de verificação de "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final service = ref.read(adminManagementServiceProvider);

      if (isSupplier) {
        await service.verifySupplier(
          supplierId: id,
          isVerified: false,
          adminId: _adminId,
        );
      } else {
        await service.verifyUser(
          userId: id,
          isVerified: false,
          adminId: _adminId,
        );
      }

      await _loadStats();
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verificação de $name removida'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  // ==================== HELPERS ====================

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: AppColors.gray400),
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
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ==================== SELECTION DIALOGS ====================

class _SupplierSelectionDialog extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> suppliers;
  final String actionLabel;
  final Color actionColor;
  final Function(String supplierId, String name) onSelect;

  const _SupplierSelectionDialog({
    required this.title,
    required this.suppliers,
    required this.actionLabel,
    required this.actionColor,
    required this.onSelect,
  });

  @override
  State<_SupplierSelectionDialog> createState() =>
      _SupplierSelectionDialogState();
}

class _SupplierSelectionDialogState extends State<_SupplierSelectionDialog> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? widget.suppliers
        : widget.suppliers.where((s) {
            final name = (s['businessName'] as String? ?? '').toLowerCase();
            final category = (s['category'] as String? ?? '').toLowerCase();
            return name.contains(_searchQuery.toLowerCase()) ||
                category.contains(_searchQuery.toLowerCase());
          }).toList();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar fornecedor...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Nenhum fornecedor encontrado'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final supplier = filtered[index];
                        final id = supplier['id'] as String;
                        final name =
                            supplier['businessName'] as String? ?? 'Sem nome';
                        final category = supplier['category'] as String? ?? '';
                        final photoUrl = supplier['profileImage'] as String?;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: photoUrl != null
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl == null
                                ? Text(name.isNotEmpty ? name[0] : '?')
                                : null,
                          ),
                          title: Text(name),
                          subtitle: Text(category),
                          trailing: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onSelect(id, name);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.actionColor,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(widget.actionLabel),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _UserSelectionDialog extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> users;
  final Function(String userId, String name) onSelect;

  const _UserSelectionDialog({
    required this.title,
    required this.users,
    required this.onSelect,
  });

  @override
  State<_UserSelectionDialog> createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<_UserSelectionDialog> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? widget.users
        : widget.users.where((u) {
            final name = (u['name'] as String? ?? '').toLowerCase();
            final email = (u['email'] as String? ?? '').toLowerCase();
            return name.contains(_searchQuery.toLowerCase()) ||
                email.contains(_searchQuery.toLowerCase());
          }).toList();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar cliente...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Nenhum cliente encontrado'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final user = filtered[index];
                        final id = user['id'] as String;
                        final name = user['name'] as String? ?? 'Sem nome';
                        final email = user['email'] as String? ?? '';
                        final photoUrl = user['photoUrl'] as String?;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: photoUrl != null
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl == null
                                ? Text(name.isNotEmpty ? name[0] : '?')
                                : null,
                          ),
                          title: Text(name),
                          subtitle: Text(email),
                          trailing: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onSelect(id, name);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Verificar'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
