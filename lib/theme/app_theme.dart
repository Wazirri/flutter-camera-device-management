import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFFF7941E); // Orange
  static const Color accentColor = Color(0xFF00ADEE); // Blue
  
  // Dark Background Colors
  static const Color darkBackgroundColor = Color(0xFF121212);
  static const Color darkCardColor = Color(0xFF1E1E1E);
  static const Color darkAppBarColor = Color(0xFF252525);
  
  // Text Colors
  static const Color darkTextColor = Colors.white;
  static const Color darkTextSecondaryColor = Colors.white70;
  
  // Status Colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFFB300);
  static const Color infoColor = Color(0xFF2196F3);
  
  // Dark Theme
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      error: errorColor,
      background: darkBackgroundColor,
      surface: darkCardColor,
    ),
    scaffoldBackgroundColor: darkBackgroundColor,
    cardColor: darkCardColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkAppBarColor,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: darkTextColor,
      ),
      iconTheme: IconThemeData(color: darkTextColor),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkAppBarColor,
      selectedItemColor: primaryColor,
      unselectedItemColor: darkTextSecondaryColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: darkTextColor,
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentColor,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accentColor,
        side: const BorderSide(color: accentColor),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: darkCardColor,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primaryColor,
      thumbColor: primaryColor,
      overlayColor: primaryColor.withOpacity(0.2),
      inactiveTrackColor: primaryColor.withOpacity(0.3),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkCardColor,
      contentTextStyle: const TextStyle(color: darkTextColor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: darkCardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentColor,
      foregroundColor: darkTextColor,
    ),
    dividerColor: Colors.white12,
    cardTheme: CardTheme(
      color: darkCardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
    ),
    // Use a system font for better cross-platform support
    fontFamily: 'Roboto',
  );
}
