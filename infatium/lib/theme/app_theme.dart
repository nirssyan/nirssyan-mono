import 'package:flutter/cupertino.dart';
import 'colors.dart';
import 'text_styles.dart';

class AppTheme {
  static const CupertinoThemeData darkTheme = CupertinoThemeData(
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    barBackgroundColor: AppColors.surface,
    brightness: Brightness.dark,
    textTheme: CupertinoTextThemeData(
      primaryColor: AppColors.textPrimary,
      navTitleTextStyle: AppTextStyles.navTitle,
      textStyle: AppTextStyles.body,
    ),
    primaryContrastingColor: AppColors.accent,
  );

  static const CupertinoThemeData lightTheme = CupertinoThemeData(
    primaryColor: AppColors.lightPrimary,
    scaffoldBackgroundColor: AppColors.lightBackground,
    barBackgroundColor: AppColors.lightSurface,
    brightness: Brightness.light,
    textTheme: CupertinoTextThemeData(
      primaryColor: AppColors.lightTextPrimary,
      navTitleTextStyle: TextStyle(
        color: AppColors.lightTextPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      textStyle: TextStyle(
        color: AppColors.lightTextPrimary,
        fontSize: 17,
      ),
    ),
    primaryContrastingColor: AppColors.lightAccent,
  );
  
  // Use dark theme by default, but support light theme
  static const CupertinoThemeData theme = darkTheme;
  
  // Дополнительные стили для виджетов
  static const double iconSize = 26.0;
  static const double buttonIconSize = 22.0;
  static const EdgeInsets buttonPadding = EdgeInsets.zero;
  static const double scaleAnimation = 1.15;
} 