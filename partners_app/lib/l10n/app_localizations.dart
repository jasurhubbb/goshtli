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
    Locale('uz')
  ];

  /// No description provided for @appTitle.
  ///
  /// In uz, this message translates to:
  /// **'Go\'sht Bozori Partners'**
  String get appTitle;

  /// No description provided for @languagePickerTitle.
  ///
  /// In uz, this message translates to:
  /// **'Til tanlang'**
  String get languagePickerTitle;

  /// No description provided for @languageUz.
  ///
  /// In uz, this message translates to:
  /// **'O\'zbekcha'**
  String get languageUz;

  /// No description provided for @languageRu.
  ///
  /// In uz, this message translates to:
  /// **'Русский'**
  String get languageRu;

  /// No description provided for @languageEn.
  ///
  /// In uz, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @next.
  ///
  /// In uz, this message translates to:
  /// **'Keyingisi'**
  String get next;

  /// No description provided for @back.
  ///
  /// In uz, this message translates to:
  /// **'Orqaga'**
  String get back;

  /// No description provided for @skip.
  ///
  /// In uz, this message translates to:
  /// **'O\'tkazib yuborish'**
  String get skip;

  /// No description provided for @confirm.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlash'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In uz, this message translates to:
  /// **'Saqlash'**
  String get save;

  /// No description provided for @yes.
  ///
  /// In uz, this message translates to:
  /// **'Ha'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'q'**
  String get no;

  /// No description provided for @loading.
  ///
  /// In uz, this message translates to:
  /// **'Yuklanmoqda…'**
  String get loading;

  /// No description provided for @tryAgain.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get tryAgain;

  /// No description provided for @rolePickerTitle.
  ///
  /// In uz, this message translates to:
  /// **'Kim sifatida ro\'yxatdan o\'tasiz?'**
  String get rolePickerTitle;

  /// No description provided for @rolePickerSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Keyinroq o\'zgartira olmaysiz'**
  String get rolePickerSubtitle;

  /// No description provided for @roleQassobTitle.
  ///
  /// In uz, this message translates to:
  /// **'Qassobman'**
  String get roleQassobTitle;

  /// No description provided for @roleQassobBody.
  ///
  /// In uz, this message translates to:
  /// **'Tirik chorvani so\'yish va bo\'laklash'**
  String get roleQassobBody;

  /// No description provided for @roleSupplierTitle.
  ///
  /// In uz, this message translates to:
  /// **'Go\'sht sotaman'**
  String get roleSupplierTitle;

  /// No description provided for @roleSupplierBody.
  ///
  /// In uz, this message translates to:
  /// **'Tayyor go\'sht yoki tirik chorva sotuvi'**
  String get roleSupplierBody;

  /// No description provided for @phoneEntryTitle.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqamingiz'**
  String get phoneEntryTitle;

  /// No description provided for @phoneEntryHint.
  ///
  /// In uz, this message translates to:
  /// **'+998 90 123 45 67'**
  String get phoneEntryHint;

  /// No description provided for @phoneEntrySendCode.
  ///
  /// In uz, this message translates to:
  /// **'Kod yuborish'**
  String get phoneEntrySendCode;

  /// No description provided for @phoneEntryError.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqamini to\'g\'ri kiriting'**
  String get phoneEntryError;

  /// No description provided for @otpTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlash kodi'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Kod {phone} raqamiga yuborildi'**
  String otpSubtitle(String phone);

  /// No description provided for @otpResend.
  ///
  /// In uz, this message translates to:
  /// **'Qayta yuborish ({sec}s)'**
  String otpResend(int sec);

  /// No description provided for @otpInvalid.
  ///
  /// In uz, this message translates to:
  /// **'Kod noto\'g\'ri yoki muddati o\'tgan'**
  String get otpInvalid;

  /// No description provided for @onboardingWelcomeQassob.
  ///
  /// In uz, this message translates to:
  /// **'Tabriklaymiz! Tezda ro\'yxatdan o\'tasiz'**
  String get onboardingWelcomeQassob;

  /// No description provided for @onboardingWelcomeSupplier.
  ///
  /// In uz, this message translates to:
  /// **'Tabriklaymiz!'**
  String get onboardingWelcomeSupplier;

  /// No description provided for @onboardingExperience.
  ///
  /// In uz, this message translates to:
  /// **'Tajribangiz necha yil?'**
  String get onboardingExperience;

  /// No description provided for @onboardingYourName.
  ///
  /// In uz, this message translates to:
  /// **'Ismingizni kiriting'**
  String get onboardingYourName;

  /// No description provided for @onboardingAboutYouTitle.
  ///
  /// In uz, this message translates to:
  /// **'O\'zingiz va servisingiz haqida'**
  String get onboardingAboutYouTitle;

  /// No description provided for @onboardingFullName.
  ///
  /// In uz, this message translates to:
  /// **'To\'liq ism'**
  String get onboardingFullName;

  /// No description provided for @onboardingCompanyName.
  ///
  /// In uz, this message translates to:
  /// **'Servis nomi (ixtiyoriy)'**
  String get onboardingCompanyName;

  /// No description provided for @onboardingAnimalsTitleQassob.
  ///
  /// In uz, this message translates to:
  /// **'Qaysi hayvonlarni so\'ya olasiz?'**
  String get onboardingAnimalsTitleQassob;

  /// No description provided for @onboardingAnimalsTitleSupplier.
  ///
  /// In uz, this message translates to:
  /// **'Qaysi hayvonlarni sotasiz?'**
  String get onboardingAnimalsTitleSupplier;

  /// No description provided for @onboardingAnimalsHint.
  ///
  /// In uz, this message translates to:
  /// **'Bir nechtasini tanlashingiz mumkin'**
  String get onboardingAnimalsHint;

  /// No description provided for @onboardingFormsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Har biri uchun shaklini tanlang'**
  String get onboardingFormsTitle;

  /// No description provided for @onboardingFormsHint.
  ///
  /// In uz, this message translates to:
  /// **'Tirik chorva — to\'y, qurbonlik. Tayyor go\'sht — restoran, ulgurji'**
  String get onboardingFormsHint;

  /// No description provided for @onboardingCapacity.
  ///
  /// In uz, this message translates to:
  /// **'Kuniga nechta bosh?'**
  String get onboardingCapacity;

  /// No description provided for @onboardingSlaughterhouse.
  ///
  /// In uz, this message translates to:
  /// **'Qushxonangiz bormi?'**
  String get onboardingSlaughterhouse;

  /// No description provided for @onboardingLocation.
  ///
  /// In uz, this message translates to:
  /// **'Joylashuvingizni belgilang'**
  String get onboardingLocation;

  /// No description provided for @onboardingLocationDetect.
  ///
  /// In uz, this message translates to:
  /// **'Avtomatik aniqlash'**
  String get onboardingLocationDetect;

  /// No description provided for @onboardingLocationChange.
  ///
  /// In uz, this message translates to:
  /// **'Boshqa joy tanlash'**
  String get onboardingLocationChange;

  /// No description provided for @onboardingSelfDelivery.
  ///
  /// In uz, this message translates to:
  /// **'O\'zingiz yetkazib bera olasizmi?'**
  String get onboardingSelfDelivery;

  /// No description provided for @onboardingVehicleType.
  ///
  /// In uz, this message translates to:
  /// **'Qaysi mashina turi?'**
  String get onboardingVehicleType;

  /// No description provided for @onboardingVehiclePlate.
  ///
  /// In uz, this message translates to:
  /// **'Davlat raqami'**
  String get onboardingVehiclePlate;

  /// No description provided for @onboardingPhoto.
  ///
  /// In uz, this message translates to:
  /// **'Ish joyi rasmi (ixtiyoriy)'**
  String get onboardingPhoto;

  /// No description provided for @onboardingPhotoSupplier.
  ///
  /// In uz, this message translates to:
  /// **'Biznes rasmi (ixtiyoriy)'**
  String get onboardingPhotoSupplier;

  /// No description provided for @onboardingTakePhoto.
  ///
  /// In uz, this message translates to:
  /// **'Rasm olish'**
  String get onboardingTakePhoto;

  /// No description provided for @onboardingSubmit.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlash'**
  String get onboardingSubmit;

  /// No description provided for @onboardingSubmitting.
  ///
  /// In uz, this message translates to:
  /// **'Yuborilmoqda…'**
  String get onboardingSubmitting;

  /// No description provided for @onboardingSubmitFailed.
  ///
  /// In uz, this message translates to:
  /// **'Yuborilmadi. Internetni tekshirib qayta urinib ko\'ring.'**
  String get onboardingSubmitFailed;

  /// No description provided for @animalMol.
  ///
  /// In uz, this message translates to:
  /// **'Mol'**
  String get animalMol;

  /// No description provided for @animalQoy.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'y'**
  String get animalQoy;

  /// No description provided for @animalEchki.
  ///
  /// In uz, this message translates to:
  /// **'Echki'**
  String get animalEchki;

  /// No description provided for @animalOt.
  ///
  /// In uz, this message translates to:
  /// **'Ot'**
  String get animalOt;

  /// No description provided for @animalTovuq.
  ///
  /// In uz, this message translates to:
  /// **'Tovuq'**
  String get animalTovuq;

  /// No description provided for @vehicleRefrigerator.
  ///
  /// In uz, this message translates to:
  /// **'Refrigerator'**
  String get vehicleRefrigerator;

  /// No description provided for @vehicleChorvaTaxi.
  ///
  /// In uz, this message translates to:
  /// **'Chorva-Taksi'**
  String get vehicleChorvaTaxi;

  /// No description provided for @formLive.
  ///
  /// In uz, this message translates to:
  /// **'Tirik'**
  String get formLive;

  /// No description provided for @formCut.
  ///
  /// In uz, this message translates to:
  /// **'Tayyor go\'sht'**
  String get formCut;

  /// No description provided for @tabHome.
  ///
  /// In uz, this message translates to:
  /// **'Bosh sahifa'**
  String get tabHome;

  /// No description provided for @tabOrders.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalar'**
  String get tabOrders;

  /// No description provided for @tabJobs.
  ///
  /// In uz, this message translates to:
  /// **'Ishlar'**
  String get tabJobs;

  /// No description provided for @tabCatalog.
  ///
  /// In uz, this message translates to:
  /// **'Katalog'**
  String get tabCatalog;

  /// No description provided for @tabSchedule.
  ///
  /// In uz, this message translates to:
  /// **'Jadval'**
  String get tabSchedule;

  /// No description provided for @tabEarnings.
  ///
  /// In uz, this message translates to:
  /// **'Daromad'**
  String get tabEarnings;

  /// No description provided for @tabProfile.
  ///
  /// In uz, this message translates to:
  /// **'Profil'**
  String get tabProfile;

  /// No description provided for @dashboardGreeting.
  ///
  /// In uz, this message translates to:
  /// **'Salom, {name}!'**
  String dashboardGreeting(String name);

  /// No description provided for @dashboardOpenNow.
  ///
  /// In uz, this message translates to:
  /// **'Hozir buyurtma qabul qilaman'**
  String get dashboardOpenNow;

  /// No description provided for @dashboardKpiTodayRevenue.
  ///
  /// In uz, this message translates to:
  /// **'Bugungi daromad'**
  String get dashboardKpiTodayRevenue;

  /// No description provided for @dashboardKpiOpenOrders.
  ///
  /// In uz, this message translates to:
  /// **'Yangi buyurtmalar'**
  String get dashboardKpiOpenOrders;

  /// No description provided for @dashboardKpiLowStock.
  ///
  /// In uz, this message translates to:
  /// **'Kam zaxira'**
  String get dashboardKpiLowStock;

  /// No description provided for @dashboardKpiReviews.
  ///
  /// In uz, this message translates to:
  /// **'Sharhlar'**
  String get dashboardKpiReviews;

  /// No description provided for @dashboardSeeAll.
  ///
  /// In uz, this message translates to:
  /// **'Hammasi'**
  String get dashboardSeeAll;

  /// No description provided for @dashboardSmartTipsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yaqinlashayotgan bayramlar'**
  String get dashboardSmartTipsTitle;

  /// No description provided for @dashboardSmartTipDaysUntil.
  ///
  /// In uz, this message translates to:
  /// **'{n} kun qoldi'**
  String dashboardSmartTipDaysUntil(int n);

  /// No description provided for @verificationBannerTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hujjatlar tekshirilmoqda'**
  String get verificationBannerTitle;

  /// No description provided for @verificationBannerBody.
  ///
  /// In uz, this message translates to:
  /// **'Administrator tomonidan tasdiqlanish kutilmoqda'**
  String get verificationBannerBody;

  /// No description provided for @verificationBannerCta.
  ///
  /// In uz, this message translates to:
  /// **'Hujjatlarni yuborish'**
  String get verificationBannerCta;

  /// No description provided for @ordersTabNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi'**
  String get ordersTabNew;

  /// No description provided for @ordersTabActive.
  ///
  /// In uz, this message translates to:
  /// **'Jarayonda'**
  String get ordersTabActive;

  /// No description provided for @ordersTabDone.
  ///
  /// In uz, this message translates to:
  /// **'Bajarilgan'**
  String get ordersTabDone;

  /// No description provided for @ordersAccept.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilish'**
  String get ordersAccept;

  /// No description provided for @ordersReject.
  ///
  /// In uz, this message translates to:
  /// **'Rad etish'**
  String get ordersReject;

  /// No description provided for @ordersAdvance.
  ///
  /// In uz, this message translates to:
  /// **'Keyingi bosqich'**
  String get ordersAdvance;

  /// No description provided for @ordersEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha buyurtma yo\'q'**
  String get ordersEmpty;

  /// No description provided for @jobsTabOffers.
  ///
  /// In uz, this message translates to:
  /// **'Yangi takliflar'**
  String get jobsTabOffers;

  /// No description provided for @jobsTabToday.
  ///
  /// In uz, this message translates to:
  /// **'Bugun'**
  String get jobsTabToday;

  /// No description provided for @jobsTabHistory.
  ///
  /// In uz, this message translates to:
  /// **'Tarix'**
  String get jobsTabHistory;

  /// No description provided for @jobsClaim.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilish'**
  String get jobsClaim;

  /// No description provided for @jobsEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Yangi takliflar yo\'q'**
  String get jobsEmpty;

  /// No description provided for @catalogTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mening tovarlarim'**
  String get catalogTitle;

  /// No description provided for @catalogAddNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi tovar qo\'shish'**
  String get catalogAddNew;

  /// No description provided for @catalogQuickPriceTitle.
  ///
  /// In uz, this message translates to:
  /// **'Narxni o\'zgartirish'**
  String get catalogQuickPriceTitle;

  /// No description provided for @catalogStock.
  ///
  /// In uz, this message translates to:
  /// **'Zaxira: {kg} kg'**
  String catalogStock(String kg);

  /// No description provided for @catalogEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hali tovar qo\'shilmagan'**
  String get catalogEmpty;

  /// No description provided for @scheduleTitle.
  ///
  /// In uz, this message translates to:
  /// **'Sig\'im jadvali'**
  String get scheduleTitle;

  /// No description provided for @scheduleBooked.
  ///
  /// In uz, this message translates to:
  /// **'{booked}/{cap} band'**
  String scheduleBooked(int booked, int cap);

  /// No description provided for @earningsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Daromad'**
  String get earningsTitle;

  /// No description provided for @earningsPeriodDay.
  ///
  /// In uz, this message translates to:
  /// **'Kun'**
  String get earningsPeriodDay;

  /// No description provided for @earningsPeriodWeek.
  ///
  /// In uz, this message translates to:
  /// **'Hafta'**
  String get earningsPeriodWeek;

  /// No description provided for @earningsPeriodMonth.
  ///
  /// In uz, this message translates to:
  /// **'Oy'**
  String get earningsPeriodMonth;

  /// No description provided for @earningsTotalLabel.
  ///
  /// In uz, this message translates to:
  /// **'Jami'**
  String get earningsTotalLabel;

  /// No description provided for @earningsOrdersLabel.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalar'**
  String get earningsOrdersLabel;

  /// No description provided for @earningsAvgTicketLabel.
  ///
  /// In uz, this message translates to:
  /// **'O\'rtacha'**
  String get earningsAvgTicketLabel;

  /// No description provided for @earningsTopProductLabel.
  ///
  /// In uz, this message translates to:
  /// **'Eng ko\'p sotilgan'**
  String get earningsTopProductLabel;

  /// No description provided for @earningsExportPdf.
  ///
  /// In uz, this message translates to:
  /// **'PDF eksport'**
  String get earningsExportPdf;

  /// No description provided for @earningsExportRange.
  ///
  /// In uz, this message translates to:
  /// **'Sana oralig\'i'**
  String get earningsExportRange;

  /// No description provided for @earningsExportSent.
  ///
  /// In uz, this message translates to:
  /// **'Yuborildi — emailingizni tekshiring'**
  String get earningsExportSent;

  /// No description provided for @profileSectionEdit.
  ///
  /// In uz, this message translates to:
  /// **'Profilni tahrirlash'**
  String get profileSectionEdit;

  /// No description provided for @profileSectionReviews.
  ///
  /// In uz, this message translates to:
  /// **'Sharhlar'**
  String get profileSectionReviews;

  /// No description provided for @profileSectionNotifications.
  ///
  /// In uz, this message translates to:
  /// **'Bildirishnomalar'**
  String get profileSectionNotifications;

  /// No description provided for @profileSectionLanguage.
  ///
  /// In uz, this message translates to:
  /// **'Til'**
  String get profileSectionLanguage;

  /// No description provided for @profileSectionSupport.
  ///
  /// In uz, this message translates to:
  /// **'Telegram orqali bog\'lanish'**
  String get profileSectionSupport;

  /// No description provided for @profileSectionLogout.
  ///
  /// In uz, this message translates to:
  /// **'Chiqish'**
  String get profileSectionLogout;

  /// No description provided for @profileVerifiedBadge.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlangan'**
  String get profileVerifiedBadge;

  /// No description provided for @profilePendingBadge.
  ///
  /// In uz, this message translates to:
  /// **'Tekshirilmoqda'**
  String get profilePendingBadge;

  /// No description provided for @profileEditTitle.
  ///
  /// In uz, this message translates to:
  /// **'Profilni tahrirlash'**
  String get profileEditTitle;

  /// No description provided for @profileEditFullName.
  ///
  /// In uz, this message translates to:
  /// **'To\'liq ism'**
  String get profileEditFullName;

  /// No description provided for @profileEditCallsAvailable.
  ///
  /// In uz, this message translates to:
  /// **'Telefon qo\'ng\'iroqlari uchun ochiqman'**
  String get profileEditCallsAvailable;

  /// No description provided for @profileEditCallsAvailableHint.
  ///
  /// In uz, this message translates to:
  /// **'Mijozlar telefon raqamingizni ko\'ra oladi'**
  String get profileEditCallsAvailableHint;

  /// No description provided for @kycTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hujjatlar'**
  String get kycTitle;

  /// No description provided for @kycPassport.
  ///
  /// In uz, this message translates to:
  /// **'Pasport'**
  String get kycPassport;

  /// No description provided for @kycLicense.
  ///
  /// In uz, this message translates to:
  /// **'Litsenziya / patent'**
  String get kycLicense;

  /// No description provided for @kycFacility.
  ///
  /// In uz, this message translates to:
  /// **'Ish joyi rasmi'**
  String get kycFacility;

  /// No description provided for @kycRequiredNote.
  ///
  /// In uz, this message translates to:
  /// **'Pasport va litsenziya majburiy'**
  String get kycRequiredNote;

  /// No description provided for @kycUpload.
  ///
  /// In uz, this message translates to:
  /// **'Yuklash'**
  String get kycUpload;

  /// No description provided for @kycApproved.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlangan'**
  String get kycApproved;

  /// No description provided for @kycPending.
  ///
  /// In uz, this message translates to:
  /// **'Tekshirilmoqda'**
  String get kycPending;

  /// No description provided for @kycReplace.
  ///
  /// In uz, this message translates to:
  /// **'Almashtirish'**
  String get kycReplace;

  /// No description provided for @ratingsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Sharhlar'**
  String get ratingsTitle;

  /// No description provided for @ratingsReplyHint.
  ///
  /// In uz, this message translates to:
  /// **'Javob yozing…'**
  String get ratingsReplyHint;

  /// No description provided for @ratingsReplyAction.
  ///
  /// In uz, this message translates to:
  /// **'Javob berish'**
  String get ratingsReplyAction;

  /// No description provided for @ratingsEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hali sharh yo\'q'**
  String get ratingsEmpty;

  /// No description provided for @loyaltyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Doimiy mijozlar'**
  String get loyaltyTitle;

  /// No description provided for @loyaltyOrdersCount.
  ///
  /// In uz, this message translates to:
  /// **'{n} buyurtma'**
  String loyaltyOrdersCount(int n);

  /// No description provided for @supportTelegramHandle.
  ///
  /// In uz, this message translates to:
  /// **'@sarimov_s'**
  String get supportTelegramHandle;
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
      'that was used.');
}
