import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movita_ecs/models/system_info.dart';
import 'camera_devices_provider.dart';

class WebSocketProvider with ChangeNotifier {
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
  CameraDevicesProvider? _cameraDevicesProvider;

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

  // Constructor - load saved settings but don't auto-connect
  WebSocketProvider() {
    _loadSettings().then((_) {
      _detectPlatform();
      
      // We no longer auto-connect to prevent connection attempts before login
      // User must explicitly call connect/login methods instead
      debugPrint('WebSocket initialized. Waiting for user to log in before attempting connection.');
    });
  }

  // Set the camera devices provider
  void setCameraDevicesProvider(CameraDevicesProvider provider) {
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
    notifyListeners();
  }

  // Add message to log
  // void _logMessage(String message) {
  //   // Add timestamp to message
  //   final timestamp = DateTime.now().toString().split('.').first;
  //   final logEntry = '[$timestamp] $message';
    
  //   _messageLog.add(logEntry);
    
  //   // Keep log size manageable (max 100 messages)
  //   if (_messageLog.length > 100) {
  //     _messageLog.removeAt(0);
  //   }
    
  //   notifyListeners();
  // }

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
      notifyListeners();

      // Check if we are using a secure connection
      final wsScheme = _isSecureConnection() ? 'wss' : 'ws';
      final url = '$wsScheme://$_serverIp:$_serverPort/ws';
      debugPrint('Connecting to WebSocket: $url');
      debugPrint('[${DateTime.now().toString().split('.').first}] Connecting to $url');

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
      debugPrint('[${DateTime.now().toString().split('.').first}] Connected successfully');
      notifyListeners();

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
        debugPrint('[${DateTime.now().toString().split('.').first}] Disconnected from server');
      } catch (e) {
        debugPrint('Error closing socket: $e');
        debugPrint('[${DateTime.now().toString().split('.').first}] Error closing socket: $e');
      }
      _socket = null;
    }

    _isConnected = false;
    _isLoggedIn = false;
    notifyListeners();
  }

  // Add a completer to track login completion
  Completer<bool>? _loginCompleter;

  // Login to server
  Future<bool> login(String username, String password, [bool rememberMe = false]) async {
    if (!_isConnected || _socket == null) {
      _errorMessage = 'Not connected to server';
      debugPrint('[${DateTime.now().toString().split('.').first}] Login failed: Not connected to server');
      notifyListeners();
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

      // Create a completer to wait for the actual login response
      _loginCompleter = Completer<bool>();

      // Send login command
      final loginCommand = 'LOGIN "$username" "$password"';
      _socket!.add(loginCommand);
      debugPrint('[${DateTime.now().toString().split('.').first}] Sending login request');

      // Wait for login response with timeout
      try {
        final result = await _loginCompleter!.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('[${DateTime.now().toString().split('.').first}] Login timeout - no response from server');
            return false;
          },
        );
        return result;
      } catch (e) {
        debugPrint('[${DateTime.now().toString().split('.').first}] Login wait error: $e');
        return false;
      }
    } catch (e) {
      _errorMessage = 'Login error: $e';
      debugPrint('[${DateTime.now().toString().split('.').first}] Login error: $e');
      notifyListeners();
      return false;
    }
  }

  // Start monitoring ECS system after login
  void startEcsMonitoring() {
    if (_isConnected && _isLoggedIn && _socket != null) {

      // Yeni format: ecs_slaves.m_X formatını kullan
      _socket!.add('Monitor ecs_slaves');
      debugPrint('[${DateTime.now().toString().split('.').first}] Started monitoring ecs_slaves (using new format)');
  
    } else {
      debugPrint('[${DateTime.now().toString().split('.').first}] Cannot start monitoring: Not connected or not logged in');
      debugPrint('Cannot start monitoring: connected=$_isConnected, logged in=$_isLoggedIn');
    }
  }
  
  // Websocket üzerinden komut gönder
  Future<bool> sendCommand(String command) async {
    if (!_isConnected || _socket == null) {
      _errorMessage = 'WebSocket bağlantısı yok. Komut gönderilemedi.';
      debugPrint('[${DateTime.now().toString().split('.').first}] $_errorMessage');
      notifyListeners();
      return false;
    }
    
    try {
      _socket!.add(command);
      debugPrint('[${DateTime.now().toString().split('.').first}] Komut gönderildi: $command');
      return true;
    } catch (e) {
      _errorMessage = 'Komut gönderirken hata: $e';
      debugPrint('[${DateTime.now().toString().split('.').first}] $_errorMessage');
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }
  
  /// Assign a camera to a group via WebSocket command
  Future<bool> sendAddGroupToCamera(String cameraKey, String groupName) async {
    // Format should be: ADD_CAMERA_TO_GROUP <cameraKey> <groupName>
    final command = "ADD_CAMERA_TO_GROUP $cameraKey $groupName";
    debugPrint('[${DateTime.now().toString().split('.').first}] Sending group assignment command: $command');
    return await sendCommand(command);
  }
  
  // Kameraya grup ekle - fixed format with more parameters
  Future<bool> addGroupToCamera(String deviceMac, String cameraIndex, String groupName) {
    // Format: ADD_CAMERA_TO_GROUP <deviceMac>:<cameraIndex> <groupName>
    final cameraKey = "$deviceMac:$cameraIndex";
    final command = 'ADD_CAMERA_TO_GROUP $cameraKey $groupName';
    debugPrint('[${DateTime.now().toString().split('.').first}] Adding camera to group: $command');
    return sendCommand(command);
  }
  
  // Kamerayı cihaza taşı
  Future<bool> moveCamera(String deviceMac, String cameraMac) {
    final command = 'MOVECAM $deviceMac $cameraMac';
    return sendCommand(command);
  }
  
  // Cihazın WiFi ayarlarını değiştir
  Future<bool> changeWifiSettings(String newName, String newPassword) {
    final command = 'DO SCRIPT "wifichange" "$newName" "$newPassword"';
    return sendCommand(command);
  }

  // Handle incoming WebSocket messages
  void _handleMessage(dynamic rawMessage) { // Renamed parameter to rawMessage
    try {
      if (rawMessage is String) {
        // Log the message (truncate if too long)
        final logMsg = rawMessage.length > 500 ? '${rawMessage.substring(0, 500)}...' : rawMessage;
        debugPrint('[${DateTime.now().toString().split('.').first}] Received: $logMsg');
        
        // Debug için data path bilgisini çıkarmaya çalış
        if (rawMessage.contains('"data"') && rawMessage.contains('"val"')) {
          try {
            final jsonData = jsonDecode(rawMessage);
            final dataPath = jsonData['data']; 
            debugPrint('⚡ WebSocket data path: $dataPath');
          } catch (e) {
            // JSON parse hatası - sessizce görmezden gel
          }
        }
        
        if (rawMessage == 'PONG') {
          // Handle heartbeat response
          return;
        }

        // Try to parse JSON message
        try {
          final jsonData = jsonDecode(rawMessage);
          // Pass jsonData to _processJsonMessage, but the original rawMessage (string) 
          // to the camera devices provider if the command is 'changed'.
          _processJsonMessage(jsonData, rawMessage); 
        } catch (e) {
          // Not a JSON message, check if it's a string command
          _processStringMessage(rawMessage);
        }
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
      debugPrint('[${DateTime.now().toString().split('.').first}] Error handling message: $e');
    }
  }
  
  // JSON mesajlarını işle
  void _processJsonMessage(Map<String, dynamic> jsonData, String rawMessageString) { // Added rawMessageString parameter
    try {
      _lastMessage = jsonData;
      
      final command = jsonData['c'];
      
      switch (command) {
        case 'login':
          // Login required or failed
          _isLoggedIn = false;
          
          // Check if this is a login failure response with error code
          final int? code = jsonData['code'];
          final String message = jsonData['msg'] ?? 'Login required';
          
          if (code == 100) {
            // Login failed - wrong password/username
            _errorMessage = message;
            debugPrint('[${DateTime.now().toString().split('.').first}] Login failed: $_errorMessage');
            
            // Complete the login with failure
            if (_loginCompleter != null && !_loginCompleter!.isCompleted) {
              _loginCompleter!.complete(false);
            }
            
            // Close WebSocket connection on login failure
            disconnect();
            
            notifyListeners();
            return; // Don't auto-login on failure
          } else {
            // Regular login required message
            _errorMessage = message;
            debugPrint('[${DateTime.now().toString().split('.').first}] Login status: $_errorMessage');
            
            // Auto-login when we receive a login message if we have credentials
            // but only if we're not already in a login process
            if (_lastUsername != null && _lastPassword != null && _loginCompleter == null) {
              debugPrint('[${DateTime.now().toString().split('.').first}] Auto-login triggered by login message');
              login(_lastUsername!, _lastPassword!, _rememberMe);
            }
          }
          
          notifyListeners();
          break;

        case 'loginok':
          // Login successful
          _isLoggedIn = true;
          _errorMessage = '';
          debugPrint('[${DateTime.now().toString().split('.').first}] Login successful');
          
          // Complete the login with success
          if (_loginCompleter != null && !_loginCompleter!.isCompleted) {
            _loginCompleter!.complete(true);
          }
          
          notifyListeners();

          // Start monitoring after successful login
          startEcsMonitoring();
          break;

        case 'sysinfo':
          // System information update
          _systemInfo = SystemInfo.fromJson(jsonData);
          _systemInfoController.add(_systemInfo!);
          debugPrint('[${DateTime.now().toString().split('.').first}] Received system info update');
          notifyListeners();
          break;

        case 'changed':
          // Forward camera device updates to the CameraDevicesProvider
          if (_cameraDevicesProvider != null) {
            _cameraDevicesProvider!.processWebSocketMessage(rawMessageString); // Use rawMessageString here
            debugPrint('[${DateTime.now().toString().split('.').first}] Received camera device update');
          }
          break;

        default:
          debugPrint('Unknown command: $command');
          debugPrint('[${DateTime.now().toString().split('.').first}] Received unknown command: $command');
          break;
      }
    } catch (e) {
      debugPrint('Error processing JSON message: $e');
      debugPrint('[${DateTime.now().toString().split('.').first}] Error processing JSON message: $e');
    }
  }

  // String mesajlarını işle
  void _processStringMessage(String message) {
    try {
      final parts = message.trim().split(' ');
      if (parts.isEmpty) return;
      
      final command = parts[0];
      
      switch (command) {
        case 'CAM_GROUP_ADD':
          if (parts.length >= 2) {
            final groupName = parts.sublist(1).join(' '); // Join all parts after command as group name
            _handleCamGroupAdd(groupName);
          }
          break;
        case 'ADD_GROUP_TO_CAM':
          if (parts.length >= 3) {
            final cameraMac = parts[1];
            final groupName = parts.sublist(2).join(' '); // Join remaining parts as group name
            _handleAddGroupToCam(cameraMac, groupName);
          }
          break;
        case 'REMOVE_GROUP_FROM_CAM':
          if (parts.length >= 3) {
            final cameraMac = parts[1];
            final groupName = parts.sublist(2).join(' '); // Join remaining parts as group name
            _handleRemoveGroupFromCam(cameraMac, groupName);
          }
          break;
        default:
          debugPrint('Unknown string command: $command');
          debugPrint('[${DateTime.now().toString().split('.').first}] Received unknown string command: $command');
          break;
      }
    } catch (e) {
      debugPrint('Error processing string message: $e');
      debugPrint('[${DateTime.now().toString().split('.').first}] Error processing string message: $e');
    }
  }
  
  // CAM_GROUP_ADD komutunu işle
  void _handleCamGroupAdd(String groupName) {
    try {
      if (groupName.isEmpty) {
        debugPrint('CAM_GROUP_ADD: Empty group name received');
        return;
      }
      
      // CameraDevicesProvider'a grup ekleme mesajı gönder
      if (_cameraDevicesProvider != null) {
        _cameraDevicesProvider!.addGroupFromWebSocket(groupName);
        debugPrint('[${DateTime.now().toString().split('.').first}] CAM_GROUP_ADD: Added group "$groupName"');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling CAM_GROUP_ADD: $e');
      debugPrint('[${DateTime.now().toString().split('.').first}] Error handling CAM_GROUP_ADD: $e');
    }
  }

  // ADD_GROUP_TO_CAM komutunu işle
  void _handleAddGroupToCam(String cameraMac, String groupName) {
    try {
      if (cameraMac.isEmpty || groupName.isEmpty) {
        debugPrint('ADD_GROUP_TO_CAM: Empty camera MAC or group name received');
        return;
      }
      
      // CameraDevicesProvider'a kamerayı gruba ekleme mesajı gönder
      if (_cameraDevicesProvider != null) {
        _cameraDevicesProvider!.addCameraToGroupFromWebSocket(cameraMac, groupName);
        debugPrint('[${DateTime.now().toString().split('.').first}] ADD_GROUP_TO_CAM: Added camera "$cameraMac" to group "$groupName"');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling ADD_GROUP_TO_CAM: $e');
      debugPrint('[${DateTime.now().toString().split('.').first}] Error handling ADD_GROUP_TO_CAM: $e');
    }
  }

  // REMOVE_GROUP_FROM_CAM komutunu işle
  void _handleRemoveGroupFromCam(String cameraMac, String groupName) {
    try {
      if (cameraMac.isEmpty || groupName.isEmpty) {
        debugPrint('REMOVE_GROUP_FROM_CAM: Empty camera MAC or group name received');
        return;
      }
      
      // CameraDevicesProvider'a kamerayı gruptan çıkarma mesajı gönder
      if (_cameraDevicesProvider != null) {
        _cameraDevicesProvider!.removeCameraFromGroupFromWebSocket(cameraMac, groupName);
        debugPrint('[${DateTime.now().toString().split('.').first}] REMOVE_GROUP_FROM_CAM: Removed camera "$cameraMac" from group "$groupName"');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling REMOVE_GROUP_FROM_CAM: $e');
      debugPrint('[${DateTime.now().toString().split('.').first}] Error handling REMOVE_GROUP_FROM_CAM: $e');
    }
  }

  // Handle WebSocket disconnection
  void _handleDisconnect() {
    debugPrint('WebSocket disconnected');
    debugPrint('[${DateTime.now().toString().split('.').first}] WebSocket disconnected');
    _isConnected = false;
    _isLoggedIn = false;
    notifyListeners();

    // Try to reconnect
    _scheduleReconnect();
  }

  // Handle WebSocket errors
  void _handleError(dynamic error) {
    debugPrint('WebSocket error: $error');
    debugPrint('[${DateTime.now().toString().split('.').first}] WebSocket error: $error');
    _errorMessage = error.toString();
    _isConnected = false;
    _isConnecting = false;
    notifyListeners();

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
          debugPrint('[${DateTime.now().toString().split('.').first}] Sending heartbeat ping');
        } catch (e) {
          debugPrint('Error sending heartbeat: $e');
          debugPrint('[${DateTime.now().toString().split('.').first}] Error sending heartbeat: $e');
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
    _stopReconnectTimer(); // Stop existing timer if any

    // Try to reconnect if we were previously connected and have credentials
    // AND if the user didn't explicitly log out (in which case _lastUsername would be null)
    if (_lastUsername != null && _lastPassword != null) {
      // Store the current state of isLoggedIn to prevent reconnection after logout
      final wasLoggedIn = _isLoggedIn;
      
      _reconnectTimer = Timer(const Duration(seconds: 5), () {
        // Only attempt reconnection if the user was logged in and didn't explicitly log out
        if (!_isConnected && !_isConnecting && wasLoggedIn && _lastUsername != null) {
          debugPrint('Attempting to reconnect...');
          debugPrint('[${DateTime.now().toString().split('.').first}] Attempting to reconnect...');
          connect(_serverIp, _serverPort,
              username: _lastUsername,
              password: _lastPassword,
              rememberMe: _rememberMe);
        } else {
          debugPrint('Skipping reconnection attempt - user logged out or reconnection not needed');
          debugPrint('[${DateTime.now().toString().split('.').first}] Skipping reconnection attempt');
        }
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
      
      notifyListeners();
      
      // Auto-connect will be handled in the constructor after _loadSettings completes
      // This allows for proper initialization before attempting connection
    } catch (e) {
      debugPrint('Error loading settings: $e');
      debugPrint('[${DateTime.now().toString().split('.').first}] Error loading settings: $e');
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
      debugPrint('[${DateTime.now().toString().split('.').first}] Error saving settings: $e');
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
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing credentials: $e');
      debugPrint('[${DateTime.now().toString().split('.').first}] Error clearing credentials: $e');
    }
  }

  /// Logout user: close socket and reset login state
  Future<void> logout() async {
    // First stop any active reconnection attempts
    _stopReconnectTimer();
    
    // Send LOGOUT command if connected
    if (_isConnected && _socket != null) {
      try {
        _socket!.add('LOGOUT');
        debugPrint('[${DateTime.now().toString().split('.').first}] Sent LOGOUT command');
      } catch (e) {
        debugPrint('Error sending logout command: $e');
      }
    }
    
    // Then disconnect
    await disconnect();
    
    // Clear credentials to prevent auto-reconnect
    _lastUsername = null;
    _lastPassword = null;
    _isLoggedIn = false;
    
    // Notify listeners about state change
    notifyListeners();
    debugPrint('User logged out. Auto-reconnect disabled.');
  }

  // Clean up resources
  @override
  void dispose() {
    _stopHeartbeat();
    _stopReconnectTimer();
    disconnect();
    _systemInfoController.close();
    super.dispose();
  }
}
