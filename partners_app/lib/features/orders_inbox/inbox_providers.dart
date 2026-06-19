import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/providers.dart';


/// Inbox list for the current bucket. F2 reads this — each row has Accept / Reject buttons.
/// Family parameter is the bucket name ('new' | 'active' | 'done').
///
/// Defensive: the backend returns `{bucket, count, results}` on 200, but a `{detail: "..."}` map on
/// 4xx error. Neither path should crash — fall back to an empty list when the shape is unexpected.
final inboxProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bucket) async {
  final r = await ref.read(apiClientProvider).dio.get('/partner/inbox/?bucket=$bucket');
  final data = r.data;
  if (data is! Map) return [];
  final raw = data['results'];
  if (raw is! List) return [];
  return raw.cast<Map<String, dynamic>>();
});
