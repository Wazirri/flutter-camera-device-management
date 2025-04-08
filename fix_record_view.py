#!/usr/bin/env python3

def fix_record_view_screen():
    with open('lib/screens/record_view_screen.dart', 'r') as file:
        content = file.read()
    
    # Find the first _downloadRecording method
    first_method_start = content.find('void _downloadRecording(String recording) async {')
    if first_method_start == -1:
        return "Could not find first _downloadRecording method"
    
    # Find the end of the first method
    first_block_end = content.find('  }', first_method_start)
    if first_block_end == -1:
        return "Could not find end of first _downloadRecording method"
    
    # Find the start of the second method
    second_method_start = content.find('void _downloadRecording(String recording) async {', first_block_end)
    if second_method_start == -1:
        return "Could not find second _downloadRecording method"
    
    # Find the end of the second method
    second_block_end = content.find('  }', second_method_start)
    if second_block_end == -1:
        return "Could not find end of second _downloadRecording method"
    
    # Create new content without the second method
    new_content = content[:second_method_start-25] + content[second_block_end+4:]
    
    with open('lib/screens/record_view_screen.dart', 'w') as file:
        file.write(new_content)
    
    return "Removed duplicate _downloadRecording method"

print(fix_record_view_screen())
