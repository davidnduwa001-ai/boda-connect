import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/models/supplier_stats_model.dart';
import '../../../../core/providers/supplier_stats_provider.dart';

/// A reusable widget for displaying supplier statistics in a grid layout
/// Supports both compact (3-column) and expanded (5-column) modes
class StatsGridWidget extends ConsumerWidget {
  final String supplierId;
  final bool showTenure;
  final bool showLeads;
  final bool compact;
  final EdgeInsetsGeometry? padding;

  const StatsGridWidget({
    super.key,
    required this.supplierId,
    this.showTenure = false,
    this.showLeads = false,
    this.compact = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(supplierStatsStreamProvider(supplierId));

    return statsAsync.when(
      loading: () => _buildLoadingState(),
      error: (e, _) => _buildErrorState(),
      data: (stats) => _buildStatsGrid(stats),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: padding ?? const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: List.generate(
          compact ? 3 : 5,
          (_) => Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.peach,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: padding ?? const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: [
          _StatCard(value: '0', label: 'Visualizações'),
          const SizedBox(width: AppDimensions.sm),
          _StatCard(value: '0', label: 'Favoritos'),
          const SizedBox(width: AppDimensions.sm),
          _StatCard(value: '0', label: 'Reservas'),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(SupplierStatsModel stats) {
    final cards = <Widget>[];

    // Views (Visualizações)
    cards.add(_StatCard(
      value: _formatNumber(stats.viewCount),
      label: 'Visualizações',
      icon: Icons.visibility_outlined,
      tooltip: 'Vezes que seu perfil foi visualizado',
    ));

    // Favorites (Favoritos)
    cards.add(_StatCard(
      value: _formatNumber(stats.favoriteCount),
      label: 'Favoritos',
      icon: Icons.favorite_outline,
      tooltip: 'Usuários que salvaram seu perfil',
    ));

    // Reservations (Reservas) - Confirmed bookings
    cards.add(_StatCard(
      value: _formatNumber(stats.confirmedBookings),
      label: 'Reservas',
      icon: Icons.calendar_today_outlined,
      tooltip: 'Reservas confirmadas',
    ));

    // Jobs Done (Trabalhos) - Completed bookings
    if (!compact || showLeads) {
      cards.add(_StatCard(
        value: _formatNumber(stats.completedBookings),
        label: 'Concluídos',
        icon: Icons.check_circle_outline,
        tooltip: 'Trabalhos finalizados com sucesso',
      ));
    }

    // Tenure (Tempo na plataforma)
    if (showTenure || !compact) {
      cards.add(_StatCard(
        value: stats.tenureDisplay,
        label: 'Na Plataforma',
        icon: Icons.schedule_outlined,
        tooltip: stats.memberSinceDisplay,
      ));
    }

    return Container(
      margin: padding ?? const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: cards.map((card) {
          final index = cards.indexOf(card);
          return Expanded(
            child: Row(
              children: [
                if (index > 0) const SizedBox(width: AppDimensions.sm),
                Expanded(child: card),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}

/// Individual stat card widget
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final String? tooltip;

  const _StatCard({
    required this.value,
    required this.label,
    this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.peach.withValues(alpha: 0.7)),
            const SizedBox(height: 4),
          ],
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.peachDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: card,
      );
    }

    return card;
  }
}

/// Extended stats widget with detailed breakdowns
class DetailedStatsWidget extends ConsumerWidget {
  final String supplierId;

  const DetailedStatsWidget({
    super.key,
    required this.supplierId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsState = ref.watch(supplierStatsProvider(supplierId));

    if (statsState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.peach),
      );
    }

    final stats = statsState.stats;
    if (stats == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estatísticas Detalhadas',
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppDimensions.md),
          _buildStatRow(
            icon: Icons.visibility,
            label: 'Visualizações do Perfil',
            value: stats.viewCount.toString(),
            subValue: statsState.viewStats != null
                ? '+${statsState.viewStats!.thisWeek} esta semana'
                : null,
          ),
          const Divider(height: 24),
          _buildStatRow(
            icon: Icons.touch_app,
            label: 'Interações (Leads)',
            value: stats.leadCount.toString(),
            subValue: 'Cliques em contacto',
          ),
          const Divider(height: 24),
          _buildStatRow(
            icon: Icons.favorite,
            label: 'Favoritos',
            value: stats.favoriteCount.toString(),
            subValue: 'Perfis que te salvaram',
          ),
          const Divider(height: 24),
          _buildStatRow(
            icon: Icons.calendar_today,
            label: 'Reservas Confirmadas',
            value: stats.confirmedBookings.toString(),
            subValue: 'Taxa de conversão: ${stats.conversionRate.toStringAsFixed(1)}%',
          ),
          const Divider(height: 24),
          _buildStatRow(
            icon: Icons.check_circle,
            label: 'Trabalhos Concluídos',
            value: stats.completedBookings.toString(),
            subValue: 'Taxa de sucesso: ${stats.successRate.toStringAsFixed(1)}%',
          ),
          const Divider(height: 24),
          _buildStatRow(
            icon: Icons.schedule,
            label: 'Tempo na Plataforma',
            value: stats.tenureDisplay,
            subValue: stats.memberSinceDisplay,
          ),
          const Divider(height: 24),
          _buildStatRow(
            icon: Icons.star,
            label: 'Avaliação',
            value: stats.rating.toStringAsFixed(1),
            subValue: '${stats.reviewCount} avaliações',
            valueColor: AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    String? subValue,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.peach.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.peach, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subValue != null)
                Text(
                  subValue,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: AppTextStyles.h3.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.peachDark,
          ),
        ),
      ],
    );
  }
}

/// Compact badge-style stats for cards
class StatsBadgesWidget extends StatelessWidget {
  final int views;
  final int favorites;
  final int bookings;
  final bool showIcons;

  const StatsBadgesWidget({
    super.key,
    required this.views,
    required this.favorites,
    required this.bookings,
    this.showIcons = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBadge(
          icon: Icons.visibility_outlined,
          value: _formatNumber(views),
          showIcon: showIcons,
        ),
        const SizedBox(width: 12),
        _buildBadge(
          icon: Icons.favorite_outline,
          value: _formatNumber(favorites),
          showIcon: showIcons,
        ),
        const SizedBox(width: 12),
        _buildBadge(
          icon: Icons.check_circle_outline,
          value: _formatNumber(bookings),
          showIcon: showIcons,
        ),
      ],
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String value,
    required bool showIcon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) ...[
          Icon(icon, size: 14, color: AppColors.gray400),
          const SizedBox(width: 4),
        ],
        Text(
          value,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}

/// Stats summary for dashboard cards
class StatsRowWidget extends StatelessWidget {
  final int views;
  final int favorites;
  final int bookings;
  final int completed;

  const StatsRowWidget({
    super.key,
    required this.views,
    required this.favorites,
    required this.bookings,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat(Icons.visibility_outlined, views, 'Views'),
          _buildDivider(),
          _buildMiniStat(Icons.favorite_outline, favorites, 'Favoritos'),
          _buildDivider(),
          _buildMiniStat(Icons.calendar_today_outlined, bookings, 'Reservas'),
          _buildDivider(),
          _buildMiniStat(Icons.check_circle_outline, completed, 'Feitos'),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, int value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.peach),
          const SizedBox(height: 4),
          Text(
            _formatNumber(value),
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: AppColors.border,
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}
