import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';


/// Uzbekistan couriers routinely have Yandex.Navigator OR Google Maps but rarely both. Always give
/// them a chooser instead of hard-coding one — trying to launch Yandex when only Google is installed
/// fails silently on Android and the courier gets stuck.
Future<void> openMapChooser(BuildContext context,
    {required double lat, required double lng, required String label}) async {
  final choice = await showModalBottomSheet<String>(context: context,
    shape: const RoundedRectangleBorder(borderRadius:
        BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(label,
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800))),
        ListTile(leading: const Icon(Icons.map_rounded, color: Color(0xFFFF0000)),
            title: const Text('Yandex Navigator'),
            onTap: () => Navigator.of(ctx).pop('yandex')),
        ListTile(leading: const Icon(Icons.map, color: Color(0xFF34A853)),
            title: const Text('Google Maps'),
            onTap: () => Navigator.of(ctx).pop('google')),
        ListTile(leading: const Icon(Icons.close), title: const Text('Bekor qilish'),
            onTap: () => Navigator.of(ctx).pop()),
        const SizedBox(height: 8),
      ])));
  if (choice == null) return;
  final uri = switch (choice) {
    'yandex' => Uri.parse('yandexnavi://build_route_on_map?lat_to=$lat&lon_to=$lng'),
    _        => Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
  };
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && choice == 'yandex') {
    // Fallback — user picked Yandex but doesn't have it installed. Try Yandex web maps instead of
    // silently failing.
    await launchUrl(Uri.parse('https://yandex.com/maps/?rtext=~$lat,$lng&rtt=auto'),
        mode: LaunchMode.externalApplication);
  }
}
