#!/usr/bin/env python3

def update_macos_entitlements():
    # Update DebugProfile.entitlements
    with open('macos/Runner/DebugProfile.entitlements', 'r') as file:
        debug_content = file.read()
    
    debug_permissions = '''        <key>com.apple.security.files.downloads.read-write</key>
        <true/>
        <key>com.apple.security.files.user-selected.read-write</key>
        <true/>'''
    
    if '</dict>' in debug_content and debug_permissions not in debug_content:
        debug_content = debug_content.replace('</dict>', f'{debug_permissions}\n</dict>')
        
        with open('macos/Runner/DebugProfile.entitlements', 'w') as file:
            file.write(debug_content)
    
    # Update Release.entitlements
    with open('macos/Runner/Release.entitlements', 'r') as file:
        release_content = file.read()
    
    release_permissions = '''        <key>com.apple.security.files.downloads.read-write</key>
        <true/>
        <key>com.apple.security.files.user-selected.read-write</key>
        <true/>'''
    
    if '</dict>' in release_content and release_permissions not in release_content:
        release_content = release_content.replace('</dict>', f'{release_permissions}\n</dict>')
        
        with open('macos/Runner/Release.entitlements', 'w') as file:
            file.write(release_content)
    
    return "macOS entitlements updated successfully."

print(update_macos_entitlements())
