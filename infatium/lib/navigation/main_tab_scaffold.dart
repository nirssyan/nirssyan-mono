import 'package:makefeed/pages/home_page.dart';
import 'package:flutter/cupertino.dart';
import '../widgets/glass_tab_bar.dart';
import '../widgets/onboarding_overlay.dart';
import '../theme/colors.dart';
import '../pages/feed_builder_tab_page.dart';
import '../pages/feeds_manager_page.dart';
import '../pages/profile_page.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';
import '../services/analytics_service.dart';
import '../models/analytics_event_schema.dart';
import '../services/onboarding_service.dart';
import '../l10n/generated/app_localizations.dart';

class MainTabScaffold extends StatefulWidget {
  final LocaleService localeService;
  
  const MainTabScaffold({super.key, required this.localeService});

  @override
  State<MainTabScaffold> createState() => MainTabScaffoldState();
}

class MainTabScaffoldState extends State<MainTabScaffold> {
  int _currentIndex = 0;
  final PageController _pageController = PageController(initialPage: 0);
  bool _isAnimating = false;

  // GlobalKey для Home таба (для fly-to-tab анимации)
  final GlobalKey _homeTabKey = GlobalKey();

  // GlobalKey для доступа к MyHomePageState (для refresh после создания ленты)
  final GlobalKey<MyHomePageState> _homePageKey = GlobalKey<MyHomePageState>();

  // GlobalKey для GlassTabBar (для ripple эффекта)
  final GlobalKey _tabBarKey = GlobalKey();

  // GlobalKey для доступа к FeedsManagerPageState (для refresh после создания ленты)
  final GlobalKey<FeedsManagerPageState> _feedsManagerPageKey = GlobalKey<FeedsManagerPageState>();

  // Onboarding state
  bool _showOnboarding = false;
  final List<GlobalKey> _tabKeys = [
    GlobalKey(debugLabel: 'homeTab'),
    GlobalKey(debugLabel: 'createTab'),
    GlobalKey(debugLabel: 'feedsTab'),
    GlobalKey(debugLabel: 'profileTab'),
  ];

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    await OnboardingService().initialize();
    if (OnboardingService().shouldShowOnboarding) {
      // Delay to ensure tab bar is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _showOnboarding = true);
        }
      });
    }
  }

  void _completeOnboarding() {
    OnboardingService().completeOnboarding();
    setState(() => _showOnboarding = false);
    AnalyticsService().capture(EventSchema.onboardingCompleted);
  }

  void _skipOnboarding() {
    OnboardingService().completeOnboarding();
    setState(() => _showOnboarding = false);
    AnalyticsService().capture(EventSchema.onboardingSkipped);
  }

  List<OnboardingStep> _buildOnboardingSteps(AppLocalizations l10n) {
    return [
      OnboardingStep(
        targetKey: _tabKeys[0],
        title: l10n.onboardingStep1Title,
        description: l10n.onboardingStep1Description,
        position: TooltipPosition.top,
      ),
      OnboardingStep(
        targetKey: _tabKeys[1],
        title: l10n.onboardingStep2Title,
        description: l10n.onboardingStep2Description,
        position: TooltipPosition.top,
      ),
      OnboardingStep(
        targetKey: _tabKeys[2],
        title: l10n.onboardingStep3Title,
        description: l10n.onboardingStep3Description,
        position: TooltipPosition.top,
      ),
      OnboardingStep(
        targetKey: _tabKeys[3],
        title: l10n.onboardingStep4Title,
        description: l10n.onboardingStep4Description,
        position: TooltipPosition.top,
      ),
    ];
  }

  late final List<Widget> _pages = [
    MyHomePage(
      key: _homePageKey,
      title: '',
      localeService: widget.localeService,
      onNavigateToChat: () => _onTabTapped(1), // Navigate to chat tab (index 1)
    ),
    FeedBuilderTabPage(localeService: widget.localeService),
    FeedsManagerPage(
      key: _feedsManagerPageKey,
      localeService: widget.localeService,
    ),
    ProfilePage(localeService: widget.localeService),
  ];

  void _onTabTapped(int index) {
    if (index == _currentIndex || _isAnimating) return;
    
    // Закрываем клавиатуру при переключении табов
    FocusManager.instance.primaryFocus?.unfocus();
    
    final distance = (index - _currentIndex).abs();
    final duration = distance > 1 
        ? const Duration(milliseconds: 300)
        : const Duration(milliseconds: 250);
    
    _isAnimating = true;
    
    // Сразу обновляем индекс для корректной анимации таб-бара
    setState(() => _currentIndex = index);
    // Analytics: таб выбран
    final l10n = AppLocalizations.of(context)!;
    final title = _getTabTitle(index, l10n);
    AnalyticsService().capture(EventSchema.tabSelected, properties: {
      'tab_index': index,
      'tab_name': title,
    });
    
    _pageController.animateToPage(
      index,
      duration: duration,
      curve: distance > 1 ? Curves.easeInOutQuart : Curves.easeInOutCubic,
    ).then((_) {
      _isAnimating = false;
    });
  }

  void _onPageChanged(int index) {
    // Обновляем индекс только если не происходит программная анимация
    if (!_isAnimating && index != _currentIndex) {
      // Сохраняем состояние чата при переключении с таба чата (индекс 1)
      if (_currentIndex == 1 && index != 1) {
        // Пользователь уходит с таба чата - состояние уже сохранено в ChatTabPage
        // через методы _onChatSelected, _showChatList и т.д.
        // Но можем дополнительно запомнить факт перехода
      }

      setState(() => _currentIndex = index);

      // Analytics: свайп между табами
      final l10n = AppLocalizations.of(context)!;
      AnalyticsService().capture(EventSchema.tabSwiped, properties: {
        'tab_index': index,
        'tab_name': _getTabTitle(index, l10n),
      });
    }
  }
  
  /// Публичный метод для навигации к табу создания ленты
  void navigateToFeedCreator() {
    _onTabTapped(1);
  }

  /// Публичный метод для навигации к домашнему табу
  void navigateToHome() {
    _onTabTapped(0);
  }

  /// Navigate to home tab AND refresh data (e.g., after feed creation)
  /// Automatically selects the feed being created
  void navigateToHomeWithRefresh() {
    _onTabTapped(0);
    // Refresh after navigation completes and auto-select creating feed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homePageKey.currentState?.refreshFeeds(selectCreatingFeed: true);
    });
  }

  /// Navigate to home tab AND wait for feed creation via WebSocket
  void navigateToHomeAndWaitForFeed(String feedId, {String? feedName, String? feedType}) {
    _onTabTapped(0);

    // Wait for multiple frames to ensure HomePage is fully mounted
    // First frame: PageView starts animation
    // Second frame: HomePage builds
    // Third frame: HomePage is ready to receive calls
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_homePageKey.currentState == null) {
            // Last resort: wait 300ms for HomePage to mount
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_homePageKey.currentState != null) {
                _homePageKey.currentState?.waitForFeedCreation(feedId, feedName: feedName, feedType: feedType);
              }
            });
            return;
          }

          _homePageKey.currentState?.waitForFeedCreation(feedId, feedName: feedName, feedType: feedType);
        });
      });
    });
  }

  /// Navigate to home tab and show loading overlay immediately (before feedId is known)
  void navigateToHomeWithPendingFeed({String? feedName, String? feedType}) {
    _onTabTapped(0);

    // Wait for multiple frames to ensure HomePage is fully mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_homePageKey.currentState == null) {
            // Last resort: wait 300ms for HomePage to mount
            Future.delayed(const Duration(milliseconds: 300), () {
              _homePageKey.currentState?.showFeedCreationLoading(feedName: feedName, feedType: feedType);
            });
            return;
          }

          _homePageKey.currentState?.showFeedCreationLoading(feedName: feedName, feedType: feedType);
        });
      });
    });
  }

  /// Update pending feed ID after API response and start WebSocket waiting
  void updatePendingFeedId(String feedId, {String? feedName, String? feedType}) {
    print('[MainTabScaffold] updatePendingFeedId called with feedId: $feedId');
    print('[MainTabScaffold] _homePageKey.currentState: ${_homePageKey.currentState}');

    if (_homePageKey.currentState != null) {
      print('[MainTabScaffold] HomePage ready, calling updatePendingFeedId directly');
      _homePageKey.currentState?.updatePendingFeedId(feedId, feedName: feedName, feedType: feedType);
    } else {
      print('[MainTabScaffold] HomePage not ready, waiting for frames...');
      // Wait for HomePage to be mounted
      _waitForHomePageAndUpdate(feedId, feedName: feedName, feedType: feedType);
    }
  }

  /// Wait for HomePage to be mounted and then call updatePendingFeedId
  void _waitForHomePageAndUpdate(String feedId, {String? feedName, String? feedType, int attempts = 0}) {
    if (attempts > 10) {
      print('[MainTabScaffold] ERROR: HomePage not ready after 10 attempts!');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_homePageKey.currentState != null) {
        print('[MainTabScaffold] HomePage ready after ${attempts + 1} frame(s)');
        _homePageKey.currentState?.updatePendingFeedId(feedId, feedName: feedName, feedType: feedType);
      } else {
        print('[MainTabScaffold] Still waiting... attempt ${attempts + 1}');
        _waitForHomePageAndUpdate(feedId, feedName: feedName, feedType: feedType, attempts: attempts + 1);
      }
    });
  }

  /// Navigate to Feeds Manager tab
  void navigateToFeedsManager() {
    _onTabTapped(2);
  }

  /// Navigate to Feeds Manager tab AND refresh data
  void navigateToFeedsManagerWithRefresh() {
    _onTabTapped(2);
    // Refresh after navigation completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _feedsManagerPageKey.currentState?.refreshFeeds();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _getTabTitle(int index, AppLocalizations l10n) {
    switch (index) {
      case 0:
        return l10n.home;
      case 1:
        return l10n.chats;
      case 2:
        return l10n.feedsTab;
      case 3:
        return l10n.profile;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService(),
      builder: (context, child) {
        final isDark = ThemeService().isDarkMode;
        final backgroundColor = isDark ? AppColors.background : AppColors.lightBackground;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final isKeyboardVisible = keyboardHeight > 0;

        final l10n = AppLocalizations.of(context)!;

        return Stack(
          children: [
            CupertinoPageScaffold(
              backgroundColor: backgroundColor,
              child: Column(
                children: [
                  // Main content area
                  Expanded(
                    child: Stack(
                      children: [
                        PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: _onPageChanged,
                          children: _pages,
                        ),

                        // Bottom tab bar
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOutCubic,
                              transform: Matrix4.translationValues(
                                0,
                                isKeyboardVisible ? 150 : 0, // Сдвигаем вниз при появлении клавиатуры
                                0
                              ),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: isKeyboardVisible ? 0.0 : 1.0,
                                child: GlassTabBar(
                                  key: _tabBarKey,
                                  currentIndex: _currentIndex,
                                  onTap: _onTabTapped,
                                  homeTabKey: _homeTabKey,
                                  tabKeys: _tabKeys,
                                  items: [
                                    GlassTabItem(icon: CupertinoIcons.news, title: _getTabTitle(0, l10n)),
                                    GlassTabItem(icon: CupertinoIcons.add, title: _getTabTitle(1, l10n), isFab: true),
                                    GlassTabItem(icon: CupertinoIcons.pencil, title: _getTabTitle(2, l10n)),
                                    GlassTabItem(icon: CupertinoIcons.person, title: _getTabTitle(3, l10n)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Onboarding overlay
            if (_showOnboarding)
              OnboardingOverlay(
                steps: _buildOnboardingSteps(l10n),
                onComplete: _completeOnboarding,
                onSkip: _skipOnboarding,
              ),
          ],
        );
      },
    );
  }
} 