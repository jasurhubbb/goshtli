// Riverpod providers for orders — repository plus async data providers used by orders screens.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/order.dart' as model;
import '../../../shared/models/paginated.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/orders_repository.dart';


final ordersRepositoryProvider = Provider<OrdersRepository>((ref) => OrdersRepository(ref.watch(apiClientProvider)));


/// Filter state for the orders list — held simply, since orders are scoped to the calling user role.
final orderStatusFilterProvider = StateProvider<model.OrderStatus?>((ref) => null);


/// Buyer's order history — autoDispose so cache resets when leaving + invalidated after place/cancel.
final myOrdersProvider = FutureProvider.autoDispose<Paginated<model.Order>>((ref) async =>
    ref.watch(ordersRepositoryProvider).myOrders(status: ref.watch(orderStatusFilterProvider)));


/// Supplier's incoming orders — same shape, different endpoint; the screen picks based on user role.
final supplierOrdersProvider = FutureProvider.autoDispose<Paginated<model.Order>>((ref) async =>
    ref.watch(ordersRepositoryProvider).supplierOrders(status: ref.watch(orderStatusFilterProvider)));


/// Single order — keyed by id. Used by detail screen and after status/cancel actions.
final orderByIdProvider = FutureProvider.autoDispose.family<model.Order, int>((ref, id) async =>
    ref.watch(ordersRepositoryProvider).getById(id));
