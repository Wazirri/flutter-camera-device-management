#!/usr/bin/env python3

import re

def fix_pagination_calculation(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Find the availableHeight calculation that subtracts paginationControlsHeight
    available_height_pattern = r'final availableHeight = size\.height - appBarHeight - paginationControlsHeight - bottomNavHeight - safeAreaPadding\.top - safeAreaPadding\.bottom;'
    
    # Replace with a calculation that doesn't subtract paginationControlsHeight
    fixed_available_height = 'final availableHeight = size.height - appBarHeight - bottomNavHeight - safeAreaPadding.top - safeAreaPadding.bottom; // Not subtracting paginationControlsHeight here'
    
    updated_content = content.replace(available_height_pattern, fixed_available_height)
    
    with open(file_path, 'w') as f:
        f.write(updated_content)
    
    return "Fixed pagination height calculation"

print(fix_pagination_calculation('lib/screens/multi_live_view_screen.dart'))
