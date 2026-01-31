import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/models/booking_model.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/providers/booking_provider.dart';
import 'package:boda_connect/features/chat/presentation/providers/chat_provider.dart' as chat;
import 'package:boda_connect/core/providers/favorites_provider.dart';
import 'package:boda_connect/core/providers/navigation_provider.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/services/seed_database_service.dart';
import 'package:boda_connect/core/services/cleanup_database_service.dart';
import 'package:boda_connect/core/services/storage_service.dart';
import 'package:boda_connect/features/client/presentation/widgets/client_bottom_nav.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ClientProfileScreen extends ConsumerStatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  ConsumerState<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends ConsumerState<ClientProfileScreen> {
  bool _isSeeding = false;
  bool _isCleaning = false;
  bool _isUploadingPhoto = false;
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    // Set nav index to profile
    Future.microtask(() {
      ref.read(clientNavIndexProvider.notifier).state = ClientNavTab.profile.tabIndex;
    });
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploadingPhoto = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload photo using storage service
      final photoUrl = await _storageService.uploadProfilePhoto(
        user.uid,
        image,
      );

      // Update Firestore user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update Firebase Auth photo URL
      await user.updatePhotoURL(photoUrl);

      // Refresh auth provider to update UI immediately
      await ref.read(authProvider.notifier).refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil atualizada com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading profile photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar foto: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
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
        title: Text('Meu Perfil',
            style: AppTextStyles.h3.copyWith(color: AppColors.gray900),),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.gray900),
            onPressed: () => context.push(Routes.clientSettings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(context, ref),
            _buildStatsSection(ref),
            _buildMenuSection(context, ref),
            _buildCleanupButton(context),
            const SizedBox(height: AppDimensions.sm),
            _buildSeedButton(context),
            const SizedBox(height: AppDimensions.md),
            _buildLogoutButton(context, ref),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: const ClientBottomNav(),
    );
  }

  Widget _buildProfileHeader(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final rawName = currentUser?.name ?? '';
    final userName = rawName.trim().isNotEmpty ? rawName.trim() : 'Cliente';
    final photoUrl = currentUser?.photoUrl;

    // Build location string from province and city
    final location = currentUser?.location;
    final userLocation = location != null && location.city != null
        ? location.province != null
            ? '${location.city}, ${location.province}'
            : location.city!
        : 'Angola';

    // Safely extract initials with fallback
    final nameParts = userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((n) => n.isNotEmpty)
        .take(2)
        .toList();
    final initials = nameParts.isEmpty
        ? 'C'
        : nameParts.map((n) => n.isNotEmpty ? n[0] : '').join().toUpperCase();

    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        children: [
          Stack(
            children: [
              // Profile photo or initials avatar
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: photoUrl == null || photoUrl.isEmpty
                      ? const LinearGradient(
                          colors: [AppColors.peach, AppColors.peachDark],
                        )
                      : null,
                  shape: BoxShape.circle,
                  image: photoUrl != null && photoUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(photoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: photoUrl == null || photoUrl.isEmpty
                    ? Center(
                        child: Text(
                          initials,
                          style: AppTextStyles.h1.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),
              // Camera button - clickable for photo upload
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingPhoto ? null : _pickAndUploadProfilePhoto,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.peach,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                    child: _isUploadingPhoto
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: AppColors.white,
                            size: 16,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(userName, style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, size: 16, color: AppColors.peach),
              const SizedBox(width: 4),
              Text(userLocation,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.peach.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: AppColors.peach.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, color: AppColors.peach, size: 16),
                const SizedBox(width: AppDimensions.xs),
                Text(
                  'Conta protegida',
                  style: AppTextStyles.caption.copyWith(color: AppColors.peach),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Edit Profile Button
          OutlinedButton.icon(
            onPressed: () => context.push(Routes.clientProfileEdit),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Editar Perfil'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.peach,
              side: const BorderSide(color: AppColors.peach),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(WidgetRef ref) {
    // Get real counts from providers
    final bookings = ref.watch(clientBookingsProvider);
    final favoritesState = ref.watch(favoritesProvider);
    final authState = ref.watch(authProvider);

    // Count bookings (exclude cancelled and rejected)
    final bookingsCount = bookings.where((b) =>
        b.status != BookingStatus.cancelled &&
        b.status != BookingStatus.rejected).length;

    // Count favorites
    final favoritesCount = favoritesState.favoriteSuppliers.length;

    // Client rating (defaults to 5.0 for new users)
    final clientRating = authState.user?.rating ?? 5.0;
    final ratingDisplay = clientRating > 0 ? clientRating.toStringAsFixed(1) : '-';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: Row(
        children: [
          _buildStatCard(
              '$bookingsCount', 'Reservas', Icons.calendar_today, AppColors.peach,),
          const SizedBox(width: AppDimensions.sm),
          _buildStatCard('$favoritesCount', 'Favoritos', Icons.favorite, AppColors.error),
          const SizedBox(width: AppDimensions.sm),
          _buildStatCard(ratingDisplay, 'Nota', Icons.star, AppColors.warning),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String value, String label, IconData icon, Color color,) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),),
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref) {
    // Get unread messages count (real-time)
    final unreadCount = ref.watch(chat.totalUnreadCountProvider);

    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            context,
            icon: Icons.calendar_today_outlined,
            title: 'Minhas Reservas',
            onTap: () => context.push(Routes.clientBookings),
          ),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
            context,
            icon: Icons.favorite_outline,
            title: 'Favoritos',
            onTap: () => context.push(Routes.clientFavorites),
          ),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
            context,
            icon: Icons.chat_bubble_outline,
            title: 'Mensagens',
            badge: unreadCount > 0 ? '$unreadCount' : null,
            onTap: () => context.push(Routes.chatList),
          ),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
            context,
            icon: Icons.credit_card_outlined,
            title: 'Métodos de Pagamento',
            onTap: () => context.push(Routes.paymentMethod),
          ),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
            context,
            icon: Icons.history_outlined,
            title: 'Histórico',
            onTap: () => context.push(Routes.clientHistory),
          ),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notificações',
            onTap: () => context.push(Routes.notifications),
          ),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
            context,
            icon: Icons.help_outline,
            title: 'Ajuda & Suporte',
            onTap: () => context.push(Routes.helpCenter),
          ),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
            context,
            icon: Icons.shield_outlined,
            title: 'Segurança & Privacidade',
            onTap: () => context.push(Routes.securityPrivacy),
          ),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
            context,
            icon: Icons.verified_user_outlined,
            title: 'Pontuação de Segurança',
            onTap: () {
              final userId = ref.read(currentUserProvider)?.uid;
              if (userId != null) {
                context.push(Routes.safetyHistory, extra: userId);
              }
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
            context,
            icon: Icons.description_outlined,
            title: 'Termos de Uso',
            onTap: () => context.push(Routes.terms),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap, String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.peachLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Icon(icon, color: AppColors.peach, size: 20),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Text(title, style: AppTextStyles.body),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.peach,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.white, fontWeight: FontWeight.w600,),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.gray400),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showLogoutDialog(context, ref),
          icon: const Icon(Icons.logout, color: AppColors.error),
          label: Text('Terminar Sessão',
              style: AppTextStyles.button.copyWith(color: AppColors.error),),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSeedButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isSeeding ? null : () => _showSeedDialog(context),
          icon: _isSeeding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_circle_outline, color: AppColors.peach),
          label: Text(
            _isSeeding ? 'Populando Dados...' : 'Popular Base de Dados (Dev)',
            style: AppTextStyles.button.copyWith(color: AppColors.peach),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.peach),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  void _showSeedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Popular Base de Dados?'),
        content: const Text(
          'Isto irá criar dados de teste:\n\n'
          '• 6 Categorias\n'
          '• 5 Fornecedores\n'
          '• 15-20 Pacotes\n'
          '• 20-25 Avaliações\n'
          '• 3 Reservas\n'
          '• 1 Conversa com mensagens\n\n'
          'Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _seedDatabase();
            },
            child: const Text(
              'Popular',
              style: TextStyle(color: AppColors.peach, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _seedDatabase() async {
    setState(() {
      _isSeeding = true;
    });

    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null || currentUser.uid.isEmpty) {
        throw Exception('Usuário não encontrado');
      }

      // Find any existing supplier user in the database to use for testing
      // You need at least one supplier account created before seeding
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'supplier')
          .limit(1)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        throw Exception(
          'Nenhum fornecedor encontrado. Crie uma conta de fornecedor primeiro antes de popular o banco de dados.',
        );
      }

      final existingSupplierId = usersSnapshot.docs.first.id;

      final seedService = SeedDatabaseService();
      await seedService.seedDatabase(
        existingClientId: currentUser.uid,
        existingSupplierId: existingSupplierId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Base de dados populada com sucesso!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao popular: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSeeding = false;
        });
      }
    }
  }

  Widget _buildCleanupButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isCleaning ? null : () => _showCleanupDialog(context),
          icon: _isCleaning
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_sweep, color: AppColors.error),
          label: Text(
            _isCleaning ? 'Limpando...' : 'Limpar Base de Dados (Dev)',
            style: AppTextStyles.button.copyWith(color: AppColors.error),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  void _showCleanupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Base de Dados?'),
        content: const Text(
          'Isto irá DELETAR todos os dados de teste:\n\n'
          '• Fornecedores\n'
          '• Pacotes\n'
          '• Avaliações\n'
          '• Reservas\n'
          '• Conversas e mensagens\n'
          '• Favoritos\n\n'
          '⚠️ Categorias e usuários serão PRESERVADOS.\n\n'
          'Esta ação não pode ser desfeita!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cleanupDatabase();
            },
            child: const Text(
              'Limpar',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cleanupDatabase() async {
    setState(() {
      _isCleaning = true;
    });

    try {
      final cleanupService = CleanupDatabaseService();
      await cleanupService.cleanupTestData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Base de dados limpa com sucesso!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao limpar: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCleaning = false;
        });
      }
    }
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminar Sessão?'),
        content: const Text('Tem certeza que deseja sair da sua conta?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Sign out from Firebase
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                context.go(Routes.welcome);
              }
            },
            child: const Text('Sair', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
