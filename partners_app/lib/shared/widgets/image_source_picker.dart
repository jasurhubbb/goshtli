import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';


/// Modal bottom sheet that asks the user whether they want to pick an image from the **camera** or
/// **gallery**. Returns the picked file's path (or null if the user cancels).
///
/// Used everywhere we need an optional/required image: wizard photo pages (qassob + supplier),
/// new-listing form, Servisim gallery uploads. Previously every call site hard-coded
/// `ImageSource.camera`, which forced users without a working camera (rare but happens — broken
/// camera permission, indoor pickup of an existing photo) into a dead-end.
Future<String?> showImageSourcePicker(BuildContext context, {
  int maxWidth = 1600,
  int imageQuality = 85,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SafeArea(top: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 4,
            margin: const EdgeInsets.only(top: 6, bottom: 16),
            decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2)))),
        Text("Rasm tanlash",
            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        _SourceTile(icon: Icons.camera_alt_rounded, label: "Kamera bilan suratga olish",
            onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        const SizedBox(height: 10),
        _SourceTile(icon: Icons.photo_library_rounded, label: "Galereyadan tanlash",
            onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        const SizedBox(height: 4),
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text("Bekor qilish")),
      ]))));
  if (source == null) return null;
  try {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source,
        maxWidth: maxWidth.toDouble(), imageQuality: imageQuality);
    return file?.path;
  } catch (_) {
    return null;
  }
}


class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant)),
        child: Row(children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 14),
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        ])));
  }
}
