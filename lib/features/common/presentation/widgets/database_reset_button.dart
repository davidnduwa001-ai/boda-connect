import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../scripts/database_manager.dart';

/// Debug button to reset database and seed fresh data
/// SECURITY: Only renders in debug mode - returns empty widget in release
class DatabaseResetButton extends StatefulWidget {
  const DatabaseResetButton({super.key});

  @override
  State<DatabaseResetButton> createState() => _DatabaseResetButtonState();
}

class _DatabaseResetButtonState extends State<DatabaseResetButton> {
  bool _isLoading = false;
  String _status = '';

  Future<void> _showResetConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 12),
            Text('Limpar Base de Dados'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta ação irá:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Apagar TODOS os dados existentes'),
            Text('• Criar novas categorias'),
            Text('• Criar 7 fornecedores de exemplo'),
            Text('• Criar 1 cliente de exemplo'),
            SizedBox(height: 16),
            Text(
              'Esta ação é IRREVERSÍVEL!',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _resetDatabase();
    }
  }

  Future<void> _resetDatabase() async {
    setState(() {
      _isLoading = true;
      _status = 'Limpando dados...';
    });

    try {
      // Clear all data
      setState(() => _status = 'Limpando base de dados...');
      await DatabaseManager.clearAllData();

      // Seed fresh data
      setState(() => _status = 'Criando novos dados...');
      await DatabaseManager.seedFreshData();

      setState(() {
        _status = 'Concluído com sucesso!';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Base de dados reiniciada com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = 'Erro: $e';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reiniciar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _clearOnly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Apenas'),
        content: const Text(
          'Isto irá apagar TODOS os dados sem criar novos. Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
        _status = 'Limpando...';
      });

      try {
        await DatabaseManager.clearAllData();
        setState(() {
          _status = 'Dados limpos!';
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Todos os dados foram apagados'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _status = 'Erro: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _seedOnly() async {
    setState(() {
      _isLoading = true;
      _status = 'Criando dados...';
    });

    try {
      await DatabaseManager.seedFreshData();
      setState(() {
        _status = 'Dados criados!';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados de exemplo criados com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = 'Erro: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // SECURITY: Only render in debug mode - prevents accidental exposure in production
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.developer_mode, color: AppColors.error, size: 20),
              SizedBox(width: 8),
              Text(
                'Ferramentas de Desenvolvimento',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.peach,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(_status, style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          else ...[
            // Reset (Clear + Seed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showResetConfirmation,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Limpar e Criar Novos Dados'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Row with Clear Only and Seed Only
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearOnly,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Limpar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _seedOnly,
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Criar Dados'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: const BorderSide(color: AppColors.success),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (_status.isNotEmpty && !_isLoading) ...[
            const SizedBox(height: 8),
            Text(
              _status,
              style: TextStyle(
                fontSize: 12,
                color: _status.contains('Erro') ? AppColors.error : AppColors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
