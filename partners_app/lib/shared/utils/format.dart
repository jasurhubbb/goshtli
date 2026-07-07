/// Thousand-separated so'm rendering — mirrors the buyer app's convention (space as thousands sep,
/// no currency symbol; callers append "so'm").
String formatSoum(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}
