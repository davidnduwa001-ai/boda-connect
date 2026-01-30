import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/supplier_view_provider.dart';
import '../../../../core/providers/client_view_provider.dart';
import '../../../../core/providers/supplier_provider.dart';

/// Debug panel to diagnose projection loading issues
///
/// Usage:
/// Add this to your dashboard screen:
/// ```dart
/// if (kDebugMode) DebugProjectionPanel()
/// ```
class DebugProjectionPanel extends ConsumerWidget {
  const DebugProjectionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🐛 DEBUG: Projection Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 12),

          // User info
          _buildDebugRow('User ID', user?.uid ?? 'NOT LOGGED IN',
              user != null ? Colors.green : Colors.red),
          _buildDebugRow('Email', user?.email ?? 'N/A', Colors.grey),

          const Divider(height: 24),

          // Supplier View Status
          _buildSupplierViewStatus(ref),

          const Divider(height: 24),

          // Client View Status
          _buildClientViewStatus(ref),

          const SizedBox(height: 12),

          // Test button
          ElevatedButton.icon(
            onPressed: () => _runProjectionTest(context, ref),
            icon: const Icon(Icons.bug_report),
            label: const Text('Run Projection Test'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierViewStatus(WidgetRef ref) {
    final viewState = ref.watch(supplierViewProvider);
    final supplierState = ref.read(supplierProvider);
    final supplierId = supplierState.currentSupplier?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SUPPLIER VIEW', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildDebugRow('Supplier ID', supplierId ?? 'NULL',
            supplierId != null ? Colors.green : Colors.red),
        _buildDebugRow('Loading', viewState.isLoading.toString(),
            viewState.isLoading ? Colors.orange : Colors.green),
        _buildDebugRow('Error', viewState.error ?? 'none',
            viewState.error != null ? Colors.red : Colors.green),
        _buildDebugRow('Has Data', (viewState.view != null).toString(),
            viewState.view != null ? Colors.green : Colors.red),

        if (viewState.view != null) ...[
          const SizedBox(height: 8),
          _buildDebugRow('Pending Bookings', '${viewState.view!.pendingBookings.length}', Colors.blue),
          _buildDebugRow('Confirmed Bookings', '${viewState.view!.confirmedBookings.length}', Colors.blue),
          _buildDebugRow('Recent Bookings', '${viewState.view!.recentBookings.length}', Colors.blue),
          _buildDebugRow('Upcoming Events', '${viewState.view!.upcomingEvents.length}', Colors.blue),
        ],
      ],
    );
  }

  Widget _buildClientViewStatus(WidgetRef ref) {
    final viewState = ref.watch(clientViewProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CLIENT VIEW', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildDebugRow('Loading', viewState.isLoading.toString(),
            viewState.isLoading ? Colors.orange : Colors.green),
        _buildDebugRow('Error', viewState.error ?? 'none',
            viewState.error != null ? Colors.red : Colors.green),
        _buildDebugRow('Has Data', (viewState.view != null).toString(),
            viewState.view != null ? Colors.green : Colors.red),

        if (viewState.view != null) ...[
          const SizedBox(height: 8),
          _buildDebugRow('Active Bookings', '${viewState.view!.activeBookings.length}', Colors.blue),
          _buildDebugRow('Recent Bookings', '${viewState.view!.recentBookings.length}', Colors.blue),
          _buildDebugRow('Upcoming Events', '${viewState.view!.upcomingEvents.length}', Colors.blue),
        ],
      ],
    );
  }

  Widget _buildDebugRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runProjectionTest(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('❌ Not logged in'), backgroundColor: Colors.red),
      );
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('🔍 Testing Firestore read...')),
    );

    try {
      // Test supplier view read
      final supplierState = ref.read(supplierProvider);
      final supplierId = supplierState.currentSupplier?.id;

      if (supplierId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('supplier_views')
            .doc(supplierId)
            .get();

        if (doc.exists) {
          final data = doc.data();
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                '✅ Supplier projection exists!\n'
                'Pending: ${(data?['pendingBookings'] as List?)?.length ?? 0}\n'
                'Recent: ${(data?['recentBookings'] as List?)?.length ?? 0}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text('❌ No supplier_views/$supplierId document found!'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }

      // Test client view read
      final clientDoc = await FirebaseFirestore.instance
          .collection('client_views')
          .doc(user.uid)
          .get();

      if (clientDoc.exists) {
        final data = clientDoc.data();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '✅ Client projection exists!\n'
              'Active: ${(data?['activeBookings'] as List?)?.length ?? 0}\n'
              'Recent: ${(data?['recentBookings'] as List?)?.length ?? 0}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('❌ No client_views/${user.uid} document found!'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on FirebaseException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Firestore error: ${e.code}\n${e.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
