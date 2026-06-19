// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Go\'sht Bozori Partners';

  @override
  String get languagePickerTitle => 'Choose your language';

  @override
  String get languageUz => 'O\'zbekcha';

  @override
  String get languageRu => 'Русский';

  @override
  String get languageEn => 'English';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get skip => 'Skip';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get loading => 'Loading…';

  @override
  String get tryAgain => 'Try again';

  @override
  String get rolePickerTitle => 'What are you signing up as?';

  @override
  String get rolePickerSubtitle => 'You can\'t change this later';

  @override
  String get roleQassobTitle => 'I am a butcher';

  @override
  String get roleQassobBody => 'Slaughter and cut live animals';

  @override
  String get roleSupplierTitle => 'I sell meat';

  @override
  String get roleSupplierBody => 'Ready meat or live animals';

  @override
  String get phoneEntryTitle => 'Your phone number';

  @override
  String get phoneEntryHint => '+998 90 123 45 67';

  @override
  String get phoneEntrySendCode => 'Send code';

  @override
  String get phoneEntryError => 'Please enter a valid phone number';

  @override
  String get otpTitle => 'Verification code';

  @override
  String otpSubtitle(String phone) {
    return 'Code sent to $phone';
  }

  @override
  String otpResend(int sec) {
    return 'Resend (${sec}s)';
  }

  @override
  String get otpInvalid => 'Code is invalid or expired';

  @override
  String get onboardingWelcomeQassob => 'Welcome! Quick sign-up';

  @override
  String get onboardingWelcomeSupplier => 'Welcome!';

  @override
  String get onboardingExperience => 'How many years of experience?';

  @override
  String get onboardingYourName => 'Your name';

  @override
  String get onboardingAboutYouTitle => 'About you and your business';

  @override
  String get onboardingFullName => 'Full name';

  @override
  String get onboardingCompanyName => 'Company / service name (optional)';

  @override
  String get onboardingAnimalsTitleQassob => 'Which animals can you cut?';

  @override
  String get onboardingAnimalsTitleSupplier => 'Which animals do you sell?';

  @override
  String get onboardingAnimalsHint => 'Choose one or more';

  @override
  String get onboardingFormsTitle => 'Choose the form for each';

  @override
  String get onboardingFormsHint =>
      'Live — weddings, sacrifice. Ready cut — restaurants, wholesale';

  @override
  String get onboardingCapacity => 'How many heads per day?';

  @override
  String get onboardingSlaughterhouse => 'Do you have a slaughterhouse?';

  @override
  String get onboardingLocation => 'Set your location';

  @override
  String get onboardingLocationDetect => 'Auto-detect';

  @override
  String get onboardingLocationChange => 'Choose another location';

  @override
  String get onboardingSelfDelivery => 'Do you deliver yourself?';

  @override
  String get onboardingVehicleType => 'What vehicle?';

  @override
  String get onboardingVehiclePlate => 'License plate';

  @override
  String get onboardingPhoto => 'Workplace photo (optional)';

  @override
  String get onboardingPhotoSupplier => 'Business photo (optional)';

  @override
  String get onboardingTakePhoto => 'Take photo';

  @override
  String get onboardingSubmit => 'Confirm';

  @override
  String get onboardingSubmitting => 'Submitting…';

  @override
  String get onboardingSubmitFailed =>
      'Submission failed. Check your connection and try again.';

  @override
  String get animalMol => 'Beef';

  @override
  String get animalQoy => 'Sheep';

  @override
  String get animalEchki => 'Goat';

  @override
  String get animalOt => 'Horse';

  @override
  String get animalTovuq => 'Chicken';

  @override
  String get vehicleRefrigerator => 'Refrigerator';

  @override
  String get vehicleChorvaTaxi => 'Chorva-Taxi';

  @override
  String get formLive => 'Live';

  @override
  String get formCut => 'Ready meat';

  @override
  String get tabHome => 'Home';

  @override
  String get tabOrders => 'Orders';

  @override
  String get tabJobs => 'Jobs';

  @override
  String get tabCatalog => 'Catalog';

  @override
  String get tabSchedule => 'Schedule';

  @override
  String get tabEarnings => 'Earnings';

  @override
  String get tabProfile => 'Profile';

  @override
  String dashboardGreeting(String name) {
    return 'Hello, $name!';
  }

  @override
  String get dashboardOpenNow => 'I\'m taking orders now';

  @override
  String get dashboardKpiTodayRevenue => 'Today\'s revenue';

  @override
  String get dashboardKpiOpenOrders => 'New orders';

  @override
  String get dashboardKpiLowStock => 'Low stock';

  @override
  String get dashboardKpiReviews => 'Reviews';

  @override
  String get dashboardSeeAll => 'See all';

  @override
  String get dashboardSmartTipsTitle => 'Upcoming holidays';

  @override
  String dashboardSmartTipDaysUntil(int n) {
    return '$n days left';
  }

  @override
  String get verificationBannerTitle => 'Documents under review';

  @override
  String get verificationBannerBody =>
      'Upload your documents — we\'ll verify within 24 hours';

  @override
  String get verificationBannerCta => 'Upload documents';

  @override
  String get ordersTabNew => 'New';

  @override
  String get ordersTabActive => 'Active';

  @override
  String get ordersTabDone => 'Done';

  @override
  String get ordersAccept => 'Accept';

  @override
  String get ordersReject => 'Reject';

  @override
  String get ordersAdvance => 'Next stage';

  @override
  String get ordersEmpty => 'No orders yet';

  @override
  String get jobsTabOffers => 'New offers';

  @override
  String get jobsTabToday => 'Today';

  @override
  String get jobsTabHistory => 'History';

  @override
  String get jobsClaim => 'Accept';

  @override
  String get jobsEmpty => 'No new offers';

  @override
  String get catalogTitle => 'My products';

  @override
  String get catalogAddNew => 'Add new product';

  @override
  String get catalogQuickPriceTitle => 'Change price';

  @override
  String catalogStock(String kg) {
    return 'Stock: $kg kg';
  }

  @override
  String get catalogEmpty => 'No products yet';

  @override
  String get scheduleTitle => 'Capacity schedule';

  @override
  String scheduleBooked(int booked, int cap) {
    return '$booked/$cap booked';
  }

  @override
  String get earningsTitle => 'Earnings';

  @override
  String get earningsPeriodDay => 'Day';

  @override
  String get earningsPeriodWeek => 'Week';

  @override
  String get earningsPeriodMonth => 'Month';

  @override
  String get earningsTotalLabel => 'Total';

  @override
  String get earningsOrdersLabel => 'Orders';

  @override
  String get earningsAvgTicketLabel => 'Average';

  @override
  String get earningsTopProductLabel => 'Top product';

  @override
  String get earningsExportPdf => 'Export PDF';

  @override
  String get earningsExportRange => 'Date range';

  @override
  String get earningsExportSent => 'Sent — check your email';

  @override
  String get profileSectionBusiness => 'Business info';

  @override
  String get profileSectionDocuments => 'Documents';

  @override
  String get profileSectionLoyalty => 'Loyal customers';

  @override
  String get profileSectionReviews => 'Reviews';

  @override
  String get profileSectionNotifications => 'Notifications';

  @override
  String get profileSectionLanguage => 'Language';

  @override
  String get profileSectionSupport => 'Contact via Telegram';

  @override
  String get profileSectionLogout => 'Log out';

  @override
  String get profileVerifiedBadge => 'Verified';

  @override
  String get profilePendingBadge => 'Under review';

  @override
  String get kycTitle => 'Documents';

  @override
  String get kycPassport => 'Passport';

  @override
  String get kycLicense => 'Business license';

  @override
  String get kycFacility => 'Workplace photo';

  @override
  String get kycRequiredNote => 'Passport and license are required';

  @override
  String get kycUpload => 'Upload';

  @override
  String get kycApproved => 'Approved';

  @override
  String get kycPending => 'Under review';

  @override
  String get kycReplace => 'Replace';

  @override
  String get ratingsTitle => 'Reviews';

  @override
  String get ratingsReplyHint => 'Write a reply…';

  @override
  String get ratingsReplyAction => 'Reply';

  @override
  String get ratingsEmpty => 'No reviews yet';

  @override
  String get loyaltyTitle => 'Loyal customers';

  @override
  String loyaltyOrdersCount(int n) {
    return '$n orders';
  }

  @override
  String get supportTelegramHandle => '@sarimov_s';
}
