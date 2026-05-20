// ListingsScreen — placeholder.
//
// The full filter-driven browse view from v2 was removed when v3.1 collapsed the bottom nav to four tabs
// (Menyu / Savat / Buyurtmalar / Profil). The Menyu tab now renders products directly via the listings provider.
// This screen stays in the router only because a few legacy deep-links still point at /search; it will be either
// rebuilt as a proper search experience or removed entirely once those links are dead.
import 'package:flutter/material.dart';


class ListingsScreen extends StatelessWidget {
  const ListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Padding(padding: EdgeInsets.all(32),
        child: Text('Coming soon.\n\nUse the Menyu tab to browse products.',
            textAlign: TextAlign.center))),
    );
  }
}
