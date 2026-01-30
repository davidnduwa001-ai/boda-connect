import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/routing/route_names.dart';

class SupplierServiceDescriptionScreen extends StatefulWidget {
  const SupplierServiceDescriptionScreen({super.key});

  @override
  State<SupplierServiceDescriptionScreen> createState() =>
      _SupplierServiceDescriptionScreenState();
}

class _SupplierServiceDescriptionScreenState
    extends State<SupplierServiceDescriptionScreen> {
  final TextEditingController _controller = TextEditingController();
  static const int _minChars = 50;
  static const int _maxChars = 500;

  // ValueNotifiers to avoid full rebuilds on every keystroke
  final _currentLengthNotifier = ValueNotifier<int>(0);
  final _canContinueNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _currentLengthNotifier.value = _controller.text.length;
    _canContinueNotifier.value = _controller.text.length >= _minChars;
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _currentLengthNotifier.dispose();
    _canContinueNotifier.dispose();
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
                      value: 0.6,
                      backgroundColor: AppColors.gray200,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.peach),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '60%',
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
              'Descrição do Serviço',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'Conte aos clientes sobre o seu trabalho',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 24),

            // Label
            const Text(
              'Descreva o seu serviço',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 8),

            // Text area
            TextField(
              controller: _controller,
              maxLines: 6,
              maxLength: _maxChars,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText:
                    'Fale sobre sua experiência, tipos de eventos que realiza e o que o diferencia.',
                hintStyle: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 15,
                ),
                filled: true,
                fillColor: AppColors.gray50,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                  borderSide: const BorderSide(
                    color: AppColors.peach,
                    width: 2,
                  ),
                ),
                counterText: '',
              ),
            ),

            const SizedBox(height: 8),

            // Character counter - uses ValueListenableBuilder to avoid full rebuilds
            ValueListenableBuilder<int>(
              valueListenable: _currentLengthNotifier,
              builder: (context, currentLength, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      currentLength < _minChars
                          ? 'Mínimo $_minChars caracteres'
                          : '✓ Mínimo atingido',
                      style: TextStyle(
                        fontSize: 12,
                        color: currentLength < _minChars
                            ? AppColors.textSecondary
                            : AppColors.success,
                        fontWeight: currentLength >= _minChars
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                    Text(
                      '$currentLength / $_maxChars',
                      style: TextStyle(
                        fontSize: 12,
                        color: currentLength > _maxChars * 0.9
                            ? AppColors.warning
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Tip box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: AppColors.info,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dica',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.info,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Uma boa descrição aumenta suas chances de receber pedidos. Mencione sua experiência, especialidades e diferenciais.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Continue button - uses ValueListenableBuilder to avoid full rebuilds
            ValueListenableBuilder<bool>(
              valueListenable: _canContinueNotifier,
              builder: (context, canContinue, child) {
                return SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: canContinue
                        ? () => context.go(Routes.supplierUpload)
                        : null,
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
                    child: const Text(
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
}
