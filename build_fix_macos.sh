#!/bin/bash

echo "Fixing Flutter macOS build issues..."

# Clean the build
flutter clean

# Update Flutter
flutter channel stable
flutter upgrade

# Remove pods
rm -rf ios/Pods ios/Podfile.lock
rm -rf macos/Pods macos/Podfile.lock

# Re-create macOS Podfile with minimum_deployment_target fix
cat > macos/Podfile << 'EOF'
platform :osx, '10.14'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'ephemeral', 'Flutter-Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure \"flutter pub get\" is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Flutter-Generated.xcconfig, then run \"flutter pub get\""
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_macos_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_macos_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_macos_build_settings(target)
    
    # Add the following block to fix build issues
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.14'
      
      # Fix for Xcode 15
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      
      # Fix for M1/ARM64 architecture
      config.build_settings['DEAD_CODE_STRIPPING'] = 'YES'
      
      # Fix for some Cocoapods issues
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
    end
  end
end
EOF

# Fix macOS runner build settings
mkdir -p macos/Runner/Configs
cat > macos/Runner/Configs/AppInfo.xcconfig << 'EOF'
// Application-level settings for the Runner target.
//
// This may be replaced with something auto-generated from metadata (e.g., pubspec.yaml) in the
// future. If not, the values below would default to using the project name when this becomes a
// 'flutter create' template.

// Bundle identifier
PRODUCT_BUNDLE_IDENTIFIER = com.example.cameraDeviceManager

// The application's name.
PRODUCT_NAME = camera_device_manager

// The application's bundle identifier
PRODUCT_BUNDLE_IDENTIFIER = com.example.cameraDeviceManager

// The copyright displayed in application information
PRODUCT_COPYRIGHT = Copyright © 2023 com.example. All rights reserved.
EOF

# Touch the Info.plist to refresh it
touch macos/Runner/Info.plist

# Regenerate Flutter files
flutter pub get
flutter pub upgrade

echo "macOS build fix applied!"
