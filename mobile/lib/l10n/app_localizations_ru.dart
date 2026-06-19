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

  @override
  String get appLanguage => 'Язык приложения';

  @override
  String appVersionLabel(String version) {
    return 'Версия приложения $version';
  }

  @override
  String get privacyPolicyLink => 'политику конфиденциальности';

  @override
  String get termsOfUseLink => 'условия использования';

  @override
  String privacyTagline(String policy, String terms) {
    return 'Нажимая, вы принимаете $policy и $terms.';
  }

  @override
  String get anonWelcomeTitle => 'Добро пожаловать в Мясной рынок';

  @override
  String get anonWelcomeSubtitle =>
      'Просматривайте объявления — регистрация потребуется при оформлении заказа.';

  @override
  String get onbLocationTitle => 'Ваш регион';

  @override
  String get onbLocationBody =>
      'Мы используем ваше местоположение, чтобы показать ближайших продавцов мяса. Это необязательно — можно изменить позже в Профиле.';

  @override
  String get onbDetectLocation => 'Определить местоположение';

  @override
  String get onbNotNow => 'Не сейчас';

  @override
  String get pickLanguageTitle => 'Выберите язык';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get savedListingsTitle => 'Избранные объявления';

  @override
  String get noSavedListingsYet => 'Пока нет сохранённых объявлений';

  @override
  String get messageHint => 'Сообщение…';

  @override
  String get noConversationsYet => 'Пока нет переписок';

  @override
  String get noNotificationsYet => 'Пока нет уведомлений';

  @override
  String get leaveReviewTitle => 'Оставить отзыв';

  @override
  String get reviewCommentOptional => 'Комментарий (необязательно)';

  @override
  String get serviceAreaHint => 'Ташкент, Самарканд, ...';

  @override
  String get tabMenu => 'Меню';

  @override
  String get tabCart => 'Корзина';

  @override
  String get tabOrders => 'Заказы';

  @override
  String get cartTitle => 'Корзина';

  @override
  String cartItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count товара',
      one: '1 товар',
      zero: '0 товаров',
    );
    return '$_temp0';
  }

  @override
  String get cartEmptyTitle => 'Корзина пуста';

  @override
  String get cartEmptyHint => 'Перейдите в Меню и добавьте любой товар.';

  @override
  String get cartGoToMenu => 'Перейти в меню';

  @override
  String get cartShopNoteLabel => 'Заметка магазину';

  @override
  String get cartShopNoteHint =>
      'Например: нарезать по 1 кг, без костей, доставить вечером';

  @override
  String get cartSubTotal => 'Подытог';

  @override
  String get cartTotal => 'ИТОГО';

  @override
  String get cartCheckout => 'Оформить заказ';

  @override
  String get cartCheckoutSnack =>
      'Заказ оформлен — подключение к серверу скоро.';

  @override
  String get soumSuffix => 'сум';

  @override
  String get perKgShort => '/кг';

  @override
  String get cartAdd => 'Добавить';

  @override
  String get cartPeekTitle => 'Ваша корзина';

  @override
  String get cartPeekChip => 'Показать';

  @override
  String get cartPeekViewAll => 'Добавить ещё';

  @override
  String cartItemsShort(int count) {
    return '$count шт';
  }

  @override
  String get cartFloatingPeek => 'Нажмите для просмотра';

  @override
  String get menuTitle => 'Меню';

  @override
  String get menuPickHint => 'Что будете готовить сегодня?';

  @override
  String get homeSearchHint => 'Поиск продуктов...';

  @override
  String get homeRegionPickerTitle => 'Выберите регион';

  @override
  String get homeRegionAll => 'Все регионы';

  @override
  String get addressesTitle => 'Адреса';

  @override
  String get addressesEmpty => 'Пока нет сохранённых адресов.';

  @override
  String get addressesNewCta => 'Новый адрес';

  @override
  String get addressesSignInCta => 'Войдите, чтобы сохранять адреса';

  @override
  String get addressFormTitleNew => 'Новый адрес';

  @override
  String get addressFormTitleEdit => 'Детали адреса';

  @override
  String get addressFieldLabel => 'Название адреса';

  @override
  String get addressFieldLabelHint => 'Дом, Офис, Ресторан...';

  @override
  String get addressFieldStreet => 'Адрес';

  @override
  String get addressFieldStreetHint => 'Улица, район, номер дома';

  @override
  String get addressFieldEntrance => 'Подъезд';

  @override
  String get addressFieldFloor => 'Этаж';

  @override
  String get addressFieldApartment => 'Квартира';

  @override
  String get addressFieldNotes => 'Подробности места доставки';

  @override
  String get addressFieldNotesHelp => 'Поможет курьеру быстрее найти вас';

  @override
  String get addressFieldDefault => 'Сделать основным адресом';

  @override
  String get addressSaveCta => 'Сохранить адрес';

  @override
  String get addressDeleteCta => 'Удалить';

  @override
  String get addressDeleteConfirm => 'Удалить этот адрес?';

  @override
  String get addressMapTitle => 'Выберите адрес на карте';

  @override
  String get addressMapConfirmTitle => 'Всё верно?';

  @override
  String get addressMapConfirmBody =>
      'Убедитесь, что метка стоит у входа, и подтвердите адрес';

  @override
  String get addressMapConfirmCta => 'Уточнить номер дома';

  @override
  String get addressMapMyLocation => 'Моё местоположение';

  @override
  String get phoneAuthTitle => 'Ваш номер телефона';

  @override
  String get phoneAuthSubtitle =>
      'Введите номер, чтобы войти или зарегистрироваться';

  @override
  String get phoneAuthHint => '90 123-45-67';

  @override
  String get phoneAuthContinue => 'Продолжить';

  @override
  String get phoneAuthInvalid => 'Введите 9-значный номер телефона';

  @override
  String get phoneDetailsTitle => 'О вас';

  @override
  String get phoneDetailsSubtitle => 'Имя нужно для оформления заказов';

  @override
  String get phoneDetailsNameLabel => 'Ваше имя';

  @override
  String get phoneDetailsBusinessLabel => 'Название компании (необязательно)';

  @override
  String get phoneDetailsCta => 'Войти';

  @override
  String get profileSettingsTitle => 'Настройки профиля';

  @override
  String get profileTapToEdit => 'Редактировать';

  @override
  String get profileFieldLastName => 'Фамилия';

  @override
  String get profileFieldFirstName => 'Имя';

  @override
  String get profileFieldPatronymic => 'Отчество';

  @override
  String get profileFieldPatronymicHint => 'Введите отчество';

  @override
  String get profileFieldDateOfBirth => 'Дата рождения';

  @override
  String get profileFieldDateOfBirthHint => 'Выберите дату';

  @override
  String get profileFieldGender => 'Пол';

  @override
  String get genderMale => 'Мужской';

  @override
  String get genderFemale => 'Женский';

  @override
  String get profileFieldPhone => 'Номер телефона';

  @override
  String get profileMyCards => 'Мои карты';

  @override
  String get profileCardsEmpty => 'Пока нет карт';

  @override
  String get profileContactUs => 'Связаться с нами';

  @override
  String get profileTelegramOpenFailed => 'Не удалось открыть Telegram';

  @override
  String get cancel => 'Отмена';

  @override
  String get adminEnterCta => 'Войти как админ';

  @override
  String get adminEnterPasswordTitle => 'Пароль администратора';

  @override
  String get adminEnterPasswordHint => 'Введите пароль';

  @override
  String get adminEnterPasswordWrong => 'Неверный пароль';

  @override
  String get adminTitle => 'Админ';

  @override
  String get adminTabNewListing => 'Новое объявление';

  @override
  String get adminTabManage => 'Управление';

  @override
  String get adminNewListingPickSupplier => 'Выберите поставщика';

  @override
  String get adminNewListingSubmit => 'Сохранить объявление';

  @override
  String get adminManageListings => 'Объявления';

  @override
  String get adminManageSuppliers => 'Поставщики';

  @override
  String get adminManageCategories => 'Категории';

  @override
  String get adminManageMarkets => 'Базары';

  @override
  String get adminManageHint => 'Создание/редактирование в выбранном разделе';

  @override
  String get adminComingSoon => 'Скоро будет';

  @override
  String get adminListingCreated => 'Объявление создано';

  @override
  String get adminPermissionDenied =>
      'Требуются права администратора — войдите под учётной записью администратора';

  @override
  String get adminNewListingPhotos => 'Фото';

  @override
  String get adminPickFromGallery => 'Выбрать из галереи';

  @override
  String get adminPickFromCamera => 'Сделать фото';

  @override
  String get adminMarketDetailListings => 'Объявления этого базара';

  @override
  String get adminMarketEditCta => 'Редактировать';

  @override
  String get adminMarketDeleteCta => 'Удалить базар';

  @override
  String get adminMarketPhoneLabel => 'Номер телефона';

  @override
  String get adminMarketEmpty => 'Объявлений пока нет';

  @override
  String get adminListingEditTitle => 'Редактировать объявление';

  @override
  String get adminListingSavedToast => 'Сохранено';

  @override
  String get adminListingDeleteCta => 'Удалить объявление';

  @override
  String get statusActive => 'Активно';

  @override
  String get statusSoldOut => 'Распродано';

  @override
  String get statusInactive => 'Неактивно';

  @override
  String get addressAutoDetectedHint =>
      'Определённое местоположение · нажмите, чтобы уточнить';

  @override
  String get otpTitle => 'Код подтверждения';

  @override
  String otpSentTo(String phone) {
    return 'Код отправлен на $phone';
  }

  @override
  String get otpResend => 'Отправить код повторно';

  @override
  String otpResendIn(int seconds) {
    return 'Повторно через $secondsс';
  }

  @override
  String get otpInvalidCode => 'Неверный код';

  @override
  String get otpExpired => 'Срок действия кода истёк — отправьте новый';

  @override
  String get qtyEditorTitle => 'Количество (кг)';

  @override
  String get qtyEditorEnterAmount => 'Введите количество';

  @override
  String get qtyEditorOnlyDigits => 'Только цифры';

  @override
  String get qtyEditorMustBePositive => 'Больше нуля';

  @override
  String qtyEditorMaxExceeded(int max) {
    return 'Максимум: $max кг';
  }

  @override
  String qtyEditorAvailable(int max) {
    return 'Доступно: $max кг';
  }

  @override
  String get qtyEditorMax => 'Всё';

  @override
  String get qtyEditorConfirm => 'Подтвердить';

  @override
  String get payTitle => 'Оплата';

  @override
  String get payProcessing => 'Обработка платежа…';

  @override
  String get payCheckingStatus => 'Проверка статуса…';

  @override
  String get paySuccessTitle => 'Оплата прошла успешно';

  @override
  String get paySuccessBody => 'Заказ принят';

  @override
  String get payFailedTitle => 'Оплата не прошла';

  @override
  String get payRetry => 'Попробовать снова';

  @override
  String get payToOrders => 'К заказам';

  @override
  String get payCancel => 'Отмена';

  @override
  String qtyEditorBelowMinimum(int min) {
    return 'Минимум: $min';
  }

  @override
  String get liveAnimalBadgeByHead => '1 ГОЛОВА';

  @override
  String get liveAnimalBadgeByWeight => 'ЖИВОЙ ВЕС';

  @override
  String get deliveryTitle => 'Доставка';

  @override
  String get deliveryAddressSection => 'Адрес';

  @override
  String get deliveryAddressChange => 'Изменить';

  @override
  String deliveryDistanceLabel(String km) {
    return 'Расстояние: $km км';
  }

  @override
  String get deliveryVehicleSection => 'Тип транспорта';

  @override
  String get deliveryVehicleRefrigerator => 'Рефрижератор';

  @override
  String get deliveryVehicleRefrigeratorHint => 'Холодовая цепь • 0°C до +4°C';

  @override
  String get deliveryVehicleChorvaTaxi => 'Чорва-Такси';

  @override
  String get deliveryVehicleChorvaTaxiHint =>
      'Специальный транспорт для живого скота';

  @override
  String get deliveryVehicleUnavailable => 'Недоступно';

  @override
  String get deliveryTimeSlotSection => 'Время доставки';

  @override
  String get deliveryTimeSlot0609 => '06:00 – 09:00';

  @override
  String get deliveryTimeSlot0913 => '09:00 – 13:00';

  @override
  String get deliveryTimeSlot1318 => '13:00 – 18:00';

  @override
  String get deliveryButcherSection => 'Услуга мясника';

  @override
  String get deliveryButcherTitle => 'Нужен забой и разделка живого скота?';

  @override
  String get deliveryButcherSubtitle =>
      'Профессиональная услуга мясника: забой, разделка и упаковка.';

  @override
  String deliveryButcherFeeLabel(String fee) {
    return 'Стоимость услуги: $fee';
  }

  @override
  String get deliveryButcherAccept => 'Добавить услугу мясника';

  @override
  String get deliveryBreakdownSection => 'Расчёт';

  @override
  String get deliveryBreakdownProducts => 'Товары';

  @override
  String get deliveryBreakdownDelivery => 'Доставка';

  @override
  String get deliveryBreakdownButcher => 'Услуга мясника';

  @override
  String get deliveryBreakdownTotal => 'ИТОГО';

  @override
  String get deliveryProceedCta => 'К оплате';

  @override
  String get deliveryNeedAddress => 'Сначала укажите адрес';

  @override
  String get deliveryLoadingQuote => 'Загрузка расчёта…';

  @override
  String get deliveryQuoteError =>
      'Не удалось получить расчёт. Попробуйте снова.';

  @override
  String get deliveryPickMapHint => 'Выбрать адрес на карте';

  @override
  String get deliveryFloorMin => 'Минимальный заказ — 10 кг (оптовые условия).';

  @override
  String get deliveryTashkentOnlyBanner =>
      'Пока доставляем только в пределах Ташкента. Расчёт от центра города.';

  @override
  String get deliveryTashkentOnlyShort => 'Пока только в Ташкенте';

  @override
  String get testUseYunusobod =>
      'ТЕСТ: установить локацию в Юнусабаде (Ташкент)';

  @override
  String get testYunusobodApplied => 'Локация установлена на Юнусабад';

  @override
  String get cardsTitle => 'Мои карты';

  @override
  String get cardsAddTitle => 'Добавить карту';

  @override
  String get cardsAddCta => 'Добавить карту';

  @override
  String get cardsAddError => 'Не удалось добавить карту. Попробуйте снова.';

  @override
  String get cardsPan => 'Номер карты';

  @override
  String get cardsExpiry => 'Срок действия';

  @override
  String get cardsHolder => 'Имя владельца';

  @override
  String get cardsPhone => 'Телефон для SMS';

  @override
  String get cardsMakeDefault => 'Сделать основной картой';

  @override
  String get cardsPciNote =>
      'Данные карты передаются по защищённому каналу. Полный номер карты не сохраняется.';

  @override
  String get cardsEmptyTitle => 'Карт ещё нет';

  @override
  String get cardsEmptyHint => 'Добавьте карту для оплаты заказов.';

  @override
  String get cardsLoadError => 'Не удалось загрузить карты.';

  @override
  String get cardsDefaultBadge => 'ОСНОВНАЯ';

  @override
  String get cardsExpiredLabel => 'Карта истекла';

  @override
  String get cardsActionMakeDefault => 'Сделать основной';

  @override
  String get cardsActionDelete => 'Удалить';

  @override
  String get cardsDeletedSnack => 'Карта удалена';

  @override
  String get paymentAmountLabel => 'Сумма платежа';

  @override
  String get paymentMethodSection => 'Способ оплаты';

  @override
  String paymentPayCta(String amount) {
    return 'Оплатить · $amount';
  }

  @override
  String get paymentPayCtaShort => 'Оплатить';

  @override
  String paymentSuccessCardLine(String brand, String last4) {
    return 'Оплачено картой $brand •••• $last4';
  }

  @override
  String get authServerUnavailable =>
      'Сервер временно недоступен. Попробуйте через минуту.';

  @override
  String get authNetworkError =>
      'Нет подключения к интернету. Проверьте соединение и попробуйте снова.';

  @override
  String get authNetworkTimeout => 'Время ожидания истекло. Попробуйте снова.';

  @override
  String get authUnexpectedError =>
      'Произошла непредвиденная ошибка. Попробуйте позже.';
}
