import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/report_model.dart';
import '../../../../core/providers/report_provider.dart';
import '../../../../core/constants/colors.dart';

class SubmitReportScreen extends ConsumerStatefulWidget {
  final String reportedId;
  final String reportedType; // 'client' or 'supplier'
  final String? bookingId;
  final String? reviewId;
  final String? chatId;
  final String reportedName; // Name of person being reported

  const SubmitReportScreen({
    super.key,
    required this.reportedId,
    required this.reportedType,
    this.bookingId,
    this.reviewId,
    this.chatId,
    required this.reportedName,
  });

  @override
  ConsumerState<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends ConsumerState<SubmitReportScreen> {
  ReportCategory? _selectedCategory;
  final _reasonController = TextEditingController();
  final List<({XFile file, Uint8List bytes})> _evidencePhotos = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  List<ReportCategory> get _availableCategories {
    if (widget.reportedType == 'supplier') {
      return ReportCategoryInfo.getSupplierCategories();
    } else {
      return ReportCategoryInfo.getClientCategories();
    }
  }

  Future<void> _pickImage() async {
    if (_evidencePhotos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo de 5 fotos permitidas')),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _evidencePhotos.add((file: pickedFile, bytes: bytes));
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _evidencePhotos.removeAt(index);
    });
  }

  Future<void> _submitReport() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma categoria')),
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, descreva o motivo da denúncia')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Determine reporter type (opposite of reported type)
      final reporterType = widget.reportedType == 'supplier' ? 'client' : 'supplier';

      final notifier = ref.read(reportProvider.notifier);
      final reportId = await notifier.submitReport(
        reporterId: currentUser.uid,
        reporterType: reporterType,
        reportedId: widget.reportedId,
        reportedType: widget.reportedType,
        bookingId: widget.bookingId,
        reviewId: widget.reviewId,
        chatId: widget.chatId,
        category: _selectedCategory!,
        reason: _reasonController.text.trim(),
        evidenceFiles: _evidencePhotos.isEmpty ? null : _evidencePhotos.map((p) => p.file).toList(),
      );

      if (reportId != null && mounted) {
        // Show success message based on severity
        final severity = ReportCategoryInfo.getSuggestedSeverity(_selectedCategory!);
        final message = severity == ReportSeverity.critical
            ? 'Denúncia crítica submetida! Nossa equipe irá investigar imediatamente.'
            : 'Denúncia submetida com sucesso! Iremos analisar e tomar as medidas necessárias.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: severity == ReportSeverity.critical
                ? AppColors.error
                : AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
        context.pop(true); // Return true to indicate success
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao submeter denúncia. Tente novamente.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: AppColors.error,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fazer Denúncia'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning card
            _buildWarningCard(),
            const SizedBox(height: 24),

            // Reported user info
            _buildReportedUserInfo(),
            const SizedBox(height: 24),

            // Category selection
            _buildCategorySection(),
            const SizedBox(height: 24),

            // Reason text field
            _buildReasonSection(),
            const SizedBox(height: 24),

            // Evidence photos
            _buildEvidenceSection(),
            const SizedBox(height: 32),

            // Submit button
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Card(
      color: Colors.orange.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Denúncias Falsas são Levadas a Sério',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Denúncias falsas ou maliciosas podem resultar na suspensão da sua conta.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade800,
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

  Widget _buildReportedUserInfo() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.info.withValues(alpha: 0.1),
              child: Icon(
                widget.reportedType == 'supplier'
                    ? Icons.business
                    : Icons.person,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Denunciando',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.reportedName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.reportedType == 'supplier' ? 'Fornecedor' : 'Cliente',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
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

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categoria da Violação *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._availableCategories.map((category) {
          final isSelected = _selectedCategory == category;
          final severity = ReportCategoryInfo.getSuggestedSeverity(category);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: isSelected ? 3 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected ? AppColors.info : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected ? AppColors.info : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ReportCategoryInfo.getLabel(category),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? AppColors.info : Colors.black87,
                                  ),
                                ),
                              ),
                              _buildSeverityBadge(severity),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ReportCategoryInfo.getDescription(category),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
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
        }),
      ],
    );
  }

  Widget _buildSeverityBadge(ReportSeverity severity) {
    Color color;
    String label;

    switch (severity) {
      case ReportSeverity.critical:
        color = Colors.red;
        label = 'CRÍTICO';
        break;
      case ReportSeverity.high:
        color = Colors.orange;
        label = 'ALTO';
        break;
      case ReportSeverity.medium:
        color = Colors.amber;
        label = 'MÉDIO';
        break;
      case ReportSeverity.low:
        color = Colors.blue;
        label = 'BAIXO';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildReasonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Descrição Detalhada *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Por favor, forneça detalhes específicos sobre o que aconteceu.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reasonController,
          maxLines: 6,
          maxLength: 1000,
          decoration: InputDecoration(
            hintText: 'Descreva o que aconteceu, quando, e qualquer informação relevante...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildEvidenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Evidências (Opcional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Adicione capturas de tela ou fotos que comprovem a violação (máx. 5)',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Add photo button
              if (_evidencePhotos.length < 5)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, color: Colors.grey[400]),
                        const SizedBox(height: 4),
                        Text(
                          'Adicionar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 12),

              // Selected photos
              ..._evidencePhotos.asMap().entries.map((entry) {
                final index = entry.key;
                final photo = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          photo.bytes,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removePhoto(index),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Submeter Denúncia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
