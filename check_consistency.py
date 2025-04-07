#!/usr/bin/env python3

import re

def check_pagination_logic(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Find both usages of the pagination adjustment
    # 1. In the container height
    container_height = re.search(r'height: availableHeight - \(_totalPages > 1 \? paginationControlsHeight : 0\),', content)
    
    # 2. In the adjustedAvailableHeight
    adjusted_height = re.search(r'final double adjustedAvailableHeight = availableHeight - \(_totalPages > 1 \? paginationControlsHeight : 0\);', content)
    
    if container_height and adjusted_height:
        print("WARNING: Pagination height is subtracted TWICE:")
        print(f"1. Container height: {container_height.group(0)}")
        print(f"2. Adjusted height: {adjusted_height.group(0)}")
        
        # Remove the adjustment from adjustedAvailableHeight
        updated = content.replace(
            'final double adjustedAvailableHeight = availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0);',
            'final double adjustedAvailableHeight = availableHeight; // Not subtracting pagination again'
        )
        
        with open(file_path, 'w') as f:
            f.write(updated)
            
        return "Fixed double pagination subtraction"
    else:
        return "Pagination logic looks consistent"

print(check_pagination_logic('lib/screens/multi_live_view_screen.dart'))
