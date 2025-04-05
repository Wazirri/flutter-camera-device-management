#!/bin/bash

# Direct fix for macOS build issues
echo "Applying direct fix for macOS build issues..."

# Remove build caches
rm -rf build/
rm -rf macos/Flutter/ephemeral
rm -rf macos/.symlinks
rm -rf macos/Pods
rm -rf macos/Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Recreate Flutter ephemeral directory
mkdir -p macos/Flutter/ephemeral
touch macos/Flutter/ephemeral/.app_filename

# Get dependencies
flutter pub get

# Fix for Flutter plugins
flutter pub run flutter_plugin_tools exec --macos -- pod repo update

echo "Running pod install..."
cd macos
pod install --repo-update
cd ..

echo "Touching Runner.xcworkspace to refresh..."
touch macos/Runner.xcworkspace

echo "Done! Now try building your app again."
