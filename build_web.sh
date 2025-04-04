#!/bin/bash

echo "Building Flutter application..."
flutter build apk --release
flutter build macos --release
flutter build linux --release
flutter build windows --release

echo "Build completed."
