// AdminManageTab — landing list for the Boshqarish tab. Each tile opens its own management screen.
//
// Layout: 4 vertically stacked tiles (Listings · Suppliers · Categories · Markets). Single-screen feel,
// no nested tabs. Drilling into a section pushes a new screen above /admin so back returns here.
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'admin_screen.dart' show AdminSection, openAdminSection;


class AdminManageTab extends StatelessWidget {
  const AdminManageTab({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // (icon, label, AdminSection) per tile — kept here as a list literal so reordering is one edit.
    // v3.3: "Yetkazib beruvchilar" (Suppliers) removed — Bozor IS the supplier (one concept). Each Market
    // auto-gets a backing SUPPLIER User on the backend, so admin only sees Markets.
    final tiles = <(IconData, String, AdminSection)>[
      (Icons.inventory_2_outlined, t.adminManageListings, AdminSection.listings),
      (Icons.storefront_outlined, t.adminManageMarkets, AdminSection.markets),
      (Icons.category_outlined, t.adminManageCategories, AdminSection.categories),
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 32), children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text(t.adminManageHint, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
      Container(decoration: BoxDecoration(color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
        child: Column(children: [
          for (int i = 0; i < tiles.length; i++) ...[
            ListTile(
              leading: Icon(tiles[i].$1, color: cs.primary),
              title: Text(tiles[i].$2, style: tt.bodyLarge),
              trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              onTap: () => openAdminSection(context, tiles[i].$3),
            ),
            if (i < tiles.length - 1) Padding(padding: const EdgeInsets.only(left: 56),
                child: Divider(height: 0.5, color: cs.outlineVariant.withValues(alpha: 0.5))),
          ],
        ])),
    ]);
  }
}
