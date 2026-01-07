import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/websocket_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/fade_in_animation.dart';

class LoginScreenOptimized extends StatefulWidget {
  const LoginScreenOptimized({Key? key}) : super(key: key);

  @override
  _LoginScreenOptimizedState createState() => _LoginScreenOptimizedState();
}

class _LoginScreenOptimizedState extends State<LoginScreenOptimized> {
  final TextEditingController _serverAddressController = TextEditingController();
  final TextEditingController _serverPortController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
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
          
          // Handle both string and int cases for server port to fix type mismatch
          var serverPort = prefs.getString('serverPort');
          if (serverPort == null) {
            // Try to get it as an int and convert to string
            final portInt = prefs.getInt('serverPort');
            serverPort = portInt?.toString() ?? '';
          }
          _serverPortController.text = serverPort;
          
          _emailController.text = prefs.getString('username') ?? 'admin';
          // Password is intentionally not loaded for security reasons
        });
      }
    } catch (e) {
      print('Error loading saved credentials: $e');
    }
  }

  Future<void> _saveCredentials() async {
    if (_rememberMe) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rememberMe', true);
        await prefs.setString('serverAddress', _serverAddressController.text);
        await prefs.setString('serverPort', _serverPortController.text);
        // Remove any old int value that might be causing the type mismatch
        await prefs.remove('serverPort'); // Remove potential int value
        await prefs.setString('serverPort', _serverPortController.text); // Save as string
        await prefs.setString('username', _emailController.text);
        // We intentionally don't save the password for security reasons
      } catch (e) {
        print('Error saving credentials: $e');
      }
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rememberMe', false);
        await prefs.remove('serverAddress');
        await prefs.remove('serverPort');
        await prefs.remove('username');
      } catch (e) {
        print('Error clearing credentials: $e');
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
    final now = DateTime.now().toIso8601String();
    print('[$now] Login button pressed');
    try {
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
        _isConnecting = true;
      });

      final webSocketProvider = Provider.of<WebSocketProviderOptimized>(context, listen: false);
      // Save credentials if remember me is checked
      await _saveCredentials();
      // Show connecting overlay
      _showConnectionProgress(context);
      
      // Use login method which will connect and handle the entire login flow
      final loginSuccess = await webSocketProvider.login(
        _emailController.text,
        _passwordController.text,
        _rememberMe,
        _serverAddressController.text,
        int.parse(_serverPortController.text),
      );

      if (!loginSuccess) {
        // Close the connecting overlay
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection failed: ${webSocketProvider.errorMessage.isNotEmpty ? webSocketProvider.errorMessage : "Please check server address and port."}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Listen for login state changes
      bool loginCompleted = false;
      bool loginFailed = false;
      String? errorMessage;

      void loginListener() {
        print('Login listener: connected=${webSocketProvider.isConnected}, loggedIn=${webSocketProvider.isLoggedIn}, waitingForChangedone=${webSocketProvider.isWaitingForChangedone}, error=${webSocketProvider.errorMessage}');
        if (webSocketProvider.lastMessage != null) {
          print('Last WebSocket message: ${webSocketProvider.lastMessage}');
        }
        // Check for login failure (any error message)
        if (webSocketProvider.errorMessage.isNotEmpty) {
          print('Login failed - error: ${webSocketProvider.errorMessage}');
          loginFailed = true;
          errorMessage = webSocketProvider.errorMessage;
        } 
        // Check for successful login completion (changedone received)
        else if (webSocketProvider.isLoggedIn && !webSocketProvider.isWaitingForChangedone) {
          print('Login completed successfully');
          loginCompleted = true;
        }
        // Check if connection was lost during login
        else if (!webSocketProvider.isConnected && webSocketProvider.errorMessage.isNotEmpty) {
          print('Connection lost during login');
          loginFailed = true;
          errorMessage = webSocketProvider.errorMessage;
        }
      }

      webSocketProvider.addListener(loginListener);

      // Wait for login completion or failure with timeout
      int waitTime = 0;
      const maxWaitTime = 30000; // 30 seconds timeout
      const checkInterval = 100; // Check every 100ms

      while (!loginCompleted && !loginFailed && mounted && waitTime < maxWaitTime) {
        await Future.delayed(const Duration(milliseconds: checkInterval));
        waitTime += checkInterval;
      }

      webSocketProvider.removeListener(loginListener);

      // Handle timeout
      if (waitTime >= maxWaitTime && !loginCompleted && !loginFailed) {
        loginFailed = true;
        errorMessage = 'Login timeout. Please try again.';
      }

      // Close the connecting overlay
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (loginCompleted && mounted) {
        // Pre-load data before navigation for smoother transition
        _preloadDashboardData();
        
        // Navigate to dashboard
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else if (loginFailed && mounted) {
        // Disconnect on login failure to reset state
        await webSocketProvider.disconnect();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? 'Login failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stack) {
      print('LOGIN ERROR: $e\n$stack');
      // Close the connecting overlay if it's showing
      if (mounted && _isConnecting && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
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
          _isConnecting = false;
        });
      }
    }
  }
  
  // Show connection progress dialog
  void _showConnectionProgress(BuildContext context) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            backgroundColor: AppTheme.darkSurface,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Connecting and logging in...',
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please wait while we establish connection and verify credentials',
                  style: TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Preload essential dashboard data
  void _preloadDashboardData() {
    try {
      // Monitoring is now started automatically after successful login
      print('[${DateTime.now().toString().split('.').first}] Dashboard data preload completed - monitoring already active');
    } catch (e) {
      print('Error preloading dashboard data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: LoginScreenOptimized build çalıştı');
    print('DEBUG: _handleLogin fonksiyonu çağrıldı');
    print('[DEBUG] LoginScreenOptimized build() called');
    print('[DEBUG] _handleLogin() called');
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
                        height: 80,
                      ),
                      const SizedBox(height: 16),
                      // Title
                      const Text(
                        'movita ECS Login',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtitle
                      Text(
                        'Enter your credentials to access the camera management system',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      // Login Form
                      Form(
                        child: Column(
                          children: [
                            // Server Address
                            CustomTextField(
                              controller: _serverAddressController,
                              hintText: 'Server Address',
                              icon: Icons.dns_rounded,
                              keyboardType: TextInputType.url,
                            ),
                            const SizedBox(height: 16),
                            // Server Port
                            CustomTextField(
                              controller: _serverPortController,
                              hintText: 'Server Port',
                              icon: Icons.settings_ethernet_rounded,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            // Email/Username
                            CustomTextField(
                              controller: _emailController,
                              hintText: 'Username',
                              icon: Icons.person_rounded,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            // Password
                            CustomTextField(
                              controller: _passwordController,
                              hintText: 'Password',
                              icon: Icons.lock_rounded,
                              isPassword: true,
                            ),
                            const SizedBox(height: 24),
                            // Remember Me Checkbox
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                                  activeColor: AppTheme.primaryBlue,
                                ),
                                const Text(
                                  'Remember Me',
                                  style: TextStyle(color: Colors.white),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    // Could implement forgot password functionality
                                  },
                                  child: const Text('Forgot Password?'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // Login Button
                            CustomButton(
                              text: 'Login',
                              isLoading: _isLoading,
                              onPressed: _isLoading ? null : () => _handleLogin(),
                            ),
                          ],
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
