#!/usr/bin/env python3

import re

with open('lib/main.dart', 'r') as file:
    content = file.read()

# 1. Remove existing keyboard handlers if any from _MyAppState class
content = re.sub(r'final HardwareKeyboard _hardwareKeyboard[^}]*_handleKeyEvent\([^}]*\)[^}]*}', '', content)

# 2. Fix the MaterialApp widget to include KeyboardFixWrapper
content = re.sub(r'Widget build\(BuildContext context\) \{\s+return MaterialApp\(', 
                'Widget build(BuildContext context) {\n    return KeyboardFixWrapper(\n      child: MaterialApp(', 
                content)

# 3. Add the closing parenthesis at the end of MaterialApp
content = content.replace('    );\n  }\n}', '    ),\n    );\n  }\n}')

with open('lib/main.dart', 'w') as file:
    file.write(content)

print("Keyboard event fix applied to main.dart")
