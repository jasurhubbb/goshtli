// ListingCreateScreen — placeholder.
//
// The supplier-side "create listing" flow was removed when v3.1 collapsed the app to buyer-only. Listings are
// now created exclusively by staff via Django Admin. This screen stays in the router only because /listings/new
// is still a known path; it will be removed once we're confident nothing links here.
import 'package:flutter/material.dart';


class ListingCreateScreen extends StatelessWidget {
  const ListingCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Padding(padding: EdgeInsets.all(32),
        child: Text('Listings are created by staff in the admin dashboard.',
            textAlign: TextAlign.center))),
    );
  }
}
