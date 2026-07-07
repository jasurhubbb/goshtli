/// Dart mirrors for the backend courier serializers. Kept in a single file because they're small +
/// tightly coupled — the Queue tab needs the list shape, detail needs the extended shape, both use
/// the same status enum + timestamps.

enum DeliveryStatus {
  assigned,
  pickedUp,
  enRoute,
  arrived,
  delivered,
  cancelled,
}

DeliveryStatus deliveryStatusFromWire(String s) {
  switch (s) {
    case 'ASSIGNED':  return DeliveryStatus.assigned;
    case 'PICKED_UP': return DeliveryStatus.pickedUp;
    case 'EN_ROUTE':  return DeliveryStatus.enRoute;
    case 'ARRIVED':   return DeliveryStatus.arrived;
    case 'DELIVERED': return DeliveryStatus.delivered;
    case 'CANCELLED': return DeliveryStatus.cancelled;
  }
  return DeliveryStatus.assigned;
}

String deliveryStatusToWire(DeliveryStatus s) {
  switch (s) {
    case DeliveryStatus.assigned:  return 'ASSIGNED';
    case DeliveryStatus.pickedUp:  return 'PICKED_UP';
    case DeliveryStatus.enRoute:   return 'EN_ROUTE';
    case DeliveryStatus.arrived:   return 'ARRIVED';
    case DeliveryStatus.delivered: return 'DELIVERED';
    case DeliveryStatus.cancelled: return 'CANCELLED';
  }
}

/// Localized Uzbek label used everywhere the status appears (list row, detail hero, history rows).
String deliveryStatusLabel(DeliveryStatus s) {
  switch (s) {
    case DeliveryStatus.assigned:  return 'Yangi';
    case DeliveryStatus.pickedUp:  return 'Olindi';
    case DeliveryStatus.enRoute:   return "Yo'lda";
    case DeliveryStatus.arrived:   return 'Yetib bordi';
    case DeliveryStatus.delivered: return 'Yetkazildi';
    case DeliveryStatus.cancelled: return 'Bekor';
  }
}


/// List-row shape. Matches the backend DeliveryListSerializer.
class DeliveryRow {
  final int id;
  final int orderId;
  final DeliveryStatus status;
  final String buyerName;
  final String buyerPhone;
  final String listingName;
  final String quantityKg;
  final String totalPrice;
  final String pickupAddress;
  final String pickupLat;
  final String pickupLng;
  final String dropoffAddress;
  final String dropoffLat;
  final String dropoffLng;
  final int cashCollectedUzs;
  final int payoutUzs;
  final String? pickedUpAt;
  final String? deliveredAt;
  final String createdAt;

  const DeliveryRow({
    required this.id, required this.orderId, required this.status,
    required this.buyerName, required this.buyerPhone,
    required this.listingName, required this.quantityKg, required this.totalPrice,
    required this.pickupAddress, required this.pickupLat, required this.pickupLng,
    required this.dropoffAddress, required this.dropoffLat, required this.dropoffLng,
    required this.cashCollectedUzs, required this.payoutUzs,
    this.pickedUpAt, this.deliveredAt, required this.createdAt,
  });

  factory DeliveryRow.fromJson(Map<String, dynamic> j) => DeliveryRow(
        id: (j['id'] as num).toInt(),
        orderId: (j['order_id'] as num).toInt(),
        status: deliveryStatusFromWire((j['status'] ?? 'ASSIGNED') as String),
        buyerName: (j['buyer_name'] ?? '') as String,
        buyerPhone: (j['buyer_phone'] ?? '') as String,
        listingName: (j['listing_name'] ?? '') as String,
        quantityKg: (j['quantity_kg'] ?? '') as String,
        totalPrice: (j['total_price'] ?? '') as String,
        pickupAddress: (j['pickup_address'] ?? '') as String,
        pickupLat: (j['pickup_lat'] ?? '') as String,
        pickupLng: (j['pickup_lng'] ?? '') as String,
        dropoffAddress: (j['dropoff_address'] ?? '') as String,
        dropoffLat: (j['dropoff_lat'] ?? '') as String,
        dropoffLng: (j['dropoff_lng'] ?? '') as String,
        cashCollectedUzs: (j['cash_collected_uzs'] as num?)?.toInt() ?? 0,
        payoutUzs: (j['payout_uzs'] as num?)?.toInt() ?? 0,
        pickedUpAt: j['picked_up_at'] as String?,
        deliveredAt: j['delivered_at'] as String?,
        createdAt: (j['created_at'] ?? '') as String,
      );
}


/// Extended detail shape — includes buyer email + notes + payment status + slot + proof URL.
class DeliveryDetail extends DeliveryRow {
  final String buyerEmail;
  final String notes;
  final String paymentStatus;
  final String timeSlot;
  final String vehicleType;
  final String proofPhotoUrl;

  const DeliveryDetail({
    required super.id, required super.orderId, required super.status,
    required super.buyerName, required super.buyerPhone,
    required super.listingName, required super.quantityKg, required super.totalPrice,
    required super.pickupAddress, required super.pickupLat, required super.pickupLng,
    required super.dropoffAddress, required super.dropoffLat, required super.dropoffLng,
    required super.cashCollectedUzs, required super.payoutUzs,
    super.pickedUpAt, super.deliveredAt, required super.createdAt,
    required this.buyerEmail, required this.notes, required this.paymentStatus,
    required this.timeSlot, required this.vehicleType, required this.proofPhotoUrl,
  });

  factory DeliveryDetail.fromJson(Map<String, dynamic> j) => DeliveryDetail(
        id: (j['id'] as num).toInt(),
        orderId: (j['order_id'] as num).toInt(),
        status: deliveryStatusFromWire((j['status'] ?? 'ASSIGNED') as String),
        buyerName: (j['buyer_name'] ?? '') as String,
        buyerPhone: (j['buyer_phone'] ?? '') as String,
        listingName: (j['listing_name'] ?? '') as String,
        quantityKg: (j['quantity_kg'] ?? '') as String,
        totalPrice: (j['total_price'] ?? '') as String,
        pickupAddress: (j['pickup_address'] ?? '') as String,
        pickupLat: (j['pickup_lat'] ?? '') as String,
        pickupLng: (j['pickup_lng'] ?? '') as String,
        dropoffAddress: (j['dropoff_address'] ?? '') as String,
        dropoffLat: (j['dropoff_lat'] ?? '') as String,
        dropoffLng: (j['dropoff_lng'] ?? '') as String,
        cashCollectedUzs: (j['cash_collected_uzs'] as num?)?.toInt() ?? 0,
        payoutUzs: (j['payout_uzs'] as num?)?.toInt() ?? 0,
        pickedUpAt: j['picked_up_at'] as String?,
        deliveredAt: j['delivered_at'] as String?,
        createdAt: (j['created_at'] ?? '') as String,
        buyerEmail: (j['buyer_email'] ?? '') as String,
        notes: (j['notes'] ?? '') as String,
        paymentStatus: (j['payment_status'] ?? '') as String,
        timeSlot: (j['time_slot'] ?? '') as String,
        vehicleType: (j['vehicle_type'] ?? '') as String,
        proofPhotoUrl: (j['proof_photo_url'] ?? '') as String,
      );
}


class CourierProfile {
  final String fullName;
  final String phone;
  final String email;
  final String vehicleKind;
  final String vehiclePlate;
  final bool isOnline;
  final String photoUrl;
  final double ratingAvg;
  final int ratingCount;
  final int lifetimeDeliveries;
  final int lifetimeEarningsUzs;

  const CourierProfile({
    required this.fullName, required this.phone, required this.email,
    required this.vehicleKind, required this.vehiclePlate,
    required this.isOnline, required this.photoUrl,
    required this.ratingAvg, required this.ratingCount,
    required this.lifetimeDeliveries, required this.lifetimeEarningsUzs,
  });

  factory CourierProfile.fromJson(Map<String, dynamic> j) => CourierProfile(
        fullName: (j['full_name'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        vehicleKind: (j['vehicle_kind'] ?? '') as String,
        vehiclePlate: (j['vehicle_plate'] ?? '') as String,
        isOnline: (j['is_online'] ?? false) as bool,
        photoUrl: (j['photo_url'] ?? '') as String,
        ratingAvg: double.tryParse('${j['rating_avg'] ?? 0}') ?? 0,
        ratingCount: (j['rating_count'] as num?)?.toInt() ?? 0,
        lifetimeDeliveries: (j['lifetime_deliveries'] as num?)?.toInt() ?? 0,
        lifetimeEarningsUzs: (j['lifetime_earnings_uzs'] as num?)?.toInt() ?? 0,
      );
}


/// Home-screen aggregate. Matches CourierDashboardView response.
class CourierDashboard {
  final int todayEarningsUzs;
  final int todayDeliveries;
  final int queueCount;
  final int activeCount;
  final int lifetimeDeliveries;
  final int lifetimeEarningsUzs;
  final double ratingAvg;
  final int ratingCount;
  final bool isOnline;
  final String vehicleKind;

  const CourierDashboard({
    required this.todayEarningsUzs, required this.todayDeliveries,
    required this.queueCount, required this.activeCount,
    required this.lifetimeDeliveries, required this.lifetimeEarningsUzs,
    required this.ratingAvg, required this.ratingCount,
    required this.isOnline, required this.vehicleKind,
  });

  factory CourierDashboard.fromJson(Map<String, dynamic> j) => CourierDashboard(
        todayEarningsUzs: (j['today_earnings_uzs'] as num?)?.toInt() ?? 0,
        todayDeliveries: (j['today_deliveries'] as num?)?.toInt() ?? 0,
        queueCount: (j['queue_count'] as num?)?.toInt() ?? 0,
        activeCount: (j['active_count'] as num?)?.toInt() ?? 0,
        lifetimeDeliveries: (j['lifetime_deliveries'] as num?)?.toInt() ?? 0,
        lifetimeEarningsUzs: (j['lifetime_earnings_uzs'] as num?)?.toInt() ?? 0,
        ratingAvg: double.tryParse('${j['rating_avg'] ?? 0}') ?? 0,
        ratingCount: (j['rating_count'] as num?)?.toInt() ?? 0,
        isOnline: (j['is_online'] ?? false) as bool,
        vehicleKind: (j['vehicle_kind'] ?? '') as String,
      );
}


class EarningsSeriesPoint {
  final String date;                                                             // ISO YYYY-MM-DD
  final int earningsUzs;
  final int deliveries;
  const EarningsSeriesPoint({required this.date, required this.earningsUzs, required this.deliveries});
  factory EarningsSeriesPoint.fromJson(Map<String, dynamic> j) => EarningsSeriesPoint(
        date: (j['date'] ?? '') as String,
        earningsUzs: (j['earnings_uzs'] as num?)?.toInt() ?? 0,
        deliveries: (j['deliveries'] as num?)?.toInt() ?? 0,
      );
}


class EarningsResult {
  final String period;
  final int totalEarningsUzs;
  final int totalDeliveries;
  final List<EarningsSeriesPoint> series;
  const EarningsResult({
    required this.period, required this.totalEarningsUzs,
    required this.totalDeliveries, required this.series,
  });
  factory EarningsResult.fromJson(Map<String, dynamic> j) => EarningsResult(
        period: (j['period'] ?? '') as String,
        totalEarningsUzs: (j['total_earnings_uzs'] as num?)?.toInt() ?? 0,
        totalDeliveries: (j['total_deliveries'] as num?)?.toInt() ?? 0,
        series: ((j['series'] as List?) ?? const [])
            .map((e) => EarningsSeriesPoint.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
