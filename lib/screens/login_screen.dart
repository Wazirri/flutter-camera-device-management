import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../providers/websocket_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverAddressController = TextEditingController();
  final _serverPortController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _isConnecting = false;
  String _connectionStatus = '';

  @override
  void initState() {
    super.initState();
    // Set default values for production
    _serverAddressController.text = '85.104.114.145';
    _serverPortController.text = '1200';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _serverAddressController.dispose();
    _serverPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ResponsiveHelper.responsiveWidget(
              context: context,
              mobile: _buildMobileLogin(),
              desktop: _buildDesktopLogin(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLogin() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 40),
          _buildLoginForm(),
          const SizedBox(height: 16),
          _buildRememberMeAndForgotPassword(),
          const SizedBox(height: 32),
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _buildDesktopLogin() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Row(
        children: [
          // Left side (Logo and background)
          Expanded(
            child: Container(
              height: MediaQuery.of(context).size.height,
              color: AppTheme.darkSurface,
              padding: const EdgeInsets.all(48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_camera_back_rounded,
                    size: 120,
                    color: AppTheme.primaryOrange,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Camera Device Manager',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Manage all your cameras and devices from one place',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.darkTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          // Right side (Login form)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please sign in to continue',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _buildLoginForm(),
                  const SizedBox(height: 16),
                  _buildRememberMeAndForgotPassword(),
                  const SizedBox(height: 32),
                  _buildLoginButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(
          Icons.video_camera_back_rounded,
          size: 80,
          color: AppTheme.primaryOrange,
        ),
        const SizedBox(height: 24),
        const Text(
          'Camera Device Manager',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'Please sign in to continue',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.darkTextSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Server address field
          const Text(
            'Server Address',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _serverAddressController,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              hintText: 'Enter server address',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter server address';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          // Server port field
          const Text(
            'Server Port',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _serverPortController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter server port',
              prefixIcon: Icon(Icons.settings_ethernet_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter server port';
              }
              // Check if port is a valid number
              if (int.tryParse(value) == null) {
                return 'Port must be a number';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          // Username field (renamed from Email)
          const Text(
            'Username',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              hintText: 'Enter your username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your username';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          // Password field
          const Text(
            'Password',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          
          // Connection status message
          if (_connectionStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                _connectionStatus,
                style: TextStyle(
                  color: _connectionStatus.contains('Error') || 
                         _connectionStatus.contains('Failed')
                      ? Colors.red
                      : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRememberMeAndForgotPassword() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: _rememberMe,
                activeColor: AppTheme.primaryBlue,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Remember me',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.darkTextSecondary,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            // No implementation, UI only
          },
          child: const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isConnecting ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isConnecting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'Login',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Get form values
      final serverAddress = _serverAddressController.text;
      final serverPort = _serverPortController.text;
      final username = _emailController.text;
      final password = _passwordController.text;
      
      setState(() {
        _isConnecting = true;
        _connectionStatus = 'Connecting to WebSocket...';
      });
      
      try {
        // Get WebSocket provider
        final webSocketProvider = Provider.of<WebSocketProvider>(context, listen: false);
        
        // Connect to WebSocket
        final connected = await webSocketProvider.connect(
          serverAddress,
          serverPort,
          username,
          password,
        );
        
        if (connected) {
          setState(() {
            _connectionStatus = 'Connected successfully!';
            _isConnecting = false;
          });
          
          // Navigate to dashboard after successful connection
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else {
          setState(() {
            _connectionStatus = 'Failed to connect to WebSocket server';
            _isConnecting = false;
          });
        }
      } catch (e) {
        setState(() {
          _connectionStatus = 'Error: ${e.toString()}';
          _isConnecting = false;
        });
        debugPrint('WebSocket connection error: $e');
      }
    }
  }
}