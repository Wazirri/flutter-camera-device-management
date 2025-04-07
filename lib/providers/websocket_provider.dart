import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

import 'camera_devices_provider.dart';

class WebSocketProvider with ChangeNotifier {
  // Store websocket connection
  WebSocketChannel? _channel;
  
  // Store connection state
  bool _isConnected = false;
  bool _isAuthenticated = false;
  bool _isConnecting = false;
  
  // Store login credentials
  String _username = '';
  String _password = '';
  
  // Store connection details
  String _serverHost = '85.104.114.145'; // Default host
  int _serverPort = 1200; // Default port
  
  // Store log messages
  List<String> _logMessages = [];
  
  // Store the last received message for other providers to access
  dynamic _lastMessage;
  
  // Maximum number of log messages to store
  static const int maxLogMessages = 100;
  
  // Heartbeat timer
  Timer? _heartbeatTimer;
  
  // Auto reconnect timer
  Timer? _reconnectTimer;
  
  // Reference to camera devices provider
  CameraDevicesProvider? _cameraDevicesProvider;
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  bool get isConnecting => _isConnecting;
  List<String> get logMessages => _logMessages;
  String get username => _username;
  String get serverHost => _serverHost;
  int get serverPort => _serverPort;
  dynamic get lastMessage => _lastMessage;
  
  // Constructor
  WebSocketProvider() {
    debugPrint("WebSocketProvider initialized");
    
    // Determine the server connection details based on platform
    _determineServerConnection();
  }
  
  // Set the camera devices provider reference
  void setCameraDevicesProvider(CameraDevicesProvider provider) {
    _cameraDevicesProvider = provider;
  }
  
  // Determine the server connection details based on platform
  void _determineServerConnection() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // When running on desktop, connect to localhost WebSocket server
      _serverHost = 'localhost';
      _serverPort = 5000;
      debugPrint("Using desktop WebSocket connection: $_serverHost:$_serverPort");
    } else {
      // Keep default values for mobile platforms
      debugPrint("Using mobile WebSocket connection: $_serverHost:$_serverPort");
    }
  }
  
  // Connect to WebSocket server
  Future<bool> connect() async {
    if (_isConnected || _isConnecting) {
      debugPrint("Already connected or connecting to WebSocket");
      return _isConnected;
    }
    
    _isConnecting = true;
    notifyListeners();
    
    try {
      // Check if the server is reachable
      bool isReachable = await _isServerReachable();
      if (!isReachable) {
        addLog("Server is not reachable at $_serverHost:$_serverPort");
        _isConnecting = false;
        notifyListeners();
        return false;
      }

      // Determine the correct WebSocket URL based on the platform
      String wsUrl;
      
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop platforms, connect to the testing WebSocket server
        wsUrl = 'ws://$_serverHost:$_serverPort/ws';
      } else {
        // For mobile platforms, connect to the production WebSocket server
        wsUrl = 'ws://$_serverHost:$_serverPort';
      }
      
      debugPrint("Connecting to WebSocket at $wsUrl");
      addLog("Connecting to $wsUrl");
      
      // Create the WebSocket channel
      _channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        pingInterval: const Duration(seconds: 5),
      );
      
      // Listen for messages from the server
      _channel!.stream.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: _handleError,
        cancelOnError: false,
      );
      
      _isConnected = true;
      _isConnecting = false;
      addLog("Connected to WebSocket server");
      
      // Setup heartbeat to keep connection alive
      _setupHeartbeat();
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("WebSocket connection error: $e");
      addLog("Connection error: $e");
      _isConnected = false;
      _isConnecting = false;
      notifyListeners();
      
      // Schedule auto reconnect
      _scheduleReconnect();
      
      return false;
    }
  }
  
  // Check if server is reachable
  Future<bool> _isServerReachable() async {
    try {
      // For desktop servers, use the HTTP health endpoint to check reachability
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final response = await http.get(
          Uri.parse('http://$_serverHost:$_serverPort/health'),
        ).timeout(const Duration(seconds: 5));
        
        return response.statusCode == 200;
      } else {
        // For mobile servers, just try to connect to the host
        final socket = await Socket.connect(
          _serverHost, 
          _serverPort,
          timeout: const Duration(seconds: 5),
        );
        socket.destroy();
        return true;
      }
    } catch (e) {
      debugPrint("Server reachability check failed: $e");
      return false;
    }
  }
  
  // Disconnect from WebSocket server
  Future<void> disconnect() async {
    if (!_isConnected) {
      return;
    }
    
    // Cancel timers
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    // Close the channel
    try {
      await _channel?.sink.close(1000, "Client disconnect");
    } catch (e) {
      debugPrint("Error closing WebSocket channel: $e");
    }
    
    _isConnected = false;
    _isAuthenticated = false;
    notifyListeners();
    
    addLog("Disconnected from WebSocket server");
  }
  
  // Handle disconnection
  void _handleDisconnect() {
    if (_isConnected) {
      debugPrint("WebSocket disconnected");
      addLog("Disconnected from server");
      
      _isConnected = false;
      _isAuthenticated = false;
      notifyListeners();
      
      // Schedule reconnect
      _scheduleReconnect();
    }
  }
  
  // Handle connection error
  void _handleError(dynamic error) {
    debugPrint("WebSocket error: $error");
    addLog("Connection error: $error");
    
    _isConnected = false;
    _isAuthenticated = false;
    notifyListeners();
    
    // Schedule reconnect
    _scheduleReconnect();
  }
  
  // Schedule reconnection
  void _scheduleReconnect() {
    if (_reconnectTimer != null) {
      _reconnectTimer!.cancel();
    }
    
    debugPrint("Scheduling reconnect in 5 seconds");
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && !_isConnecting) {
        debugPrint("Attempting to reconnect...");
        connect();
      }
    });
  }
  
  // Setup heartbeat timer
  void _setupHeartbeat() {
    // Cancel existing timer if any
    _heartbeatTimer?.cancel();
    
    // Create new timer that sends a ping every 30 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        debugPrint("Sending heartbeat ping");
        sendMessage("PING");
      } else {
        timer.cancel();
      }
    });
  }
  
  // Send message to server
  void sendMessage(String message) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(message);
        addLog("Sent: $message");
      } catch (e) {
        debugPrint("Error sending message: $e");
        addLog("Send error: $e");
      }
    } else {
      debugPrint("Cannot send message: not connected");
      addLog("Cannot send message: not connected");
    }
  }
  
  // Handle incoming message
  void _handleMessage(dynamic message) {
    if (message == null) return;
    
    // Log the raw message for debugging
    debugPrint("Received: $message");
    
    // Store the last message for other providers to access
    _lastMessage = message;
    
    // Handle ping response
    if (message == "PONG") {
      debugPrint("Received PONG heartbeat response");
      return;
    }
    
    // Handle JSON messages
    try {
      Map<String, dynamic> jsonData = jsonDecode(message);
      
      // Add to log with formatted JSON for readability
      addLog("Received: ${jsonEncode(jsonData)}");
      
      // Handle different message types based on the 'c' field
      String messageType = jsonData['c'] ?? '';
      
      switch (messageType) {
        case 'login':
          _handleLoginResponse(jsonData);
          break;
        case 'changed':
          _handleChangedData(jsonData);
          break;
        case 'sysinfo':
          _handleSystemInfo(jsonData);
          break;
        default:
          // Other message types
          debugPrint("Unhandled message type: $messageType");
      }
    } catch (e) {
      // If not a JSON message, just add to log
      addLog("Received non-JSON message: $message");
    }
    
    // Notify listeners of the new message
    notifyListeners();
  }
  
  // Handle login response
  void _handleLoginResponse(Map<String, dynamic> data) {
    final status = data['status'] ?? '';
    final message = data['msg'] ?? '';
    
    if (status == 'success') {
      _isAuthenticated = true;
      addLog("Login successful");
      
      // After successful login, start monitoring ECS
      sendMessage("DO MONITORECS");
    } else {
      _isAuthenticated = false;
      addLog("Login failed: $message");
    }
    
    notifyListeners();
  }
  
  // Handle changed data (device/camera updates)
  void _handleChangedData(Map<String, dynamic> data) {
    final String dataPath = data['data'] ?? '';
    final dynamic value = data['value'];
    
    // Check if it's a camera device update (ecs.slaves.m_*)
    if (dataPath.startsWith('ecs.slaves.m_') && value != null) {
      if (_cameraDevicesProvider != null) {
        // Pass the camera device update to the camera devices provider
        _cameraDevicesProvider!.handleCameraDeviceUpdate(dataPath, value);
      } else {
        debugPrint("CameraDevicesProvider not set, cannot handle camera device update");
      }
    }
  }
  
  // Handle system information updates
  void _handleSystemInfo(Map<String, dynamic> data) {
    // Just log and store system info in this provider
    // Can be expanded later to pass to a dedicated system info provider
    debugPrint("System info update received");
  }
  
  // Login to the server
  Future<bool> login(String username, String password) async {
    if (!_isConnected) {
      bool connected = await connect();
      if (!connected) {
        addLog("Cannot login: not connected");
        return false;
      }
    }
    
    _username = username;
    _password = password;
    
    // Send login message
    sendMessage("LOGIN $username $password");
    
    // Return current authentication state
    // Note: This will be updated when the server responds
    return _isAuthenticated;
  }
  
  // Add a message to the log
  void addLog(String message) {
    final timestamp = DateTime.now().toString().substring(0, 19);
    final logMessage = "[$timestamp] $message";
    
    _logMessages.add(logMessage);
    
    // Keep log size manageable
    if (_logMessages.length > maxLogMessages) {
      _logMessages = _logMessages.sublist(_logMessages.length - maxLogMessages);
    }
  }
  
  // Handle app lifecycle changes (called from parent widget)
  void handleAppLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App is visible and responding to user input
        if (!_isConnected && !_isConnecting) {
          debugPrint("App resumed, attempting to reconnect");
          connect();
        }
        break;
      case AppLifecycleState.inactive:
        // App is inactive, happens when notifications or modal alerts appear
        break;
      case AppLifecycleState.paused:
        // App is not visible to the user, running in the background
        break;
      case AppLifecycleState.detached:
        // Application is detached (applicable for iOS and Android)
        // Ensure clean disconnect
        disconnect();
        break;
      default:
        break;
    }
  }
  
  // Clean up resources
  @override
  void dispose() {
    debugPrint("Disposing WebSocketProvider");
    
    // Cancel timers
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    
    // Close connection
    _channel?.sink.close();
    
    super.dispose();
  }
}
