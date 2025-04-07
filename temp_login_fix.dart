import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movita_ecs/providers/websocket_provider.dart';
import 'package:movita_ecs/screens/dashboard_screen.dart';
import 'package:movita_ecs/theme/app_theme.dart';
import 'package:movita_ecs/widgets/custom_button.dart';
import 'package:movita_ecs/widgets/custom_text_field.dart';
import 'package:movita_ecs/widgets/fade_in_animation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _serverAddressController = TextEditingController();
  final TextEditingController _serverPortController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    // No default values, let the user enter them
    // For email field, we'll keep a default value for convenience
    _emailController.text = 'admin';
    // Password is intentionally left empty
    
    // Load saved credentials if available
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('rememberMe') ?? false;
      
      if (rememberMe) {
        setState(() {
          _rememberMe = true;
          _serverAddressController.text = prefs.getString('serverAddress') ?? '';
          _serverPortController.text = prefs.getString('serverPort') ?? '';
          _emailController.text = prefs.getString('username') ?? 'admin';
          // Password is intentionally not loaded for security reasons
        });
      }
    } catch (e) {
      debugPrint('Error loading saved credentials: $e');
    }
  }

  Future<void> _saveCredentials() async {
    if (_rememberMe) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rememberMe', true);
        await prefs.setString('serverAddress', _serverAddressController.text);
        await prefs.setString('serverPort', _serverPortController.text);
        await prefs.setString('username', _emailController.text);
        // We intentionally don't save the password for security reasons
      } catch (e) {
        debugPrint('Error saving credentials: $e');
      }
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rememberMe', false);
        await prefs.remove('serverAddress');
        await prefs.remove('serverPort');
        await prefs.remove('username');
      } catch (e) {
        debugPrint('Error clearing credentials: $e');
      }
    }
  }

  @override
  void dispose() {
    _serverAddressController.dispose();
    _serverPortController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    // Validate inputs
    if (_serverAddressController.text.isEmpty ||
        _serverPortController.text.isEmpty ||
        _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final webSocketProvider = Provider.of<WebSocketProvider>(context, listen: false);
      
      // Save credentials if remember me is checked
      await _saveCredentials();
      
      // Connect to WebSocket server
      final connected = await webSocketProvider.connect(
        _serverAddressController.text,
        int.parse(_serverPortController.text),
        username: _emailController.text,
        password: _passwordController.text,
        rememberMe: _rememberMe,
      );

      if (connected && mounted) {
        // Navigate to dashboard on successful connection using named route
        // This ensures proper AppShell wrapping
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection failed. Please check your credentials.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.darkBackgroundColor,
              AppTheme.darkBackgroundColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: FadeInAnimation(
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  margin: const EdgeInsets.symmetric(horizontal: 24.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Image.asset(
                        'assets/images/movita_logo.png',
                        height: 120,
                        width: 120,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'movita ECS',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 32),
                      CustomTextField(
                        controller: _serverAddressController,
                        hintText: 'Server Address',
                        icon: Icons.dns,
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _serverPortController,
                        hintText: 'Server Port',
                        icon: Icons.settings_ethernet,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _emailController,
                        hintText: 'Username',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _passwordController,
                        hintText: 'Password',
                        icon: Icons.lock,
                        isPassword: true,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                            activeColor: AppTheme.primaryColor,
                          ),
                          const Text(
                            'Remember Me',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: 'LOGIN',
                        isLoading: _isLoading,
                        onPressed: _handleLogin,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Camera Device Management System',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
