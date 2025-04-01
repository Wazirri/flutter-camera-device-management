import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  String _serverAddress = '';
  String _serverPort = '';
  String _username = '';
  String _password = '';
  List<String> _messageLog = [];

  bool get isConnected => _isConnected;
  List<String> get messageLog => _messageLog;
  
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
    }
  }
  
  // Handle received message
  void _onMessage(dynamic message) {
    try {
      // Log the raw message first
      final timestamp = DateTime.now().toString();
      final rawLogMessage = '[$timestamp] Received: $message';
      _messageLog.add(rawLogMessage);
      debugPrint(rawLogMessage);
      
      // Try to parse as JSON if possible
      try {
        final jsonMessage = jsonDecode(message.toString());
        final jsonLogMessage = '[$timestamp] Parsed JSON: ${jsonEncode(jsonMessage)}';
        _messageLog.add(jsonLogMessage);
        debugPrint(jsonLogMessage);
      } catch (e) {
        // Not valid JSON, that's okay, we already logged the raw message
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling message: $e');
    }
  }
  
  // Handle WebSocket errors
  void _onError(dynamic error) {
    debugPrint('WebSocket error: $error');
    _messageLog.add('[${DateTime.now()}] Error: $error');
    notifyListeners();
  }
  
  // Handle WebSocket closure
  void _onDone() {
    debugPrint('WebSocket connection closed');
    _messageLog.add('[${DateTime.now()}] Connection closed');
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