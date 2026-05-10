// HeartButton — toggles the favorite state for a listing. Drops onto listing detail + cards as an action.
//
// Uses optimistic UI: the icon flips immediately on tap, and the backend call runs in the background. If the call
// fails we invalidate and revert visually on the next rebuild.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/favorites_providers.dart';


class HeartButton extends ConsumerStatefulWidget {
  final int listingId;
  final double size;
  const HeartButton({super.key, required this.listingId, this.size = 24});
  @override
  ConsumerState<HeartButton> createState() => _HeartButtonState();
}


class _HeartButtonState extends ConsumerState<HeartButton> {
  bool? _optimisticState;     // null = use the server-state from the provider; set during in-flight toggles

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ids = ref.watch(favoritedIdsProvider).asData?.value ?? <int>{};
    final saved = _optimisticState ?? ids.contains(widget.listingId);
    return IconButton(
      iconSize: widget.size,
      icon: Icon(saved ? Icons.favorite : Icons.favorite_border, color: saved ? cs.error : cs.onSurfaceVariant),
      onPressed: () async {
        // Optimistic flip → invalidate the underlying provider so subsequent reads pick up the server truth
        setState(() => _optimisticState = !saved);
        final repo = ref.read(favoritesRepositoryProvider);
        try {
          if (saved) { await repo.remove(widget.listingId); } else { await repo.add(widget.listingId); }
          ref..invalidate(favoritedIdsProvider)..invalidate(favoritesListProvider);
        } catch (_) {
          // On failure, revert the optimistic UI
          if (mounted) setState(() => _optimisticState = saved);
        } finally {
          // Clear the override so future provider updates drive the UI
          if (mounted) setState(() => _optimisticState = null);
        }
      },
    );
  }
}
