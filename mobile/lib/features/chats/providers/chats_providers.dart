// Riverpod providers for chats — repo, conversation list, and per-conversation message list.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';
import '../data/chats_repository.dart';


final chatsRepositoryProvider = Provider<ChatsRepository>((ref) => ChatsRepository(ref.watch(apiClientProvider)));


/// Conversation list — invalidated whenever the user enters or leaves a chat detail screen.
final conversationsProvider = FutureProvider.autoDispose((ref) async =>
    ref.watch(chatsRepositoryProvider).listConversations());


/// Per-conversation messages — keyed by conversation id. Polled by the chat detail screen every few seconds.
final conversationMessagesProvider = FutureProvider.autoDispose.family((ref, int convId) async =>
    ref.watch(chatsRepositoryProvider).fetchMessages(convId));


/// v3.9.8 — global unread total for the AppBar badge dot. Refreshed on a 20-second pulse so a
/// user who never opens Chatlar still sees a "you have new messages" indicator within ~20s of a
/// real-time WS push arriving. Authenticated-only (anonymous users have no chats); we return 0
/// when there's no session.
final unreadChatsTotalProvider = StreamProvider<int>((ref) async* {
  // Yield 0 first so the dot isn't pre-rendered on a stale provider value during the first poll.
  yield 0;
  while (true) {
    final auth = ref.read(authNotifierProvider);
    if (auth is AuthAuthenticated) {
      try {
        final api = ref.read(apiClientProvider);
        final r = await api.dio.get('/chats/unread-total/');
        if (r.statusCode == 200 && r.data is Map) {
          yield (r.data['unread'] as num?)?.toInt() ?? 0;
        } else {
          yield 0;
        }
      } catch (_) {
        yield 0;
      }
    } else {
      yield 0;
    }
    await Future<void>.delayed(const Duration(seconds: 20));
  }
});
