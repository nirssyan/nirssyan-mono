import 'package:flutter/cupertino.dart';

class TelegramColors {
  // Telegram brand blue (approx.)
  static const Color brandBlue = Color(0xFF26A4E3);

  static const List<Color> avatarColors = [
    Color(0xFFE17076), // Red
    Color(0xFF7BC862), // Green
    Color(0xFF65AADD), // Blue
    Color(0xFFFFC107), // Yellow
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFF44336), // Deep Red
    Color(0xFF4CAF50), // Light Green
    Color(0xFF2196F3), // Light Blue
  ];

  static Color getAvatarColor(String name) {
    final hash = name.hashCode.abs();
    return avatarColors[hash % avatarColors.length];
  }
} 