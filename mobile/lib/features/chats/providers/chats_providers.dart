// Riverpod providers for chats — repo, conversation list, and per-conversation message list.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/chats_repository.dart';


final chatsRepositoryProvider = Provider<ChatsRepository>((ref) => ChatsRepository(ref.watch(apiClientProvider)));


/// Conversation list — invalidated whenever the user enters or leaves a chat detail screen.
final conversationsProvider = FutureProvider.autoDispose((ref) async =>
    ref.watch(chatsRepositoryProvider).listConversations());


/// Per-conversation messages — keyed by conversation id. Polled by the chat detail screen every few seconds.
final conversationMessagesProvider = FutureProvider.autoDispose.family((ref, int convId) async =>
    ref.watch(chatsRepositoryProvider).fetchMessages(convId));
