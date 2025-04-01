# Camera Device Manager

A cross-platform Flutter application for camera and device management with a focus on UI/UX design.

## Description

This project is a UI/UX design implementation for a camera and device management system. It provides a modern dark-themed interface with responsive layouts across multiple platforms. The application includes various screens for managing cameras, devices, viewing live feeds, and recordings.

**Note:** This is a UI design implementation only and does not include actual backend functionality or camera/device communication.

## Features

- **Cross-Platform:** Designed for macOS, Linux, Windows, Android, and iOS platforms
- **Dark Theme:** Modern dark UI with brand colors #F7941E (orange) and #00ADEE (blue)
- **Responsive Design:** Adapts to different screen sizes with platform-specific navigation (bottom tabs for mobile, side menu for desktop)
- **Multiple Screens:**
  - Login Screen
  - Dashboard with overview statistics
  - Live Camera View with grid layout options
  - Recordings view with playback controls
  - Cameras management screen
  - Devices management screen
  - Settings screen

## Screenshots

Below are some screenshots of the application on different platforms and screen sizes:

![Dashboard View](attached_assets/image_1743526289103.png)
![Live View Screen](attached_assets/image_1743526301149.png)
![Settings Screen](attached_assets/image_1743526307872.png)

## Getting Started

### Prerequisites

- Flutter SDK
- Dart
- Platform-specific development tools (Xcode for iOS/macOS, Android Studio for Android)

### Installation

1. Clone the repository
   ```
   git clone https://github.com/yourusername/camera-device-manager.git
   ```
2. Navigate to the project directory
   ```
   cd camera-device-manager
   ```
3. Install dependencies
   ```
   flutter pub get
   ```
4. Run the application
   ```
   flutter run
   ```

## Project Structure

The project is organized as follows:

- `lib/`
  - `main.dart` - Application entry point
  - `models/` - Data models
  - `screens/` - UI screen implementations
  - `theme/` - App theme and styling
  - `utils/` - Utility functions and helpers
  - `widgets/` - Reusable UI components

## Technology Stack

- Flutter SDK
- Dart programming language
- Material Design

## UI Design Principles

- Consistent color scheme based on brand colors
- Platform-adaptive navigation patterns
- Responsive layouts for various screen sizes
- Dark theme for reduced eye strain in monitoring environments
- Clear visual hierarchy and typographic scale