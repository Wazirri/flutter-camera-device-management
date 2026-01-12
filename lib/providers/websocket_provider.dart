import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movita_ecs/models/system_info.dart';
import 'package:movita_ecs/models/permissions.dart';
import 'camera_devices_provider.dart';
import 'user_group_provider.dart';
import 'conversion_tracking_provider.dart';

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
  String? _currentLoggedInUsername; // Login yapan kullanıcının adı
  
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
  
  // Store last conversions response
  Map<String, dynamic>? _lastConversionsResponse;
  
  // Get last conversions response
  Map<String, dynamic>? get lastConversionsResponse => _lastConversionsResponse;
  
  // Store last convert_rec response
  Map<String, dynamic>? _lastConvertRecResponse;
  
  // Get last convert_rec response
  Map<String, dynamic>? get lastConvertRecResponse => _lastConvertRecResponse;
  
  // Clear last convert_rec response
  void clearLastConvertRecResponse() {
    _lastConvertRecResponse = null;
  }
  
  // Store last parameter_set result for UI notification
  Map<String, dynamic>? _lastParameterSetResult;
  
  // Get last parameter_set result and clear it (one-time read)
  Map<String, dynamic>? consumeLastParameterSetResult() {
    final result = _lastParameterSetResult;
    _lastParameterSetResult = null;
    return result;
  }
  
  // Get last parameter_set result without clearing
  Map<String, dynamic>? get lastParameterSetResult => _lastParameterSetResult;
  
  // Global result message callback for notifications
  // Parameters: commandType (e.g., 'COMMAND'), result (0=error, 1=success), message, mac (device), commandText (full command sent)
  void Function(String commandType, int result, String message, {String? mac, String? commandText})? onResultMessage;
  
  // Two-phase notification callback for commands like CLEARCAMS
  // Parameters: phase (1 or 2), mac, message
  void Function(int phase, String mac, String message)? onTwoPhaseNotification;
  
  // Combined result notification callback - shows command send status AND device result together
  // Parameters: commandType, sendResult (1=sent successfully), deviceResult (-1=pending, 0=error, 1=success), 
  //             sendMessage, deviceMessage, mac, commandText
  void Function(String commandType, int sendResult, int deviceResult, 
                String sendMessage, String deviceMessage, 
                {String? mac, String? commandText})? onCombinedResultMessage;
  
  // Pending CLEARCAMS commands waiting for 'deleted' confirmation
  final Set<String> _pendingClearCams = {};
  
  // Pending COMMAND messages waiting for device response
  // Key: "${mac}_${commandText}", Value: {sendResult, sendMessage, timestamp}
  final Map<String, Map<String, dynamic>> _pendingCommands = {};
  
  // Pending SHMC (slave_cmd) commands waiting for server response
  // Key: "${mac}_${command}", Value: {timestamp, commandText}
  final Map<String, Map<String, dynamic>> _pendingShmcCommands = {};
  
  // Connection settings
  String _serverIp = '85.104.114.145';
  int _serverPort = 1200;
  
  // Notification batching
  bool _needsNotification = false;
  Timer? _notificationDebounceTimer;
  final int _notificationBatchWindow = 500; // milliseconds - increased for better batching with many cameras

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

  // Reference to ConversionTrackingProvider
  ConversionTrackingProvider? _conversionTrackingProvider;

  // Set the conversion tracking provider
  void setConversionTrackingProvider(ConversionTrackingProvider provider) {
    _conversionTrackingProvider = provider;
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
  String? get currentLoggedInUsername => _currentLoggedInUsername;
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

  // Add message to log
  void _logMessage(String message) {
    final now = DateTime.now();
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    final logEntry = '[$timestamp] $message';
    
    _messageLog.add(logEntry);
    
    // Keep log size manageable (max 50000000 messages)
    if (_messageLog.length > 50000000) {
      _messageLog.removeAt(0);
    }
    
    _batchNotifyListeners();
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
    
    // Don't reconnect if user never logged in successfully
    if (!_isLoggedIn && _lastUsername == null) {
      print('Reconnect suppressed: user not logged in.');
      return false;
    }
    
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
    print('[${DateTime.now().toString().split('.').first}] logout() called');
    
    // Stop all timers first
    _stopHeartbeat();
    _stopReconnectTimer();
    _notificationDebounceTimer?.cancel();
    _notificationDebounceTimer = null;
    
    // Close socket connection
    if (_socket != null) {
      try {
        // Send a logout message if connected
        if (_isConnected) {
          try {
            _socket!.add('logout');
            print('[${DateTime.now().toString().split('.').first}] Sent logout command to server');
          } catch (e) {
            print('[${DateTime.now().toString().split('.').first}] Error sending logout command: $e');
          }
        }
        
        // Close the socket
        await _socket!.close();
        print('[${DateTime.now().toString().split('.').first}] WebSocket connection closed');
      } catch (e) {
        print('[${DateTime.now().toString().split('.').first}] Error closing socket during logout: $e');
      }
      _socket = null;
    }
    
    // Reset all state
    _lastUsername = null;
    _lastPassword = null;
    _currentLoggedInUsername = null;
    _isLoggedIn = false;
    _isConnected = false;
    _isConnecting = false;
    _isWaitingForChangedone = false;
    _errorMessage = '';
    _lastMessage = null;
    _lastConversionsResponse = null;
    _lastConvertRecResponse = null;
    
    // Clear message log
    _messageLog.clear();
    
    // Reset all provider data
    print('[${DateTime.now().toString().split('.').first}] Resetting camera devices provider...');
    _cameraDevicesProvider?.resetData();
    print('[${DateTime.now().toString().split('.').first}] Resetting user group provider...');
    _userGroupProvider?.clear();
    
    print('[${DateTime.now().toString().split('.').first}] Logout complete - all connections closed and state reset');
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
      _errorMessage = 'No WebSocket connection. Command could not be sent.';
      print('[${DateTime.now().toString().split('.').first}] $_errorMessage');
      _logMessage('ERROR: $_errorMessage');
      _batchNotifyListeners();
      
      // Try to reconnect if we have credentials
      if (_lastUsername != null && _lastPassword != null) {
        print('[${DateTime.now().toString().split('.').first}] Connection lost detected during sendCommand, scheduling reconnect...');
        _logMessage('INFO: Bağlantı koptu, yeniden bağlanılıyor...');
        _scheduleReconnect();
      }
      return false;
    }
    
    try {
      _socket!.add(command);
      print('[${DateTime.now().toString().split('.').first}] Command sent: $command');
      _logMessage('SENT: $command');
      
      // Track CLEARCAMS commands - response comes as slave_cmd, not COMMAND
      // Format: <MAC> CLEARCAMS
      // NOTE: Phase notifications are handled by the progress dialog, not here
      if (command.contains(' CLEARCAMS')) {
        final parts = command.split(' ');
        if (parts.isNotEmpty) {
          final mac = parts[0];
          _pendingClearCams.add(mac);
          print('[CLEARCAMS] Stored pending command for device: $mac');
          
          // Timeout to auto-clear if no response in 15 seconds
          Future.delayed(const Duration(seconds: 15), () {
            if (_pendingClearCams.contains(mac)) {
              _pendingClearCams.remove(mac);
              print('[CLEARCAMS] Timeout - no response for: $mac');
              // Show timeout notification
              if (onTwoPhaseNotification != null) {
                onTwoPhaseNotification!(2, mac, 'Cihazdan yanıt alınamadı (zaman aşımı)');
              }
            }
          });
        }
      }
      
      // Track SHMC commands for combined notification with slave_cmd response
      // Format: <MAC> SHMC <path> <value>
      if (command.contains(' SHMC ')) {
        final parts = command.split(' ');
        if (parts.length >= 3) {
          final mac = parts[0];
          // Full command after MAC (e.g., "SHMC configuration.service.recorder.on 1")
          final shmcCommand = parts.sublist(1).join(' ');
          final pendingKey = '${mac}_$shmcCommand';
          
          _pendingShmcCommands[pendingKey] = {
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'commandText': shmcCommand,
            'mac': mac,
          };
          
          print('[SHMC] Stored pending command: $pendingKey');
          
          // Timeout to auto-clear if no response in 10 seconds
          Future.delayed(const Duration(seconds: 10), () {
            if (_pendingShmcCommands.containsKey(pendingKey)) {
              final pendingData = _pendingShmcCommands.remove(pendingKey);
              print('[SHMC] Timeout - no response for: $pendingKey');
              
              // Show timeout notification
              if (onCombinedResultMessage != null && pendingData != null) {
                onCombinedResultMessage!(
                  'SHMC',
                  1, // sent successfully
                  -1, // no response (timeout)
                  'Komut gönderildi',
                  'Cihazdan yanıt alınamadı (zaman aşımı)',
                  mac: mac,
                  commandText: shmcCommand,
                );
              }
            }
          });
        }
      }
      
      return true;
    } catch (e) {
      _errorMessage = 'Error sending command: $e';
      print('[${DateTime.now().toString().split('.').first}] $_errorMessage');
      _logMessage('ERROR: $_errorMessage');
      
      // Connection might be broken, schedule reconnect
      if (_lastUsername != null && _lastPassword != null) {
        print('[${DateTime.now().toString().split('.').first}] Send error, scheduling reconnect...');
        _logMessage('INFO: Gönderim hatası, yeniden bağlanılıyor...');
        _handleDisconnect();
      }
      
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
  /// Permissions: 1111100000000000 (16-bit number)
  Future<bool> sendCreateGroup(String groupName, String description, String permissions) async {
    // Remove quotes from permissions if it's a number string (e.g., "1111100000000000")
    final permValue = permissions.replaceAll('"', '');
    final command = 'CREATEGROUP "$groupName" "$description" $permValue';
    print('WebSocketProvider: Sending create group command: $command');
    return await sendCommand(command);
  }

  /// Modify a group
  /// Format: MODIFYGROUP groupname description permissions
  /// Permissions: 1111100000000000 (16-bit number)
  Future<bool> sendModifyGroup(String groupName, String description, String permissions) async {
    // Remove quotes from permissions if it's a number string
    final permValue = permissions.replaceAll('"', '');
    final command = 'MODIFYGROUP "$groupName" "$description" $permValue';
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

  /// Set network configuration for a device
  /// Format: SET_NETWORK ip gw dhcp mac
  /// Example: SET_NETWORK 192.168.1.10 192.168.1.1 0 EA:FE:A9:B7:5B:55
  Future<bool> sendSetNetwork({
    required String ip,
    required String gateway,
    required String dhcp,
    required String mac,
  }) async {
    final command = 'SET_NETWORK $ip $gateway $dhcp $mac';
    print('WebSocketProvider: Sending set network command: $command');
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
  
  // Change camera name
  Future<bool> changeCameraName(String cameraMac, String newName) async {
    final command = 'CHANGE_CAM_NAME $cameraMac $newName';
    print('WebSocketProvider: Sending change camera name command: $command');
    return await sendCommand(command);
  }
  
  // Toggle camera distribute (SETINT command)
  Future<bool> toggleCameraDistribute(String cameraMac, bool distribute) async {
    final value = distribute ? 1 : 0;
    final command = 'SETINT all_cameras.$cameraMac.distribute $value';
    print('WebSocketProvider: Sending toggle camera distribute command: $command');
    return await sendCommand(command);
  }
  
  // Set camera distribute count (SETINT command)
  Future<bool> setCameraDistributeCount(String cameraMac, int count) async {
    final command = 'SETINT all_cameras.$cameraMac.distribute_count $count';
    print('WebSocketProvider: Sending set camera distribute_count command: $command');
    return await sendCommand(command);
  }
  
  // Toggle Smart Player service on a device
  // Format: <MAC> SHMC configuration.service.smart_player.on <0|1>
  Future<bool> setSmartPlayerService(String deviceMac, bool enabled) async {
    final value = enabled ? 1 : 0;
    final command = '$deviceMac SHMC configuration.service.smart_player.on $value';
    print('WebSocketProvider: Sending Smart Player service command: $command');
    return await sendCommand(command);
  }
  
  // Toggle Recorder service on a device
  // Format: <MAC> SHMC configuration.service.recorder.on <0|1>
  Future<bool> setRecorderService(String deviceMac, bool enabled) async {
    final value = enabled ? 1 : 0;
    final command = '$deviceMac SHMC configuration.service.recorder.on $value';
    print('WebSocketProvider: Sending Recorder service command: $command');
    return await sendCommand(command);
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
        
        // Log raw message to UI (truncate if too long for display)
        final displayMsg = message.length > 200000 ? '${message.substring(0, 200000)}...' : message;
        _logMessage(displayMsg);
        
        // Try to parse JSON message
        try {
          final jsonData = jsonDecode(message);
          _processJsonMessage(jsonData);
        } catch (e) {
          // Not a JSON message, check if it's a string command
          _processStringMessage(message);
        }
      }
    } catch (e) {
      print('Error handling message: $e');
      _logMessage('ERROR: $e');
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
      
      // Global result notification - if result field exists, notify listeners
      if (jsonData.containsKey('result') && command != null) {
        final result = jsonData['result'];
        final msg = jsonData['msg'] ?? jsonData['message'] ?? '';
        final mac = jsonData['mac']?.toString();
        final commandText = jsonData['command']?.toString();
        // Convert result to int (could be int or string)
        final resultInt = result is int ? result : int.tryParse(result.toString()) ?? -1;
        
        print('[DEBUG] command=$command, commandText=$commandText, mac=$mac, result=$resultInt');
        
        // Handle CLEARCAMS command specially - skip COMMAND type, handled via slave_cmd
        // Response comes as slave_cmd, not COMMAND, so we just skip here to avoid double notification
        if (command == 'COMMAND' && commandText == 'CLEARCAMS' && mac != null && mac.isNotEmpty) {
          print('[CLEARCAMS] Skipping COMMAND type message for $mac, waiting for slave_cmd response');
          // Skip all notification systems for CLEARCAMS COMMAND type
          return;
        }
        
        // Handle all COMMAND type messages with pending tracking (except CLEARCAMS and SHMC)
        // CLEARCAMS and SHMC are handled via slave_cmd response, not COMMAND
        if (command == 'COMMAND' && commandText != null && mac != null && mac.isNotEmpty) {
          // Skip SHMC commands - they are handled via slave_cmd response only
          if (commandText.contains('SHMC')) {
            print('[SHMC] Skipping COMMAND type message for $mac: $commandText');
            return;
          }
          
          final pendingKey = '${mac}_$commandText';
          
          // Check if this is a device response (result could be 0 or 1 from device)
          // Device responses typically come after the send confirmation
          if (_pendingCommands.containsKey(pendingKey)) {
            // This is the device response - combine with send result
            final pendingData = _pendingCommands.remove(pendingKey)!;
            final sendResult = pendingData['sendResult'] as int;
            final sendMessage = pendingData['sendMessage'] as String;
            
            print('[COMMAND] Combined notification: Send=$sendResult, Device=$resultInt, MAC=$mac, Command=$commandText');
            
            // Use combined notification if available
            if (onCombinedResultMessage != null) {
              onCombinedResultMessage!(
                'COMMAND',
                sendResult,
                resultInt,
                sendMessage,
                msg.toString(),
                mac: mac,
                commandText: commandText,
              );
            }
            // Skip regular notification - we used combined
            return;
          } else {
            // This is the first message (send confirmation)
            // Store it and wait for device response
            _pendingCommands[pendingKey] = {
              'sendResult': resultInt,
              'sendMessage': msg.toString(),
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            };
            
            print('[COMMAND] Stored pending command: $pendingKey, waiting for device response');
            
            // Set timeout to auto-notify if no device response in 5 seconds
            Future.delayed(const Duration(seconds: 5), () {
              if (_pendingCommands.containsKey(pendingKey)) {
                final pendingData = _pendingCommands.remove(pendingKey)!;
                final sendResult = pendingData['sendResult'] as int;
                final sendMessage = pendingData['sendMessage'] as String;
                
                print('[COMMAND] Timeout - no device response for: $pendingKey');
                
                // Show combined notification with pending device result
                if (onCombinedResultMessage != null) {
                  onCombinedResultMessage!(
                    'COMMAND',
                    sendResult,
                    -1, // -1 = no device response yet
                    sendMessage,
                    'Cihazdan yanıt bekleniyor...',
                    mac: mac,
                    commandText: commandText,
                  );
                }
              }
            });
            
            // Skip regular notification for now - we'll combine later
            return;
          }
        }
        
        // Handle slave_cmd response - combine with pending SHMC command or handle CLEARCAMS
        if (command == 'slave_cmd') {
          final device = jsonData['device']?.toString();
          final shmcCommand = jsonData['command']?.toString();
          
          print('[slave_cmd] device=$device, command=$shmcCommand');
          print('[slave_cmd] Pending SHMC keys: ${_pendingShmcCommands.keys.toList()}');
          
          if (device != null && shmcCommand != null) {
            // Check if this is a CLEARCAMS response - show Phase 1 complete, wait for 'deleted' message
            if (shmcCommand == 'CLEARCAMS') {
              print('[CLEARCAMS] slave_cmd response received for device: $device, Phase 1 complete');
              print('[CLEARCAMS] Pending CLEARCAMS set: $_pendingClearCams');
              
              // Phase 1 complete - command was delivered to device
              // Always send Phase 1 notification for CLEARCAMS (dialog is listening)
              if (onTwoPhaseNotification != null) {
                onTwoPhaseNotification!(1, device, 'Komut cihaza iletildi');
              }
              // Don't remove from pending - wait for 'deleted' message for Phase 2
              return;
            }
            
            final pendingKey = '${device}_$shmcCommand';
            
            if (_pendingShmcCommands.containsKey(pendingKey)) {
              // Found pending command - show combined notification
              _pendingShmcCommands.remove(pendingKey);
              
              print('[SHMC] Combined notification: Device=$device, Command=$shmcCommand, Result=$resultInt, Msg=$msg');
              
              // Use combined notification - shows both send and result in one popup
              if (onCombinedResultMessage != null) {
                onCombinedResultMessage!(
                  'SHMC',
                  1, // sent successfully (we wouldn't get here otherwise)
                  resultInt, // device response (0=error, 1=success)
                  'Komut gönderildi',
                  msg.toString(),
                  mac: device,
                  commandText: shmcCommand,
                );
              }
              
              // Skip regular notification - we handled it
              return;
            }
          }
          
          // If not a pending command, still skip regular notification for slave_cmd
          // as it's a response type message
          return;
        }
        
        // Skip certain commands that have their own handling (like heartbeat, login, etc.)
        final skipCommands = ['login', 'changedone', 'system_info', 'user_groups', 'conversions'];
        if (!skipCommands.contains(command) && onResultMessage != null) {
          print('[ResultNotification] Command: $command, Result: $resultInt, Message: $msg, MAC: $mac, CommandText: $commandText');
          onResultMessage!(command.toString(), resultInt, msg.toString(), mac: mac, commandText: commandText);
        }
      }
      
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
        _errorMessage = 'Invalid username or password';
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

        case 'loginfail':
          // Login failed - wrong password/username
          _isLoggedIn = false;
          _isWaitingForChangedone = false;
          final errorMsg = jsonData['error'] ?? 'Login failed';
          final remainingAttempts = jsonData['remaining_attempts'];
          _errorMessage = remainingAttempts != null 
              ? '$errorMsg (Remaining attempts: $remainingAttempts)' 
              : errorMsg;
          print('[${DateTime.now().toString().split('.').first}] Login failed: $_errorMessage');
          disconnect().then((_) {
            _batchNotifyListeners();
          });
          _batchNotifyListeners();
          break;

        case 'loginok':
          // Login successful - send Monitor ecs_slaves message
          _isLoggedIn = true;
          _isWaitingForChangedone = true;
          _errorMessage = '';
          _currentLoggedInUsername = _lastUsername; // Login yapan kullanıcıyı kaydet
          print('[${DateTime.now().toString().split('.').first}] Login successful as $_currentLoggedInUsername, sending Monitor ecs_slaves');
          
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
          // Store conversions response in dedicated variable
          _lastMessage = jsonData;
          _lastConversionsResponse = jsonData;
          print('[${DateTime.now().toString().split('.').first}] Received conversions response');
          print('[Conversions] Data: ${jsonData['data']}');
          _batchNotifyListeners();
          break;

        case 'convert_rec':
          // Store convert_rec response for polling
          _lastMessage = jsonData;
          _lastConvertRecResponse = jsonData;
          final result = jsonData['result'];
          final msg = jsonData['msg'] ?? jsonData['message'] ?? '';
          final filePath = jsonData['file_path'] ?? '';
          final status = jsonData['status'] ?? '';
          print('[${DateTime.now().toString().split('.').first}] Received convert_rec response: result=$result, status=$status, message=$msg');
          if (filePath.isNotEmpty) {
            print('[ConvertRec] File path: $filePath');
          }
          
          // If result is 0 (error), notify ConversionTrackingProvider immediately
          if (result == 0 && _conversionTrackingProvider != null) {
            // Extract camera name from error message (format: "KAMERA104 kamerası convert işlemi başarısız...")
            String cameraName = '';
            final msgStr = msg.toString();
            if (msgStr.contains(' kamerası')) {
              cameraName = msgStr.split(' kamerası').first.trim();
            } else if (msgStr.contains('KAMERA')) {
              // Try to extract KAMERA<number> pattern
              final match = RegExp(r'KAMERA\d+').firstMatch(msgStr);
              if (match != null) {
                cameraName = match.group(0)!;
              }
            }
            
            if (cameraName.isNotEmpty) {
              print('[ConvertRec] ❌ Error for camera: $cameraName - $msg');
              _conversionTrackingProvider!.markAsError(
                cameraName: cameraName,
                errorMessage: msg.toString(),
              );
            } else {
              print('[ConvertRec] ❌ Error but could not extract camera name: $msg');
            }
          }
          
          _batchNotifyListeners();
          break;

        case 'error':
          // Handle error messages
          _lastMessage = jsonData;
          print('[${DateTime.now().toString().split('.').first}] Error: $message');
          
          // Forward to UserGroupProvider to show error
          if (_userGroupProvider != null) {
            _userGroupProvider!.handleOperationResult(
              success: false,
              message: message,
            );
          }
          _batchNotifyListeners();
          break;

        case 'set_network':
          // Handle network settings change response
          final result = jsonData['result'] as int?;
          final msg = message;
          
          print('🌐 WebSocket: Network settings response: $msg (result: $result)');
          
          if (result == 1) {
            // Success - device network changed, wait 30 seconds then reconnect
            print('⏳ Network settings updated successfully. Device will restart...');
            print('⏳ Waiting 30 seconds before reconnecting...');
            
            // Show message to user
            if (_userGroupProvider != null) {
              _userGroupProvider!.handleOperationResult(
                success: true,
                message: '$msg\n\nDevice is restarting, connection will be refreshed in 30 seconds...',
              );
            }
            
            // Schedule reconnection after 30 seconds
            Future.delayed(const Duration(seconds: 30), () async {
              print('🔄 Attempting to reconnect after network change...');
              
              // Disconnect current connection
              await disconnect();
              
              // Wait a bit more then reconnect
              await Future.delayed(const Duration(seconds: 2));
              
              // Use reconnect method which has saved credentials
              final success = await reconnect();
              
              if (success) {
                print('✅ Successfully reconnected after network change');
                if (_userGroupProvider != null) {
                  _userGroupProvider!.handleOperationResult(
                    success: true,
                    message: 'Connection successfully refreshed!',
                  );
                }
              } else {
                print('❌ Failed to reconnect after network change');
                if (_userGroupProvider != null) {
                  _userGroupProvider!.handleOperationResult(
                    success: false,
                    message: 'Connection could not be refreshed. Please login manually.',
                  );
                }
              }
            });
          } else {
            // Failed
            print('❌ Network settings update failed: $msg');
            if (_userGroupProvider != null) {
              _userGroupProvider!.handleOperationResult(
                success: false,
                message: msg,
              );
            }
          }
          _batchNotifyListeners();
          break;

        case 'success':
          // Handle success messages
          _lastMessage = jsonData;
          final action = jsonData['action'] ?? '';
          print('[${DateTime.now().toString().split('.').first}] Success: $message (action: $action)');
          
          // Parse and enhance permission messages
          String displayMessage = message;
          if (message.contains('Yetkiler:')) {
            displayMessage = _parsePermissionSuccessMessage(message);
          }
          
          // Handle group operations
          if (_userGroupProvider != null) {
            // Extract group name from success messages
            if (message.contains('silindi')) {
              // "Grup 'denememeeee' başarıyla silindi!"
              final groupNameMatch = RegExp(r"Grup '([^']+)' başarıyla silindi").firstMatch(message);
              if (groupNameMatch != null) {
                final groupName = groupNameMatch.group(1);
                print('🗑️ Deleting group from local state: $groupName');
                _userGroupProvider!.removeGroupLocally(groupName!);
              }
            } else if (message.contains('oluşturuldu')) {
              // "Grup 'name' başarıyla oluşturuldu!"
              print('✅ Group created, will refresh on next GETGROUPLIST');
            } else if (message.contains('güncellendi')) {
              // "Grup 'name' başarıyla güncellendi!"
              print('✅ Group updated, will refresh on next GETGROUPLIST');
            }
            
            // Forward success message
            _userGroupProvider!.handleOperationResult(
              success: true,
              message: displayMessage,
            );
          }
          _batchNotifyListeners();
          break;

        case 'pong':
          // Pong response from server - heartbeat acknowledgment, no action needed
          break;

        case 'deleted':
          // Handle deleted keys (e.g., cameras cleared from device, system data, etc.)
          // Format: {"c":"deleted", "keys":["ecs_slaves.36:56:F0:A5:36:30.cam", "cameras_mac.MAC.current.CAM_MAC", ...]}
          final keys = jsonData['keys'] as List<dynamic>?;
          if (keys != null && keys.isNotEmpty) {
            // Group keys by device MAC for better notification
            final Map<String, List<String>> deletedByDevice = {};
            final Map<String, Set<String>> deletedCamerasByDevice = {}; // Track camera MACs per device
            final List<String> otherDeletedKeys = [];
            
            for (var key in keys) {
              final keyStr = key.toString();
              
              // Check if this is an ecs_slaves key
              if (keyStr.startsWith('ecs_slaves.')) {
                final parts = keyStr.split('.');
                if (parts.length >= 2) {
                  final deviceMac = parts[1];
                  deletedByDevice.putIfAbsent(deviceMac, () => []);
                  deletedByDevice[deviceMac]!.add(keyStr);
                }
              } 
              // Check if this is a cameras_mac key (camera data per device)
              // Format: cameras_mac.<DEVICE_MAC>.current.<CAMERA_MAC>[.property]
              // Only process if the key contains '.current.' - this indicates actual camera deletion
              else if (keyStr.startsWith('cameras_mac.') && keyStr.contains('.current.')) {
                final parts = keyStr.split('.');
                if (parts.length >= 4) {
                  final deviceMac = parts[1]; // Device MAC
                  // Find the camera MAC (after 'current')
                  final currentIndex = parts.indexOf('current');
                  if (currentIndex >= 0 && currentIndex + 1 < parts.length) {
                    final cameraMac = parts[currentIndex + 1]; // Camera MAC
                    
                    deletedByDevice.putIfAbsent(deviceMac, () => []);
                    deletedByDevice[deviceMac]!.add(keyStr);
                    
                    // Track unique camera MACs being deleted
                    deletedCamerasByDevice.putIfAbsent(deviceMac, () => {});
                    deletedCamerasByDevice[deviceMac]!.add(cameraMac);
                    
                    print('[DELETED] cameras_mac.current key: device=$deviceMac, camera=$cameraMac, key=$keyStr');
                  }
                }
              }
              else if (keyStr.startsWith('all_cameras.')) {
                // all_cameras.<CAMERA_MAC>[.property] - camera data deleted from global list
                final parts = keyStr.split('.');
                if (parts.length >= 2) {
                  final cameraMac = parts[1];
                  // Track for deletion from global camera list
                  otherDeletedKeys.add(keyStr);
                  // Also add to a special set for global camera deletion
                  deletedCamerasByDevice.putIfAbsent('__global__', () => {});
                  deletedCamerasByDevice['__global__']!.add(cameraMac);
                  print('[DELETED] all_cameras key: camera=$cameraMac, key=$keyStr');
                }
              } else {
                otherDeletedKeys.add(keyStr);
              }
            }
            
            // Handle global camera deletions (from all_cameras.* keys)
            if (deletedCamerasByDevice.containsKey('__global__')) {
              final globalCameras = deletedCamerasByDevice['__global__']!;
              print('[DELETED] Global cameras to remove: ${globalCameras.length}');
              for (final cameraMac in globalCameras) {
                _cameraDevicesProvider?.removeCameraFromGlobalList(cameraMac);
              }
            }
            
            // Process each device's deleted keys
            for (var entry in deletedByDevice.entries) {
              final deviceMac = entry.key;
              final deviceKeys = entry.value;
              
              // Check what type of data was deleted
              // ecs_slaves.MAC.cam or ecs_slaves.MAC.cam.[0].property indicates all cameras deleted
              final hasCamDeleted = deviceKeys.any((k) => 
                  k.endsWith('.cam') || k.contains('.cam.['));
              final hasSystemDeleted = deviceKeys.any((k) => k.contains('.system'));
              final hasCamerasMacDeleted = deviceKeys.any((k) => k.startsWith('cameras_mac.'));
              
              // Handle ecs_slaves.*.cam deletion - all device cameras cleared
              if (hasCamDeleted) {
                print('[DELETED] Device $deviceMac cameras deleted (ecs_slaves.*.cam)');
                
                // Clear cameras locally - this removes from both device and global list
                _cameraDevicesProvider?.clearDeviceCamerasLocally(deviceMac);
                
                // Check if this was a pending CLEARCAMS command
                if (_pendingClearCams.contains(deviceMac)) {
                  _pendingClearCams.remove(deviceMac);
                  // Notify phase 2: Device confirmed deletion
                  if (onTwoPhaseNotification != null) {
                    onTwoPhaseNotification!(2, deviceMac, 'Cihaz kameraları sildi');
                  }
                } else {
                  // Not a pending CLEARCAMS, just notify normally
                  if (onResultMessage != null) {
                    onResultMessage!('deleted', 1, 'Cihaz $deviceMac kameraları silindi', mac: deviceMac);
                  }
                }
              }
              
              // Handle cameras_mac deletion - specific cameras removed
              if (hasCamerasMacDeleted && !hasCamDeleted) {
                final camerasDeleted = deletedCamerasByDevice[deviceMac] ?? {};
                print('[DELETED] Device $deviceMac specific cameras deleted: ${camerasDeleted.length} cameras');
                
                // Remove specific cameras locally
                for (final cameraMac in camerasDeleted) {
                  _cameraDevicesProvider?.removeCameraLocally(deviceMac, cameraMac);
                }
                
                // Check if this was a pending CLEARCAMS command
                if (_pendingClearCams.contains(deviceMac)) {
                  _pendingClearCams.remove(deviceMac);
                  // Notify phase 2: Device confirmed deletion
                  if (onTwoPhaseNotification != null) {
                    onTwoPhaseNotification!(2, deviceMac, 'Cihaz kameraları sildi (${camerasDeleted.length} kamera)');
                  }
                } else {
                  // Not a pending CLEARCAMS, just notify normally
                  if (onResultMessage != null) {
                    final shortMac = deviceMac.length > 8 
                        ? '...${deviceMac.substring(deviceMac.length - 8)}' 
                        : deviceMac;
                    onResultMessage!('deleted', 1, 
                        '[$shortMac] ${camerasDeleted.length} kamera silindi', 
                        mac: deviceMac);
                  }
                }
              }
              
              if (hasSystemDeleted) {
                // System data deleted - device is disconnecting or being removed
                print('[DELETED] Device $deviceMac system data deleted (${deviceKeys.length} keys)');
                
                // Check if the main system key is deleted (indicates full device removal)
                final mainSystemDeleted = deviceKeys.any((k) => 
                    k == 'ecs_slaves.$deviceMac.system' || 
                    k.endsWith('.system.shmc_ready') ||
                    k.endsWith('.system.progstate'));
                
                if (mainSystemDeleted) {
                  // Full system data deletion - remove or mark device as disconnected
                  _cameraDevicesProvider?.markDeviceDisconnected(deviceMac);
                }
                
                // Notify about system data deletion
                if (onResultMessage != null) {
                  final shortMac = deviceMac.length > 8 
                      ? '...${deviceMac.substring(deviceMac.length - 8)}' 
                      : deviceMac;
                  onResultMessage!('deleted', 1, 
                      'Cihaz [$shortMac] bağlantısı kesildi (${deviceKeys.length} veri silindi)', 
                      mac: deviceMac);
                }
              }
            }
            
            // Log other deleted keys if any
            if (otherDeletedKeys.isNotEmpty) {
              print('[DELETED] Other keys deleted: $otherDeletedKeys');
            }
          }
          _batchNotifyListeners();
          break;

        case 'add_group_to_cam':
          // Handle add camera to group response
          final result = jsonData['result'] as int?;
          final msg = jsonData['msg'] ?? '';
          final cameraMac = jsonData['camera'] ?? jsonData['mac'] ?? '';
          
          print('📷 WebSocket: add_group_to_cam response: result=$result, msg=$msg, camera=$cameraMac');
          
          if (result == 0) {
            // Failed - result 0 means error
            print('❌ Failed to add camera to group: $msg');
            if (_userGroupProvider != null) {
              final errorMessage = cameraMac.isNotEmpty 
                  ? 'Kamera $cameraMac: $msg'
                  : msg;
              _userGroupProvider!.handleOperationResult(
                success: false,
                message: errorMessage,
              );
            }
          } else {
            // Success - result 1 or other non-zero value
            print('✅ Camera added to group successfully: $msg');
            if (_userGroupProvider != null) {
              final successMessage = cameraMac.isNotEmpty 
                  ? 'Kamera $cameraMac: $msg'
                  : msg;
              _userGroupProvider!.handleOperationResult(
                success: true,
                message: successMessage,
              );
            }
          }
          _batchNotifyListeners();
          break;

        case 'parameter_set':
          // Handle SETINT command response
          final result = jsonData['result'] as int?;
          final msg = jsonData['msg'] ?? '';
          final key = jsonData['key'] ?? '';
          final value = jsonData['value'];
          
          print('⚙️ WebSocket: parameter_set response: result=$result, msg=$msg, key=$key, value=$value');
          
          // Store the last parameter set result for UI notification
          _lastParameterSetResult = {
            'success': result == 1,
            'message': msg,
            'key': key,
            'value': value,
          };
          
          // Log to WebSocket log
          if (result == 1) {
            _logMessage('INFO: ✅ $msg');
          } else {
            _logMessage('ERROR: ❌ $msg');
          }
          
          _batchNotifyListeners();
          break;

        default:
          // Handle any command with result/msg pattern (generic command response handler)
          // Format: {"c":"command_name", "result":1, "msg":"..."}
          if (jsonData.containsKey('result')) {
            final result = jsonData['result'] as int?;
            final msg = jsonData['msg'] ?? message ?? '';
            
            print('📨 WebSocket: Command "$command" response: result=$result, msg=$msg');
            
            if (_userGroupProvider != null && msg.toString().isNotEmpty) {
              final isSuccess = result == 1;
              _userGroupProvider!.handleOperationResult(
                success: isSuccess,
                message: '$msg',
              );
            }
            _batchNotifyListeners();
          } else {
            print('[${DateTime.now().toString().split('.').first}] Received unknown command: $command');
          }
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
    _logMessage('INFO: WebSocket bağlantısı koptu');
    
    // Keep login state - we'll try to reconnect with same credentials
    final wasLoggedIn = _isLoggedIn;
    final hasCredentials = _lastUsername != null && _lastPassword != null;
    
    print('[${DateTime.now().toString().split('.').first}] Disconnect state: wasLoggedIn=$wasLoggedIn, hasCredentials=$hasCredentials');
    
    _isConnected = false;
    _isWaitingForChangedone = false;
    _socket = null;
    _batchNotifyListeners();

    // Try to reconnect if we have credentials (either was logged in or have saved credentials)
    if (hasCredentials) {
      print('[${DateTime.now().toString().split('.').first}] Connection lost, scheduling reconnect...');
      _logMessage('INFO: Bağlantı koptu, 3 saniye sonra yeniden bağlanılacak...');
      _scheduleReconnect();
    } else {
      print('[${DateTime.now().toString().split('.').first}] No credentials saved, not scheduling reconnect');
      _logMessage('INFO: Kayıtlı kimlik bilgisi yok, yeniden bağlanma planlanmıyor');
    }
  }

  // Handle WebSocket errors
  void _handleError(dynamic error) {
    print('WebSocket error: $error');
    print('[${DateTime.now().toString().split('.').first}] WebSocket error: $error');
    _logMessage('ERROR: WebSocket hatası: $error');
    _errorMessage = error.toString();
    
    // Keep login state - we'll try to reconnect with same credentials
    final wasLoggedIn = _isLoggedIn;
    final hasCredentials = _lastUsername != null && _lastPassword != null;
    
    print('[${DateTime.now().toString().split('.').first}] Error state: wasLoggedIn=$wasLoggedIn, hasCredentials=$hasCredentials');
    
    _isConnected = false;
    _isConnecting = false;
    _isWaitingForChangedone = false;
    _socket = null;
    
    // Start connection error handling and auto-reconnect
    _handleConnectionError();
    
    _batchNotifyListeners();

    // Try to reconnect if we have credentials
    if (hasCredentials) {
      print('[${DateTime.now().toString().split('.').first}] Connection error, scheduling reconnect...');
      _logMessage('INFO: Bağlantı hatası, 3 saniye sonra yeniden bağlanılacak...');
      _scheduleReconnect();
    } else {
      print('[${DateTime.now().toString().split('.').first}] No credentials saved, not scheduling reconnect');
      _logMessage('INFO: Kayıtlı kimlik bilgisi yok, yeniden bağlanma planlanmıyor');
    }
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
    // Don't reconnect if we don't have credentials
    if (_lastUsername == null || _lastPassword == null) {
      print('[${DateTime.now().toString().split('.').first}] Reconnect suppressed: no saved credentials.');
      _logMessage('INFO: Yeniden bağlanma iptal edildi: kayıtlı kimlik bilgisi yok');
      return;
    }
    
    // Don't schedule multiple reconnect attempts
    if (_reconnectTimer != null && _reconnectTimer!.isActive) {
      print('[${DateTime.now().toString().split('.').first}] Reconnect already scheduled, skipping...');
      return;
    }
    
    _stopReconnectTimer(); // Stop existing timer if any

    print('[${DateTime.now().toString().split('.').first}] Scheduling reconnect in 3 seconds...');
    _logMessage('INFO: 3 saniye sonra yeniden bağlanılacak...');
    
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      print('Attempting to reconnect...');
      print('[${DateTime.now().toString().split('.').first}] Attempting to reconnect to $_serverIp:$_serverPort');
      _logMessage('INFO: Yeniden bağlanılıyor: $_serverIp:$_serverPort');
      
      final success = await connect(_serverIp, _serverPort,
          username: _lastUsername!, password: _lastPassword!, rememberMe: _rememberMe);
      
      if (!success) {
        print('[${DateTime.now().toString().split('.').first}] Reconnect failed, will retry in 5 seconds...');
        _logMessage('ERROR: Yeniden bağlanma başarısız, 5 saniye sonra tekrar denenecek...');
        // Schedule another reconnect attempt with longer delay
        _reconnectTimer = Timer(const Duration(seconds: 5), () {
          _scheduleReconnect();
        });
      } else {
        print('[${DateTime.now().toString().split('.').first}] Reconnect successful!');
        _logMessage('INFO: Yeniden bağlantı başarılı!');
      }
    });
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
    
    // Store login state before resetting
    final wasLoggedIn = _isLoggedIn;
    
    _isConnected = false;
    _isLoggedIn = false;
    
    // Start auto-reconnect only if user was previously logged in and we have saved credentials
    if (wasLoggedIn && _lastUsername != null && _lastPassword != null) {
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

  /// Parse success messages containing permission info
  /// Example: "Grup 'name' başarıyla oluşturuldu! (Yetkiler: 1111111111111111)"
  /// Returns: "Grup 'name' başarıyla oluşturuldu! (VIEW, RECORD, USER, GROUP, ADMIN, ...)"
  String _parsePermissionSuccessMessage(String message) {
    try {
      // Extract permission string from message
      final regex = RegExp(r'Yetkiler:\s*(\d{16})');
      final match = regex.firstMatch(message);
      
      if (match != null && match.groupCount >= 1) {
        final permString = match.group(1)!;
        
        // Parse permissions
        final grantedPerms = Permissions.parsePermissionString(permString);
        
        if (grantedPerms.isEmpty) {
          return message.replaceAll(
            RegExp(r'\(Yetkiler:.*?\)'),
            '(Yetki yok)',
          );
        }
        
        // Create human-readable permission list
        final permNames = grantedPerms.map((p) => p.name).join(', ');
        
        // Replace the permission string with names
        return message.replaceAll(
          RegExp(r'\(Yetkiler:.*?\)'),
          '(Yetkiler: $permNames)',
        );
      }
      
      return message;
    } catch (e) {
      print('Error parsing permission message: $e');
      return message;
    }
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
