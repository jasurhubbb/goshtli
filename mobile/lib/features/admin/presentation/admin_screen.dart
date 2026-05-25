// AdminScreen — gated by the "Admin sifatida kirish" password prompt on the Profile tab.
//
// Auth model (v3.3):
//   The admin gate is a SEPARATE auth context (AdminAuthNotifier + AdminTokenStorage + AdminApiClient).
//   It never touches the main app's user session. Entering /admin while logged in as a buyer keeps the
//   buyer session intact; exiting /admin (or tapping the lock button) drops the admin tokens only.
//
// Two tabs:
//   • Yangi e'lon  — form to create a listing for a chosen Bozor (Market = supplier; resolved server-side)
//   • Boshqarish  — list of 3 sub-sections (E'lonlar / Bozorlar / Kategoriyalar)
//
// Lock button (top right): admin's explicit "exit" — clears admin tokens and pops back to wherever they
// were in the main app. Useful when admins want to hand the phone back without leaving admin powers cached.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../providers/admin_auth_providers.dart';
import 'admin_new_listing_tab.dart';
import 'admin_manage_tab.dart';


class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return DefaultTabController(length: 2, child: Scaffold(
      appBar: AppBar(
        title: Text(t.adminTitle),
        actions: [
          // Lock the admin gate — clears admin tokens ONLY (main app session is untouched). The router's
          // redirect on /admin → /profile fires automatically once adminAuth flips back to locked.
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: t.logout,
            onPressed: () async {
              await ref.read(adminAuthNotifierProvider.notifier).lock();
              // Router redirect will bounce us off /admin → /profile automatically; pop just in case the
              // redirect didn't fire (e.g. routes that don't observe the gate).
              if (context.mounted && context.canPop()) context.pop();
            },
          ),
        ],
        bottom: TabBar(tabs: [
          Tab(text: t.adminTabNewListing),
          Tab(text: t.adminTabManage),
        ]),
      ),
      body: const TabBarView(children: [
        AdminNewListingTab(),
        AdminManageTab(),
      ]),
    ));
  }
}


// ---- Manage-tab sub-section nav target ---------------------------------------

/// Section IDs for the Boshqarish sub-screens. Routed via /admin/manage/<id> so deep links work and back
/// navigation pops back to the section list (not the tab bar).
///
/// v3.3: Suppliers were folded into Markets — each Bozor (Market) auto-gets a backing SUPPLIER User on the
/// backend, so there's only one concept to manage in the UI. The enum value was removed entirely.
enum AdminSection { listings, categories, markets }


/// Convenience wrapper that opens a manage sub-section. Used from AdminManageTab tiles.
void openAdminSection(BuildContext context, AdminSection s) {
  context.push('/admin/manage/${s.name}');
}
