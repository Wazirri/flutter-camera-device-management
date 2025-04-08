#!/usr/bin/env python3

with open('lib/main.dart', 'r') as file:
    content = file.read()

# Wrong closing parentheses
old_closing = """        }
      },
    ),
    );"""

# Fixed closing parentheses
fixed_closing = """        }
      },
    ),
  );"""

# Apply fix
content = content.replace(old_closing, fixed_closing)

# Write the fixed content back to the file
with open('lib/main.dart', 'w') as file:
    file.write(content)

print("Fixed closing parentheses in main.dart")
