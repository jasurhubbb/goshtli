import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
    Locale('uz'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Meat Marketplace'**
  String get appTitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back to Meat Marketplace'**
  String get welcomeSubtitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordMin8.
  ///
  /// In en, this message translates to:
  /// **'Password (min 8)'**
  String get passwordMin8;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @noAccountCta.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Create one'**
  String get noAccountCta;

  /// No description provided for @haveAccountCta.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccountCta;

  /// No description provided for @validateEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get validateEmail;

  /// No description provided for @validateMin8.
  ///
  /// In en, this message translates to:
  /// **'Min 8 characters'**
  String get validateMin8;

  /// No description provided for @validatePasswordMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get validatePasswordMatch;

  /// No description provided for @validateName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get validateName;

  /// No description provided for @roleBuyer.
  ///
  /// In en, this message translates to:
  /// **'Buyer'**
  String get roleBuyer;

  /// No description provided for @roleSupplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get roleSupplier;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @buyerHome.
  ///
  /// In en, this message translates to:
  /// **'Buyer home'**
  String get buyerHome;

  /// No description provided for @supplierHome.
  ///
  /// In en, this message translates to:
  /// **'Supplier home'**
  String get supplierHome;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name} 👋'**
  String greeting(String name);

  /// No description provided for @verificationPendingBanner.
  ///
  /// In en, this message translates to:
  /// **'Account pending verification — listing creation is locked until an admin verifies you.'**
  String get verificationPendingBanner;

  /// No description provided for @sectionListings.
  ///
  /// In en, this message translates to:
  /// **'Listings'**
  String get sectionListings;

  /// No description provided for @sectionOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get sectionOrders;

  /// No description provided for @browseListings.
  ///
  /// In en, this message translates to:
  /// **'Browse listings'**
  String get browseListings;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get myOrders;

  /// No description provided for @myListings.
  ///
  /// In en, this message translates to:
  /// **'My listings'**
  String get myListings;

  /// No description provided for @incomingOrders.
  ///
  /// In en, this message translates to:
  /// **'Incoming orders'**
  String get incomingOrders;

  /// No description provided for @newListing.
  ///
  /// In en, this message translates to:
  /// **'New listing'**
  String get newListing;

  /// No description provided for @statTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get statTotal;

  /// No description provided for @statActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statActive;

  /// No description provided for @statSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get statSoldOut;

  /// No description provided for @statInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get statInactive;

  /// No description provided for @statPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statPending;

  /// No description provided for @statInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statInProgress;

  /// No description provided for @statDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statDelivered;

  /// No description provided for @statCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statCancelled;

  /// No description provided for @listingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Listings'**
  String get listingsTitle;

  /// No description provided for @noListingsMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No listings match these filters'**
  String get noListingsMatchFilters;

  /// No description provided for @searchListingsHint.
  ///
  /// In en, this message translates to:
  /// **'Search title or description'**
  String get searchListingsHint;

  /// No description provided for @kgAvailableSuffix.
  ///
  /// In en, this message translates to:
  /// **'kg avail'**
  String get kgAvailableSuffix;

  /// No description provided for @perKgSuffix.
  ///
  /// In en, this message translates to:
  /// **'/ kg'**
  String get perKgSuffix;

  /// No description provided for @listingFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get listingFieldTitle;

  /// No description provided for @listingFieldMeatType.
  ///
  /// In en, this message translates to:
  /// **'Meat type'**
  String get listingFieldMeatType;

  /// No description provided for @listingFieldStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get listingFieldStatus;

  /// No description provided for @listingFieldPricePerKg.
  ///
  /// In en, this message translates to:
  /// **'Price / kg'**
  String get listingFieldPricePerKg;

  /// No description provided for @listingFieldQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity (kg)'**
  String get listingFieldQuantity;

  /// No description provided for @listingFieldAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get listingFieldAvailable;

  /// No description provided for @listingFieldLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get listingFieldLocation;

  /// No description provided for @listingFieldAvailableFrom.
  ///
  /// In en, this message translates to:
  /// **'Available from'**
  String get listingFieldAvailableFrom;

  /// No description provided for @listingFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get listingFieldDescription;

  /// No description provided for @listingFieldDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get listingFieldDescriptionOptional;

  /// No description provided for @listingPickAvailableFrom.
  ///
  /// In en, this message translates to:
  /// **'Pick an available-from date'**
  String get listingPickAvailableFrom;

  /// No description provided for @listingMinTitleChars.
  ///
  /// In en, this message translates to:
  /// **'Min 3 chars'**
  String get listingMinTitleChars;

  /// No description provided for @validateGtZero.
  ///
  /// In en, this message translates to:
  /// **'> 0 required'**
  String get validateGtZero;

  /// No description provided for @validateRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get validateRequired;

  /// No description provided for @createListingButton.
  ///
  /// In en, this message translates to:
  /// **'Create listing'**
  String get createListingButton;

  /// No description provided for @listingDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Listing'**
  String get listingDetailTitle;

  /// No description provided for @listingActionPlaceOrder.
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get listingActionPlaceOrder;

  /// No description provided for @listingActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get listingActionEdit;

  /// No description provided for @listingActionDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get listingActionDeactivate;

  /// No description provided for @listingActionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get listingActionSave;

  /// No description provided for @listingStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get listingStatusActive;

  /// No description provided for @listingStatusSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get listingStatusSoldOut;

  /// No description provided for @listingStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get listingStatusInactive;

  /// No description provided for @meatBeef.
  ///
  /// In en, this message translates to:
  /// **'Beef'**
  String get meatBeef;

  /// No description provided for @meatMutton.
  ///
  /// In en, this message translates to:
  /// **'Mutton'**
  String get meatMutton;

  /// No description provided for @meatChicken.
  ///
  /// In en, this message translates to:
  /// **'Chicken'**
  String get meatChicken;

  /// No description provided for @meatGoat.
  ///
  /// In en, this message translates to:
  /// **'Goat'**
  String get meatGoat;

  /// No description provided for @meatHorse.
  ///
  /// In en, this message translates to:
  /// **'Horse'**
  String get meatHorse;

  /// No description provided for @meatOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get meatOther;

  /// No description provided for @myOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get myOrdersTitle;

  /// No description provided for @incomingOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Incoming orders'**
  String get incomingOrdersTitle;

  /// No description provided for @noOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get noOrdersYet;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @orderDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String orderDetailTitle(int id);

  /// No description provided for @orderFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From: {email}'**
  String orderFromLabel(String email);

  /// No description provided for @orderToLabel.
  ///
  /// In en, this message translates to:
  /// **'To: {email}'**
  String orderToLabel(String email);

  /// No description provided for @orderFieldDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get orderFieldDeliveryAddress;

  /// No description provided for @orderFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get orderFieldNotes;

  /// No description provided for @orderFieldNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get orderFieldNotesOptional;

  /// No description provided for @orderPlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Place order — {title}'**
  String orderPlaceTitle(String title);

  /// No description provided for @orderAvailabilityHint.
  ///
  /// In en, this message translates to:
  /// **'Available: {qty} kg @ {price} / kg'**
  String orderAvailabilityHint(String qty, String price);

  /// No description provided for @orderQtyAddrRequired.
  ///
  /// In en, this message translates to:
  /// **'Quantity and delivery address are required'**
  String get orderQtyAddrRequired;

  /// No description provided for @orderOnlyKgAvailable.
  ///
  /// In en, this message translates to:
  /// **'Only {qty}kg available'**
  String orderOnlyKgAvailable(String qty);

  /// No description provided for @orderConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm order'**
  String get orderConfirmButton;

  /// No description provided for @orderPlacedSnack.
  ///
  /// In en, this message translates to:
  /// **'Order placed'**
  String get orderPlacedSnack;

  /// No description provided for @orderCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get orderCancelButton;

  /// No description provided for @orderCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel order?'**
  String get orderCancelTitle;

  /// No description provided for @orderCancelBody.
  ///
  /// In en, this message translates to:
  /// **'Stock will be restored on the listing. This cannot be undone.'**
  String get orderCancelBody;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @orderActionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get orderActionConfirm;

  /// No description provided for @orderActionStartProcessing.
  ///
  /// In en, this message translates to:
  /// **'Start processing'**
  String get orderActionStartProcessing;

  /// No description provided for @orderActionMarkInTransit.
  ///
  /// In en, this message translates to:
  /// **'Mark in transit'**
  String get orderActionMarkInTransit;

  /// No description provided for @orderActionMarkDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark delivered'**
  String get orderActionMarkDelivered;

  /// No description provided for @orderActionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get orderActionCancel;

  /// No description provided for @orderTerminalNoActions.
  ///
  /// In en, this message translates to:
  /// **'No further actions — order is {status}'**
  String orderTerminalNoActions(String status);

  /// No description provided for @orderStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get orderStatusPending;

  /// No description provided for @orderStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get orderStatusConfirmed;

  /// No description provided for @orderStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get orderStatusProcessing;

  /// No description provided for @orderStatusInTransit.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get orderStatusInTransit;

  /// No description provided for @orderStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get orderStatusDelivered;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get orderStatusCancelled;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @buyerProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Buyer profile'**
  String get buyerProfileTitle;

  /// No description provided for @supplierProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Supplier profile'**
  String get supplierProfileTitle;

  /// No description provided for @profileFieldBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get profileFieldBusinessName;

  /// No description provided for @profileFieldRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get profileFieldRegion;

  /// No description provided for @profileFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get profileFieldAddress;

  /// No description provided for @profileVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get profileVerified;

  /// No description provided for @profileUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get profileUnverified;

  /// No description provided for @profileSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get profileSavedSnack;

  /// No description provided for @profileAdminViaDjango.
  ///
  /// In en, this message translates to:
  /// **'Admin profile editing is via Django Admin'**
  String get profileAdminViaDjango;

  /// No description provided for @failedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String failedPrefix(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
