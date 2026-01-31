import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/models/notification_model.dart';
import '../../../../core/providers/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Load notifications when screen opens
    Future.microtask(() => ref.read(notificationProvider.notifier).loadNotifications());
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Agora mesmo';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return 'Há $minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'Há $hours ${hours == 1 ? 'hora' : 'horas'}';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return 'Há $days ${days == 1 ? 'dia' : 'dias'}';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Há $weeks ${weeks == 1 ? 'semana' : 'semanas'}';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationProvider);
    final notifications = notificationState.notifications;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (notifications.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'mark_all_read') {
                  ref.read(notificationProvider.notifier).markAllAsRead();
                } else if (value == 'delete_all') {
                  _showDeleteAllDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'mark_all_read',
                  child: Row(
                    children: [
                      Icon(Icons.done_all, size: 20),
                      SizedBox(width: 8),
                      Text('Marcar todas como lidas'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, size: 20),
                      SizedBox(width: 8),
                      Text('Eliminar todas'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: notificationState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(notificationProvider.notifier).loadNotifications();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppDimensions.md),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.sm),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _buildNotificationCard(notification);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Sem notificações',
            style: AppTextStyles.h3.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Você não tem notificações no momento',
            style: AppTextStyles.body.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        ref.read(notificationProvider.notifier).deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificação eliminada')),
        );
      },
      child: InkWell(
        onTap: () {
          if (!notification.isRead) {
            ref.read(notificationProvider.notifier).markAsRead(notification.id);
          }
          _handleNotificationTap(notification);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: notification.isRead ? Colors.white : AppColors.peach.withAlpha((0.05 * 255).toInt()),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notification.isRead ? Colors.grey.shade200 : AppColors.peach.withAlpha((0.2 * 255).toInt()),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getNotificationColor(notification.type).withAlpha((0.1 * 255).toInt()),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationColor(notification.type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.peach,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTimeAgo(notification.createdAt),
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.grey.shade500,
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
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case NotificationType.newBooking:
        return Icons.calendar_today;
      case NotificationType.bookingConfirmed:
        return Icons.check_circle;
      case NotificationType.bookingCancelled:
        return Icons.cancel;
      case NotificationType.newMessage:
        return Icons.message;
      case NotificationType.newReview:
        return Icons.star;
      case NotificationType.paymentReceived:
        return Icons.payment;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case NotificationType.newBooking:
        return Colors.blue;
      case NotificationType.bookingConfirmed:
        return Colors.green;
      case NotificationType.bookingCancelled:
        return Colors.red;
      case NotificationType.newMessage:
        return Colors.purple;
      case NotificationType.newReview:
        return Colors.orange;
      case NotificationType.paymentReceived:
        return Colors.teal;
      default:
        return AppColors.peach;
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Navigate based on notification type
    switch (notification.type) {
      case NotificationType.newBooking:
      case NotificationType.bookingConfirmed:
      case NotificationType.bookingCancelled:
        // Navigate to booking detail if bookingId is available
        final bookingId = notification.data?['bookingId'] as String?;
        if (bookingId != null) {
          context.push('/supplier-order-detail', extra: bookingId);
        } else {
          context.push('/supplier-orders');
        }
        break;
      case NotificationType.newMessage:
        // Navigate to chat
        final chatId = notification.data?['chatId'] as String?;
        final senderId = notification.data?['senderId'] as String?;
        final senderName = notification.data?['senderName'] as String? ?? 'Usuário';
        if (chatId != null) {
          final encodedName = Uri.encodeComponent(senderName);
          context.push('/chat-detail?conversationId=$chatId&userId=$senderId&userName=$encodedName');
        } else {
          context.push('/chat-list');
        }
        break;
      case NotificationType.newReview:
        // Navigate to reviews
        context.push('/supplier-reviews');
        break;
      case NotificationType.paymentReceived:
        // Navigate to revenue screen
        context.push('/supplier-revenue');
        break;
      default:
        break;
    }
  }

  void _showDeleteAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar todas as notificações?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(notificationProvider.notifier).deleteAll();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
