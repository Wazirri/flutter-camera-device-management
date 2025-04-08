#!/usr/bin/env python3

def fix_dashboard_screen():
    with open('lib/screens/dashboard_screen.dart', 'r') as file:
        lines = file.readlines()
    
    fixed_lines = []
    for line in lines:
        if "shrinkWrap: true," in line:
            fixed_lines.append("      shrinkWrap: true, // Fixed\n")
        else:
            fixed_lines.append(line)
    
    with open('lib/screens/dashboard_screen.dart', 'w') as file:
        file.writelines(fixed_lines)
    
    return "Dashboard screen updated."

print(fix_dashboard_screen())
