import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/services/presence_service.dart';
import 'package:boda_connect/core/widgets/loading_widget.dart';
import 'package:boda_connect/features/chat/domain/entities/conversation_entity.dart';
import 'package:boda_connect/features/chat/presentation/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsStreamProvider);
    final currentUser = ref.watch(currentUserProvider);

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
          'Mensagens',
          style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
        ),
        centerTitle: true,
      ),
      body: conversationsAsync.when(
        data: (either) => either.fold(
          (failure) => _buildErrorState(context, failure.message),
          (conversations) {
            if (conversations.isEmpty) {
              return _buildEmptyState(context);
            }
            return _buildConversationList(context, ref, conversations, currentUser?.uid);
          },
        ),
        loading: () => const ShimmerListLoading(itemCount: 6, itemHeight: 72),
        error: (error, _) => _buildErrorState(context, error.toString()),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar conversas',
            style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: AppColors.peachLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: AppColors.peach,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Nenhuma conversa ainda',
                style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
              ),
              const SizedBox(height: 8),
              Text(
                'Suas conversas aparecerão aqui',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationList(
    BuildContext context,
    WidgetRef ref,
    List<ConversationEntity> conversations,
    String? currentUserId,
  ) {
    if (currentUserId == null) return _buildEmptyState(context);

    // Sort conversations by last message time (most recent first)
    final sortedConversations = [...conversations]..sort((a, b) {
      final aTime = a.lastMessageAt ?? a.updatedAt;
      final bTime = b.lastMessageAt ?? b.updatedAt;
      return bTime.compareTo(aTime);
    });

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(conversationsStreamProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.md),
        itemCount: sortedConversations.length,
        itemBuilder: (context, index) {
          return _ConversationItem(
            conversation: sortedConversations[index],
            currentUserId: currentUserId,
          );
        },
      ),
    );
  }
}

class _ConversationItem extends ConsumerStatefulWidget {
  const _ConversationItem({
    required this.conversation,
    required this.currentUserId,
  });

  final ConversationEntity conversation;
  final String currentUserId;

  @override
  ConsumerState<_ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends ConsumerState<_ConversationItem> {
  final PresenceService _presenceService = PresenceService();
  UserPresence _otherUserPresence = UserPresence(isOnline: false, lastSeen: null);

  @override
  void initState() {
    super.initState();
    _loadPresence();
  }

  Future<void> _loadPresence() async {
    final otherUserId = _getOtherUserId();
    if (otherUserId != null) {
      final presence = await _presenceService.getUserPresenceOnce(otherUserId);
      if (mounted) {
        setState(() {
          _otherUserPresence = presence;
        });
      }
    }
  }

  String? _getOtherUserId() {
    final conv = widget.conversation;
    if (widget.currentUserId == conv.clientId) {
      return conv.supplierId;
    } else {
      return conv.clientId;
    }
  }

  String _getOtherUserName() {
    final conv = widget.conversation;
    if (widget.currentUserId == conv.clientId) {
      return conv.supplierName ?? 'Fornecedor';
    } else {
      return conv.clientName ?? 'Cliente';
    }
  }

  String? _getOtherUserPhoto() {
    final conv = widget.conversation;
    if (widget.currentUserId == conv.clientId) {
      return conv.supplierPhoto;
    } else {
      return conv.clientPhoto;
    }
  }

  int _getUnreadCount() {
    return widget.conversation.getUnreadCountFor(widget.currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    final otherUserName = _getOtherUserName();
    final otherUserPhoto = _getOtherUserPhoto();
    final otherUserId = _getOtherUserId();
    final unreadCount = _getUnreadCount();
    final isUnread = unreadCount > 0;
    final lastMessageTime = widget.conversation.lastMessageAt ?? widget.conversation.updatedAt;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: AppColors.cardShadow,
        border: isUnread
            ? Border.all(color: AppColors.peach.withValues(alpha: 0.3), width: 2)
            : null,
      ),
      child: InkWell(
        onTap: () {
          context.push(
            '${Routes.chatDetail}?conversationId=${widget.conversation.id}&userId=$otherUserId&userName=${Uri.encodeComponent(otherUserName)}',
          );
        },
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Row(
            children: [
              // Avatar with online indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.peachLight,
                    backgroundImage: otherUserPhoto != null
                        ? NetworkImage(otherUserPhoto)
                        : null,
                    child: otherUserPhoto == null
                        ? Text(
                            _getInitials(otherUserName),
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.peach,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  // Online indicator
                  if (_otherUserPresence.isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppDimensions.md),

              // Chat details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherUserName,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(lastMessageTime),
                          style: AppTextStyles.caption.copyWith(
                            color: isUnread ? AppColors.peach : AppColors.textSecondary,
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.conversation.lastMessage ?? 'Inicie uma conversa',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isUnread ? AppColors.gray900 : AppColors.textSecondary,
                              fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.peach,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(time);
    } else if (messageDate == yesterday) {
      return 'Ontem';
    } else if (now.difference(time).inDays < 7) {
      return DateFormat('EEEE', 'pt_BR').format(time);
    } else {
      return DateFormat('dd/MM/yyyy').format(time);
    }
  }
}
