// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'AI Чат';

  @override
  String get signIn => 'Войти';

  @override
  String get signUp => 'Зарегистрироваться';

  @override
  String get registration => 'Регистрация';

  @override
  String get signInToAccount => 'Войдите в свой аккаунт';

  @override
  String get createNewAccount => 'Создайте новый аккаунт';

  @override
  String get signInWithGoogle => 'Войти через Google';

  @override
  String get signInWithApple => 'Войти через Apple';

  @override
  String get signInWithMagicLink => 'Войти с email';

  @override
  String get checkYourEmail => 'Проверьте почту';

  @override
  String get magicLinkSent => 'Мы отправили вам ссылку для входа';

  @override
  String get magicLinkDescription => 'Перейдите по ссылке в письме для входа';

  @override
  String get continueWithEmail => 'Продолжить с email';

  @override
  String get enterYourEmail => 'Введите ваш email';

  @override
  String get magicLinkSentToEmail =>
      'Мы отправили ссылку для входа на ваш email';

  @override
  String get clickLinkToSignIn =>
      'Перейдите по ссылке в письме для входа в аккаунт';

  @override
  String get cantFindEmail => 'Не нашли письмо?';

  @override
  String get checkSpamFolder =>
      'Проверьте папку \"Спам\" или \"Нежелательные\"';

  @override
  String get resendEmail => 'Отправить повторно';

  @override
  String resendEmailIn(int seconds) {
    return 'Повторная отправка через $seconds сек';
  }

  @override
  String get or => 'или';

  @override
  String get email => 'Email';

  @override
  String get password => 'Пароль';

  @override
  String get confirmPassword => 'Подтвердите пароль';

  @override
  String get fillAllFields => 'Заполните все поля';

  @override
  String get enterValidEmail => 'Введите корректный email';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get noAccount => 'Нет аккаунта? ';

  @override
  String get haveAccount => 'Уже есть аккаунт? ';

  @override
  String get home => 'Главная';

  @override
  String get search => 'Поиск';

  @override
  String get chats => 'Создать';

  @override
  String get profile => 'Профиль';

  @override
  String get news => 'Лента';

  @override
  String get all => 'Все';

  @override
  String get technology => 'Технологии';

  @override
  String get ai => 'ИИ';

  @override
  String get science => 'Наука';

  @override
  String get space => 'Космос';

  @override
  String get ecology => 'Экология';

  @override
  String minutesAgo(int minutes) {
    return '$minutes мин назад';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours ч назад';
  }

  @override
  String daysAgo(int days) {
    return '$days дн назад';
  }

  @override
  String get products => 'Продукты';

  @override
  String get techCrunch => 'TechCrunch';

  @override
  String get appleNews => 'Apple News';

  @override
  String get scienceToday => 'Science Today';

  @override
  String get aiWeekly => 'AI Weekly';

  @override
  String get ecoNews => 'EcoNews';

  @override
  String get spaceExplorer => 'Space Explorer';

  @override
  String get searchPage => 'Поиск';

  @override
  String get chatsPage => 'Создать';

  @override
  String get settings => 'Настройки';

  @override
  String get appIcon => 'Иконка приложения';

  @override
  String get darkIcon => 'Темная';

  @override
  String get lightIcon => 'Светлая';

  @override
  String get language => 'Язык';

  @override
  String get theme => 'Тема';

  @override
  String get darkMode => 'Темная тема';

  @override
  String get lightMode => 'Светлая тема';

  @override
  String get zenMode => 'Режим концентрации';

  @override
  String get zenModeDescription => 'Скрыть счетчики непрочитанных';

  @override
  String get zenModeEnabled => 'Включен';

  @override
  String get zenModeDisabled => 'Выключен';

  @override
  String get zenModeEnabledDescription => 'Счетчики непрочитанных скрыты';

  @override
  String get zenModeDisabledDescription => 'Счетчики непрочитанных видны';

  @override
  String get zenModeInfo =>
      'Когда режим концентрации включен, все счетчики непрочитанных и значки будут скрыты во всем приложении. Это поможет вам сосредоточиться на контенте без отвлечения на уведомления.';

  @override
  String get viewSettings => 'Настройки вида';

  @override
  String get imagePreviews => 'Превью изображений';

  @override
  String get imagePreviewsDescription => 'Показывать превью в ленте новостей';

  @override
  String get imagePreviewsEnabled => 'Включено';

  @override
  String get imagePreviewsDisabled => 'Выключено';

  @override
  String get imagePreviewsEnabledDescription => 'Превью изображений видны';

  @override
  String get imagePreviewsDisabledDescription => 'Превью изображений скрыты';

  @override
  String get imagePreviewsInfo =>
      'Когда выключено, карточки новостей не будут показывать превью изображений и видео, делая ленту более компактной и текстовой.';

  @override
  String get defaultContent => 'Контент по умолчанию';

  @override
  String get defaultContentDescription => 'Выберите, что показывать первым';

  @override
  String get summaryFirstDescription => 'Краткая сводка показывается первой';

  @override
  String get fullTextFirstDescription => 'Полный текст показывается первым';

  @override
  String get defaultContentInfo =>
      'Эта настройка меняет порядок вкладок контента. Выберите, хотите ли вы видеть краткую сводку или полный текст первым при открытии новости.';

  @override
  String get logout => 'Выйти';

  @override
  String get logoutConfirm => 'Вы уверены, что хотите выйти?';

  @override
  String get cancel => 'Отмена';

  @override
  String get account => 'Аккаунт';

  @override
  String get deepseekChat => 'DeepSeek AI';

  @override
  String get aiAssistant => 'ИИ Ассистент';

  @override
  String get startConversation => 'Начните разговор с ИИ';

  @override
  String get typeMessage => 'Введите сообщение...';

  @override
  String get aiIsTyping => 'ИИ печатает...';

  @override
  String get feedTyping1 => 'Собираем ленту';

  @override
  String get feedTyping2 => 'Лента в пути';

  @override
  String get feedTyping3 => 'Готовим контент';

  @override
  String get feedTyping4 => 'Почти готово';

  @override
  String get feedTyping5 => 'Создаём магию';

  @override
  String get feedTyping6 => 'Секундочку';

  @override
  String get feedTyping7 => 'Готовимся';

  @override
  String get feedTyping8 => 'Уже скоро';

  @override
  String get feedTyping9 => 'Заваривается';

  @override
  String get feedTyping10 => 'Загружаем';

  @override
  String get feedSubtext1 => 'Подождите';

  @override
  String get feedSubtext2 => 'Ищем жемчужины';

  @override
  String get feedSubtext3 => 'Момент';

  @override
  String get feedSubtext4 => 'Персонализируем';

  @override
  String get feedSubtext5 => 'Почти там';

  @override
  String get feedSubtext6 => 'Сортируем';

  @override
  String get feedSubtext7 => 'Для вас';

  @override
  String get feedSubtext8 => 'Работаем';

  @override
  String get feedSubtext9 => 'Не уходите';

  @override
  String get feedSubtext10 => 'Финиш близко';

  @override
  String get sendMessage => 'Отправить сообщение';

  @override
  String get viewComment => 'Комментарий AI';

  @override
  String get viewOverview => 'Обзор';

  @override
  String get contactUs => 'Связаться с нами';

  @override
  String get emailCopied => 'Скопировано!';

  @override
  String get emailCopiedMessage => 'Email адрес скопирован в буфер обмена';

  @override
  String get feedManagement => 'Управление лентой';

  @override
  String get renameFeed => 'Переименовать';

  @override
  String get deleteFeed => 'Отписаться';

  @override
  String get confirmDeleteFeed =>
      'Вы уверены, что хотите отписаться от этой ленты?';

  @override
  String get confirmDeleteFeedMessage =>
      'Это действие нельзя отменить. Все посты из этой ленты будут удалены из вашей ленты.';

  @override
  String get delete => 'Удалить';

  @override
  String get rename => 'Переименовать';

  @override
  String get enterNewName => 'Введите новое название ленты';

  @override
  String get feedNameRequired => 'Название ленты обязательно';

  @override
  String get feedRenamed => 'Лента успешно переименована';

  @override
  String get feedDeleted => 'Отписка от ленты выполнена';

  @override
  String get errorRenamingFeed => 'Ошибка переименования ленты';

  @override
  String get errorDeletingFeed => 'Ошибка отписки от ленты';

  @override
  String get save => 'Сохранить';

  @override
  String get readAllPosts => 'Прочитать все';

  @override
  String postsMarkedAsRead(int count) {
    return 'Отмечено постов: $count';
  }

  @override
  String get errorMarkingPostsAsRead => 'Ошибка отметки постов';

  @override
  String sourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count источника',
      many: '$count источников',
      few: '$count источника',
      one: '$count источник',
      zero: 'Нет источников',
    );
    return '$_temp0';
  }

  @override
  String get noFeedsTitle => 'У вас пока нет лент';

  @override
  String get noFeedsSubtitle => 'Нажмите +, чтобы создать первую ленту';

  @override
  String get noFeedsDescription =>
      'Добавьте любимые источники и получайте персонализированный контент с помощью ИИ.';

  @override
  String get goToChat => 'Перейти к созданию';

  @override
  String get feedOnTheWay => 'Ваша лента уже в пути';

  @override
  String get feedLoadingDescription => 'Мы собираем для вас лучшие новости';

  @override
  String get feedGenerating => 'Генерируем ленту специально для вас';

  @override
  String get chat => 'Сессия';

  @override
  String get startAConversation => 'Начните создание';

  @override
  String get newChat => 'Новая сессия';

  @override
  String get deleteChat => 'Удалить';

  @override
  String get deleteSession => 'Удалить';

  @override
  String get confirmDeleteChat => 'Удалить сессию?';

  @override
  String get confirmDeleteChatMessage =>
      'Эта сессия и все её сообщения будут безвозвратно удалены.';

  @override
  String get chatDeleted => 'Сессия удалена';

  @override
  String get sessionDeleted => 'Сессия удалена';

  @override
  String get errorLoadingChats => 'Ошибка загрузки сессий';

  @override
  String get errorLoadingSessions => 'Ошибка загрузки сессий';

  @override
  String get tryAgain => 'Попробовать снова';

  @override
  String get errorCreatingChat => 'Ошибка создания сессии';

  @override
  String get errorCreatingSession => 'Ошибка создания сессии';

  @override
  String get errorDeletingChat => 'Ошибка удаления сессии';

  @override
  String get errorDeletingSession => 'Ошибка удаления сессии';

  @override
  String get yesterday => 'Вчера';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get resetPassword => 'Сброс пароля';

  @override
  String get enterEmailToReset =>
      'Введите ваш email, и мы отправим вам инструкции по восстановлению пароля.';

  @override
  String get send => 'Отправить';

  @override
  String get resetPasswordSuccess => 'Инструкции отправлены';

  @override
  String get resetPasswordSuccessMessage =>
      'Проверьте вашу почту для получения инструкций по восстановлению пароля.';

  @override
  String get success => 'Успешно';

  @override
  String get passwordChangedSuccessfully => 'Ваш пароль успешно изменен!';

  @override
  String get createNewPassword => 'Создайте новый пароль';

  @override
  String get enterNewPasswordBelow => 'Введите новый пароль ниже';

  @override
  String get newPassword => 'Новый пароль';

  @override
  String get passwordRequirements =>
      'Минимум 8 символов, включая заглавные, строчные буквы, цифры и спецсимволы';

  @override
  String get backToSignIn => 'Вернуться к входу';

  @override
  String get continueButton => 'Продолжить';

  @override
  String get retry => 'Повторить';

  @override
  String get error => 'Ошибка';

  @override
  String get sourcesModalTitle => 'Источники';

  @override
  String get feedback => 'Обратная связь';

  @override
  String get sendFeedback => 'Отправить отзыв';

  @override
  String get shareYourFeedback => 'Поделитесь мнением';

  @override
  String get shareYourThoughts => 'Поделитесь с нами вашими мыслями';

  @override
  String get feedbackSubtitle =>
      'Мы будем рады услышать ваши мысли, предложения или любые проблемы, с которыми вы столкнулись';

  @override
  String get feedbackPlaceholder => 'Идеи, баги, отзыв...';

  @override
  String get sendingFeedback => 'Отправка отзыва...';

  @override
  String get feedbackSent => 'Спасибо!';

  @override
  String get feedbackSentMessage =>
      'Ваш отзыв получен. Мы ценим, что вы нашли время, чтобы помочь нам стать лучше!';

  @override
  String get feedbackError => 'Ошибка отправки отзыва';

  @override
  String get feedbackEmpty => 'Пожалуйста, введите ваш отзыв';

  @override
  String characterLimit(int count, int max) {
    return '$count / $max символов';
  }

  @override
  String get closingAutomatically => 'Закрывается автоматически';

  @override
  String get appTakingBreak => 'Приложение отдыхает';

  @override
  String get appTakingBreakDescription =>
      'Мы скоро вернёмся. Попробуйте позже.';

  @override
  String get viewSettingsSubtitle => 'Настройте вашу ленту';

  @override
  String get viewSettingsPageSubtitle => 'Настройте внешний вид ленты';

  @override
  String get profileDetails => 'Детали профиля';

  @override
  String get deleteAccount => 'Удалить аккаунт';

  @override
  String get deleteAccountConfirmTitle => 'Удалить аккаунт?';

  @override
  String get deleteAccountConfirmMessage =>
      'Это действие удалит ваш аккаунт и все связанные с ним данные навсегда. Это действие нельзя отменить.';

  @override
  String get yes => 'Да';

  @override
  String get deleteAccountProcessing => 'Удаление аккаунта...';

  @override
  String get accountDeleted => 'Аккаунт удален';

  @override
  String get deleteAccountError => 'Ошибка удаления аккаунта';

  @override
  String pleaseWaitSeconds(int seconds) {
    return 'Подождите $seconds сек...';
  }

  @override
  String get dangerZone => 'Опасная зона';

  @override
  String get accountInfo => 'Информация об аккаунте';

  @override
  String agreeToTerms(String terms, String privacy) {
    return 'Продолжая, вы соглашаетесь с нашими $terms и $privacy';
  }

  @override
  String get termsOfService => 'Условиями использования';

  @override
  String get privacyPolicy => 'Политикой конфиденциальности';

  @override
  String get mustAgreeToTerms =>
      'Пожалуйста, согласитесь с Условиями и Политикой конфиденциальности для продолжения';

  @override
  String get agreeToTermsPrefix => 'Продолжая, вы соглашаетесь с нашими ';

  @override
  String get andText => ' и ';

  @override
  String get feedCreatorTitle => 'Создать ленту';

  @override
  String get promptLabel => 'Формат отображения';

  @override
  String get promptHint => 'Какой контент вы хотите?';

  @override
  String get sourcesLabel => 'Источники';

  @override
  String get sourcesHint => '@канал1, @канал2, https://...';

  @override
  String get feedTypeLabel => 'Тип ленты';

  @override
  String get singlePostType => 'Отдельные посты';

  @override
  String get singlePostTypeDescription => 'Каждый пост показывается отдельно';

  @override
  String get digestType => 'Сводка';

  @override
  String get digestTypeDescription => 'Посты объединяются в сводку';

  @override
  String get createFeedButton => 'Создать';

  @override
  String get creatingFeed => 'Создаём вашу ленту...';

  @override
  String get creatingDigest => 'Создаём вашу сводку...';

  @override
  String get feedItemCreating => 'Создаётся...';

  @override
  String get waitingForFirstPost => 'Ожидание первого поста';

  @override
  String get timeout => 'Тайм-аут';

  @override
  String get promptRequired => 'Пожалуйста, введите промпт';

  @override
  String get sourcesRequired => 'Пожалуйста, введите хотя бы один источник';

  @override
  String get digestDuration => 'Продолжительность';

  @override
  String digestMinutes(int count) {
    return '$count мин';
  }

  @override
  String digestHours(int count) {
    return '$count ч';
  }

  @override
  String get presets => 'Типовые';

  @override
  String get reset => 'Сбросить';

  @override
  String get feedTitle => 'Название';

  @override
  String get feedTitlePlaceholder => 'Дайте название ленте';

  @override
  String get feedDescription => 'Описание';

  @override
  String get feedDescriptionPlaceholder => 'Опишите, о чём эта лента';

  @override
  String get feedFilters => 'Фильтры контента';

  @override
  String get filterDuplicates => 'Удалять дубликаты';

  @override
  String get filterAds => 'Фильтровать рекламу';

  @override
  String get filterSpam => 'Убирать спам';

  @override
  String get filterClickbait => 'Без кликбейта';

  @override
  String get feedTags => 'Теги';

  @override
  String get feedTagsPlaceholder => 'Добавьте теги (до 4)';

  @override
  String get feedTagsLimitError => 'Максимум 4 тега';

  @override
  String get feedNotReady => 'Лента ещё не готова к созданию';

  @override
  String get feedCreatedSuccess => 'Лента успешно создана!';

  @override
  String get digestsTab => 'Сводки';

  @override
  String get feedsTab => 'Ленты';

  @override
  String get noDigestsTitle => 'Пока нет сводок';

  @override
  String get noDigestsHint =>
      'Создайте сводку, чтобы объединить несколько источников';

  @override
  String get noRegularFeedsHint =>
      'Создайте ленту, чтобы получать отдельные посты из любимых источников';

  @override
  String get linkTelegram => 'Привязать Telegram';

  @override
  String get telegramLinked => 'Telegram привязан';

  @override
  String get linkTelegramSubtitle => 'Получайте уведомления в Telegram';

  @override
  String get linkTelegramLoading => 'Подключение...';

  @override
  String get linkTelegramError =>
      'Не удалось получить ссылку. Попробуйте ещё раз.';

  @override
  String get summarizeUnseenTitle => 'Собрать непрочитанное?';

  @override
  String summarizeUnseenMessage(int count, String feedName) {
    return 'Создать AI-сводку из $count непрочитанных постов в «$feedName». Они будут отмечены как прочитанные.';
  }

  @override
  String get summarizeUnseenConfirm => 'Создать сводку';

  @override
  String get summarizeUnseenCancel => 'Отмена';

  @override
  String summarizeUnseenOverLimit(int count, int limit) {
    return 'Слишком много непрочитанных постов ($count). Максимум для сводки — $limit. Прочитайте часть постов, чтобы создать сводку.';
  }

  @override
  String get summarizeStatusPreparing => 'Подготовка сводки...';

  @override
  String get summarizeStatusCollecting => 'Собираем посты...';

  @override
  String get summarizeStatusGenerating => 'Генерация сводки...';

  @override
  String get summarizeStatusReady => 'Сводка готова!';

  @override
  String get summarizeStatusFailed => 'Не удалось создать сводку';

  @override
  String get noMorePosts => 'Больше нет постов';

  @override
  String get offlineMode => 'Офлайн - показаны сохраненные данные';

  @override
  String get noPostsYet => 'Пока нет постов';

  @override
  String get noPostsYetDescription =>
      'Посты появятся здесь, когда будут сгенерированы для этой ленты.';

  @override
  String get onboardingStep1Title => 'Ленты';

  @override
  String get onboardingStep1Description =>
      'Здесь живут ваши ленты, отдельная вкладка для обычных лент и сводок.';

  @override
  String get onboardingStep2Title => 'Создание ленты';

  @override
  String get onboardingStep2Description =>
      'Соберите свою персональную ленту. Ваш контент — ваши правила.';

  @override
  String get onboardingStep3Title => 'Редактирование ленты';

  @override
  String get onboardingStep3Description =>
      'Здесь можно в любой момент донастроить ваши ленты.';

  @override
  String get onboardingStep4Title => 'Настройки';

  @override
  String get onboardingStep4Description =>
      'Профиль, тема, настройки приложения и всё остальное — здесь.';

  @override
  String get onboardingSkip => 'Пропустить';

  @override
  String get onboardingNext => 'Далее';

  @override
  String get onboardingFinish => 'Понятно!';

  @override
  String get authErrorInvalidCredentials => 'Неверный email или пароль';

  @override
  String get authErrorEmailNotConfirmed => 'Подтвердите email перед входом';

  @override
  String get authErrorInvalidLoginData => 'Неверные данные для входа';

  @override
  String get authErrorInvalidEmailFormat => 'Неверный формат email';

  @override
  String get authErrorTooManyAttempts =>
      'Слишком много попыток. Попробуйте позже';

  @override
  String get authErrorSignInFailed => 'Ошибка входа';

  @override
  String get authErrorSignInError => 'Ошибка входа';

  @override
  String get authErrorEmailAlreadyRegistered => 'Email уже зарегистрирован';

  @override
  String get authErrorTooManySignUpAttempts =>
      'Слишком много попыток регистрации. Попробуйте позже';

  @override
  String get authErrorSignUpFailed => 'Ошибка регистрации';

  @override
  String get authErrorSignUpError => 'Ошибка регистрации';

  @override
  String get authErrorPasswordTooShort =>
      'Пароль должен содержать минимум 8 символов';

  @override
  String get authErrorPasswordNeedsUppercase =>
      'Пароль должен содержать заглавные буквы';

  @override
  String get authErrorPasswordNeedsLowercase =>
      'Пароль должен содержать строчные буквы';

  @override
  String get authErrorPasswordNeedsNumbers => 'Пароль должен содержать цифры';

  @override
  String get authErrorPasswordNeedsSpecialChars =>
      'Пароль должен содержать специальные символы';

  @override
  String get authErrorGoogleCancelled => 'Вход через Google отменен';

  @override
  String get authErrorGoogleFailed => 'Не удалось войти через Google';

  @override
  String get authErrorGoogleNoIdToken =>
      'Не удалось получить ID токен от Google';

  @override
  String get authErrorGoogleError => 'Ошибка входа через Google';

  @override
  String get authErrorAppleCancelled => 'Вход через Apple отменен';

  @override
  String get authErrorAppleError => 'Ошибка входа через Apple';

  @override
  String get authErrorOAuthCancelled => 'Вход отменен';

  @override
  String get authErrorOAuthError => 'Ошибка OAuth авторизации';

  @override
  String get authErrorOAuthTimeout => 'Превышено время ожидания авторизации';

  @override
  String get authErrorSessionRefreshFailed => 'Не удалось обновить сессию';

  @override
  String get authErrorSessionRefreshError => 'Ошибка обновления сессии';

  @override
  String get authErrorPasswordResetFailed =>
      'Не удалось отправить сброс пароля';

  @override
  String get authErrorPasswordResetError => 'Ошибка сброса пароля';

  @override
  String get authErrorPasswordUpdateFailed => 'Не удалось изменить пароль';

  @override
  String get authErrorPasswordUpdateError => 'Ошибка изменения пароля';

  @override
  String get authErrorNoDataToUpdate => 'Нет данных для обновления';

  @override
  String get authErrorProfileUpdateFailed => 'Не удалось обновить профиль';

  @override
  String get authErrorProfileUpdateError => 'Ошибка обновления профиля';

  @override
  String get authErrorNotAuthenticated => 'Пользователь не авторизован';

  @override
  String get authErrorAccountDeleteFailed => 'Не удалось удалить аккаунт';

  @override
  String get authErrorAccountDeleteError => 'Ошибка удаления аккаунта';

  @override
  String get authErrorMagicLinkSendError =>
      'Не удалось отправить ссылку для входа';

  @override
  String get authErrorMagicLinkError => 'Ошибка отправки ссылки';

  @override
  String get authErrorDemoLoginMissingToken =>
      'Ошибка сервера: отсутствует токен';

  @override
  String get authErrorDemoLoginFailed => 'Ошибка демо-входа';

  @override
  String get authErrorDemoLoginConnectionError =>
      'Ошибка подключения к серверу';

  @override
  String get authErrorUserNotFound => 'Пользователь не найден';

  @override
  String get authErrorEmailConfirmationError =>
      'Не удалось отправить подтверждение';

  @override
  String get authErrorNetworkError => 'Ошибка сети. Проверьте подключение';

  @override
  String get authErrorUnknownError => 'Произошла непредвиденная ошибка';

  @override
  String get authMessageCheckEmailForConfirmation =>
      'Проверьте email для подтверждения регистрации';

  @override
  String get authMessagePasswordResetSent =>
      'Инструкции по сбросу пароля отправлены на email';

  @override
  String get authMessagePasswordChanged => 'Пароль успешно изменен';

  @override
  String get authMessageAccountDeleted => 'Аккаунт удален';

  @override
  String get authMessageCheckEmailForLink =>
      'Проверьте почту для входа. Письмо придет в течение минуты.';

  @override
  String get authMessageConfirmationEmailSent =>
      'Письмо с подтверждением отправлено';

  @override
  String get slideFeedTypeTitle => 'Какую ленту создать?';

  @override
  String get slideFeedTypeSubtitle => 'Выберите формат отображения постов';

  @override
  String get slideFeedTypeIndividualPosts => 'Отдельные\nпосты';

  @override
  String get slideFeedTypeIndividualPostsDesc => 'Каждый пост отдельно';

  @override
  String get slideFeedTypeDigest => 'Сводка';

  @override
  String get slideFeedTypeDigestDesc => 'Объединяем в сводку';

  @override
  String get slideContentTitle => 'Откуда брать контент?';

  @override
  String get slideContentSubtitle => 'Блоги, Telegram каналы и RSS';

  @override
  String get slideContentSourceHint => '@channel или https://...';

  @override
  String get slideContentPopular => 'Популярные:';

  @override
  String get slideConfigTitle => 'Настройка контента';

  @override
  String get slideConfigSubtitle => 'Как обрабатывать и что фильтровать';

  @override
  String get slideConfigProcessingStyle => 'Стиль обработки';

  @override
  String get slideConfigProcessingHint => 'Как AI будет обрабатывать новости';

  @override
  String get slideConfigCustomStyle => 'Свой стиль...';

  @override
  String get slideConfigFilters => 'Фильтры';

  @override
  String get slideConfigFiltersHint => 'Что убирать из ленты';

  @override
  String get slideConfigCustomFilter => 'Свой фильтр...';

  @override
  String get slideConfigAddCustom => 'Добавить свой';

  @override
  String get slideFinalizeTitle => 'Почти готово!';

  @override
  String get slideFinalizeSubtitle => 'Проверьте настройки ленты';

  @override
  String get slideFinalizeName => 'Название';

  @override
  String get slideFinalizeSummary => 'Сводка';

  @override
  String get slideFinalizeSave => 'Сохранить';

  @override
  String get slideFinalizeCreateFeed => 'Создать ленту';

  @override
  String get slideFinalizeNameHint => 'Придумайте название';

  @override
  String get slideFinalizeType => 'Тип';

  @override
  String get slideFinalizeIndividualPosts => 'Отдельные посты';

  @override
  String get slideFinalizeDigest => 'Сводка';

  @override
  String get slideFinalizeFrequency => 'Частота';

  @override
  String get slideFinalizeSources => 'Источники';

  @override
  String get slideFinalizeStyle => 'Стиль';

  @override
  String get slideFinalizeFilters => 'Фильтры';

  @override
  String get slideNext => 'Далее';

  @override
  String get slideDone => 'Готово';

  @override
  String get slideDigestFrequency => 'Частота сводки';

  @override
  String get slideDigestFrequencyHint => 'Как часто собирать новости';

  @override
  String get slideDigestEveryHour => 'Каждый час';

  @override
  String get slideDigestEvery3Hours => 'Каждые 3ч';

  @override
  String get slideDigestEvery6Hours => 'Каждые 6ч';

  @override
  String get slideDigestEvery12Hours => 'Каждые 12ч';

  @override
  String get slideDigestDaily => 'Раз в день';

  @override
  String get slideDigestEvery2Days => 'Раз в 2 дня';

  @override
  String get slideDigestCustom => 'Другое';

  @override
  String get slideDigestCancel => 'Отмена';

  @override
  String get slidePostsPreview => 'Так будут выглядеть посты';

  @override
  String get slideDailyDigest => 'Сводка за день';

  @override
  String get slidePostsCombined => '3 поста объединены';

  @override
  String get aiStyleBrief => 'Кратко';

  @override
  String get aiStyleEssence => 'Суть';

  @override
  String get aiStyleFull => 'Полно';

  @override
  String get aiStyleCustom => 'Свой';

  @override
  String get aiStyleBriefDesc => '2-3 строки, только главное';

  @override
  String get aiStyleEssenceDesc => 'Основные факты и контекст';

  @override
  String get aiStyleFullDesc => 'Полный текст с деталями';

  @override
  String get aiStyleCustomDesc => 'Опишите своими словами';

  @override
  String get aiStyleHowToDisplay => 'Как показывать?';

  @override
  String get aiStyleSwipeHint => 'Свайп для выбора стиля';

  @override
  String get aiStyleCustomStyle => 'Свой стиль';

  @override
  String get aiStyleCustomProcessingStyle => 'Свой стиль обработки';

  @override
  String get aiStyleSwipeRight => 'Свайп вправо';

  @override
  String get aiStyleCustomPlaceholder => 'Например: без воды, только факты';

  @override
  String get aiStyleChipNoAds => 'без рекламы';

  @override
  String get aiStyleChipNumbersOnly => 'только цифры';

  @override
  String get aiStyleChipCasual => 'неформально';

  @override
  String get aiStyleHowToProcess => 'Как обрабатывать?';

  @override
  String get aiStyleAiAdaptsHint => 'AI адаптирует текст под ваш стиль';

  @override
  String get aiStylePreview => 'Превью';

  @override
  String get aiStyleEnterAbove => 'Введите свой стиль выше...';

  @override
  String get aiStylePreviewTitle => 'Apple представила M4';

  @override
  String get aiStylePreviewBrief =>
      'Новый чип на 50% быстрее. Выходит в ноябре.';

  @override
  String get aiStylePreviewEssence =>
      'Новый чип M4 на 50% быстрее предшественника. Доступен с ноября в линейке MacBook Pro и iMac.';

  @override
  String get aiStylePreviewFull =>
      'Apple анонсировала новый процессор M4 на специальном мероприятии. Чип на 50% быстрее M3, улучшенный нейронный движок и поддержка 32 ГБ RAM. Выход запланирован на ноябрь в линейке MacBook Pro, iMac и Mac mini.';

  @override
  String get feedEditTitle => 'Редактирование';

  @override
  String get feedEditName => 'Название';

  @override
  String get feedEditNameHint => 'Название ленты';

  @override
  String get feedEditSources => 'Источники';

  @override
  String get feedEditSchedule => 'Расписание';

  @override
  String get feedEditFilters => 'Фильтры';

  @override
  String get feedEditFilterHint => 'Фильтр...';

  @override
  String get feedEditSave => 'Сохранить';

  @override
  String get feedEditFailedToLoad => 'Не удалось загрузить данные';

  @override
  String get feedEditSourceAlreadyAdded => 'Источник уже добавлен';

  @override
  String get feedEditNetworkError => 'Ошибка сети';

  @override
  String get feedEditNotFound => 'Не найден';

  @override
  String get feedEditError => 'Ошибка';

  @override
  String get feedEditFilterAlreadyExists => 'Такой фильтр уже добавлен';

  @override
  String get feedEditEnterName => 'Введите название';

  @override
  String get feedEditWaitForValidation => 'Дождитесь проверки источников';

  @override
  String get feedEditAddSource => 'Добавьте хотя бы один источник';

  @override
  String get feedEditFailedToSave => 'Не удалось сохранить';

  @override
  String get feedEditDeleteFeedTitle => 'Удалить ленту?';

  @override
  String feedEditDeleteFeedMessage(String name) {
    return 'Лента \"$name\" будет удалена безвозвратно.';
  }

  @override
  String get feedEditFailedToDelete => 'Не удалось удалить';

  @override
  String get feedEditEveryHour => 'Каждый час';

  @override
  String get feedEditEvery3Hours => 'Каждые 3 часа';

  @override
  String get feedEditEvery6Hours => 'Каждые 6 часов';

  @override
  String get feedEditEvery12Hours => 'Каждые 12 часов';

  @override
  String get feedEditOnceADay => 'Раз в день';

  @override
  String get formSelectFeedType => 'Выберите тип ленты';

  @override
  String get formAddSource => 'Добавьте хотя бы один источник';

  @override
  String get formWaitForValidation => 'Дождитесь проверки источников';

  @override
  String get formAddValidSource => 'Добавьте хотя бы один валидный источник';

  @override
  String get formCreateFailed =>
      'Не удалось создать ленту. Проверьте данные и попробуйте снова.';

  @override
  String get formAuthError => 'Ошибка авторизации. Войдите в аккаунт снова.';

  @override
  String get formLimitReached =>
      'Достигнут лимит. Пока доступно ограниченное количество.';

  @override
  String get formSomethingWentWrong => 'Что-то пошло не так. Попробуйте позже.';

  @override
  String get formServerError => 'Ошибка сервера. Попробуйте позже.';

  @override
  String get formCreateError => 'Не удалось создать ленту. Попробуйте позже.';

  @override
  String get formNetworkError =>
      'Ошибка сети. Проверьте подключение к интернету.';

  @override
  String get formUnexpectedError => 'Что-то пошло не так. Попробуйте позже.';

  @override
  String get previewFilterMode => 'Фильтрация';

  @override
  String get previewDigestMode => 'Сводка';

  @override
  String get previewCommentsMode => 'Комментарии';

  @override
  String get previewReadMode => 'Чтение';

  @override
  String get previewDescription => 'ОПИСАНИЕ';

  @override
  String get previewPrompt => 'ПРОМПТ';

  @override
  String get previewUnknown => 'Неизвестно';

  @override
  String previewSourcesCount(int count) {
    return 'ИСТОЧНИКИ ($count)';
  }

  @override
  String previewFiltersCount(int count) {
    return 'ФИЛЬТРЫ ($count)';
  }

  @override
  String get previewSubscribing => 'Подписка...';

  @override
  String get previewCreating => 'Создание...';

  @override
  String get previewSubscribe => 'Подписаться';

  @override
  String get previewCreateFeed => 'Создать ленту';

  @override
  String get limitMoreFeaturesSoon => 'Скоро здесь будет больше возможностей';

  @override
  String get limitGotIt => 'Понятно';

  @override
  String get limitSourcesTitle => 'Лимит источников';

  @override
  String get limitFiltersTitle => 'Лимит фильтров';

  @override
  String get limitStylesTitle => 'Лимит стилей';

  @override
  String get limitFeedsTitle => 'Лимит лент';

  @override
  String limitSourcesMessage(int limit) {
    return 'Пока доступно только $limit источников на ленту.';
  }

  @override
  String limitFiltersMessage(int limit) {
    return 'Пока доступно только $limit фильтров на ленту.';
  }

  @override
  String limitStylesMessage(int limit) {
    return 'Пока доступно только $limit стилей на ленту.';
  }

  @override
  String limitFeedsMessage(int limit) {
    return 'Пока доступно только $limit лент.';
  }

  @override
  String get feedSavedSuccess => 'Лента успешно сохранена!';

  @override
  String get addAtLeastOneSource => 'Добавьте хотя бы один источник';

  @override
  String get myFeeds => 'Мои ленты';

  @override
  String get loadingError => 'Ошибка загрузки';

  @override
  String get retryButton => 'Повторить';

  @override
  String get noFeedsYet => 'Пока нет лент';

  @override
  String get createFirstFeedHint =>
      'Создайте первую ленту, чтобы получать персонализированные новости с помощью ИИ.';

  @override
  String get createFeed => 'Создать ленту';

  @override
  String get shareImage => 'Поделиться изображением';

  @override
  String get shareImageFailed => 'Не удалось поделиться изображением';

  @override
  String get saving => 'Сохранение...';

  @override
  String get imageSavedToGallery => 'Изображение сохранено в галерею';

  @override
  String get noPermissionToSave => 'Нет разрешения на сохранение изображений';

  @override
  String get imageSaveError => 'Ошибка при сохранении изображения';

  @override
  String get cannotShare => 'Невозможно поделиться';

  @override
  String get noShareIdAvailable =>
      'У этой новости отсутствует идентификатор для шаринга.';

  @override
  String couldNotOpenLink(String href) {
    return 'Не удалось открыть ссылку: $href';
  }

  @override
  String get connectionError =>
      'Не удалось подключиться к серверу. Проверьте интернет-соединение.';

  @override
  String get feedCreationSlow =>
      'Создание ленты занимает больше времени, чем обычно. Попробуйте обновить позже.';

  @override
  String get couldNotLoadNews => 'Не удалось загрузить новости';

  @override
  String get checkInternetConnection => 'Проверьте подключение к интернету';

  @override
  String get tryAgainButton => 'Попробовать еще раз';

  @override
  String get unsafeUrl => 'Небезопасный URL';

  @override
  String get unsafeUrlBlocked =>
      'Заблокирована попытка перехода на опасный URL';

  @override
  String get contentLoadFailed => 'Не удалось загрузить содержимое';

  @override
  String get videoBlockedForSafety =>
      'Это видео заблокировано для вашей безопасности';

  @override
  String get closeButton => 'Закрыть';

  @override
  String get loadingText => 'Загрузка...';

  @override
  String get videoUnsafeUrl => 'Небезопасный URL';

  @override
  String get videoUnsafeMessage =>
      'Это видео не может быть открыто для вашей безопасности';

  @override
  String get videoTitle => 'Видео';

  @override
  String get urlEmpty => 'URL пустой';

  @override
  String get urlInvalidFormat => 'Некорректный формат URL';

  @override
  String urlDangerousProtocol(String scheme) {
    return 'Опасный протокол: $scheme://';
  }

  @override
  String get urlOnlyHttpAllowed =>
      'Разрешены только https:// и http:// протоколы';

  @override
  String get urlUnsafeVideoUnknownSource =>
      'Это видео из неизвестного источника и использует небезопасное соединение (http://)';

  @override
  String get urlUnsafeVideoUnknown => 'Это видео из неизвестного источника';

  @override
  String get feedBuilderStartCreating => 'Начните создание';

  @override
  String get feedBuilderSession => 'Сессия';

  @override
  String get feedTypeIndividualPosts => 'Отдельные посты';

  @override
  String get feedTypeDigestLabel => 'Сводка';

  @override
  String get feedTypeIndividualPostsDesc => 'Каждый пост отображается отдельно';

  @override
  String get feedTypeDigestLabelDesc => 'Посты объединяются в сводку';

  @override
  String get configBriefSummary => 'Краткий пересказ';

  @override
  String get configWithAnalysis => 'С анализом';

  @override
  String get configOriginal => 'Оригинал';

  @override
  String get configKeyPointsOnly => 'Только главное';

  @override
  String get configRemoveDuplicates => 'Удалять дубликаты';

  @override
  String get configFilterAds => 'Фильтровать рекламу';

  @override
  String get configRemoveSpam => 'Убирать спам';

  @override
  String get configNoClickbait => 'Без кликбейта';

  @override
  String get feedNotFound => 'Лента не найдена';

  @override
  String get alreadySubscribed => 'Вы уже подписаны';

  @override
  String get feedLoadError => 'Не удалось загрузить ленту';

  @override
  String get feedSubscribeError => 'Не удалось подписаться на ленту';

  @override
  String get analyticsConsent => 'Сбор аналитики';

  @override
  String get analyticsConsentDescription =>
      'Помочь улучшить приложение, отправляя анонимные данные об использовании';

  @override
  String get errorLoadingPosts => 'Не удалось загрузить посты';

  @override
  String get tapToRetry => 'Нажмите, чтобы повторить';
}
