import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart'; // Import for MediaKit

import 'utils/keyboard_fix.dart'; // Import keyboard fix utilities
import 'utils/file_logger_optimized.dart'; // Import optimized file logger
import 'utils/error_monitor.dart'; // Import error monitor
import 'screens/cameras_screen.dart';
import 'screens/camera_devices_screen.dart';
import 'screens/camera_groups_screen.dart';  // New camera groups screen
import 'screens/dashboard_screen_optimized.dart'; // Using optimized dashboard
import 'screens/devices_screen.dart';
import 'screens/live_view_screen.dart';
import 'screens/login_screen_optimized.dart';
import 'screens/record_view_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/websocket_log_screen.dart';
import 'screens/multi_live_view_screen.dart';  // New multi-camera view screen
import 'screens/multi_recordings_screen.dart';  // New multi-recordings screen
import 'screens/activities_screen.dart';  // New activities screen
import 'theme/app_theme.dart';
import 'utils/responsive_helper.dart';
import 'utils/page_transitions.dart';
import 'widgets/desktop_side_menu.dart';
import 'widgets/mobile_bottom_navigation_bar.dart';
import 'providers/websocket_provider_optimized.dart'; // Using optimized websocket provider
import 'providers/camera_devices_provider_optimized.dart'; // Using optimized camera devices provider
import 'providers/multi_view_layout_provider.dart';

Future<void> main() async {
  // This captures errors that happen during initialization
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize error monitoring
    ErrorMonitor.instance.startMonitoring();
    
    // Initialize MediaKit
    MediaKit.ensureInitialized();
    
    // Initialize optimized file logger with error protection
    await FileLoggerOptimized.init();
    
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
          print('Configuring iOS/macOS specific settings');
        }
      } catch (e) {
        print('Error setting orientations: $e');
      }
    }
    
    // Create optimized providers
    final webSocketProvider = WebSocketProviderOptimized();
    final cameraDevicesProvider = CameraDevicesProviderOptimized();
    final multiViewLayoutProvider = MultiViewLayoutProvider();
    
    // Connect the providers
    webSocketProvider.setCameraDevicesProvider(cameraDevicesProvider);
    
    // Run the app with providers
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WebSocketProviderOptimized>.value(value: webSocketProvider),
          ChangeNotifierProvider<CameraDevicesProviderOptimized>.value(value: cameraDevicesProvider),
          ChangeNotifierProvider<MultiViewLayoutProvider>.value(value: multiViewLayoutProvider),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stackTrace) {
    // Log any errors that occur during initialization
    print('Caught error: $error');
    print('Stack trace: $stackTrace');
    
    // Check for file system errors
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('too many open files') || 
        errorString.contains('errno = 24')) {
      FileLoggerOptimized.disableLogging();
      print('Logları dosyaya yazma işini iptal edildi. (File logging has been disabled)');
    }
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
    print('App lifecycle state changed to: $state');
    
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
          '/': (context) => const LoginScreenOptimized(),
          '/login': (context) => const LoginScreenOptimized(),
          '/dashboard': (context) => const AppShell(
            currentRoute: '/dashboard',
            child: DashboardScreenOptimized(), // Using optimized dashboard
          ),
          '/cameras': (context) => const AppShell(
            currentRoute: '/cameras',
            child: CamerasScreen(),
          ),
          '/camera-groups': (context) => const AppShell(
            currentRoute: '/camera-groups',
            child: CameraGroupsScreen(),
          ),
          '/devices': (context) => const AppShell(
            currentRoute: '/devices',
            child: DevicesScreen(),
          ),
          '/settings': (context) => const AppShell(
            currentRoute: '/settings',
            child: SettingsScreen(),
          ),
          '/camera-devices': (context) => const AppShell(
            currentRoute: '/camera-devices',
            child: CameraDevicesScreen(),
          ),
          '/websocket-logs': (context) => const AppShell(
            currentRoute: '/websocket-logs',
            child: WebSocketLogScreen(),
          ),
          '/multi-live-view': (context) => const AppShell(
            currentRoute: '/multi-live-view',
            child: MultiLiveViewScreen(),
          ),
          '/multi-recordings': (context) => const AppShell(
            currentRoute: '/multi-recordings',
            child: MultiRecordingsScreen(),
          ),
          '/activities': (context) => const AppShell(
            currentRoute: '/activities',
            child: ActivitiesScreen(),
          ),
          '/live-view': (context) => const AppShell(
            currentRoute: '/live-view',
            child: LiveViewScreen(camera: null),
          ),
          '/recordings': (context) => const AppShell(
            currentRoute: '/recordings',
            child: RecordViewScreen(camera: null),
          ),
        },
        // Custom page transitions and routes that require parameters
        onGenerateRoute: (settings) {
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
          
          // Default back to the routes if no custom handling was performed
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
    // Register observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove observer when app is disposed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle state changes
    print('AppShell lifecycle state: $state');
    
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
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isLargeScreen = isDesktop || isTablet;

    if (isLargeScreen) {
      return Scaffold(
        key: _scaffoldKey,
        body: Row(
          children: [
            // Side menu for desktop/tablet
            DesktopSideMenu(currentRoute: widget.currentRoute),
            // Main content area
            Expanded(
              child: ClipRRect(
                // Use ClipRRect to avoid rendering issues with video players
                child: Material(
                  color: AppTheme.darkBackground,
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile layout with bottom navigation
      return Scaffold(
        key: _scaffoldKey,
        body: SafeArea(
          child: Material(
            color: AppTheme.darkBackground,
            child: widget.child,
          ),
        ),
        bottomNavigationBar: const MobileBottomNavigationBar(),
      );
    }
  }
}
