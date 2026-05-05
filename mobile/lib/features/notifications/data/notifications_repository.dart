// NotificationsRepository — list, unread count, mark-read (single + bulk).
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/notification.dart';
import '../../../shared/models/paginated.dart';
import '../../listings/data/listings_repository.dart' show ApiException;


class NotificationsRepository {
  final ApiClient _api;
  NotificationsRepository(this._api);

  Future<Paginated<AppNotification>> list({bool? isRead}) async {
    final r = await _api.dio.get('/notifications/', queryParameters: {'is_read': ?isRead});
    if (r.statusCode == 200) return Paginated.fromJson(r.data as Map<String, dynamic>, AppNotification.fromJson);
    throw _toApiException(r);
  }

  Future<int> unreadCount() async {
    final r = await _api.dio.get('/notifications/unread-count/');
    if (r.statusCode == 200) return (r.data as Map<String, dynamic>)['unread'] as int;
    throw _toApiException(r);
  }

  Future<AppNotification> markRead(int id) async {
    final r = await _api.dio.post('/notifications/$id/read/');
    if (r.statusCode == 200) return AppNotification.fromJson(r.data as Map<String, dynamic>);
    throw _toApiException(r);
  }

  Future<void> markAllRead() async {
    final r = await _api.dio.post('/notifications/read-all/');
    if (r.statusCode != 204) throw _toApiException(r);
  }

  ApiException _toApiException(Response r) =>
      ApiException(r.data is Map && (r.data as Map)['detail'] is String
          ? (r.data as Map)['detail'] as String : 'HTTP ${r.statusCode}');
}
