import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/services/offline_sync_service.dart';

/// Singleton connectivity instance to avoid creating multiple listeners
final _connectivity = Connectivity();

/// Provider for connectivity status - cached stream
final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  return _connectivity.onConnectivityChanged;
});

/// Provider for sync status - uses singleton service
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  return OfflineSyncService().syncStatusStream;
});

/// Provider for pending operations count
final pendingOperationsProvider = Provider<int>((ref) {
  return OfflineSyncService().pendingOperationsCount;
});

/// Network status indicator widget
/// Shows offline banner and sync status
class NetworkIndicator extends ConsumerWidget {
  final Widget child;
  final bool showSyncStatus;

  const NetworkIndicator({
    super.key,
    required this.child,
    this.showSyncStatus = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);

    return Column(
      children: [
        // Offline banner - wrapped in RepaintBoundary to prevent child repaints
        RepaintBoundary(
          child: connectivity.when(
            data: (result) {
              if (result == ConnectivityResult.none) {
                return _OfflineBanner();
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),

        // Sync status banner (if enabled) - wrapped for isolation
        if (showSyncStatus) RepaintBoundary(child: _SyncStatusBanner()),

        // Main content
        Expanded(child: child),
      ],
    );
  }
}

/// Offline banner widget
class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade700,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'network.offline'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              'network.offline_message'.tr(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sync status banner widget
class _SyncStatusBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);

    return syncStatus.when(
      data: (status) {
        switch (status) {
          case SyncStatus.syncing:
            return _StatusBanner(
              color: Colors.blue,
              icon: Icons.sync_rounded,
              text: 'network.syncing'.tr(),
              isAnimated: true,
            );
          case SyncStatus.pendingRetry:
            final count = ref.read(pendingOperationsProvider);
            return _StatusBanner(
              color: Colors.amber,
              icon: Icons.pending_rounded,
              text: 'network.sync_pending'.tr(),
              trailing: count > 0 ? '($count)' : null,
            );
          case SyncStatus.error:
            return _StatusBanner(
              color: Colors.red,
              icon: Icons.error_outline_rounded,
              text: 'errors.sync_failed'.tr(),
              onTap: () => OfflineSyncService().syncNow(),
            );
          default:
            return const SizedBox.shrink();
        }
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Status banner helper widget
class _StatusBanner extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String text;
  final String? trailing;
  final bool isAnimated;
  final VoidCallback? onTap;

  const _StatusBanner({
    required this.color,
    required this.icon,
    required this.text,
    this.trailing,
    this.isAnimated = false,
    this.onTap,
  });

  @override
  State<_StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<_StatusBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.isAnimated) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: widget.color,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            widget.isAnimated
                ? RotationTransition(
                    turns: _controller,
                    child: Icon(widget.icon, color: Colors.white, size: 14),
                  )
                : Icon(widget.icon, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              widget.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 4),
              Text(
                widget.trailing!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact network status icon for app bars
class NetworkStatusIcon extends ConsumerWidget {
  final double size;
  final Color? onlineColor;
  final Color? offlineColor;

  const NetworkStatusIcon({
    super.key,
    this.size = 20,
    this.onlineColor,
    this.offlineColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);

    return connectivity.when(
      data: (result) {
        final isOnline = result != ConnectivityResult.none;
        return Icon(
          isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
          size: size,
          color: isOnline
              ? (onlineColor ?? Colors.green)
              : (offlineColor ?? Colors.red),
        );
      },
      loading: () => Icon(
        Icons.wifi_rounded,
        size: size,
        color: Colors.grey,
      ),
      error: (_, __) => Icon(
        Icons.wifi_off_rounded,
        size: size,
        color: offlineColor ?? Colors.red,
      ),
    );
  }
}
