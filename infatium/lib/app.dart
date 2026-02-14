import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'models/custom_auth_state.dart';
import 'l10n/generated/app_localizations.dart';
import 'theme/app_theme.dart';
import 'navigation/main_tab_scaffold.dart';
import 'pages/auth_page.dart';
import 'pages/splash_page.dart';
import 'services/auth_service.dart';
import 'services/app_icon_service.dart';
import 'services/theme_service.dart';
import 'services/locale_service.dart';
import 'services/analytics_service.dart';
import 'services/navigation_service.dart';
import 'services/tag_service.dart';
import 'services/zen_mode_service.dart';
import 'services/image_preview_service.dart';
import 'services/notification_service.dart';
import 'services/websocket_service.dart';
import 'services/news_service.dart';
import 'services/suggestion_service.dart';
import 'services/subscription_service.dart';
import 'services/deep_link_service.dart';
import 'services/session_tracker_service.dart';
import 'services/error_logging_service.dart';
import 'config/notification_config.dart';

class MyApp extends StatefulWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final bool testMode;
  const MyApp({super.key, this.testMode = false});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final AnalyticsService _analytics = AnalyticsService();
  final TagService _tagService = TagService();
  final SessionTrackerService _sessionTracker = SessionTrackerService();
  bool _isInitializing = true;
  StreamSubscription<CustomAuthState>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    DeepLinkService().initialize();
    _sessionTracker.initialize();
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    _authStateSubscription?.cancel();
    DeepLinkService().dispose();
    _sessionTracker.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  void _onLocaleChanged() {
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _sessionTracker.handleLifecycleChange(state);
    AuthService().handleAppLifecycleChange(state);
  }

  void _listenToAuthStateChanges() {
    _authStateSubscription = AuthService().authStateChanges.listen((CustomAuthState data) {
      // Handle password recovery event
      if (data.event == CustomAuthEvent.passwordRecovery) {
        // Wait for a short delay to ensure app is fully initialized
        Future.delayed(const Duration(milliseconds: 500), () {
          // Switch AuthPage to reset password mode instead of navigating
          AuthPage.globalKey.currentState?.switchToResetPassword();
        });
      }
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Минимальное время показа splash screen для полного проигрывания анимации
      const minSplashDuration = Duration(milliseconds: 1000);
      final stopwatch = Stopwatch()..start();

      if (widget.testMode) {
        // Минимальная инициализация для тестов без нативных плагинов
        await Future.wait([
          _themeService.initialize(),
          _localeService.initialize(),
        ]);
      } else {
        await Future.wait([
          AuthService().initialize(),
          AppIconService().initialize(),
          _themeService.initialize(),
          _localeService.initialize(),
          ZenModeService().initialize(),
          ImagePreviewService().initialize(),
          _analytics.initialize(),
          ErrorLoggingService().initialize(),
        ]);

        // Initialize auth state listener AFTER AuthService is initialized
        _listenToAuthStateChanges();

        // Load data if user is authenticated
        if (AuthService().isAuthenticated) {
          await Future.wait([
            _loadPromptExamples(),
            NewsService.fetchUserFeedsHTTP(),
            SuggestionService().fetchAll(),
            SubscriptionService().fetchSubscription(),
            if (NotificationConfig.enableNotifications)
              NotificationService().initialize(),
          ]);
        }
      }

      // Ждем минимальное время, если инициализация завершилась быстрее
      final elapsed = stopwatch.elapsed;
      if (elapsed < minSplashDuration) {
        await Future.delayed(minSplashDuration - elapsed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _loadPromptExamples() async {
    try {
      await _tagService.fetchPromptExamples();
    } catch (e) {
      // Don't throw - prompt examples are optional
      print('Error loading prompt examples: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      navigatorKey: MyApp.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'makefeed',
      theme: _themeService.isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: _isInitializing
          ? const SplashPage()
          : AuthWrapper(localeService: _localeService),

      // Локализация
      locale: _localeService.currentLocale,
      supportedLocales: _localeService.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final LocaleService localeService;

  const AuthWrapper({
    super.key,
    required this.localeService,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  final TagService _tagService = TagService();
  final GlobalKey<MainTabScaffoldState> _mainTabKey = GlobalKey<MainTabScaffoldState>();
  bool _wasAuthenticated = false;
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _wasAuthenticated = _authService.isAuthenticated;
    _authService.addListener(_onAuthStateChanged);
    // Передаем ключ NavigationService для глобального доступа
    NavigationService().setMainTabKey(_mainTabKey);
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  Future<void> _onAuthStateChanged() async {
    final isNowAuthenticated = _authService.isAuthenticated;

    // If user just logged in (transitioned from not authenticated to authenticated)
    if (!_wasAuthenticated && isNowAuthenticated) {
      // Start loading data
      setState(() {
        _isLoadingData = true;
      });

      // Load data for the newly authenticated user
      await Future.wait([
        _tagService.fetchPromptExamples(),
        NewsService.fetchUserFeedsHTTP(),
        SuggestionService().fetchAll(),
        SubscriptionService().fetchSubscription(),
      ]);

      // Initialize notifications for newly logged in user
      if (NotificationConfig.enableNotifications) {
        await NotificationService().initialize();
      }

      // Loading completed
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }

      // Process pending feed deep link after data is loaded
      if (DeepLinkService().hasPendingFeedLink) {
        DeepLinkService().processPendingFeedLink();
      }
    }

    // If user just logged out (transitioned from authenticated to not authenticated)
    if (_wasAuthenticated && !isNowAuthenticated) {
      // Unregister notification token before user is gone
      if (NotificationConfig.enableNotifications) {
        await NotificationService().unregisterToken();
      }
      // Disconnect persistent WebSocket
      WebSocketService().disconnectPersistent();
      // Clear suggestions cache
      SuggestionService().clear();
      // Clear subscription cache
      SubscriptionService().clear();
    }

    // Update the previous state
    _wasAuthenticated = isNowAuthenticated;

    // Only trigger rebuild if not loading
    if (!_isLoadingData && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authService.isAuthenticated) {
      return AuthPage(
        key: AuthPage.globalKey,
        localeService: widget.localeService,
      );
    }

    // Show loading screen while loading data after login
    if (_isLoadingData) {
      return const SplashPage();
    }

    // Show main app
    return MainTabScaffold(key: _mainTabKey, localeService: widget.localeService);
  }
}
