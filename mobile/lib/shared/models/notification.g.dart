// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    AppNotification(
      id: (json['id'] as num).toInt(),
      kind: $enumDecode(_$NotificationKindEnumMap, json['kind']),
      title: json['title'] as String,
      message: json['message'] as String,
      link: json['link'] as String,
      isRead: json['is_read'] as bool,
      createdAt: json['created_at'] as String,
    );

Map<String, dynamic> _$AppNotificationToJson(AppNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': _$NotificationKindEnumMap[instance.kind]!,
      'title': instance.title,
      'message': instance.message,
      'link': instance.link,
      'is_read': instance.isRead,
      'created_at': instance.createdAt,
    };

const _$NotificationKindEnumMap = {
  NotificationKind.supplierVerified: 'SUPPLIER_VERIFIED',
  NotificationKind.orderPlaced: 'ORDER_PLACED',
  NotificationKind.orderStatusChanged: 'ORDER_STATUS_CHANGED',
  NotificationKind.orderCancelled: 'ORDER_CANCELLED',
  NotificationKind.other: 'OTHER',
};
