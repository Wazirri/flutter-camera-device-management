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
import 'screens/multi_live_view_screen.dart';  // New multi-camera view screen
import 'providers/settings_provider.dart';
import 'theme/app_theme.dart';
import 'utils/page_transitions.dart';
import 'utils/responsive_helper.dart';
import 'utils/page_transitions.dart';
import 'widgets/desktop_side_menu.dart';
import 'widgets/mobile_bottom_navigation_bar.dart';
import 'providers/websocket_provider.dart';
import 'providers/camera_devices_provider.dart';

void main() async {
  // Ensure that MediaKit is initialized
  MediaKit.ensureInitialized();
  
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set orientation preferences
  if (!kIsWeb) {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
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
      }
    } catch (e) {
      debugPrint('Error setting orientations: $e');
    }
  }
  
  // Create providers first
  final webSocketProvider = WebSocketProvider();
  final cameraDevicesProvider = CameraDevicesProvider();
  final settingsProvider = SettingsProvider();
  
  // Connect the providers
  webSocketProvider.setCameraDevicesProvider(cameraDevicesProvider);
  
  // Run the app with providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WebSocketProvider>.value(value: webSocketProvider),
        ChangeNotifierProvider<CameraDevicesProvider>.value(value: cameraDevicesProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  @override
  void initState() {
    super.initState();
    
    // Initialize auto-connect if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Get providers
      final wsProvider = Provider.of<WebSocketProvider>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      // Wait for settings to be initialized
      if (!settingsProvider.isInitialized) {
        // Wait for settings to load (you can add a proper future wait here)
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Auto-connect if enabled
      if (settingsProvider.autoConnect && !wsProvider.isConnected) {
        wsProvider.connect(
          settingsProvider.serverIp,
          settingsProvider.serverPort,
          settingsProvider.username,
          settingsProvider.password,
        );
      }
    });
  }
  
  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use settings provider to get theme mode
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final themeMode = settingsProvider.darkMode ? ThemeMode.dark : ThemeMode.light;
    
    return MaterialApp(
      title: 'Camera Device Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: Builder(
        builder: (context) {
          final isDesktop = ResponsiveHelper.isDesktop(context);
          
          // Main screen list
          final List<Widget> _screens = [
            const DashboardScreen(),
            const CamerasScreen(),
            const DevicesScreen(),
            // New Multi Live View Screen
            const MultiLiveViewScreen(),
          ];
          
          return Scaffold(
            key: _scaffoldKey,
            drawer: isDesktop ? null : const DesktopSideMenu(),
            body: Row(
              children: [
                // Show side menu on desktop
                if (isDesktop) const DesktopSideMenu(),
                
                // Main content area
                Expanded(
                  child: _screens[_currentIndex],
                ),
              ],
            ),
            
            // Show bottom navigation on mobile
            bottomNavigationBar: isDesktop
                ? null
                : MobileBottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: _onItemTapped,
                  ),
          );
        },
      ),
      
      // Route generator for named routes
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return buildPageTransition(const LoginScreen());
          case '/cameras':
            return buildPageTransition(const CamerasScreen());
          case '/devices':
            return buildPageTransition(const DevicesScreen());
          case '/camera_devices':
            return buildPageTransition(const CameraDevicesScreen());
          case '/dashboard':
            return buildPageTransition(const DashboardScreen());
          case '/live_view':
            final args = settings.arguments as Map<String, dynamic>?;
            final cameraId = args?['cameraId'] as String? ?? '';
            return buildPageTransition(LiveViewScreen(cameraId: cameraId));
          case '/record_view':
            final args = settings.arguments as Map<String, dynamic>?;
            final cameraId = args?['cameraId'] as String? ?? '';
            return buildPageTransition(RecordViewScreen(cameraId: cameraId));
          case '/multi_live_view':
            return buildPageTransition(const MultiLiveViewScreen());
          case '/settings':
            return buildPageTransition(const SettingsScreen());
          case '/websocket_log':
            return buildPageTransition(const WebSocketLogScreen());
          default:
            return null;
        }
      },
    );
  }
}

  // Helper method to create consistent page transitions across the app
  Widget buildPageTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        
        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    ).buildPage(null, null, null);
  }
