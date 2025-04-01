import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/cameras_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/live_view_screen.dart';
import 'screens/login_screen.dart';
import 'screens/record_view_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';
import 'utils/responsive_helper.dart';
import 'widgets/desktop_menu.dart';
import 'widgets/mobile_menu.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        '/settings': (context) => const AppShell(child: SettingsScreen()),
      },
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

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  String get _currentRoute {
    final route = ModalRoute.of(context)?.settings.name ?? '/dashboard';
    return route;
  }

  @override
  Widget build(BuildContext context) {
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
      body: Row(
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
    if (route != _currentRoute) {
      Navigator.pushReplacementNamed(context, route);
    }
    
    // Close drawer if open
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }
}