import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart'; // Import for MediaKit
import 'screens/cameras_screen.dart';
import 'screens/camera_devices_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/live_view_screen.dart';
import 'screens/login_screen.dart';
import 'screens/record_view_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/websocket_log_screen.dart';
import 'screens/multi_live_view_screen.dart';  // New multi-camera view screen
import 'theme/app_theme.dart';
import 'utils/responsive_helper.dart';
import 'utils/page_transitions.dart';
import 'widgets/desktop_side_menu.dart';
import 'widgets/mobile_bottom_navigation_bar.dart';
import 'providers/websocket_provider.dart';
import 'providers/camera_devices_provider.dart';
import 'providers/multi_view_layout_provider.dart';
import 'providers/recording_provider.dart';

Future<void> main() async {
  // This captures errors that happen during initialization
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize MediaKit
    MediaKit.ensureInitialized();
    
    // Set orientations (only for mobile platforms)
    if (true) {
      try {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        
        // Set specific platform settings
        if (Platform.isIOS || Platform.isMacOS) {
          // iOS/macOS specific settings if needed
          debugPrint('Configuring iOS/macOS specific settings');
        }
      } catch (e) {
        debugPrint('Error setting orientations: $e');
      }
    }
    
    // Run the app
    runApp(const CameraDeviceManagerApp());
  }, (error, stackTrace) {
    // Log any errors that occur during app initialization
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stackTrace');
  });
}

class CameraDeviceManagerApp extends StatelessWidget {
  const CameraDeviceManagerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WebSocketProvider()),
        ChangeNotifierProvider(create: (_) => CameraDevicesProvider()),
        ChangeNotifierProvider(create: (_) => MultiViewLayoutProvider()),
        ChangeNotifierProvider(create: (_) => RecordingProvider()),
      ],
      child: MaterialApp(
        title: 'movita ECS',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const LoginScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const AppShell(child: DashboardScreen()),
          '/cameras': (context) => const AppShell(child: CamerasScreen()),
          '/camera-devices': (context) => const AppShell(child: CameraDevicesScreen()),
          '/devices': (context) => const AppShell(child: DevicesScreen()),
          '/records': (context) => const AppShell(child: RecordViewScreen()),
          '/settings': (context) => const AppShell(child: SettingsScreen()),
          '/logs': (context) => const AppShell(child: WebSocketLogScreen()),
          '/multi-view': (context) => const AppShell(child: MultiLiveViewScreen()),
        },
        onGenerateRoute: (settings) {
          // Handle dynamic routes
          if (settings.name == '/live-view') {
            final camera = settings.arguments as dynamic;
            return PageTransition(
              child: AppShell(child: LiveViewScreen(camera: camera)),
              type: PageTransitionType.rightToLeft,
            );
          } else if (settings.name == '/record-view') {
            final camera = settings.arguments as dynamic;
            return PageTransition(
              child: AppShell(child: RecordViewScreen(camera: camera)),
              type: PageTransitionType.rightToLeft,
            );
          }
          return null;
        },
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  final Widget child;
  
  const AppShell({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if we're on a desktop platform
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      // For desktop, use side menu; for mobile, use bottom navigation
      body: Row(
        children: [
          // Side menu for desktop
          if (isDesktop) const DesktopSideMenu(),
          
          // Main content area
          Expanded(child: child),
        ],
      ),
      
      // Bottom navigation for mobile/tablet
      bottomNavigationBar: isDesktop 
          ? null  // No bottom nav on desktop
          : const MobileBottomNavigationBar(),
    );
  }
}
