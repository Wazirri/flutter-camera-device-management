#!/usr/bin/env python3

import re

def update_file(filepath):
    with open(filepath, 'r') as file:
        content = file.read()
    
    # Look for the section where we calculate cell height
    cell_height_pattern = re.compile(r'final double cellHeight = availableHeight / activeRowsNeeded;')
    updated_content = cell_height_pattern.sub(
        'final double cellHeight = (availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0)) / activeRowsNeeded;',
        content
    )
    
    # Remove the pagination controls height adjustment from the Container
    container_height_pattern = re.compile(r'height: availableHeight - \(_totalPages > 1 \? paginationControlsHeight : 0\),')
    updated_content = container_height_pattern.sub('height: availableHeight,', updated_content)
    
    with open(filepath, 'w') as file:
        file.write(updated_content)
    
    return "Updated the file successfully"

print(update_file('lib/screens/multi_live_view_screen.dart'))
