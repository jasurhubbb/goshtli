// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Go\'sht Bozori Partners';

  @override
  String get languagePickerTitle => 'Выберите язык';

  @override
  String get languageUz => 'O\'zbekcha';

  @override
  String get languageRu => 'Русский';

  @override
  String get languageEn => 'English';

  @override
  String get next => 'Далее';

  @override
  String get back => 'Назад';

  @override
  String get skip => 'Пропустить';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get loading => 'Загрузка…';

  @override
  String get tryAgain => 'Повторить';

  @override
  String get rolePickerTitle => 'Кем вы регистрируетесь?';

  @override
  String get rolePickerSubtitle => 'Изменить нельзя';

  @override
  String get roleQassobTitle => 'Я мясник';

  @override
  String get roleQassobBody => 'Забой и разделка живого скота';

  @override
  String get roleSupplierTitle => 'Я продаю мясо';

  @override
  String get roleSupplierBody => 'Готовое мясо или живой скот';

  @override
  String get phoneEntryTitle => 'Ваш номер телефона';

  @override
  String get phoneEntryHint => '+998 90 123 45 67';

  @override
  String get phoneEntrySendCode => 'Отправить код';

  @override
  String get phoneEntryError => 'Введите корректный номер телефона';

  @override
  String get otpTitle => 'Код подтверждения';

  @override
  String otpSubtitle(String phone) {
    return 'Код отправлен на $phone';
  }

  @override
  String otpResend(int sec) {
    return 'Отправить снова ($secс)';
  }

  @override
  String get otpInvalid => 'Неверный или просроченный код';

  @override
  String get onboardingWelcomeQassob => 'Поздравляем! Быстрая регистрация';

  @override
  String get onboardingWelcomeSupplier => 'Поздравляем!';

  @override
  String get onboardingExperience => 'Сколько лет опыта?';

  @override
  String get onboardingYourName => 'Введите ваше имя';

  @override
  String get onboardingAboutYouTitle => 'О вас и вашем сервисе';

  @override
  String get onboardingFullName => 'Полное имя';

  @override
  String get onboardingCompanyName => 'Название сервиса (необязательно)';

  @override
  String get onboardingAnimalsTitleQassob =>
      'Каких животных можете разделывать?';

  @override
  String get onboardingAnimalsTitleSupplier => 'Каких животных продаёте?';

  @override
  String get onboardingAnimalsHint => 'Можно выбрать несколько';

  @override
  String get onboardingFormsTitle => 'Выберите форму для каждого';

  @override
  String get onboardingFormsHint =>
      'Живой — для свадеб, жертвоприношений. Готовое мясо — для ресторанов, опта';

  @override
  String get onboardingCapacity => 'Сколько голов в день?';

  @override
  String get onboardingSlaughterhouse => 'У вас есть бойня?';

  @override
  String get onboardingLocation => 'Укажите ваше местоположение';

  @override
  String get onboardingLocationDetect => 'Определить автоматически';

  @override
  String get onboardingLocationChange => 'Выбрать другое место';

  @override
  String get onboardingSelfDelivery => 'Доставляете сами?';

  @override
  String get onboardingVehicleType => 'Какой транспорт?';

  @override
  String get onboardingVehiclePlate => 'Гос. номер';

  @override
  String get onboardingPhoto => 'Фото рабочего места (необязательно)';

  @override
  String get onboardingPhotoSupplier => 'Фото бизнеса (необязательно)';

  @override
  String get onboardingTakePhoto => 'Сделать фото';

  @override
  String get onboardingSubmit => 'Подтвердить';

  @override
  String get onboardingSubmitting => 'Отправляется…';

  @override
  String get onboardingSubmitFailed =>
      'Не отправлено. Проверьте интернет и попробуйте снова.';

  @override
  String get animalMol => 'Говядина';

  @override
  String get animalQoy => 'Овца';

  @override
  String get animalEchki => 'Коза';

  @override
  String get animalOt => 'Конь';

  @override
  String get animalTovuq => 'Курица';

  @override
  String get vehicleRefrigerator => 'Рефрижератор';

  @override
  String get vehicleChorvaTaxi => 'Чорва-Такси';

  @override
  String get formLive => 'Живой';

  @override
  String get formCut => 'Готовое мясо';

  @override
  String get tabHome => 'Главная';

  @override
  String get tabOrders => 'Заказы';

  @override
  String get tabJobs => 'Работы';

  @override
  String get tabCatalog => 'Каталог';

  @override
  String get tabSchedule => 'График';

  @override
  String get tabEarnings => 'Доход';

  @override
  String get tabProfile => 'Профиль';

  @override
  String dashboardGreeting(String name) {
    return 'Здравствуйте, $name!';
  }

  @override
  String get dashboardOpenNow => 'Я принимаю заказы сейчас';

  @override
  String get dashboardKpiTodayRevenue => 'Доход сегодня';

  @override
  String get dashboardKpiOpenOrders => 'Новые заказы';

  @override
  String get dashboardKpiLowStock => 'Низкий запас';

  @override
  String get dashboardKpiReviews => 'Отзывы';

  @override
  String get dashboardSeeAll => 'Все';

  @override
  String get dashboardSmartTipsTitle => 'Ближайшие праздники';

  @override
  String dashboardSmartTipDaysUntil(int n) {
    return 'Осталось $n дн.';
  }

  @override
  String get verificationBannerTitle => 'Документы проверяются';

  @override
  String get verificationBannerBody =>
      'Ожидается подтверждение администратором';

  @override
  String get verificationBannerCta => 'Отправить документы';

  @override
  String get ordersTabNew => 'Новые';

  @override
  String get ordersTabActive => 'В работе';

  @override
  String get ordersTabDone => 'Выполнены';

  @override
  String get ordersAccept => 'Принять';

  @override
  String get ordersReject => 'Отклонить';

  @override
  String get ordersAdvance => 'Следующий этап';

  @override
  String get ordersEmpty => 'Пока нет заказов';

  @override
  String get jobsTabOffers => 'Новые предложения';

  @override
  String get jobsTabToday => 'Сегодня';

  @override
  String get jobsTabHistory => 'История';

  @override
  String get jobsClaim => 'Принять';

  @override
  String get jobsEmpty => 'Нет новых предложений';

  @override
  String get catalogTitle => 'Мои товары';

  @override
  String get catalogAddNew => 'Добавить товар';

  @override
  String get catalogQuickPriceTitle => 'Изменить цену';

  @override
  String catalogStock(String kg) {
    return 'Запас: $kg кг';
  }

  @override
  String get catalogEmpty => 'Пока нет товаров';

  @override
  String get scheduleTitle => 'График мощности';

  @override
  String scheduleBooked(int booked, int cap) {
    return '$booked/$cap занято';
  }

  @override
  String get earningsTitle => 'Доход';

  @override
  String get earningsPeriodDay => 'День';

  @override
  String get earningsPeriodWeek => 'Неделя';

  @override
  String get earningsPeriodMonth => 'Месяц';

  @override
  String get earningsTotalLabel => 'Всего';

  @override
  String get earningsOrdersLabel => 'Заказы';

  @override
  String get earningsAvgTicketLabel => 'Средний';

  @override
  String get earningsTopProductLabel => 'Топ продаж';

  @override
  String get earningsExportPdf => 'Экспорт PDF';

  @override
  String get earningsExportRange => 'Период';

  @override
  String get earningsExportSent => 'Отправлено — проверьте email';

  @override
  String get profileSectionEdit => 'Редактировать профиль';

  @override
  String get profileSectionReviews => 'Отзывы';

  @override
  String get profileSectionNotifications => 'Уведомления';

  @override
  String get profileSectionLanguage => 'Язык';

  @override
  String get profileSectionSupport => 'Связаться через Telegram';

  @override
  String get profileSectionLogout => 'Выйти';

  @override
  String get profileVerifiedBadge => 'Подтверждено';

  @override
  String get profilePendingBadge => 'Проверяется';

  @override
  String get profileEditTitle => 'Редактировать профиль';

  @override
  String get profileEditFullName => 'Полное имя';

  @override
  String get profileEditCallsAvailable => 'Доступен для звонков';

  @override
  String get profileEditCallsAvailableHint =>
      'Клиенты увидят ваш номер телефона';

  @override
  String get kycTitle => 'Документы';

  @override
  String get kycPassport => 'Паспорт';

  @override
  String get kycLicense => 'Лицензия / патент';

  @override
  String get kycFacility => 'Фото рабочего места';

  @override
  String get kycRequiredNote => 'Паспорт и лицензия обязательны';

  @override
  String get kycUpload => 'Загрузить';

  @override
  String get kycApproved => 'Подтверждено';

  @override
  String get kycPending => 'Проверяется';

  @override
  String get kycReplace => 'Заменить';

  @override
  String get ratingsTitle => 'Отзывы';

  @override
  String get ratingsReplyHint => 'Напишите ответ…';

  @override
  String get ratingsReplyAction => 'Ответить';

  @override
  String get ratingsEmpty => 'Отзывов пока нет';

  @override
  String get loyaltyTitle => 'Постоянные клиенты';

  @override
  String loyaltyOrdersCount(int n) {
    return '$n заказов';
  }

  @override
  String get supportTelegramHandle => '@sarimov_s';
}
