import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/providers.dart';


/// Inbox list for the current bucket. F2 reads this — each row has Accept / Reject buttons.
/// Family parameter is the bucket name ('new' | 'active' | 'done').
final inboxProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bucket) async {
  final r = await ref.read(apiClientProvider).dio.get('/partner/inbox/?bucket=$bucket');
  final results = ((r.data as Map)['results'] as List).cast<Map<String, dynamic>>();
  return results;
});
