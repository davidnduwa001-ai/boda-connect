import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/providers/admin_chat_provider.dart';
import '../../../../core/services/admin_chat_service.dart';

class AdminBroadcastScreen extends ConsumerStatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  ConsumerState<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends ConsumerState<AdminBroadcastScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetRole = 'all'; // 'all', 'client', 'supplier'
  BroadcastPriority _priority = BroadcastPriority.normal;
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
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
        title: Text(
          'Enviar Broadcast',
          style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.info),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      'Mensagens broadcast são enviadas para todos os usuários selecionados e aparecem como notificações.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.lg),

            // Title field
            Text('Título *', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppDimensions.sm),
            TextField(
              controller: _titleController,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: 'Ex: Novidades da plataforma',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.md),

            // Message field
            Text('Mensagem *', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppDimensions.sm),
            TextField(
              controller: _messageController,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Escreva sua mensagem aqui...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),

            // Target audience
            Text('Destinatários', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppDimensions.sm),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Todos os usuários'),
                    subtitle: const Text('Clientes e fornecedores'),
                    value: 'all',
                    groupValue: _targetRole,
                    activeColor: AppColors.peach,
                    onChanged: (value) => setState(() => _targetRole = value!),
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: const Text('Apenas clientes'),
                    subtitle: const Text('Usuários que procuram serviços'),
                    value: 'client',
                    groupValue: _targetRole,
                    activeColor: AppColors.peach,
                    onChanged: (value) => setState(() => _targetRole = value!),
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: const Text('Apenas fornecedores'),
                    subtitle: const Text('Prestadores de serviços'),
                    value: 'supplier',
                    groupValue: _targetRole,
                    activeColor: AppColors.peach,
                    onChanged: (value) => setState(() => _targetRole = value!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.lg),

            // Priority
            Text('Prioridade', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppDimensions.sm),
            Wrap(
              spacing: AppDimensions.sm,
              children: BroadcastPriority.values.map((priority) {
                final isSelected = _priority == priority;
                return ChoiceChip(
                  label: Text(_getPriorityLabel(priority)),
                  selected: isSelected,
                  selectedColor: _getPriorityColor(priority).withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? _getPriorityColor(priority) : AppColors.gray700,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _priority = priority);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.xl),

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendBroadcast,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.peach,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                child: _isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                        ),
                      )
                    : const Text('Enviar Broadcast', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: AppDimensions.xl),

            // Recent broadcasts
            Text('Broadcasts Recentes', style: AppTextStyles.h4),
            const SizedBox(height: AppDimensions.md),
            _buildRecentBroadcasts(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentBroadcasts() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(adminChatServiceProvider).getAllBroadcasts(limit: 10),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.peach));
        }

        final broadcasts = snapshot.data ?? [];
        if (broadcasts.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppDimensions.lg),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Center(
              child: Text(
                'Nenhum broadcast enviado ainda',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: broadcasts.length,
          itemBuilder: (context, index) {
            final broadcast = broadcasts[index];
            return _buildBroadcastItem(broadcast);
          },
        );
      },
    );
  }

  Widget _buildBroadcastItem(Map<String, dynamic> broadcast) {
    final title = broadcast['title'] as String? ?? '';
    final message = broadcast['message'] as String? ?? '';
    final targetRole = broadcast['targetRole'] as String?;
    final priority = BroadcastPriority.values.firstWhere(
      (p) => p.name == broadcast['priority'],
      orElse: () => BroadcastPriority.normal,
    );
    final readBy = (broadcast['readBy'] as List<dynamic>?)?.length ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getPriorityColor(priority).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getPriorityLabel(priority),
                  style: AppTextStyles.caption.copyWith(
                    color: _getPriorityColor(priority),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              if (targetRole != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    targetRole == 'client' ? 'Clientes' : 'Fornecedores',
                    style: AppTextStyles.caption.copyWith(color: AppColors.gray700),
                  ),
                ),
              const Spacer(),
              Text(
                '$readBy lido(s)',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            title,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _getPriorityLabel(BroadcastPriority priority) {
    switch (priority) {
      case BroadcastPriority.low:
        return 'Baixa';
      case BroadcastPriority.normal:
        return 'Normal';
      case BroadcastPriority.high:
        return 'Alta';
      case BroadcastPriority.urgent:
        return 'Urgente';
    }
  }

  Color _getPriorityColor(BroadcastPriority priority) {
    switch (priority) {
      case BroadcastPriority.low:
        return AppColors.gray400;
      case BroadcastPriority.normal:
        return AppColors.info;
      case BroadcastPriority.high:
        return AppColors.warning;
      case BroadcastPriority.urgent:
        return AppColors.error;
    }
  }

  Future<void> _sendBroadcast() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, adicione um título'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, adicione uma mensagem'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final notifier = ref.read(adminChatNotifierProvider.notifier);

      final broadcastId = await notifier.sendBroadcast(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        senderId: currentUser?.uid ?? 'admin',
        senderName: currentUser?.displayName ?? 'Admin',
        targetRole: _targetRole == 'all' ? null : _targetRole,
        priority: _priority,
      );

      if (mounted) {
        if (broadcastId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Broadcast enviado com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
          _titleController.clear();
          _messageController.clear();
          setState(() {
            _targetRole = 'all';
            _priority = BroadcastPriority.normal;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao enviar broadcast'),
              backgroundColor: AppColors.error,
            ),
          );
        }
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
        setState(() => _isSending = false);
      }
    }
  }
}
