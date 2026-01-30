import 'package:boda_connect/core/models/booking_model.dart';
import 'package:boda_connect/core/providers/booking_provider.dart';
import 'package:boda_connect/core/providers/supplier_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dashboard Statistics Model
class DashboardStats {
  final int ordersToday;
  final int monthlyRevenue;
  final double rating;
  final int responseRate;
  final int pendingOrders;
  final int confirmedOrders;
  final int completedOrders;
  final List<BookingModel> recentOrders;
  final List<BookingModel> upcomingEvents;

  const DashboardStats({
    this.ordersToday = 0,
    this.monthlyRevenue = 0,
    this.rating = 0.0,
    this.responseRate = 0,
    this.pendingOrders = 0,
    this.confirmedOrders = 0,
    this.completedOrders = 0,
    this.recentOrders = const [],
    this.upcomingEvents = const [],
  });

  DashboardStats copyWith({
    int? ordersToday,
    int? monthlyRevenue,
    double? rating,
    int? responseRate,
    int? pendingOrders,
    int? confirmedOrders,
    int? completedOrders,
    List<BookingModel>? recentOrders,
    List<BookingModel>? upcomingEvents,
  }) {
    return DashboardStats(
      ordersToday: ordersToday ?? this.ordersToday,
      monthlyRevenue: monthlyRevenue ?? this.monthlyRevenue,
      rating: rating ?? this.rating,
      responseRate: responseRate ?? this.responseRate,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      confirmedOrders: confirmedOrders ?? this.confirmedOrders,
      completedOrders: completedOrders ?? this.completedOrders,
      recentOrders: recentOrders ?? this.recentOrders,
      upcomingEvents: upcomingEvents ?? this.upcomingEvents,
    );
  }

  /// Format monthly revenue for display
  String get formattedRevenue {
    if (monthlyRevenue >= 1000000) {
      return '${(monthlyRevenue / 1000000).toStringAsFixed(1)}M';
    } else if (monthlyRevenue >= 1000) {
      return '${(monthlyRevenue / 1000).toStringAsFixed(0)}K';
    }
    return monthlyRevenue.toString();
  }

  /// Format rating for display
  String get formattedRating {
    return rating > 0 ? rating.toStringAsFixed(1) : '0.0';
  }
}

/// Enhanced Analytics Model with detailed metrics
class SupplierAnalytics {
  // Revenue metrics
  final int totalRevenue;
  final int monthlyRevenue;
  final int weeklyRevenue;
  final int todayRevenue;
  final List<RevenueDataPoint> revenueHistory;
  final double revenueGrowthPercent;

  // Booking metrics
  final int totalBookings;
  final int monthlyBookings;
  final int weeklyBookings;
  final int todayBookings;
  final double conversionRate;
  final double cancellationRate;
  final int averageBookingValue;

  // Performance metrics
  final double rating;
  final int totalReviews;
  final int responseRate;
  final int averageResponseTimeMinutes;
  final int profileViews;
  final int packageViews;

  // Booking status breakdown
  final int pendingBookings;
  final int confirmedBookings;
  final int completedBookings;
  final int cancelledBookings;

  // Package performance
  final List<PackageAnalytics> topPackages;

  // Time-based insights
  final Map<int, int> bookingsByDayOfWeek;
  final Map<int, int> bookingsByMonth;
  final String peakBookingDay;
  final String peakBookingMonth;

  const SupplierAnalytics({
    this.totalRevenue = 0,
    this.monthlyRevenue = 0,
    this.weeklyRevenue = 0,
    this.todayRevenue = 0,
    this.revenueHistory = const [],
    this.revenueGrowthPercent = 0.0,
    this.totalBookings = 0,
    this.monthlyBookings = 0,
    this.weeklyBookings = 0,
    this.todayBookings = 0,
    this.conversionRate = 0.0,
    this.cancellationRate = 0.0,
    this.averageBookingValue = 0,
    this.rating = 0.0,
    this.totalReviews = 0,
    this.responseRate = 0,
    this.averageResponseTimeMinutes = 0,
    this.profileViews = 0,
    this.packageViews = 0,
    this.pendingBookings = 0,
    this.confirmedBookings = 0,
    this.completedBookings = 0,
    this.cancelledBookings = 0,
    this.topPackages = const [],
    this.bookingsByDayOfWeek = const {},
    this.bookingsByMonth = const {},
    this.peakBookingDay = '-',
    this.peakBookingMonth = '-',
  });

  String formatRevenue(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M Kz';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K Kz';
    }
    return '$amount Kz';
  }

  String get formattedTotalRevenue => formatRevenue(totalRevenue);
  String get formattedMonthlyRevenue => formatRevenue(monthlyRevenue);
  String get formattedWeeklyRevenue => formatRevenue(weeklyRevenue);
  String get formattedTodayRevenue => formatRevenue(todayRevenue);
  String get formattedAverageBookingValue => formatRevenue(averageBookingValue);
}

/// Revenue data point for charts
class RevenueDataPoint {
  final DateTime date;
  final int amount;
  final String label;

  const RevenueDataPoint({
    required this.date,
    required this.amount,
    required this.label,
  });
}

/// Package performance analytics
class PackageAnalytics {
  final String packageId;
  final String packageName;
  final int bookingCount;
  final int revenue;
  final double averageRating;

  const PackageAnalytics({
    required this.packageId,
    required this.packageName,
    this.bookingCount = 0,
    this.revenue = 0,
    this.averageRating = 0.0,
  });
}

/// Dashboard Stats Provider
/// Calculates real-time statistics from bookings and supplier data
final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  // Watch booking state
  final bookingState = ref.watch(bookingProvider);

  // Watch supplier state to get rating and response rate
  final supplierState = ref.watch(supplierProvider);

  final supplierBookings = bookingState.supplierBookings;
  final currentSupplier = supplierState.currentSupplier;

  // Calculate orders today
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final ordersToday = supplierBookings.where((booking) {
    final bookingDate = DateTime(
      booking.createdAt.year,
      booking.createdAt.month,
      booking.createdAt.day,
    );
    return bookingDate.isAtSameMomentAs(today);
  }).length;

  // Calculate monthly revenue
  final currentMonth = DateTime(now.year, now.month);
  final monthlyRevenue = supplierBookings.where((booking) {
    final bookingMonth = DateTime(
      booking.eventDate.year,
      booking.eventDate.month,
    );
    return bookingMonth.isAtSameMomentAs(currentMonth) &&
        (booking.status == BookingStatus.confirmed ||
            booking.status == BookingStatus.completed);
  }).fold<int>(0, (sum, booking) => sum + booking.totalPrice);

  // Get rating from supplier profile
  final rating = currentSupplier?.rating ?? 0.0;

  // Get response rate from supplier profile
  final responseRate = currentSupplier?.responseRate.toInt() ?? 0;

  // Count orders by status
  final pendingOrders = supplierBookings
      .where((b) => b.status == BookingStatus.pending)
      .length;

  final confirmedOrders = supplierBookings
      .where((b) => b.status == BookingStatus.confirmed)
      .length;

  final completedOrders = supplierBookings
      .where((b) => b.status == BookingStatus.completed)
      .length;

  // Get recent orders (last 5 bookings sorted by creation date)
  final recentOrders = List<BookingModel>.from(supplierBookings)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final recentOrdersList = recentOrders.take(5).toList();

  // Get upcoming events (future confirmed bookings sorted by event date)
  final upcomingEvents = supplierBookings
      .where((b) =>
          (b.status == BookingStatus.confirmed ||
              b.status == BookingStatus.pending) &&
          b.eventDate.isAfter(now))
      .toList()
    ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
  final upcomingEventsList = upcomingEvents.take(5).toList();

  return DashboardStats(
    ordersToday: ordersToday,
    monthlyRevenue: monthlyRevenue,
    rating: rating,
    responseRate: responseRate,
    pendingOrders: pendingOrders,
    confirmedOrders: confirmedOrders,
    completedOrders: completedOrders,
    recentOrders: recentOrdersList,
    upcomingEvents: upcomingEventsList,
  );
});

/// Provider to check if supplier has loaded their bookings
final hasLoadedBookingsProvider = Provider<bool>((ref) {
  final bookingState = ref.watch(bookingProvider);
  return bookingState.supplierBookings.isNotEmpty || !bookingState.isLoading;
});

/// Enhanced Supplier Analytics Provider
/// Provides detailed analytics for the supplier dashboard
final supplierAnalyticsProvider = Provider<SupplierAnalytics>((ref) {
  final bookingState = ref.watch(bookingProvider);
  final supplierState = ref.watch(supplierProvider);

  final allBookings = bookingState.supplierBookings;
  final currentSupplier = supplierState.currentSupplier;
  final packages = supplierState.packages;

  if (allBookings.isEmpty) {
    return SupplierAnalytics(
      rating: currentSupplier?.rating ?? 0.0,
      totalReviews: currentSupplier?.reviewCount ?? 0,
      responseRate: currentSupplier?.responseRate.toInt() ?? 0,
    );
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekAgo = today.subtract(const Duration(days: 7));
  final monthStart = DateTime(now.year, now.month, 1);
  final lastMonthStart = DateTime(now.year, now.month - 1, 1);

  // Revenue calculations
  int calculateRevenue(List<BookingModel> bookings) {
    return bookings
        .where((b) =>
            b.status == BookingStatus.confirmed ||
            b.status == BookingStatus.completed)
        .fold<int>(0, (sum, b) => sum + b.totalPrice);
  }

  final totalRevenue = calculateRevenue(allBookings);

  final monthlyBookingsList = allBookings.where((b) {
    return b.createdAt.isAfter(monthStart) ||
           (b.createdAt.year == monthStart.year &&
            b.createdAt.month == monthStart.month &&
            b.createdAt.day == monthStart.day);
  }).toList();
  final monthlyRevenue = calculateRevenue(monthlyBookingsList);

  final weeklyBookingsList = allBookings.where((b) {
    return b.createdAt.isAfter(weekAgo);
  }).toList();
  final weeklyRevenue = calculateRevenue(weeklyBookingsList);

  final todayBookingsList = allBookings.where((b) {
    final bookingDate = DateTime(
      b.createdAt.year,
      b.createdAt.month,
      b.createdAt.day,
    );
    return bookingDate.isAtSameMomentAs(today);
  }).toList();
  final todayRevenue = calculateRevenue(todayBookingsList);

  // Last month revenue for growth calculation
  final lastMonthBookings = allBookings.where((b) {
    final bookingMonth = DateTime(b.createdAt.year, b.createdAt.month);
    return bookingMonth.isAtSameMomentAs(lastMonthStart);
  }).toList();
  final lastMonthRevenue = calculateRevenue(lastMonthBookings);

  // Calculate revenue growth percent
  double revenueGrowth = 0.0;
  if (lastMonthRevenue > 0) {
    revenueGrowth = ((monthlyRevenue - lastMonthRevenue) / lastMonthRevenue) * 100;
  } else if (monthlyRevenue > 0) {
    revenueGrowth = 100.0;
  }

  // Generate revenue history (last 6 months)
  final revenueHistory = <RevenueDataPoint>[];
  for (int i = 5; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final monthBookings = allBookings.where((b) {
      final bookingMonth = DateTime(b.createdAt.year, b.createdAt.month);
      return bookingMonth.year == month.year && bookingMonth.month == month.month;
    }).toList();
    final revenue = calculateRevenue(monthBookings);

    final monthNames = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    revenueHistory.add(RevenueDataPoint(
      date: month,
      amount: revenue,
      label: monthNames[month.month - 1],
    ));
  }

  // Booking counts
  final totalBookings = allBookings.length;
  final monthlyBookings = monthlyBookingsList.length;
  final weeklyBookings = weeklyBookingsList.length;
  final todayBookings = todayBookingsList.length;

  // Status breakdown
  final pendingBookings = allBookings.where((b) => b.status == BookingStatus.pending).length;
  final confirmedBookings = allBookings.where((b) => b.status == BookingStatus.confirmed).length;
  final completedBookings = allBookings.where((b) => b.status == BookingStatus.completed).length;
  final cancelledBookings = allBookings.where((b) => b.status == BookingStatus.cancelled).length;

  // Conversion and cancellation rates
  final conversionRate = totalBookings > 0
      ? ((confirmedBookings + completedBookings) / totalBookings) * 100
      : 0.0;
  final cancellationRate = totalBookings > 0
      ? (cancelledBookings / totalBookings) * 100
      : 0.0;

  // Average booking value
  final paidBookings = allBookings.where((b) =>
      b.status == BookingStatus.confirmed || b.status == BookingStatus.completed);
  final averageBookingValue = paidBookings.isNotEmpty
      ? (paidBookings.fold<int>(0, (sum, b) => sum + b.totalPrice) / paidBookings.length).round()
      : 0;

  // Bookings by day of week
  final bookingsByDayOfWeek = <int, int>{};
  for (var i = 1; i <= 7; i++) {
    bookingsByDayOfWeek[i] = 0;
  }
  for (final booking in allBookings) {
    final dayOfWeek = booking.eventDate.weekday;
    bookingsByDayOfWeek[dayOfWeek] = (bookingsByDayOfWeek[dayOfWeek] ?? 0) + 1;
  }

  // Peak booking day
  final dayNames = ['', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
  var peakDay = 1;
  var maxBookingsDay = 0;
  bookingsByDayOfWeek.forEach((day, count) {
    if (count > maxBookingsDay) {
      maxBookingsDay = count;
      peakDay = day;
    }
  });
  final peakBookingDay = maxBookingsDay > 0 ? dayNames[peakDay] : '-';

  // Bookings by month
  final bookingsByMonth = <int, int>{};
  for (var i = 1; i <= 12; i++) {
    bookingsByMonth[i] = 0;
  }
  for (final booking in allBookings) {
    final month = booking.eventDate.month;
    bookingsByMonth[month] = (bookingsByMonth[month] ?? 0) + 1;
  }

  // Peak booking month
  final monthNames = ['', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
                       'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
  var peakMonth = 1;
  var maxBookingsMonth = 0;
  bookingsByMonth.forEach((month, count) {
    if (count > maxBookingsMonth) {
      maxBookingsMonth = count;
      peakMonth = month;
    }
  });
  final peakBookingMonth = maxBookingsMonth > 0 ? monthNames[peakMonth] : '-';

  // Top packages by bookings
  final packageBookings = <String, int>{};
  final packageRevenue = <String, int>{};
  for (final booking in allBookings) {
    final packageId = booking.packageId;
    packageBookings[packageId] = (packageBookings[packageId] ?? 0) + 1;
    if (booking.status == BookingStatus.confirmed || booking.status == BookingStatus.completed) {
      packageRevenue[packageId] = (packageRevenue[packageId] ?? 0) + booking.totalPrice;
    }
  }

  final topPackages = <PackageAnalytics>[];
  final sortedPackageIds = packageBookings.keys.toList()
    ..sort((a, b) => (packageBookings[b] ?? 0).compareTo(packageBookings[a] ?? 0));

  for (final packageId in sortedPackageIds.take(5)) {
    final package = packages.where((p) => p.id == packageId).firstOrNull;
    topPackages.add(PackageAnalytics(
      packageId: packageId,
      packageName: package?.name ?? 'Pacote Desconhecido',
      bookingCount: packageBookings[packageId] ?? 0,
      revenue: packageRevenue[packageId] ?? 0,
    ));
  }

  return SupplierAnalytics(
    totalRevenue: totalRevenue,
    monthlyRevenue: monthlyRevenue,
    weeklyRevenue: weeklyRevenue,
    todayRevenue: todayRevenue,
    revenueHistory: revenueHistory,
    revenueGrowthPercent: revenueGrowth,
    totalBookings: totalBookings,
    monthlyBookings: monthlyBookings,
    weeklyBookings: weeklyBookings,
    todayBookings: todayBookings,
    conversionRate: conversionRate,
    cancellationRate: cancellationRate,
    averageBookingValue: averageBookingValue,
    rating: currentSupplier?.rating ?? 0.0,
    totalReviews: currentSupplier?.reviewCount ?? 0,
    responseRate: currentSupplier?.responseRate.toInt() ?? 0,
    averageResponseTimeMinutes: 30, // Placeholder - would need chat data
    profileViews: 0, // Would need to track views in Firestore
    packageViews: 0, // Would need to track views in Firestore
    pendingBookings: pendingBookings,
    confirmedBookings: confirmedBookings,
    completedBookings: completedBookings,
    cancelledBookings: cancelledBookings,
    topPackages: topPackages,
    bookingsByDayOfWeek: bookingsByDayOfWeek,
    bookingsByMonth: bookingsByMonth,
    peakBookingDay: peakBookingDay,
    peakBookingMonth: peakBookingMonth,
  );
});
