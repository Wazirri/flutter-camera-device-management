#!/usr/bin/env python3

# This script fixes theme data issues in app_theme.dart

with open('lib/theme/app_theme.dart', 'r') as file:
    content = file.read()

# Fix CardTheme, TabBarTheme, and DialogTheme by removing 'const'
content = content.replace("cardTheme: const CardTheme(", "cardTheme: CardTheme(")
content = content.replace("tabBarTheme: const TabBarTheme(", "tabBarTheme: TabBarTheme(")
content = content.replace("dialogTheme: const DialogTheme(", "dialogTheme: DialogTheme(")

# Write the content back to the file
with open('lib/theme/app_theme.dart', 'w') as file:
    file.write(content)

print("Fixed theme data issues in app_theme.dart")
