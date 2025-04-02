import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'theme/app_theme.dart';
import 'utils/responsive_helper.dart';
import 'widgets/desktop_side_menu.dart';
import 'widgets/mobile_bottom_navigation_bar.dart';
import 'providers/websocket_provider.dart';
import 'providers/camera_devices_provider.dart';

Future<void> main() async {
  // This captures errors that happen during initialization
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize MediaKit
    MediaKit.ensureInitialized();
    
    // Set orientations (only for mobile platforms)
    if (!kIsWeb) {
      try {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        
        // Set specific platform settings
        if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
          // iOS/macOS specific settings if needed
          debugPrint('Configuring iOS/macOS specific settings');
        }
      } catch (e) {
        debugPrint('Error setting orientations: $e');
      }
    }
    
    // Run the app
    runApp(const MyApp());
  }, (error, stackTrace) {
    // Log any errors that occur during initialization
    debugPrint('Caught error: $error');
    debugPrint('Stack trace: $stackTrace');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Register observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Connect the providers
    Future.microtask(() {
      final webSocketProvider = Provider.of<WebSocketProvider>(context, listen: false);
      final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
      
      // Set camera devices provider in websocket provider
      webSocketProvider.setCameraDevicesProvider(cameraDevicesProvider);
    });
  }

  @override
  void dispose() {
    // Remove observer when app is disposed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    debugPrint('App lifecycle state changed to: $state');
    
    // Handle specific state changes if needed
    switch (state) {
      case AppLifecycleState.resumed:
        // App is visible and responding to user input
        break;
      case AppLifecycleState.inactive:
        // App is inactive, happens when notifications or modal alerts appear
        break;
      case AppLifecycleState.paused:
        // App is not visible
        break;
      case AppLifecycleState.detached:
        // Application is in detached state (applicable for iOS and Android)
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WebSocketProvider()),
        ChangeNotifierProvider(create: (_) => CameraDevicesProvider()),
      ],
      child: MaterialApp(
        title: 'Camera Device Manager',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const AppShell(child: DashboardScreen()),
          '/live-view': (context) => const AppShell(child: LiveViewScreen()),
          '/recordings': (context) => const AppShell(child: RecordViewScreen()),
          '/cameras': (context) => const AppShell(child: CamerasScreen()),
          '/devices': (context) => const AppShell(child: DevicesScreen()),
          '/camera-devices': (context) => const AppShell(child: CameraDevicesScreen()),
          '/settings': (context) => const AppShell(child: SettingsScreen()),
          '/websocket-logs': (context) => const WebSocketLogScreen(),
        },
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  @override
  void initState() {
    super.initState();
    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Clean up observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle state changes
    debugPrint('AppShell lifecycle state: $state');
    
    if (state == AppLifecycleState.resumed) {
      // When app is resumed from background, rebuild UI if needed
      if (mounted) {
        setState(() {
          // Refresh the UI
        });
      }
    }
  }

  String get _currentRoute {
    final route = ModalRoute.of(context)?.settings.name ?? '/dashboard';
    return route;
  }

  @override
  Widget build(BuildContext context) {
    // Determine device type for responsive layout
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return Scaffold(
      key: _scaffoldKey,
      drawer: isMobile
          ? SizedBox(
              width: 250,
              child: DesktopSideMenu(
                currentRoute: _currentRoute,
                onDestinationSelected: _navigateToRoute,
              ),
            )
          : null,
      body: SafeArea(
        child: Row(
          children: [
            // Desktop side menu
            if (isDesktop || isTablet)
              DesktopSideMenu(
                currentRoute: _currentRoute,
                onDestinationSelected: _navigateToRoute,
              ),
            
            // Main content
            Expanded(
              child: widget.child,
            ),
          ],
        ),
      ),
      // Mobile bottom navigation
      bottomNavigationBar: isMobile
          ? MobileBottomNavigationBar(
              currentRoute: _currentRoute,
              onDestinationSelected: _navigateToRoute,
            )
          : null,
    );
  }

  void _navigateToRoute(String route) {
    try {
      if (route != _currentRoute) {
        Navigator.pushReplacementNamed(context, route);
      }
      
      // Close drawer if open
      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Handle any navigation errors
      debugPrint('Navigation error: $e');
    }
  }
}