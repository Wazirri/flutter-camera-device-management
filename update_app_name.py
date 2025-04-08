#!/usr/bin/env python3

def update_app_name():
    with open('android/app/src/main/AndroidManifest.xml', 'r') as file:
        content = file.read()
    
    # Update app name
    old_name = 'android:label="Camera Device Manager"'
    new_name = 'android:label="movita ECS"'
    
    if old_name in content:
        content = content.replace(old_name, new_name)
        
        with open('android/app/src/main/AndroidManifest.xml', 'w') as file:
            file.write(content)
        
        return "App name updated to 'movita ECS'."
    else:
        return "Old app name not found. No changes made."

print(update_app_name())
