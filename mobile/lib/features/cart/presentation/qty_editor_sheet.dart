// QtyEditorSheet — modal bottom sheet for typing the exact kg amount on a listing.
//
// Why this exists: the +/- steppers (home card, cart row, cart peek bar) are fine for fine-tuning, but
// nobody wants to tap "+" 100 times to order 100 kg. Production marketplaces (Uzum, Wolt, Yandex Eda)
// all let you TAP THE NUMBER and type. We do the same: tap the qty readout → this sheet → keyboard +
// max-stock validation + Tasdiqlash.
//
// Side benefits over the bare stepper:
//   • Shows the listing's available stock ("Mavjud: 240 kg") so buyers see the cap before they hit it
//   • Validates client-side so the backend never sees a 100kg-for-a-12kg-listing request
//   • Optional `allowZero` for clearing the row by typing 0 (cart row uses this; home card adds-only)
//
// Usage:
//   final newQty = await showQtyEditorSheet(context, listingId: ..., currentQty: 3, maxKg: 12);
//   if (newQty != null) setQty(listingId, newQty);
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';


/// Drop-in helper. Returns the new quantity if the user confirmed, null if they dismissed/cancelled.
///
/// v3.6 PRD §1: `minKg` enforces the wholesale 10kg minimum on raw-meat listings; live-by-head listings
/// pass minKg=1 (one animal). `unitLabel` swaps "kg" → "bosh" (head) so the sheet matches the badge on the
/// product card.
Future<int?> showQtyEditorSheet(BuildContext context, {
  required int currentQty,
  required int maxKg,
  bool allowZero = true,
  int minKg = 1,
  String unitLabel = 'kg',
  String? listingName,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,                                          // lets the sheet rise above the keyboard
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _QtyEditorSheet(
      currentQty: currentQty,
      maxKg: maxKg,
      minKg: minKg,
      allowZero: allowZero,
      unitLabel: unitLabel,
      listingName: listingName,
    ),
  );
}


class _QtyEditorSheet extends StatefulWidget {
  final int currentQty;
  final int maxKg;
  final int minKg;
  final bool allowZero;
  final String unitLabel;
  final String? listingName;
  const _QtyEditorSheet({
    required this.currentQty,
    required this.maxKg,
    required this.minKg,
    required this.allowZero,
    required this.unitLabel,
    this.listingName,
  });
  @override
  State<_QtyEditorSheet> createState() => _QtyEditorSheetState();
}


class _QtyEditorSheetState extends State<_QtyEditorSheet> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the current qty so the common path (small tweak) is one backspace + new digit.
    // Empty when currentQty=0 so the placeholder shows instead of "0".
    _ctrl = TextEditingController(text: widget.currentQty > 0 ? widget.currentQty.toString() : '');
    // Auto-select-all on open so a fresh number replaces the old one cleanly.
    _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  /// Validate the typed value against allowZero + maxKg. Returns the parsed int on success, null + sets
  /// _error on failure.
  int? _validate() {
    final t = AppLocalizations.of(context);
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = t.qtyEditorEnterAmount);
      return null;
    }
    final n = int.tryParse(raw);
    if (n == null) {
      setState(() => _error = t.qtyEditorOnlyDigits);
      return null;
    }
    if (!widget.allowZero && n <= 0) {
      setState(() => _error = t.qtyEditorMustBePositive);
      return null;
    }
    if (n < 0) {
      setState(() => _error = t.qtyEditorMustBePositive);
      return null;
    }
    // PRD v2 §1 wholesale minimum — enforced client-side so the buyer sees the issue immediately rather
    // than waiting for the server's 400 response. The 0 case is handled above when allowZero is false.
    if (n > 0 && n < widget.minKg) {
      setState(() => _error = t.qtyEditorBelowMinimum(widget.minKg));
      return null;
    }
    if (n > widget.maxKg) {
      setState(() => _error = t.qtyEditorMaxExceeded(widget.maxKg));
      return null;
    }
    return n;
  }

  void _submit() {
    final n = _validate();
    if (n == null) return;
    HapticFeedback.lightImpact();
    Navigator.pop(context, n);
  }

  /// Returns the right quick-chip set for the listing's sale type. Raw meat (minKg=10) shows
  /// 10/25/50/100; live by head (minKg=1) shows 1/2/3. Both include a "Max" chip when stock > the largest
  /// chip — lets the buyer dump the entire listing into the cart in one tap.
  List<Widget> _quickChipsForListing(AppLocalizations t) {
    final values = widget.minKg >= 10 ? const [10, 25, 50, 100] : const [1, 2, 3, 5];
    final tapValue = (int v) {
      setState(() {
        _ctrl.text = v.toString();
        _error = null;
        _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
      });
    };
    return [
      for (final v in values) if (v <= widget.maxKg && v >= widget.minKg)
        _QuickChip(value: v, unitLabel: widget.unitLabel, onTap: () => tapValue(v)),
      if (widget.maxKg > values.last)
        _QuickChip(label: t.qtyEditorMax, value: widget.maxKg, unitLabel: widget.unitLabel,
                   onTap: () => tapValue(widget.maxKg)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      // Lift the sheet above the soft keyboard so the input + CTA stay visible
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
        child: SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Drag handle
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 6, bottom: 16),
                decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            // Header
            Text(widget.listingName ?? t.qtyEditorTitle,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            // The big input row — number + "kg" suffix. We use a regular TextField (not a stepper) so the
            // OS numeric keypad opens and the user can also paste from clipboard.
            Container(
              decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),                  // 9999 kg is way more than any listing
                  ],
                  onChanged: (_) { if (_error != null) setState(() => _error = null); },
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    hintText: '0',
                    hintStyle: tt.displaySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w800),
                  ),
                )),
                Text(widget.unitLabel, style: tt.headlineSmall?.copyWith(
                    color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 10),
            // Stock hint OR error — same vertical slot so the layout doesn't jump when an error appears.
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(_error ?? t.qtyEditorAvailable(widget.maxKg),
                  style: tt.bodyMedium?.copyWith(
                      color: _error != null ? cs.error : cs.onSurfaceVariant))),
            const SizedBox(height: 18),
            // Quick-add shortcut chips for common bulk amounts. PRD §1: floor is 10kg for raw meat — show
            // 10 / 25 / 50 / 100 / max. For BY_HEAD live animals the chip set narrows to 1/2/3 + max so
            // the buyer isn't suggesting more heads than the listing has.
            Wrap(spacing: 8, runSpacing: 8, children: _quickChipsForListing(t)),
            const SizedBox(height: 20),
            // Primary CTA
            SizedBox(height: 54, child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Text(t.qtyEditorConfirm, style: tt.titleMedium?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w700)))),
          ]),
        )),
      ),
    );
  }
}


class _QuickChip extends StatelessWidget {
  final int value;
  final String? label;
  final String unitLabel;
  final VoidCallback onTap;
  const _QuickChip({required this.value, required this.onTap,
                    this.label, this.unitLabel = 'kg'});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(label ?? '$value $unitLabel',
                style: tt.titleSmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600)))));
  }
}
