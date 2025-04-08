#!/usr/bin/env python3

def fix_navigation_stack():
    # main.dart dosyasını düzenleyerek, ana menülerin doğrudan ilgili sayfaya gitmesini sağla
    with open('lib/main.dart', 'r') as file:
        content = file.read()

    # Ana menülerin route tanımlarını değiştir, Navigator.push yerine Navigator.pushNamed kullanarak
    # herbir sayfayı doğrudan açıp, geri butonu olmamasını sağlayacağız
    
    # MaterialApp onGenerateRoute metodu yerine routes kullanacağız
    old_routes = '''        initialRoute: '/login',
        onGenerateRoute: (settings) {
          // Define custom page transitions for different routes
          Widget page;
          
          switch(settings.name) {
          case '/login':
            page = const LoginScreen();
            // Fade in transition for login
            return AppPageTransitions.fade(page);
            
          case '/dashboard':
            page = AppShell(
              currentRoute: settings.name ?? '/dashboard',
              child: const DashboardScreen(),
            );
            // Shared axis transition for dashboard (feels connected to login)
            return AppPageTransitions.sharedAxisHorizontal(page);
            
          case '/live-view':
            // Check if there's a camera parameter passed
            final args = settings.arguments;
            if (args is Map && args.containsKey('camera')) {
              page = AppShell(
                currentRoute: settings.name ?? '/live-view',
                child: LiveViewScreen(camera: args['camera']),
              );
            } else {
              page = AppShell(
                currentRoute: settings.name ?? '/live-view',
                child: const LiveViewScreen(),
              );
            }
            // Zoom transition for camera views to emphasize content
            return AppPageTransitions.zoomIn(page);
            
          case '/recordings':
            final args = settings.arguments;
            if (args is Map && args.containsKey('camera')) {
              page = AppShell(
                currentRoute: settings.name ?? '/recordings',
                child: RecordViewScreen(camera: args['camera']),
              );
            } else {
              page = AppShell(
                currentRoute: settings.name ?? '/recordings',
                child: const RecordViewScreen(),
              );
            }
            // Slide up transition for recordings
            return AppPageTransitions.slideUp(page);
          case '/multi-live-view':
            page = AppShell(
              currentRoute: settings.name ?? '/multi-live-view',
              child: const MultiLiveViewScreen(),
            );
            return AppPageTransitions.sharedAxisHorizontal(page);
            
          case '/cameras':
            page = AppShell(
              currentRoute: settings.name ?? '/cameras',
              child: const CamerasScreen(),
            );
            // Horizontal slide for navigation
            return AppPageTransitions.slideHorizontal(page);
            
          case '/devices':
            page = AppShell(
              currentRoute: settings.name ?? '/devices',
              child: const DevicesScreen(),
            );
            // Horizontal slide for navigation
            return AppPageTransitions.slideHorizontal(page);
            
          case '/camera-devices':
            page = AppShell(
              currentRoute: settings.name ?? '/camera-devices',
              child: const CameraDevicesScreen(),
            );
            // Horizontal slide for navigation
            return AppPageTransitions.slideHorizontal(page);
            
          case '/settings':
            page = AppShell(
              currentRoute: settings.name ?? '/settings',
              child: const SettingsScreen(),
            );
            // Scale and fade for settings to stand out
            return AppPageTransitions.scaleAndFade(page);
            
          case '/websocket-logs':
            page = const WebSocketLogScreen();
            // Slide up for overlay-like screen
            return AppPageTransitions.slideUp(page);
            
          default:
            page = AppShell(
              currentRoute: '/dashboard',
              child: const DashboardScreen(),
            );
            // Default transition
            return AppPageTransitions.fade(page);
        }
      },'''
    
    # Yeni route yapısı
    new_routes = '''        initialRoute: '/login',
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
        },'''
    
    content = content.replace(old_routes, new_routes)
    
    # _navigateToRoute metodunu değiştir - pushReplacementNamed yerine pushNamed kullan
    old_navigate = '''  void _navigateToRoute(String route) {
    try {
      if (route != widget.currentRoute) {
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
  }'''
    
    new_navigate = '''  void _navigateToRoute(String route) {
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
  }'''
    
    content = content.replace(old_navigate, new_navigate)
    
    with open('lib/main.dart', 'w') as file:
        file.write(content)
    
    return "Fixed menu navigation to prevent back button appearance"

print(fix_navigation_stack())
