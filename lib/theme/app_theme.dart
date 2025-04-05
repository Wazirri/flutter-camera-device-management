import 'package:flutter/material.dart';

class AppTheme {
  // Primary brand colors
  static const Color primaryColor = Color(0xFFF7941E); // Brand orange
  static const Color accentColor = Color(0xFF00ADEE); // Brand blue
  static const Color primaryOrange = Color(0xFFF7941E); // Same as primaryColor
  static const Color primaryBlue = Color(0xFF00ADEE); // Same as accentColor
  
  // Dark theme colors
  static const Color backgroundColor = Color(0xFF121212);
  static const Color darkBackground = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color errorColor = Color(0xFFCF6679);
  static const Color darkBorder = Color(0xFF2D2D2D);
  
  // Additional UI colors
  static const Color textColor = Colors.white;
  static const Color darkTextPrimary = Colors.white;
  static const Color textSecondaryColor = Colors.white70;
  static const Color darkTextSecondary = Colors.white70;
  static const Color dividerColor = Colors.white24;
  static const Color cardColor = Color(0xFF2C2C2C);
  static const Color panelBackground = Color(0xFF1A1A1A);
  
  // Status colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color online = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color warning = Color(0xFFFFC107);
  static const Color dangerColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);
  
  // Create the material theme
  static ThemeData darkTheme() {
    return ThemeData.dark().copyWith(
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      scaffoldBackgroundColor: backgroundColor,
      cardTheme: const CardTheme(
        color: cardColor,
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.white54,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor,
      ),
      textTheme: const TextTheme().copyWith(
        // Replace deprecated text styles with current ones
        displayLarge: const TextStyle(color: textColor),
        displayMedium: const TextStyle(color: textColor),
        displaySmall: const TextStyle(color: textColor),
        headlineMedium: const TextStyle(color: textColor),
        headlineSmall: const TextStyle(color: textColor),
        titleLarge: const TextStyle(color: textColor),
        bodyLarge: const TextStyle(color: textColor),
        bodyMedium: const TextStyle(color: textColor),
      ),
    );
  }
}
