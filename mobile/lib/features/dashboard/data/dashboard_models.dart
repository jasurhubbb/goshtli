// Dashboard payload models — plain classes (no codegen needed; only consumed in one place each).
class BuyerDashboard {
  final int ordersPending, ordersInProgress, ordersDelivered, ordersCancelled;
  const BuyerDashboard({required this.ordersPending, required this.ordersInProgress,
                        required this.ordersDelivered, required this.ordersCancelled});
  factory BuyerDashboard.fromJson(Map<String, dynamic> j) => BuyerDashboard(
      ordersPending: j['orders_pending'] as int, ordersInProgress: j['orders_in_progress'] as int,
      ordersDelivered: j['orders_delivered'] as int, ordersCancelled: j['orders_cancelled'] as int);
}


class SupplierDashboard {
  final bool isVerified;
  final int listingsTotal, listingsActive, listingsSoldOut, listingsInactive;
  final int ordersPending, ordersInProgress, ordersDelivered, ordersCancelled;
  const SupplierDashboard({required this.isVerified, required this.listingsTotal, required this.listingsActive,
                           required this.listingsSoldOut, required this.listingsInactive,
                           required this.ordersPending, required this.ordersInProgress,
                           required this.ordersDelivered, required this.ordersCancelled});
  factory SupplierDashboard.fromJson(Map<String, dynamic> j) => SupplierDashboard(
      isVerified: j['is_verified'] as bool,
      listingsTotal: j['listings_total'] as int, listingsActive: j['listings_active'] as int,
      listingsSoldOut: j['listings_sold_out'] as int, listingsInactive: j['listings_inactive'] as int,
      ordersPending: j['orders_pending'] as int, ordersInProgress: j['orders_in_progress'] as int,
      ordersDelivered: j['orders_delivered'] as int, ordersCancelled: j['orders_cancelled'] as int);
}
