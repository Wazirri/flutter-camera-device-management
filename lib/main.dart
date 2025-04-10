import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart'; // Import for MediaKit

import 'utils/keyboard_fix.dart'; // Import keyboard fix utilities
import 'utils/keyboard_fix.dart'; // Import keyboard fix utilities
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
    
    // Create providers first
    final webSocketProvider = WebSocketProvider();
    final cameraDevicesProvider = CameraDevicesProvider();
    final multiViewLayoutProvider = MultiViewLayoutProvider();
    
    // Connect the providers
    webSocketProvider.setCameraDevicesProvider(cameraDevicesProvider);
    
    // Run the app with providers
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WebSocketProvider>.value(value: webSocketProvider),
          ChangeNotifierProvider<CameraDevicesProvider>.value(value: cameraDevicesProvider),
          ChangeNotifierProvider<MultiViewLayoutProvider>.value(value: multiViewLayoutProvider),
        ],
        child: const MyApp(),
      ),
    );
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
  // Klavye olaylarını takip etmek için HardwareKeyboard'u kullanacağız
  final HardwareKeyboard _hardwareKeyboard = HardwareKeyboard.instance;
  final Set<PhysicalKeyboardKey> _physicalKeysPressed = <PhysicalKeyboardKey>{};
  
  @override
  void initState() {
    super.initState();
    // Register observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Klavye olay dinleyicisini ekle
    _hardwareKeyboard.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    // Klavye olay dinleyicisini kaldır
    _hardwareKeyboard.removeHandler(_handleKeyEvent);
    
    // Remove observer when app is disposed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  // Klavye olaylarını işleyen fonksiyon
  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Eğer tuş zaten basılı olarak işaretliyse, bu tuşun basılmasını yoksay
      if (_physicalKeysPressed.contains(event.physicalKey)) {
        return true; // Olayı tükettik ve uygulamaya gitmesini engelledik
      }
      // Değilse, tuşu basılı olarak işaretle
      _physicalKeysPressed.add(event.physicalKey);
    } else if (event is KeyUpEvent) {
      // Tuşun bırakıldığını işaretle
      _physicalKeysPressed.remove(event.physicalKey);
    }
    return false; // Olayı normal şekilde işle
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
    return KeyboardFixWrapper(
      child: MaterialApp(
        title: 'movita ECS',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => AppShell(
              currentRoute: '/dashboard',
              child: const DashboardScreen(),
            ),
          '/live-view': (context) => AppShell(
              currentRoute: '/live-view',
              child: const LiveViewScreen(),
            ),
          '/recordings': (context) => AppShell(
              currentRoute: '/recordings',
              child: const RecordViewScreen(),
            ),
          '/multi-live-view': (context) => AppShell(
              currentRoute: '/multi-live-view',
              child: const MultiLiveViewScreen(),
            ),
          '/cameras': (context) => AppShell(
              currentRoute: '/cameras',
              child: const CamerasScreen(),
            ),
          '/devices': (context) => AppShell(
              currentRoute: '/devices',
              child: const DevicesScreen(),
            ),
          '/camera-devices': (context) => AppShell(
              currentRoute: '/camera-devices',
              child: const CameraDevicesScreen(),
            ),
          '/settings': (context) => AppShell(
              currentRoute: '/settings',
              child: const SettingsScreen(),
            ),
          '/websocket-logs': (context) => const WebSocketLogScreen(),
        },
        // Özel geçişler ve parametreli rotalar için onGenerateRoute
        onGenerateRoute: (settings) {
          // Define custom page transitions for certain routes
          Widget? page;
          
          switch(settings.name) {
            case '/live-view':
              // Check if there's a camera parameter passed
              final args = settings.arguments;
              if (args is Map && args.containsKey('camera')) {
                page = AppShell(
                  currentRoute: settings.name ?? '/live-view',
                  child: LiveViewScreen(camera: args['camera']),
                );
                return AppPageTransitions.zoomIn(page);
              }
              break;
              
            case '/recordings':
              final args = settings.arguments;
              if (args is Map && args.containsKey('camera')) {
                page = AppShell(
                  currentRoute: settings.name ?? '/recordings',
                  child: RecordViewScreen(camera: args['camera']),
                );
                return AppPageTransitions.slideUp(page);
              }
              break;
          }
          
          // Özel bir durum yoksa routes'a düşer
          return null;
        },
    ),
    );
  }
}

class AppShell extends StatefulWidget {
  final Widget child;
  final String currentRoute;

  const AppShell({
    Key? key,
    required this.child,
    required this.currentRoute,
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

  @override
  Widget build(BuildContext context) {
    // Determine device type for responsive layout
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return Scaffold(
      key: _scaffoldKey,
      // Ana menülerden otomatik geri butonunu devre dışı bırak
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Ana menülerde geri butonu gösterme
        toolbarHeight: 0, // AppBar görünmez yap ama kontrolü sağla
      ),
      drawer: isMobile
          ? SizedBox(
              width: 250,
              child: DesktopSideMenu(
                currentRoute: widget.currentRoute,
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
                currentRoute: widget.currentRoute,
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
              currentRoute: widget.currentRoute,
              onDestinationSelected: _navigateToRoute,
            )
          : null,
    );
  }

  void _navigateToRoute(String route) {
    try {
      if (route != widget.currentRoute) {
        // Mevcut sayfayı tamamen kaldır ve yeni sayfayı aç
        // böylece geri butonu olmayacak
        Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
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
