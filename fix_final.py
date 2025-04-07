#!/usr/bin/env python3

def fix_multiview_layout():
    # Read the whole file
    with open('lib/screens/multi_live_view_screen.dart', 'r') as file:
        content = file.read()
    
    # Fix the duplicate activeRowsNeeded declarations
    content = content.replace("""    // Calculate how many actual rows we need for the active cameras
    // This ensures we don't reserve space for empty slots
    // Use layout rows or calculate based on active cameras if layout rows is not available
    final activeRowsNeeded = 5; // Fixed number of rows to ensure grid fills the screen
    final activeRowsNeeded = (_currentLayout.rows > 0) ? _currentLayout.rows : 5; // Always use layout rows count or default to 5 rows""", 
    """    // Instead of calculating rows based on active cameras, we use a fixed number of rows
    // This ensures the grid always fills the entire screen regardless of camera count
    final activeRowsNeeded = 5; // Fixed number of rows to ensure grid fills the screen""")
    
    # Write the updated content back
    with open('lib/screens/multi_live_view_screen.dart', 'w') as file:
        file.write(content)
    
    return "Fixed duplicate activeRowsNeeded declarations in multi view layout"

print(fix_multiview_layout())

# Verify the changes
grep -n "activeRowsNeeded" lib/screens/multi_live_view_screen.dart
