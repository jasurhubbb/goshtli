// Localized labels for the three closed enums (MeatType, ListingStatus, OrderStatus).
// Extension methods so callers write `meatType.label(context)` instead of plumbing AppLocalizations through every helper.
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../models/listing.dart';
import '../models/order.dart' as model;


extension MeatTypeL10n on MeatType {
  String label(BuildContext context) {
    final t = AppLocalizations.of(context);
    return switch (this) {
      MeatType.beef => t.meatBeef, MeatType.mutton => t.meatMutton, MeatType.chicken => t.meatChicken,
      MeatType.goat => t.meatGoat, MeatType.horse => t.meatHorse, MeatType.other => t.meatOther,
    };
  }
}


extension ListingStatusL10n on ListingStatus {
  String label(BuildContext context) {
    final t = AppLocalizations.of(context);
    return switch (this) {
      ListingStatus.active => t.listingStatusActive,
      ListingStatus.soldOut => t.listingStatusSoldOut,
      ListingStatus.inactive => t.listingStatusInactive,
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
