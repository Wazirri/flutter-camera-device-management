import 'package:flutter/material.dart';
import '../services/websocket_service.dart';

class WebSocketProvider with ChangeNotifier {
  final WebSocketService _service = WebSocketService();
  
  // Constructor
  WebSocketProvider() {
    // Set up the message handler
    _service.setMessageHandler(_handleMessage);
  }
  
  // Expose the service for direct access
  WebSocketService get service => _service;
  
  // Connection status
  bool get isConnected => _service.isConnected;
  List<String> get messageLog => _service.messageLog;
  
  // Connect to server
  Future<bool> connect(String address, String port, String username, String password) async {
    return await _service.connect(address, port, username, password);
  }
  
  // Disconnect from server
  void disconnect() {
    _service.disconnect();
  }
  
  // Send message
  void sendMessage(String message) {
    _service.sendMessage(message);
  }
  
  // Clear message log
  void clearLog() {
    _service.clearLog();
  }
  
  // Message handler
  void _handleMessage(Map<String, dynamic> message) {
    // Forward to other providers if needed
  }
}
