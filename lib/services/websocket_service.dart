import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/system_info.dart';

class WebSocketService with ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isAuthenticating = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  List<String> _messageLog = [];
  SystemInfo? _systemInfo;
  
  // Authentication credentials
  String _address = '';
  String _port = '';
  String _username = '';
  String _password = '';
  
  // Message handler function reference
  Function(Map<String, dynamic>)? _messageHandler;
  
  // Getters
  bool get isConnected => _isConnected;
  List<String> get messageLog => _messageLog;
  SystemInfo? get systemInfo => _systemInfo;
  
  // Set a message handler function
  void setMessageHandler(Function(Map<String, dynamic>) handler) {
    _messageHandler = handler;
  }
  
  // Connect to WebSocket server
  Future<bool> connect(String address, String port, String username, String password) async {
    // Store credentials for reconnection
    _address = address;
    _port = port;
    _username = username;
    _password = password;
    
    if (_isConnected) {
      print('[WebSocket] Already connected, disconnecting first');
      disconnect();
    }
    
    try {
      final wsUrl = 'ws://$address:$port';
      print('[WebSocket] Connecting to $wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      _isAuthenticating = true;
      
      print('[WebSocket] Connected, waiting for messages');
      _addToLog('Connected to $wsUrl');
      
      // Listen for incoming messages
      _channel!.stream.listen((message) {
        _handleMessage(message);
      }, onDone: () {
        print('[WebSocket] Connection closed');
        _handleDisconnect();
      }, onError: (error) {
        print('[WebSocket] Error: $error');
        _addToLog('Error: $error');
        _handleDisconnect();
      });
      
      // Start heartbeat
      _startHeartbeat();
      
      notifyListeners();
      return true;
    } catch (e) {
      print('[WebSocket] Connection error: $e');
      _addToLog('Connection error: $e');
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }
  
  // Reconnect to the server
  Future<bool> reconnect() async {
    return await connect(_address, _port, _username, _password);
  }
  
  // Send a message to the server
  void sendMessage(String message) {
    if (_isConnected && _channel != null) {
      print('[WebSocket] Sending: $message');
      _addToLog('Sent: $message');
      _channel!.sink.add(message);
    } else {
      print('[WebSocket] Not connected, cannot send message');
      _addToLog('Not connected, cannot send message');
    }
  }
  
  // Disconnect from the server
  void disconnect() {
    if (_channel != null) {
      print('[WebSocket] Disconnecting');
      _channel!.sink.close();
      _channel = null;
    }
    
    _stopHeartbeat();
    _stopReconnectTimer();
    
    _isConnected = false;
    _isAuthenticating = false;
    
    notifyListeners();
  }
  
  // Handle disconnect and auto-reconnect
  void _handleDisconnect() {
    _isConnected = false;
    _channel = null;
    _stopHeartbeat();
    
    _addToLog('Disconnected, will try to reconnect...');
    
    // Set up reconnection timer
    _startReconnectTimer();
    
    notifyListeners();
  }
  
  // Start heartbeat timer
  void _startHeartbeat() {
    _stopHeartbeat(); // Ensure no duplicate timers
    
    // Send a heartbeat every 30 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && !_isAuthenticating) {
        print('[WebSocket] Sending heartbeat');
        sendMessage('PING');
      }
    });
  }
  
  // Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  
  // Start reconnect timer
  void _startReconnectTimer() {
    _stopReconnectTimer(); // Ensure no duplicate timers
    
    // Try to reconnect every 5 seconds
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      print('[WebSocket] Attempting to reconnect...');
      reconnect().then((success) {
        if (success) {
          print('[WebSocket] Reconnection successful');
          _stopReconnectTimer();
        }
      });
    });
  }
  
  // Stop reconnect timer
  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
  
  // Handle incoming message
  void _handleMessage(dynamic message) {
    print('[WebSocket] Received: $message');
    _addToLog('Received: $message');
    
    // Skip empty messages
    if (message == null || message.toString().trim().isEmpty) {
      return;
    }
    
    // Check for camera messages and always print them in a special format
    if (message.toString().contains('cam')) {
      print('🎥 [WebSocket] CAMERA MESSAGE: $message');
    }
    
    try {
      // Try to parse as JSON
      final Map<String, dynamic> parsed = json.decode(message);
      
      // Handle system information
      if (parsed['c'] == 'sysinfo') {
        _handleSystemInfo(parsed);
      }
      
      // Handle login message
      else if (parsed['c'] == 'login') {
        _handleLoginMessage(parsed);
      }
      
      // Special logging for camera-related properties
      else if (parsed['c'] == 'changed' && 
               parsed.containsKey('data') && 
               parsed['data'].toString().contains('cam')) {
        print('📦 Camera message: ${parsed['data']} = ${parsed['val']}');
        
        // Also forward to handler
        if (_messageHandler != null) {
          _messageHandler!(parsed);
        }
      }
      
      // Handle device property change
      else if (parsed['c'] == 'changed' && parsed.containsKey('data')) {
        // Check if it's a device message
        if (parsed['data'].toString().startsWith('ecs.slaves.')) {
          print('📦 Device message: ${parsed['data']} = ${parsed['val']}');
        }
        
        // Forward to handler
        if (_messageHandler != null) {
          _messageHandler!(parsed);
        }
      }
      
      // Forward other messages to handler
      else if (_messageHandler != null) {
        _messageHandler!(parsed);
      }
      
    } catch (e) {
      // Handle non-JSON messages
      
      // Check if it's a PONG response
      if (message.toString() == 'PONG') {
        print('[WebSocket] Received heartbeat response');
      }
      // Any other non-JSON message
      else {
        print('[WebSocket] Non-JSON message: $message');
      }
    }
    
    notifyListeners();
  }
  
  // Handle system information message
  void _handleSystemInfo(Map<String, dynamic> message) {
    // Parse system info
    _systemInfo = SystemInfo.fromJson(message);
    print('[WebSocket] Received system info: CPU Temp: ${_systemInfo?.cpuTemp}, Memory: ${_systemInfo?.totalRam}/${_systemInfo?.freeRam}');
  }
  
  // Handle login-related messages
  void _handleLoginMessage(Map<String, dynamic> message) {
    // Check for login prompt
    if (message['msg'] == 'Oturum açılmamış!') {
      print('[WebSocket] Login required, sending credentials');
      _addToLog('Login required, sending credentials');
      
      // Send login command
      sendMessage('LOGIN $_username $_password');
      _isAuthenticating = true;
    }
    // Check for successful login
    else if (message['msg'] == 'Oturum açıldı!') {
      print('[WebSocket] Login successful');
      _addToLog('Login successful');
      
      // Request system monitoring after login
      sendMessage('DO MONITORECS');
      _isAuthenticating = false;
    }
    // Check for login failure
    else if (message['msg'].toString().contains('hatalı')) {
      print('[WebSocket] Login failed: ${message['msg']}');
      _addToLog('Login failed: ${message['msg']}');
      _isAuthenticating = false;
    }
  }
  
  // Add message to log
  void _addToLog(String message) {
    _messageLog.add('[${DateTime.now()}] $message');
    
    // Limit log size to 100 entries
    if (_messageLog.length > 100) {
      _messageLog.removeAt(0);
    }
  }
  
  // Clear message log
  void clearLog() {
    _messageLog.clear();
    notifyListeners();
  }
  
  // Clean up resources
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
