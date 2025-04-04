import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/system_info.dart';

typedef MessageHandler = void Function(Map<String, dynamic> message);

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  List<String> _messageLog = [];
  SystemInfo? _systemInfo;
  bool _monitorCommandSent = false;
  MessageHandler? _onParsedMessage;
  
  String _username = '';
  String _password = '';
  String _address = '';
  String _port = '';
  
  // Auto-reconnect properties
  Timer? _reconnectTimer;
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 10;
  static const int reconnectDelay = 3; // seconds
  
  // Heartbeat properties
  Timer? _heartbeatTimer;
  static const int heartbeatInterval = 30; // seconds
  DateTime? _lastMessageTime;
  
  // Getters
  bool get isConnected => _isConnected;
  List<String> get messageLog => List.unmodifiable(_messageLog);
  SystemInfo? get systemInfo => _systemInfo;
  
  // Set message handler
  void setMessageHandler(MessageHandler handler) {
    _onParsedMessage = handler;
  }
  
  // Connect to WebSocket server
  Future<bool> connect(String address, String port, String username, String password) async {
    if (_isConnected) {
      debugPrint('Already connected to WebSocket server');
      return true;
    }
    
    try {
      // Store connection parameters for possible reconnection
      _address = address;
      _port = port;
      _username = username;
      _password = password;
      _shouldReconnect = true;
      
      // Attempt to connect
      final uri = Uri.parse('ws://$address:$port');
      _channel = IOWebSocketChannel.connect(uri);
      
      // Add to message log
      final timestamp = DateTime.now().toString();
      _addToLog('[$timestamp] Connecting to WebSocket server: ${uri.toString()}');
      
      // Listen for messages
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false
      );
      
      // Set connection status and notify listeners
      _isConnected = true;
      _lastMessageTime = DateTime.now();
      _reconnectAttempts = 0;
      _startHeartbeat();
      notifyListeners();
      
      debugPrint('Connected to WebSocket server: ${uri.toString()}');
      return true;
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _isConnected = false;
      notifyListeners();
      _scheduleReconnect();
      return false;
    }
  }
  
  // Start heartbeat to monitor connection health
  void _startHeartbeat() {
    _stopHeartbeat(); // Stop existing timer if any
    
    _heartbeatTimer = Timer.periodic(Duration(seconds: heartbeatInterval), (timer) {
      if (!_isConnected) {
        _stopHeartbeat();
        return;
      }
      
      // Check when we last received a message
      final now = DateTime.now();
      final lastMessageDuration = _lastMessageTime != null 
        ? now.difference(_lastMessageTime!) 
        : Duration(seconds: heartbeatInterval * 2);
      
      // If it's been too long since a message was received, consider the connection dead
      if (lastMessageDuration.inSeconds > heartbeatInterval * 2) {
        debugPrint('No messages received in ${lastMessageDuration.inSeconds} seconds. Resetting connection.');
        _resetConnection();
        return;
      }
      
      // Send a heartbeat message if connected
      if (_channel != null && _isConnected) {
        _channel!.sink.add('PING');
        debugPrint('Heartbeat sent: PING');
      }
    });
  }
  
  // Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  
  // Send login message
  void sendLoginMessage(String username, String password) {
    if (_channel != null && _isConnected) {
      final loginMessage = 'LOGIN "$username" "$password"';
      _channel!.sink.add(loginMessage);
      debugPrint('Sent login message: $loginMessage');
      
      // Add to message log
      final timestamp = DateTime.now().toString();
      _addToLog('[$timestamp] Sent: $loginMessage');
    }
  }
  
  // Handle received message
  void _onMessage(dynamic message) {
    try {
      // Update last message time
      _lastMessageTime = DateTime.now();
      
      // Log the raw message first
      final timestamp = DateTime.now().toString();
      final rawLogMessage = '[$timestamp] Received: $message';
      _addToLog(rawLogMessage);
      
      // Reset reconnect attempts as we're receiving messages
      _reconnectAttempts = 0;
      
      // Try to parse as JSON if possible
      try {
        final jsonMessage = jsonDecode(message.toString());
        final jsonLogMessage = '[$timestamp] Parsed JSON: ${jsonEncode(jsonMessage)}';
        _addToLog(jsonLogMessage);
        
        // Check for login message
        if (jsonMessage is Map) {
          if (jsonMessage['c'] == 'login' && 
              (jsonMessage['msg'] == 'Oturum açılmamış!' || 
               jsonMessage['msg'].toString().contains('Oturum açılmamış'))) {
            
            // If we receive this specific login message, send login credentials
            sendLoginMessage(_username, _password);
            // Reset monitor command flag on new login
            _monitorCommandSent = false;
          }
          
          // Check for system info message
          else if (jsonMessage['c'] == 'sysinfo') {
            // Parse system info
            _systemInfo = SystemInfo.fromJson(jsonMessage);
            
            // Send the monitor command only once after login
            if (!_monitorCommandSent) {
              sendMonitorCommand();
              _monitorCommandSent = true;
            }
            
            notifyListeners();
          }
          
          // Pass the parsed message to the handler if provided
          if (_onParsedMessage != null && jsonMessage is Map<String, dynamic>) {
            // For changed messages, add extra debug info
            if (jsonMessage['c'] == 'changed' && 
                jsonMessage.containsKey('data') && 
                jsonMessage.containsKey('val')) {
              
              final String dataPath = jsonMessage['data'].toString();
              
              // Add detailed debug info for camera device messages
              if (dataPath.startsWith('ecs.slaves.m_')) {
                debugPrint('📦 Device message: ${jsonMessage['data']} = ${jsonMessage['val']}');
                _onParsedMessage!(jsonMessage);
              }
            } 
            // Handle login success
            else if (jsonMessage['c'] == 'loginok') {
              debugPrint('👤 Successfully logged in: ${jsonMessage['username']}');
              _onParsedMessage!(jsonMessage);
            }
            // Handle any other message type
            else {
              _onParsedMessage!(jsonMessage);
            }
          }
        }
        
      } catch (e) {
        // Not valid JSON, that's okay, we already logged the raw message
        debugPrint('Message is not valid JSON: $e');
        
        // Check for PONG response to our PING
        if (message.toString() == 'PONG') {
          debugPrint('Heartbeat response received: PONG');
          return;
        }
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
    }
  }
  
  // Send the "DO MONITORECS" command
  void sendMonitorCommand() {
    if (_channel != null && _isConnected) {
      final monitorCommand = 'DO MONITORECS';
      _channel!.sink.add(monitorCommand);
      
      // Log the command
      final timestamp = DateTime.now().toString();
      final logMessage = '[$timestamp] Sent: $monitorCommand';
      _addToLog(logMessage);
      debugPrint(logMessage);
    }
  }
  
  // Handle WebSocket errors
  void _onError(dynamic error) {
    debugPrint('WebSocket error: $error');
    _addToLog('[${DateTime.now()}] Error: $error');
    _resetConnection();
  }
  
  // Handle WebSocket closure
  void _onDone() {
    debugPrint('WebSocket connection closed');
    _addToLog('[${DateTime.now()}] Connection closed');
    _resetConnection();
  }
  
  // Reset connection status and attempt reconnect if needed
  void _resetConnection() {
    if (_isConnected) {
      _isConnected = false;
      notifyListeners();
    }
    
    // Clean up
    _channel?.sink.close();
    _channel = null;
    _stopHeartbeat();
    
    // Schedule reconnect if needed
    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }
  
  // Schedule a reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectTimer != null || _reconnectAttempts >= maxReconnectAttempts) {
      return;
    }
    
    _reconnectAttempts++;
    
    debugPrint('Scheduling reconnect attempt ${_reconnectAttempts}/$maxReconnectAttempts in $reconnectDelay seconds...');
    
    _reconnectTimer = Timer(Duration(seconds: reconnectDelay), () {
      _reconnectTimer = null;
      if (_shouldReconnect && !_isConnected) {
        debugPrint('Attempting to reconnect...');
        connect(_address, _port, _username, _password);
      }
    });
  }
  
  // Send a message
  void sendMessage(String message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(message);
      
      // Log the message
      final timestamp = DateTime.now().toString();
      _addToLog('[$timestamp] Sent: $message');
      
      debugPrint('Sent message: $message');
    } else {
      debugPrint('Cannot send message, not connected to WebSocket server');
    }
  }
  
  // Disconnect WebSocket
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopHeartbeat();
    
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    
    if (_isConnected) {
      _isConnected = false;
      notifyListeners();
    }
    
    _addToLog('[${DateTime.now()}] Disconnected from WebSocket server');
    debugPrint('Disconnected from WebSocket server');
  }
  
  // Add message to log with timestamp
  void _addToLog(String message) {
    _messageLog.add(message);
    
    // Limit log size to prevent memory issues
    if (_messageLog.length > 1000) {
      _messageLog.removeAt(0);
    }
  }
  
  // Clear message log
  void clearLog() {
    _messageLog.clear();
    notifyListeners();
  }
  
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
