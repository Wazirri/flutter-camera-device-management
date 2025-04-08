#!/usr/bin/env python3

with open('lib/screens/record_view_screen.dart', 'r') as file:
    content = file.read()

# Replace the incorrect method boundary with the correct syntax
incorrect_boundary = "}  void _updateRecordingsForSelectedDay"
correct_boundary = "}\n  \n  void _updateRecordingsForSelectedDay"

updated_content = content.replace(incorrect_boundary, correct_boundary)

# Write the fixed content back to the file
with open('lib/screens/record_view_screen.dart', 'w') as file:
    file.write(updated_content)

print("Fixed method boundary in record_view_screen.dart")
