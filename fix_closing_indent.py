#!/usr/bin/env python3

with open('lib/main.dart', 'r') as file:
    content = file.read()

# Current indentation problem
old_indent = """    ),
  );
  }"""

# Fixed indentation
fixed_indent = """    ),
    );
  }"""

# Apply fix
content = content.replace(old_indent, fixed_indent)

# Write the fixed content back to the file
with open('lib/main.dart', 'w') as file:
    file.write(content)

print("Fixed indentation of closing parentheses in main.dart")
