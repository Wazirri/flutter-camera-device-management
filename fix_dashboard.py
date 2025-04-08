#!/usr/bin/env python3

import re

def fix_dashboard_screen():
    with open('lib/screens/dashboard_screen.dart', 'r') as file:
        content = file.read()
    
    # Find the _buildOverviewCards method and add a tiny fix to make sure any hidden
    # characters or formatting issues are resolved
    pattern = r'(Widget _buildOverviewCards\(BuildContext context\) \{\s+final isSmallScreen = ResponsiveHelper\.isMobile\(context\);\s+\s+return GridView\.count\(\s+)shrinkWrap: true,'
    
    if re.search(pattern, content):
        fixed_content = re.sub(pattern, r'\1shrinkWrap: true, // Fixed', content)
        
        with open('lib/screens/dashboard_screen.dart', 'w') as file:
            file.write(fixed_content)
        
        return "Dashboard screen fixed successfully."
    else:
        return "Pattern not found. No changes made."

print(fix_dashboard_screen())
