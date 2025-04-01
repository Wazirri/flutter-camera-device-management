import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';

import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/live_view_screen.dart';
import 'screens/record_view_screen.dart';
import 'screens/cameras_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CameraDeviceManagerApp());
}

class CameraDeviceManagerApp extends StatelessWidget {
  const CameraDeviceManagerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera & Device Manager',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/live_view': (context) => const LiveViewScreen(),
        '/record_view': (context) => const RecordViewScreen(),
        '/cameras': (context) => const CamerasScreen(),
        '/devices': (context) => const DevicesScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

// Helper method to determine if the app is running on a mobile or desktop platform
bool isMobilePlatform() {
  return UniversalPlatform.isIOS || UniversalPlatform.isAndroid;
}

bool isDesktopPlatform() {
  return UniversalPlatform.isWindows || 
         UniversalPlatform.isMacOS || 
         UniversalPlatform.isLinux;
}
