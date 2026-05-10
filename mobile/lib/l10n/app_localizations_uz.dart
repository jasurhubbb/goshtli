// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'Go\'sht Bozori';

  @override
  String get signIn => 'Kirish';

  @override
  String get welcomeSubtitle => 'Go\'sht Bozoriga xush kelibsiz';

  @override
  String get email => 'Email';

  @override
  String get password => 'Parol';

  @override
  String get passwordMin8 => 'Parol (kamida 8 ta belgi)';

  @override
  String get confirmPassword => 'Parolni tasdiqlang';

  @override
  String get fullName => 'To\'liq ism';

  @override
  String get phone => 'Telefon';

  @override
  String get createAccount => 'Hisob yaratish';

  @override
  String get noAccountCta => 'Hisobingiz yo\'qmi? Yangi yarating';

  @override
  String get haveAccountCta => 'Hisobingiz bormi? Tizimga kiring';

  @override
  String get validateEmail => 'To\'g\'ri email kiriting';

  @override
  String get validateMin8 => 'Kamida 8 ta belgi';

  @override
  String get validatePasswordMatch => 'Parollar mos kelmaydi';

  @override
  String get validateName => 'Ismingizni kiriting';

  @override
  String get roleBuyer => 'Xaridor';

  @override
  String get roleSupplier => 'Yetkazib beruvchi';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get home => 'Bosh sahifa';

  @override
  String get buyerHome => 'Xaridor bosh sahifasi';

  @override
  String get supplierHome => 'Yetkazib beruvchi bosh sahifasi';

  @override
  String get profile => 'Profil';

  @override
  String get logout => 'Chiqish';

  @override
  String get refresh => 'Yangilash';

  @override
  String get language => 'Til';

  @override
  String get tabHome => 'Asosiy';

  @override
  String get tabSearch => 'Qidirish';

  @override
  String get tabNotifications => 'Xabarnomalar';

  @override
  String get tabChats => 'Chatlar';

  @override
  String get tabProfile => 'Profil';

  @override
  String get chatsTitle => 'Chatlar';

  @override
  String get chatsComingSoon => 'Chat C bosqichida qo\'shiladi';

  @override
  String get notificationsTitle => 'Xabarnomalar';

  @override
  String get markAllRead => 'Hammasini o\'qilgan deb belgilash';

  @override
  String get deleteAccount => 'Hisobni o\'chirish';

  @override
  String get deleteAccountConfirmTitle => 'Hisobni o\'chirasizmi?';

  @override
  String get deleteAccountConfirmBody =>
      'Profil, e\'lonlar va buyurtmalar tarixi butunlay o\'chiriladi. Bu amalni qaytarib bo\'lmaydi.';

  @override
  String get deleteAccountConfirmYes => 'Ha, o\'chirish';

  @override
  String get becomeSeller => 'Sotuvchi bo\'lish';

  @override
  String get halal => 'Halol';

  @override
  String get freshnessDate => 'So\'yilgan sanasi';

  @override
  String get coldChainFresh => 'Yangi';

  @override
  String get coldChainChilled => 'Sovutilgan';

  @override
  String get coldChainFrozen => 'Muzlatilgan';

  @override
  String get serviceArea => 'Yetkazish hududi';

  @override
  String get addPhoto => 'Rasm qo\'shish';

  @override
  String get removePhoto => 'O\'chirish';

  @override
  String get photoRequired => 'Kamida bitta rasm kerak';

  @override
  String greeting(String name) {
    return 'Salom, $name 👋';
  }

  @override
  String get verificationPendingBanner =>
      'Hisobingiz tasdiqlanishi kutilmoqda — administrator tomonidan tasdiqlanmaguncha e\'lon yarata olmaysiz.';

  @override
  String get sectionListings => 'E\'lonlar';

  @override
  String get sectionOrders => 'Buyurtmalar';

  @override
  String get browseListings => 'E\'lonlarni ko\'rish';

  @override
  String get myOrders => 'Mening buyurtmalarim';

  @override
  String get myListings => 'Mening e\'lonlarim';

  @override
  String get incomingOrders => 'Kelgan buyurtmalar';

  @override
  String get newListing => 'Yangi e\'lon';

  @override
  String get statTotal => 'Jami';

  @override
  String get statActive => 'Faol';

  @override
  String get statSoldOut => 'Tugagan';

  @override
  String get statInactive => 'Faol emas';

  @override
  String get statPending => 'Kutilmoqda';

  @override
  String get statInProgress => 'Jarayonda';

  @override
  String get statDelivered => 'Yetkazildi';

  @override
  String get statCancelled => 'Bekor qilindi';

  @override
  String get listingsTitle => 'E\'lonlar';

  @override
  String get noListingsMatchFilters =>
      'Tanlangan filtrlarga mos e\'lon topilmadi';

  @override
  String get searchListingsHint => 'Sarlavha yoki tavsifdan qidiring';

  @override
  String get kgAvailableSuffix => 'kg mavjud';

  @override
  String get perKgSuffix => '/ kg';

  @override
  String get listingFieldTitle => 'Sarlavha';

  @override
  String get listingFieldMeatType => 'Go\'sht turi';

  @override
  String get listingFieldStatus => 'Holati';

  @override
  String get listingFieldPricePerKg => 'Narx / kg';

  @override
  String get listingFieldQuantity => 'Miqdor (kg)';

  @override
  String get listingFieldAvailable => 'Mavjud';

  @override
  String get listingFieldLocation => 'Manzil';

  @override
  String get listingFieldAvailableFrom => 'Mavjud sanasi';

  @override
  String get listingFieldDescription => 'Tavsif';

  @override
  String get listingFieldDescriptionOptional => 'Tavsif (ixtiyoriy)';

  @override
  String get listingPickAvailableFrom => 'Mavjudlik sanasini tanlang';

  @override
  String get listingMinTitleChars => 'Kamida 3 ta belgi';

  @override
  String get validateGtZero => '> 0 bo\'lishi kerak';

  @override
  String get validateRequired => 'Majburiy';

  @override
  String get createListingButton => 'E\'lon yaratish';

  @override
  String get listingDetailTitle => 'E\'lon';

  @override
  String get listingActionPlaceOrder => 'Buyurtma berish';

  @override
  String get listingActionEdit => 'Tahrirlash';

  @override
  String get listingActionDeactivate => 'Faolsizlantirish';

  @override
  String get listingActionSave => 'Saqlash';

  @override
  String get listingStatusActive => 'Faol';

  @override
  String get listingStatusSoldOut => 'Tugagan';

  @override
  String get listingStatusInactive => 'Faol emas';

  @override
  String get meatBeef => 'Mol go\'shti';

  @override
  String get meatMutton => 'Qo\'y go\'shti';

  @override
  String get meatChicken => 'Tovuq go\'shti';

  @override
  String get meatGoat => 'Echki go\'shti';

  @override
  String get meatHorse => 'Ot go\'shti';

  @override
  String get meatOther => 'Boshqa';

  @override
  String get myOrdersTitle => 'Mening buyurtmalarim';

  @override
  String get incomingOrdersTitle => 'Kelgan buyurtmalar';

  @override
  String get noOrdersYet => 'Hozircha buyurtmalar yo\'q';

  @override
  String get filterAll => 'Hammasi';

  @override
  String orderDetailTitle(int id) {
    return 'Buyurtma #$id';
  }

  @override
  String orderFromLabel(String email) {
    return 'Kimdan: $email';
  }

  @override
  String orderToLabel(String email) {
    return 'Kimga: $email';
  }

  @override
  String get orderFieldDeliveryAddress => 'Yetkazib berish manzili';

  @override
  String get orderFieldNotes => 'Izohlar';

  @override
  String get orderFieldNotesOptional => 'Izohlar (ixtiyoriy)';

  @override
  String orderPlaceTitle(String title) {
    return 'Buyurtma berish — $title';
  }

  @override
  String orderAvailabilityHint(String qty, String price) {
    return 'Mavjud: $qty kg @ $price / kg';
  }

  @override
  String get orderQtyAddrRequired =>
      'Miqdor va yetkazib berish manzili majburiy';

  @override
  String orderOnlyKgAvailable(String qty) {
    return 'Faqat $qty kg mavjud';
  }

  @override
  String get orderConfirmButton => 'Buyurtmani tasdiqlash';

  @override
  String get orderPlacedSnack => 'Buyurtma berildi';

  @override
  String get orderCancelButton => 'Buyurtmani bekor qilish';

  @override
  String get orderCancelTitle => 'Buyurtmani bekor qilasizmi?';

  @override
  String get orderCancelBody =>
      'E\'londagi miqdor qaytariladi. Bu amalni qaytarib bo\'lmaydi.';

  @override
  String get no => 'Yo\'q';

  @override
  String get orderActionConfirm => 'Tasdiqlash';

  @override
  String get orderActionStartProcessing => 'Tayyorlashni boshlash';

  @override
  String get orderActionMarkInTransit => 'Yo\'lga chiqdi deb belgilash';

  @override
  String get orderActionMarkDelivered => 'Yetkazildi deb belgilash';

  @override
  String get orderActionCancel => 'Bekor qilish';

  @override
  String orderTerminalNoActions(String status) {
    return 'Boshqa amal yo\'q — buyurtma $status';
  }

  @override
  String get orderStatusPending => 'Kutilmoqda';

  @override
  String get orderStatusConfirmed => 'Tasdiqlangan';

  @override
  String get orderStatusProcessing => 'Tayyorlanmoqda';

  @override
  String get orderStatusInTransit => 'Yo\'lda';

  @override
  String get orderStatusDelivered => 'Yetkazilgan';

  @override
  String get orderStatusCancelled => 'Bekor qilingan';

  @override
  String get profileTitle => 'Profil';

  @override
  String get buyerProfileTitle => 'Xaridor profili';

  @override
  String get supplierProfileTitle => 'Yetkazib beruvchi profili';

  @override
  String get profileFieldBusinessName => 'Korxona nomi';

  @override
  String get profileFieldRegion => 'Hudud';

  @override
  String get profileFieldAddress => 'Manzil';

  @override
  String get profileVerified => 'Tasdiqlangan';

  @override
  String get profileUnverified => 'Tasdiqlanmagan';

  @override
  String get profileSavedSnack => 'Saqlandi';

  @override
  String get profileAdminViaDjango =>
      'Administrator profili Django Admin orqali tahrirlanadi';

  @override
  String failedPrefix(String error) {
    return 'Xatolik: $error';
  }

  @override
  String get viewAll => 'Barchasi';

  @override
  String get sectionFarmers => 'Fermalar';

  @override
  String get sectionButchers => 'Qassoblar';
}
