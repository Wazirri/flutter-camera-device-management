#!/usr/bin/env python3

def fix_multiview_layout():
    # Read the whole file
    with open('lib/screens/multi_live_view_screen.dart', 'r') as file:
        content = file.readlines()
    
    # Fix 1: Update paginationControlsHeight and availableHeight calculation
    for i, line in enumerate(content):
        if "final paginationControlsHeight = _totalPages > 1 ? 60.0 : 0.0;" in line:
            content[i] = "    final paginationControlsHeight = _totalPages > 1 ? 48.0 : 0.0; // Reduced height\n"
            print(f"Updated paginationControlsHeight at line {i+1}")
        
        if "final availableHeight = size.height - appBarHeight - bottomNavHeight - safeAreaPadding.top - safeAreaPadding.bottom;" in line:
            content[i] = "    final availableHeight = size.height - appBarHeight - bottomNavHeight - safeAreaPadding.top - safeAreaPadding.bottom - 0.5; // Added small adjustment to eliminate rounding gaps\n"
            print(f"Updated availableHeight calculation at line {i+1}")
    
    # Fix 2: Update the Container height calculation for better precision
    for i, line in enumerate(content):
        if "height: availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0)," in line:
            content[i] = "            height: availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0),\n"
            print(f"Confirmed Container height at line {i+1}")
    
    # Fix 3: Update cell height calculation for better precision
    for i, line in enumerate(content):
        if "final double cellHeight = (availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0)) / activeRowsNeeded;" in line:
            content[i] = "    final double cellHeight = (availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0)) / activeRowsNeeded;\n"
            print(f"Confirmed cell height calculation at line {i+1}")
    
    # Write the updated content back
    with open('lib/screens/multi_live_view_screen.dart', 'w') as file:
        file.writelines(content)
    
    return "Multi Camera View layout adjusted further to eliminate any bottom margin space"

print(fix_multiview_layout())
