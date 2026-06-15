// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Order _$OrderFromJson(Map<String, dynamic> json) => Order(
  id: (json['id'] as num).toInt(),
  buyerEmail: json['buyer_email'] as String,
  supplierEmail: json['supplier_email'] as String,
  supplierUserId: (json['supplier_user_id'] as num?)?.toInt() ?? 0,
  buyerName: json['buyer_name'] as String? ?? '',
  buyerPhone: json['buyer_phone'] as String? ?? '',
  sellerNameUz: json['seller_name_uz'] as String? ?? '',
  sellerNameRu: json['seller_name_ru'] as String? ?? '',
  listingId: (json['listing'] as num).toInt(),
  listingNameUz: json['listing_name_uz'] as String? ?? '',
  listingNameRu: json['listing_name_ru'] as String? ?? '',
  listingCategorySlug: json['listing_category_slug'] as String? ?? '',
  listingMarketSlug: json['listing_market_slug'] as String? ?? '',
  listingPricePerKg: _decimalFromString(json['listing_price_per_kg']),
  quantityKg: _decimalFromString(json['quantity_kg']),
  totalPrice: _decimalFromString(json['total_price']),
  deliveryAddress: json['delivery_address'] as String,
  notes: json['notes'] as String,
  status: $enumDecode(_$OrderStatusEnumMap, json['status']),
  paymentStatus:
      $enumDecodeNullable(
        _$OrderPaymentStatusEnumMap,
        json['payment_status'],
      ) ??
      OrderPaymentStatus.unpaid,
  paymentUrl: json['payment_url'] as String? ?? '',
  createdAt: json['created_at'] as String,
);

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
  'id': instance.id,
  'buyer_email': instance.buyerEmail,
  'supplier_email': instance.supplierEmail,
  'supplier_user_id': instance.supplierUserId,
  'buyer_name': instance.buyerName,
  'buyer_phone': instance.buyerPhone,
  'seller_name_uz': instance.sellerNameUz,
  'seller_name_ru': instance.sellerNameRu,
  'listing': instance.listingId,
  'listing_name_uz': instance.listingNameUz,
  'listing_name_ru': instance.listingNameRu,
  'listing_category_slug': instance.listingCategorySlug,
  'listing_market_slug': instance.listingMarketSlug,
  'listing_price_per_kg': _decimalToString(instance.listingPricePerKg),
  'quantity_kg': _decimalToString(instance.quantityKg),
  'total_price': _decimalToString(instance.totalPrice),
  'delivery_address': instance.deliveryAddress,
  'notes': instance.notes,
  'status': _$OrderStatusEnumMap[instance.status]!,
  'payment_status': _$OrderPaymentStatusEnumMap[instance.paymentStatus]!,
  'payment_url': instance.paymentUrl,
  'created_at': instance.createdAt,
};

const _$OrderStatusEnumMap = {
  OrderStatus.pending: 'PENDING',
  OrderStatus.confirmed: 'CONFIRMED',
  OrderStatus.processing: 'PROCESSING',
  OrderStatus.inTransit: 'IN_TRANSIT',
  OrderStatus.delivered: 'DELIVERED',
  OrderStatus.cancelled: 'CANCELLED',
};

const _$OrderPaymentStatusEnumMap = {
  OrderPaymentStatus.unpaid: 'UNPAID',
  OrderPaymentStatus.pending: 'PENDING',
  OrderPaymentStatus.paid: 'PAID',
  OrderPaymentStatus.failed: 'FAILED',
  OrderPaymentStatus.refunded: 'REFUNDED',
};
