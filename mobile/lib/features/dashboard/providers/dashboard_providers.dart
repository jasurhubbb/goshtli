// Riverpod providers for the dashboards.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/dashboard_models.dart';
import '../data/dashboard_repository.dart';


final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) =>
    DashboardRepository(ref.watch(apiClientProvider)));


final buyerDashboardProvider = FutureProvider.autoDispose<BuyerDashboard>((ref) async =>
    ref.watch(dashboardRepositoryProvider).buyer());


final supplierDashboardProvider = FutureProvider.autoDispose<SupplierDashboard>((ref) async =>
    ref.watch(dashboardRepositoryProvider).supplier());
