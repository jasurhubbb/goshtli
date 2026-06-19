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

  @override
  String get viewAll => 'View all';

  @override
  String get sectionFarmers => 'Farmers';

  @override
  String get sectionButchers => 'Butchers';

  @override
  String get appLanguage => 'App language';

  @override
  String appVersionLabel(String version) {
    return 'App version $version';
  }

  @override
  String get privacyPolicyLink => 'privacy policy';

  @override
  String get termsOfUseLink => 'terms of use';

  @override
  String privacyTagline(String policy, String terms) {
    return 'By tapping, I accept the $policy & $terms.';
  }

  @override
  String get anonWelcomeTitle => 'Welcome to Meat Marketplace';

  @override
  String get anonWelcomeSubtitle =>
      'Browse listings — you\'ll register when placing an order.';

  @override
  String get onbLocationTitle => 'Your area';

  @override
  String get onbLocationBody =>
      'We use your location to show nearby meat sellers. This is optional — you can change it later in Profile.';

  @override
  String get onbDetectLocation => 'Detect location';

  @override
  String get onbNotNow => 'Not now';

  @override
  String get pickLanguageTitle => 'Choose language';

  @override
  String get continueAction => 'Continue';

  @override
  String get savedListingsTitle => 'Favorite listings';

  @override
  String get noSavedListingsYet => 'No saved listings yet';

  @override
  String get messageHint => 'Message…';

  @override
  String get noConversationsYet => 'No conversations yet';

  @override
  String get noNotificationsYet => 'No notifications yet';

  @override
  String get leaveReviewTitle => 'Leave a review';

  @override
  String get reviewCommentOptional => 'Comment (optional)';

  @override
  String get serviceAreaHint => 'Tashkent, Samarkand, ...';

  @override
  String get tabMenu => 'Menu';

  @override
  String get tabCart => 'Cart';

  @override
  String get tabOrders => 'Orders';

  @override
  String get cartTitle => 'Cart';

  @override
  String cartItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: '0 items',
    );
    return '$_temp0';
  }

  @override
  String get cartEmptyTitle => 'Your cart is empty';

  @override
  String get cartEmptyHint => 'Tap any product on the Menu to add it here.';

  @override
  String get cartGoToMenu => 'Go to menu';

  @override
  String get cartShopNoteLabel => 'Note to the shop';

  @override
  String get cartShopNoteHint =>
      'E.g. cut into 1 kg pieces, no bones, deliver in the evening';

  @override
  String get cartSubTotal => 'Subtotal';

  @override
  String get cartTotal => 'TOTAL';

  @override
  String get cartCheckout => 'Place order';

  @override
  String get cartCheckoutSnack => 'Order placed — backend wiring coming soon.';

  @override
  String get soumSuffix => 'so\'m';

  @override
  String get perKgShort => '/kg';

  @override
  String get cartAdd => 'Add';

  @override
  String get cartPeekTitle => 'Your cart';

  @override
  String get cartPeekChip => 'View';

  @override
  String get cartPeekViewAll => 'Add more';

  @override
  String cartItemsShort(int count) {
    return '$count pcs';
  }

  @override
  String get cartFloatingPeek => 'Tap to peek';

  @override
  String get menuTitle => 'Menu';

  @override
  String get menuPickHint => 'Pick what you\'ll cook today';

  @override
  String get homeSearchHint => 'Search products...';

  @override
  String get homeRegionPickerTitle => 'Choose region';

  @override
  String get homeRegionAll => 'All regions';

  @override
  String get addressesTitle => 'Addresses';

  @override
  String get addressesEmpty => 'No saved addresses yet.';

  @override
  String get addressesNewCta => 'New address';

  @override
  String get addressesSignInCta => 'Sign in to save addresses';

  @override
  String get addressFormTitleNew => 'New address';

  @override
  String get addressFormTitleEdit => 'Address details';

  @override
  String get addressFieldLabel => 'Address label';

  @override
  String get addressFieldLabelHint => 'Home, Office, Restaurant...';

  @override
  String get addressFieldStreet => 'Address';

  @override
  String get addressFieldStreetHint => 'Street, neighbourhood, house number';

  @override
  String get addressFieldEntrance => 'Entrance';

  @override
  String get addressFieldFloor => 'Floor';

  @override
  String get addressFieldApartment => 'Apartment';

  @override
  String get addressFieldNotes => 'Delivery instructions';

  @override
  String get addressFieldNotesHelp => 'Helps the courier find you faster';

  @override
  String get addressFieldDefault => 'Make this my default address';

  @override
  String get addressSaveCta => 'Save address';

  @override
  String get addressDeleteCta => 'Delete';

  @override
  String get addressDeleteConfirm => 'Delete this address?';

  @override
  String get addressMapTitle => 'Pick your address on the map';

  @override
  String get addressMapConfirmTitle => 'Everything correct?';

  @override
  String get addressMapConfirmBody =>
      'Make sure the marker is at the entrance and confirm';

  @override
  String get addressMapConfirmCta => 'Refine house number';

  @override
  String get addressMapMyLocation => 'My location';

  @override
  String get phoneAuthTitle => 'Your phone number';

  @override
  String get phoneAuthSubtitle => 'Enter your number to sign in or sign up';

  @override
  String get phoneAuthHint => '90 123-45-67';

  @override
  String get phoneAuthContinue => 'Continue';

  @override
  String get phoneAuthInvalid => 'Enter a 9-digit phone number';

  @override
  String get phoneDetailsTitle => 'About you';

  @override
  String get phoneDetailsSubtitle => 'We need your name for orders';

  @override
  String get phoneDetailsNameLabel => 'Your name';

  @override
  String get phoneDetailsBusinessLabel => 'Business name (optional)';

  @override
  String get phoneDetailsCta => 'Sign in';

  @override
  String get profileSettingsTitle => 'Profile settings';

  @override
  String get profileTapToEdit => 'Edit';

  @override
  String get profileFieldLastName => 'Last name';

  @override
  String get profileFieldFirstName => 'First name';

  @override
  String get profileFieldPatronymic => 'Patronymic';

  @override
  String get profileFieldPatronymicHint => 'Enter patronymic';

  @override
  String get profileFieldDateOfBirth => 'Date of birth';

  @override
  String get profileFieldDateOfBirthHint => 'Pick a date';

  @override
  String get profileFieldGender => 'Gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get profileFieldPhone => 'Phone number';

  @override
  String get profileMyCards => 'My cards';

  @override
  String get profileCardsEmpty => 'No cards yet';

  @override
  String get profileContactUs => 'Contact us';

  @override
  String get profileTelegramOpenFailed => 'Could not open Telegram';

  @override
  String get cancel => 'Cancel';

  @override
  String get adminEnterCta => 'Enter as admin';

  @override
  String get adminEnterPasswordTitle => 'Admin password';

  @override
  String get adminEnterPasswordHint => 'Enter password';

  @override
  String get adminEnterPasswordWrong => 'Wrong password';

  @override
  String get adminTitle => 'Admin';

  @override
  String get adminTabNewListing => 'New listing';

  @override
  String get adminTabManage => 'Manage';

  @override
  String get adminNewListingPickSupplier => 'Pick a supplier';

  @override
  String get adminNewListingSubmit => 'Save listing';

  @override
  String get adminManageListings => 'Listings';

  @override
  String get adminManageSuppliers => 'Suppliers';

  @override
  String get adminManageCategories => 'Categories';

  @override
  String get adminManageMarkets => 'Markets';

  @override
  String get adminManageHint => 'Create/edit items in the selected section';

  @override
  String get adminComingSoon => 'Coming soon';

  @override
  String get adminListingCreated => 'Listing created';

  @override
  String get adminPermissionDenied =>
      'Admin permissions required — sign in with an admin account';

  @override
  String get adminNewListingPhotos => 'Photos';

  @override
  String get adminPickFromGallery => 'Pick from gallery';

  @override
  String get adminPickFromCamera => 'Take a photo';

  @override
  String get adminMarketDetailListings => 'Listings at this market';

  @override
  String get adminMarketEditCta => 'Edit';

  @override
  String get adminMarketDeleteCta => 'Delete market';

  @override
  String get adminMarketPhoneLabel => 'Phone number';

  @override
  String get adminMarketEmpty => 'No listings yet';

  @override
  String get adminListingEditTitle => 'Edit listing';

  @override
  String get adminListingSavedToast => 'Saved';

  @override
  String get adminListingDeleteCta => 'Delete listing';

  @override
  String get statusActive => 'Active';

  @override
  String get statusSoldOut => 'Sold out';

  @override
  String get statusInactive => 'Inactive';

  @override
  String get addressAutoDetectedHint => 'Detected location · tap to refine';

  @override
  String get otpTitle => 'Verification code';

  @override
  String otpSentTo(String phone) {
    return 'Code sent to $phone';
  }

  @override
  String get otpResend => 'Resend code';

  @override
  String otpResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get otpInvalidCode => 'Invalid code';

  @override
  String get otpExpired => 'Code expired — request a new one';

  @override
  String get qtyEditorTitle => 'Quantity (kg)';

  @override
  String get qtyEditorEnterAmount => 'Enter an amount';

  @override
  String get qtyEditorOnlyDigits => 'Digits only';

  @override
  String get qtyEditorMustBePositive => 'Must be greater than zero';

  @override
  String qtyEditorMaxExceeded(int max) {
    return 'Max: $max kg';
  }

  @override
  String qtyEditorAvailable(int max) {
    return 'Available: $max kg';
  }

  @override
  String get qtyEditorMax => 'All';

  @override
  String get qtyEditorConfirm => 'Confirm';

  @override
  String get payTitle => 'Payment';

  @override
  String get payProcessing => 'Processing payment…';

  @override
  String get payCheckingStatus => 'Checking status…';

  @override
  String get paySuccessTitle => 'Payment successful';

  @override
  String get paySuccessBody => 'Your order has been accepted';

  @override
  String get payFailedTitle => 'Payment failed';

  @override
  String get payRetry => 'Try again';

  @override
  String get payToOrders => 'Go to orders';

  @override
  String get payCancel => 'Cancel';

  @override
  String qtyEditorBelowMinimum(int min) {
    return 'Minimum: $min';
  }

  @override
  String get liveAnimalBadgeByHead => '1 HEAD';

  @override
  String get liveAnimalBadgeByWeight => 'LIVE WEIGHT';

  @override
  String get deliveryTitle => 'Delivery';

  @override
  String get deliveryAddressSection => 'Address';

  @override
  String get deliveryAddressChange => 'Change';

  @override
  String deliveryDistanceLabel(String km) {
    return 'Distance: $km km';
  }

  @override
  String get deliveryVehicleSection => 'Vehicle type';

  @override
  String get deliveryVehicleRefrigerator => 'Refrigerator';

  @override
  String get deliveryVehicleRefrigeratorHint => 'Cold chain • 0°C to +4°C';

  @override
  String get deliveryVehicleChorvaTaxi => 'Chorva-Taxi';

  @override
  String get deliveryVehicleChorvaTaxiHint =>
      'Special transport for live animals';

  @override
  String get deliveryVehicleUnavailable => 'Unavailable';

  @override
  String get deliveryTimeSlotSection => 'Time slot';

  @override
  String get deliveryTimeSlot0609 => '06:00 – 09:00';

  @override
  String get deliveryTimeSlot0913 => '09:00 – 13:00';

  @override
  String get deliveryTimeSlot1318 => '13:00 – 18:00';

  @override
  String get deliveryButcherSection => 'Butcher service';

  @override
  String get deliveryButcherTitle =>
      'Need slaughter and butchering for the live animal?';

  @override
  String get deliveryButcherSubtitle =>
      'Professional butcher service: slaughter, cleaning and packaging.';

  @override
  String deliveryButcherFeeLabel(String fee) {
    return 'Service fee: $fee';
  }

  @override
  String get deliveryButcherAccept => 'Add butcher service';

  @override
  String get deliveryBreakdownSection => 'Breakdown';

  @override
  String get deliveryBreakdownProducts => 'Products';

  @override
  String get deliveryBreakdownDelivery => 'Delivery';

  @override
  String get deliveryBreakdownButcher => 'Butcher service';

  @override
  String get deliveryBreakdownTotal => 'TOTAL';

  @override
  String get deliveryProceedCta => 'Proceed to payment';

  @override
  String get deliveryNeedAddress => 'Please set an address first';

  @override
  String get deliveryLoadingQuote => 'Loading quote…';

  @override
  String get deliveryQuoteError => 'Couldn\'t load the quote. Try again.';

  @override
  String get deliveryPickMapHint => 'Pick the address on the map';

  @override
  String get deliveryFloorMin => 'Minimum order is 10 kg (wholesale).';

  @override
  String get deliveryTashkentOnlyBanner =>
      'We currently deliver only within Tashkent city. The quote is calculated from the city centre.';

  @override
  String get deliveryTashkentOnlyShort => 'Tashkent only for now';

  @override
  String get testUseYunusobod => 'TEST: use Yunusobod (Tashkent) location';

  @override
  String get testYunusobodApplied => 'Location set to Yunusobod';

  @override
  String get cardsTitle => 'My cards';

  @override
  String get cardsAddTitle => 'Add card';

  @override
  String get cardsAddCta => 'Add card';

  @override
  String get cardsAddError => 'Couldn\'t add the card. Try again.';

  @override
  String get cardsPan => 'Card number';

  @override
  String get cardsExpiry => 'Expiry';

  @override
  String get cardsHolder => 'Cardholder name';

  @override
  String get cardsPhone => 'Phone for SMS';

  @override
  String get cardsMakeDefault => 'Make this the default card';

  @override
  String get cardsPciNote =>
      'Card data is sent over an encrypted channel. We never store the full card number.';

  @override
  String get cardsEmptyTitle => 'No cards yet';

  @override
  String get cardsEmptyHint => 'Add a card to pay for your orders.';

  @override
  String get cardsLoadError => 'Couldn\'t load cards.';

  @override
  String get cardsDefaultBadge => 'DEFAULT';

  @override
  String get cardsExpiredLabel => 'Card expired';

  @override
  String get cardsActionMakeDefault => 'Set as default';

  @override
  String get cardsActionDelete => 'Delete';

  @override
  String get cardsDeletedSnack => 'Card deleted';

  @override
  String get paymentAmountLabel => 'Amount to pay';

  @override
  String get paymentMethodSection => 'Payment method';

  @override
  String paymentPayCta(String amount) {
    return 'Pay · $amount';
  }

  @override
  String get paymentPayCtaShort => 'Pay';

  @override
  String paymentSuccessCardLine(String brand, String last4) {
    return 'Paid with $brand •••• $last4';
  }

  @override
  String get authServerUnavailable =>
      'Server is temporarily unavailable. Please try again in a moment.';

  @override
  String get authNetworkError =>
      'No internet connection. Check your connection and try again.';

  @override
  String get authNetworkTimeout => 'The request timed out. Please try again.';

  @override
  String get authUnexpectedError =>
      'Something went wrong. Please try again later.';
}
