import 'package:flutter/cupertino.dart';
import 'colors.dart';

class AppTextStyles {
  // Навигация
  static const TextStyle navTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle tabSelected = TextStyle(
    color: AppColors.tabSelected,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle tabUnselected = TextStyle(
    color: AppColors.tabUnselected,
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );
  
  // Контент
  static const TextStyle headline = TextStyle(
    fontSize: 18,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle counter = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle pageTitle = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );
} 