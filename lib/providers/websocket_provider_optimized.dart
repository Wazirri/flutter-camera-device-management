import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movita_ecs/models/system_info.dart';
import 'camera_devices_provider_optimized.dart';

class WebSocketProviderOptimized with ChangeNotifier {
  WebSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  String? _lastUsername;
  String? _lastPassword;
  bool _rememberMe = false;

  bool _isConnected = false;
  bool _isLoggedIn = false;
  bool _isConnecting = false;
  String _errorMessage = '';
  SystemInfo? _systemInfo;
  
  // Reference to CameraDevicesProvider
  CameraDevicesProviderOptimized? _cameraDevicesProvider;

  // System info stream controller
  final _systemInfoController = StreamController<SystemInfo>.broadcast();

  // Message log functionality
  final List<String> _messageLog = [];
  bool _isLocalServerMode = false;
  
  // Store last received message for other providers to access
  dynamic _lastMessage;
  
  // Son gelen mesajı al
  dynamic get lastMessage => _lastMessage;
  
  // Connection settings
  String _serverIp = '85.104.114.145';
  int _serverPort = 1200;
  
  // Notification batching
  bool _needsNotification = false;
  Timer? _notificationDebounceTimer;
  final int _notificationBatchWindow = 200; // milliseconds

  // Constructor - load saved settings but don't auto-connect
  WebSocketProviderOptimized() {
    _loadSettings().then((_) {
      _detectPlatform();
      
      // We no longer auto-connect to prevent connection attempts before login
      // User must explicitly call connect/login methods instead
      debugPrint('WebSocket initialized. Waiting for user to log in before attempting connection.');
    });
  }

  // Set the camera devices provider
  void setCameraDevicesProvider(CameraDevicesProviderOptimized provider) {
    _cameraDevicesProvider = provider;
  }

  // Detect platform and use local server if desktop
  bool _isDesktop = false;
  void _detectPlatform() {
    _isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    if (_isDesktop) {
      // Use local server if running on desktop
      _serverIp = 'localhost';
      _serverPort = 5000;
      _isLocalServerMode = true;
      debugPrint('Running on desktop platform, using local server at $_serverIp:$_serverPort');
    }
  }

  // Getters
  bool get isConnected => _isConnected;
  bool get isLoggedIn => _isLoggedIn;
  bool get isConnecting => _isConnecting;
  String get errorMessage => _errorMessage;
  SystemInfo? get systemInfo => _systemInfo;
  Stream<SystemInfo> get onSystemInfoUpdate => _systemInfoController.stream;
  String get serverIp => _serverIp;
  int get serverPort => _serverPort;
  bool get rememberMe => _rememberMe;
  bool get isLocalServerMode => _isLocalServerMode;
  List<String> get messageLog => List.unmodifiable(_messageLog);

  // Clear message log
  void clearLog() {
    _messageLog.clear();
    _batchNotifyListeners();
  }

  // Add message to log (with reduced logging for performance)
  void _logMessage(String message, {bool isImportant = false}) {
    // Add timestamp to message
    final timestamp = DateTime.now().toString().split('.').first;
    final logEntry = '[$timestamp] $message';
    
    // Only log important messages or a subset of regular messages for performance
    if (isImportant || _messageLog.length % 10 == 0) {
      _messageLog.add(logEntry);
      
      // Keep log size manageable (max 100 messages)
      if (_messageLog.length > 100) {
        _messageLog.removeAt(0);
      }
      
      // Only notify for important messages or periodically
      if (isImportant) {
        _batchNotifyListeners();
      }
    }
  }

  // Connect to WebSocket server
  Future<bool> connect(String serverIp, int serverPort,
      {String? username, String? password, bool rememberMe = false}) async {
    // Save connection settings
    _serverIp = serverIp;
    _serverPort = serverPort;
    _rememberMe = rememberMe;
    _lastUsername = username;
    _lastPassword = password;

    // Save settings if Remember Me is checked
    if (_rememberMe) {
      await _saveSettings();
    }

    // Close existing connections
    await disconnect();

    try {
      _isConnecting = true;
      _errorMessage = '';
      _batchNotifyListeners();

      // Check if we are using a secure connection
      final wsScheme = _isSecureConnection() ? 'wss' : 'ws';
      final url = '$wsScheme://$_serverIp:$_serverPort/ws';
      debugPrint('Connecting to WebSocket: $url');
      _logMessage('Connecting to $url', isImportant: true);

      // Connect to WebSocket server
      _socket = await WebSocket.connect(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Connection timed out');
        },
      );

      // Set up listeners
      _socket!.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: _handleError,
        cancelOnError: false,
      );

      _isConnected = true;
      _isConnecting = false;
      _logMessage('Connected successfully', isImportant: true);
      _batchNotifyListeners();

      // Start heartbeat
      _startHeartbeat();

      // Attempt login if credentials are provided
      if (username != null && password != null) {
        return login(username, password, rememberMe);
      }

      return true;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  // Disconnect from WebSocket server
  Future<void> disconnect() async {
    _stopHeartbeat();
    _stopReconnectTimer();

    if (_socket != null) {
      try {
        await _socket!.close();
        _logMessage('Disconnected from server', isImportant: true);
      } catch (e) {
        debugPrint('Error closing socket: $e');
        _logMessage('Error closing socket: $e', isImportant: true);
      }
      _socket = null;
    }

    _isConnected = false;
    _isLoggedIn = false;
    _batchNotifyListeners();
  }

  // Login to server
  Future<bool> login(String username, String password, [bool rememberMe = false]) async {
    if (!_isConnected || _socket == null) {
      _errorMessage = 'Not connected to server';
      _logMessage('Login failed: Not connected to server', isImportant: true);
      _batchNotifyListeners();
      return false;
    }

    try {
      _lastUsername = username;
      _lastPassword = password;
      _rememberMe = rememberMe;

      // Save settings if Remember Me is checked
      if (_rememberMe) {
        await _saveSettings();
      }

      // Send login command
      final loginCommand = 'LOGIN "$username" "$password"';
      _socket!.add(loginCommand);
      _logMessage('Sending login request', isImportant: true);

      // Wait for login response (handled in _handleMessage)
      // We'll return true for now and let the message handler update the state
      return true;
    } catch (e) {
      _errorMessage = 'Login error: $e';
      _logMessage('Login error: $e', isImportant: true);
      _batchNotifyListeners();
      return false;
    }
  }

  /// Logout user: close socket and reset login state
  Future<void> logout() async {
    await disconnect();
    _lastUsername = null;
    _lastPassword = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  // Start monitoring ECS system after login
  void startEcsMonitoring() {
    if (_isConnected && _isLoggedIn && _socket != null) {
      // First get system info
      _socket!.add('GET SYSINFO');
      _logMessage('Sent GET SYSINFO command', isImportant: true);
      
      // Use new format: ecs_slaves.m_X
      _socket!.add('Monitor ecs_slaves');
      _logMessage('Started monitoring ecs_slaves', isImportant: true);
      
      // Get camera and device info
      _socket!.add('GET CAMERAS');
      _logMessage('Sent GET CAMERAS command', isImportant: true);
    } else {
      _logMessage('Cannot start monitoring: Not connected or not logged in', isImportant: true);
      debugPrint('Cannot start monitoring: connected=$_isConnected, logged in=$_isLoggedIn');
    }
  }
  
  // Send command via WebSocket
  Future<bool> sendCommand(String command) async {
    if (!_isConnected || _socket == null) {
      _errorMessage = 'WebSocket bağlantısı yok. Komut gönderilemedi.';
      _logMessage(_errorMessage, isImportant: true);
      _batchNotifyListeners();
      return false;
    }
    
    try {
      _socket!.add(command);
      _logMessage('Komut gönderildi: $command');
      return true;
    } catch (e) {
      _errorMessage = 'Komut gönderirken hata: $e';
      _logMessage(_errorMessage, isImportant: true);
      debugPrint(_errorMessage);
      _batchNotifyListeners();
      return false;
    }
  }
  
  /// Assign a camera to a group via WebSocket command
  Future<bool> sendAddGroupToCamera(String cameraKey, String groupName) async {
    final command = "ADD_GROUP_TO_CAM $cameraKey $groupName";
    debugPrint('WebSocketProvider: Sending group assignment command: $command');
    return await sendCommand(command);
  }
  
  // Move camera to device
  Future<bool> moveCamera(String deviceMac, String cameraMac) {
    final command = 'MOVECAM $deviceMac $cameraMac';
    return sendCommand(command);
  }
  
  // Change WiFi settings
  Future<bool> changeWifiSettings(String newName, String newPassword) {
    final command = 'DO SCRIPT "wifichange" "$newName" "$newPassword"';
    return sendCommand(command);
  }

  // Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      if (message is String) {
        // Skip detailed logging for heartbeat messages
        if (message == 'PONG') {
          return;
        }
        
        // Log the message (truncate if too long)
        final logMsg = message.length > 500 ? '${message.substring(0, 500)}...' : message;
        _logMessage('Received: $logMsg');
        
        // Try to parse JSON message
        try {
          final jsonData = jsonDecode(message);
          _processJsonMessage(jsonData);
        } catch (e) {
          // Not a JSON message, probably text-based protocol
        }
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
      _logMessage('Error handling message: $e', isImportant: true);
    }
  }
  
  // Process JSON messages
  void _processJsonMessage(Map<String, dynamic> jsonData) {
    try {
      // Save the last message
      _lastMessage = jsonData;
      
      final command = jsonData['c'];
      
      switch (command) {
        case 'login':
          // Login required or failed
          _isLoggedIn = false;
          _errorMessage = jsonData['msg'] ?? 'Login required';
          _logMessage('Login status: $_errorMessage', isImportant: true);
          
          // Auto-login when we receive a login message if we have credentials
          if (_lastUsername != null && _lastPassword != null) {
            _logMessage('Auto-login triggered by login message');
            login(_lastUsername!, _lastPassword!, _rememberMe);
          }
          
          _batchNotifyListeners();
          break;

        case 'loginok':
          // Login successful
          _isLoggedIn = true;
          _errorMessage = '';
          _logMessage('Login successful', isImportant: true);
          _batchNotifyListeners();

          // Start monitoring after successful login
          startEcsMonitoring();
          break;

        case 'sysinfo':
          // System information update
          _systemInfo = SystemInfo.fromJson(jsonData);
          _systemInfoController.add(_systemInfo!);
          _logMessage('Received system info update');
          _batchNotifyListeners();
          break;

        case 'changed':
          // Forward camera device updates to the CameraDevicesProvider
          if (_cameraDevicesProvider != null) {
            _cameraDevicesProvider!.processWebSocketMessage(jsonData);
            _logMessage('Received camera device update');
          }
          break;

        default:
          _logMessage('Received unknown command: $command');
          break;
      }
    } catch (e) {
      debugPrint('Error processing JSON message: $e');
      _logMessage('Error processing JSON message: $e', isImportant: true);
    }
  }

  // Handle WebSocket disconnection
  void _handleDisconnect() {
    debugPrint('WebSocket disconnected');
    _logMessage('WebSocket disconnected', isImportant: true);
    _isConnected = false;
    _isLoggedIn = false;
    _batchNotifyListeners();

    // Try to reconnect
    _scheduleReconnect();
  }

  // Handle WebSocket errors
  void _handleError(dynamic error) {
    debugPrint('WebSocket error: $error');
    _logMessage('WebSocket error: $error', isImportant: true);
    _errorMessage = error.toString();
    _isConnected = false;
    _isConnecting = false;
    _batchNotifyListeners();

    // Try to reconnect
    _scheduleReconnect();
  }

  // Start heartbeat timer
  void _startHeartbeat() {
    _stopHeartbeat(); // Stop existing timer if any

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _socket != null) {
        try {
          _socket!.add('PING');
          // Don't log heartbeats - they're too frequent
        } catch (e) {
          debugPrint('Error sending heartbeat: $e');
          _handleDisconnect();
        }
      } else {
        _stopHeartbeat();
      }
    });
  }

  // Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // Schedule reconnection attempt
  void _scheduleReconnect() {
    // Don't auto-reconnect unless user is logged in
    if (!_isLoggedIn) {
      debugPrint('Reconnect suppressed: user not logged in.');
      return;
    }
    _stopReconnectTimer(); // Stop existing timer if any

    // Try to reconnect if we were previously connected and have credentials
    if (_lastUsername != null && _lastPassword != null) {
      _reconnectTimer = Timer(const Duration(seconds: 5), () {
        debugPrint('Attempting to reconnect...');
        _logMessage('Attempting to reconnect...', isImportant: true);
        connect(_serverIp, _serverPort,
            username: _lastUsername!, password: _lastPassword!, rememberMe: _rememberMe);
      });
    }
  }

  // Stop reconnect timer
  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // Check if connection should use secure WebSocket
  bool _isSecureConnection() {
    // Implement criteria for when to use secure connection (WSS)
    // For example, if connecting to a domain other than localhost
    if (_serverIp == 'localhost' || _serverIp == '127.0.0.1') {
      return false;
    }
    
    // Check if server uses an IP address format
    final ipRegex = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
    if (ipRegex.hasMatch(_serverIp)) {
      return false; 
    }
    
    // For other domains, use secure WebSocket
    return true;
  }

  // Load saved settings
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _serverIp = prefs.getString('serverIp') ?? _serverIp;
      _serverPort = prefs.getInt('serverPort') ?? _serverPort;
      _rememberMe = prefs.getBool('rememberMe') ?? false;
      
      // Only load credentials if rememberMe was true
      if (_rememberMe) {
        _lastUsername = prefs.getString('username');
        _lastPassword = prefs.getString('password');
      }
      
      _batchNotifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _logMessage('Error loading settings: $e', isImportant: true);
    }
  }

  // Save settings
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('serverIp', _serverIp);
      await prefs.setInt('serverPort', _serverPort);
      await prefs.setBool('rememberMe', _rememberMe);
      
      // Only save credentials if rememberMe is true
      if (_rememberMe && _lastUsername != null && _lastPassword != null) {
        await prefs.setString('username', _lastUsername!);
        await prefs.setString('password', _lastPassword!);
      } else {
        // Clear saved credentials if rememberMe is turned off
        await prefs.remove('username');
        await prefs.remove('password');
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      _logMessage('Error saving settings: $e', isImportant: true);
    }
  }

  // Clear saved credentials
  Future<void> clearSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('username');
      await prefs.remove('password');
      await prefs.setBool('rememberMe', false);
      
      _lastUsername = null;
      _lastPassword = null;
      _rememberMe = false;
      
      _batchNotifyListeners();
    } catch (e) {
      debugPrint('Error clearing credentials: $e');
      _logMessage('Error clearing credentials: $e', isImportant: true);
    }
  }
  
  // Batch notifications to reduce UI rebuilds
  void _batchNotifyListeners() {
    _needsNotification = true;
    
    // If a timer is already pending, do nothing
    if (_notificationDebounceTimer?.isActive ?? false) {
      return;
    }
    
    // Schedule a delayed notification
    _notificationDebounceTimer = Timer(Duration(milliseconds: _notificationBatchWindow), () {
      if (_needsNotification) {
        _needsNotification = false;
        notifyListeners();
      }
    });
  }

  // Clean up resources
  @override
  void dispose() {
    _stopHeartbeat();
    _stopReconnectTimer();
    _notificationDebounceTimer?.cancel();
    disconnect();
    _systemInfoController.close();
    super.dispose();
  }
}
