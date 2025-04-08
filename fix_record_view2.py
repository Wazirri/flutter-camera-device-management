#!/usr/bin/env python3

import re

def fix_record_view_screen():
    with open('lib/screens/record_view_screen.dart', 'r', encoding='utf-8') as file:
        lines = file.readlines()
    
    # Make a backup just in case
    with open('lib/screens/record_view_screen.dart.bak', 'w', encoding='utf-8') as file:
        file.writelines(lines)
    
    # This will store the new content
    new_lines = []
    # This will help us detect any duplicate method
    method_found = False
    skip_current = False

    for i, line in enumerate(lines):
        # If we find a method definition for _downloadRecording
        if "_downloadRecording" in line and "void" in line and "(" in line:
            if not method_found:
                # First occurrence, keep it
                method_found = True
                new_lines.append("  // İndirme işlevini başlat (Download function)\n")
                new_lines.append(line)
            else:
                # Another occurrence found! Skip this and the associated block
                skip_current = True
                print(f"Found duplicate method at line {i+1}")
                continue

        # If we're skipping a duplicate method and find the end of the method block
        elif skip_current and line.strip() == "}":
            skip_current = False
            continue
        # Otherwise, add the line if we're not skipping
        elif not skip_current:
            new_lines.append(line)
    
    # Write cleaned file
    with open('lib/screens/record_view_screen.dart', 'w', encoding='utf-8') as file:
        file.writelines(new_lines)
    
    return "Cleaned up record_view_screen.dart to remove any potential duplicate methods"

print(fix_record_view_screen())
