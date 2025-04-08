#!/usr/bin/env python3

def update_ios_plist():
    with open('ios/Runner/Info.plist', 'r') as file:
        content = file.read()
    
    # Update app name
    old_name = '<string>Camera Device Manager</string>'
    new_name = '<string>movita ECS</string>'
    
    if old_name in content:
        content = content.replace(old_name, new_name)
    
    # Update bundle name
    old_bundle = '<string>camera_device_manager</string>'
    new_bundle = '<string>movita_ecs</string>'
    
    if old_bundle in content:
        content = content.replace(old_bundle, new_bundle)
    
    # Add permissions before closing </dict> tag
    permissions = '''        <key>NSAppTransportSecurity</key>
        <dict>
                <key>NSAllowsArbitraryLoads</key>
                <true/>
        </dict>
        <key>NSPhotoLibraryAddUsageDescription</key>
        <string>Bu uygulama, kayıtları cihazınıza indirmek için fotoğraf kitaplığına erişim gerektirir.</string>
        <key>NSPhotoLibraryUsageDescription</key>
        <string>Bu uygulama, kayıtları cihazınıza indirmek için fotoğraf kitaplığına erişim gerektirir.</string>
        <key>NSDocumentsFolderUsageDescription</key>
        <string>Bu uygulama, kayıtları cihazınıza indirmek için belge klasörüne erişim gerektirir.</string>'''
    
    if '</dict>' in content:
        content = content.replace('</dict>', f'{permissions}\n</dict>')
    
    with open('ios/Runner/Info.plist', 'w') as file:
        file.write(content)
    
    return "iOS Info.plist updated with app name and permissions."

print(update_ios_plist())
