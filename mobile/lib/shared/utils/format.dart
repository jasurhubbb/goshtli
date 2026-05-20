// Tiny number-formatting helpers — kept dependency-free so they're cheap to import anywhere. If we later add
// `package:intl` NumberFormat usage elsewhere, we can swap these for that without changing call sites.

/// Format an integer so'm value with thin-space thousands separators. "95000" → "95 000".
/// Uses a thin no-break space (U+202F) so the digits never wrap and the gap stays visually consistent across fonts.
String formatSoum(int value) {
  if (value < 1000) return value.toString();
  final s = value.toString();
  final buf = StringBuffer();
  final firstGroupLen = s.length % 3 == 0 ? 3 : s.length % 3;
  buf.write(s.substring(0, firstGroupLen));
  for (var i = firstGroupLen; i < s.length; i += 3) {
    buf.write(' ');
    buf.write(s.substring(i, i + 3));
  }
  return buf.toString();
}
