import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/providers.dart';


/// Inbox list for the current bucket. F2 reads this — each row has Accept / Reject buttons.
/// Family parameter is the bucket name ('new' | 'active' | 'done').
///
/// Defensive: backend returns `{bucket, count, results}` on 200 success. Any 4xx (most often 403 when
/// the caller's role isn't SUPPLIER/QASSOB) comes back through ApiClient as a `{detail: "…"}` map
/// because validateStatus accepts <500. We now THROW with the detail so the UI's error branch shows
/// the real reason ("You do not have permission…") instead of a misleading empty state.
final inboxProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bucket) async {
  final r = await ref.read(apiClientProvider).dio.get('/partner/inbox/?bucket=$bucket');
  final data = r.data;
  if (data is Map && data['results'] is List) {
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }
  if (data is Map && data['detail'] is String) {
    // Surface the backend's reason — most often "you don't have permission" when the partner account
    // was registered with role=BUYER (pre-v3.8.3 signup bug). The user now sees WHY the list is empty.
    throw Exception(data['detail'] as String);
  }
  return [];
});
