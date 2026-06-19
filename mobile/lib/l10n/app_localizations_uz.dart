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

  @override
  String get appLanguage => 'Ilova tili';

  @override
  String appVersionLabel(String version) {
    return 'Ilova versiyasi $version';
  }

  @override
  String get privacyPolicyLink => 'maxfiylik siyosatini';

  @override
  String get termsOfUseLink => 'foydalanish shartlarini';

  @override
  String privacyTagline(String policy, String terms) {
    return 'Bosish orqali siz $policy va $terms qabul qilasiz.';
  }

  @override
  String get anonWelcomeTitle => 'Go\'sht Bozoriga xush kelibsiz';

  @override
  String get anonWelcomeSubtitle =>
      'E\'lonlarni ko\'rib chiqing — buyurtma berish vaqtida ro\'yxatdan o\'tasiz.';

  @override
  String get onbLocationTitle => 'Sizning hududingiz';

  @override
  String get onbLocationBody =>
      'Yaqin atrofdagi go\'sht sotuvchilarini ko\'rsatish uchun joylashuvingizdan foydalanamiz. Bu ixtiyoriy — keyinroq Profil sahifasidan o\'zgartirishingiz mumkin.';

  @override
  String get onbDetectLocation => 'Joylashuvni aniqlash';

  @override
  String get onbNotNow => 'Hozir emas';

  @override
  String get pickLanguageTitle => 'Tilni tanlang';

  @override
  String get continueAction => 'Davom eting';

  @override
  String get savedListingsTitle => 'Sevimli e\'lonlar';

  @override
  String get noSavedListingsYet => 'Hozircha saqlangan e\'lonlar yo\'q';

  @override
  String get messageHint => 'Xabar…';

  @override
  String get noConversationsYet => 'Hozircha suhbatlar yo\'q';

  @override
  String get noNotificationsYet => 'Hozircha bildirishnomalar yo\'q';

  @override
  String get leaveReviewTitle => 'Sharh qoldirish';

  @override
  String get reviewCommentOptional => 'Izoh (ixtiyoriy)';

  @override
  String get serviceAreaHint => 'Toshkent, Samarqand, ...';

  @override
  String get tabMenu => 'Menyu';

  @override
  String get tabCart => 'Savat';

  @override
  String get tabOrders => 'Buyurtmalar';

  @override
  String get tabServices => 'Servislar';

  @override
  String get servicesQassobs => 'Qassoblar';

  @override
  String get servicesSlaughterhouses => 'Qushxona xizmatlari';

  @override
  String get servicesFilterAll => 'Hammasi';

  @override
  String get servicesContact => 'Bog\'lanish';

  @override
  String get servicesProfile => 'Profil';

  @override
  String get servicesNoneFound => 'Hozircha topilmadi';

  @override
  String servicesYearsExp(int n) {
    return '$n yil tajriba';
  }

  @override
  String get cartTitle => 'Savat';

  @override
  String cartItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta mahsulot',
      one: '1 ta mahsulot',
      zero: '0 ta mahsulot',
    );
    return '$_temp0';
  }

  @override
  String get cartEmptyTitle => 'Savat bo\'sh';

  @override
  String get cartEmptyHint =>
      'Menyu sahifasidan biror mahsulotni tanlab qo\'shing.';

  @override
  String get cartGoToMenu => 'Menyuga o\'tish';

  @override
  String get cartShopNoteLabel => 'Do\'konga izoh';

  @override
  String get cartShopNoteHint =>
      'Masalan: 1 kg bo\'lakka kesilsin, suyaksiz, kechqurun yetkazib bering';

  @override
  String get cartSubTotal => 'Oraliq summa';

  @override
  String get cartTotal => 'JAMI';

  @override
  String get cartCheckout => 'Buyurtma berish';

  @override
  String get cartCheckoutSnack =>
      'Buyurtma berildi — backend ulanishi keyinroq.';

  @override
  String get soumSuffix => 'so\'m';

  @override
  String get perKgShort => '/kg';

  @override
  String get cartAdd => 'Qo\'shish';

  @override
  String get cartPeekTitle => 'Sizning savatingiz';

  @override
  String get cartPeekChip => 'Ko\'rish';

  @override
  String get cartPeekViewAll => 'Savatga qo\'shish';

  @override
  String cartItemsShort(int count) {
    return '$count ta';
  }

  @override
  String get cartFloatingPeek => 'Ko\'rish uchun bosing';

  @override
  String get menuTitle => 'Menyu';

  @override
  String get menuPickHint => 'Bugun nima pishirasiz?';

  @override
  String get homeSearchHint => 'Mahsulot qidirish...';

  @override
  String get homeRegionPickerTitle => 'Hududni tanlang';

  @override
  String get homeRegionAll => 'Barcha hududlar';

  @override
  String get addressesTitle => 'Manzillar';

  @override
  String get addressesEmpty => 'Hozircha saqlangan manzil yo\'q.';

  @override
  String get addressesNewCta => 'Yangi manzil';

  @override
  String get addressesSignInCta => 'Manzilni saqlash uchun kiring';

  @override
  String get addressFormTitleNew => 'Yangi manzil';

  @override
  String get addressFormTitleEdit => 'Manzil tafsilotlari';

  @override
  String get addressFieldLabel => 'Manzil nomi';

  @override
  String get addressFieldLabelHint => 'Uy, Ofis, Restoran...';

  @override
  String get addressFieldStreet => 'Manzil';

  @override
  String get addressFieldStreetHint => 'Ko\'cha, mahalla, uy raqami';

  @override
  String get addressFieldEntrance => 'Kirish yo\'lagi';

  @override
  String get addressFieldFloor => 'Qavat';

  @override
  String get addressFieldApartment => 'Xonadon';

  @override
  String get addressFieldNotes => 'Belgilangan joy va manzil tafsilotlari';

  @override
  String get addressFieldNotesHelp =>
      'Bu kuryerga sizni tezroq topishga yordam beradi';

  @override
  String get addressFieldDefault => 'Asosiy manzil sifatida belgilash';

  @override
  String get addressSaveCta => 'Manzilni saqlash';

  @override
  String get addressDeleteCta => 'O\'chirish';

  @override
  String get addressDeleteConfirm => 'Bu manzilni o\'chirasizmi?';

  @override
  String get addressMapTitle => 'Manzilni xaritadan tanlang';

  @override
  String get addressMapConfirmTitle => 'Hammasi to\'g\'rimi?';

  @override
  String get addressMapConfirmBody =>
      'Marker kirish joyida ekanligiga ishonch hosil qiling va manzilni tasdiqlang';

  @override
  String get addressMapConfirmCta => 'Uy raqamini aniqlashtirish';

  @override
  String get addressMapMyLocation => 'Mening joylashuvim';

  @override
  String get phoneAuthTitle => 'Telefon raqamingiz';

  @override
  String get phoneAuthSubtitle =>
      'Kirish yoki ro\'yxatdan o\'tish uchun raqamingizni kiriting';

  @override
  String get phoneAuthHint => '90 123-45-67';

  @override
  String get phoneAuthContinue => 'Davom etish';

  @override
  String get phoneAuthInvalid => '9 raqamli telefon raqami kiriting';

  @override
  String get phoneDetailsTitle => 'O\'zingiz haqida';

  @override
  String get phoneDetailsSubtitle => 'Buyurtmalar uchun ism kerak';

  @override
  String get phoneDetailsNameLabel => 'Ismingiz';

  @override
  String get phoneDetailsBusinessLabel => 'Biznes nomi (ixtiyoriy)';

  @override
  String get phoneDetailsCta => 'Kirish';

  @override
  String get profileSettingsTitle => 'Profil sozlamalari';

  @override
  String get profileTapToEdit => 'To\'g\'rilash';

  @override
  String get profileFieldLastName => 'Familiya';

  @override
  String get profileFieldFirstName => 'Ism';

  @override
  String get profileFieldPatronymic => 'Otasining ismi';

  @override
  String get profileFieldPatronymicHint => 'Ota ismini kiriting';

  @override
  String get profileFieldDateOfBirth => 'Tug\'ilgan kun';

  @override
  String get profileFieldDateOfBirthHint => 'Sanani tanlang';

  @override
  String get profileFieldGender => 'Jins';

  @override
  String get genderMale => 'Erkak';

  @override
  String get genderFemale => 'Ayol';

  @override
  String get profileFieldPhone => 'Telefon raqami';

  @override
  String get profileMyCards => 'Kartalarim';

  @override
  String get profileCardsEmpty => 'Hozircha kartalar yo\'q';

  @override
  String get profileContactUs => 'Biz bilan bog\'lanish';

  @override
  String get profileTelegramOpenFailed => 'Telegramni ochib bo\'lmadi';

  @override
  String get cancel => 'Bekor qilish';

  @override
  String get adminEnterCta => 'Admin sifatida kirish';

  @override
  String get adminEnterPasswordTitle => 'Admin paroli';

  @override
  String get adminEnterPasswordHint => 'Parolni kiriting';

  @override
  String get adminEnterPasswordWrong => 'Parol noto\'g\'ri';

  @override
  String get adminTitle => 'Admin';

  @override
  String get adminTabNewListing => 'Yangi e\'lon';

  @override
  String get adminTabManage => 'Boshqarish';

  @override
  String get adminNewListingPickSupplier => 'Yetkazib beruvchini tanlang';

  @override
  String get adminNewListingSubmit => 'E\'lonni saqlash';

  @override
  String get adminManageListings => 'E\'lonlar';

  @override
  String get adminManageSuppliers => 'Yetkazib beruvchilar';

  @override
  String get adminManageCategories => 'Kategoriyalar';

  @override
  String get adminManageMarkets => 'Bozorlar';

  @override
  String get adminManageHint =>
      'Tanlangan bo\'limda yaratish/tahrirlash mumkin';

  @override
  String get adminComingSoon => 'Tez orada qo\'shiladi';

  @override
  String get adminListingCreated => 'E\'lon yaratildi';

  @override
  String get adminPermissionDenied =>
      'Admin huquqlari kerak — admin akkaunt bilan kiring';

  @override
  String get adminNewListingPhotos => 'Rasmlar';

  @override
  String get adminPickFromGallery => 'Galereyadan tanlash';

  @override
  String get adminPickFromCamera => 'Kameradan suratga olish';

  @override
  String get adminMarketDetailListings => 'Bu bozordagi e\'lonlar';

  @override
  String get adminMarketEditCta => 'Tahrirlash';

  @override
  String get adminMarketDeleteCta => 'Bozorni o\'chirish';

  @override
  String get adminMarketPhoneLabel => 'Telefon raqami';

  @override
  String get adminMarketEmpty => 'Hozircha e\'lonlar yo\'q';

  @override
  String get adminListingEditTitle => 'E\'lonni tahrirlash';

  @override
  String get adminListingSavedToast => 'Saqlandi';

  @override
  String get adminListingDeleteCta => 'E\'lonni o\'chirish';

  @override
  String get statusActive => 'Faol';

  @override
  String get statusSoldOut => 'Tugagan';

  @override
  String get statusInactive => 'Faol emas';

  @override
  String get addressAutoDetectedHint =>
      'Aniqlangan joylashuv · aniqlashtirish uchun bosing';

  @override
  String get otpTitle => 'Tasdiqlash kodi';

  @override
  String otpSentTo(String phone) {
    return 'Kod $phone raqamiga yuborildi';
  }

  @override
  String get otpResend => 'Qaytadan yuborish';

  @override
  String otpResendIn(int seconds) {
    return 'Qaytadan yuborish (${seconds}s)';
  }

  @override
  String get otpInvalidCode => 'Kod noto\'g\'ri';

  @override
  String get otpExpired => 'Kod muddati tugadi — qaytadan yuboring';

  @override
  String get qtyEditorTitle => 'Miqdor (kg)';

  @override
  String get qtyEditorEnterAmount => 'Miqdorni kiriting';

  @override
  String get qtyEditorOnlyDigits => 'Faqat raqam';

  @override
  String get qtyEditorMustBePositive => 'Noldan katta bo\'lishi kerak';

  @override
  String qtyEditorMaxExceeded(int max) {
    return 'Maksimum: $max kg';
  }

  @override
  String qtyEditorAvailable(int max) {
    return 'Mavjud: $max kg';
  }

  @override
  String get qtyEditorMax => 'Hammasi';

  @override
  String get qtyEditorConfirm => 'Tasdiqlash';

  @override
  String get payTitle => 'To\'lov';

  @override
  String get payProcessing => 'To\'lov amalga oshirilmoqda…';

  @override
  String get payCheckingStatus => 'Status tekshirilmoqda…';

  @override
  String get paySuccessTitle => 'To\'lov muvaffaqiyatli';

  @override
  String get paySuccessBody => 'Buyurtmangiz qabul qilindi';

  @override
  String get payFailedTitle => 'To\'lov amalga oshmadi';

  @override
  String get payRetry => 'Qaytadan urinish';

  @override
  String get payToOrders => 'Buyurtmalarga o\'tish';

  @override
  String get payCancel => 'Bekor qilish';

  @override
  String qtyEditorBelowMinimum(int min) {
    return 'Minimal miqdor: $min';
  }

  @override
  String get liveAnimalBadgeByHead => '1 BOSH';

  @override
  String get liveAnimalBadgeByWeight => 'TIRIK VAZN';

  @override
  String get deliveryTitle => 'Yetkazib berish';

  @override
  String get deliveryAddressSection => 'Manzil';

  @override
  String get deliveryAddressChange => 'O\'zgartirish';

  @override
  String deliveryDistanceLabel(String km) {
    return 'Masofa: $km km';
  }

  @override
  String get deliveryVehicleSection => 'Transport turi';

  @override
  String get deliveryVehicleRefrigerator => 'Refrijerator';

  @override
  String get deliveryVehicleRefrigeratorHint =>
      'Sovuqlik zanjiri • 0°C dan +4°C';

  @override
  String get deliveryVehicleChorvaTaxi => 'Chorva-Taksi';

  @override
  String get deliveryVehicleChorvaTaxiHint =>
      'Tirik chorva uchun maxsus transport';

  @override
  String get deliveryVehicleUnavailable => 'Mavjud emas';

  @override
  String get deliveryTimeSlotSection => 'Vaqt oralig\'i';

  @override
  String get deliveryTimeSlot0609 => '06:00 – 09:00';

  @override
  String get deliveryTimeSlot0913 => '09:00 – 13:00';

  @override
  String get deliveryTimeSlot1318 => '13:00 – 18:00';

  @override
  String get deliveryButcherSection => 'Qassob xizmati';

  @override
  String get deliveryButcherTitle =>
      'Tirik chorvani so\'yish va bo\'laklash kerakmi?';

  @override
  String get deliveryButcherSubtitle =>
      'Professional qassob xizmati. So\'yish, tozalash va bo\'laklab paketlash.';

  @override
  String deliveryButcherFeeLabel(String fee) {
    return 'Xizmat narxi: $fee';
  }

  @override
  String get deliveryButcherAccept => 'Qassob xizmatini qo\'shish';

  @override
  String get deliveryBreakdownSection => 'Hisob-kitob';

  @override
  String get deliveryBreakdownProducts => 'Mahsulotlar';

  @override
  String get deliveryBreakdownDelivery => 'Yetkazib berish';

  @override
  String get deliveryBreakdownButcher => 'Qassob xizmati';

  @override
  String get deliveryBreakdownTotal => 'JAMI';

  @override
  String get deliveryProceedCta => 'To\'lovga o\'tish';

  @override
  String get deliveryNeedAddress => 'Avval manzilni belgilang';

  @override
  String get deliveryLoadingQuote => 'Hisob-kitob yuklanmoqda…';

  @override
  String get deliveryQuoteError =>
      'Hisob-kitobni olib bo\'lmadi. Qayta urinib ko\'ring.';

  @override
  String get deliveryPickMapHint => 'Xaritadan manzilni tanlash';

  @override
  String get deliveryFloorMin =>
      'Minimal buyurtma 10 kg dan boshlanadi (ulgurji shartlari).';

  @override
  String get deliveryTashkentOnlyBanner =>
      'Hozircha faqat Toshkent shahri ichida yetkazib beramiz. Hisob-kitob shahar markaziga nisbatan tuziladi.';

  @override
  String get deliveryTashkentOnlyShort => 'Hozircha faqat Toshkent shahrida';

  @override
  String get testUseYunusobod =>
      'TEST: Yunusobod (Toshkent) joylashuvini qo\'llash';

  @override
  String get testYunusobodApplied => 'Joylashuv Yunusobodga o\'rnatildi';

  @override
  String get cardsTitle => 'Mening kartalarim';

  @override
  String get cardsAddTitle => 'Yangi karta qo\'shish';

  @override
  String get cardsAddCta => 'Yangi karta qo\'shish';

  @override
  String get cardsAddError => 'Karta qo\'shilmadi. Qayta urinib ko\'ring.';

  @override
  String get cardsPan => 'Karta raqami';

  @override
  String get cardsExpiry => 'Amal qilish muddati';

  @override
  String get cardsHolder => 'Karta egasi (ism)';

  @override
  String get cardsPhone => 'SMS uchun telefon';

  @override
  String get cardsMakeDefault => 'Ushbu kartani asosiy qilish';

  @override
  String get cardsPciNote =>
      'Karta ma\'lumotlari shifrlangan kanal orqali yuboriladi. Biz to\'liq karta raqamini saqlamaymiz.';

  @override
  String get cardsEmptyTitle => 'Hali kartalar yo\'q';

  @override
  String get cardsEmptyHint => 'Buyurtmalarni to\'lash uchun karta qo\'shing.';

  @override
  String get cardsLoadError => 'Kartalarni yuklab bo\'lmadi.';

  @override
  String get cardsDefaultBadge => 'ASOSIY';

  @override
  String get cardsExpiredLabel => 'Karta muddati tugagan';

  @override
  String get cardsActionMakeDefault => 'Asosiy qilish';

  @override
  String get cardsActionDelete => 'O\'chirish';

  @override
  String get cardsDeletedSnack => 'Karta o\'chirildi';

  @override
  String get paymentAmountLabel => 'To\'lov summasi';

  @override
  String get paymentMethodSection => 'To\'lov usuli';

  @override
  String paymentPayCta(String amount) {
    return 'To\'lash · $amount';
  }

  @override
  String get paymentPayCtaShort => 'To\'lash';

  @override
  String paymentSuccessCardLine(String brand, String last4) {
    return '$brand •••• $last4 dan to\'landi';
  }

  @override
  String get authServerUnavailable =>
      'Server vaqtinchalik ishlamayapti. Iltimos, bir oz vaqtdan so\'ng qayta urinib ko\'ring.';

  @override
  String get authNetworkError =>
      'Internetga ulanmadi. Aloqani tekshiring va qaytadan urinib ko\'ring.';

  @override
  String get authNetworkTimeout =>
      'So\'rov vaqti tugadi. Iltimos, qaytadan urinib ko\'ring.';

  @override
  String get authUnexpectedError =>
      'Kutilmagan xatolik yuz berdi. Iltimos, keyinroq urinib ko\'ring.';
}
