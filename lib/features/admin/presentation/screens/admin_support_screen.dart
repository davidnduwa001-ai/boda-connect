import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/models/support_ticket_model.dart';
import '../../../../core/services/support_ticket_service.dart';

/// Provider for support ticket service
final supportTicketServiceProvider = Provider<SupportTicketService>((ref) {
  return SupportTicketService();
});

/// State for admin support tickets
class AdminSupportState {
  final List<SupportTicket> tickets;
  final List<SupportTicket> myTickets;
  final Map<String, int> stats;
  final bool isLoading;
  final String? error;
  final String? processingTicketId;

  const AdminSupportState({
    this.tickets = const [],
    this.myTickets = const [],
    this.stats = const {},
    this.isLoading = false,
    this.error,
    this.processingTicketId,
  });

  AdminSupportState copyWith({
    List<SupportTicket>? tickets,
    List<SupportTicket>? myTickets,
    Map<String, int>? stats,
    bool? isLoading,
    String? error,
    String? processingTicketId,
  }) {
    return AdminSupportState(
      tickets: tickets ?? this.tickets,
      myTickets: myTickets ?? this.myTickets,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      processingTicketId: processingTicketId,
    );
  }
}

/// Provider for admin support state
final adminSupportProvider =
    StateNotifierProvider<AdminSupportNotifier, AdminSupportState>(
  (ref) => AdminSupportNotifier(ref),
);

/// Notifier for admin support operations
class AdminSupportNotifier extends StateNotifier<AdminSupportState> {
  final Ref _ref;

  AdminSupportNotifier(this._ref)
      : super(const AdminSupportState(isLoading: true)) {
    _loadData();
  }

  SupportTicketService get _service => _ref.read(supportTicketServiceProvider);

  Future<void> _loadData() async {
    try {
      final tickets = await _service.getOpenTickets();
      final statsData = await _service.getTicketStats();

      // Convert dynamic map to int map
      final stats = <String, int>{};
      statsData.forEach((key, value) {
        if (value is int) {
          stats[key] = value;
        } else if (value is double) {
          stats[key] = value.toInt();
        }
      });

      state = state.copyWith(
        tickets: tickets,
        stats: stats,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadData();
  }

  Future<void> assignTicket(String ticketId, String adminId, String adminName) async {
    state = state.copyWith(processingTicketId: ticketId);
    try {
      await _service.assignTicket(
        ticketId: ticketId,
        adminId: adminId,
        adminName: adminName,
      );
      await _loadData();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(processingTicketId: null);
    }
  }

  Future<void> updateStatus(String ticketId, TicketStatus status) async {
    state = state.copyWith(processingTicketId: ticketId);
    try {
      await _service.updateTicketStatus(ticketId: ticketId, status: status);
      await _loadData();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(processingTicketId: null);
    }
  }

  Future<void> replyToTicket({
    required String ticketId,
    required String adminId,
    required String adminName,
    required String content,
  }) async {
    try {
      await _service.addMessage(
        ticketId: ticketId,
        senderId: adminId,
        senderName: adminName,
        senderRole: 'admin',
        content: content,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Admin screen for managing support tickets
class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TicketStatus? _statusFilter;
  TicketPriority? _priorityFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminSupportProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Support Tickets'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.peach,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.peach,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Open'),
                  const SizedBox(width: 8),
                  if (state.stats['open'] != null && state.stats['open']! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${state.stats['open']}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            const Tab(text: 'Assigned to Me'),
            const Tab(text: 'All Tickets'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminSupportProvider.notifier).refresh(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.peach))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTicketsList(_filterTickets(state.tickets, openOnly: true)),
                _buildTicketsList(state.myTickets),
                _buildTicketsList(_filterTickets(state.tickets)),
              ],
            ),
    );
  }

  List<SupportTicket> _filterTickets(List<SupportTicket> tickets, {bool openOnly = false}) {
    var filtered = tickets;

    if (openOnly) {
      filtered = filtered.where((t) =>
        t.status != TicketStatus.resolved &&
        t.status != TicketStatus.closed
      ).toList();
    }

    if (_statusFilter != null) {
      filtered = filtered.where((t) => t.status == _statusFilter).toList();
    }

    if (_priorityFilter != null) {
      filtered = filtered.where((t) => t.priority == _priorityFilter).toList();
    }

    // Sort by priority and then by date
    filtered.sort((a, b) {
      final priorityCompare = b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) return priorityCompare;
      return b.createdAt.compareTo(a.createdAt);
    });

    return filtered;
  }

  Widget _buildTicketsList(List<SupportTicket> tickets) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AppColors.gray300),
            const SizedBox(height: 16),
            Text(
              'No tickets found',
              style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: tickets.length,
      itemBuilder: (context, index) => _buildTicketCard(tickets[index]),
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    final state = ref.watch(adminSupportProvider);
    final isProcessing = state.processingTicketId == ticket.id;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: ticket.priority == TicketPriority.urgent
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.border,
          width: ticket.priority == TicketPriority.urgent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              children: [
                // Priority indicator
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getPriorityColor(ticket.priority),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                // Category icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(ticket.category).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(ticket.category),
                    color: _getCategoryColor(ticket.category),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Ticket info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.subject,
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '#${ticket.id.substring(0, 8)}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
                          ),
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: AppColors.gray400)),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(ticket.createdAt),
                            style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status & Priority badges
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusBadge(ticket.status),
                    const SizedBox(height: 4),
                    _buildPriorityBadge(ticket.priority),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Message preview
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Text(
              ticket.description,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // User info
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.gray50,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: AppColors.gray400),
                const SizedBox(width: 8),
                Text(
                  ticket.userName,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                const Spacer(),
                if (ticket.assignedAdminId != null)
                  Row(
                    children: [
                      const Icon(Icons.assignment_ind, size: 16, color: AppColors.peach),
                      const SizedBox(width: 4),
                      Text(
                        ticket.assignedAdminName ?? 'Assigned',
                        style: AppTextStyles.caption.copyWith(color: AppColors.peach),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Actions
          Container(
            padding: const EdgeInsets.all(AppDimensions.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isProcessing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  TextButton.icon(
                    onPressed: () => _viewTicketDetails(ticket),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View'),
                  ),
                  if (ticket.assignedAdminId == null)
                    TextButton.icon(
                      onPressed: () => _assignToMe(ticket.id),
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: const Text('Assign to Me'),
                    ),
                  if (ticket.status != TicketStatus.resolved)
                    TextButton.icon(
                      onPressed: () => _showReplyDialog(ticket),
                      icon: const Icon(Icons.reply_outlined, size: 18),
                      label: const Text('Reply'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.peach),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TicketStatus status) {
    Color color;
    String text;

    switch (status) {
      case TicketStatus.open:
        color = AppColors.error;
        text = 'Open';
        break;
      case TicketStatus.assigned:
        color = Colors.blue;
        text = 'Assigned';
        break;
      case TicketStatus.awaitingUserResponse:
        color = AppColors.warning;
        text = 'Awaiting User';
        break;
      case TicketStatus.inProgress:
        color = AppColors.peach;
        text = 'In Progress';
        break;
      case TicketStatus.resolved:
        color = AppColors.success;
        text = 'Resolved';
        break;
      case TicketStatus.closed:
        color = AppColors.gray400;
        text = 'Closed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPriorityBadge(TicketPriority priority) {
    Color color;
    String text;

    switch (priority) {
      case TicketPriority.low:
        color = AppColors.gray400;
        text = 'Low';
        break;
      case TicketPriority.medium:
        color = Colors.blue;
        text = 'Medium';
        break;
      case TicketPriority.high:
        color = AppColors.warning;
        text = 'High';
        break;
      case TicketPriority.urgent:
        color = AppColors.error;
        text = 'Urgent';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flag, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Color _getPriorityColor(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low:
        return AppColors.gray400;
      case TicketPriority.medium:
        return Colors.blue;
      case TicketPriority.high:
        return AppColors.warning;
      case TicketPriority.urgent:
        return AppColors.error;
    }
  }

  Color _getCategoryColor(TicketCategory category) {
    switch (category) {
      case TicketCategory.accountIssue:
        return Colors.purple;
      case TicketCategory.paymentProblem:
        return Colors.green;
      case TicketCategory.technicalBug:
        return AppColors.error;
      case TicketCategory.featureRequest:
        return Colors.blue;
      case TicketCategory.bookingHelp:
        return AppColors.peach;
      case TicketCategory.verificationHelp:
        return Colors.teal;
      case TicketCategory.general:
        return AppColors.gray400;
    }
  }

  IconData _getCategoryIcon(TicketCategory category) {
    switch (category) {
      case TicketCategory.accountIssue:
        return Icons.person_outline;
      case TicketCategory.paymentProblem:
        return Icons.payment;
      case TicketCategory.technicalBug:
        return Icons.bug_report_outlined;
      case TicketCategory.featureRequest:
        return Icons.lightbulb_outline;
      case TicketCategory.bookingHelp:
        return Icons.calendar_today_outlined;
      case TicketCategory.verificationHelp:
        return Icons.verified_outlined;
      case TicketCategory.general:
        return Icons.help_outline;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(date);
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Tickets'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Status:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _statusFilter == null,
                  onSelected: (selected) {
                    setState(() => _statusFilter = null);
                    Navigator.pop(context);
                  },
                ),
                ...TicketStatus.values.map((status) => FilterChip(
                      label: Text(status.name),
                      selected: _statusFilter == status,
                      onSelected: (selected) {
                        setState(() => _statusFilter = selected ? status : null);
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Priority:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _priorityFilter == null,
                  onSelected: (selected) {
                    setState(() => _priorityFilter = null);
                    Navigator.pop(context);
                  },
                ),
                ...TicketPriority.values.map((priority) => FilterChip(
                      label: Text(priority.name),
                      selected: _priorityFilter == priority,
                      onSelected: (selected) {
                        setState(() => _priorityFilter = selected ? priority : null);
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _statusFilter = null;
                _priorityFilter = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignToMe(String ticketId) async {
    const adminId = 'admin_user'; // Get from auth in real app
    const adminName = 'Admin'; // Get from auth in real app
    await ref.read(adminSupportProvider.notifier).assignTicket(ticketId, adminId, adminName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket assigned to you'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _viewTicketDetails(SupportTicket ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TicketDetailScreen(ticket: ticket),
      ),
    );
  }

  void _showReplyDialog(SupportTicket ticket) {
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reply to #${ticket.id.substring(0, 8)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Type your reply...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (messageController.text.isNotEmpty) {
                const adminId = 'admin_user';
                const adminName = 'Admin';
                await ref.read(adminSupportProvider.notifier).replyToTicket(
                      ticketId: ticket.id,
                      adminId: adminId,
                      adminName: adminName,
                      content: messageController.text,
                    );
                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.peach,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

/// Ticket detail screen
class _TicketDetailScreen extends ConsumerStatefulWidget {
  final SupportTicket ticket;

  const _TicketDetailScreen({required this.ticket});

  @override
  ConsumerState<_TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<_TicketDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text('#${widget.ticket.id.substring(0, 8)}'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          PopupMenuButton<TicketStatus>(
            icon: const Icon(Icons.more_vert),
            onSelected: (status) async {
              await ref.read(adminSupportProvider.notifier).updateStatus(
                    widget.ticket.id,
                    status,
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Status updated to ${status.name}')),
                );
              }
            },
            itemBuilder: (context) => TicketStatus.values
                .map((status) => PopupMenuItem(
                      value: status,
                      child: Text('Mark as ${status.name}'),
                    ))
                .toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Ticket info header
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ticket.subject,
                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.ticket.description,
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      label: Text(widget.ticket.category.name),
                      backgroundColor: AppColors.gray100,
                    ),
                    Chip(
                      label: Text(widget.ticket.priority.name),
                      backgroundColor: AppColors.warning.withValues(alpha: 0.1),
                    ),
                    Chip(
                      label: Text(widget.ticket.status.name),
                      backgroundColor: AppColors.peach.withValues(alpha: 0.1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Messages
          Expanded(
            child: StreamBuilder<List<TicketMessage>>(
              stream: ref
                  .read(supportTicketServiceProvider)
                  .streamTicketMessages(widget.ticket.id, includeInternal: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppDimensions.md),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isAdmin = message.senderRole == 'admin';

                    return Align(
                      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isAdmin ? AppColors.peach : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.content,
                              style: TextStyle(
                                color: isAdmin ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM dd, HH:mm').format(message.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: isAdmin
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : AppColors.gray400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Message input
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: AppColors.peach,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    const adminId = 'admin_user';
    const adminName = 'Admin';
    await ref.read(adminSupportProvider.notifier).replyToTicket(
          ticketId: widget.ticket.id,
          adminId: adminId,
          adminName: adminName,
          content: _messageController.text,
        );

    _messageController.clear();
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}
