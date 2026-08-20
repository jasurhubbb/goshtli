// Dashboard payload models — plain classes (no codegen needed; only consumed in one place each).
class BuyerDashboard {
  final int ordersPending, ordersInProgress, ordersDelivered, ordersCancelled;
  const BuyerDashboard({
    required this.ordersPending,
    required this.ordersInProgress,
    required this.ordersDelivered,
    required this.ordersCancelled,
  });
  factory BuyerDashboard.fromJson(Map<String, dynamic> j) => BuyerDashboard(
    ordersPending: j['orders_pending'] as int,
    ordersInProgress: j['orders_in_progress'] as int,
    ordersDelivered: j['orders_delivered'] as int,
    ordersCancelled: j['orders_cancelled'] as int,
  );
}
