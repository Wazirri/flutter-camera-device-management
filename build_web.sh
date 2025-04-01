#!/bin/bash

echo "Building Flutter web application..."
flutter build web --web-renderer html

echo "Build completed. Starting server..."
node server.js