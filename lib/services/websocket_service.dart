import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/system_info.dart';

typedef MessageHandler = void Function(Map<String, dynamic> message);

class WebSocketService with ChangeNotifier {
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
      print('Already connected to WebSocket server');
      return true;
    }
    
    _address = address;
    _port = port;
    _username = username;
    _password = password;
    
    // Format the WebSocket URI
    final uri = 'ws://$address:$port';
    
    try {
      print('Connecting to WebSocket: $uri');
      _channel = IOWebSocketChannel.connect(uri);
      
      // Listen for messages
      _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      
      _isConnected = true;
      _shouldReconnect = true;
      _reconnectAttempts = 0;
      
      // Start heartbeat
      _startHeartbeat();
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      _isConnected = false;
      // Schedule reconnect attempt
      _scheduleReconnect();
      
      notifyListeners();
      return false;
    }
  }
  
  // Handle incoming WebSocket data
  void _onData(dynamic data) {
    _lastMessageTime = DateTime.now();
    
    // Raw message for log
    final rawMessage = data.toString();
    _messageLog.add('➤ $rawMessage');
    
    // Limit log size to prevent memory issues
    if (_messageLog.length > 100) {
      _messageLog.removeRange(0, 20);
    }
    
    try {
      // Parse the message as JSON
      final Map<String, dynamic> message = jsonDecode(rawMessage);
      
      // Add detailed logging for debugging
      print('WebSocket received message: ${message["c"]}');
      
      // Handle system info messages
      if (message['c'] == 'sysinfo') {
        _systemInfo = SystemInfo.fromJson(message);
      }
      
      // Handle login messages
      if (message['c'] == 'login' && message['msg'] == 'Oturum açılmamış!') {
        // Not logged in, send login credentials if we have them
        if (_username.isNotEmpty && _password.isNotEmpty) {
          print('Sending login credentials');
          sendMessage('LOGIN $_username $_password');
        } else {
          print('Login required but no credentials available');
        }
      }
      
      // If we're logged in and haven't sent the monitor command yet, do so
      if (message['c'] == 'login' && message['msg'] == 'success' && !_monitorCommandSent) {
        print('Login successful, sending monitor command');
        sendMessage('DO MONITORECS');
        _monitorCommandSent = true;
      }
      
      // Call the message handler if one is registered
      if (_onParsedMessage != null) {
        try {
          _onParsedMessage!(message);
        } catch (handlerError) {
          print('Error in message handler: $handlerError');
        }
      }
    } catch (e) {
      // Not a valid JSON message, just keep it in the log
      print('Error parsing WebSocket message: $e');
      print('Raw message: $rawMessage');
    }
    
    notifyListeners();
  }
    
  // Handle WebSocket errors
  void _onError(dynamic error) {
    print('WebSocket error: $error');
    _messageLog.add('✘ Error: $error');
    
    notifyListeners();
  }
  
  // Handle WebSocket connection closure
  void _onDone() {
    print('WebSocket connection closed');
    _messageLog.add('✘ Connection closed');
    _isConnected = false;
    
    // Schedule reconnect attempt if needed
    if (_shouldReconnect) {
      _scheduleReconnect();
    }
    
    // Stop heartbeat
    _stopHeartbeat();
    
    notifyListeners();
  }
  
  // Schedule a reconnect attempt
  void _scheduleReconnect() {
    if (_reconnectTimer != null) {
      _reconnectTimer!.cancel();
    }
    
    _reconnectAttempts++;
    if (_reconnectAttempts <= maxReconnectAttempts) {
      print('Scheduling reconnect attempt $_reconnectAttempts in $reconnectDelay seconds');
      _reconnectTimer = Timer(Duration(seconds: reconnectDelay), () {
        connect(_address, _port, _username, _password);
      });
    } else {
      print('Maximum reconnect attempts reached');
    }
  }
  
  // Start heartbeat timer
  void _startHeartbeat() {
    _stopHeartbeat();
    _lastMessageTime = DateTime.now();
    
    _heartbeatTimer = Timer.periodic(Duration(seconds: heartbeatInterval), (_) {
      _checkHeartbeat();
    });
  }
  
  // Stop heartbeat timer
  void _stopHeartbeat() {
    if (_heartbeatTimer != null) {
      _heartbeatTimer!.cancel();
      _heartbeatTimer = null;
    }
  }
  
  // Check for connection liveness
  void _checkHeartbeat() {
    if (!_isConnected || _lastMessageTime == null) {
      return;
    }
    
    final now = DateTime.now();
    final diff = now.difference(_lastMessageTime!).inSeconds;
    
    if (diff > heartbeatInterval * 2) {
      print('No heartbeat received for $diff seconds, reconnecting...');
      if (_channel != null) {
        _channel!.sink.close();
      }
      connect(_address, _port, _username, _password);
    }
  }
  
  // Disconnect from WebSocket server
  void disconnect() {
    _shouldReconnect = false;
    _stopHeartbeat();
    
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    
    _isConnected = false;
    notifyListeners();
  }
  
  // Send a message to the WebSocket server
  void sendMessage(String message) {
    if (!_isConnected || _channel == null) {
      print('Cannot send message: not connected');
      return;
    }
    
    try {
      _channel!.sink.add(message);
      _messageLog.add('← $message');
      
      // Limit log size
      if (_messageLog.length > 100) {
        _messageLog.removeRange(0, 20);
      }
      
      notifyListeners();
    } catch (e) {
      print('Error sending message: $e');
    }
  }
  
  // Clear WebSocket logs
  void clearLogs() {
    _messageLog = [];
    notifyListeners();
  }
}
