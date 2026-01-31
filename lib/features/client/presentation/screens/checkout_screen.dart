import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/models/package_model.dart';
import '../../../../core/models/booking_model.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/providers/availability_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final PackageModel package;
  final DateTime selectedDate;
  final int guestCount;
  final List<String> selectedCustomizations;
  final int totalPrice;
  final String supplierId;

  const CheckoutScreen({
    super.key,
    required this.package,
    required this.selectedDate,
    required this.guestCount,
    required this.selectedCustomizations,
    required this.totalPrice,
    required this.supplierId,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventNameController = TextEditingController();
  final _eventLocationController = TextEditingController();
  final _eventTimeController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedPaymentMethod = 'bank_transfer';
  bool _isProcessing = false;

  @override
  void dispose() {
    _eventNameController.dispose();
    _eventLocationController.dispose();
    _eventTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Finalizar Reserva'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Package Summary Card
              _buildPackageSummaryCard(),
              const SizedBox(height: AppDimensions.md),

              // Event Details Section
              _buildSectionHeader('Detalhes do Evento'),
              const SizedBox(height: AppDimensions.sm),
              _buildEventDetailsCard(),
              const SizedBox(height: AppDimensions.md),

              // Payment Method Section
              _buildSectionHeader('Método de Pagamento'),
              const SizedBox(height: AppDimensions.sm),
              _buildPaymentMethodCard(),
              const SizedBox(height: AppDimensions.md),

              // Price Breakdown Section
              _buildSectionHeader('Resumo de Preços'),
              const SizedBox(height: AppDimensions.sm),
              _buildPriceBreakdownCard(),
              const SizedBox(height: AppDimensions.md),

              // Notes Section
              _buildSectionHeader('Observações (Opcional)'),
              const SizedBox(height: AppDimensions.sm),
              _buildNotesCard(),
              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
    );
  }

  Widget _buildPackageSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.peach, AppColors.peachDark],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: const Center(
              child: Text('📦', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.package.name,
                  style: AppTextStyles.h4.copyWith(color: AppColors.gray900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(widget.selectedDate)} • ${widget.guestCount} convidados',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _eventNameController,
            decoration: InputDecoration(
              labelText: 'Nome do Evento *',
              hintText: 'Ex: Casamento de João e Maria',
              prefixIcon: const Icon(Icons.event, color: AppColors.peach),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Por favor, insira o nome do evento';
              }
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.md),
          TextFormField(
            controller: _eventLocationController,
            decoration: InputDecoration(
              labelText: 'Local do Evento *',
              hintText: 'Ex: Salão de Festas Central',
              prefixIcon: const Icon(Icons.location_on, color: AppColors.peach),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Por favor, insira o local do evento';
              }
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.md),
          TextFormField(
            controller: _eventTimeController,
            decoration: InputDecoration(
              labelText: 'Hora do Evento *',
              hintText: 'Ex: 18:00',
              prefixIcon: const Icon(Icons.access_time, color: AppColors.peach),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Por favor, insira a hora do evento';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    final paymentMethods = [
      {
        'id': 'bank_transfer',
        'name': 'Transferência Bancária',
        'icon': Icons.account_balance,
        'description': 'Transferir para conta do fornecedor',
      },
      {
        'id': 'cash',
        'name': 'Dinheiro',
        'icon': Icons.money,
        'description': 'Pagamento em dinheiro no local',
      },
      {
        'id': 'mobile_money',
        'name': 'Pagamento Móvel',
        'icon': Icons.phone_android,
        'description': 'Multicaixa Express, EMIS, etc.',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: paymentMethods.map((method) {
          final isSelected = _selectedPaymentMethod == method['id'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPaymentMethod = method['id'] as String;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: AppDimensions.sm),
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.peachLight : AppColors.gray50,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: isSelected ? AppColors.peach : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    method['icon'] as IconData,
                    color: isSelected ? AppColors.peach : AppColors.gray700,
                    size: 28,
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          method['name'] as String,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.peachDark : AppColors.gray900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          method['description'] as String,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.peach,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPriceBreakdownCard() {
    final customizationsPrices = widget.selectedCustomizations.map((name) {
      final customization = widget.package.customizations.firstWhere(
        (c) => c.name == name,
        orElse: () => widget.package.customizations.first,
      );
      return customization.price;
    }).toList();


    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          _buildPriceRow('Pacote Base', widget.package.price),
          if (widget.selectedCustomizations.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            const Divider(),
            const SizedBox(height: AppDimensions.sm),
            ...widget.selectedCustomizations.asMap().entries.map((entry) {
              final index = entry.key;
              final name = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.xs),
                child: _buildPriceRow(
                  '+ $name',
                  customizationsPrices[index],
                  isSubItem: true,
                ),
              );
            }),
          ],
          const SizedBox(height: AppDimensions.sm),
          const Divider(thickness: 2),
          const SizedBox(height: AppDimensions.sm),
          _buildPriceRow(
            'Total',
            widget.totalPrice,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, int price, {bool isSubItem = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? AppTextStyles.h4.copyWith(color: AppColors.gray900)
              : isSubItem
                  ? AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)
                  : AppTextStyles.body.copyWith(color: AppColors.gray900),
        ),
        Text(
          _formatPrice(price),
          style: isTotal
              ? AppTextStyles.h3.copyWith(color: AppColors.peachDark)
              : isSubItem
                  ? AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)
                  : AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray900,
                    ),
        ),
      ],
    );
  }

  Widget _buildNotesCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: AppColors.cardShadow,
      ),
      child: TextFormField(
        controller: _notesController,
        maxLines: 4,
        maxLength: 500,
        decoration: InputDecoration(
          hintText: 'Adicione informações adicionais sobre o evento...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handleConfirmBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.peach,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: AppColors.gray300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                    ),
                  )
                : Text(
                    'Confirmar Reserva',
                    style: AppTextStyles.button.copyWith(color: AppColors.white),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleConfirmBooking() async {
    debugPrint('BEFORE reservation click');
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check blocked dates from real-time provider first
      final blockedDatesAsync = ref.read(supplierBlockedDatesProvider(widget.supplierId));
      final blockedDates = blockedDatesAsync.valueOrNull ?? [];

      if (isDateBlockedForSupplier(blockedDates, widget.selectedDate)) {
        _showDateConflictDialog();
        return;
      }

      final repository = ref.read(bookingRepositoryProvider);

      // Fetch client name from users collection
      final clientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final clientName = clientDoc.data()?['name'] as String? ?? 'Cliente';

      // Fetch supplier name from suppliers collection
      final supplierDoc = await FirebaseFirestore.instance
          .collection('suppliers')
          .doc(widget.supplierId)
          .get();
      final supplierName = supplierDoc.data()?['businessName'] as String? ?? 'Fornecedor';

      final now = DateTime.now();
      final bookingId = const Uuid().v4();

      final booking = BookingModel(
        id: bookingId,
        clientId: currentUser.uid,
        clientName: clientName,
        supplierId: widget.supplierId,
        supplierName: supplierName,
        packageId: widget.package.id,
        packageName: widget.package.name,
        eventName: _eventNameController.text.trim(),
        eventType: null, // Package doesn't have category field
        eventDate: widget.selectedDate,
        eventTime: _eventTimeController.text.trim(),
        eventLocation: _eventLocationController.text.trim(),
        status: BookingStatus.pending,
        totalPrice: widget.totalPrice,
        paidAmount: 0,
        currency: 'AOA',
        selectedCustomizations: widget.selectedCustomizations,
        guestCount: widget.guestCount,
        clientNotes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        createdAt: now,
        updatedAt: now,
      );

      // Create booking
      debugPrint('BEFORE createBooking Cloud Function call');
      await repository.createBooking(booking);
      debugPrint('AFTER createBooking Cloud Function call');

      if (mounted) {
        // Navigate to payment success screen
        context.go('/payment-success', extra: {
          'bookingId': bookingId,
          'paymentMethod': _selectedPaymentMethod,
          'totalAmount': widget.totalPrice,
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ BOOKING ERROR: $e');
      debugPrint('❌ STACK TRACE: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar reserva: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      debugPrint('AFTER reservation click');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showDateConflictDialog() {
    setState(() {
      _isProcessing = false;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.event_busy, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Data Indisponível'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A data selecionada (${_formatDate(widget.selectedDate)}) já não está disponível.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 12),
            Text(
              'Isso pode acontecer porque:',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            _buildConflictReason('O fornecedor bloqueou esta data'),
            _buildConflictReason('Outro cliente acabou de reservar'),
            _buildConflictReason('O limite de reservas foi atingido'),
            const SizedBox(height: 12),
            Text(
              'Por favor, volte e escolha outra data.',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to package detail
            },
            child: const Text('Escolher Outra Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictReason(String reason) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason,
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatPrice(int price) {
    final formatted = price
        .toString()
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '$formatted Kz';
  }
}
