import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../models/system_info.dart';

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  String _serverAddress = '';
  String _serverPort = '';
  String _username = '';
  String _password = '';
  List<String> _messageLog = [];
  SystemInfo? _systemInfo;
  static const int maxLogMessages = 2000; // Maximum number of log messages to keep

  bool get isConnected => _isConnected;
  List<String> get messageLog => _messageLog;
  SystemInfo? get systemInfo => _systemInfo;
  
  // Add message to log with size limit enforcement
  void _addToLog(String message) {
    _messageLog.add(message);
    
    // If we exceed the maximum number of messages, remove oldest ones
    if (_messageLog.length > maxLogMessages) {
      _messageLog = _messageLog.sublist(_messageLog.length - maxLogMessages);
    }
    
    notifyListeners();
  }
  
  // Connect to WebSocket server
  Future<bool> connect(String address, String port, String username, String password) async {
    _serverAddress = address;
    _serverPort = port;
    _username = username;
    _password = password;
    
    try {
      final uri = Uri.parse('ws://$address:$port');
      _channel = IOWebSocketChannel.connect(uri);
      
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );
      
      // Send the login message
      sendLoginMessage(username, password);
      
      _isConnected = true;
      notifyListeners();
      debugPrint('WebSocket connected to $uri');
      return true;
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _isConnected = false;
      notifyListeners();
      return false;
    }
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
      // Log the raw message first
      final timestamp = DateTime.now().toString();
      final rawLogMessage = '[$timestamp] Received: $message';
      _addToLog(rawLogMessage);
      debugPrint(rawLogMessage);
      
      // Try to parse as JSON if possible
      try {
        final jsonMessage = jsonDecode(message.toString());
        final jsonLogMessage = '[$timestamp] Parsed JSON: ${jsonEncode(jsonMessage)}';
        _addToLog(jsonLogMessage);
        debugPrint(jsonLogMessage);
        
        // Check for login message
        if (jsonMessage is Map) {
          if (jsonMessage['c'] == 'login' && 
              jsonMessage['msg'] == 'Oturum açılmamış! ') {
            
            // If we receive this specific login message, send login credentials
            sendLoginMessage(_username, _password);
          }
          
          // Check for system info message
          else if (jsonMessage['c'] == 'sysinfo') {
            // Parse system info
            _systemInfo = SystemInfo.fromJson(jsonMessage);
            debugPrint('System info updated: ${jsonMessage['cpuTemp']}°C');
            notifyListeners(); // Ensure UI updates with new system info
            
            // Send the monitor command after receiving system info
            sendMonitorCommand();
          }
        }
        
      } catch (e) {
        // Not valid JSON, that's okay, we already logged the raw message
        debugPrint('Error parsing JSON: $e');
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
    }
  }
  
  // Send the "DO MONITOR ecs" command
  void sendMonitorCommand() {
    if (_channel != null && _isConnected) {
      final monitorCommand = 'DO MONITOR ecs';
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
  }
  
  // Handle WebSocket closure
  void _onDone() {
    debugPrint('WebSocket connection closed');
    _addToLog('[${DateTime.now()}] Connection closed');
    _isConnected = false;
    notifyListeners();
    
    // Attempt reconnection after a delay
    Future.delayed(const Duration(seconds: 5), _reconnect);
  }
  
  // Attempt to reconnect
  Future<void> _reconnect() async {
    if (!_isConnected && _serverAddress.isNotEmpty && _serverPort.isNotEmpty) {
      debugPrint('Attempting to reconnect to WebSocket...');
      await connect(_serverAddress, _serverPort, _username, _password);
    }
  }
  
  // Send a message through the WebSocket
  void sendMessage(String message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(message);
      final timestamp = DateTime.now().toString();
      _addToLog('[$timestamp] Sent: $message');
      debugPrint('Sent message: $message');
    } else {
      debugPrint('Cannot send message, WebSocket not connected');
      // Try to reconnect
      _reconnect();
    }
  }
  
  // Disconnect WebSocket
  void disconnect() {
    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }
    
    if (_channel != null) {
      _channel!.sink.close(status.goingAway);
      _channel = null;
    }
    
    _isConnected = false;
    notifyListeners();
    debugPrint('WebSocket disconnected');
  }
  
  // Clean up resources
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
  
  // Clear message log
  void clearLog() {
    _messageLog.clear();
    notifyListeners();
  }
}