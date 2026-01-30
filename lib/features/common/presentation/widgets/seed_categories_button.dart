import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/scripts/seed_categories.dart';
import 'package:flutter/material.dart';

/// Debug button to seed categories to Firestore
/// Add this to any screen during development to populate categories
class SeedCategoriesButton extends StatefulWidget {
  const SeedCategoriesButton({super.key});

  @override
  State<SeedCategoriesButton> createState() => _SeedCategoriesButtonState();
}

class _SeedCategoriesButtonState extends State<SeedCategoriesButton> {
  bool _isSeeding = false;
  String? _message;

  Future<void> _seedCategories() async {
    setState(() {
      _isSeeding = true;
      _message = null;
    });

    try {
      // Check if categories already exist
      final exists = await SeedCategories.categoriesExist();

      if (exists && mounted) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Categorias Existem'),
            content: const Text(
              'As categorias já existem no Firestore. Deseja sobrescrevê-las?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );

        if (shouldContinue != true) {
          setState(() {
            _isSeeding = false;
            _message = 'Cancelado pelo usuário';
          });
          return;
        }
      }

      // Seed categories
      await SeedCategories.seedToFirestore();

      // Update supplier counts
      await SeedCategories.updateAllSupplierCounts();

      setState(() {
        _isSeeding = false;
        _message = '✅ Categorias criadas com sucesso!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Categorias criadas com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSeeding = false;
        _message = '❌ Erro: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao criar categorias: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: _isSeeding ? null : _seedCategories,
          icon: _isSeeding
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : const Icon(Icons.cloud_upload),
          label: Text(_isSeeding ? 'Criando...' : 'Seed Categories'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.peach,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            style: TextStyle(
              fontSize: 12,
              color: _message!.startsWith('✅')
                  ? AppColors.success
                  : AppColors.error,
            ),
          ),
        ],
      ],
    );
  }
}
