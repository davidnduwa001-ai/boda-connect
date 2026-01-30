import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/providers/category_provider.dart';
import '../../../../core/providers/supplier_registration_provider.dart';
import '../../../../core/routing/route_names.dart';

/// INDUSTRY-LOCKED CATEGORY SELECTION
///
/// This screen enforces strict industry categorization:
/// 1. Supplier must select ONE primary industry (e.g., Photography)
/// 2. Once selected, only subcategories within that industry are shown
/// 3. Supplier cannot mix categories from different industries
/// 4. This ensures clean search results and prevents "category pollution"
class SupplierServiceTypeScreen extends ConsumerStatefulWidget {
  const SupplierServiceTypeScreen({super.key});

  @override
  ConsumerState<SupplierServiceTypeScreen> createState() => _SupplierServiceTypeScreenState();
}

class _SupplierServiceTypeScreenState extends ConsumerState<SupplierServiceTypeScreen> {
  /// INDUSTRY LOCK: Only ONE primary industry can be selected
  CategoryModel? _selectedIndustry;

  /// Subcategories within the locked industry (can select multiple)
  final Set<String> _selectedSubcategories = {};

  /// Check if user can continue (must select industry + at least 1 subcategory)
  bool get _canContinue =>
      _selectedIndustry != null && _selectedSubcategories.isNotEmpty;

  /// Handle industry selection - LOCKS the supplier to this industry
  void _selectIndustry(CategoryModel industry) {
    setState(() {
      if (_selectedIndustry?.id == industry.id) {
        // Deselect if clicking same industry
        _selectedIndustry = null;
        _selectedSubcategories.clear();
      } else {
        // Lock to new industry and clear previous subcategories
        _selectedIndustry = industry;
        _selectedSubcategories.clear();
      }
    });
  }

  /// Handle subcategory selection within locked industry
  void _toggleSubcategory(String subcategory) {
    setState(() {
      if (_selectedSubcategories.contains(subcategory)) {
        _selectedSubcategories.remove(subcategory);
      } else {
        _selectedSubcategories.add(subcategory);
      }
    });
  }

  /// Save selection and continue
  void _onContinue() {
    if (!_canContinue) return;

    // Save to registration provider with industry tag
    ref.read(supplierRegistrationProvider.notifier).updateServiceType(
      serviceType: _selectedIndustry!.name,
      eventTypes: _selectedSubcategories.toList(),
    );

    context.go(Routes.supplierDescription);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.screenPaddingHorizontal,
              8,
              AppDimensions.screenPaddingHorizontal,
              16,
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
                          value: 0.4,
                          backgroundColor: AppColors.gray200,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.peach),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '40%',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Text(
                  _selectedIndustry == null
                      ? 'Selecione sua Indústria'
                      : 'Indústria: ${_selectedIndustry!.name}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _selectedIndustry == null
                      ? 'Escolha UMA categoria principal para o seu negócio.\nIsso determinará onde você aparecerá nas buscas.'
                      : 'Agora selecione os tipos de serviços que oferece dentro de ${_selectedIndustry!.name}.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                // Industry lock warning
                if (_selectedIndustry != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, color: AppColors.warning, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Indústria bloqueada. Toque na categoria acima para alterar.',
                            style: TextStyle(
                              color: Colors.orange.shade800,
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
          ),

          // Content
          Expanded(
            child: categoriesAsync.when(
              data: (categories) => _buildContent(categories),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.peach),
              ),
              error: (error, _) => _buildContent(getDefaultCategories()),
            ),
          ),

          // Bottom button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.screenPaddingHorizontal),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selection summary
                  if (_selectedIndustry != null && _selectedSubcategories.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_selectedIndustry!.name}: ${_selectedSubcategories.join(", ")}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _canContinue ? _onContinue : null,
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
                      child: Text(
                        _selectedIndustry == null
                            ? 'Selecione uma indústria'
                            : _selectedSubcategories.isEmpty
                                ? 'Selecione pelo menos 1 serviço'
                                : 'Continuar',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<CategoryModel> categories) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.screenPaddingHorizontal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STEP 1: Industry Selection (if not locked)
          if (_selectedIndustry == null) ...[
            ...categories.map((category) => _buildIndustryTile(category)),
          ] else ...[
            // Show locked industry (tappable to change)
            _buildLockedIndustryTile(_selectedIndustry!),

            const SizedBox(height: 24),

            // STEP 2: Subcategory Selection (within locked industry)
            const Text(
              'Tipos de Serviço',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Selecione todos os serviços que você oferece:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),

            // Subcategories from locked industry
            ..._selectedIndustry!.subcategories.map(
              (sub) => _buildSubcategoryTile(sub),
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Build industry tile (for initial selection)
  Widget _buildIndustryTile(CategoryModel category) {
    return GestureDetector(
      onTap: () => _selectIndustry(category),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(category.icon, style: const TextStyle(fontSize: 24)),
              ),
            ),

            const SizedBox(width: 14),

            // Category info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${category.subcategories.length} tipos de serviço',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.gray400,
            ),
          ],
        ),
      ),
    );
  }

  /// Build locked industry tile (shows selected industry with option to change)
  Widget _buildLockedIndustryTile(CategoryModel category) {
    return GestureDetector(
      onTap: () => _selectIndustry(category), // Tap to unlock/change
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: category.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(color: AppColors.peach, width: 2),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(category.icon, style: const TextStyle(fontSize: 24)),
              ),
            ),

            const SizedBox(width: 14),

            // Category info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.peach,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SELECIONADO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Toque para alterar indústria',
                    style: TextStyle(
                      color: Colors.deepOrange.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Lock icon
            Icon(
              Icons.lock_open,
              size: 20,
              color: AppColors.peach,
            ),
          ],
        ),
      ),
    );
  }

  /// Build subcategory tile (for selection within locked industry)
  Widget _buildSubcategoryTile(String subcategory) {
    final isSelected = _selectedSubcategories.contains(subcategory);

    return GestureDetector(
      onTap: () => _toggleSubcategory(subcategory),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.peach.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.peach : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Subcategory icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.peach.withValues(alpha: 0.2)
                    : AppColors.gray100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSelected ? Icons.check : Icons.add,
                color: isSelected ? AppColors.peach : AppColors.gray400,
                size: 18,
              ),
            ),

            const SizedBox(width: 12),

            // Label
            Expanded(
              child: Text(
                subcategory,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            // Checkbox indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.peach : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.peach : AppColors.gray300,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
