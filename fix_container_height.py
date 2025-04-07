#!/usr/bin/env python3

import re

def fix_container_height(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Find the container height line
    container_height_pattern = r'height: availableHeight,'
    
    # Replace with the adjusted height calculation
    fixed_container_height = 'height: availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0),'
    
    updated_content = content.replace(container_height_pattern, fixed_container_height)
    
    with open(file_path, 'w') as f:
        f.write(updated_content)
    
    return "Fixed container height calculation"

print(fix_container_height('lib/screens/multi_live_view_screen.dart'))
