import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart'; // Import for MediaKit
import 'package:fvp/fvp.dart' as fvp; // Import FVP for video player

import 'utils/keyboard_fix.dart'; // Import keyboard fix utilities
import 'utils/file_logger.dart'; // Import optimized file logger
import 'utils/error_monitor.dart'; // Import error monitor
import 'screens/cameras_screen.dart';
import 'screens/all_cameras_screen.dart';
import 'screens/camera_devices_screen.dart';
import 'screens/camera_groups_screen.dart';  // New camera groups screen
import 'screens/recording_download_screen.dart';  // Recording download screen
import 'screens/user_group_management_screen.dart';  // User and group management screen
import 'screens/dashboard_screen.dart'; // Using optimized dashboard
import 'screens/live_view_screen.dart';
import 'screens/login_screen.dart';

import 'screens/settings_screen.dart';
import 'screens/websocket_log_screen.dart';
import 'screens/multi_live_view_screen.dart';  // New multi-camera view screen
import 'screens/multi_recordings_screen.dart';  // New multi-recordings screen
import 'screens/multi_camera_view_screen.dart';  // Multi camera view screen
import 'screens/camera_layout_assignment_screen.dart';  // Camera layout assignment screen
import 'screens/activities_screen.dart';  // New activities screen
import 'screens/live_recording_screen.dart';  // Live recording screen
import 'theme/app_theme.dart';
import 'utils/responsive_helper.dart';
import 'utils/page_transitions.dart';
import 'widgets/desktop_side_menu.dart';
import 'widgets/mobile_bottom_navigation_bar.dart';
import 'providers/websocket_provider.dart'; // Using optimized websocket provider
import 'providers/camera_devices_provider.dart'; // Using optimized camera devices provider
import 'providers/multi_view_layout_provider.dart';
import 'providers/multi_camera_view_provider.dart'; // Multi camera view provider
import 'providers/user_group_provider.dart'; // User group provider
import 'providers/conversion_tracking_provider.dart'; // Conversion tracking provider
import 'providers/notification_provider.dart'; // Notification provider for session messages

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
    final userGroupProvider = UserGroupProvider();
    final conversionTrackingProvider = ConversionTrackingProvider();
    final notificationProvider = NotificationProvider();
    
    // Initialize conversion tracking with websocket provider
    conversionTrackingProvider.initialize(webSocketProvider);
    
    // Connect the providers
    webSocketProvider.setCameraDevicesProvider(cameraDevicesProvider);
    webSocketProvider.setUserGroupProvider(userGroupProvider);
    webSocketProvider.setConversionTrackingProvider(conversionTrackingProvider);
    cameraDevicesProvider.setWebSocketProvider(webSocketProvider);
    cameraDevicesProvider.setUserGroupProvider(userGroupProvider);
    
    // Run the app with providers
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WebSocketProviderOptimized>.value(value: webSocketProvider),
          ChangeNotifierProvider<CameraDevicesProviderOptimized>.value(value: cameraDevicesProvider),
          ChangeNotifierProvider<MultiViewLayoutProvider>.value(value: multiViewLayoutProvider),
          ChangeNotifierProvider<MultiCameraViewProvider>.value(value: multiCameraViewProvider),
          ChangeNotifierProvider<UserGroupProvider>.value(value: userGroupProvider),
          ChangeNotifierProvider<ConversionTrackingProvider>.value(value: conversionTrackingProvider),
          ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
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
        // Only reconnect if user was previously logged in
        if (!webSocketProvider.isConnected && webSocketProvider.isLoggedIn) {
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
          '/user-group-management': (context) => const AppShell(
            currentRoute: '/user-group-management',
            child: UserGroupManagementScreen(),
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
          '/all-cameras': (context) => const AppShell(
            currentRoute: '/all-cameras',
            child: AllCamerasScreen(),
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
    
    // Setup global conversion complete callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupConversionCallbacks();
    });
  }
  
  void _setupConversionCallbacks() {
    final trackingProvider = Provider.of<ConversionTrackingProvider>(context, listen: false);
    final webSocketProvider = Provider.of<WebSocketProviderOptimized>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    
    // Set callback for combined result messages (send + device response in one popup)
    webSocketProvider.onCombinedResultMessage = (commandType, sendResult, deviceResult, 
        sendMessage, deviceMessage, {String? mac, String? commandText}) {
      if (mounted) {
        // Determine overall status
        final sendSuccess = sendResult == 1;
        final deviceSuccess = deviceResult == 1;
        final devicePending = deviceResult == -1;
        final deviceError = deviceResult == 0;
        
        // Choose icon and color based on combined status
        IconData icon;
        Color color;
        String statusEmoji;
        
        if (sendSuccess && deviceSuccess) {
          // Both successful
          icon = Icons.check_circle;
          color = Colors.green.shade600;
          statusEmoji = '✅';
        } else if (sendSuccess && devicePending) {
          // Sent but waiting for device
          icon = Icons.hourglass_empty;
          color = Colors.orange.shade600;
          statusEmoji = '⏳';
        } else if (sendSuccess && deviceError) {
          // Sent successfully but device reported error
          icon = Icons.warning_amber;
          color = Colors.orange.shade700;
          statusEmoji = '⚠️';
        } else {
          // Send failed
          icon = Icons.error_outline;
          color = Colors.red.shade600;
          statusEmoji = '❌';
        }
        
        // Build display text
        final shortMac = mac != null && mac.length > 8 
            ? '...${mac.substring(mac.length - 8)}' 
            : (mac ?? '');
        
        // Shorten command text
        String shortCommand = commandText ?? '';
        if (shortCommand.length > 30) {
          shortCommand = '${shortCommand.substring(0, 30)}...';
        }
        
        // Build status lines
        final sendStatusIcon = sendSuccess ? '✓' : '✗';
        String deviceStatusIcon;
        String deviceStatusText;
        if (devicePending) {
          deviceStatusIcon = '⏳';
          deviceStatusText = 'Bekleniyor...';
        } else if (deviceSuccess) {
          deviceStatusIcon = '✓';
          deviceStatusText = deviceMessage.isNotEmpty ? deviceMessage : 'Başarılı';
        } else {
          deviceStatusIcon = '✗';
          deviceStatusText = deviceMessage.isNotEmpty ? deviceMessage : 'Hata';
        }
        
        // Log to NotificationProvider
        final logMessage = '[$shortMac] $shortCommand\n'
            'Gönderim: ${sendSuccess ? "Başarılı" : "Hata"}\n'
            'Sonuç: $deviceStatusText';
        notificationProvider.addNotification(
          message: logMessage,
          type: deviceSuccess ? NotificationType.success 
              : (devicePending ? NotificationType.warning : NotificationType.error),
          cameraMac: mac,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with MAC
                      Text(
                        '$statusEmoji [$shortMac] $shortCommand',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Two-line status
                      Row(
                        children: [
                          Text(
                            '$sendStatusIcon Gönderim: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: sendSuccess ? Colors.green.shade100 : Colors.red.shade100,
                            ),
                          ),
                          Text(
                            sendSuccess ? 'Başarılı' : 'Hata',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: sendSuccess ? Colors.green.shade100 : Colors.red.shade100,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '$deviceStatusIcon Sonuç: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: deviceSuccess 
                                  ? Colors.green.shade100 
                                  : (devicePending ? Colors.orange.shade100 : Colors.red.shade100),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              deviceStatusText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: deviceSuccess 
                                    ? Colors.green.shade100 
                                    : (devicePending ? Colors.orange.shade100 : Colors.red.shade100),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: color,
            duration: Duration(seconds: deviceSuccess ? 3 : 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    };
    
    // Set callback for WebSocket result messages (non-COMMAND types)
    webSocketProvider.onResultMessage = (commandType, result, message, {String? mac, String? commandText}) {
      if (mounted && message.isNotEmpty) {
        final isSuccess = result == 1;
        final icon = isSuccess ? Icons.check_circle : Icons.error_outline;
        final color = isSuccess ? Colors.green.shade600 : Colors.red.shade600;
        final emoji = isSuccess ? '✅' : '❌';
        
        // Log to NotificationProvider
        notificationProvider.addNotification(
          message: '$commandType: $message',
          type: isSuccess ? NotificationType.success : NotificationType.error,
        );
        
        // Build display text with MAC and command info if available
        String displayTitle = '$emoji $commandType';
        String displaySubtitle = message;
        if (mac != null && mac.isNotEmpty) {
          displaySubtitle = '[$mac] $message';
        }
        if (commandText != null && commandText.isNotEmpty) {
          // Show shortened command text
          final shortCommand = commandText.length > 50 
              ? '${commandText.substring(0, 50)}...' 
              : commandText;
          displaySubtitle = '$displaySubtitle\n→ $shortCommand';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        displaySubtitle,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: color,
            duration: Duration(seconds: isSuccess ? 3 : 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    };
    
    // Set callback for two-phase notifications (e.g., CLEARCAMS)
    webSocketProvider.onTwoPhaseNotification = (phase, mac, message) {
      if (mounted) {
        final isPhase1 = phase == 1;
        final icon = isPhase1 ? Icons.send : Icons.check_circle;
        final color = isPhase1 ? Colors.blue.shade600 : Colors.green.shade600;
        final phaseText = isPhase1 ? '1/2' : '2/2';
        final checkMark = isPhase1 ? '📤' : '✅';
        
        // Log to NotificationProvider
        notificationProvider.addNotification(
          message: 'CLEARCAMS [$phaseText]: $message',
          type: isPhase1 ? NotificationType.info : NotificationType.success,
        );
        
        // Get short MAC for display
        final shortMac = mac.length > 8 ? '...${mac.substring(mac.length - 8)}' : mac;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$checkMark CLEARCAMS [$phaseText]',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        '[$shortMac] $message',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: color,
            duration: Duration(seconds: isPhase1 ? 2 : 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    };
    
    // Set callback for when conversion completes
    trackingProvider.onConversionComplete = (conversion) {
      if (mounted) {
        // Log to NotificationProvider
        notificationProvider.addSuccess(
          'Dönüştürme Tamamlandı: ${conversion.cameraName} (${conversion.startTime} - ${conversion.endTime})',
          cameraName: conversion.cameraName,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '✅ Dönüştürme Tamamlandı!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${conversion.cameraName} (${conversion.startTime} - ${conversion.endTime})',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'İndir',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/recording-download');
              },
            ),
          ),
        );
      }
    };
    
    // Set callback for conversion errors
    trackingProvider.onConversionError = (conversion, error) {
      if (mounted) {
        // Log to NotificationProvider
        notificationProvider.addError(
          'Dönüştürme Hatası: ${conversion.cameraName}: $error',
          cameraName: conversion.cameraName,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('❌ ${conversion.cameraName}: $error'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    };
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
        // Only reconnect if user was previously logged in
        if (!webSocketProvider.isConnected && webSocketProvider.isLoggedIn) {
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
                  child: Column(
                    children: [
                      // Global conversion tracking banner
                      _buildConversionBanner(context),
                      // Main content
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // Global floating notification button
        floatingActionButton: _buildNotificationFab(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
      );
    } else {
      // Mobile layout with bottom navigation
      return Scaffold(
        key: _scaffoldKey,
        body: SafeArea(
          child: Material(
            color: AppTheme.darkBackground,
            child: Column(
              children: [
                // Global conversion tracking banner
                _buildConversionBanner(context),
                // Main content
                Expanded(child: widget.child),
              ],
            ),
          ),
        ),
        bottomNavigationBar: MobileBottomNavigationBar(
          currentRoute: widget.currentRoute,
          onDestinationSelected: (route) {
            Navigator.pushReplacementNamed(context, route);
          },
        ),
        // Global floating notification button
        floatingActionButton: _buildNotificationFab(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
      );
    }
  }

  /// Build floating action button for notifications
  Widget _buildNotificationFab(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Stack(
            children: [
              FloatingActionButton.small(
                heroTag: 'notification_fab',
                onPressed: () => _showNotificationsPanel(context),
                backgroundColor: AppTheme.darkSurface,
                child: Icon(
                  notificationProvider.hasUnread
                      ? Icons.notifications_active
                      : Icons.notifications_outlined,
                  color: notificationProvider.hasUnread
                      ? AppTheme.primaryOrange
                      : Colors.grey,
                ),
              ),
              if (notificationProvider.hasUnread)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      notificationProvider.unreadCount > 99
                          ? '99+'
                          : notificationProvider.unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Show notifications panel
  void _showNotificationsPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Consumer<NotificationProvider>(
          builder: (context, notificationProvider, child) {
            final notifications = notificationProvider.notifications;
            
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.notifications, color: AppTheme.primaryOrange),
                      const SizedBox(width: 8),
                      const Text(
                        'Bildirimler',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      if (notificationProvider.hasUnread)
                        TextButton(
                          onPressed: () {
                            notificationProvider.markAllAsRead();
                          },
                          child: const Text('Tümünü Okundu İşaretle'),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                        onPressed: notifications.isEmpty
                            ? null
                            : () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AppTheme.darkSurface,
                                    title: const Text('Tüm Bildirimleri Sil',
                                        style: TextStyle(color: Colors.white)),
                                    content: const Text(
                                        'Tüm bildirimler silinecek. Emin misiniz?',
                                        style: TextStyle(color: Colors.grey)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('İptal'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          notificationProvider.clearAll();
                                          Navigator.pop(ctx);
                                        },
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red),
                                        child: const Text('Sil'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${notifications.length} bildirim',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.grey),
                  
                  // Notifications list
                  Expanded(
                    child: notifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none,
                                    size: 64, color: Colors.grey.shade700),
                                const SizedBox(height: 16),
                                Text(
                                  'Henüz bildirim yok',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final notification = notifications[index];
                              return Dismissible(
                                key: Key(notification.id),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) {
                                  notificationProvider.removeNotification(notification.id);
                                },
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: Colors.red,
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: notification.color.withValues(alpha: 0.2),
                                    child: Icon(notification.icon, color: notification.color, size: 20),
                                  ),
                                  title: Text(
                                    notification.message,
                                    style: TextStyle(
                                      color: notification.isRead ? Colors.grey : Colors.white,
                                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Row(
                                    children: [
                                      if (notification.cameraMac != null) ...[
                                        Icon(Icons.videocam, size: 12, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          notification.cameraMac!.length > 8
                                              ? '...${notification.cameraMac!.substring(notification.cameraMac!.length - 8)}'
                                              : notification.cameraMac!,
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        notification.formattedTime,
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  trailing: !notification.isRead
                                      ? Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppTheme.primaryOrange,
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                      : null,
                                  onTap: () {
                                    if (!notification.isRead) {
                                      notificationProvider.markAsRead(notification.id);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildConversionBanner(BuildContext context) {
    return Consumer<ConversionTrackingProvider>(
      builder: (context, trackingProvider, child) {
        final pendingConversions = trackingProvider.pendingConversions.where((c) => !c.isComplete).toList();
        
        if (pendingConversions.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade700, Colors.orange.shade500],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '🔄 ${pendingConversions.length} dönüştürme devam ediyor: ${pendingConversions.map((c) => c.cameraName).join(", ")}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => Navigator.pushReplacementNamed(context, '/recording-download'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Detay',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
