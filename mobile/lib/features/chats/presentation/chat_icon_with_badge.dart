import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/chats_providers.dart';


/// Telegram-style chat icon button with a small red dot when there are unread messages, plus a
/// numeric count for counts ≥ 2. Tap pushes the buyer to /chats. Used in the HomeScreen header
/// (top-right corner) and anywhere else we want to surface unread state.
class ChatIconWithBadge extends ConsumerWidget {
  /// Foreground color of the icon — defaults to onSurface; pass a custom color when the icon sits
  /// on a tinted/dark background (e.g. inside a hero header).
  final Color? color;
  const ChatIconWithBadge({super.key, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final unread = ref.watch(unreadChatsTotalProvider).asData?.value ?? 0;
    return Stack(clipBehavior: Clip.none, children: [
      IconButton(
        icon: Icon(Icons.chat_bubble_outline_rounded, color: color ?? cs.onSurface),
        tooltip: 'Chatlar',
        onPressed: () => context.push('/chats'),
      ),
      if (unread > 0)
        // Pill badge positioned over the top-right corner of the chat icon, identical visual
        // language to the WhatsApp / Telegram unread indicator. Numeric for counts < 100, "99+"
        // beyond that so it stays a single readable glyph at any scale.
        Positioned(top: 6, right: 4, child: IgnorePointer(child: Container(
          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: const Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 1.5)),
          child: Center(child: Text(unread > 99 ? '99+' : '$unread',
              style: const TextStyle(color: Colors.white,
                  fontSize: 10, fontWeight: FontWeight.w800, height: 1.0)))))),
    ]);
  }
}
