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

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get tabSearch;

  /// No description provided for @tabNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get tabNotifications;

  /// No description provided for @tabChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get tabChats;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @chatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsTitle;

  /// No description provided for @chatsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Chat coming in Milestone C'**
  String get chatsComingSoon;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes your profile, listings, and order history. This cannot be undone.'**
  String get deleteAccountConfirmBody;

  /// No description provided for @deleteAccountConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, delete'**
  String get deleteAccountConfirmYes;

  /// No description provided for @becomeSeller.
  ///
  /// In en, this message translates to:
  /// **'Become a seller'**
  String get becomeSeller;

  /// No description provided for @halal.
  ///
  /// In en, this message translates to:
  /// **'Halal'**
  String get halal;

  /// No description provided for @freshnessDate.
  ///
  /// In en, this message translates to:
  /// **'Freshness date'**
  String get freshnessDate;

  /// No description provided for @coldChainFresh.
  ///
  /// In en, this message translates to:
  /// **'Fresh'**
  String get coldChainFresh;

  /// No description provided for @coldChainChilled.
  ///
  /// In en, this message translates to:
  /// **'Chilled'**
  String get coldChainChilled;

  /// No description provided for @coldChainFrozen.
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get coldChainFrozen;

  /// No description provided for @serviceArea.
  ///
  /// In en, this message translates to:
  /// **'Service area'**
  String get serviceArea;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removePhoto;

  /// No description provided for @photoRequired.
  ///
  /// In en, this message translates to:
  /// **'At least one photo required'**
  String get photoRequired;

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

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @sectionFarmers.
  ///
  /// In en, this message translates to:
  /// **'Farmers'**
  String get sectionFarmers;

  /// No description provided for @sectionButchers.
  ///
  /// In en, this message translates to:
  /// **'Butchers'**
  String get sectionButchers;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguage;

  /// No description provided for @appVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'App version {version}'**
  String appVersionLabel(String version);

  /// No description provided for @privacyPolicyLink.
  ///
  /// In en, this message translates to:
  /// **'privacy policy'**
  String get privacyPolicyLink;

  /// No description provided for @termsOfUseLink.
  ///
  /// In en, this message translates to:
  /// **'terms of use'**
  String get termsOfUseLink;

  /// Template — UI splits on {policy}/{terms} placeholders to render them as underlined links
  ///
  /// In en, this message translates to:
  /// **'By tapping, I accept the {policy} & {terms}.'**
  String privacyTagline(String policy, String terms);

  /// No description provided for @anonWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Meat Marketplace'**
  String get anonWelcomeTitle;

  /// No description provided for @anonWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse listings — you\'ll register when placing an order.'**
  String get anonWelcomeSubtitle;

  /// No description provided for @onbLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Your area'**
  String get onbLocationTitle;

  /// No description provided for @onbLocationBody.
  ///
  /// In en, this message translates to:
  /// **'We use your location to show nearby meat sellers. This is optional — you can change it later in Profile.'**
  String get onbLocationBody;

  /// No description provided for @onbDetectLocation.
  ///
  /// In en, this message translates to:
  /// **'Detect location'**
  String get onbDetectLocation;

  /// No description provided for @onbNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get onbNotNow;

  /// No description provided for @pickLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get pickLanguageTitle;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @savedListingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorite listings'**
  String get savedListingsTitle;

  /// No description provided for @noSavedListingsYet.
  ///
  /// In en, this message translates to:
  /// **'No saved listings yet'**
  String get noSavedListingsYet;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get messageHint;

  /// No description provided for @noConversationsYet.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversationsYet;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// No description provided for @leaveReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave a review'**
  String get leaveReviewTitle;

  /// No description provided for @reviewCommentOptional.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get reviewCommentOptional;

  /// No description provided for @serviceAreaHint.
  ///
  /// In en, this message translates to:
  /// **'Tashkent, Samarkand, ...'**
  String get serviceAreaHint;

  /// No description provided for @tabMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get tabMenu;

  /// No description provided for @tabCart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get tabCart;

  /// No description provided for @tabOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get tabOrders;

  /// No description provided for @tabServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get tabServices;

  /// No description provided for @servicesQassobs.
  ///
  /// In en, this message translates to:
  /// **'Butchers'**
  String get servicesQassobs;

  /// No description provided for @servicesSlaughterhouses.
  ///
  /// In en, this message translates to:
  /// **'Slaughterhouses'**
  String get servicesSlaughterhouses;

  /// No description provided for @servicesFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get servicesFilterAll;

  /// No description provided for @servicesContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get servicesContact;

  /// No description provided for @servicesProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get servicesProfile;

  /// No description provided for @servicesNoneFound.
  ///
  /// In en, this message translates to:
  /// **'None found yet'**
  String get servicesNoneFound;

  /// No description provided for @servicesYearsExp.
  ///
  /// In en, this message translates to:
  /// **'{n} yrs exp'**
  String servicesYearsExp(int n);

  /// No description provided for @cartTitle.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cartTitle;

  /// No description provided for @cartItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 items} =1{1 item} other{{count} items}}'**
  String cartItemsCount(int count);

  /// No description provided for @cartEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmptyTitle;

  /// No description provided for @cartEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap any product on the Menu to add it here.'**
  String get cartEmptyHint;

  /// No description provided for @cartGoToMenu.
  ///
  /// In en, this message translates to:
  /// **'Go to menu'**
  String get cartGoToMenu;

  /// No description provided for @cartShopNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note to the shop'**
  String get cartShopNoteLabel;

  /// No description provided for @cartShopNoteHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. cut into 1 kg pieces, no bones, deliver in the evening'**
  String get cartShopNoteHint;

  /// No description provided for @cartSubTotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get cartSubTotal;

  /// No description provided for @cartTotal.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get cartTotal;

  /// No description provided for @cartCheckout.
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get cartCheckout;

  /// No description provided for @cartCheckoutSnack.
  ///
  /// In en, this message translates to:
  /// **'Order placed — backend wiring coming soon.'**
  String get cartCheckoutSnack;

  /// No description provided for @soumSuffix.
  ///
  /// In en, this message translates to:
  /// **'so\'m'**
  String get soumSuffix;

  /// No description provided for @perKgShort.
  ///
  /// In en, this message translates to:
  /// **'/kg'**
  String get perKgShort;

  /// No description provided for @cartAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get cartAdd;

  /// No description provided for @cartPeekTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cart'**
  String get cartPeekTitle;

  /// No description provided for @cartPeekChip.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get cartPeekChip;

  /// No description provided for @cartPeekViewAll.
  ///
  /// In en, this message translates to:
  /// **'Add more'**
  String get cartPeekViewAll;

  /// No description provided for @cartItemsShort.
  ///
  /// In en, this message translates to:
  /// **'{count} pcs'**
  String cartItemsShort(int count);

  /// No description provided for @cartFloatingPeek.
  ///
  /// In en, this message translates to:
  /// **'Tap to peek'**
  String get cartFloatingPeek;

  /// No description provided for @menuTitle.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuTitle;

  /// No description provided for @menuPickHint.
  ///
  /// In en, this message translates to:
  /// **'Pick what you\'ll cook today'**
  String get menuPickHint;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get homeSearchHint;

  /// No description provided for @homeRegionPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose region'**
  String get homeRegionPickerTitle;

  /// No description provided for @homeRegionAll.
  ///
  /// In en, this message translates to:
  /// **'All regions'**
  String get homeRegionAll;

  /// No description provided for @addressesTitle.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get addressesTitle;

  /// No description provided for @addressesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved addresses yet.'**
  String get addressesEmpty;

  /// No description provided for @addressesNewCta.
  ///
  /// In en, this message translates to:
  /// **'New address'**
  String get addressesNewCta;

  /// No description provided for @addressesSignInCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save addresses'**
  String get addressesSignInCta;

  /// No description provided for @addressFormTitleNew.
  ///
  /// In en, this message translates to:
  /// **'New address'**
  String get addressFormTitleNew;

  /// No description provided for @addressFormTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Address details'**
  String get addressFormTitleEdit;

  /// No description provided for @addressFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Address label'**
  String get addressFieldLabel;

  /// No description provided for @addressFieldLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Home, Office, Restaurant...'**
  String get addressFieldLabelHint;

  /// No description provided for @addressFieldStreet.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressFieldStreet;

  /// No description provided for @addressFieldStreetHint.
  ///
  /// In en, this message translates to:
  /// **'Street, neighbourhood, house number'**
  String get addressFieldStreetHint;

  /// No description provided for @addressFieldEntrance.
  ///
  /// In en, this message translates to:
  /// **'Entrance'**
  String get addressFieldEntrance;

  /// No description provided for @addressFieldFloor.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get addressFieldFloor;

  /// No description provided for @addressFieldApartment.
  ///
  /// In en, this message translates to:
  /// **'Apartment'**
  String get addressFieldApartment;

  /// No description provided for @addressFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Delivery instructions'**
  String get addressFieldNotes;

  /// No description provided for @addressFieldNotesHelp.
  ///
  /// In en, this message translates to:
  /// **'Helps the courier find you faster'**
  String get addressFieldNotesHelp;

  /// No description provided for @addressFieldDefault.
  ///
  /// In en, this message translates to:
  /// **'Make this my default address'**
  String get addressFieldDefault;

  /// No description provided for @addressSaveCta.
  ///
  /// In en, this message translates to:
  /// **'Save address'**
  String get addressSaveCta;

  /// No description provided for @addressDeleteCta.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get addressDeleteCta;

  /// No description provided for @addressDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this address?'**
  String get addressDeleteConfirm;

  /// No description provided for @addressMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick your address on the map'**
  String get addressMapTitle;

  /// No description provided for @addressMapConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Everything correct?'**
  String get addressMapConfirmTitle;

  /// No description provided for @addressMapConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Make sure the marker is at the entrance and confirm'**
  String get addressMapConfirmBody;

  /// No description provided for @addressMapConfirmCta.
  ///
  /// In en, this message translates to:
  /// **'Refine house number'**
  String get addressMapConfirmCta;

  /// No description provided for @addressMapMyLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get addressMapMyLocation;

  /// No description provided for @phoneAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'Your phone number'**
  String get phoneAuthTitle;

  /// No description provided for @phoneAuthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your number to sign in or sign up'**
  String get phoneAuthSubtitle;

  /// No description provided for @phoneAuthHint.
  ///
  /// In en, this message translates to:
  /// **'90 123-45-67'**
  String get phoneAuthHint;

  /// No description provided for @phoneAuthContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get phoneAuthContinue;

  /// No description provided for @phoneAuthInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a 9-digit phone number'**
  String get phoneAuthInvalid;

  /// No description provided for @phoneDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get phoneDetailsTitle;

  /// No description provided for @phoneDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We need your name for orders'**
  String get phoneDetailsSubtitle;

  /// No description provided for @phoneDetailsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get phoneDetailsNameLabel;

  /// No description provided for @phoneDetailsBusinessLabel.
  ///
  /// In en, this message translates to:
  /// **'Business name (optional)'**
  String get phoneDetailsBusinessLabel;

  /// No description provided for @phoneDetailsCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get phoneDetailsCta;

  /// No description provided for @profileSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile settings'**
  String get profileSettingsTitle;

  /// No description provided for @profileTapToEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileTapToEdit;

  /// No description provided for @profileFieldLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get profileFieldLastName;

  /// No description provided for @profileFieldFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get profileFieldFirstName;

  /// No description provided for @profileFieldPatronymic.
  ///
  /// In en, this message translates to:
  /// **'Patronymic'**
  String get profileFieldPatronymic;

  /// No description provided for @profileFieldPatronymicHint.
  ///
  /// In en, this message translates to:
  /// **'Enter patronymic'**
  String get profileFieldPatronymicHint;

  /// No description provided for @profileFieldDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get profileFieldDateOfBirth;

  /// No description provided for @profileFieldDateOfBirthHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get profileFieldDateOfBirthHint;

  /// No description provided for @profileFieldGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get profileFieldGender;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @profileFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get profileFieldPhone;

  /// No description provided for @profileMyCards.
  ///
  /// In en, this message translates to:
  /// **'My cards'**
  String get profileMyCards;

  /// No description provided for @profileCardsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No cards yet'**
  String get profileCardsEmpty;

  /// No description provided for @profileContactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get profileContactUs;

  /// No description provided for @profileTelegramOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open Telegram'**
  String get profileTelegramOpenFailed;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @adminEnterCta.
  ///
  /// In en, this message translates to:
  /// **'Enter as admin'**
  String get adminEnterCta;

  /// No description provided for @adminEnterPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin password'**
  String get adminEnterPasswordTitle;

  /// No description provided for @adminEnterPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get adminEnterPasswordHint;

  /// No description provided for @adminEnterPasswordWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get adminEnterPasswordWrong;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminTitle;

  /// No description provided for @adminTabNewListing.
  ///
  /// In en, this message translates to:
  /// **'New listing'**
  String get adminTabNewListing;

  /// No description provided for @adminTabManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get adminTabManage;

  /// No description provided for @adminNewListingPickSupplier.
  ///
  /// In en, this message translates to:
  /// **'Pick a supplier'**
  String get adminNewListingPickSupplier;

  /// No description provided for @adminNewListingSubmit.
  ///
  /// In en, this message translates to:
  /// **'Save listing'**
  String get adminNewListingSubmit;

  /// No description provided for @adminManageListings.
  ///
  /// In en, this message translates to:
  /// **'Listings'**
  String get adminManageListings;

  /// No description provided for @adminManageSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get adminManageSuppliers;

  /// No description provided for @adminManageCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get adminManageCategories;

  /// No description provided for @adminManageMarkets.
  ///
  /// In en, this message translates to:
  /// **'Markets'**
  String get adminManageMarkets;

  /// No description provided for @adminManageHint.
  ///
  /// In en, this message translates to:
  /// **'Create/edit items in the selected section'**
  String get adminManageHint;

  /// No description provided for @adminComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get adminComingSoon;

  /// No description provided for @adminListingCreated.
  ///
  /// In en, this message translates to:
  /// **'Listing created'**
  String get adminListingCreated;

  /// No description provided for @adminPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Admin permissions required — sign in with an admin account'**
  String get adminPermissionDenied;

  /// No description provided for @adminNewListingPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get adminNewListingPhotos;

  /// No description provided for @adminPickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from gallery'**
  String get adminPickFromGallery;

  /// No description provided for @adminPickFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get adminPickFromCamera;

  /// No description provided for @adminMarketDetailListings.
  ///
  /// In en, this message translates to:
  /// **'Listings at this market'**
  String get adminMarketDetailListings;

  /// No description provided for @adminMarketEditCta.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get adminMarketEditCta;

  /// No description provided for @adminMarketDeleteCta.
  ///
  /// In en, this message translates to:
  /// **'Delete market'**
  String get adminMarketDeleteCta;

  /// No description provided for @adminMarketPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get adminMarketPhoneLabel;

  /// No description provided for @adminMarketEmpty.
  ///
  /// In en, this message translates to:
  /// **'No listings yet'**
  String get adminMarketEmpty;

  /// No description provided for @adminListingEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit listing'**
  String get adminListingEditTitle;

  /// No description provided for @adminListingSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get adminListingSavedToast;

  /// No description provided for @adminListingDeleteCta.
  ///
  /// In en, this message translates to:
  /// **'Delete listing'**
  String get adminListingDeleteCta;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get statusSoldOut;

  /// No description provided for @statusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get statusInactive;

  /// No description provided for @addressAutoDetectedHint.
  ///
  /// In en, this message translates to:
  /// **'Detected location · tap to refine'**
  String get addressAutoDetectedHint;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get otpTitle;

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'Code sent to {phone}'**
  String otpSentTo(String phone);

  /// No description provided for @otpResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get otpResend;

  /// No description provided for @otpResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String otpResendIn(int seconds);

  /// No description provided for @otpInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code'**
  String get otpInvalidCode;

  /// No description provided for @otpExpired.
  ///
  /// In en, this message translates to:
  /// **'Code expired — request a new one'**
  String get otpExpired;

  /// No description provided for @qtyEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Quantity (kg)'**
  String get qtyEditorTitle;

  /// No description provided for @qtyEditorEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get qtyEditorEnterAmount;

  /// No description provided for @qtyEditorOnlyDigits.
  ///
  /// In en, this message translates to:
  /// **'Digits only'**
  String get qtyEditorOnlyDigits;

  /// No description provided for @qtyEditorMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Must be greater than zero'**
  String get qtyEditorMustBePositive;

  /// No description provided for @qtyEditorMaxExceeded.
  ///
  /// In en, this message translates to:
  /// **'Max: {max} kg'**
  String qtyEditorMaxExceeded(int max);

  /// No description provided for @qtyEditorAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available: {max} kg'**
  String qtyEditorAvailable(int max);

  /// No description provided for @qtyEditorMax.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get qtyEditorMax;

  /// No description provided for @qtyEditorConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get qtyEditorConfirm;

  /// No description provided for @payTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payTitle;

  /// No description provided for @payProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing payment…'**
  String get payProcessing;

  /// No description provided for @payCheckingStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking status…'**
  String get payCheckingStatus;

  /// No description provided for @paySuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment successful'**
  String get paySuccessTitle;

  /// No description provided for @paySuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your order has been accepted'**
  String get paySuccessBody;

  /// No description provided for @payFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get payFailedTitle;

  /// No description provided for @payRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get payRetry;

  /// No description provided for @payToOrders.
  ///
  /// In en, this message translates to:
  /// **'Go to orders'**
  String get payToOrders;

  /// No description provided for @payCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get payCancel;

  /// No description provided for @qtyEditorBelowMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum: {min}'**
  String qtyEditorBelowMinimum(int min);

  /// No description provided for @liveAnimalBadgeByHead.
  ///
  /// In en, this message translates to:
  /// **'1 HEAD'**
  String get liveAnimalBadgeByHead;

  /// No description provided for @liveAnimalBadgeByWeight.
  ///
  /// In en, this message translates to:
  /// **'LIVE WEIGHT'**
  String get liveAnimalBadgeByWeight;

  /// No description provided for @deliveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deliveryTitle;

  /// No description provided for @deliveryAddressSection.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get deliveryAddressSection;

  /// No description provided for @deliveryAddressChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get deliveryAddressChange;

  /// No description provided for @deliveryDistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance: {km} km'**
  String deliveryDistanceLabel(String km);

  /// No description provided for @deliveryVehicleSection.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get deliveryVehicleSection;

  /// No description provided for @deliveryVehicleRefrigerator.
  ///
  /// In en, this message translates to:
  /// **'Refrigerator'**
  String get deliveryVehicleRefrigerator;

  /// No description provided for @deliveryVehicleRefrigeratorHint.
  ///
  /// In en, this message translates to:
  /// **'Cold chain • 0°C to +4°C'**
  String get deliveryVehicleRefrigeratorHint;

  /// No description provided for @deliveryVehicleChorvaTaxi.
  ///
  /// In en, this message translates to:
  /// **'Chorva-Taxi'**
  String get deliveryVehicleChorvaTaxi;

  /// No description provided for @deliveryVehicleChorvaTaxiHint.
  ///
  /// In en, this message translates to:
  /// **'Special transport for live animals'**
  String get deliveryVehicleChorvaTaxiHint;

  /// No description provided for @deliveryVehicleUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get deliveryVehicleUnavailable;

  /// No description provided for @deliveryTimeSlotSection.
  ///
  /// In en, this message translates to:
  /// **'Time slot'**
  String get deliveryTimeSlotSection;

  /// No description provided for @deliveryTimeSlot0609.
  ///
  /// In en, this message translates to:
  /// **'06:00 – 09:00'**
  String get deliveryTimeSlot0609;

  /// No description provided for @deliveryTimeSlot0913.
  ///
  /// In en, this message translates to:
  /// **'09:00 – 13:00'**
  String get deliveryTimeSlot0913;

  /// No description provided for @deliveryTimeSlot1318.
  ///
  /// In en, this message translates to:
  /// **'13:00 – 18:00'**
  String get deliveryTimeSlot1318;

  /// No description provided for @deliveryButcherSection.
  ///
  /// In en, this message translates to:
  /// **'Butcher service'**
  String get deliveryButcherSection;

  /// No description provided for @deliveryButcherTitle.
  ///
  /// In en, this message translates to:
  /// **'Need slaughter and butchering for the live animal?'**
  String get deliveryButcherTitle;

  /// No description provided for @deliveryButcherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Professional butcher service: slaughter, cleaning and packaging.'**
  String get deliveryButcherSubtitle;

  /// No description provided for @deliveryButcherFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Service fee: {fee}'**
  String deliveryButcherFeeLabel(String fee);

  /// No description provided for @deliveryButcherAccept.
  ///
  /// In en, this message translates to:
  /// **'Add butcher service'**
  String get deliveryButcherAccept;

  /// No description provided for @deliveryBreakdownSection.
  ///
  /// In en, this message translates to:
  /// **'Breakdown'**
  String get deliveryBreakdownSection;

  /// No description provided for @deliveryBreakdownProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get deliveryBreakdownProducts;

  /// No description provided for @deliveryBreakdownDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deliveryBreakdownDelivery;

  /// No description provided for @deliveryBreakdownButcher.
  ///
  /// In en, this message translates to:
  /// **'Butcher service'**
  String get deliveryBreakdownButcher;

  /// No description provided for @deliveryBreakdownTotal.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get deliveryBreakdownTotal;

  /// No description provided for @deliveryProceedCta.
  ///
  /// In en, this message translates to:
  /// **'Proceed to payment'**
  String get deliveryProceedCta;

  /// No description provided for @deliveryNeedAddress.
  ///
  /// In en, this message translates to:
  /// **'Please set an address first'**
  String get deliveryNeedAddress;

  /// No description provided for @deliveryLoadingQuote.
  ///
  /// In en, this message translates to:
  /// **'Loading quote…'**
  String get deliveryLoadingQuote;

  /// No description provided for @deliveryQuoteError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the quote. Try again.'**
  String get deliveryQuoteError;

  /// No description provided for @deliveryPickMapHint.
  ///
  /// In en, this message translates to:
  /// **'Pick the address on the map'**
  String get deliveryPickMapHint;

  /// No description provided for @deliveryFloorMin.
  ///
  /// In en, this message translates to:
  /// **'Minimum order is 10 kg (wholesale).'**
  String get deliveryFloorMin;

  /// No description provided for @deliveryTashkentOnlyBanner.
  ///
  /// In en, this message translates to:
  /// **'We currently deliver only within Tashkent city. The quote is calculated from the city centre.'**
  String get deliveryTashkentOnlyBanner;

  /// No description provided for @deliveryTashkentOnlyShort.
  ///
  /// In en, this message translates to:
  /// **'Tashkent only for now'**
  String get deliveryTashkentOnlyShort;

  /// No description provided for @testUseYunusobod.
  ///
  /// In en, this message translates to:
  /// **'TEST: use Yunusobod (Tashkent) location'**
  String get testUseYunusobod;

  /// No description provided for @testYunusobodApplied.
  ///
  /// In en, this message translates to:
  /// **'Location set to Yunusobod'**
  String get testYunusobodApplied;

  /// No description provided for @cardsTitle.
  ///
  /// In en, this message translates to:
  /// **'My cards'**
  String get cardsTitle;

  /// No description provided for @cardsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add card'**
  String get cardsAddTitle;

  /// No description provided for @cardsAddCta.
  ///
  /// In en, this message translates to:
  /// **'Add card'**
  String get cardsAddCta;

  /// No description provided for @cardsAddError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the card. Try again.'**
  String get cardsAddError;

  /// No description provided for @cardsPan.
  ///
  /// In en, this message translates to:
  /// **'Card number'**
  String get cardsPan;

  /// No description provided for @cardsExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get cardsExpiry;

  /// No description provided for @cardsHolder.
  ///
  /// In en, this message translates to:
  /// **'Cardholder name'**
  String get cardsHolder;

  /// No description provided for @cardsPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone for SMS'**
  String get cardsPhone;

  /// No description provided for @cardsMakeDefault.
  ///
  /// In en, this message translates to:
  /// **'Make this the default card'**
  String get cardsMakeDefault;

  /// No description provided for @cardsPciNote.
  ///
  /// In en, this message translates to:
  /// **'Card data is sent over an encrypted channel. We never store the full card number.'**
  String get cardsPciNote;

  /// No description provided for @cardsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No cards yet'**
  String get cardsEmptyTitle;

  /// No description provided for @cardsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add a card to pay for your orders.'**
  String get cardsEmptyHint;

  /// No description provided for @cardsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load cards.'**
  String get cardsLoadError;

  /// No description provided for @cardsDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT'**
  String get cardsDefaultBadge;

  /// No description provided for @cardsExpiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Card expired'**
  String get cardsExpiredLabel;

  /// No description provided for @cardsActionMakeDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get cardsActionMakeDefault;

  /// No description provided for @cardsActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get cardsActionDelete;

  /// No description provided for @cardsDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Card deleted'**
  String get cardsDeletedSnack;

  /// No description provided for @paymentAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount to pay'**
  String get paymentAmountLabel;

  /// No description provided for @paymentMethodSection.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethodSection;

  /// No description provided for @paymentPayCta.
  ///
  /// In en, this message translates to:
  /// **'Pay · {amount}'**
  String paymentPayCta(String amount);

  /// No description provided for @paymentPayCtaShort.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get paymentPayCtaShort;

  /// No description provided for @paymentSuccessCardLine.
  ///
  /// In en, this message translates to:
  /// **'Paid with {brand} •••• {last4}'**
  String paymentSuccessCardLine(String brand, String last4);

  /// No description provided for @authServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Server is temporarily unavailable. Please try again in a moment.'**
  String get authServerUnavailable;

  /// No description provided for @authNetworkError.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your connection and try again.'**
  String get authNetworkError;

  /// No description provided for @authNetworkTimeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get authNetworkTimeout;

  /// No description provided for @authUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again later.'**
  String get authUnexpectedError;
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
