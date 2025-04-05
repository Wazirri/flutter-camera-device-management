import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/websocket_provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Text editing controllers
  late TextEditingController _serverIpController;
  late TextEditingController _serverPortController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _slideshowIntervalController;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _serverIpController = TextEditingController(text: settings.serverIp);
    _serverPortController = TextEditingController(text: settings.serverPort.toString());
    _usernameController = TextEditingController(text: settings.username);
    _passwordController = TextEditingController(text: settings.password);
    _slideshowIntervalController = TextEditingController(text: settings.slideshowInterval.toString());
  }
  
  @override
  void dispose() {
    // Dispose controllers
    _serverIpController.dispose();
    _serverPortController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _slideshowIntervalController.dispose();
    super.dispose();
  }
  
  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final wsProvider = Provider.of<WebSocketProvider>(context, listen: false);
      
      // Save connection settings
      settingsProvider.setConnectionParams(
        serverIp: _serverIpController.text,
        serverPort: int.parse(_serverPortController.text),
        username: _usernameController.text,
        password: _passwordController.text,
      );
      
      // Save slideshow interval
      settingsProvider.setSlideshowInterval(
        double.parse(_slideshowIntervalController.text)
      );
      
      // Show a confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      
      // If WebSocket is connected and connection params changed, ask to reconnect
      if (wsProvider.isConnected &&
          (wsProvider.serverIp != _serverIpController.text ||
           wsProvider.serverPort != int.parse(_serverPortController.text))) {
        _showReconnectDialog();
      }
    }
  }
  
  void _resetSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'This will reset all settings to their default values. Continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Reset settings
              final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
              settingsProvider.resetToDefaults();
              
              // Update controllers
              _serverIpController.text = settingsProvider.serverIp;
              _serverPortController.text = settingsProvider.serverPort.toString();
              _usernameController.text = settingsProvider.username;
              _passwordController.text = settingsProvider.password;
              _slideshowIntervalController.text = settingsProvider.slideshowInterval.toString();
              
              // Show confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings reset to defaults'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('RESET'),
          ),
        ],
      ),
    );
  }
  
  void _showReconnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reconnect?'),
        content: const Text(
          'Connection settings have changed. Would you like to reconnect to the server now?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('LATER'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final wsProvider = Provider.of<WebSocketProvider>(context, listen: false);
              wsProvider.disconnect();
              wsProvider.connect(
                _serverIpController.text,
                int.parse(_serverPortController.text),
              );
            },
            child: const Text('RECONNECT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final wsProvider = Provider.of<WebSocketProvider>(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to defaults',
            onPressed: _resetSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32.0 : 16.0,
          vertical: 16.0,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection Settings Section
              _buildSectionHeader(context, 'Connection Settings'),
              Card(
                margin: const EdgeInsets.only(bottom: 24.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Server IP
                      TextFormField(
                        controller: _serverIpController,
                        decoration: const InputDecoration(
                          labelText: 'Server IP',
                          hintText: 'Enter server IP address',
                          prefixIcon: Icon(Icons.computer),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter server IP';
                          }
                          // Simple IP validation
                          final ipPattern = RegExp(
                            r'^(\d{1,3}\.){3}\d{1,3}$'
                          );
                          if (!ipPattern.hasMatch(value)) {
                            return 'Please enter a valid IP address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Server Port
                      TextFormField(
                        controller: _serverPortController,
                        decoration: const InputDecoration(
                          labelText: 'Server Port',
                          hintText: 'Enter server port number',
                          prefixIcon: Icon(Icons.settings_ethernet),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter server port';
                          }
                          final port = int.tryParse(value);
                          if (port == null || port <= 0 || port > 65535) {
                            return 'Please enter a valid port (1-65535)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Username
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'Enter username',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Password
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.visibility),
                            onPressed: () {
                              // Toggle password visibility
                            },
                          ),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Auto Connect Switch
                      SwitchListTile(
                        title: const Text('Auto Connect'),
                        subtitle: const Text(
                          'Automatically connect to server on startup'
                        ),
                        value: settingsProvider.autoConnect,
                        onChanged: (value) {
                          settingsProvider.setAutoConnect(value);
                        },
                        secondary: const Icon(Icons.power_settings_new),
                      ),
                      
                      // Connection status
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              wsProvider.isConnected
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: wsProvider.isConnected
                                  ? Colors.green
                                  : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              wsProvider.isConnected
                                  ? 'Connected to server'
                                  : 'Not connected',
                              style: TextStyle(
                                color: wsProvider.isConnected
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Display Settings Section
              _buildSectionHeader(context, 'Display Settings'),
              Card(
                margin: const EdgeInsets.only(bottom: 24.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dark Mode Switch
                      SwitchListTile(
                        title: const Text('Dark Mode'),
                        subtitle: const Text(
                          'Use dark theme throughout the app'
                        ),
                        value: settingsProvider.darkMode,
                        onChanged: (value) {
                          settingsProvider.setDarkMode(value);
                        },
                        secondary: Icon(
                          settingsProvider.darkMode
                              ? Icons.dark_mode
                              : Icons.light_mode,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Multi-view Settings Section
              _buildSectionHeader(context, 'Multi Camera View Settings'),
              Card(
                margin: const EdgeInsets.only(bottom: 24.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Auto Slideshow Switch
                      SwitchListTile(
                        title: const Text('Auto Slideshow'),
                        subtitle: const Text(
                          'Automatically cycle between camera pages'
                        ),
                        value: settingsProvider.autoSlideshowEnabled,
                        onChanged: (value) {
                          settingsProvider.setAutoSlideshowEnabled(value);
                        },
                        secondary: const Icon(Icons.slideshow),
                      ),
                      const SizedBox(height: 16),
                      
                      // Slideshow Interval Slider
                      Visibility(
                        visible: settingsProvider.autoSlideshowEnabled,
                        maintainState: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Text(
                                'Page Change Interval: ${settingsProvider.slideshowInterval.toStringAsFixed(0)} seconds',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Slider(
                              value: settingsProvider.slideshowInterval,
                              min: 5,
                              max: 120,
                              divisions: 23,
                              label: '${settingsProvider.slideshowInterval.toStringAsFixed(0)} sec',
                              onChanged: (value) {
                                settingsProvider.setSlideshowInterval(value);
                                _slideshowIntervalController.text = value.toString();
                              },
                            ),
                            // Manual input for precise control
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: TextFormField(
                                controller: _slideshowIntervalController,
                                decoration: const InputDecoration(
                                  labelText: 'Interval (seconds)',
                                  hintText: 'Enter interval in seconds',
                                  prefixIcon: Icon(Icons.timer),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter an interval';
                                  }
                                  final interval = double.tryParse(value);
                                  if (interval == null || interval < 5 || interval > 120) {
                                    return 'Value must be between 5-120 seconds';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  final interval = double.tryParse(value);
                                  if (interval != null && interval >= 5 && interval <= 120) {
                                    settingsProvider.setSlideshowInterval(interval);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Save Button
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('SAVE SETTINGS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _saveSettings,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppTheme.accentColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
