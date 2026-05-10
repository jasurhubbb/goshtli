// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Meat Marketplace';

  @override
  String get signIn => 'Sign in';

  @override
  String get welcomeSubtitle => 'Welcome back to Meat Marketplace';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get passwordMin8 => 'Password (min 8)';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get fullName => 'Full name';

  @override
  String get phone => 'Phone';

  @override
  String get createAccount => 'Create account';

  @override
  String get noAccountCta => 'Don\'t have an account? Create one';

  @override
  String get haveAccountCta => 'Already have an account? Sign in';

  @override
  String get validateEmail => 'Enter a valid email';

  @override
  String get validateMin8 => 'Min 8 characters';

  @override
  String get validatePasswordMatch => 'Passwords do not match';

  @override
  String get validateName => 'Enter your name';

  @override
  String get roleBuyer => 'Buyer';

  @override
  String get roleSupplier => 'Supplier';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get home => 'Home';

  @override
  String get buyerHome => 'Buyer home';

  @override
  String get supplierHome => 'Supplier home';

  @override
  String get profile => 'Profile';

  @override
  String get logout => 'Logout';

  @override
  String get refresh => 'Refresh';

  @override
  String get language => 'Language';

  @override
  String get tabHome => 'Home';

  @override
  String get tabSearch => 'Search';

  @override
  String get tabNotifications => 'Notifications';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabProfile => 'Profile';

  @override
  String get chatsTitle => 'Chats';

  @override
  String get chatsComingSoon => 'Chat coming in Milestone C';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountConfirmTitle => 'Delete your account?';

  @override
  String get deleteAccountConfirmBody =>
      'This permanently removes your profile, listings, and order history. This cannot be undone.';

  @override
  String get deleteAccountConfirmYes => 'Yes, delete';

  @override
  String get becomeSeller => 'Become a seller';

  @override
  String get halal => 'Halal';

  @override
  String get freshnessDate => 'Freshness date';

  @override
  String get coldChainFresh => 'Fresh';

  @override
  String get coldChainChilled => 'Chilled';

  @override
  String get coldChainFrozen => 'Frozen';

  @override
  String get serviceArea => 'Service area';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get removePhoto => 'Remove';

  @override
  String get photoRequired => 'At least one photo required';

  @override
  String greeting(String name) {
    return 'Hello, $name 👋';
  }

  @override
  String get verificationPendingBanner =>
      'Account pending verification — listing creation is locked until an admin verifies you.';

  @override
  String get sectionListings => 'Listings';

  @override
  String get sectionOrders => 'Orders';

  @override
  String get browseListings => 'Browse listings';

  @override
  String get myOrders => 'My orders';

  @override
  String get myListings => 'My listings';

  @override
  String get incomingOrders => 'Incoming orders';

  @override
  String get newListing => 'New listing';

  @override
  String get statTotal => 'Total';

  @override
  String get statActive => 'Active';

  @override
  String get statSoldOut => 'Sold out';

  @override
  String get statInactive => 'Inactive';

  @override
  String get statPending => 'Pending';

  @override
  String get statInProgress => 'In progress';

  @override
  String get statDelivered => 'Delivered';

  @override
  String get statCancelled => 'Cancelled';

  @override
  String get listingsTitle => 'Listings';

  @override
  String get noListingsMatchFilters => 'No listings match these filters';

  @override
  String get searchListingsHint => 'Search title or description';

  @override
  String get kgAvailableSuffix => 'kg avail';

  @override
  String get perKgSuffix => '/ kg';

  @override
  String get listingFieldTitle => 'Title';

  @override
  String get listingFieldMeatType => 'Meat type';

  @override
  String get listingFieldStatus => 'Status';

  @override
  String get listingFieldPricePerKg => 'Price / kg';

  @override
  String get listingFieldQuantity => 'Quantity (kg)';

  @override
  String get listingFieldAvailable => 'Available';

  @override
  String get listingFieldLocation => 'Location';

  @override
  String get listingFieldAvailableFrom => 'Available from';

  @override
  String get listingFieldDescription => 'Description';

  @override
  String get listingFieldDescriptionOptional => 'Description (optional)';

  @override
  String get listingPickAvailableFrom => 'Pick an available-from date';

  @override
  String get listingMinTitleChars => 'Min 3 chars';

  @override
  String get validateGtZero => '> 0 required';

  @override
  String get validateRequired => 'Required';

  @override
  String get createListingButton => 'Create listing';

  @override
  String get listingDetailTitle => 'Listing';

  @override
  String get listingActionPlaceOrder => 'Place order';

  @override
  String get listingActionEdit => 'Edit';

  @override
  String get listingActionDeactivate => 'Deactivate';

  @override
  String get listingActionSave => 'Save';

  @override
  String get listingStatusActive => 'Active';

  @override
  String get listingStatusSoldOut => 'Sold out';

  @override
  String get listingStatusInactive => 'Inactive';

  @override
  String get meatBeef => 'Beef';

  @override
  String get meatMutton => 'Mutton';

  @override
  String get meatChicken => 'Chicken';

  @override
  String get meatGoat => 'Goat';

  @override
  String get meatHorse => 'Horse';

  @override
  String get meatOther => 'Other';

  @override
  String get myOrdersTitle => 'My orders';

  @override
  String get incomingOrdersTitle => 'Incoming orders';

  @override
  String get noOrdersYet => 'No orders yet';

  @override
  String get filterAll => 'All';

  @override
  String orderDetailTitle(int id) {
    return 'Order #$id';
  }

  @override
  String orderFromLabel(String email) {
    return 'From: $email';
  }

  @override
  String orderToLabel(String email) {
    return 'To: $email';
  }

  @override
  String get orderFieldDeliveryAddress => 'Delivery address';

  @override
  String get orderFieldNotes => 'Notes';

  @override
  String get orderFieldNotesOptional => 'Notes (optional)';

  @override
  String orderPlaceTitle(String title) {
    return 'Place order — $title';
  }

  @override
  String orderAvailabilityHint(String qty, String price) {
    return 'Available: $qty kg @ $price / kg';
  }

  @override
  String get orderQtyAddrRequired =>
      'Quantity and delivery address are required';

  @override
  String orderOnlyKgAvailable(String qty) {
    return 'Only ${qty}kg available';
  }

  @override
  String get orderConfirmButton => 'Confirm order';

  @override
  String get orderPlacedSnack => 'Order placed';

  @override
  String get orderCancelButton => 'Cancel order';

  @override
  String get orderCancelTitle => 'Cancel order?';

  @override
  String get orderCancelBody =>
      'Stock will be restored on the listing. This cannot be undone.';

  @override
  String get no => 'No';

  @override
  String get orderActionConfirm => 'Confirm';

  @override
  String get orderActionStartProcessing => 'Start processing';

  @override
  String get orderActionMarkInTransit => 'Mark in transit';

  @override
  String get orderActionMarkDelivered => 'Mark delivered';

  @override
  String get orderActionCancel => 'Cancel';

  @override
  String orderTerminalNoActions(String status) {
    return 'No further actions — order is $status';
  }

  @override
  String get orderStatusPending => 'Pending';

  @override
  String get orderStatusConfirmed => 'Confirmed';

  @override
  String get orderStatusProcessing => 'Processing';

  @override
  String get orderStatusInTransit => 'In transit';

  @override
  String get orderStatusDelivered => 'Delivered';

  @override
  String get orderStatusCancelled => 'Cancelled';

  @override
  String get profileTitle => 'Profile';

  @override
  String get buyerProfileTitle => 'Buyer profile';

  @override
  String get supplierProfileTitle => 'Supplier profile';

  @override
  String get profileFieldBusinessName => 'Business name';

  @override
  String get profileFieldRegion => 'Region';

  @override
  String get profileFieldAddress => 'Address';

  @override
  String get profileVerified => 'Verified';

  @override
  String get profileUnverified => 'Unverified';

  @override
  String get profileSavedSnack => 'Saved';

  @override
  String get profileAdminViaDjango =>
      'Admin profile editing is via Django Admin';

  @override
  String failedPrefix(String error) {
    return 'Failed: $error';
  }
}
