// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'Go\'sht Bozori Partners';

  @override
  String get languagePickerTitle => 'Til tanlang';

  @override
  String get languageUz => 'O\'zbekcha';

  @override
  String get languageRu => 'Русский';

  @override
  String get languageEn => 'English';

  @override
  String get next => 'Keyingisi';

  @override
  String get back => 'Orqaga';

  @override
  String get skip => 'O\'tkazib yuborish';

  @override
  String get confirm => 'Tasdiqlash';

  @override
  String get cancel => 'Bekor qilish';

  @override
  String get save => 'Saqlash';

  @override
  String get yes => 'Ha';

  @override
  String get no => 'Yo\'q';

  @override
  String get loading => 'Yuklanmoqda…';

  @override
  String get tryAgain => 'Qayta urinish';

  @override
  String get rolePickerTitle => 'Kim sifatida ro\'yxatdan o\'tasiz?';

  @override
  String get rolePickerSubtitle => 'Keyinroq o\'zgartira olmaysiz';

  @override
  String get roleQassobTitle => 'Qassobman';

  @override
  String get roleQassobBody => 'Tirik chorvani so\'yish va bo\'laklash';

  @override
  String get roleSupplierTitle => 'Go\'sht sotaman';

  @override
  String get roleSupplierBody => 'Tayyor go\'sht yoki tirik chorva sotuvi';

  @override
  String get phoneEntryTitle => 'Telefon raqamingiz';

  @override
  String get phoneEntryHint => '+998 90 123 45 67';

  @override
  String get phoneEntrySendCode => 'Kod yuborish';

  @override
  String get phoneEntryError => 'Telefon raqamini to\'g\'ri kiriting';

  @override
  String get otpTitle => 'Tasdiqlash kodi';

  @override
  String otpSubtitle(String phone) {
    return 'Kod $phone raqamiga yuborildi';
  }

  @override
  String otpResend(int sec) {
    return 'Qayta yuborish (${sec}s)';
  }

  @override
  String get otpInvalid => 'Kod noto\'g\'ri yoki muddati o\'tgan';

  @override
  String get onboardingWelcomeQassob =>
      'Tabriklaymiz! Tezda ro\'yxatdan o\'tasiz';

  @override
  String get onboardingWelcomeSupplier => 'Tabriklaymiz!';

  @override
  String get onboardingExperience => 'Tajribangiz necha yil?';

  @override
  String get onboardingYourName => 'Ismingizni kiriting';

  @override
  String get onboardingAboutYouTitle => 'O\'zingiz va servisingiz haqida';

  @override
  String get onboardingFullName => 'To\'liq ism';

  @override
  String get onboardingCompanyName => 'Servis nomi (ixtiyoriy)';

  @override
  String get onboardingAnimalsTitleQassob => 'Qaysi hayvonlarni so\'ya olasiz?';

  @override
  String get onboardingAnimalsTitleSupplier => 'Qaysi hayvonlarni sotasiz?';

  @override
  String get onboardingAnimalsHint => 'Bir nechtasini tanlashingiz mumkin';

  @override
  String get onboardingFormsTitle => 'Har biri uchun shaklini tanlang';

  @override
  String get onboardingFormsHint =>
      'Tirik chorva — to\'y, qurbonlik. Tayyor go\'sht — restoran, ulgurji';

  @override
  String get onboardingCapacity => 'Kuniga nechta bosh?';

  @override
  String get onboardingSlaughterhouse => 'Qushxonangiz bormi?';

  @override
  String get onboardingLocation => 'Joylashuvingizni belgilang';

  @override
  String get onboardingLocationDetect => 'Avtomatik aniqlash';

  @override
  String get onboardingLocationChange => 'Boshqa joy tanlash';

  @override
  String get onboardingSelfDelivery => 'O\'zingiz yetkazib bera olasizmi?';

  @override
  String get onboardingVehicleType => 'Qaysi mashina turi?';

  @override
  String get onboardingVehiclePlate => 'Davlat raqami';

  @override
  String get onboardingPhoto => 'Ish joyi rasmi (ixtiyoriy)';

  @override
  String get onboardingPhotoSupplier => 'Biznes rasmi (ixtiyoriy)';

  @override
  String get onboardingTakePhoto => 'Rasm olish';

  @override
  String get onboardingSubmit => 'Tasdiqlash';

  @override
  String get onboardingSubmitting => 'Yuborilmoqda…';

  @override
  String get onboardingSubmitFailed =>
      'Yuborilmadi. Internetni tekshirib qayta urinib ko\'ring.';

  @override
  String get animalMol => 'Mol';

  @override
  String get animalQoy => 'Qo\'y';

  @override
  String get animalEchki => 'Echki';

  @override
  String get animalOt => 'Ot';

  @override
  String get animalTovuq => 'Tovuq';

  @override
  String get vehicleRefrigerator => 'Refrigerator';

  @override
  String get vehicleChorvaTaxi => 'Chorva-Taksi';

  @override
  String get formLive => 'Tirik';

  @override
  String get formCut => 'Tayyor go\'sht';

  @override
  String get tabHome => 'Bosh sahifa';

  @override
  String get tabOrders => 'Buyurtmalar';

  @override
  String get tabJobs => 'Ishlar';

  @override
  String get tabCatalog => 'Katalog';

  @override
  String get tabSchedule => 'Jadval';

  @override
  String get tabEarnings => 'Daromad';

  @override
  String get tabProfile => 'Profil';

  @override
  String dashboardGreeting(String name) {
    return 'Salom, $name!';
  }

  @override
  String get dashboardOpenNow => 'Hozir buyurtma qabul qilaman';

  @override
  String get dashboardKpiTodayRevenue => 'Bugungi daromad';

  @override
  String get dashboardKpiOpenOrders => 'Yangi buyurtmalar';

  @override
  String get dashboardKpiLowStock => 'Kam zaxira';

  @override
  String get dashboardKpiReviews => 'Sharhlar';

  @override
  String get dashboardSeeAll => 'Hammasi';

  @override
  String get dashboardSmartTipsTitle => 'Yaqinlashayotgan bayramlar';

  @override
  String dashboardSmartTipDaysUntil(int n) {
    return '$n kun qoldi';
  }

  @override
  String get verificationBannerTitle => 'Hujjatlar tekshirilmoqda';

  @override
  String get verificationBannerBody =>
      'Administrator tomonidan tasdiqlanish kutilmoqda';

  @override
  String get verificationBannerCta => 'Hujjatlarni yuborish';

  @override
  String get ordersTabNew => 'Yangi';

  @override
  String get ordersTabActive => 'Jarayonda';

  @override
  String get ordersTabDone => 'Bajarilgan';

  @override
  String get ordersAccept => 'Qabul qilish';

  @override
  String get ordersReject => 'Rad etish';

  @override
  String get ordersAdvance => 'Keyingi bosqich';

  @override
  String get ordersEmpty => 'Hozircha buyurtma yo\'q';

  @override
  String get jobsTabOffers => 'Yangi takliflar';

  @override
  String get jobsTabToday => 'Bugun';

  @override
  String get jobsTabHistory => 'Tarix';

  @override
  String get jobsClaim => 'Qabul qilish';

  @override
  String get jobsEmpty => 'Yangi takliflar yo\'q';

  @override
  String get catalogTitle => 'Mening tovarlarim';

  @override
  String get catalogAddNew => 'Yangi tovar qo\'shish';

  @override
  String get catalogQuickPriceTitle => 'Narxni o\'zgartirish';

  @override
  String catalogStock(String kg) {
    return 'Zaxira: $kg kg';
  }

  @override
  String get catalogEmpty => 'Hali tovar qo\'shilmagan';

  @override
  String get scheduleTitle => 'Sig\'im jadvali';

  @override
  String scheduleBooked(int booked, int cap) {
    return '$booked/$cap band';
  }

  @override
  String get earningsTitle => 'Daromad';

  @override
  String get earningsPeriodDay => 'Kun';

  @override
  String get earningsPeriodWeek => 'Hafta';

  @override
  String get earningsPeriodMonth => 'Oy';

  @override
  String get earningsTotalLabel => 'Jami';

  @override
  String get earningsOrdersLabel => 'Buyurtmalar';

  @override
  String get earningsAvgTicketLabel => 'O\'rtacha';

  @override
  String get earningsTopProductLabel => 'Eng ko\'p sotilgan';

  @override
  String get earningsExportPdf => 'PDF eksport';

  @override
  String get earningsExportRange => 'Sana oralig\'i';

  @override
  String get earningsExportSent => 'Yuborildi — emailingizni tekshiring';

  @override
  String get profileSectionEdit => 'Profilni tahrirlash';

  @override
  String get profileSectionReviews => 'Sharhlar';

  @override
  String get profileSectionNotifications => 'Bildirishnomalar';

  @override
  String get profileSectionLanguage => 'Til';

  @override
  String get profileSectionSupport => 'Telegram orqali bog\'lanish';

  @override
  String get profileSectionLogout => 'Chiqish';

  @override
  String get profileVerifiedBadge => 'Tasdiqlangan';

  @override
  String get profilePendingBadge => 'Tekshirilmoqda';

  @override
  String get profileEditTitle => 'Profilni tahrirlash';

  @override
  String get profileEditFullName => 'To\'liq ism';

  @override
  String get profileEditCallsAvailable =>
      'Telefon qo\'ng\'iroqlari uchun ochiqman';

  @override
  String get profileEditCallsAvailableHint =>
      'Mijozlar telefon raqamingizni ko\'ra oladi';

  @override
  String get kycTitle => 'Hujjatlar';

  @override
  String get kycPassport => 'Pasport';

  @override
  String get kycLicense => 'Litsenziya / patent';

  @override
  String get kycFacility => 'Ish joyi rasmi';

  @override
  String get kycRequiredNote => 'Pasport va litsenziya majburiy';

  @override
  String get kycUpload => 'Yuklash';

  @override
  String get kycApproved => 'Tasdiqlangan';

  @override
  String get kycPending => 'Tekshirilmoqda';

  @override
  String get kycReplace => 'Almashtirish';

  @override
  String get ratingsTitle => 'Sharhlar';

  @override
  String get ratingsReplyHint => 'Javob yozing…';

  @override
  String get ratingsReplyAction => 'Javob berish';

  @override
  String get ratingsEmpty => 'Hali sharh yo\'q';

  @override
  String get loyaltyTitle => 'Doimiy mijozlar';

  @override
  String loyaltyOrdersCount(int n) {
    return '$n buyurtma';
  }

  @override
  String get supportTelegramHandle => '@sarimov_s';
}
