import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'utils/error_monitor.dart';
import 'utils/file_logger_optimized.dart';

// This is an optimized launcher that prevents "too many open files" errors
// and provides better error handling.

void main() {
  // Set up error handling early
  ErrorMonitor.instance.startMonitoring();
  
  // Disable file logging for web platform
  if (kIsWeb) {
    FileLoggerOptimized.disableLogging();
  }
  
  // Run the app with error handling
  runZonedGuarded(
    () => runApp(const LauncherApp()),
    (error, stack) {
      print('Caught error: $error');
      
      // Check for file system errors
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('too many open files') || 
          errorString.contains('errno = 24')) {
        FileLoggerOptimized.disableLogging();
        print('Logları dosyaya yazma işini iptal edildi. (File logging has been disabled)');
      }
    },
  );
}

class LauncherApp extends StatelessWidget {
  const LauncherApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECS Launcher',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LauncherScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LauncherScreen extends StatelessWidget {
  const LauncherScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('movita ECS Launcher'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.launch,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'movita ECS Camera Management',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Select a version to launch:',
                style: TextStyle(
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              _buildVersionButton(
                context,
                title: 'Optimized Version',
                subtitle: 'Faster performance, better memory and resource management',
                isPrimary: true,
                isOptimized: true,
              ),
              const SizedBox(height: 16),
              _buildVersionButton(
                context,
                title: 'Original Version',
                subtitle: 'The standard version of the application',
                isPrimary: false,
                isOptimized: false,
              ),
              const SizedBox(height: 36),
              // System status card
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Performance Optimizations',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '✓ Reduced memory usage',
                        style: TextStyle(height: 1.5),
                      ),
                      const Text(
                        '✓ Faster dashboard loading',
                        style: TextStyle(height: 1.5),
                      ),
                      const Text(
                        '✓ Optimized file handling',
                        style: TextStyle(height: 1.5),
                      ),
                      const Text(
                        '✓ Improved error resilience',
                        style: TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isPrimary,
    required bool isOptimized,
  }) {
    return Card(
      elevation: 3,
      color: isPrimary ? Colors.blue : null,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => VersionLauncher(isOptimized: isOptimized),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isPrimary ? Icons.flash_on : Icons.play_arrow,
                    color: isPrimary ? Colors.white : Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isPrimary ? Colors.white : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: isPrimary ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VersionLauncher extends StatefulWidget {
  final bool isOptimized;

  const VersionLauncher({
    Key? key,
    required this.isOptimized,
  }) : super(key: key);

  @override
  State<VersionLauncher> createState() => _VersionLauncherState();
}

class _VersionLauncherState extends State<VersionLauncher> {
  @override
  void initState() {
    super.initState();
    
    // Launch the appropriate version
    _launchApp();
  }
  
  Future<void> _launchApp() async {
    // Small delay to let the UI render first
    await Future.delayed(Duration.zero);
    
    if (widget.isOptimized) {
      // Run the optimized version with error handling
      await import('main_optimized.dart') as optimized;
      optimized.main();
    } else {
      // Run the original version
      await import('main.dart') as original;
      original.main();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              'Launching ${widget.isOptimized ? 'Optimized' : 'Original'} Version...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
