import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors
  static const Color primaryOrange = Color(0xFFF7941E);
  static const Color primaryBlue = Color(0xFF00ADEE);
  
  // Convenience getters for brand colors
  static Color get primaryColor => primaryOrange;
  static Color get accentColor => primaryBlue;
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkError = Color(0xFFCF6679);
  static const Color darkBorder = Color(0xFF2A2A2A);
  
  // Added for backward compatibility
  static Color get darkBackgroundColor => darkBackground;
  
  // Text colors
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFFB3B3B3);
  
  // Status colors
  static const Color online = Color(0xFF4CAF50);
  static const Color offline = Color(0xFFBDBDBD);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);
  
  // Elevation colors
  static final List<Color> darkElevationOverlays = [
    Colors.white.withOpacity(0.05),
    Colors.white.withOpacity(0.08),
    Colors.white.withOpacity(0.11),
    Colors.white.withOpacity(0.12),
    Colors.white.withOpacity(0.14),
  ];

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    primaryColor: primaryBlue,
    colorScheme: const ColorScheme.dark(
      primary: primaryBlue,
      secondary: primaryOrange,
      surface: darkSurface,
      error: darkError,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: darkTextPrimary,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkTextPrimary,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: primaryBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryBlue,
        side: const BorderSide(color: primaryBlue),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryOrange,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: darkError, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2A2A2A),
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkSurface,
      indicatorColor: primaryBlue.withOpacity(0.24),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(
          color: darkTextPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryBlue);
        }
        return const IconThemeData(color: darkTextSecondary);
      }),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: darkSurface,
      selectedIconTheme: IconThemeData(color: primaryBlue),
      unselectedIconTheme: IconThemeData(color: darkTextSecondary),
      selectedLabelTextStyle: TextStyle(
        color: primaryBlue,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: darkTextSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      tileColor: darkSurface,
      textColor: darkTextPrimary,
      iconColor: darkTextSecondary,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: primaryBlue,
      unselectedLabelColor: darkTextSecondary,
      indicatorColor: primaryBlue,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: primaryBlue,
      unselectedItemColor: darkTextSecondary,
      type: BottomNavigationBarType.fixed,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryBlue;
        }
        return darkTextSecondary;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryBlue.withOpacity(0.5);
        }
        return darkTextSecondary.withOpacity(0.3);
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryBlue;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: darkTextSecondary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryBlue;
        }
        return darkTextSecondary;
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryBlue,
      linearTrackColor: Color(0xFF2A2A2A),
      circularTrackColor: Color(0xFF2A2A2A),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkSurface,
      contentTextStyle: const TextStyle(color: darkTextPrimary),
      actionTextColor: primaryOrange,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: const TextStyle(color: darkTextPrimary),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 57, 
        fontWeight: FontWeight.w400, 
        color: darkTextPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: 45, 
        fontWeight: FontWeight.w400, 
        color: darkTextPrimary,
      ),
      displaySmall: TextStyle(
        fontSize: 36, 
        fontWeight: FontWeight.w400, 
        color: darkTextPrimary,
      ),
      headlineLarge: TextStyle(
        fontSize: 32, 
        fontWeight: FontWeight.w400, 
        color: darkTextPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 28, 
        fontWeight: FontWeight.w400, 
        color: darkTextPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 24, 
        fontWeight: FontWeight.w400, 
        color: darkTextPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 22, 
        fontWeight: FontWeight.w500, 
        color: darkTextPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16, 
        fontWeight: FontWeight.w500, 
        color: darkTextPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14, 
        fontWeight: FontWeight.w500, 
        color: darkTextPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16, 
        fontWeight: FontWeight.w400, 
        color: darkTextPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14, 
        fontWeight: FontWeight.w400, 
        color: darkTextPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 12, 
        fontWeight: FontWeight.w400, 
        color: darkTextSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 14, 
        fontWeight: FontWeight.w500, 
        color: darkTextPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 12, 
        fontWeight: FontWeight.w500, 
        color: darkTextPrimary,
      ),
      labelSmall: TextStyle(
        fontSize: 11, 
        fontWeight: FontWeight.w500, 
        color: darkTextSecondary,
      ),
    ),
  );
}
