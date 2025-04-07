#!/usr/bin/env python3

import re

def fix_multiview_layout(file_path):
    with open(file_path, 'r') as file:
        content = file.read()
    
    # Fix 1: Update the availableHeight calculation to not subtract paginationControlsHeight
    available_height_pattern = re.compile(r'final availableHeight = size\.height - appBarHeight - paginationControlsHeight - bottomNavHeight - safeAreaPadding\.top - safeAreaPadding\.bottom;')
    updated_content = available_height_pattern.sub(
        'final availableHeight = size.height - appBarHeight - bottomNavHeight - safeAreaPadding.top - safeAreaPadding.bottom;',
        content
    )
    
    # Fix 2: Update the Container height to account for pagination controls once
    container_height_pattern = re.compile(r'height: availableHeight,')
    updated_content = container_height_pattern.sub(
        'height: availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0),',
        updated_content
    )
    
    # Fix 3: Simplify the aspect ratio calculation (remove the duplicate pagination adjustment)
    aspect_ratio_section_pattern = re.compile(r'// Adjust the available height by removing the pagination controls if needed\s+final double adjustedAvailableHeight = availableHeight - \(_totalPages > 1 \? paginationControlsHeight : 0\);\s+final double cellHeight = adjustedAvailableHeight / activeRowsNeeded;')
    updated_content = aspect_ratio_section_pattern.sub(
        '// Calculate cell height based on container height and active rows needed\nfinal double cellHeight = (availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0)) / activeRowsNeeded;',
        updated_content
    )
    
    with open(file_path, 'w') as file:
        file.write(updated_content)
    
    return "Multi Camera View layout fixed successfully"

print(fix_multiview_layout('lib/screens/multi_live_view_screen.dart'))
