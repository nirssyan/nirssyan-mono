import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:makefeed/l10n/generated/app_localizations.dart';
import 'package:makefeed/pages/home_page.dart';
import 'package:makefeed/services/locale_service.dart';
import 'package:makefeed/theme/app_theme.dart';

void main() {
  // Load fonts and configure golden toolkit
  setUpAll(() async {
    // Load all fonts including Roboto for testing
    await loadAppFonts();
  });

  // Define custom device sizes (App Store requirements)
  const iphoneProSize = Size(393, 852); // iPhone 15 Pro dimensions
  const pixel8Size = Size(412, 915); // Pixel 8 dimensions

  // Helper to wrap pages in CupertinoApp with localization
  Widget wrapInApp(Widget child, {required Locale locale, bool isDark = false}) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
      ],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    );
  }

  group('iOS Screenshots - English', () {
    testGoldens('1_home_feed_en', (tester) async {
      // Screenshot 1: Home page with news feed
      await tester.pumpWidgetBuilder(
        wrapInApp(
          MyHomePage(
            title: 'makefeed',
            localeService: LocaleService(),
            onNavigateToChat: () {},
          ),
          locale: const Locale('en'),
        ),
        surfaceSize: iphoneProSize,
      );

      // Use pump instead of pumpAndSettle for pages with infinite animations
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await screenMatchesGolden(
        tester,
        'ios/en-US/1_home_feed',
        customPump: (tester) => tester.pump(),
      );
    });

    testGoldens('3_home_dark_en', (tester) async {
      // Screenshot 3: Home page with dark theme
      await tester.pumpWidgetBuilder(
        wrapInApp(
          MyHomePage(
            title: 'makefeed',
            localeService: LocaleService(),
            onNavigateToChat: () {},
          ),
          locale: const Locale('en'),
          isDark: true,
        ),
        surfaceSize: iphoneProSize,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await screenMatchesGolden(
        tester,
        'ios/en-US/3_home_dark',
        customPump: (tester) => tester.pump(),
      );
    });
  });

  group('iOS Screenshots - Russian', () {
    testGoldens('1_home_feed_ru', (tester) async {
      // Скриншот 1: Главная страница с новостной лентой
      await tester.pumpWidgetBuilder(
        wrapInApp(
          MyHomePage(
            title: 'makefeed',
            localeService: LocaleService(),
            onNavigateToChat: () {},
          ),
          locale: const Locale('ru'),
        ),
        surfaceSize: iphoneProSize,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await screenMatchesGolden(
        tester,
        'ios/ru-RU/1_home_feed',
        customPump: (tester) => tester.pump(),
      );
    });

    testGoldens('3_home_dark_ru', (tester) async {
      // Скриншот 3: Главная страница с темной темой
      await tester.pumpWidgetBuilder(
        wrapInApp(
          MyHomePage(
            title: 'makefeed',
            localeService: LocaleService(),
            onNavigateToChat: () {},
          ),
          locale: const Locale('ru'),
          isDark: true,
        ),
        surfaceSize: iphoneProSize,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await screenMatchesGolden(
        tester,
        'ios/ru-RU/3_home_dark',
        customPump: (tester) => tester.pump(),
      );
    });
  });

  group('Android Screenshots - English', () {
    testGoldens('1_home_feed_android_en', (tester) async {
      await tester.pumpWidgetBuilder(
        wrapInApp(
          MyHomePage(
            title: 'makefeed',
            localeService: LocaleService(),
            onNavigateToChat: () {},
          ),
          locale: const Locale('en'),
        ),
        surfaceSize: pixel8Size,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await screenMatchesGolden(
        tester,
        'android/en-US/1_home_feed',
        customPump: (tester) => tester.pump(),
      );
    });
  });

  group('Android Screenshots - Russian', () {
    testGoldens('1_home_feed_android_ru', (tester) async {
      await tester.pumpWidgetBuilder(
        wrapInApp(
          MyHomePage(
            title: 'makefeed',
            localeService: LocaleService(),
            onNavigateToChat: () {},
          ),
          locale: const Locale('ru'),
        ),
        surfaceSize: pixel8Size,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await screenMatchesGolden(
        tester,
        'android/ru-RU/1_home_feed',
        customPump: (tester) => tester.pump(),
      );
    });
  });
}
