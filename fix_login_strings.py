#!/usr/bin/env python3

def fix_login_screen():
    with open('lib/screens/login_screen.dart', 'r') as file:
        content = file.read()
    
    # Fix first multi-line string
    first_string_old = """                      Text(
                        'movita ECS
Enterprise Camera System',
                        style: TextStyle("""
    
    first_string_new = """                      Text(
                        'movita ECS\\nEnterprise Camera System',
                        style: TextStyle("""
    
    # Fix second multi-line string
    second_string_old = """                      Text(
                        'movita ECS
Enterprise Camera System - Camera Management System',
                        style: TextStyle("""
    
    second_string_new = """                      Text(
                        'movita ECS\\nEnterprise Camera System - Camera Management System',
                        style: TextStyle("""
    
    # Replace the strings
    content = content.replace(first_string_old, first_string_new)
    content = content.replace(second_string_old, second_string_new)
    
    with open('lib/screens/login_screen.dart', 'w') as file:
        file.write(content)
    
    return "Login screen string format issues fixed."

print(fix_login_screen())
