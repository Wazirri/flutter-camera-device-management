#!/usr/bin/env python3

import re

def update_file(filepath):
    with open(filepath, 'r') as file:
        content = file.read()
    
    # Look for the section where we calculate aspect ratio
    aspectratio_section = re.search(r'// Calculate optimal aspect ratio.*?final double aspectRatio = cellWidth / cellHeight;', content, re.DOTALL)
    if aspectratio_section:
        old_section = aspectratio_section.group(0)
        new_section = """    // Calculate optimal aspect ratio based on the available height and active rows
    final double cellWidth = size.width / _gridColumns;
    // Adjust the available height by removing the pagination controls height if needed
    final double adjustedAvailableHeight = availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0);
    final double cellHeight = adjustedAvailableHeight / activeRowsNeeded;
    final double aspectRatio = cellWidth / cellHeight;"""
        
        content = content.replace(old_section, new_section)
    
    with open(filepath, 'w') as file:
        file.write(content)
    
    return "Updated the file successfully"

print(update_file('lib/screens/multi_live_view_screen.dart'))

# Verify the update
import os
os.system('grep -n "adjustedAvailableHeight" lib/screens/multi_live_view_screen.dart')
