import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors
  static const Color orangeAccent = Color(0xFFF7941E);
  static const Color blueAccent = Color(0xFF00ADEE);
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF252525);
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  
  // Status colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFE53935);
  static const Color warningColor = orangeAccent;
  static const Color infoColor = blueAccent;
  
  // Create the dark theme
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    primaryColor: blueAccent,
    colorScheme: const ColorScheme.dark(
      primary: blueAccent,
      secondary: orangeAccent,
      surface: darkSurface,
      background: darkBackground,
      error: errorColor,
    ),
    
    // AppBar theme
    appBarTheme: const AppBarTheme(
      color: darkBackground,
      elevation: 0,
      iconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    
    // Card theme
    cardTheme: const CardTheme(
      color: darkCard,
      elevation: 2,
      margin: EdgeInsets.all(8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8.0)),
      ),
    ),
    
    // Button themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: blueAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: blueAccent,
        side: const BorderSide(color: blueAccent),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: blueAccent,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      ),
    ),
    
    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: blueAccent, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textSecondary),
    ),
    
    // Text themes
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textPrimary),
      bodySmall: TextStyle(color: textSecondary),
      labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
    ),
    
    // Navigation bar theme (for mobile)
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: blueAccent,
      unselectedItemColor: textSecondary,
      elevation: 8.0,
      type: BottomNavigationBarType.fixed,
    ),
    
    // Navigation rail theme (for desktop)
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: darkSurface,
      selectedIconTheme: IconThemeData(color: blueAccent),
      selectedLabelTextStyle: TextStyle(color: blueAccent),
      unselectedIconTheme: IconThemeData(color: textSecondary),
      unselectedLabelTextStyle: TextStyle(color: textSecondary),
    ),
    
    // Divider theme
    dividerTheme: const DividerThemeData(
      color: Color(0xFF323232),
      thickness: 1.0,
      space: 1.0,
    ),
    
    // Tab theme
    tabBarTheme: const TabBarTheme(
      labelColor: blueAccent,
      unselectedLabelColor: textSecondary,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: blueAccent, width: 2.0),
      ),
    ),
  );
}
