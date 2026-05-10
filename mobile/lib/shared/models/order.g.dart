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
  listingId: (json['listing'] as num).toInt(),
  listingTitle: json['listing_title'] as String,
  listingMeatType: json['listing_meat_type'] as String,
  listingPricePerKg: _decimalFromString(json['listing_price_per_kg']),
  quantityKg: _decimalFromString(json['quantity_kg']),
  totalPrice: _decimalFromString(json['total_price']),
  deliveryAddress: json['delivery_address'] as String,
  notes: json['notes'] as String,
  status: $enumDecode(_$OrderStatusEnumMap, json['status']),
  createdAt: json['created_at'] as String,
);

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
  'id': instance.id,
  'buyer_email': instance.buyerEmail,
  'supplier_email': instance.supplierEmail,
  'supplier_user_id': instance.supplierUserId,
  'listing': instance.listingId,
  'listing_title': instance.listingTitle,
  'listing_meat_type': instance.listingMeatType,
  'listing_price_per_kg': _decimalToString(instance.listingPricePerKg),
  'quantity_kg': _decimalToString(instance.quantityKg),
  'total_price': _decimalToString(instance.totalPrice),
  'delivery_address': instance.deliveryAddress,
  'notes': instance.notes,
  'status': _$OrderStatusEnumMap[instance.status]!,
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
