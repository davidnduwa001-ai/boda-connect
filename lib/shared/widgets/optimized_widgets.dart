import 'package:flutter/material.dart';

/// Wraps a widget in a RepaintBoundary to prevent unnecessary repaints
/// Use for complex widgets that don't change often
class OptimizedContainer extends StatelessWidget {
  final Widget child;
  final bool addRepaintBoundary;

  const OptimizedContainer({
    super.key,
    required this.child,
    this.addRepaintBoundary = true,
  });

  @override
  Widget build(BuildContext context) {
    if (addRepaintBoundary) {
      return RepaintBoundary(child: child);
    }
    return child;
  }
}

/// An optimized ListView that automatically handles performance best practices:
/// - Uses addAutomaticKeepAlives for caching
/// - Uses addRepaintBoundaries for isolation
/// - Provides lazy loading support
class OptimizedListView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final int? cacheExtent;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final Widget? loadingWidget;
  final Widget? emptyWidget;

  const OptimizedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.separatorBuilder,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.cacheExtent,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.loadingWidget,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyWidget != null) {
      return emptyWidget!;
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (onLoadMore != null &&
            notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200) {
          onLoadMore!();
        }
        return false;
      },
      child: ListView.builder(
        controller: controller,
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: physics ?? const AlwaysScrollableScrollPhysics(),
        cacheExtent: cacheExtent?.toDouble() ?? 500,
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
        itemCount: items.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return loadingWidget ??
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
          }

          final item = items[index];
          final widget = itemBuilder(context, item, index);

          if (separatorBuilder != null && index < items.length - 1) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget,
                separatorBuilder!(context, index),
              ],
            );
          }

          return widget;
        },
      ),
    );
  }
}

/// An optimized GridView for displaying items in a grid layout
class OptimizedGridView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final Widget? emptyWidget;

  const OptimizedGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.childAspectRatio = 1.0,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyWidget != null) {
      return emptyWidget!;
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (onLoadMore != null &&
            notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200) {
          onLoadMore!();
        }
        return false;
      },
      child: GridView.builder(
        controller: controller,
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: physics ?? const AlwaysScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return RepaintBoundary(
            child: itemBuilder(context, items[index], index),
          );
        },
      ),
    );
  }
}

/// A widget that defers expensive builds until after the first frame
/// Useful for screens with many widgets
class DeferredBuilder extends StatefulWidget {
  final Widget Function(BuildContext context) builder;
  final Widget? placeholder;
  final Duration delay;

  const DeferredBuilder({
    super.key,
    required this.builder,
    this.placeholder,
    this.delay = Duration.zero,
  });

  @override
  State<DeferredBuilder> createState() => _DeferredBuilderState();
}

class _DeferredBuilderState extends State<DeferredBuilder> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.delay == Duration.zero) {
        if (mounted) setState(() => _isReady = true);
      } else {
        Future.delayed(widget.delay, () {
          if (mounted) setState(() => _isReady = true);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return widget.placeholder ?? const SizedBox.shrink();
    }
    return widget.builder(context);
  }
}

/// Optimized scroll physics for smoother scrolling on low-end devices
class OptimizedScrollPhysics extends ScrollPhysics {
  const OptimizedScrollPhysics({super.parent});

  @override
  OptimizedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return OptimizedScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingVelocity => 50.0; // Lower threshold for fling detection

  @override
  double get maxFlingVelocity => 8000.0; // Cap max velocity for smoothness

  @override
  double carriedMomentum(double existingVelocity) {
    return existingVelocity.sign *
           (existingVelocity.abs() * 0.5).clamp(0.0, 500.0);
  }
}

/// A shimmer loading placeholder for better perceived performance
class ShimmerPlaceholder extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.baseColor ?? Colors.grey[300]!;
    final highlightColor = widget.highlightColor ?? Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_animation.value - 1).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 1).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
