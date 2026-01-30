import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/constants/colors.dart';
import '../../../../../core/constants/dimensions.dart';
import '../../../../../core/constants/text_styles.dart';
import '../../../../../core/models/booking_model.dart';
import '../../../../../core/models/report_model.dart';
import '../../../../../core/providers/dispute_provider.dart';

class DisputeDialog extends ConsumerStatefulWidget {
  final BookingModel booking;

  const DisputeDialog({
    super.key,
    required this.booking,
  });

  @override
  ConsumerState<DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends ConsumerState<DisputeDialog> {
  String? _selectedReason;
  final _descriptionController = TextEditingController();
  final List<XFile> _evidencePhotos = [];
  bool _isSubmitting = false;

  final List<Map<String, String>> _disputeReasons = [
    {
      'id': 'service_not_provided',
      'title': 'Serviço não foi prestado',
      'description': 'O fornecedor não compareceu ou não prestou o serviço',
    },
    {
      'id': 'poor_quality',
      'title': 'Qualidade abaixo do esperado',
      'description': 'O serviço não atendeu o padrão prometido',
    },
    {
      'id': 'incomplete_service',
      'title': 'Serviço incompleto',
      'description': 'Nem todos os itens/serviços foram entregues',
    },
    {
      'id': 'late_arrival',
      'title': 'Atraso significativo',
      'description': 'O fornecedor chegou muito atrasado',
    },
    {
      'id': 'damaged_items',
      'title': 'Itens danificados',
      'description': 'Equipamentos ou itens foram danificados',
    },
    {
      'id': 'unprofessional_behavior',
      'title': 'Comportamento não profissional',
      'description': 'Conduta inadequada do fornecedor',
    },
    {
      'id': 'payment_dispute',
      'title': 'Disputa de pagamento',
      'description': 'Cobrança incorreta ou valor diferente do acordado',
    },
    {
      'id': 'other',
      'title': 'Outro motivo',
      'description': 'Motivo não listado acima',
    },
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_evidencePhotos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Máximo de 5 fotos permitido'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _evidencePhotos.add(image);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppDimensions.lg),
              decoration: const BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusLg),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: const Icon(
                      Icons.gavel,
                      color: AppColors.error,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Abrir Disputa',
                          style: AppTextStyles.h3.copyWith(color: AppColors.error),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Descreva o problema com sua reserva',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.gray700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: AppColors.gray700,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Warning
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: AppDimensions.sm),
                          Expanded(
                            child: Text(
                              'Disputas devem ser abertas apenas para problemas legítimos. Nossa equipe analisará ambos os lados.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.warning,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.lg),

                    // Booking Info
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reserva',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.booking.eventName,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: #${widget.booking.id.substring(0, 8).toUpperCase()}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.lg),

                    // Reason Selection
                    Text(
                      'Motivo da Disputa *',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),

                    ..._disputeReasons.map((reason) {
                      final isSelected = _selectedReason == reason['id'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedReason = reason['id'];
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppDimensions.sm),
                          padding: const EdgeInsets.all(AppDimensions.md),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.errorLight : AppColors.white,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            border: Border.all(
                              color: isSelected ? AppColors.error : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: isSelected ? AppColors.error : AppColors.gray400,
                                size: 22,
                              ),
                              const SizedBox(width: AppDimensions.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reason['title']!,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? AppColors.error
                                            : AppColors.gray900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      reason['description']!,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: AppDimensions.lg),

                    // Description
                    Text(
                      'Descrição Detalhada *',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      maxLength: 1000,
                      decoration: InputDecoration(
                        hintText: 'Descreva em detalhes o que aconteceu...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          borderSide: const BorderSide(color: AppColors.error, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.lg),

                    // Evidence Photos
                    Text(
                      'Evidências (Fotos)',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Text(
                      'Adicione fotos que comprovem o problema (máx. 5)',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),

                    // Photos Grid
                    Wrap(
                      spacing: AppDimensions.sm,
                      runSpacing: AppDimensions.sm,
                      children: [
                        // Add Photo Button
                        if (_evidencePhotos.length < 5)
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.gray100,
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                border: Border.all(
                                  color: AppColors.border,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, color: AppColors.gray400),
                                  SizedBox(height: 4),
                                  Text(
                                    'Adicionar',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.gray400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Photo Thumbnails
                        ..._evidencePhotos.asMap().entries.map((entry) {
                          final index = entry.key;
                          return Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.gray200,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Center(
                                  child: Icon(Icons.image, color: AppColors.gray400),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _evidencePhotos.removeAt(index);
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
                                      size: 12,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(AppDimensions.lg),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: AppTextStyles.button.copyWith(
                          color: AppColors.gray700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ||
                              _selectedReason == null ||
                              _descriptionController.text.trim().isEmpty
                          ? null
                          : _submitDispute,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.gray300,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                              ),
                            )
                          : Text(
                              'Abrir Disputa',
                              style: AppTextStyles.button.copyWith(
                                color: AppColors.white,
                              ),
                            ),
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

  Future<void> _submitDispute() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final reporterType =
          currentUser.uid == widget.booking.clientId ? 'client' : 'supplier';
      final params = UserDisputeParams(
        userId: currentUser.uid,
        userType: reporterType,
      );

      // 1. Upload evidence photos to Firebase Storage
      final List<String> evidenceUrls = [];
      if (_evidencePhotos.isNotEmpty) {
        for (int i = 0; i < _evidencePhotos.length; i++) {
          final url = await _uploadEvidencePhoto(_evidencePhotos[i], widget.booking.id, i);
          if (url != null) {
            evidenceUrls.add(url);
          }
        }
      }

      // 2. File dispute via provider/service
      final reasonTitle =
          _disputeReasons.firstWhere((r) => r['id'] == _selectedReason)['title'];
      final category = _mapReasonToCategory(_selectedReason!);
      final severity = ReportCategoryInfo.getSuggestedSeverity(category);

      final disputeId = await ref.read(userDisputesProvider(params).notifier).fileDispute(
            bookingId: widget.booking.id,
            category: category,
            reason: '$reasonTitle: ${_descriptionController.text.trim()}',
            evidenceUrls: evidenceUrls.isEmpty ? null : evidenceUrls,
            severity: severity,
          );

      if (disputeId == null) {
        throw Exception('Failed to open dispute');
      }

      // 3. Send notification to supplier
      await _notifySupplier(disputeId);

      // 4. Send notification to admins
      await _notifyAdmins(disputeId);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disputa aberta com sucesso. Nossa equipe irá analisar.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir disputa: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<String?> _uploadEvidencePhoto(XFile photo, String bookingId, int index) async {
    try {
      final bytes = await photo.readAsBytes();
      final fileName = 'evidence_${index}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('disputes')
          .child(bookingId)
          .child(fileName);

      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading evidence photo: $e');
      return null;
    }
  }

  ReportCategory _mapReasonToCategory(String reason) {
    switch (reason) {
      case 'service_not_provided':
        return ReportCategory.noShow;
      case 'poor_quality':
      case 'damaged_items':
        return ReportCategory.poorQuality;
      case 'incomplete_service':
        return ReportCategory.underdelivery;
      case 'late_arrival':
      case 'unprofessional_behavior':
        return ReportCategory.unprofessional;
      case 'payment_dispute':
        return ReportCategory.overcharging;
      default:
        return ReportCategory.other;
    }
  }

  Future<void> _notifySupplier(String disputeId) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.booking.supplierId,
        'type': 'dispute_opened',
        'title': 'Nova Disputa',
        'body': 'Uma disputa foi aberta para a reserva "${widget.booking.eventName}". '
            'Por favor, verifique e responda.',
        'data': {
          'disputeId': disputeId,
          'bookingId': widget.booking.id,
        },
        'isRead': false,
        'priority': 'high',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error notifying supplier: $e');
    }
  }

  Future<void> _notifyAdmins(String disputeId) async {
    try {
      final adminsQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (final adminDoc in adminsQuery.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': adminDoc.id,
          'type': 'dispute_opened',
          'title': 'Nova Disputa',
          'body': 'Uma nova disputa foi aberta e requer análise. '
              'Motivo: ${_disputeReasons.firstWhere((r) => r['id'] == _selectedReason)['title']}',
          'data': {
            'disputeId': disputeId,
            'bookingId': widget.booking.id,
          },
          'isRead': false,
          'priority': 'high',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error notifying admins: $e');
    }
  }
}
