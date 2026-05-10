// Star widgets — display (read-only) + interactive picker for the submit sheet.
import 'package:flutter/material.dart';


/// Small ★ widget — fractional fill so 4.6 shows ~4½ stars. Used inline on cards next to "(23)".
class StarRow extends StatelessWidget {
  final double rating;       // 0..5; non-integer renders a half-filled last star
  final int count;
  final double size;
  final bool showCount;

  const StarRow({super.key, required this.rating, this.count = 0, this.size = 14, this.showCount = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final full = rating.floor();
    final hasHalf = (rating - full) >= 0.25 && (rating - full) < 0.75;
    final filled = hasHalf ? full : rating.round();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (int i = 0; i < 5; i++) Icon(
        i < filled ? Icons.star : (i == filled && hasHalf ? Icons.star_half : Icons.star_border),
        size: size, color: i < filled || (i == filled && hasHalf) ? Colors.amber : cs.outlineVariant),
      if (showCount && count > 0) Padding(padding: const EdgeInsets.only(left: 4),
          child: Text('($count)', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
    ]);
  }
}


/// Interactive 5-star picker — used in the "leave a review" sheet. Stateless; parent owns the value.
class StarPicker extends StatelessWidget {
  final int value;                                    // 1..5
  final ValueChanged<int> onChanged;
  final double size;

  const StarPicker({super.key, required this.value, required this.onChanged, this.size = 36});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    for (int i = 1; i <= 5; i++) IconButton(
      iconSize: size, padding: const EdgeInsets.symmetric(horizontal: 2),
      icon: Icon(i <= value ? Icons.star : Icons.star_border,
        color: i <= value ? Colors.amber : Theme.of(context).colorScheme.outlineVariant),
      onPressed: () => onChanged(i)),
  ]);
}
