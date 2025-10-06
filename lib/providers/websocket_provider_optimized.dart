import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movita_ecs/models/system_info.dart';
import 'camera_devices_provider_optimized.dart';
import 'user_group_provider.dart';

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
  bool _isWaitingForChangedone = false;
  String _errorMessage = '';
  SystemInfo? _systemInfo;
  
  // Reference to CameraDevicesProvider
  CameraDevicesProviderOptimized? _cameraDevicesProvider;
  
  // Reference to UserGroupProvider
  UserGroupProvider? _userGroupProvider;

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
      print('WebSocket initialized. Waiting for user to log in before attempting connection.');
    });
  }

  // Set the camera devices provider
  void setCameraDevicesProvider(CameraDevicesProviderOptimized provider) {
    _cameraDevicesProvider = provider;
  }

  // Set the user group provider
  void setUserGroupProvider(UserGroupProvider provider) {
    _userGroupProvider = provider;
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
      print('Running on desktop platform, using local server at $_serverIp:$_serverPort');
    }
  }

  // Getters
  bool get isConnected => _isConnected;
  bool get isLoggedIn => _isLoggedIn;
  bool get isConnecting => _isConnecting;
  bool get isWaitingForChangedone => _isWaitingForChangedone;
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

  // // Add message to log (with reduced logging for performance)
  // void _logMessage(String message, {bool isImportant = false}) {
  //   // Add timestamp to message
  //   final timestamp = DateTime.now().toString().split('.').first;
  //   final logEntry = '[$timestamp] $message';
    
  //   // Only log important messages or a subset of regular messages for performance
  //   if (isImportant || _messageLog.length % 10 == 0) {
  //     _messageLog.add(logEntry);
      
  //     // Keep log size manageable (max 100 messages)
  //     if (_messageLog.length > 100) {
  //       _messageLog.removeAt(0);
  //     }
      
  //     // Only notify for important messages or periodically
  //     if (isImportant) {
  //       _batchNotifyListeners();
  //     }
  //   }
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
      _batchNotifyListeners();

      // Check if we are using a secure connection
      final wsScheme = _isSecureConnection() ? 'wss' : 'ws';
      final url = '$wsScheme://$_serverIp:$_serverPort';
      print('Connecting to WebSocket: $url');
      print('[${DateTime.now().toString().split('.').first}] Connecting to $url');

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
      print('[${DateTime.now().toString().split('.').first}] Connected successfully');
      _batchNotifyListeners();

      // Start heartbeat
      _startHeartbeat();

      // New login flow: Just connect, don't automatically attempt login
      // Wait for "Oturum açılmamış!" message and then send credentials
      print('[${DateTime.now().toString().split('.').first}] Connected, waiting for login prompt');

      return true;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  // Disconnect from WebSocket server
  Future<void> disconnect() async {
    print('[${DateTime.now().toString().split('.').first}] disconnect() called'); // CORRECTED THIS LINE
    _stopHeartbeat();
    _stopReconnectTimer();

    if (_socket != null) {
      try {
        await _socket!.close();
        print('[${DateTime.now().toString().split('.').first}] Disconnected from server');
      } catch (e) {
        print('Error closing socket: $e');
        print('[${DateTime.now().toString().split('.').first}] Error closing socket: $e');
      }
      _socket = null;
    }

    _isConnected = false;
    _isLoggedIn = false;
    _isWaitingForChangedone = false;
    _batchNotifyListeners();
  }

  // Reconnect to WebSocket server with saved credentials
  Future<bool> reconnect() async {
    print('[${DateTime.now().toString().split('.').first}] reconnect() called');
    
    // Check if we have saved credentials
    if (_lastUsername == null || _lastPassword == null) {
      print('No saved credentials available for reconnect');
      return false;
    }
    
    // Disconnect first if still connected
    if (_isConnected) {
      await disconnect();
    }
    
    // Wait a bit before reconnecting
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Attempt to reconnect with saved credentials
    print('[${DateTime.now().toString().split('.').first}] Attempting to reconnect with saved credentials');
    return await connect(_serverIp, _serverPort, 
        username: _lastUsername!, 
        password: _lastPassword!, 
        rememberMe: _rememberMe);
  }

  // Login to server - now just connects and waits for login prompt
  Future<bool> login(String username, String password, [bool rememberMe = false, String? serverIp, int? serverPort]) async {
    // Store credentials for when we receive the login prompt
    _lastUsername = username;
    _lastPassword = password;
    _rememberMe = rememberMe;
    
    // Update server settings if provided
    if (serverIp != null) _serverIp = serverIp;
    if (serverPort != null) _serverPort = serverPort;

    // Save settings if Remember Me is checked
    if (_rememberMe) {
      await _saveSettings();
    }

    // Connect to server if not already connected
    if (!_isConnected) {
      print('[${DateTime.now().toString().split('.').first}] Not connected, initiating connection');
      return await connect(_serverIp, _serverPort, 
          username: username, password: password, rememberMe: rememberMe);
    } else {
      print('[${DateTime.now().toString().split('.').first}] Already connected, waiting for login prompt');
      return true;
    }
  }

  /// Logout user: close socket and reset login state
  Future<void> logout() async {
    print('[${DateTime.now().toString().split('.').first}] logout() called'); // CORRECTED THIS LINE
    await disconnect();
    _lastUsername = null;
    _lastPassword = null;
    _isLoggedIn = false;
    _isWaitingForChangedone = false;
    notifyListeners();
  }

  // Start monitoring ECS system after login
  void startEcsMonitoring() {
    if (_isConnected && _isLoggedIn && _socket != null) {
      // Monitor ecs_slaves is now automatically sent after loginok
      // This method is kept for backward compatibility and manual monitoring start
      print('[${DateTime.now().toString().split('.').first}] Monitoring already started automatically after login');
    } else {
      print('[${DateTime.now().toString().split('.').first}] Cannot start monitoring: Not connected or not logged in');
      print('Cannot start monitoring: connected=$_isConnected, logged in=$_isLoggedIn');
    }
  }
  
  // Send command via WebSocket
  Future<bool> sendCommand(String command) async {
    if (!_isConnected || _socket == null) {
      _errorMessage = 'WebSocket bağlantısı yok. Komut gönderilemedi.';
      print('[${DateTime.now().toString().split('.').first}] $_errorMessage');
      _batchNotifyListeners();
      return false;
    }
    
    try {
      _socket!.add(command);
      print('[${DateTime.now().toString().split('.').first}] Komut gönderildi: $command');
      return true;
    } catch (e) {
      _errorMessage = 'Komut gönderirken hata: $e';
      print('[${DateTime.now().toString().split('.').first}] $_errorMessage');
      print(_errorMessage);
      _batchNotifyListeners();
      return false;
    }
  }
  
  /// Assign a camera to a group via WebSocket command
  Future<bool> sendAddGroupToCamera(String cameraKey, String groupName) async {
    final command = "ADD_GROUP_TO_CAM $cameraKey $groupName";
    print('WebSocketProvider: Sending group assignment command: $command');
    return await sendCommand(command);
  }

  /// Remove a camera from a group via WebSocket command
  Future<bool> sendRemoveGroupFromCamera(String cameraMac, String groupName) async {
    final command = "REMOVE_GROUP_FROM_CAM $cameraMac $groupName";
    print('WebSocketProvider: Sending remove group from camera command: $command');
    return await sendCommand(command);
  }

  // ============= USER MANAGEMENT COMMANDS =============
  
  /// Create a new user
  /// Format: CREATEUSER username password name group_name
  Future<bool> sendCreateUser(String username, String password, String name, String groupName) async {
    final command = 'CREATEUSER "$username" "$password" "$name" "$groupName"';
    print('WebSocketProvider: Sending create user command: $command');
    return await sendCommand(command);
  }

  /// Delete a user
  /// Format: DELETEUSER username
  Future<bool> sendDeleteUser(String username) async {
    final command = 'DELETEUSER "$username"';
    print('WebSocketProvider: Sending delete user command: $command');
    return await sendCommand(command);
  }

  /// Change user password
  /// Format: CHANGEPASS username new_pass
  Future<bool> sendChangePassword(String username, String newPassword) async {
    final command = 'CHANGEPASS "$username" "$newPassword"';
    print('WebSocketProvider: Sending change password command: $command');
    return await sendCommand(command);
  }

  // ============= GROUP MANAGEMENT COMMANDS =============
  
  /// Create a new group
  /// Format: CREATEGROUP groupname description permissions
  /// Permissions: view,record,user_management
  Future<bool> sendCreateGroup(String groupName, String description, String permissions) async {
    final command = 'CREATEGROUP "$groupName" "$description" "$permissions"';
    print('WebSocketProvider: Sending create group command: $command');
    return await sendCommand(command);
  }

  /// Modify a group
  /// Format: MODIFYGROUP groupname description permissions
  Future<bool> sendModifyGroup(String groupName, String description, String permissions) async {
    final command = 'MODIFYGROUP "$groupName" "$description" "$permissions"';
    print('WebSocketProvider: Sending modify group command: $command');
    return await sendCommand(command);
  }

  /// Delete a group
  /// Format: DELETEGROUP groupname
  Future<bool> sendDeleteGroup(String groupName) async {
    final command = 'DELETEGROUP "$groupName"';
    print('WebSocketProvider: Sending delete group command: $command');
    return await sendCommand(command);
  }

  /// Convert recording via WebSocket command
  Future<bool> sendConvertRecording({
    required String cameraName, // The camera name (e.g., KAMERA131)
    required String startTime,
    required String endTime,
    required String format,
    required String targetSlaveMac,
  }) async {
    final command = "CONVERT_REC $cameraName $startTime $endTime $format $targetSlaveMac";
    print('WebSocketProvider: Sending convert recording command: $command');
    return await sendCommand(command);
  }
  
  // Move camera to device
  Future<bool> moveCamera(String cameraMac, String sourceMac, String targetMac) {
    final command = 'MOVECAM $cameraMac $sourceMac $targetMac';
    return sendCommand(command);
  }
  
  // Change WiFi settings
  Future<bool> changeWifiSettings(String newName, String newPassword) {
    final command = 'DO SCRIPT "wifichange" "$newName" "$newPassword"';
    return sendCommand(command);
  }

  // Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    final now = DateTime.now().toIso8601String();
    print('[$now] FSA AAAAAWebSocket raw message: $message');
    try {
      if (message is String) {
        // Skip detailed logging for heartbeat messages
        if (message == 'PONG') {
          return;
        }
        
        print('[$now] WebSocket raw message: $message');
        // Log the message (truncate if too long)
        final logMsg = message.length > 500 ? '${message.substring(0, 500)}...' : message;
        print('[${DateTime.now().toString().split('.').first}] Received: $logMsg');
        // Try to parse JSON message
        try {
          final jsonData = jsonDecode(message);
          print('WebSocket message parsed as JSON: $jsonData');
          _processJsonMessage(jsonData);
        } catch (e) {
          print('WebSocket message is not valid JSON: $e');
          // Not a JSON message, check if it's a string command
          _processStringMessage(message);
        }
      }
    } catch (e) {
      print('Error handling message: $e');
      print('[${DateTime.now().toString().split('.').first}] Error handling message: $e');
    }
  }
  
  // Process JSON messages
  void _processJsonMessage(Map<String, dynamic> jsonData) {
    print('FSAAAA Processing JSON message: $jsonData');
    try {
      // Save the last message
      _lastMessage = jsonData;
      final now = DateTime.now().toIso8601String();
      print('[$now] processJsonMessage: keys=${jsonData.keys.toList()}, full=$jsonData');
      
      final command = jsonData['c'];
      final message = jsonData['msg'] ?? '';
      
      print('processJsonMessage: command=$command, msg=$message');
      
      // Handle "Oturum açılmamış!" message - send login credentials (trim to handle spaces)
      if (message.trim() == "Oturum açılmamış!" && _lastUsername != null && _lastPassword != null) {
        print('[${DateTime.now().toString().split('.').first}] Received login prompt, sending credentials');
        final loginCommand = 'LOGIN "$_lastUsername" "$_lastPassword"';
        _socket!.add(loginCommand);
        print('[${DateTime.now().toString().split('.').first}] Sent login command');
        return;
      }
      
      // Handle "Şifre veya kullanıcı adı yanlış!" message - show error and disconnect
      if (message.trim() == "Şifre veya kullanıcı adı yanlış!") {
        print('[${DateTime.now().toString().split('.').first}] Login failed: wrong credentials');
        _errorMessage = message;
        _isLoggedIn = false;
        _isWaitingForChangedone = false;
        // Disconnect on login failure
        disconnect().then((_) {
          _batchNotifyListeners();
        });
        _batchNotifyListeners();
        return;
      }
      
      switch (command) {
        case 'login':
          // Login required or failed - this is the old logic, kept for compatibility
          _isLoggedIn = false;
          _isWaitingForChangedone = false;
          
          final int? code = jsonData['code'];
          
          if (code == 100) {
            // Login failed - wrong password/username
            _errorMessage = message;
            print('[${DateTime.now().toString().split('.').first}] Login failed: $_errorMessage');
            disconnect().then((_) {
              _batchNotifyListeners();
            });
            _batchNotifyListeners();
            return;
          } else {
            // Regular login required message - don't treat as error if it's "Oturum açılmamış!"
            if (message.trim() != "Oturum açılmamış!") {
              _errorMessage = message;
              print('[${DateTime.now().toString().split('.').first}] Login status: $_errorMessage');
            } else {
              // Clear any previous error for login prompt
              _errorMessage = '';
              print('[${DateTime.now().toString().split('.').first}] Login prompt received, waiting for credentials to be sent');
            }
          }
          
          _batchNotifyListeners();
          break;

        case 'loginok':
          // Login successful - send Monitor ecs_slaves message
          _isLoggedIn = true;
          _isWaitingForChangedone = true;
          _errorMessage = '';
          print('[${DateTime.now().toString().split('.').first}] Login successful, sending Monitor ecs_slaves');
          
          // Send Monitor ecs_slaves message immediately after loginok
          if (_socket != null) {
            _socket!.add('Monitor ecs_slaves');
            _socket!.add('Monitor users');
            _socket!.add('Monitor groups');
            print('[${DateTime.now().toString().split('.').first}] Sent Monitor ecs_slaves command');
          }
          
          _batchNotifyListeners();
          break;

        case 'changedone':
          // changedone message received - login process complete
          final name = jsonData['name'];
          print('changedone message received: name=$name, isWaitingForChangedone=$_isWaitingForChangedone');
          if (name == 'ecs_slaves') {
            _isWaitingForChangedone = false;
          print('[${DateTime.now().toString().split('.').first}] changedone received for ecs_slaves - login complete');
            print('changedone: isWaitingForChangedone now $_isWaitingForChangedone, isLoggedIn=$_isLoggedIn');
            _batchNotifyListeners();
          }
          
          // Forward to UserGroupProvider for users and groups completion
          if (_userGroupProvider != null) {
            _userGroupProvider!.processWebSocketMessage(jsonData);
          }
          break;

        case 'sysinfo':
          // System information update
          _systemInfo = SystemInfo.fromJson(jsonData);
          _systemInfoController.add(_systemInfo!);
          // Forward sysinfo to CameraDevicesProvider as well
          if (_cameraDevicesProvider != null) {
            _cameraDevicesProvider!.processWebSocketMessage(jsonData);
          }
          print('[${DateTime.now().toString().split('.').first}] Received system info update');
          _batchNotifyListeners();
          break;

        case 'changed':
          // Forward camera device updates to the CameraDevicesProvider
          if (_cameraDevicesProvider != null) {
            _cameraDevicesProvider!.processWebSocketMessage(jsonData);
            print('[${DateTime.now().toString().split('.').first}] Received camera device update');
          }
          
          // Forward user and group updates to UserGroupProvider
          if (_userGroupProvider != null) {
            _userGroupProvider!.processWebSocketMessage(jsonData);
          }
          break;

        case 'conversions':
          // Store conversions response
          _lastMessage = jsonData;
          print('[${DateTime.now().toString().split('.').first}] Received conversions response');
          print('[Conversions] Data: ${jsonData['data']}');
          _batchNotifyListeners();
          break;

        default:
          print('[${DateTime.now().toString().split('.').first}] Received unknown command: $command');
          break;
      }
    } catch (e) {
      print('Error processing JSON message: $e');
      print('[${DateTime.now().toString().split('.').first}] Error processing JSON message: $e');
    }
  }

  // String mesajlarını işle
  void _processStringMessage(String message) {
    try {
      final parts = message.trim().split(' ');
      if (parts.isEmpty) return;
      
      final command = parts[0];
      
      // No string commands currently handled
      print('[${DateTime.now().toString().split('.').first}] Received string command: $command');
    } catch (e) {
      print('[${DateTime.now().toString().split('.').first}] Error processing string message: $e');
    }
  }

  // Handle WebSocket disconnection
  void _handleDisconnect() {
    print('WebSocket disconnected');
    print('[${DateTime.now().toString().split('.').first}] WebSocket disconnected');
    _isConnected = false;
    _isWaitingForChangedone = false;
    _batchNotifyListeners();

    // Try to reconnect (login state korunur)
    _scheduleReconnect();
  }

  // Handle WebSocket errors
  void _handleError(dynamic error) {
    print('WebSocket error: $error');
    print('[${DateTime.now().toString().split('.').first}] WebSocket error: $error');
    _errorMessage = error.toString();
    _isConnected = false;
    _isConnecting = false;
    _isWaitingForChangedone = false;
    
    // Start connection error handling and auto-reconnect
    _handleConnectionError();
    
    _batchNotifyListeners();

    // Try to reconnect (login state korunur)
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
          print('Error sending heartbeat: $e');
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
      print('Reconnect suppressed: user not logged in.');
      return;
    }
    _stopReconnectTimer(); // Stop existing timer if any

    // Try to reconnect if we were previously connected and have credentials
    if (_lastUsername != null && _lastPassword != null) {
      _reconnectTimer = Timer(const Duration(seconds: 5), () {
        print('Attempting to reconnect...');
        print('[${DateTime.now().toString().split('.').first}] Attempting to reconnect...');
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
      print('Error loading settings: $e');
      print('[${DateTime.now().toString().split('.').first}] Error loading settings: $e');
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
      print('Error saving settings: $e');
      print('[${DateTime.now().toString().split('.').first}] Error saving settings: $e');
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
      print('Error clearing credentials: $e');
      print('[${DateTime.now().toString().split('.').first}] Error clearing credentials: $e');
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
  
  // Handle connection errors and start auto-reconnect
  void _handleConnectionError() {
    print('[${DateTime.now().toString().split('.').first}] Connection error detected, starting auto-reconnect');
    
    _isConnected = false;
    _isLoggedIn = false;
    
    // Start auto-reconnect if we have saved credentials
    if (_lastUsername != null && _lastPassword != null) {
      _startAutoReconnect();
    }
    
    _batchNotifyListeners();
  }
  
  // Start automatic reconnection timer
  void _startAutoReconnect() {
    _stopReconnectTimer(); // Stop any existing timer
    
    print('[${DateTime.now().toString().split('.').first}] Starting auto-reconnect timer');
    
    _reconnectTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!_isConnected && _lastUsername != null && _lastPassword != null) {
        print('[${DateTime.now().toString().split('.').first}] Auto-reconnect attempt');
        
        try {
          final success = await reconnect();
          if (success) {
            print('[${DateTime.now().toString().split('.').first}] Auto-reconnect successful');
            _stopReconnectTimer();
          } else {
            print('[${DateTime.now().toString().split('.').first}] Auto-reconnect failed, will retry');
          }
        } catch (e) {
          print('[${DateTime.now().toString().split('.').first}] Auto-reconnect error: $e');
        }
      } else if (_isConnected) {
        // Stop timer if we're connected
        _stopReconnectTimer();
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
