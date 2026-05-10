// Chats placeholder — real conversation list + messages land in Milestone C.
//
// Kept simple so the bottom-tab structure is in place now; replacing this widget later won't touch routing.
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';


class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar.large(title: Text(t.chatsTitle)),
        SliverFillRemaining(hasScrollBody: false, child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.forum_outlined, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(t.chatsComingSoon,
                 style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          ]))),
      ]),
    );
  }
}
