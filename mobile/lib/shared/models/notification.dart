// Notification — mirrors backend notifications.Notification. Kind drives the icon shown next to each row.
import 'package:json_annotation/json_annotation.dart';

part 'notification.g.dart';


/// Closed enum mirroring backend Notification.Kind. UI maps each kind to an icon.
enum NotificationKind {
  @JsonValue('SUPPLIER_VERIFIED') supplierVerified,
  @JsonValue('ORDER_PLACED') orderPlaced,
  @JsonValue('ORDER_STATUS_CHANGED') orderStatusChanged,
  @JsonValue('ORDER_CANCELLED') orderCancelled,
  @JsonValue('OTHER') other,
}


@JsonSerializable()
class AppNotification {
  final int id;
  final NotificationKind kind;
  final String title;
  final String message;
  final String link;
  @JsonKey(name: 'is_read') final bool isRead;
  @JsonKey(name: 'created_at') final String createdAt;

  const AppNotification({required this.id, required this.kind, required this.title, required this.message,
                         required this.link, required this.isRead, required this.createdAt});

  factory AppNotification.fromJson(Map<String, dynamic> json) => _$AppNotificationFromJson(json);
  Map<String, dynamic> toJson() => _$AppNotificationToJson(this);
}
