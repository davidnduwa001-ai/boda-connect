import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/providers/navigation_provider.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shared bottom navigation bar for client screens
class ClientBottomNav extends ConsumerWidget {
  const ClientBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                index: ClientNavTab.home.tabIndex,
                icon: Icons.home_rounded,
                label: 'Início',
                route: Routes.clientHome,
              ),
              _NavItem(
                index: ClientNavTab.search.tabIndex,
                icon: Icons.search_rounded,
                label: 'Pesquisar',
                route: Routes.clientSearch,
              ),
              _NavItem(
                index: ClientNavTab.favorites.tabIndex,
                icon: Icons.favorite_rounded,
                label: 'Favoritos',
                route: Routes.clientFavorites,
              ),
              _NavItem(
                index: ClientNavTab.bookings.tabIndex,
                icon: Icons.calendar_month_rounded,
                label: 'Reservas',
                route: Routes.clientBookings,
              ),
              _NavItem(
                index: ClientNavTab.profile.tabIndex,
                icon: Icons.person_rounded,
                label: 'Perfil',
                route: Routes.clientProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.route,
  });

  final int index;
  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(clientNavIndexProvider);
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (currentIndex == index) return;

        ref.read(clientNavIndexProvider.notifier).state = index;
        context.go(route);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.peach.withValues(alpha: 0.15),
                    AppColors.peach.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: EdgeInsets.all(isSelected ? 8 : 4),
              decoration: isSelected
                  ? BoxDecoration(
                      color: AppColors.peach,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.peach.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    )
                  : null,
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: isSelected ? 24 : 22,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              style: TextStyle(
                fontSize: isSelected ? 11 : 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.peach : AppColors.textSecondary,
                letterSpacing: isSelected ? 0.2 : 0,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
