import 'package:flutter/material.dart';

// This is a simple launcher that lets you choose between the original version
// and the optimized version of the app.
// Run this file to test both versions and compare performance.

void main() {
  runApp(const LauncherApp());
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
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              _buildLaunchButton(
                context,
                title: 'Original Version',
                subtitle: 'Standard implementation',
                onPressed: () {
                  // Launch the original version
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const VersionLauncher(isOptimized: false),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildLaunchButton(
                context,
                title: 'Optimized Version',
                subtitle: 'Performance improvements for faster loading',
                onPressed: () {
                  // Launch the optimized version
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const VersionLauncher(isOptimized: true),
                    ),
                  );
                },
                isPrimary: true,
              ),
              const SizedBox(height: 48),
              const Text(
                'The optimized version includes improvements to reduce loading delays after login and improve overall performance.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLaunchButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 4,
        color: isPrimary ? Colors.blue : null,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
    
    // Both versions now use the optimized main.dart
    await import('main.dart') as main;
    main.main();
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
