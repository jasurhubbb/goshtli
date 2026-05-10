// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Мясной рынок';

  @override
  String get signIn => 'Войти';

  @override
  String get welcomeSubtitle => 'С возвращением в Мясной рынок';

  @override
  String get email => 'Email';

  @override
  String get password => 'Пароль';

  @override
  String get passwordMin8 => 'Пароль (минимум 8 символов)';

  @override
  String get confirmPassword => 'Подтвердите пароль';

  @override
  String get fullName => 'Полное имя';

  @override
  String get phone => 'Телефон';

  @override
  String get createAccount => 'Создать аккаунт';

  @override
  String get noAccountCta => 'Нет аккаунта? Создайте';

  @override
  String get haveAccountCta => 'Уже есть аккаунт? Войти';

  @override
  String get validateEmail => 'Введите правильный email';

  @override
  String get validateMin8 => 'Минимум 8 символов';

  @override
  String get validatePasswordMatch => 'Пароли не совпадают';

  @override
  String get validateName => 'Введите имя';

  @override
  String get roleBuyer => 'Покупатель';

  @override
  String get roleSupplier => 'Поставщик';

  @override
  String get roleAdmin => 'Администратор';

  @override
  String get home => 'Главная';

  @override
  String get buyerHome => 'Главная покупателя';

  @override
  String get supplierHome => 'Главная поставщика';

  @override
  String get profile => 'Профиль';

  @override
  String get logout => 'Выйти';

  @override
  String get refresh => 'Обновить';

  @override
  String get language => 'Язык';

  @override
  String get tabHome => 'Главная';

  @override
  String get tabSearch => 'Поиск';

  @override
  String get tabNotifications => 'Уведомления';

  @override
  String get tabChats => 'Чаты';

  @override
  String get tabProfile => 'Профиль';

  @override
  String get chatsTitle => 'Чаты';

  @override
  String get chatsComingSoon => 'Чат появится на этапе C';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get markAllRead => 'Отметить всё как прочитанное';

  @override
  String get deleteAccount => 'Удалить аккаунт';

  @override
  String get deleteAccountConfirmTitle => 'Удалить аккаунт?';

  @override
  String get deleteAccountConfirmBody =>
      'Профиль, объявления и история заказов будут удалены навсегда. Это действие нельзя отменить.';

  @override
  String get deleteAccountConfirmYes => 'Да, удалить';

  @override
  String get becomeSeller => 'Стать продавцом';

  @override
  String get halal => 'Халяль';

  @override
  String get freshnessDate => 'Дата забоя';

  @override
  String get coldChainFresh => 'Свежее';

  @override
  String get coldChainChilled => 'Охлаждённое';

  @override
  String get coldChainFrozen => 'Замороженное';

  @override
  String get serviceArea => 'Зона доставки';

  @override
  String get addPhoto => 'Добавить фото';

  @override
  String get removePhoto => 'Удалить';

  @override
  String get photoRequired => 'Требуется минимум одно фото';

  @override
  String greeting(String name) {
    return 'Здравствуйте, $name 👋';
  }

  @override
  String get verificationPendingBanner =>
      'Аккаунт ожидает проверки — создание объявлений недоступно до подтверждения администратором.';

  @override
  String get sectionListings => 'Объявления';

  @override
  String get sectionOrders => 'Заказы';

  @override
  String get browseListings => 'Просмотр объявлений';

  @override
  String get myOrders => 'Мои заказы';

  @override
  String get myListings => 'Мои объявления';

  @override
  String get incomingOrders => 'Входящие заказы';

  @override
  String get newListing => 'Новое объявление';

  @override
  String get statTotal => 'Всего';

  @override
  String get statActive => 'Активные';

  @override
  String get statSoldOut => 'Распроданы';

  @override
  String get statInactive => 'Неактивные';

  @override
  String get statPending => 'В ожидании';

  @override
  String get statInProgress => 'В процессе';

  @override
  String get statDelivered => 'Доставлены';

  @override
  String get statCancelled => 'Отменены';

  @override
  String get listingsTitle => 'Объявления';

  @override
  String get noListingsMatchFilters => 'Нет объявлений по этим фильтрам';

  @override
  String get searchListingsHint => 'Поиск по названию или описанию';

  @override
  String get kgAvailableSuffix => 'кг в наличии';

  @override
  String get perKgSuffix => '/ кг';

  @override
  String get listingFieldTitle => 'Название';

  @override
  String get listingFieldMeatType => 'Тип мяса';

  @override
  String get listingFieldStatus => 'Статус';

  @override
  String get listingFieldPricePerKg => 'Цена / кг';

  @override
  String get listingFieldQuantity => 'Количество (кг)';

  @override
  String get listingFieldAvailable => 'Доступно';

  @override
  String get listingFieldLocation => 'Местоположение';

  @override
  String get listingFieldAvailableFrom => 'Доступно с';

  @override
  String get listingFieldDescription => 'Описание';

  @override
  String get listingFieldDescriptionOptional => 'Описание (необязательно)';

  @override
  String get listingPickAvailableFrom => 'Выберите дату доступности';

  @override
  String get listingMinTitleChars => 'Минимум 3 символа';

  @override
  String get validateGtZero => '> 0 обязательно';

  @override
  String get validateRequired => 'Обязательно';

  @override
  String get createListingButton => 'Создать объявление';

  @override
  String get listingDetailTitle => 'Объявление';

  @override
  String get listingActionPlaceOrder => 'Сделать заказ';

  @override
  String get listingActionEdit => 'Изменить';

  @override
  String get listingActionDeactivate => 'Деактивировать';

  @override
  String get listingActionSave => 'Сохранить';

  @override
  String get listingStatusActive => 'Активно';

  @override
  String get listingStatusSoldOut => 'Распродано';

  @override
  String get listingStatusInactive => 'Неактивно';

  @override
  String get meatBeef => 'Говядина';

  @override
  String get meatMutton => 'Баранина';

  @override
  String get meatChicken => 'Курятина';

  @override
  String get meatGoat => 'Козлятина';

  @override
  String get meatHorse => 'Конина';

  @override
  String get meatOther => 'Другое';

  @override
  String get myOrdersTitle => 'Мои заказы';

  @override
  String get incomingOrdersTitle => 'Входящие заказы';

  @override
  String get noOrdersYet => 'Заказов пока нет';

  @override
  String get filterAll => 'Все';

  @override
  String orderDetailTitle(int id) {
    return 'Заказ №$id';
  }

  @override
  String orderFromLabel(String email) {
    return 'От: $email';
  }

  @override
  String orderToLabel(String email) {
    return 'Кому: $email';
  }

  @override
  String get orderFieldDeliveryAddress => 'Адрес доставки';

  @override
  String get orderFieldNotes => 'Заметки';

  @override
  String get orderFieldNotesOptional => 'Заметки (необязательно)';

  @override
  String orderPlaceTitle(String title) {
    return 'Сделать заказ — $title';
  }

  @override
  String orderAvailabilityHint(String qty, String price) {
    return 'Доступно: $qty кг по $price / кг';
  }

  @override
  String get orderQtyAddrRequired => 'Количество и адрес доставки обязательны';

  @override
  String orderOnlyKgAvailable(String qty) {
    return 'Доступно только $qty кг';
  }

  @override
  String get orderConfirmButton => 'Подтвердить заказ';

  @override
  String get orderPlacedSnack => 'Заказ оформлен';

  @override
  String get orderCancelButton => 'Отменить заказ';

  @override
  String get orderCancelTitle => 'Отменить заказ?';

  @override
  String get orderCancelBody =>
      'Количество вернётся в объявление. Это действие нельзя отменить.';

  @override
  String get no => 'Нет';

  @override
  String get orderActionConfirm => 'Подтвердить';

  @override
  String get orderActionStartProcessing => 'Начать обработку';

  @override
  String get orderActionMarkInTransit => 'Отметить в пути';

  @override
  String get orderActionMarkDelivered => 'Отметить доставленным';

  @override
  String get orderActionCancel => 'Отменить';

  @override
  String orderTerminalNoActions(String status) {
    return 'Дальнейших действий нет — заказ $status';
  }

  @override
  String get orderStatusPending => 'В ожидании';

  @override
  String get orderStatusConfirmed => 'Подтверждён';

  @override
  String get orderStatusProcessing => 'В обработке';

  @override
  String get orderStatusInTransit => 'В пути';

  @override
  String get orderStatusDelivered => 'Доставлен';

  @override
  String get orderStatusCancelled => 'Отменён';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get buyerProfileTitle => 'Профиль покупателя';

  @override
  String get supplierProfileTitle => 'Профиль поставщика';

  @override
  String get profileFieldBusinessName => 'Название компании';

  @override
  String get profileFieldRegion => 'Регион';

  @override
  String get profileFieldAddress => 'Адрес';

  @override
  String get profileVerified => 'Подтверждён';

  @override
  String get profileUnverified => 'Не подтверждён';

  @override
  String get profileSavedSnack => 'Сохранено';

  @override
  String get profileAdminViaDjango =>
      'Профиль администратора редактируется через Django Admin';

  @override
  String failedPrefix(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get viewAll => 'Все';

  @override
  String get sectionFarmers => 'Фермеры';

  @override
  String get sectionButchers => 'Мясники';
}
