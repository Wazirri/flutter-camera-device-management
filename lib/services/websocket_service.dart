import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/system_info.dart';
import '../utils/file_logger.dart';

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
    // Initialize file logger
    await FileLogger.init();
    await FileLogger.log('Starting connection to WebSocket server', tag: 'CONNECTION');
    
    if (_isConnected) {
      print('Already connected to WebSocket server');
      await FileLogger.log('Already connected to WebSocket server', tag: 'CONNECTION');
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
      await FileLogger.log('Connecting to WebSocket server: ${uri.toString()}', tag: 'CONNECTION');
      
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
      
      print('Connected to WebSocket server: ${uri.toString()}');
      await FileLogger.log('Successfully connected to WebSocket server: ${uri.toString()}', tag: 'CONNECTION');
      return true;
    } catch (e) {
      print('WebSocket connection failed: $e');
      await FileLogger.log('WebSocket connection failed: $e', tag: 'ERROR');
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
        print('No messages received in ${lastMessageDuration.inSeconds} seconds. Resetting connection.');
        _resetConnection();
        return;
      }
      
      // Send a heartbeat message if connected
      if (_channel != null && _isConnected) {
        _channel!.sink.add('PING');
        print('Heartbeat sent: PING');
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
      print('Sent login message: $loginMessage');
      
      // Add to message log
      final timestamp = DateTime.now().toString();
      _addToLog('[$timestamp] Sent: $loginMessage');
    }
  }
  
  // Handle received message
  void _onMessage(dynamic message) {
    // print('WebSocket message received: $message');
    try {
      final Map<String, dynamic> data = json.decode(message);
      _processMessage(data);
    } catch (e) {
      print('Error processing WebSocket message: $e');
    }
  }
  
  void _processMessage(Map<String, dynamic> data) async {
    try {
      // Update last message time
      _lastMessageTime = DateTime.now();
      
      // Log the raw message first
      final timestamp = DateTime.now().toString();
      final rawLogMessage = '[$timestamp] Received: ${jsonEncode(data)}';
      _addToLog(rawLogMessage);
      
      // Log raw message to file
      await FileLogger.log('Received raw message: ${jsonEncode(data)}', tag: 'WS_RAW');
      
      // Reset reconnect attempts as we're receiving messages
      _reconnectAttempts = 0;
      
      // Process the already decoded JSON data
      final jsonMessage = data;
      final jsonLogMessage = '[$timestamp] Processed JSON: ${jsonEncode(jsonMessage)}';
      _addToLog(jsonLogMessage);
      
      // Log the JSON data to file
      await FileLogger.logWebSocketMessage(jsonMessage, tag: 'WS_JSON');
      
      // Check for login message
      if (jsonMessage['c'] == 'login' && 
          (jsonMessage['msg'] == 'Oturum açılmamış!' || 
           jsonMessage['msg'].toString().contains('Oturum açılmamış'))) {
        
        // If we receive this specific login message, send login credentials
        await FileLogger.log('Received login required message. Sending credentials.', tag: 'LOGIN');
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
          await FileLogger.log('Sending monitor command after login', tag: 'MONITOR');
          sendMonitorCommand();
          _monitorCommandSent = true;
        }
        
        // Her sysinfo mesajında notifyListeners çağrılıyor
        // Bu sayede arayüzdeki sistem bilgileri gerçek zamanlı güncelleniyor
        print('✅ Sistem bilgileri güncellendi: CPU Sıcaklığı=${_systemInfo?.cpuTemp}°C, RAM Kullanımı=${_systemInfo?.ramUsagePercentage.toStringAsFixed(1)}%');
        await FileLogger.log('System info updated: CPU Temp=${_systemInfo?.cpuTemp}°C, RAM Usage=${_systemInfo?.ramUsagePercentage.toStringAsFixed(1)}%', tag: 'SYSINFO');
        notifyListeners();
      }
      
      // Pass the message to the handler if provided
      if (_onParsedMessage != null) {
        // For changed messages, add extra debug info
        if (jsonMessage['c'] == 'changed' && 
            jsonMessage.containsKey('data') && 
            jsonMessage.containsKey('val')) {
          
          final String dataPath = jsonMessage['data'].toString();
          final dynamic value = jsonMessage['val'];
          
          // Add detailed debug info for camera device messages
          if (dataPath.startsWith('ecs_slaves.m_')) {
            print('📦 Device message: ${jsonMessage['data']} = ${jsonMessage['val']}');
            await FileLogger.log('Device message data path: $dataPath', tag: 'DEVICE');
            await FileLogger.log('Device message value: $value (${value.runtimeType})', tag: 'DEVICE');
            await FileLogger.log('Full message for $dataPath:', tag: 'DEVICE');
            await FileLogger.logWebSocketMessage(jsonMessage, tag: 'DEVICE_DATA');
            _onParsedMessage!(jsonMessage);
          }
        } 
        // Handle login success
        else if (jsonMessage['c'] == 'loginok') {
          print('👤 Successfully logged in: ${jsonMessage['username']}');
          await FileLogger.log('Successfully logged in: ${jsonMessage['username']}', tag: 'LOGIN');
          _onParsedMessage!(jsonMessage);
        }
        // Handle any other message type
        else {
          await FileLogger.log('Other message type: ${jsonMessage['c']}', tag: 'OTHER');
          _onParsedMessage!(jsonMessage);
        }
      }
    } catch (e) {
      print('Error handling message: $e');
      await FileLogger.log('Error handling WebSocket message: $e', tag: 'ERROR');
    }
  }
  
  // Send the "DO MONITORECS" command
  void sendMonitorCommand() async {
    if (_channel != null && _isConnected) {
      final monitorCommand = 'Monitor ecs_slaves';
      _channel!.sink.add(monitorCommand);
      
      // Log the command
      final timestamp = DateTime.now().toString();
      final logMessage = '[$timestamp] Sent: $monitorCommand';
      _addToLog(logMessage);
      print(logMessage);
      await FileLogger.log('Sent monitor command: $monitorCommand', tag: 'COMMAND');
    }
  }
  
  // Handle WebSocket errors
  void _onError(dynamic error) {
    print('WebSocket error: $error');
    _addToLog('[${DateTime.now()}] Error: $error');
    _resetConnection();
  }
  
  // Handle WebSocket closure
  void _onDone() {
    print('WebSocket connection closed');
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
    
    print('Scheduling reconnect attempt ${_reconnectAttempts}/$maxReconnectAttempts in $reconnectDelay seconds...');
    
    _reconnectTimer = Timer(Duration(seconds: reconnectDelay), () {
      _reconnectTimer = null;
      if (_shouldReconnect && !_isConnected) {
        print('Attempting to reconnect...');
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
      
      print('Sent message: $message');
    } else {
      print('Cannot send message, not connected to WebSocket server');
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
    print('Disconnected from WebSocket server');
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
