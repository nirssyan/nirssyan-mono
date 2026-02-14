import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppColors {
  // Dark theme colors only (strict black/white)
  static const Color primary = Color(0xFF000000);
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceElevated = Color(0xFF262626); // Elevated cards for better contrast
  
  // Glass effects
  static const Color glassBackground = Color(0xFF1A1A1A);
  static const Color glassBorder = Colors.white;
  static const Color glassShadow = Colors.black;
  
  // Navigation - no blue colors
  static const Color tabSelected = Colors.white;
  static const Color tabUnselected = Color(0xFF666666);
  static const Color navBarBorder = Color(0x1A000000);
  
  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF999999);
  
  // Buttons - no blue colors
  static const Color buttonPrimary = Colors.white;
  static const Color iconPrimary = Colors.white;
  static const Color iconSecondary = Color(0xFF666666);
  
  // Accent colors - strict black/white
  static const Color accent = Colors.white;
  static const Color accentSecondary = Color(0xFF333333);
  static const Color grokSurface = Color(0xFF2A2A2A);
  static const Color grokHover = Color(0xFF333333);

  // Light theme colors (pure white background)
  static const Color lightPrimary = Color(0xFF000000);
  static const Color lightBackground = Color(0xFFFFFFFF); // Pure white
  static const Color lightSurface = Color(0xFFF8F9FA);
  
  // Light glass effects
  static const Color lightGlassBackground = Color(0xFFF8F9FA);
  static const Color lightGlassBorder = Colors.black;
  static const Color lightGlassShadow = Colors.grey;
  
  // Light navigation
  static const Color lightTabSelected = Colors.black;
  static const Color lightTabUnselected = Color(0xFF999999);
  static const Color lightNavBarBorder = Color(0x1AFFFFFF);
  
  // Light text
  static const Color lightTextPrimary = Colors.black;
  static const Color lightTextSecondary = Color(0xFF666666);
  
  // Light buttons
  static const Color lightButtonPrimary = Colors.black;
  static const Color lightIconPrimary = Colors.black;
  static const Color lightIconSecondary = Color(0xFF999999);
  
  // Light accent colors
  static const Color lightAccent = Colors.black;
  static const Color lightAccentSecondary = Color(0xFFCCCCCC);
  static const Color lightGrokSurface = Color(0xFFF5F5F5);
  static const Color lightGrokHover = Color(0xFFCCCCCC);
} 