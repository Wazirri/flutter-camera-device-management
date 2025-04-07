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
import 'transitions/page_transition.dart';
import 'widgets/desktop_side_menu.dart';
import 'widgets/mobile_bottom_navigation_bar.dart';
import 'providers/websocket_provider.dart';
import 'providers/camera_devices_provider.dart';
import 'providers/multi_view_layout_provider.dart';
import 'providers/recording_provider.dart';
import 'models/device_status.dart';

Future<void> main() async {
  // This captures errors that happen during initialization
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize MediaKit - required for camera display
    MediaKit.ensureInitialized();
    
    // Lock screen orientation to portrait mode for mobile
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    
    // Setup navigation observer
    final routeObserver = RouteObserver<PageRoute>();
    
    // Apply system UI overlay style (status bar, etc.)
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppTheme.darkBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => WebSocketProvider()),
          ChangeNotifierProxyProvider<WebSocketProvider, CameraDevicesProvider>(
            create: (_) => CameraDevicesProvider(),
            update: (_, webSocketProvider, cameraDevicesProvider) => 
              cameraDevicesProvider!..updateFromWebSocket(webSocketProvider),
          ),
          ChangeNotifierProvider(create: (_) => MultiViewLayoutProvider()),
          ChangeNotifierProvider(create: (_) => RecordingProvider()),
        ],
        child: CameraDeviceManagerApp(routeObserver: routeObserver),
      ),
    );
  }, (error, stack) {
    print('Unhandled error: $error');
    print('Stack trace: $stack');
  });
}

class CameraDeviceManagerApp extends StatefulWidget {
  final RouteObserver<PageRoute> routeObserver;
  
  const CameraDeviceManagerApp({Key? key, required this.routeObserver}) : super(key: key);

  @override
  State<CameraDeviceManagerApp> createState() => _CameraDeviceManagerAppState();
}

class _CameraDeviceManagerAppState extends State<CameraDeviceManagerApp> {
  String _currentRoute = '/login';
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'movita ECS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      navigatorKey: _navigatorKey,
      navigatorObservers: [widget.routeObserver],
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        final args = settings.arguments;
        
        Widget page;
        switch (settings.name) {
          case '/login':
            page = const LoginScreen();
            break;
          case '/dashboard':
            page = const DashboardScreen();
            break;
          case '/live-view':
            page = const LiveViewScreen();
            break;
          case '/multi-live-view':
            page = const MultiLiveViewScreen();
            break;
          case '/recordings':
            page = const RecordViewScreen();
            break;
          case '/cameras':
            page = const CamerasScreen();
            break;
          case '/devices':
            page = const DevicesScreen();
            break;
          case '/camera-devices':
            page = const CameraDevicesScreen();
            break;
          case '/settings':
            page = const SettingsScreen();
            break;
          case '/websocket-logs':
            page = const WebSocketLogScreen();
            break;
          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Route not found')),
              ),
            );
        }
        
        // Use custom page transition
        if (settings.name == '/login') {
            return PageTransition(
              child: page,
              type: PageTransitionType.fade,
              settings: settings,
            );
        } else {
            return PageTransition(
              child: AppShell(child: page),
              type: PageTransitionType.rightToLeft,
              settings: settings,
            );
        }
      },
    );
  }
  
  void _navigateTo(String route) {
    setState(() => _currentRoute = route);
    _navigatorKey.currentState?.pushReplacementNamed(route);
  }
}

class AppShell extends StatelessWidget {
  final Widget child;
  
  const AppShell({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if we're on a desktop platform
    final isDesktop = ResponsiveHelper.isDesktop(context);
    // Use Navigator.of(context).widget.defaultTitle to get current route
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '/dashboard';
    
    return Scaffold(
      // For desktop, use side menu; for mobile, use bottom navigation
      body: Row(
        children: [
          // Side menu for desktop
          if (isDesktop) DesktopSideMenu(
            currentRoute: currentRoute,
            onDestinationSelected: (route) {
              Navigator.of(context).pushReplacementNamed(route);
            },
          ),
          
          // Main content area
          Expanded(child: child),
        ],
      ),
      
      // Bottom navigation for mobile/tablet
      bottomNavigationBar: isDesktop 
          ? null  // No bottom nav on desktop
          : MobileBottomNavigationBar(
              currentRoute: currentRoute,
              onDestinationSelected: (route) {
                Navigator.of(context).pushReplacementNamed(route);
              },
            ),
    );
  }
}
