import 'package:flutter_riverpod/flutter_riverpod.dart';

// ==================== CLIENT NAVIGATION ====================

/// Client bottom navigation index provider
final clientNavIndexProvider = StateProvider<int>((ref) => 0);

/// Client navigation tabs
enum ClientNavTab {
  home(0),
  search(1),
  favorites(2),
  bookings(3),
  profile(4);

  const ClientNavTab(this.tabIndex);
  final int tabIndex;
}

// ==================== SUPPLIER NAVIGATION ====================

/// Supplier bottom navigation index provider
final supplierNavIndexProvider = StateProvider<int>((ref) => 0);

/// Supplier navigation tabs
enum SupplierNavTab {
  dashboard(0),
  packages(1),
  availability(2),
  revenue(3),
  profile(4);

  const SupplierNavTab(this.tabIndex);
  final int tabIndex;
}
