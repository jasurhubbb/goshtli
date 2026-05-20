// Localized labels for the closed enums (ListingStatus, OrderStatus).
// Extension methods so callers write `status.label(context)` instead of plumbing AppLocalizations through every helper.
//
// v3.1 catalog overhaul: the MeatType extension is gone — meat category is now a server-side FK (MeatCategory)
// with bilingual name fields, so the label() call doesn't need a client-side enum mapping.
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../models/listing.dart';
import '../models/order.dart' as model;


extension ListingStatusL10n on ListingStatus {
  String label(BuildContext context) {
    final t = AppLocalizations.of(context);
    return switch (this) {
      ListingStatus.active => t.listingStatusActive,
      ListingStatus.outOfStock => t.listingStatusSoldOut,
      ListingStatus.archived => t.listingStatusInactive,
    };
  }
}


extension OrderStatusL10n on model.OrderStatus {
  String label(BuildContext context) {
    final t = AppLocalizations.of(context);
    return switch (this) {
      model.OrderStatus.pending => t.orderStatusPending,
      model.OrderStatus.confirmed => t.orderStatusConfirmed,
      model.OrderStatus.processing => t.orderStatusProcessing,
      model.OrderStatus.inTransit => t.orderStatusInTransit,
      model.OrderStatus.delivered => t.orderStatusDelivered,
      model.OrderStatus.cancelled => t.orderStatusCancelled,
    };
  }
}
