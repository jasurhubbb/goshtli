// Delivery providers — repo + the selected vehicle/time/butcher state for the delivery page.
//
// We keep the selection in a single Notifier so the bottom-bar total updates instantly when any toggle
// changes (vehicle, time slot, butcher) — without each child widget having to re-listen separately.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart' show apiClientProvider;
import '../data/delivery_models.dart';
import '../data/delivery_repository.dart';


final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) =>
    DeliveryRepository(ref.watch(apiClientProvider)));


/// Pure UI state for the delivery page. NOT persisted across screens — the buyer re-enters the page from
/// scratch each time (matches Wolt / Yandex Eda's checkout reset pattern).
class DeliverySelection {
  final String? vehicleCode;                       // matches VehicleOption.code; null = unset
  final String? timeSlotCode;                      // matches TimeSlotOption.code
  final bool butcherRequested;                     // mirrors the toggle in the butcher section
  final DeliveryQuote? quote;                      // last successful quote (null while loading)
  final bool loading;
  final String? error;

  const DeliverySelection({this.vehicleCode, this.timeSlotCode,
                           this.butcherRequested = false, this.quote,
                           this.loading = false, this.error});

  DeliverySelection copyWith({
    String? vehicleCode, bool resetVehicle = false,
    String? timeSlotCode, bool resetTimeSlot = false,
    bool? butcherRequested,
    DeliveryQuote? quote, bool resetQuote = false,
    bool? loading,
    String? error, bool resetError = false,
  }) => DeliverySelection(
    vehicleCode: resetVehicle ? null : (vehicleCode ?? this.vehicleCode),
    timeSlotCode: resetTimeSlot ? null : (timeSlotCode ?? this.timeSlotCode),
    butcherRequested: butcherRequested ?? this.butcherRequested,
    quote: resetQuote ? null : (quote ?? this.quote),
    loading: loading ?? this.loading,
    error: resetError ? null : (error ?? this.error),
  );

  /// Helpers the page widget asks for. Avoid recomputing in 4 places — cheap pattern, easier to test.
  VehicleOption? get selectedVehicle => quote == null || vehicleCode == null ? null
      : quote!.options.firstWhere((o) => o.code == vehicleCode,
          orElse: () => quote!.options.first);
  double get deliveryPrice => selectedVehicle?.totalPrice ?? 0;
  double get butcherFee => butcherRequested ? (quote?.butcherService.flatFee ?? 0) : 0;
}


class DeliverySelectionNotifier extends StateNotifier<DeliverySelection> {
  DeliverySelectionNotifier() : super(const DeliverySelection());

  void setVehicle(String code) => state = state.copyWith(vehicleCode: code);
  void setTimeSlot(String code) => state = state.copyWith(timeSlotCode: code);
  void setButcherRequested(bool v) => state = state.copyWith(butcherRequested: v);
  void setLoading(bool v) => state = state.copyWith(loading: v);
  void setError(String? err) => state = state.copyWith(error: err, resetError: err == null);

  /// Called once a fresh quote lands. Auto-selects the first AVAILABLE vehicle so the page never opens
  /// in a "nothing picked" state — buyer can override with one tap. Time slot is left unset until the
  /// buyer picks one (it's a deliberate decision, not a default).
  void setQuote(DeliveryQuote quote) {
    final firstAvailable = quote.options.where((o) => o.available).isEmpty
        ? null
        : quote.options.firstWhere((o) => o.available).code;
    state = state.copyWith(
      quote: quote,
      vehicleCode: firstAvailable,
      loading: false,
      resetError: true,
    );
  }

  void reset() => state = const DeliverySelection();
}


final deliverySelectionProvider = StateNotifierProvider<DeliverySelectionNotifier, DeliverySelection>(
    (ref) => DeliverySelectionNotifier());
