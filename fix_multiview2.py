#!/usr/bin/env python3

def fix_multiview_layout():
    # Read the whole file
    with open('lib/screens/multi_live_view_screen.dart', 'r') as file:
        content = file.readlines()
    
    # Find and update the availableHeight calculation line
    for i, line in enumerate(content):
        if "final availableHeight = size.height - appBarHeight -" in line:
            if "paginationControlsHeight" in line:
                content[i] = "    final availableHeight = size.height - appBarHeight - bottomNavHeight - safeAreaPadding.top - safeAreaPadding.bottom;\n"
                print(f"Updated availableHeight calculation at line {i+1}")
    
    # Find and update the Container height
    for i, line in enumerate(content):
        if "height: availableHeight," in line:
            content[i] = "            height: availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0),\n"
            print(f"Updated Container height at line {i+1}")
    
    # Find and update the adjustedAvailableHeight section
    adjust_height_found = False
    for i, line in enumerate(content):
        if "final double adjustedAvailableHeight = availableHeight -" in line:
            adjust_height_found = True
            content[i] = "    // Calculate cell height directly using the effective available height\n"
            # If we found the next line that calculates cellHeight, we update it too
            if i+1 < len(content) and "cellHeight = adjustedAvailableHeight" in content[i+1]:
                content[i+1] = "    final double cellHeight = (availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0)) / activeRowsNeeded;\n"
                print(f"Updated cell height calculation at lines {i+1}-{i+2}")
    
    # Write the updated content back
    with open('lib/screens/multi_live_view_screen.dart', 'w') as file:
        file.writelines(content)
    
    return "Multi Camera View layout fixed"

print(fix_multiview_layout())
