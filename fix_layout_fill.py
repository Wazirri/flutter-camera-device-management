#!/usr/bin/env python3

def fix_multiview_layout():
    # Read the whole file
    with open('lib/screens/multi_live_view_screen.dart', 'r') as file:
        content = file.readlines()
    
    # Find and fix the activeRowsNeeded calculation
    for i, line in enumerate(content):
        if "final activeRowsNeeded = (activeCameraCount / _gridColumns).ceil();" in line:
            # We'll comment out this line but leave it for reference
            content[i] = "    // final activeRowsNeeded = (activeCameraCount / _gridColumns).ceil(); // Old calculation\n"
            # Add a new line that always uses a fixed row count per page
            content.insert(i+1, "    final activeRowsNeeded = (_currentLayout.rows > 0) ? _currentLayout.rows : 5; // Always use layout rows count or default to 5 rows\n")
            print(f"Updated activeRowsNeeded calculation at line {i+1}")
    
    # Find and fix the height calculation
    for i, line in enumerate(content):
        if "final double cellHeight = (availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0)) / activeRowsNeeded;" in line:
            content[i] = "    final double cellHeight = (availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0)) / activeRowsNeeded;\n"
            print(f"Updated cellHeight calculation at line {i+1}")
    
    # Write the updated content back
    with open('lib/screens/multi_live_view_screen.dart', 'w') as file:
        file.writelines(content)
    
    return "Multi Camera View layout updated to always fill the screen using layout's row count"

print(fix_multiview_layout())
