#!/usr/bin/env python3

# This script replaces primaryOrange and primaryBlue with primaryColor and accentColor
# and darkBackgroundColor with darkBackground throughout the codebase

import os
import re

def process_dart_file(file_path):
    with open(file_path, 'r') as file:
        content = file.read()
    
    # Replace primaryOrange with primaryColor
    content = content.replace('AppTheme.primaryOrange', 'AppTheme.primaryColor')
    
    # Replace primaryBlue with accentColor
    content = content.replace('AppTheme.primaryBlue', 'AppTheme.accentColor')
    
    # Replace darkBackgroundColor with darkBackground
    content = content.replace('AppTheme.darkBackgroundColor', 'AppTheme.darkBackground')
    
    # Write back to file if changes were made
    with open(file_path, 'w') as file:
        file.write(content)

def traverse_directory(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                process_dart_file(file_path)

# Process all Dart files in the lib directory
traverse_directory('lib')
print("Fixed AppTheme color naming across all Dart files")
