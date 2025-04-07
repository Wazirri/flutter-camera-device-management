import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors
  static const Color primaryColor = Color(0xFFF7941E); // Orange
  static const Color accentColor = Color(0xFF00ADEE);  // Blue
  
  // Status colors
  static const Color successColor = Color(0xFF4CAF50); // Green
  static const Color warningColor = Color(0xFFFF9800); // Orange
  static const Color errorColor = Color(0xFFE53935);   // Red
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkInput = Color(0xFF2C2C2C);
  static Color darkTextPrimary = Colors.white;
  static Color darkTextSecondary = Colors.white70;
  
  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, Color(0xFFFF5722)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentColor, Color(0xFF2196F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Get status color based on value percentage
  static Color getStatusColor(double value) {
    if (value < 0.3) return successColor;
    if (value < 0.7) return warningColor;
    return errorColor;
  }
  
  // Dark theme
  static ThemeData darkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: darkBackground,
    primaryColor: primaryColor,
    colorScheme: const ColorScheme.dark().copyWith(
      primary: primaryColor,
      secondary: accentColor,
      surface: darkSurface,
      error: errorColor,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkSurface,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: darkTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(
        color: darkTextPrimary,
      ),
    ),
    cardTheme: CardTheme(
      color: darkSurface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accentColor,
        side: const BorderSide(color: accentColor),
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
    inputDecorationTheme: InputDecorationTheme(
      fillColor: darkInput,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: darkTextSecondary),
      hintStyle: TextStyle(color: darkTextSecondary.withOpacity(0.5)),
      prefixIconColor: darkTextSecondary,
      suffixIconColor: darkTextSecondary,
    ),
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: darkTextPrimary,
      displayColor: darkTextPrimary,
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade800,
      thickness: 1,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: accentColor,
      unselectedItemColor: darkTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    tabBarTheme: TabBarTheme(
      labelColor: accentColor,
      unselectedLabelColor: darkTextSecondary,
      indicator: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: accentColor,
            width: 2,
          ),
        ),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkSurface,
      contentTextStyle: TextStyle(color: darkTextPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}
