import 'dart:async';
import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/services/category_stats_service.dart';
import 'package:boda_connect/core/services/platform_settings_service.dart';
import 'package:boda_connect/core/services/supplier_onboarding_service.dart';
import 'package:boda_connect/core/services/admin_chat_service.dart';
import 'package:boda_connect/core/providers/admin_chat_provider.dart';
import 'package:boda_connect/features/admin/presentation/widgets/supplier_eligibility_cards.dart';
import 'package:boda_connect/features/admin/presentation/widgets/rate_limit_dashboard.dart';
import 'package:boda_connect/features/admin/presentation/widgets/identity_verification_panel.dart';
import 'package:boda_connect/core/utils/eligibility_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Comprehensive Admin Dashboard for BODA CONNECT
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _notifications = [];
  final _categoryStatsService = CategoryStatsService();
  final _platformSettingsService = PlatformSettingsService();
  bool _isRefreshingCategoryCounts = false;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;

  // Settings values
  double _platformCommission = 10.0;
  bool _maintenanceMode = false;
  bool _newRegistrations = true;
  String _supportEmail = 'support@bodaconnect.ao';
  String _supportPhone = '+244 923 456 789';
  String _supportWhatsApp = '+244923456789';

  // Notification settings
  bool _notifyNewBookings = true;
  bool _notifyNewDisputes = true;
  bool _notifyNewAppeals = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationsFromFirestore();
    _loadSettings();
  }

  /// Load admin notifications from Firestore in real-time
  void _loadNotificationsFromFirestore() {
    _notificationsSubscription = FirebaseFirestore.instance
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _notifications = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'title': data['title'] as String? ?? 'Notification',
              'message': data['message'] as String? ?? '',
              'type': data['type'] as String? ?? 'info',
              'time': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              'read': data['read'] as bool? ?? false,
              'data': data['data'] as Map<String, dynamic>?,
            };
          }).toList();
        });
      }
    }, onError: (e) {
      // Permission denied is expected if Firestore rules aren't configured for admin
      // Only log other errors
      if (!e.toString().contains('permission-denied')) {
        debugPrint('❌ Error loading admin notifications: $e');
      }
      // Fallback to empty list
      if (mounted) {
        setState(() => _notifications = []);
      }
    });
  }

  /// Mark notification as read
  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('admin_notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      // Silently handle permission errors
      if (!e.toString().contains('permission-denied')) {
        debugPrint('❌ Error marking notification as read: $e');
      }
    }
  }

  /// Mark all notifications as read
  Future<void> _markAllNotificationsAsRead() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final notification in _notifications) {
        if (notification['read'] == false) {
          final docRef = FirebaseFirestore.instance
              .collection('admin_notifications')
              .doc(notification['id'] as String);
          batch.update(docRef, {'read': true});
        }
      }
      await batch.commit();
    } catch (e) {
      // Silently handle permission errors
      if (!e.toString().contains('permission-denied')) {
        debugPrint('❌ Error marking all notifications as read: $e');
      }
    }
  }

  void _loadSettings() async {
    try {
      // Load from platform settings service (dynamic)
      final settings = await _platformSettingsService.getSettings();

      if (mounted) {
        setState(() {
          _platformCommission = settings.platformCommission;
          _maintenanceMode = settings.maintenanceMode;
          _newRegistrations = settings.allowNewRegistrations;
          _supportEmail = settings.supportEmail;
          _supportPhone = settings.supportPhone;
          _supportWhatsApp = settings.supportWhatsApp;
        });
      }
    } catch (e) {
      // Silently handle permission errors - use defaults
      if (!e.toString().contains('permission-denied')) {
        debugPrint('❌ Error loading settings: $e');
      }
    }
  }

  /// Save settings to Firestore
  Future<void> _saveSettings() async {
    try {
      await _platformSettingsService.updateSupportContact(
        email: _supportEmail,
        phone: _supportPhone,
        whatsApp: _supportWhatsApp,
      );
      await _platformSettingsService.updateCommission(_platformCommission);
      await _platformSettingsService.updateMaintenanceMode(_maintenanceMode);
      await _platformSettingsService.updateRegistrationSettings(
        allowNewRegistrations: _newRegistrations,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações salvas com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar configurações: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Row(
        children: [
          if (isWideScreen) _buildSideNav(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isWideScreen),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWideScreen ? null : _buildBottomNav(),
    );
  }

  Widget _buildSideNav() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/boda_logo.png',
                    width: 45,
                    height: 45,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.peach, AppColors.peachDark]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.celebration, color: Colors.white, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BODA CONNECT', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    Text('Admin Panel', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
                _buildNavItem(1, Icons.people_outline, Icons.people, 'Users'),
                _buildNavItem(2, Icons.store_outlined, Icons.store, 'Suppliers'),
                _buildNavItemWithBadge(3, Icons.verified_user_outlined, Icons.verified_user, 'Onboarding Queue'),
                _buildNavItem(4, Icons.calendar_today_outlined, Icons.calendar_today, 'Bookings'),
                _buildNavItem(5, Icons.receipt_long_outlined, Icons.receipt_long, 'Transactions'),
                _buildNavItem(6, Icons.report_problem_outlined, Icons.report_problem, 'Disputes'),
                _buildNavItem(7, Icons.warning_amber_outlined, Icons.warning_amber, 'Violations'),
                _buildNavItem(8, Icons.gavel_outlined, Icons.gavel, 'Appeals'),
                _buildNavItem(9, Icons.block_outlined, Icons.block, 'Suspensions'),
                _buildNavItem(10, Icons.category_outlined, Icons.category, 'Categories'),
                _buildNavItem(11, Icons.support_agent_outlined, Icons.support_agent, 'Support Chat'),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Divider()),
                _buildNavItem(12, Icons.analytics_outlined, Icons.analytics, 'Reports'),
                _buildNavItem(13, Icons.settings_outlined, Icons.settings, 'Settings'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? AppColors.peach.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(isSelected ? activeIcon : icon, color: isSelected ? AppColors.peach : AppColors.gray400, size: 22),
                const SizedBox(width: 12),
                Text(label, style: AppTextStyles.body.copyWith(color: isSelected ? AppColors.peach : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItemWithBadge(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? AppColors.peach.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(isSelected ? activeIcon : icon, color: isSelected ? AppColors.peach : AppColors.gray400, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: AppTextStyles.body.copyWith(color: isSelected ? AppColors.peach : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('supplier_onboarding')
                      .where('status', isEqualTo: 'pending_review')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isWideScreen) {
    final unreadCount = _notifications.where((n) => n['read'] == false).length;

    return Container(
      padding: EdgeInsets.fromLTRB(isWideScreen ? 32 : 16, 16, isWideScreen ? 32 : 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          if (!isWideScreen) IconButton(icon: const Icon(Icons.menu), onPressed: _showMobileMenu),
          Expanded(child: Text(_getPageTitle(), style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold))),
          if (isWideScreen)
            Container(
              width: 300,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: AppColors.gray400, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: AppColors.gray400, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          const SizedBox(width: 16),
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: _showNotificationsPanel,
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            offset: const Offset(0, 50),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.peach.withValues(alpha: 0.2),
                  child: const Icon(Icons.person, color: AppColors.peach, size: 20),
                ),
                if (isWideScreen) ...[
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Admin', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                      Text('Super Admin', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ],
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Row(children: [Icon(Icons.person_outline, size: 20), SizedBox(width: 12), Text('Profile')])),
              const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings_outlined, size: 20), SizedBox(width: 12), Text('Settings')])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 20, color: AppColors.error), SizedBox(width: 12), Text('Logout', style: TextStyle(color: AppColors.error))])),
            ],
            onSelected: (value) {
              if (value == 'logout') _logout();
              if (value == 'settings') setState(() => _selectedIndex = 13);
            },
          ),
        ],
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0: return 'Dashboard';
      case 1: return 'User Management';
      case 2: return 'Supplier Management';
      case 3: return 'Onboarding Queue';
      case 4: return 'Bookings';
      case 5: return 'Transactions';
      case 6: return 'Disputes';
      case 7: return 'Violations';
      case 8: return 'Appeals';
      case 9: return 'Suspensions';
      case 10: return 'Categories';
      case 11: return 'Support Chat';
      case 12: return 'Reports & Analytics';
      case 13: return 'Settings';
      default: return 'Admin Dashboard';
    }
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0: return _buildDashboardTab();
      case 1: return _buildUsersTab();
      case 2: return _buildSuppliersTab();
      case 3: return _buildOnboardingQueueTab();
      case 4: return _buildBookingsTab();
      case 5: return _buildTransactionsTab();
      case 6: return _buildDisputesTab();
      case 7: return _buildViolationsTab();
      case 8: return _buildAppealsTab();
      case 9: return _buildSuspensionsTab();
      case 10: return _buildCategoriesTab();
      case 11: return _buildSupportChatTab();
      case 12: return _buildReportsTab();
      case 13: return _buildSettingsTab();
      default: return _buildDashboardTab();
    }
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex > 4 ? 4 : _selectedIndex,
      onTap: (index) {
        if (index == 4) {
          _showMobileMenu();
        } else {
          setState(() => _selectedIndex = index);
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.peach,
      unselectedItemColor: AppColors.gray400,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
        BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Suppliers'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Bookings'),
        BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
      ],
    );
  }

  // ==================== NOTIFICATIONS ====================

  void _showNotificationsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.gray300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Notifications', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600)),
                      TextButton(
                        onPressed: () {
                          _markAllNotificationsAsRead();
                          Navigator.pop(context);
                        },
                        child: const Text('Mark all read'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _notifications.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.gray300),
                        const SizedBox(height: 12),
                        Text('No notifications', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                      ],
                    ))
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        final isRead = notification['read'] as bool;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isRead ? AppColors.gray100 : AppColors.peach.withValues(alpha: 0.1),
                            child: Icon(Icons.notifications, color: isRead ? AppColors.gray400 : AppColors.peach, size: 20),
                          ),
                          title: Text(notification['title'] as String, style: AppTextStyles.body.copyWith(fontWeight: isRead ? FontWeight.normal : FontWeight.w600)),
                          subtitle: Text(_formatTimeAgo(notification['time'] as DateTime), style: AppTextStyles.caption),
                          trailing: isRead ? null : Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.peach, shape: BoxShape.circle)),
                          onTap: () {
                            _markNotificationAsRead(notification['id'] as String);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ==================== DASHBOARD TAB ====================

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsSection(),
          const SizedBox(height: 24),
          // Supplier Eligibility & Rate Limits Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SupplierEligibilityCards(
                        onTapEligible: () => setState(() => _selectedIndex = 2),
                        onTapBlocked: () => setState(() => _selectedIndex = 2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: RateLimitDashboard(),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  SupplierEligibilityCards(
                    onTapEligible: () => setState(() => _selectedIndex = 2),
                    onTapBlocked: () => setState(() => _selectedIndex = 2),
                  ),
                  const SizedBox(height: 16),
                  RateLimitDashboard(),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Quick Actions', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _buildQuickActions(),
          const SizedBox(height: 24),
          Text('Recent Activity', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return FutureBuilder<Map<String, int>>(
      future: _getStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        final statCards = [
          {'title': 'Total Users', 'value': '${stats['users'] ?? 0}', 'icon': Icons.people, 'color': Colors.blue},
          {'title': 'Suppliers', 'value': '${stats['suppliers'] ?? 0}', 'icon': Icons.store, 'color': Colors.green},
          {'title': 'Blocked by ID', 'value': '${stats['blockedByIdentity'] ?? 0}', 'icon': Icons.badge_outlined, 'color': Colors.amber},
          {'title': 'Bookings', 'value': '${stats['bookings'] ?? 0}', 'icon': Icons.calendar_today, 'color': Colors.orange},
          {'title': 'Revenue', 'value': '${NumberFormat.compact().format(stats['revenue'] ?? 0)} AOA', 'icon': Icons.attach_money, 'color': AppColors.peach},
          {'title': 'Open Disputes', 'value': '${stats['disputes'] ?? 0}', 'icon': Icons.report_problem, 'color': AppColors.error},
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 1400 ? 6 : (constraints.maxWidth > 1000 ? 3 : (constraints.maxWidth > 600 ? 2 : 1));
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: crossAxisCount == 1 ? 3 : 1.6,
              ),
              itemCount: statCards.length,
              itemBuilder: (context, index) {
                final stat = statCards[index];
                return _buildStatCard(
                  title: stat['title'] as String,
                  value: stat['value'] as String,
                  icon: stat['icon'] as IconData,
                  color: stat['color'] as Color,
                );
              },
            );
          },
        );
      },
    );
  }

  Future<Map<String, int>> _getStats() async {
    final Map<String, int> stats = {'users': 0, 'suppliers': 0, 'bookings': 0, 'revenue': 0, 'disputes': 0, 'appeals': 0, 'blockedByIdentity': 0};

    try {
      // Get user counts
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      stats['users'] = usersSnapshot.docs.length;
      stats['suppliers'] = usersSnapshot.docs.where((d) => d.data()['userType'] == 'supplier').length;

      // Get bookings
      final bookingsSnapshot = await FirebaseFirestore.instance.collection('bookings').get();
      stats['bookings'] = bookingsSnapshot.docs.length;

      // Calculate revenue
      for (var doc in bookingsSnapshot.docs) {
        stats['revenue'] = (stats['revenue'] ?? 0) + ((doc.data()['totalPrice'] as num?)?.toInt() ?? 0);
      }

      // Get suppliers blocked by identity verification (active but not verified)
      try {
        final suppliersSnapshot = await FirebaseFirestore.instance
            .collection('suppliers')
            .where('accountStatus', isEqualTo: 'active')
            .get();
        stats['blockedByIdentity'] = suppliersSnapshot.docs.where((d) {
          final status = d.data()['identityVerificationStatus'] as String?;
          return status != 'verified';
        }).length;
      } catch (_) {}

      // Get disputes (try-catch in case collection doesn't exist)
      try {
        final disputesSnapshot = await FirebaseFirestore.instance.collection('disputes').where('status', isEqualTo: 'open').get();
        stats['disputes'] = disputesSnapshot.docs.length;
      } catch (_) {}

      // Get appeals
      try {
        final appealsSnapshot = await FirebaseFirestore.instance.collection('appeals').where('status', isEqualTo: 'pending').get();
        stats['appeals'] = appealsSnapshot.docs.length;
      } catch (_) {}
    } catch (e) {
      // Return defaults on error
    }

    return stats;
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(value, style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.person_add, 'label': 'Add User', 'color': Colors.blue, 'onTap': () => _showAddUserDialog()},
      {'icon': Icons.send, 'label': 'Send Notification', 'color': Colors.orange, 'onTap': () => _showSendNotificationDialog()},
      {'icon': Icons.star, 'label': 'Destaques & Verificação', 'color': Colors.amber, 'onTap': () => context.push(Routes.adminFeaturedVerification)},
      {'icon': Icons.category_outlined, 'label': 'Manage Categories', 'color': Colors.purple, 'onTap': () => setState(() => _selectedIndex = 9)},
      {'icon': Icons.analytics, 'label': 'View Reports', 'color': AppColors.peach, 'onTap': () => setState(() => _selectedIndex = 11)},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: actions.map((action) => InkWell(
        onTap: action['onTap'] as VoidCallback?,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: (action['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(action['icon'] as IconData, color: action['color'] as Color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(action['label'] as String, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildRecentActivity() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('bookings').orderBy('createdAt', descending: true).limit(5).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data?.docs ?? [];

        if (bookings.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: AppColors.gray300),
                  const SizedBox(height: 12),
                  Text('No recent activity', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final booking = bookings[index].data() as Map<String, dynamic>;
              final createdAt = (booking['createdAt'] as Timestamp?)?.toDate();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.peach.withValues(alpha: 0.1),
                  child: const Icon(Icons.event, color: AppColors.peach),
                ),
                title: Text(booking['eventName'] ?? 'Booking #${bookings[index].id.substring(0, 6)}'),
                subtitle: Text(createdAt != null ? DateFormat('MMM dd, yyyy - HH:mm').format(createdAt) : 'Date unknown', style: AppTextStyles.caption),
                trailing: _buildStatusBadge(booking['status'] as String? ?? 'pending'),
              );
            },
          ),
        );
      },
    );
  }

  // ==================== USERS TAB ====================

  Widget _buildUsersTab() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').where('userType', isEqualTo: 'client').limit(50).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildEmptyState('No users found', Icons.people_outline);
        }

        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return _buildEmptyState('No users found', Icons.people_outline);
        }

        return _buildUserList('All Clients', users);
      },
    );
  }

  Widget _buildUserList(String title, List<QueryDocumentSnapshot> users) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.all(20), child: Text(title, style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600))),
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final data = users[index].data() as Map<String, dynamic>;
                final isActive = data['isActive'] as bool? ?? true;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: (isActive ? AppColors.peach : AppColors.error).withValues(alpha: 0.1),
                    child: Text((data['name'] as String? ?? '?')[0].toUpperCase(), style: TextStyle(color: isActive ? AppColors.peach : AppColors.error)),
                  ),
                  title: Text(data['name'] ?? 'Unknown', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
                  subtitle: Text('${data['email'] ?? ''} • ${data['phone'] ?? ''}', style: AppTextStyles.caption),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusBadge(isActive ? 'active' : 'suspended'),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'view', child: Text('View Details')),
                          PopupMenuItem(value: 'suspend', child: Text(isActive ? 'Suspend' : 'Reactivate')),
                        ],
                        onSelected: (value) {
                          if (value == 'view') _showUserDetailsDialog(users[index].id);
                          if (value == 'suspend') isActive ? _suspendUser(users[index].id) : _reactivateUser(users[index].id);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SUPPLIERS TAB ====================

  Widget _buildSuppliersTab() {
    // Query the suppliers collection directly for proper SupplierOnboardingStatus
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('suppliers').limit(50).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final suppliers = snapshot.data?.docs ?? [];

        if (suppliers.isEmpty) {
          return _buildEmptyState('No suppliers found', Icons.store_outlined);
        }

        return _buildSupplierList('All Suppliers', suppliers);
      },
    );
  }

  /// Build a supplier-specific list that opens Supplier Detail bottom sheet
  /// instead of the legacy raw user details dialog
  Widget _buildSupplierList(String title, List<QueryDocumentSnapshot> suppliers) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.all(20), child: Text(title, style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600))),
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: suppliers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final data = suppliers[index].data() as Map<String, dynamic>;
                final supplierId = suppliers[index].id;
                final isActive = data['isActive'] as bool? ?? true;
                final businessName = data['businessName'] as String? ?? 'Unknown';
                final category = data['category'] as String? ?? '';
                final accountStatus = data['accountStatus'] as String? ?? 'pendingReview';
                final identityStatus = data['identityVerificationStatus'] as String? ?? 'pending';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: (isActive ? AppColors.peach : AppColors.error).withValues(alpha: 0.1),
                    child: Text(
                      businessName.isNotEmpty ? businessName[0].toUpperCase() : '?',
                      style: TextStyle(color: isActive ? AppColors.peach : AppColors.error),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(businessName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
                      ),
                      // Identity verification badge
                      _buildIdentityBadge(identityStatus),
                    ],
                  ),
                  subtitle: Text('$category • $accountStatus', style: AppTextStyles.caption),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusBadge(isActive ? 'active' : 'suspended'),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'view', child: Text('View Details')),
                          PopupMenuItem(value: 'suspend', child: Text(isActive ? 'Suspend' : 'Reactivate')),
                        ],
                        onSelected: (value) {
                          if (value == 'view') {
                            // CRITICAL: Use Supplier Detail sheet, NOT legacy user dialog
                            debugPrint('🔍 OPENING SUPPLIER DETAIL SHEET for $supplierId');
                            _viewSupplierDetails(supplierId);
                          }
                          if (value == 'suspend') {
                            isActive ? _suspendSupplier(supplierId) : _reactivateSupplier(supplierId);
                          }
                        },
                      ),
                    ],
                  ),
                  // Tap row to open supplier details
                  onTap: () {
                    debugPrint('🔍 OPENING SUPPLIER DETAIL SHEET for $supplierId (row tap)');
                    _viewSupplierDetails(supplierId);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build identity verification status badge
  Widget _buildIdentityBadge(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'verified':
        color = AppColors.success;
        icon = Icons.verified;
        break;
      case 'rejected':
        color = AppColors.error;
        icon = Icons.cancel;
        break;
      default: // pending
        color = AppColors.warning;
        icon = Icons.pending;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status == 'verified' ? 'ID ✓' : status == 'rejected' ? 'ID ✗' : 'ID ?',
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Suspend a supplier
  void _suspendSupplier(String supplierId) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Suspend Supplier?'),
          content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Reason for suspension'), maxLines: 2),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim().isNotEmpty ? controller.text.trim() : 'Admin action'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              child: const Text('Suspend'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      try {
        final adminId = ref.read(authProvider).firebaseUser?.uid;
        await FirebaseFirestore.instance.collection('suppliers').doc(supplierId).update({
          'isActive': false,
          'accountStatus': 'suspended',
          'suspension': {'reason': result, 'suspendedAt': FieldValue.serverTimestamp(), 'suspendedBy': adminId},
        });
        setState(() {});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier suspended'), backgroundColor: AppColors.success));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  /// Reactivate a supplier
  void _reactivateSupplier(String supplierId) async {
    try {
      final adminId = ref.read(authProvider).firebaseUser?.uid;
      await FirebaseFirestore.instance.collection('suppliers').doc(supplierId).update({
        'isActive': true,
        'accountStatus': 'active',
        'suspension': FieldValue.delete(),
        'reactivatedAt': FieldValue.serverTimestamp(),
        'reactivatedBy': adminId,
      });
      setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier reactivated'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  /// View supplier details in the proper Supplier Detail bottom sheet
  /// with IdentityVerificationPanel and AdminEligibilityCard
  void _viewSupplierDetails(String supplierId) {
    final onboardingService = SupplierOnboardingService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: FutureBuilder<SupplierOnboardingStatus?>(
            future: onboardingService.getOnboardingStatus(supplierId),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.peach),
                );
              }

              if (!snapshot.hasData || snapshot.data == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      const Text('Supplier not found'),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }

              final supplier = snapshot.data!;
              final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';

              // ASSERTION: Ensure we have full SupplierOnboardingStatus data
              assert(
                supplier.supplierId.isNotEmpty,
                'Admin supplier details must use full SupplierOnboardingStatus with valid supplierId',
              );
              debugPrint(
                '🔍 _viewSupplierDetails: supplierId=${supplier.supplierId}, '
                'identityVerificationStatus=${supplier.identityVerificationStatus.name}, '
                'accountStatus=${supplier.accountStatus.name}, '
                'isEligibleForBookings=${supplier.isEligibleForBookings}',
              );

              return Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.peach.withValues(alpha: 0.1),
                          radius: 24,
                          child: Text(
                            (supplier.businessName ?? 'S')[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.peach,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                supplier.businessName ?? 'Unknown Supplier',
                                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                supplier.category ?? 'No category',
                                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Eligibility Card
                          AdminEligibilityCard(status: supplier),
                          const SizedBox(height: 16),

                          // Identity Verification Panel - THE KEY SECTION
                          IdentityVerificationPanel(
                            supplier: supplier,
                            adminId: adminId,
                            onStatusChanged: () {
                              // Refresh the bottom sheet
                              Navigator.pop(ctx);
                              _viewSupplierDetails(supplierId);
                              // Refresh the list
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 16),

                          // Contact Information
                          _buildSupplierDetailSection(
                            title: 'Contact Information',
                            icon: Icons.contact_phone,
                            children: [
                              if (supplier.phone != null)
                                _buildSupplierDetailRow('Phone', supplier.phone!),
                              if (supplier.email != null)
                                _buildSupplierDetailRow('Email', supplier.email!),
                              if (supplier.whatsapp != null)
                                _buildSupplierDetailRow('WhatsApp', supplier.whatsapp!),
                              if (supplier.website != null)
                                _buildSupplierDetailRow('Website', supplier.website!),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Location
                          if (supplier.city != null || supplier.province != null)
                            _buildSupplierDetailSection(
                              title: 'Location',
                              icon: Icons.location_on,
                              children: [
                                if (supplier.address != null)
                                  _buildSupplierDetailRow('Address', supplier.address!),
                                if (supplier.city != null)
                                  _buildSupplierDetailRow('City', supplier.city!),
                                if (supplier.province != null)
                                  _buildSupplierDetailRow('Province', supplier.province!),
                              ],
                            ),
                          const SizedBox(height: 16),

                          // Business Info
                          _buildSupplierDetailSection(
                            title: 'Business Information',
                            icon: Icons.business,
                            children: [
                              _buildSupplierDetailRow('Entity Type', supplier.entityType.name),
                              if (supplier.nif != null)
                                _buildSupplierDetailRow('NIF', supplier.nif!),
                              if (supplier.idDocumentType != null)
                                _buildSupplierDetailRow('Document Type', supplier.idDocumentType!.name),
                              if (supplier.idDocumentNumber != null)
                                _buildSupplierDetailRow('Document Number', supplier.idDocumentNumber!),
                              _buildSupplierDetailRow('Pricing', supplier.priceDisplay),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSupplierDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ONBOARDING QUEUE TAB ====================

  Widget _buildOnboardingQueueTab() {
    // Use the dedicated OnboardingQueueWidget with proper tabs
    return _OnboardingQueueWidget(
      onApprove: _handleApproveSupplier,
      onReject: _handleRejectSupplier,
      onRequestChanges: _handleRequestChanges,
      onDelete: _handleDeleteSupplier,
    );
  }

  Future<void> _handleApproveSupplier(String supplierId) async {
    final adminId = ref.read(authProvider).firebaseUser?.uid;
    if (adminId == null) {
      _showSnackBar('Erro: Administrador não autenticado', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprovar Fornecedor'),
        content: const Text('Tem certeza que deseja aprovar este fornecedor?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Aprovar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final service = SupplierOnboardingService();
    final success = await service.approveSupplier(supplierId: supplierId, adminId: adminId);
    _showSnackBar(success ? 'Fornecedor aprovado com sucesso!' : 'Erro ao aprovar fornecedor', isError: !success);
  }

  Future<void> _handleRejectSupplier(String supplierId) async {
    final adminId = ref.read(authProvider).firebaseUser?.uid;
    if (adminId == null) {
      _showSnackBar('Erro: Administrador não autenticado', isError: true);
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeitar Candidatura'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Motivo da rejeição...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );

    if (result == null || result.trim().isEmpty) return;

    final service = SupplierOnboardingService();
    final success = await service.rejectSupplier(supplierId: supplierId, adminId: adminId, rejectionReason: result);
    _showSnackBar(success ? 'Candidatura rejeitada' : 'Erro ao rejeitar candidatura', isError: !success);
  }

  Future<void> _handleRequestChanges(String supplierId) async {
    final adminId = ref.read(authProvider).firebaseUser?.uid;
    if (adminId == null) {
      _showSnackBar('Erro: Administrador não autenticado', isError: true);
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitar Alterações'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Descreva as alterações necessárias...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (result == null || result.trim().isEmpty) return;

    final service = SupplierOnboardingService();
    final success = await service.requestChanges(supplierId: supplierId, adminId: adminId, clarificationRequest: result);
    _showSnackBar(success ? 'Pedido de alterações enviado!' : 'Erro ao enviar pedido', isError: !success);
  }

  Future<void> _handleDeleteSupplier(String supplierId) async {
    final adminId = ref.read(authProvider).firebaseUser?.uid;
    if (adminId == null) {
      _showSnackBar('Erro: Administrador não autenticado', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Fornecedor'),
        content: const Text('Tem certeza que deseja eliminar este fornecedor permanentemente? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final service = SupplierOnboardingService();
    final success = await service.deleteSupplier(supplierId: supplierId, adminId: adminId);
    _showSnackBar(success ? 'Fornecedor eliminado' : 'Erro ao eliminar fornecedor', isError: !success);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : AppColors.success,
        ),
      );
    }
  }

  // ==================== BOOKINGS TAB ====================

  Widget _buildBookingsTab() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('bookings').orderBy('createdAt', descending: true).limit(50).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data?.docs ?? [];

        if (bookings.isEmpty) {
          return _buildEmptyState('No bookings found', Icons.calendar_today_outlined);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final booking = bookings[index].data() as Map<String, dynamic>;
                final eventDate = (booking['eventDate'] as Timestamp?)?.toDate();
                return ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(booking['status']).withValues(alpha: 0.1),
                    child: Icon(Icons.event, color: _getStatusColor(booking['status'])),
                  ),
                  title: Text(booking['eventName'] ?? 'Booking #${bookings[index].id.substring(0, 6)}', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(eventDate != null ? 'Event: ${DateFormat('MMM dd, yyyy').format(eventDate)}' : 'Date not set'),
                      Text('Price: ${booking['totalPrice'] ?? 0} AOA'),
                    ],
                  ),
                  trailing: _buildStatusBadge(booking['status'] as String? ?? 'pending'),
                  onTap: () => _showBookingDetailsDialog(bookings[index].id),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ==================== TRANSACTIONS TAB ====================

  Widget _buildTransactionsTab() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('bookings').orderBy('createdAt', descending: true).limit(100).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data?.docs ?? [];

        if (bookings.isEmpty) {
          return _buildEmptyState('No transactions found', Icons.receipt_long_outlined);
        }

        // Calculate totals from bookings
        double totalRevenue = 0;
        int completedCount = 0;
        int pendingCount = 0;

        for (var doc in bookings) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['totalPrice'] as num?)?.toDouble() ?? 0;
          final status = data['status'] as String? ?? 'pending';

          if (status == 'completed' || status == 'confirmed') {
            completedCount++;
            totalRevenue += amount;
          } else if (status == 'pending') {
            pendingCount++;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              Row(
                children: [
                  Expanded(child: _buildMiniStatCard('Total Revenue', '${NumberFormat.compact().format(totalRevenue)} AOA', Icons.trending_up, AppColors.success)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMiniStatCard('Completed', '$completedCount', Icons.check_circle, Colors.blue)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMiniStatCard('Pending', '$pendingCount', Icons.pending, AppColors.warning)),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('All Transactions', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600)),
                          TextButton.icon(
                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export feature coming soon!'))),
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Export'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: bookings.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final tx = bookings[index].data() as Map<String, dynamic>;
                        final createdAt = (tx['createdAt'] as Timestamp?)?.toDate();
                        final amount = (tx['totalPrice'] as num?)?.toDouble() ?? 0;
                        final status = tx['status'] as String? ?? 'pending';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.success.withValues(alpha: 0.1),
                            child: const Icon(Icons.arrow_forward, color: AppColors.success),
                          ),
                          title: Text('Booking #${bookings[index].id.substring(0, 8)}', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tx['eventName'] ?? 'Service booking'),
                              if (createdAt != null) Text(DateFormat('MMM dd, yyyy - HH:mm').format(createdAt), style: AppTextStyles.caption.copyWith(color: AppColors.gray400)),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('+${NumberFormat('#,###').format(amount)} AOA', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: AppColors.success)),
                              _buildStatusBadge(status),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text(title, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DISPUTES TAB ====================

  Widget _buildDisputesTab() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('disputes').orderBy('createdAt', descending: true).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final disputes = snapshot.data?.docs ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add Dispute Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('All Disputes', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600)),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDisputeDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Dispute'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (disputes.isEmpty)
                _buildEmptyState('No disputes found', Icons.report_problem_outlined)
              else
                ...disputes.map((dispute) => _buildDisputeCard(dispute.id, dispute.data() as Map<String, dynamic>)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDisputeCard(String disputeId, Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'open';
    final isOpen = status == 'open' || status == 'pending' || status == 'investigating';
    final reason = data['reason'] as String? ?? 'No reason provided';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOpen ? AppColors.error.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _getStatusColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.report_problem, color: _getStatusColor(status)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dispute #${disputeId.substring(0, 8)}', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                      if (createdAt != null) Text(DateFormat('MMM dd, yyyy - HH:mm').format(createdAt), style: AppTextStyles.caption.copyWith(color: AppColors.gray400)),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text('Reason:', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(reason, style: AppTextStyles.body),
            if (isOpen) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _assignDispute(disputeId),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Assign to Me'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _resolveDispute(disputeId),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Resolve'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== VIOLATIONS TAB ====================

  Widget _buildViolationsTab() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('violations').orderBy('createdAt', descending: true).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final violations = snapshot.data?.docs ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('User Violations', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600)),
                  ElevatedButton.icon(
                    onPressed: () => _showAddViolationDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Violation'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (violations.isEmpty)
                _buildEmptyState('No violations recorded', Icons.verified_user_outlined)
              else
                ...violations.map((violation) => _buildViolationCard(violation.id, violation.data() as Map<String, dynamic>)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildViolationCard(String violationId, Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'other';
    final description = data['description'] as String? ?? '';
    final severity = data['severity'] as String? ?? 'warning';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final actionTaken = data['actionTaken'] as String?;

    Color severityColor;
    switch (severity) {
      case 'critical': severityColor = AppColors.error; break;
      case 'major': severityColor = Colors.orange; break;
      case 'minor': severityColor = AppColors.warning; break;
      default: severityColor = AppColors.gray400;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: severityColor, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: severityColor.withValues(alpha: 0.1),
                  child: Icon(Icons.warning, color: severityColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type.toUpperCase(), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                      if (createdAt != null) Text(DateFormat('MMM dd, yyyy').format(createdAt), style: AppTextStyles.caption.copyWith(color: AppColors.gray400)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: severityColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(severity.toUpperCase(), style: AppTextStyles.caption.copyWith(color: severityColor, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(description, style: AppTextStyles.body),
            if (actionTaken != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.gray100, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.gavel, size: 16, color: AppColors.gray400),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Action: $actionTaken', style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray400))),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => _issueWarning(violationId), child: const Text('Issue Warning'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _suspendForViolation(violationId),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                      child: const Text('Suspend User'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== APPEALS TAB ====================

  Widget _buildAppealsTab() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('appeals').orderBy('submittedAt', descending: true).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final appeals = snapshot.data?.docs ?? [];

        if (appeals.isEmpty) {
          return _buildEmptyState('No appeals found', Icons.gavel_outlined);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: appeals.map((appeal) => _buildAppealCard(appeal.id, appeal.data() as Map<String, dynamic>)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildAppealCard(String appealId, Map<String, dynamic> data) {
    final userId = data['userId'] as String? ?? '';
    final message = data['message'] as String? ?? '';
    final status = data['status'] as String? ?? 'pending';
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.peach.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, color: AppColors.peach),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User Appeal', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                      Text('User: ${userId.substring(0, 8)}...', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 16),
            Text('Appeal Message:', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(message, style: AppTextStyles.body),
            if (submittedAt != null) ...[
              const SizedBox(height: 12),
              Text('Submitted: ${DateFormat('MMM dd, yyyy - HH:mm').format(submittedAt)}', style: AppTextStyles.caption.copyWith(color: AppColors.gray400)),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectAppeal(appealId),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveAppeal(appealId, userId),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== SUSPENSIONS TAB ====================

  Widget _buildSuspensionsTab() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').where('isActive', isEqualTo: false).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final suspendedUsers = snapshot.data?.docs ?? [];

        if (suspendedUsers.isEmpty) {
          return _buildEmptyState('No suspended users', Icons.verified_user_outlined);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: suspendedUsers.map((user) {
              final data = user.data() as Map<String, dynamic>;
              return _buildSuspensionCard(user.id, data);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSuspensionCard(String userId, Map<String, dynamic> data) {
    final name = data['name'] as String? ?? 'Unknown';
    final userType = data['userType'] as String? ?? 'client';
    final suspension = data['suspension'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  child: const Icon(Icons.block, color: AppColors.error),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                      Text(userType, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                _buildStatusBadge('suspended'),
              ],
            ),
            if (suspension != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text('Reason: ${suspension['reason'] ?? 'Unknown'}', style: AppTextStyles.body),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _reactivateUser(userId),
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Reactivate Account'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== CATEGORIES TAB ====================

  /// Refresh supplier count for a single category
  Future<void> _refreshSingleCategoryCount(String categoryId, String categoryName) async {
    try {
      await _categoryStatsService.updateCategorySupplierCount(categoryId, categoryName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated count for $categoryName'), backgroundColor: AppColors.success),
        );
        setState(() {}); // Trigger rebuild
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Refresh all category supplier counts
  Future<void> _refreshCategoryCounts() async {
    setState(() => _isRefreshingCategoryCounts = true);
    try {
      await _categoryStatsService.updateAllCategorySupplierCounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category counts updated!'), backgroundColor: AppColors.success),
        );
        setState(() {}); // Trigger rebuild
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating counts: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingCategoryCounts = false);
      }
    }
  }

  Widget _buildCategoriesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('categories').orderBy('order').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data?.docs ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Service Categories', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      // Refresh counts button
                      OutlinedButton.icon(
                        onPressed: _isRefreshingCategoryCounts ? null : _refreshCategoryCounts,
                        icon: _isRefreshingCategoryCounts
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh, size: 18),
                        label: Text(_isRefreshingCategoryCounts ? 'Updating...' : 'Refresh Counts'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddCategoryDialog(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Category'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (categories.isEmpty)
                _buildEmptyState('No categories found', Icons.category_outlined)
              else
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final category = categories[index].data() as Map<String, dynamic>;
                      final categoryName = category['name'] as String? ?? '';
                      final isActive = category['isActive'] as bool? ?? true;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.peach.withValues(alpha: 0.1),
                          child: Icon(_getCategoryIcon(category['icon'] as String?), color: AppColors.peach),
                        ),
                        title: Text(categoryName.isNotEmpty ? categoryName : 'Unknown', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
                        // Real-time supplier count using FutureBuilder
                        subtitle: FutureBuilder<int>(
                          future: _categoryStatsService.getSupplierCountForCategory(categoryName),
                          builder: (context, countSnapshot) {
                            final count = countSnapshot.data ?? category['supplierCount'] ?? 0;
                            final isLoading = countSnapshot.connectionState == ConnectionState.waiting;
                            return Row(
                              children: [
                                Text('$count suppliers', style: AppTextStyles.caption),
                                if (isLoading) ...[
                                  const SizedBox(width: 8),
                                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
                                ],
                              ],
                            );
                          },
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isActive,
                              onChanged: (value) => _toggleCategoryActive(categories[index].id, value),
                              activeColor: AppColors.success,
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(value: 'refresh', child: Text('Refresh Count')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') _showEditCategoryDialog(categories[index].id, category);
                                if (value == 'refresh') _refreshSingleCategoryCount(categories[index].id, categoryName);
                                if (value == 'delete') _deleteCategory(categories[index].id);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String? iconName) {
    switch (iconName) {
      case 'camera': return Icons.camera_alt;
      case 'music': return Icons.music_note;
      case 'cake': return Icons.cake;
      case 'flower': return Icons.local_florist;
      case 'car': return Icons.directions_car;
      case 'dress': return Icons.checkroom;
      case 'restaurant': return Icons.restaurant;
      case 'decoration': return Icons.celebration;
      default: return Icons.category;
    }
  }

  // ==================== SUPPORT CHAT TAB ====================

  Widget _buildSupportChatTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('isSupport', isEqualTo: true)
          .orderBy('lastMessageAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data?.docs ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Support Conversations', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => context.push(Routes.adminBroadcast),
                        icon: const Icon(Icons.campaign, size: 18),
                        label: const Text('Broadcasts'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.peach,
                          side: const BorderSide(color: AppColors.peach),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('Online', style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (chats.isEmpty)
                Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.support_agent, size: 64, color: AppColors.gray300),
                        const SizedBox(height: 16),
                        Text('No active support conversations', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Text('Users can reach out via the app for support', style: AppTextStyles.caption.copyWith(color: AppColors.gray400)),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: () => _showBroadcastMessageDialog(),
                          icon: const Icon(Icons.campaign, size: 18),
                          label: const Text('Send Broadcast Message'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: chats.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final chat = chats[index].data() as Map<String, dynamic>;
                      final participants = chat['participants'] as List<dynamic>? ?? [];
                      final participantNames = chat['participantNames'] as Map<String, dynamic>? ?? {};
                      final participantPhotos = chat['participantPhotos'] as Map<String, dynamic>? ?? {};
                      final unreadCounts = chat['unreadCount'] as Map<String, dynamic>? ?? {};
                      final lastMessageAt = (chat['lastMessageAt'] as Timestamp?)?.toDate();

                      // Get user (non-admin) info
                      final userId = participants.firstWhere(
                        (p) => p != AdminChatService.adminSupportId,
                        orElse: () => '',
                      );
                      final userName = participantNames[userId] as String? ?? 'Unknown User';
                      final userPhoto = participantPhotos[userId] as String? ?? '';
                      final hasUnread = (unreadCounts[AdminChatService.adminSupportId] as int?) ?? 0;

                      return ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.peach.withValues(alpha: 0.1),
                              backgroundImage: userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
                              child: userPhoto.isEmpty
                                  ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?', style: TextStyle(color: AppColors.peach))
                                  : null,
                            ),
                            if (hasUnread > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                                  child: Center(child: Text('$hasUnread', style: const TextStyle(color: Colors.white, fontSize: 10))),
                                ),
                              ),
                          ],
                        ),
                        title: Text(userName, style: AppTextStyles.body.copyWith(fontWeight: hasUnread > 0 ? FontWeight.w600 : FontWeight.normal)),
                        subtitle: Text(chat['lastMessage'] ?? 'No messages', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (lastMessageAt != null) Text(_formatTimeAgo(lastMessageAt), style: AppTextStyles.caption.copyWith(color: AppColors.gray400)),
                            const SizedBox(height: 4),
                            _buildStatusBadge(chat['status'] as String? ?? 'open'),
                          ],
                        ),
                        onTap: () => _openSupportChat(chats[index].id, chat),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ==================== REPORTS TAB ====================

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Platform Reports & Analytics', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600)),
              OutlinedButton.icon(
                onPressed: () => context.push(Routes.adminReports),
                icon: const Icon(Icons.report_outlined, size: 18),
                label: const Text('Manage Reports'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.peach,
                  side: const BorderSide(color: AppColors.peach),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Real-time stats
          FutureBuilder<Map<String, dynamic>>(
            future: _getReportData(),
            builder: (context, snapshot) {
              final data = snapshot.data ?? {};

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overview', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2,
                        children: [
                          _buildMiniStatCard('Total Users', '${data['totalUsers'] ?? 0}', Icons.people, Colors.blue),
                          _buildMiniStatCard('Active Suppliers', '${data['activeSuppliers'] ?? 0}', Icons.store, Colors.green),
                          _buildMiniStatCard('This Month', '${data['monthlyBookings'] ?? 0} bookings', Icons.calendar_today, Colors.orange),
                          _buildMiniStatCard('Monthly Revenue', '${NumberFormat.compact().format(data['monthlyRevenue'] ?? 0)} AOA', Icons.attach_money, AppColors.peach),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Text('Report Types', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 800 ? 3 : 2;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.2,
                        children: [
                          _buildReportCard('User Growth', Icons.trending_up, Colors.blue, 'Track new user registrations', () => _generateReport('users')),
                          _buildReportCard('Revenue Report', Icons.attach_money, Colors.green, 'View earnings and transactions', () => _generateReport('revenue')),
                          _buildReportCard('Booking Analytics', Icons.analytics, Colors.orange, 'Booking trends and patterns', () => _generateReport('bookings')),
                          _buildReportCard('Supplier Performance', Icons.star, AppColors.peach, 'Top performers and ratings', () => _generateReport('suppliers')),
                          _buildReportCard('Category Stats', Icons.category, Colors.purple, 'Popular service categories', () => _generateReport('categories')),
                          _buildReportCard('Dispute Summary', Icons.report_problem, AppColors.error, 'Dispute resolution metrics', () => _generateReport('disputes')),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getReportData() async {
    final Map<String, dynamic> data = {};

    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      data['totalUsers'] = usersSnapshot.docs.length;
      data['activeSuppliers'] = usersSnapshot.docs.where((d) => d.data()['userType'] == 'supplier' && (d.data()['isActive'] ?? true)).length;

      // Get this month's bookings
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final bookingsSnapshot = await FirebaseFirestore.instance.collection('bookings')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .get();

      data['monthlyBookings'] = bookingsSnapshot.docs.length;

      double monthlyRevenue = 0;
      for (var doc in bookingsSnapshot.docs) {
        monthlyRevenue += (doc.data()['totalPrice'] as num?)?.toDouble() ?? 0;
      }
      data['monthlyRevenue'] = monthlyRevenue;
    } catch (e) {
      // Use defaults
    }

    return data;
  }

  Widget _buildReportCard(String title, IconData icon, Color color, String description, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 28),
            ),
            const Spacer(),
            Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(description, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  void _generateReport(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Generate ${type.toUpperCase()} Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select date range for the report:'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Generating $type report for last 7 days...'), backgroundColor: AppColors.success),
                      );
                    },
                    child: const Text('Last 7 Days'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Generating $type report for last 30 days...'), backgroundColor: AppColors.success),
                      );
                    },
                    child: const Text('Last 30 Days'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  // ==================== SETTINGS TAB ====================

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Platform Settings
          Text('Platform Settings', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _buildSettingsTile(
                  icon: Icons.percent,
                  title: 'Platform Commission',
                  subtitle: '${_platformCommission.toStringAsFixed(0)}%',
                  onTap: () => _showCommissionDialog(),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  secondary: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.peach.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.build, color: AppColors.peach, size: 22),
                  ),
                  title: const Text('Maintenance Mode'),
                  subtitle: Text(_maintenanceMode ? 'App is in maintenance' : 'App is running normally'),
                  value: _maintenanceMode,
                  onChanged: (value) => _updateSetting('maintenanceMode', value),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  secondary: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.peach.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.person_add, color: AppColors.peach, size: 22),
                  ),
                  title: const Text('Allow New Registrations'),
                  subtitle: Text(_newRegistrations ? 'Users can register' : 'Registration disabled'),
                  value: _newRegistrations,
                  onChanged: (value) => _updateSetting('newRegistrations', value),
                ),
                const Divider(height: 1),
                _buildSettingsTile(
                  icon: Icons.email,
                  title: 'Support Email',
                  subtitle: _supportEmail,
                  onTap: () => _showSupportEmailDialog(),
                ),
                const Divider(height: 1),
                _buildSettingsTile(
                  icon: Icons.phone,
                  title: 'Support Phone',
                  subtitle: _supportPhone,
                  onTap: () => _showSupportPhoneDialog(),
                ),
                const Divider(height: 1),
                _buildSettingsTile(
                  icon: Icons.chat,
                  title: 'Support WhatsApp',
                  subtitle: _supportWhatsApp,
                  onTap: () => _showSupportWhatsAppDialog(),
                ),
                const Divider(height: 1),
                _buildSettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Push Notifications',
                  subtitle: 'Configure notification settings',
                  onTap: () => _showNotificationSettingsDialog(),
                ),
                const Divider(height: 1),
                _buildSettingsTile(
                  icon: Icons.language_outlined,
                  title: 'Default Language',
                  subtitle: 'Portuguese',
                  onTap: () => _showLanguageDialog(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Save All Settings Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('Save All Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.peach,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text('Admin Account', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _buildSettingsTile(icon: Icons.person_outline, title: 'Profile', subtitle: 'Edit admin profile', onTap: () => _showAdminProfileDialog()),
                const Divider(height: 1),
                _buildSettingsTile(icon: Icons.security_outlined, title: 'Security', subtitle: 'Password and security settings', onTap: () => _showSecuritySettingsDialog()),
                const Divider(height: 1),
                _buildSettingsTile(icon: Icons.backup_outlined, title: 'Database Backup', subtitle: 'Backup and restore data', onTap: () => _showBackupDialog()),
                const Divider(height: 1),
                _buildSettingsTile(icon: Icons.logout, title: 'Sign Out', subtitle: 'Sign out of admin account', onTap: _logout, isDestructive: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool isDestructive = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: (isDestructive ? AppColors.error : AppColors.peach).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: isDestructive ? AppColors.error : AppColors.peach, size: 22),
      ),
      title: Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500, color: isDestructive ? AppColors.error : null)),
      subtitle: Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _updateSetting(String key, dynamic value) async {
    setState(() {
      if (key == 'maintenanceMode') _maintenanceMode = value;
      if (key == 'newRegistrations') _newRegistrations = value;
    });

    try {
      // Use platform settings service for consistent settings management
      if (key == 'maintenanceMode') {
        await _platformSettingsService.updateMaintenanceMode(value);
      } else if (key == 'newRegistrations') {
        await _platformSettingsService.updateRegistrationSettings(allowNewRegistrations: value);
      } else {
        // Fallback to direct Firestore update
        await FirebaseFirestore.instance.collection('admin_settings').doc('platform').set({key: value}, SetOptions(merge: true));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Setting updated'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }


  // ==================== HELPER WIDGETS ====================

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'approved': case 'active': case 'completed': case 'resolved': case 'confirmed': color = AppColors.success; break;
      case 'rejected': case 'suspended': case 'failed': case 'cancelled': color = AppColors.error; break;
      case 'in_progress': case 'processing': color = Colors.blue; break;
      default: color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.replaceAll('_', ' ').toUpperCase(), style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed': case 'approved': case 'completed': case 'resolved': return AppColors.success;
      case 'pending': case 'open': return AppColors.warning;
      case 'cancelled': case 'rejected': case 'suspended': return AppColors.error;
      default: return AppColors.gray400;
    }
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.gray300),
            const SizedBox(height: 16),
            Text(message, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================

  void _showMobileMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.gray300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              ...[
                {'index': 4, 'icon': Icons.receipt_long_outlined, 'label': 'Transactions'},
                {'index': 5, 'icon': Icons.report_problem_outlined, 'label': 'Disputes'},
                {'index': 6, 'icon': Icons.warning_amber_outlined, 'label': 'Violations'},
                {'index': 7, 'icon': Icons.gavel_outlined, 'label': 'Appeals'},
                {'index': 8, 'icon': Icons.block_outlined, 'label': 'Suspensions'},
                {'index': 9, 'icon': Icons.category_outlined, 'label': 'Categories'},
                {'index': 10, 'icon': Icons.support_agent_outlined, 'label': 'Support Chat'},
                {'index': 11, 'icon': Icons.analytics_outlined, 'label': 'Reports'},
                {'index': 12, 'icon': Icons.settings_outlined, 'label': 'Settings'},
              ].map((item) => ListTile(
                leading: Icon(item['icon'] as IconData),
                title: Text(item['label'] as String),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = item['index'] as int);
                },
              )),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        context.go(Routes.adminLogin);
      }
    }
  }

  // Dialog methods
  void _showUserDetailsDialog(String userId) => _showDetailsDialog('User Details', userId, 'users');
  void _showBookingDetailsDialog(String bookingId) => _showDetailsDialog('Booking Details', bookingId, 'bookings');

  void _showDetailsDialog(String title, String docId, String collection) {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection(collection).doc(docId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const AlertDialog(content: Center(child: CircularProgressIndicator()));

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          if (data == null) return AlertDialog(title: Text(title), content: const Text('No data found'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]);

          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: data.entries.map((entry) {
                  String value = entry.value.toString();
                  if (entry.value is Timestamp) value = DateFormat('MMM dd, yyyy HH:mm').format((entry.value as Timestamp).toDate());
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 120, child: Text('${entry.key}:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))),
                        Expanded(child: Text(value, style: AppTextStyles.bodySmall)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          );
        },
      ),
    );
  }

  void _suspendUser(String userId) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Suspend User?'),
          content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Reason for suspension'), maxLines: 2),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim().isNotEmpty ? controller.text.trim() : 'Admin action'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              child: const Text('Suspend'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'isActive': false,
          'suspension': {'reason': result, 'suspendedAt': FieldValue.serverTimestamp(), 'suspendedBy': FirebaseAuth.instance.currentUser?.uid},
        });
        setState(() {});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User suspended'), backgroundColor: AppColors.success));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _reactivateUser(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({'isActive': true, 'suspension': FieldValue.delete()});
      setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User reactivated'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  void _approveAppeal(String appealId, String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({'isActive': true, 'suspension': FieldValue.delete()});
      await FirebaseFirestore.instance.collection('appeals').doc(appealId).update({'status': 'approved', 'reviewedAt': FieldValue.serverTimestamp(), 'reviewedBy': FirebaseAuth.instance.currentUser?.uid});
      setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appeal approved'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  void _rejectAppeal(String appealId) async {
    try {
      await FirebaseFirestore.instance.collection('appeals').doc(appealId).update({'status': 'rejected', 'reviewedAt': FieldValue.serverTimestamp(), 'reviewedBy': FirebaseAuth.instance.currentUser?.uid});
      setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appeal rejected'), backgroundColor: AppColors.warning));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  void _assignDispute(String disputeId) async {
    try {
      await FirebaseFirestore.instance.collection('disputes').doc(disputeId).update({'status': 'in_progress', 'assignedTo': FirebaseAuth.instance.currentUser?.uid, 'assignedAt': FieldValue.serverTimestamp()});
      setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispute assigned to you'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  void _resolveDispute(String disputeId) async {
    try {
      await FirebaseFirestore.instance.collection('disputes').doc(disputeId).update({'status': 'resolved', 'resolvedAt': FieldValue.serverTimestamp(), 'resolvedBy': FirebaseAuth.instance.currentUser?.uid});
      setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispute resolved'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  void _issueWarning(String violationId) async {
    try {
      await FirebaseFirestore.instance.collection('violations').doc(violationId).update({'actionTaken': 'Warning issued', 'actionDate': FieldValue.serverTimestamp(), 'actionBy': FirebaseAuth.instance.currentUser?.uid});
      setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Warning issued'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  void _suspendForViolation(String violationId) async {
    final violation = await FirebaseFirestore.instance.collection('violations').doc(violationId).get();
    final userId = violation.data()?['userId'] as String?;
    if (userId != null) {
      _suspendUser(userId);
      await FirebaseFirestore.instance.collection('violations').doc(violationId).update({'actionTaken': 'Account suspended', 'actionDate': FieldValue.serverTimestamp(), 'actionBy': FirebaseAuth.instance.currentUser?.uid});
    }
  }

  void _toggleCategoryActive(String categoryId, bool isActive) async {
    try {
      await FirebaseFirestore.instance.collection('categories').doc(categoryId).update({'isActive': isActive});
      setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  void _deleteCategory(String categoryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await FirebaseFirestore.instance.collection('categories').doc(categoryId).delete();
        setState(() {});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category deleted'), backgroundColor: AppColors.success));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  // Create/Edit dialogs
  void _showAddUserDialog() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add User - Users register through the app')));
  }

  void _showSendNotificationDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Push Notification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 16),
            TextField(controller: bodyController, decoration: const InputDecoration(labelText: 'Message'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification sent to all users'), backgroundColor: AppColors.success));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: Colors.white),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showCreateDisputeDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Dispute'),
        content: TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('disputes').add({
                  'reason': reasonController.text.trim(),
                  'status': 'open',
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': FirebaseAuth.instance.currentUser?.uid,
                });
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispute created'), backgroundColor: AppColors.success));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: Colors.white),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddViolationDialog() {
    final userIdController = TextEditingController();
    final descriptionController = TextEditingController();
    String type = 'policy_violation';
    String severity = 'warning';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Violation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: userIdController, decoration: const InputDecoration(labelText: 'User ID')),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Violation Type'),
                  items: const [
                    DropdownMenuItem(value: 'policy_violation', child: Text('Policy Violation')),
                    DropdownMenuItem(value: 'spam', child: Text('Spam')),
                    DropdownMenuItem(value: 'fraud', child: Text('Fraud')),
                    DropdownMenuItem(value: 'harassment', child: Text('Harassment')),
                  ],
                  onChanged: (v) => setState(() => type = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: severity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: const [
                    DropdownMenuItem(value: 'warning', child: Text('Warning')),
                    DropdownMenuItem(value: 'minor', child: Text('Minor')),
                    DropdownMenuItem(value: 'major', child: Text('Major')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                  ],
                  onChanged: (v) => setState(() => severity = v!),
                ),
                const SizedBox(height: 16),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (userIdController.text.trim().isNotEmpty && descriptionController.text.trim().isNotEmpty) {
                  await FirebaseFirestore.instance.collection('violations').add({
                    'userId': userIdController.text.trim(),
                    'type': type,
                    'severity': severity,
                    'description': descriptionController.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                    'createdBy': FirebaseAuth.instance.currentUser?.uid,
                  });
                  Navigator.pop(context);
                  this.setState(() {});
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Violation added'), backgroundColor: AppColors.success));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: Colors.white),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    String icon = 'category';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Category Name')),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: icon,
                decoration: const InputDecoration(labelText: 'Icon'),
                items: const [
                  DropdownMenuItem(value: 'camera', child: Text('Camera')),
                  DropdownMenuItem(value: 'music', child: Text('Music')),
                  DropdownMenuItem(value: 'cake', child: Text('Cake')),
                  DropdownMenuItem(value: 'flower', child: Text('Flower')),
                  DropdownMenuItem(value: 'car', child: Text('Car')),
                  DropdownMenuItem(value: 'dress', child: Text('Dress')),
                  DropdownMenuItem(value: 'restaurant', child: Text('Restaurant')),
                  DropdownMenuItem(value: 'decoration', child: Text('Decoration')),
                  DropdownMenuItem(value: 'category', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => icon = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final count = await FirebaseFirestore.instance.collection('categories').count().get();
                  await FirebaseFirestore.instance.collection('categories').add({
                    'name': nameController.text.trim(),
                    'icon': icon,
                    'isActive': true,
                    'order': count.count,
                    'supplierCount': 0,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
                  this.setState(() {});
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Category added'), backgroundColor: AppColors.success));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: Colors.white),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(String categoryId, Map<String, dynamic> category) {
    final nameController = TextEditingController(text: category['name'] ?? '');
    String icon = category['icon'] ?? 'category';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Category Name')),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: icon,
                decoration: const InputDecoration(labelText: 'Icon'),
                items: const [
                  DropdownMenuItem(value: 'camera', child: Text('Camera')),
                  DropdownMenuItem(value: 'music', child: Text('Music')),
                  DropdownMenuItem(value: 'cake', child: Text('Cake')),
                  DropdownMenuItem(value: 'flower', child: Text('Flower')),
                  DropdownMenuItem(value: 'car', child: Text('Car')),
                  DropdownMenuItem(value: 'dress', child: Text('Dress')),
                  DropdownMenuItem(value: 'restaurant', child: Text('Restaurant')),
                  DropdownMenuItem(value: 'decoration', child: Text('Decoration')),
                  DropdownMenuItem(value: 'category', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => icon = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  await FirebaseFirestore.instance.collection('categories').doc(categoryId).update({'name': nameController.text.trim(), 'icon': icon});
                  Navigator.pop(context);
                  this.setState(() {});
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Category updated'), backgroundColor: AppColors.success));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _openSupportChat(String chatId, Map<String, dynamic> chat) {
    // Navigate to chat detail screen
    context.push('${Routes.chatDetail}/$chatId');
  }

  void _showBroadcastMessageDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String targetRole = 'all';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.peach.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.campaign, color: AppColors.peach),
              ),
              const SizedBox(width: 12),
              const Text('Broadcast Message'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'E.g., Platform Update',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Your message to users...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text('Target Audience:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: targetRole,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(value: 'client', child: Text('Clients Only')),
                    DropdownMenuItem(value: 'supplier', child: Text('Suppliers Only')),
                  ],
                  onChanged: (value) => setDialogState(() => targetRole = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (titleController.text.trim().isEmpty || messageController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all fields'), backgroundColor: AppColors.error),
                  );
                  return;
                }

                Navigator.pop(dialogContext);

                final currentUser = FirebaseAuth.instance.currentUser;
                final adminChatNotifier = ref.read(adminChatNotifierProvider.notifier);

                final broadcastId = await adminChatNotifier.sendBroadcast(
                  title: titleController.text.trim(),
                  message: messageController.text.trim(),
                  senderId: currentUser?.uid ?? 'admin',
                  senderName: currentUser?.displayName ?? 'Admin',
                  targetRole: targetRole == 'all' ? null : targetRole,
                  priority: BroadcastPriority.normal,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(broadcastId != null ? 'Broadcast message sent!' : 'Failed to send broadcast'),
                      backgroundColor: broadcastId != null ? AppColors.success : AppColors.error,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: Colors.white),
              icon: const Icon(Icons.send),
              label: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  // Settings dialogs
  void _showCommissionDialog() {
    final controller = TextEditingController(text: _platformCommission.toStringAsFixed(1));
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.peach.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.percent, color: AppColors.peach),
              ),
              const SizedBox(width: 12),
              const Text('Platform Commission'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set the percentage fee that BODA CONNECT takes from each transaction.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Commission Percentage',
                  suffixText: '%',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                  helperText: 'Valid range: 0% - 50%',
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  setDialogState(() {
                    if (parsed == null) {
                      errorText = 'Enter a valid number';
                    } else if (parsed < 0 || parsed > 50) {
                      errorText = 'Must be between 0% and 50%';
                    } else {
                      errorText = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Example: For a 100,000 AOA booking at ${controller.text}%, platform fee = ${((double.tryParse(controller.text) ?? 0) * 1000).toStringAsFixed(0)} AOA',
                        style: const TextStyle(fontSize: 12, color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: errorText != null ? null : () async {
                final value = double.tryParse(controller.text) ?? _platformCommission;

                // Update local state
                setState(() => _platformCommission = value);

                // Save using platform settings service (handles both collections)
                try {
                  await _platformSettingsService.updateCommission(value);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Commission updated'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  debugPrint('Error saving commission: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }

                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportEmailDialog() {
    final controller = TextEditingController(text: _supportEmail);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support Email'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Email')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() => _supportEmail = controller.text.trim());
              _updateSetting('supportEmail', _supportEmail);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSupportPhoneDialog() {
    final controller = TextEditingController(text: _supportPhone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support Phone'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: '+244 923 456 789',
          ),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() => _supportPhone = controller.text.trim());
              _updateSetting('supportPhone', _supportPhone);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSupportWhatsAppDialog() {
    final controller = TextEditingController(text: _supportWhatsApp);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support WhatsApp'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'WhatsApp Number',
            hintText: '+244923456789',
            helperText: 'Enter number without spaces',
          ),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() => _supportWhatsApp = controller.text.trim().replaceAll(' ', ''));
              _updateSetting('supportWhatsApp', _supportWhatsApp);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Notification Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('New Bookings'),
                subtitle: const Text('Notify when new bookings are made'),
                value: _notifyNewBookings,
                onChanged: (v) {
                  setDialogState(() => _notifyNewBookings = v);
                  setState(() {});
                  _updateSetting('notifyNewBookings', v);
                },
              ),
              SwitchListTile(
                title: const Text('New Disputes'),
                subtitle: const Text('Notify when disputes are opened'),
                value: _notifyNewDisputes,
                onChanged: (v) {
                  setDialogState(() => _notifyNewDisputes = v);
                  setState(() {});
                  _updateSetting('notifyNewDisputes', v);
                },
              ),
              SwitchListTile(
                title: const Text('New Appeals'),
                subtitle: const Text('Notify when appeals are submitted'),
                value: _notifyNewAppeals,
                onChanged: (v) {
                  setDialogState(() => _notifyNewAppeals = v);
                  setState(() {});
                  _updateSetting('notifyNewAppeals', v);
                },
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(title: const Text('Portuguese'), value: 'pt', groupValue: 'pt', onChanged: (v) => Navigator.pop(context)),
            RadioListTile<String>(title: const Text('English'), value: 'en', groupValue: 'pt', onChanged: (v) => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  void _showAdminProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 40, backgroundColor: AppColors.peach.withValues(alpha: 0.2), child: const Icon(Icons.person, size: 40, color: AppColors.peach)),
            const SizedBox(height: 16),
            Text('Super Admin', style: AppTextStyles.h3),
            Text(FirebaseAuth.instance.currentUser?.email ?? 'admin@bodaconnect.ao', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showSecuritySettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Change Password'),
              onTap: () {
                Navigator.pop(context);
                _showChangePasswordDialog();
              },
            ),
            ListTile(leading: const Icon(Icons.security), title: const Text('Two-Factor Auth'), trailing: const Text('Enabled')),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontSize: 14),
                  ),
                ),
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock),
                  helperText: 'Minimum 8 characters',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      // Validate inputs
                      if (currentPasswordController.text.isEmpty ||
                          newPasswordController.text.isEmpty ||
                          confirmPasswordController.text.isEmpty) {
                        setDialogState(() => errorMessage = 'All fields are required');
                        return;
                      }

                      if (newPasswordController.text.length < 8) {
                        setDialogState(() => errorMessage = 'Password must be at least 8 characters');
                        return;
                      }

                      if (newPasswordController.text != confirmPasswordController.text) {
                        setDialogState(() => errorMessage = 'Passwords do not match');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null || user.email == null) {
                          throw Exception('User not authenticated');
                        }

                        // Re-authenticate user
                        final credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: currentPasswordController.text,
                        );
                        await user.reauthenticateWithCredential(credential);

                        // Update password
                        await user.updatePassword(newPasswordController.text);

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password changed successfully'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() {
                          isLoading = false;
                          if (e.code == 'wrong-password') {
                            errorMessage = 'Current password is incorrect';
                          } else {
                            errorMessage = 'Failed to change password: ${e.message}';
                          }
                        });
                      } catch (e) {
                        setDialogState(() {
                          isLoading = false;
                          errorMessage = 'Failed to change password';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.peach,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Database Backup'),
        content: const Text('Create a backup of all platform data?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup started...'), backgroundColor: AppColors.success));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: Colors.white),
            child: const Text('Create Backup'),
          ),
        ],
      ),
    );
  }
}

// ==================== ONBOARDING QUEUE WIDGET ====================

class _OnboardingQueueWidget extends StatefulWidget {
  final Future<void> Function(String supplierId) onApprove;
  final Future<void> Function(String supplierId) onReject;
  final Future<void> Function(String supplierId) onRequestChanges;
  final Future<void> Function(String supplierId) onDelete;

  const _OnboardingQueueWidget({
    required this.onApprove,
    required this.onReject,
    required this.onRequestChanges,
    required this.onDelete,
  });

  @override
  State<_OnboardingQueueWidget> createState() => _OnboardingQueueWidgetState();
}

class _OnboardingQueueWidgetState extends State<_OnboardingQueueWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.peach,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.peach,
            tabs: const [
              Tab(text: 'Pendentes'),
              Tab(text: 'Alterações'),
              Tab(text: 'Aprovados'),
              Tab(text: 'Rejeitados'),
            ],
          ),
        ),
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSupplierList('pendingReview'),
              _buildSupplierList('needsClarification'),
              _buildSupplierList('active'),
              _buildSupplierList('rejected'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('suppliers')
          .where('accountStatus', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.peach));
        }

        final suppliers = snapshot.data?.docs ?? [];

        if (suppliers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getEmptyIcon(status), size: 64, color: AppColors.gray300),
                const SizedBox(height: 16),
                Text(_getEmptyMessage(status), style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: suppliers.length,
          itemBuilder: (context, index) {
            final doc = suppliers[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildSupplierCard(doc.id, data, status);
          },
        );
      },
    );
  }

  IconData _getEmptyIcon(String status) {
    switch (status) {
      case 'pendingReview': return Icons.inbox_outlined;
      case 'needsClarification': return Icons.help_outline;
      case 'active': return Icons.store_outlined;
      case 'rejected': return Icons.cancel_outlined;
      default: return Icons.inbox_outlined;
    }
  }

  String _getEmptyMessage(String status) {
    switch (status) {
      case 'pendingReview': return 'Nenhuma candidatura pendente';
      case 'needsClarification': return 'Nenhuma alteração pendente';
      case 'active': return 'Nenhum fornecedor aprovado';
      case 'rejected': return 'Nenhum fornecedor rejeitado';
      default: return 'Nenhum fornecedor';
    }
  }

  Widget _buildSupplierCard(String supplierId, Map<String, dynamic> data, String status) {
    final businessName = data['businessName'] as String? ?? 'Fornecedor';
    final category = data['category'] as String? ?? '';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final phone = data['phone'] as String? ?? '';
    final email = data['email'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final idDocumentType = data['idDocumentType'] as String? ?? '';
    final idDocumentNumber = data['idDocumentNumber'] as String? ?? '';
    final nif = data['nif'] as String? ?? '';
    final entityType = data['entityType'] as String? ?? '';
    final photos = (data['photos'] as List<dynamic>?)?.cast<String>() ?? [];
    final profilePhoto = data['profilePhoto'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with profile photo
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile photo or icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: profilePhoto.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(profilePhoto, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 30),
                          ),
                        )
                      : Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 30),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(businessName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                          ),
                          _buildStatusBadge(status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (category.isNotEmpty) Text('Categoria: $category', style: AppTextStyles.caption),
                      if (createdAt != null)
                        Text('Registado: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Contact & Document Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contact info row
                if (phone.isNotEmpty || email.isNotEmpty)
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (phone.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(phone, style: AppTextStyles.caption),
                          ],
                        ),
                      if (email.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.email, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(email, style: AppTextStyles.caption),
                          ],
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                // Document info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Documentos', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (entityType.isNotEmpty)
                        _buildDocRow('Tipo de Entidade', entityType == 'individual' ? 'Pessoa Singular' : 'Empresa'),
                      if (idDocumentType.isNotEmpty && idDocumentNumber.isNotEmpty)
                        _buildDocRow(_getDocTypeName(idDocumentType), idDocumentNumber),
                      if (nif.isNotEmpty)
                        _buildDocRow('NIF', nif),
                      if (idDocumentType.isEmpty && idDocumentNumber.isEmpty && nif.isEmpty)
                        Text('Nenhum documento fornecido', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Description
                if (description.isNotEmpty) ...[
                  Text('Descrição', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(description, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary), maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                ],
                // Photos gallery
                if (photos.isNotEmpty) ...[
                  Text('Fotos (${photos.length})', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _showPhotoDialog(context, photos, index),
                          child: Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.gray100,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                photos[index],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: AppColors.gray400),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.photo_library_outlined, color: AppColors.warning, size: 20),
                        const SizedBox(width: 8),
                        Text('Nenhuma foto enviada', style: AppTextStyles.caption.copyWith(color: AppColors.warning)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (status == 'pendingReview' || status == 'needsClarification') ...[
                  _buildActionButton(
                    icon: Icons.check_circle,
                    label: 'Aprovar',
                    color: AppColors.success,
                    onTap: () => widget.onApprove(supplierId),
                  ),
                  _buildActionButton(
                    icon: Icons.edit_note,
                    label: 'Alterações',
                    color: Colors.orange,
                    onTap: () => widget.onRequestChanges(supplierId),
                  ),
                  _buildActionButton(
                    icon: Icons.cancel,
                    label: 'Rejeitar',
                    color: AppColors.error,
                    onTap: () => widget.onReject(supplierId),
                  ),
                ],
                if (status == 'active') ...[
                  _buildActionButton(
                    icon: Icons.block,
                    label: 'Suspender',
                    color: Colors.orange,
                    onTap: () => widget.onReject(supplierId),
                  ),
                ],
                if (status == 'rejected') ...[
                  _buildActionButton(
                    icon: Icons.refresh,
                    label: 'Reativar',
                    color: AppColors.success,
                    onTap: () => widget.onApprove(supplierId),
                  ),
                ],
                // Delete button available for all statuses
                _buildActionButton(
                  icon: Icons.delete_forever,
                  label: 'Eliminar',
                  color: AppColors.error,
                  onTap: () => widget.onDelete(supplierId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getDocTypeName(String type) {
    switch (type) {
      case 'bi': return 'Bilhete de Identidade';
      case 'passport': return 'Passaporte';
      case 'residentCard': return 'Cartão de Residente';
      default: return 'Documento';
    }
  }

  void _showPhotoDialog(BuildContext context, List<String> photos, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  child: Center(
                    child: Image.network(
                      photos[index],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 64),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pendingReview': return AppColors.warning;
      case 'needsClarification': return Colors.orange;
      case 'active': return AppColors.success;
      case 'rejected': return AppColors.error;
      default: return AppColors.gray400;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pendingReview': return Icons.hourglass_empty;
      case 'needsClarification': return Icons.help_outline;
      case 'active': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      default: return Icons.help;
    }
  }

  Widget _buildStatusBadge(String status) {
    String label;
    Color color;

    switch (status) {
      case 'pendingReview':
        label = 'Pendente';
        color = AppColors.warning;
        break;
      case 'needsClarification':
        label = 'Alterações';
        color = Colors.orange;
        break;
      case 'active':
        label = 'Aprovado';
        color = AppColors.success;
        break;
      case 'rejected':
        label = 'Rejeitado';
        color = AppColors.error;
        break;
      default:
        label = status;
        color = AppColors.gray400;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
