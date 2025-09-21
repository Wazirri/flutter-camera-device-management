import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart'; // Import for MediaKit
import 'package:fvp/fvp.dart' as fvp; // Import FVP for video player

import 'utils/keyboard_fix.dart'; // Import keyboard fix utilities
import 'utils/file_logger_optimized.dart'; // Import optimized file logger
import 'utils/error_monitor.dart'; // Import error monitor
import 'screens/cameras_screen.dart';
import 'screens/camera_devices_screen.dart';
import 'screens/camera_groups_screen.dart';  // New camera groups screen
import 'screens/recording_download_screen.dart';  // Recording download screen
import 'screens/dashboard_screen_optimized.dart'; // Using optimized dashboard
import 'screens/live_view_screen.dart';
import 'screens/login_screen_optimized.dart';

import 'screens/settings_screen.dart';
import 'screens/websocket_log_screen.dart';
import 'screens/multi_live_view_screen.dart';  // New multi-camera view screen
import 'screens/multi_recordings_screen.dart';  // New multi-recordings screen
import 'screens/multi_camera_view_screen.dart';  // Multi camera view screen
import 'screens/camera_layout_assignment_screen.dart';  // Camera layout assignment screen
import 'screens/activities_screen.dart';  // New activities screen
import 'theme/app_theme.dart';
import 'utils/responsive_helper.dart';
import 'utils/page_transitions.dart';
import 'widgets/desktop_side_menu.dart';
import 'widgets/mobile_bottom_navigation_bar.dart';
import 'providers/websocket_provider_optimized.dart'; // Using optimized websocket provider
import 'providers/camera_devices_provider_optimized.dart'; // Using optimized camera devices provider
import 'providers/multi_view_layout_provider.dart';
import 'providers/multi_camera_view_provider.dart'; // Multi camera view provider

Future<void> main() async {
  // This captures errors that happen during initialization
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize error monitoring
    ErrorMonitor.instance.startMonitoring();
    
    // Initialize MediaKit
    MediaKit.ensureInitialized();
    
    // Register FVP for enhanced video player support
    fvp.registerWith();
    
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
    final multiCameraViewProvider = MultiCameraViewProvider();
    
    // Connect the providers
    webSocketProvider.setCameraDevicesProvider(cameraDevicesProvider);
    cameraDevicesProvider.setWebSocketProvider(webSocketProvider);
    
    // Run the app with providers
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WebSocketProviderOptimized>.value(value: webSocketProvider),
          ChangeNotifierProvider<CameraDevicesProviderOptimized>.value(value: cameraDevicesProvider),
          ChangeNotifierProvider<MultiViewLayoutProvider>.value(value: multiViewLayoutProvider),
          ChangeNotifierProvider<MultiCameraViewProvider>.value(value: multiCameraViewProvider),
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
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle state changes at the top level
    print('App lifecycle state changed to: $state');
    
    // Get providers
    final webSocketProvider = Provider.of<WebSocketProviderOptimized>(context, listen: false);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App is resumed from background
        print('App resumed - ensuring WebSocket connection');
        if (!webSocketProvider.isConnected) {
          print('WebSocket disconnected during background, reconnecting...');
          webSocketProvider.reconnect();
        }
        break;
        
      case AppLifecycleState.paused:
        // App is paused (going to background)
        print('App paused - maintaining WebSocket connection');
        break;
        
      case AppLifecycleState.inactive:
        // App is inactive
        print('App inactive');
        break;
        
      case AppLifecycleState.detached:
        // App is detached
        print('App detached - closing connections');
        webSocketProvider.disconnect();
        break;
        
      case AppLifecycleState.hidden:
        // App is hidden
        print('App hidden - maintaining connection for background updates');
        break;
    }
    
    super.didChangeAppLifecycleState(state);
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
          '/recording-download': (context) => const AppShell(
            currentRoute: '/recording-download',
            child: RecordingDownloadScreen(),
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
            child: MultiRecordingsScreen(),
          ),
          '/multi-camera-view': (context) => const AppShell(
            currentRoute: '/multi-camera-view',
            child: MultiCameraViewScreen(),
          ),
          '/camera-layout-assignment': (context) => const AppShell(
            currentRoute: '/camera-layout-assignment',
            child: CameraLayoutAssignmentScreen(),
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
                  child: const MultiRecordingsScreen(),
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
    
    final webSocketProvider = Provider.of<WebSocketProviderOptimized>(context, listen: false);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // When app is resumed from background, check WebSocket connection
        print('App resumed - checking WebSocket connection');
        if (!webSocketProvider.isConnected) {
          print('WebSocket disconnected, attempting to reconnect...');
          webSocketProvider.reconnect();
        }
        
        // Rebuild UI if needed
        if (mounted) {
          setState(() {
            // Refresh the UI
          });
        }
        break;
        
      case AppLifecycleState.paused:
        // App is paused, keep connection but reduce activity
        print('App paused - maintaining WebSocket connection');
        break;
        
      case AppLifecycleState.inactive:
        // App is inactive (e.g., during transitions)
        print('App inactive - maintaining connection');
        break;
        
      case AppLifecycleState.detached:
        // App is detached, close connection
        print('App detached - closing WebSocket connection');
        webSocketProvider.disconnect();
        break;
        
      case AppLifecycleState.hidden:
        // App is hidden, maintain connection for background updates
        print('App hidden - maintaining WebSocket connection for background updates');
        break;
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
            DesktopSideMenu(
              currentRoute: widget.currentRoute, 
              onDestinationSelected: (route) {
                Navigator.pushReplacementNamed(context, route);
              },
            ),
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
        bottomNavigationBar: MobileBottomNavigationBar(
          currentRoute: widget.currentRoute,
          onDestinationSelected: (route) {
            Navigator.pushReplacementNamed(context, route);
          },
        ),
      );
    }
  }
}
