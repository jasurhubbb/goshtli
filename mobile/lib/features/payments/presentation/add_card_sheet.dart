// AddCardSheet — modal where the buyer enters card details. Mirrors the inline form Payme uses on its
// hosted checkout page (PAN, expiry, CVC, holder, phone). Auto-detects brand from BIN client-side so
// the icon flips while typing — same as Wolt UZ / Uzum.
//
// Usage:
//   final added = await showAddCardSheet(context, autoMakeDefault: true);
//   if (added != null) {  /* card persisted; refresh picker */  }
//
// The sheet validates locally + posts to POST /payments/cards/. The Add CTA is disabled until all
// required fields parse; failures surface as field-level errors below the inputs.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../listings/data/listings_repository.dart' show ApiException;
import '../data/card_model.dart';
import '../providers/cards_providers.dart';


/// Open the sheet. Returns the created card on success, null on dismiss.
Future<PaymentCard?> showAddCardSheet(BuildContext context, {bool autoMakeDefault = false}) {
  return showModalBottomSheet<PaymentCard>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _AddCardSheet(autoMakeDefault: autoMakeDefault),
  );
}


// ---------- Sheet ----------

class _AddCardSheet extends ConsumerStatefulWidget {
  final bool autoMakeDefault;
  const _AddCardSheet({required this.autoMakeDefault});
  @override
  ConsumerState<_AddCardSheet> createState() => _AddCardSheetState();
}


class _AddCardSheetState extends ConsumerState<_AddCardSheet> {
  final _pan = TextEditingController();
  final _expiry = TextEditingController();
  final _cvc = TextEditingController();
  final _holder = TextEditingController();
  final _phone = TextEditingController();
  bool _saveAsDefault = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _saveAsDefault = widget.autoMakeDefault;
    // Live-detect brand on PAN edits so the trailing icon flips while typing.
    _pan.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pan.dispose(); _expiry.dispose(); _cvc.dispose();
    _holder.dispose(); _phone.dispose();
    super.dispose();
  }

  /// Client-side BIN detection — mirrors backend `detect_brand`. Lets the icon update as the user types.
  CardBrand _detectBrand(String pan) {
    final digits = pan.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith(RegExp(r'9860|6440'))) return CardBrand.humo;
    if (digits.startsWith(RegExp(r'8600|5614'))) return CardBrand.uzcard;
    if (digits.startsWith('4')) return CardBrand.visa;
    if (digits.startsWith(RegExp(r'5[1-5]|2[2-7]'))) return CardBrand.mastercard;
    return CardBrand.unknown;
  }

  /// Strip the typed PAN to digits + check 12-19 length. Returns null if invalid.
  String? _validatePan() {
    final digits = _pan.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 12 || digits.length > 19) return null;
    return digits;
  }

  /// Expect "MM/YY" or "MM/YYYY". Returns (mm, yy) or null when malformed/past.
  (int, int)? _parseExpiry() {
    final raw = _expiry.text.trim();
    final m = RegExp(r'^(\d{1,2})\s*/\s*(\d{2,4})$').firstMatch(raw);
    if (m == null) return null;
    final mm = int.tryParse(m.group(1)!) ?? 0;
    var yy = int.tryParse(m.group(2)!) ?? 0;
    if (mm < 1 || mm > 12) return null;
    if (yy < 24) yy += 2000;
    return (mm, yy);
  }

  /// True for cards that DON'T require a CVC (Uzbek-issued HUMO + UZCARD). The mobile UI hides the CVC
  /// field for these brands and the backend accepts the cards without one.
  bool _brandRequiresCvc(CardBrand brand) => brand == CardBrand.visa
      || brand == CardBrand.mastercard
      || brand == CardBrand.unknown;            // unknown defaults to "ask" — safer than skipping

  bool get _canSubmit {
    if (_submitting) return false;
    if (_validatePan() == null) return false;
    if (_parseExpiry() == null) return false;
    // CVC only required for international schemes. HUMO / UZCARD can submit with the field hidden.
    if (_brandRequiresCvc(_detectBrand(_pan.text))) {
      final cvc = _cvc.text.trim();
      if (cvc.length < 3 || cvc.length > 4) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    if (!_canSubmit) return;
    final digits = _validatePan()!;
    final (mm, yy) = _parseExpiry()!;
    setState(() { _submitting = true; _error = null; });
    HapticFeedback.selectionClick();
    // For HUMO / UZCARD we send an empty CVC even if the user typed something earlier (e.g. they pasted
    // a Visa, then changed to a HUMO number) — keeps the wire payload aligned with the brand.
    final brand = _detectBrand(_pan.text);
    final cvcForWire = _brandRequiresCvc(brand) ? _cvc.text.trim() : '';
    try {
      final card = await ref.read(cardsProvider.notifier).add(
        pan: digits, expiresMonth: mm, expiresYear: yy, cvc: cvcForWire,
        holderName: _holder.text.trim(), phoneForSms: _phone.text.trim(),
        makeDefault: _saveAsDefault,
      );
      if (!mounted) return;
      Navigator.pop(context, card);
    } on ApiException catch (e) {
      if (mounted) setState(() { _submitting = false; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _submitting = false; _error = t.cardsAddError; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final brand = _detectBrand(_pan.text);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
        child: SafeArea(top: false, child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Drag handle
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 8, bottom: 14),
                decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            // Header
            Row(children: [
              Expanded(child: Text(t.cardsAddTitle, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              IconButton.filledTonal(onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 18)),
            ]),
            const SizedBox(height: 18),

            // PAN field with live brand icon trailing. Auto-format with spaces every 4 digits.
            _LabeledField(
              label: t.cardsPan,
              child: TextField(
                controller: _pan,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(19),
                  _GroupOf4SpacesFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: '8600 1234 5678 9012',
                  suffixIcon: Padding(padding: const EdgeInsets.all(10),
                      child: _BrandBadge(brand: brand)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              )),
            const SizedBox(height: 14),

            // Expiry + (optional CVC) — HUMO / UZCARD skip the CVC entirely since Uzbek-issued cards
            // don't carry one. International cards (VISA / MASTERCARD / unknown BIN) still show the
            // CVC slot. Field-presence is brand-driven so it flips automatically as the buyer types.
            Row(children: [
              Expanded(child: _LabeledField(
                label: t.cardsExpiry,
                child: TextField(
                  controller: _expiry,
                  keyboardType: TextInputType.datetime,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d/]')),
                    LengthLimitingTextInputFormatter(7),
                    _ExpiryAutoSlashFormatter(),
                  ],
                  decoration: InputDecoration(hintText: 'MM/YY',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))))),
              if (_brandRequiresCvc(brand)) ...[
                const SizedBox(width: 12),
                Expanded(child: _LabeledField(
                  label: 'CVC',
                  child: TextField(
                    controller: _cvc,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(hintText: '•••',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))))),
              ],
            ]),
            const SizedBox(height: 14),

            _LabeledField(
              label: t.cardsHolder,
              child: TextField(
                controller: _holder,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [LengthLimitingTextInputFormatter(80)],
                decoration: InputDecoration(hintText: 'JASUR MAMARASULOV',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
            const SizedBox(height: 14),

            _LabeledField(
              label: t.cardsPhone,
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                  LengthLimitingTextInputFormatter(15),
                ],
                decoration: InputDecoration(hintText: '+998 90 123 45 67',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
            const SizedBox(height: 14),

            SwitchListTile.adaptive(
              value: _saveAsDefault,
              onChanged: (v) => setState(() => _saveAsDefault = v),
              title: Text(t.cardsMakeDefault, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              contentPadding: EdgeInsets.zero,
              dense: true),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 18),

            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: _canSubmit ? _submit : null,
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(t.cardsAddCta, style: tt.titleMedium?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800))),
            const SizedBox(height: 8),
            Text(t.cardsPciNote, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
          ]),
        )),
      ),
    );
  }
}


// ---------- Helpers ----------

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 6, bottom: 6),
        child: Text(label, style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700))),
      child,
    ]);
  }
}


/// Small pill rendering the detected brand. Shown inline next to the PAN field while typing.
class _BrandBadge extends StatelessWidget {
  final CardBrand brand;
  const _BrandBadge({required this.brand});

  @override
  Widget build(BuildContext context) {
    final (label, color, fg) = switch (brand) {
      CardBrand.visa => ('VISA', const Color(0xFF1A1F71), Colors.white),
      CardBrand.mastercard => ('MC', const Color(0xFFEB001B), Colors.white),
      CardBrand.humo => ('HUMO', const Color(0xFF008080), Colors.white),
      CardBrand.uzcard => ('UZCARD', const Color(0xFF002F87), Colors.white),
      CardBrand.unknown => ('CARD', Colors.grey, Colors.white),
    };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w900,
          fontSize: 10, letterSpacing: 0.5)));
  }
}


/// Inserts a space every 4 digits ("8600123412345678" → "8600 1234 1234 5678"). Cursor handling is
/// intentionally simple — Flutter places the cursor at the end after each insert, which is what we want
/// for a left-to-right typed field.
class _GroupOf4SpacesFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length));
  }
}


/// Auto-insert the slash between MM and YY ("1225" → "12/25"). Lets the buyer type without reaching
/// for the symbol key.
class _ExpiryAutoSlashFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 3) {
      text = '${digits.substring(0, 2)}/${digits.substring(2, digits.length.clamp(0, 6))}';
    } else {
      text = digits;
    }
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
