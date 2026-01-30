import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/models/package_model.dart';
import 'package:boda_connect/core/models/cart_model.dart';
import 'package:boda_connect/core/models/supplier_model.dart';
import 'package:boda_connect/core/providers/cart_provider.dart';
import 'package:boda_connect/core/providers/availability_provider.dart';
import 'package:boda_connect/core/providers/supplier_provider.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/features/client/presentation/screens/checkout_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

/// Provider for fetching a package by ID (for reload-safety on web)
final packageByIdProvider = FutureProvider.family<PackageModel?, String>((ref, packageId) async {
  if (packageId.isEmpty) return null;
  try {
    final doc = await FirebaseFirestore.instance
        .collection('packages')
        .doc(packageId)
        .get();
    if (!doc.exists) return null;
    return PackageModel.fromFirestore(doc);
  } catch (e) {
    debugPrint('Error fetching package by ID: $e');
    return null;
  }
});

class ClientPackageDetailScreen extends ConsumerStatefulWidget {
  const ClientPackageDetailScreen({
    super.key,
    this.packageModel,
    this.packageId,
  });
  final PackageModel? packageModel;
  final String? packageId; // For reload-safety: fetch by ID if packageModel is null

  @override
  ConsumerState<ClientPackageDetailScreen> createState() => _ClientPackageDetailScreenState();
}

class _ClientPackageDetailScreenState extends ConsumerState<ClientPackageDetailScreen> {
  DateTime? _selectedDate;
  int _guestCount = 100;
  final Set<int> _selectedCustomizations = {};

  @override
  Widget build(BuildContext context) {
    // If packageModel is provided, use it directly
    // Otherwise, fetch by packageId for web reload-safety
    if (widget.packageModel != null) {
      return _buildScaffoldWithPackage(widget.packageModel!);
    }

    // Fetch package by ID
    final packageId = widget.packageId ?? '';
    if (packageId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Pacote não encontrado'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(Routes.clientHome),
                child: const Text('Voltar ao início'),
              ),
            ],
          ),
        ),
      );
    }

    final packageAsync = ref.watch(packageByIdProvider(packageId));

    return packageAsync.when(
      data: (package) {
        if (package == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Erro')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pacote não encontrado'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go(Routes.clientHome),
                    child: const Text('Voltar ao início'),
                  ),
                ],
              ),
            ),
          );
        }
        return _buildScaffoldWithPackage(package);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Erro ao carregar pacote: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(Routes.clientHome),
                child: const Text('Voltar ao início'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScaffoldWithPackage(PackageModel package) {

    // Preload blocked dates for this supplier
    ref.watch(supplierBlockedDatesProvider(package.supplierId));

    // Fetch supplier to check eligibility
    final supplierAsync = ref.watch(supplierDetailProvider(package.supplierId));
    final supplier = supplierAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(package),
          SliverToBoxAdapter(child: _buildContentColumn(package)),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(package, supplier),
    );
  }

  Widget _buildAppBar(PackageModel package) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.peach,
      leading: GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: AppColors.gray900),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () => _sharePackage(package),
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share_outlined, color: AppColors.gray900, size: 20),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.peach, AppColors.peachDark],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Text('📦', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                Text(
                  package.name,
                  style: AppTextStyles.h2.copyWith(color: AppColors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentColumn(PackageModel package) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description Card
        Container(
          margin: const EdgeInsets.all(AppDimensions.md),
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                package.description,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              const Divider(),
              const SizedBox(height: AppDimensions.sm),
              Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                children: [
                  _buildInfoChip(Icons.access_time, package.duration),
                  _buildInfoChip(Icons.monetization_on_outlined, package.formattedPrice),
                  if (package.bookingCount > 0)
                    _buildInfoChip(Icons.people_outline, '${package.bookingCount} reservas'),
                ],
              ),
            ],
          ),
        ),

        // Included Services
        if (package.includes.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(AppDimensions.md),
            child: Text('Serviços Incluídos', style: AppTextStyles.h3),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: package.includes.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 20, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: AppTextStyles.body.copyWith(color: AppColors.gray900),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
        ],

        // Select Date & Guests
        Container(
          margin: const EdgeInsets.all(AppDimensions.md),
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Detalhes da Reserva', style: AppTextStyles.h3),
              const SizedBox(height: AppDimensions.md),

              // Date Picker
              GestureDetector(
                onTap: () async {
                  // Fetch blocked dates for this supplier
                  final blockedDatesAsync = ref.read(supplierBlockedDatesProvider(package.supplierId));
                  final blockedDates = blockedDatesAsync.valueOrNull ?? [];

                  final date = await showDatePicker(
                    context: context,
                    initialDate: _findNextAvailableDate(
                      DateTime.now().add(const Duration(days: 30)),
                      blockedDates,
                    ),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    selectableDayPredicate: (DateTime day) {
                      // Disable blocked dates
                      return !isDateBlockedForSupplier(blockedDates, day);
                    },
                    helpText: 'Selecione a data do evento',
                    cancelText: 'Cancelar',
                    confirmText: 'Confirmar',
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: AppColors.peach),
                      const SizedBox(width: AppDimensions.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Data do Evento', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                          Text(
                            _selectedDate != null
                                ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                : 'Selecionar data',
                            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: AppColors.gray400),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.md),

              // Guest Count
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline, color: AppColors.peach),
                    const SizedBox(width: AppDimensions.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Número de Convidados', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                        Text('$_guestCount pessoas', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        if (_guestCount > 20) {
                          setState(() => _guestCount -= 10);
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.peach),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() => _guestCount += 10);
                      },
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.peach),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Optional Customizations
        if (package.customizations.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.md),
            child: Text('Personalizações Disponíveis', style: AppTextStyles.h3),
          ),
          const SizedBox(height: AppDimensions.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
            child: Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: List.generate(package.customizations.length, (index) {
                final customization = package.customizations[index];
                final isSelected = _selectedCustomizations.contains(index);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedCustomizations.remove(index);
                      } else {
                        _selectedCustomizations.add(index);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.peachLight : AppColors.white,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(
                        color: isSelected ? AppColors.peach : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_circle_outline, size: 20, color: AppColors.peach),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customization.name,
                              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '+${_formatPrice(customization.price)}',
                              style: AppTextStyles.caption.copyWith(color: AppColors.peachDark),
                            ),
                          ],
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle, size: 18, color: AppColors.peach),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],

        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gray700),
          const SizedBox(width: 4),
          Text(text, style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildBottomBar(PackageModel package, SupplierModel? supplier) {
    int customizationsTotal = 0;
    for (final index in _selectedCustomizations) {
      customizationsTotal += package.customizations[index].price;
    }

    final totalPrice = package.price + customizationsTotal;

    // Check if supplier is eligible for bookings
    final isEligible = supplier?.isEligibleForBookings ?? false;
    final canBook = _selectedDate != null && isEligible;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show message if supplier is not eligible
            if (!isEligible && supplier != null) ...[
              Container(
                padding: const EdgeInsets.all(AppDimensions.sm),
                margin: const EdgeInsets.only(bottom: AppDimensions.sm),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                    const SizedBox(width: AppDimensions.xs),
                    Expanded(
                      child: Text(
                        'Este fornecedor não está a aceitar reservas de momento.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.gray700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    Text(_formatPrice(totalPrice), style: AppTextStyles.h2.copyWith(color: AppColors.peachDark)),
                  ],
                ),
                const SizedBox(width: AppDimensions.sm),
                // Add to Cart Button
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: canBook ? () => _addToCart(package, totalPrice, customizationsTotal) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.peach,
                      side: const BorderSide(color: AppColors.peach, width: 2),
                      disabledForegroundColor: AppColors.gray400,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                    ),
                    child: const Icon(Icons.shopping_cart_outlined, size: 24),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                // Reserve Button
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: canBook ? () => _navigateToCheckout(context, package) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.peach,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.gray300,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                      ),
                      child: Text('Reservar', style: AppTextStyles.button.copyWith(color: AppColors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCheckout(BuildContext context, PackageModel package) {
    // Calculate selected customizations names
    final selectedCustomizationNames = _selectedCustomizations
        .map((index) => package.customizations[index].name)
        .toList();

    // Calculate total price
    int customizationsTotal = 0;
    for (final index in _selectedCustomizations) {
      customizationsTotal += package.customizations[index].price;
    }
    final totalPrice = package.price + customizationsTotal;

    // Navigate to checkout with all required data
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          package: package,
          selectedDate: _selectedDate!,
          guestCount: _guestCount,
          selectedCustomizations: selectedCustomizationNames,
          totalPrice: totalPrice,
          supplierId: package.supplierId,
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    final formatted = price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '$formatted Kz';
  }

  /// Find the next available date starting from the given date
  /// Skips blocked dates to ensure the initial date is selectable
  DateTime _findNextAvailableDate(DateTime startDate, List<DateTime> blockedDates) {
    DateTime candidate = startDate;
    final maxDate = DateTime.now().add(const Duration(days: 365));

    while (isDateBlockedForSupplier(blockedDates, candidate) && candidate.isBefore(maxDate)) {
      candidate = candidate.add(const Duration(days: 1));
    }

    return candidate;
  }

  void _sharePackage(PackageModel package) {
    final text = '''
🎉 Confira este pacote incrível!

📦 ${package.name}
💰 Preço: ${_formatPrice(package.price)}
⏱️ Duração: ${package.duration}

📋 Descrição:
${package.description}

${package.includes.isNotEmpty ? '✅ Inclui:\n${package.includes.map((item) => '• $item').join('\n')}\n' : ''}
${package.bookingCount > 0 ? '⭐ ${package.bookingCount} reservas realizadas\n' : ''}
📱 Baixe o Boda Connect e faça sua reserva!
''';

    Share.share(
      text,
      subject: 'Pacote: ${package.name}',
    );
  }

  Future<void> _addToCart(PackageModel package, int totalPrice, int customizationsTotal) async {
    if (_selectedDate == null) return;

    try {
      // Fetch supplier name from Firestore
      String supplierName = 'Fornecedor';
      try {
        final supplierDoc = await FirebaseFirestore.instance
            .collection('suppliers')
            .doc(package.supplierId)
            .get();

        if (supplierDoc.exists) {
          final data = supplierDoc.data();
          supplierName = data?['businessName'] as String? ?? 'Fornecedor';
        }
      } catch (e) {
        print('Error fetching supplier name: $e');
      }

      // Calculate selected customizations names
      final selectedCustomizationNames = _selectedCustomizations
          .map((index) => package.customizations[index].name)
          .toList();

      // Create cart item
      final cartItem = CartItem(
        id: '', // Will be set by Firestore
        packageId: package.id,
        packageName: package.name,
        supplierId: package.supplierId,
        supplierName: supplierName,
        selectedDate: _selectedDate!,
        guestCount: _guestCount,
        selectedCustomizations: selectedCustomizationNames,
        basePrice: package.price,
        customizationsPrice: customizationsTotal,
        totalPrice: totalPrice,
        packageImage: package.photos.isNotEmpty ? package.photos.first : null,
        addedAt: DateTime.now(),
      );

      final repository = ref.read(cartRepositoryProvider);
      await repository.addToCart(cartItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Pacote adicionado ao carrinho'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Ver Carrinho',
              textColor: AppColors.white,
              onPressed: () => context.push(Routes.clientCart),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar ao carrinho: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
