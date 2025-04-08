#!/usr/bin/env python3

def update_manifest():
    with open('android/app/src/main/AndroidManifest.xml', 'r') as file:
        content = file.read()
    
    # Add permissions to the manifest
    old_line = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
    new_line = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>'''
    
    if old_line in content:
        content = content.replace(old_line, new_line)
        
        with open('android/app/src/main/AndroidManifest.xml', 'w') as file:
            file.write(content)
        
        return "Android manifest updated with permissions."
    else:
        return "Manifest header not found as expected. No changes made."

print(update_manifest())
