// Bottom sheet for posting a review. Opens from the order detail screen on DELIVERED orders.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../orders/providers/orders_providers.dart';
import '../providers/reviews_providers.dart';
import 'star_rating.dart';


Future<void> showReviewSubmitSheet(BuildContext context, WidgetRef ref,
                                   {required int orderId, required int supplierId}) async {
  await showModalBottomSheet(context: context, isScrollControlled: true, builder: (sctx) =>
    _ReviewForm(orderId: orderId, supplierId: supplierId));
}


class _ReviewForm extends ConsumerStatefulWidget {
  final int orderId, supplierId;
  const _ReviewForm({required this.orderId, required this.supplierId});
  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}


class _ReviewFormState extends ConsumerState<_ReviewForm> {
  int _rating = 5;
  final _comment = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() { _comment.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    setState(() { _submitting = true; _error = null; });
    try {
      await ref.read(reviewsRepositoryProvider).create(
        orderId: widget.orderId, rating: _rating, comment: _comment.text.trim());
      // Invalidate review caches so the supplier's aggregate + list pick up the new entry
      ref..invalidate(supplierRatingProvider(widget.supplierId))
         ..invalidate(supplierReviewsProvider(widget.supplierId))
         ..invalidate(orderByIdProvider(widget.orderId));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.profileSavedSnack)));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(padding: EdgeInsets.only(left: 20, right: 20, top: 4,
                                            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Leave a review', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        Center(child: StarPicker(value: _rating, onChanged: (v) => setState(() => _rating = v))),
        const SizedBox(height: 20),
        TextField(controller: _comment, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Comment (optional)')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 20),
        FilledButton(onPressed: _submitting ? null : _submit,
          child: _submitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                             : Text(t.listingActionSave)),
      ]));
  }
}
