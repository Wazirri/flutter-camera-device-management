import 'package:flutter/material.dart';
import '../services/websocket_service.dart';

class WebSocketProvider extends ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  
  bool get isConnected => _webSocketService.isConnected;
  List<String> get messageLog => _webSocketService.messageLog;
  
  // Connect to WebSocket server
  Future<bool> connect(String address, String port, String username, String password) async {
    return await _webSocketService.connect(address, port, username, password);
  }
  
  // Send a message
  void sendMessage(String message) {
    _webSocketService.sendMessage(message);
  }
  
  // Disconnect WebSocket
  void disconnect() {
    _webSocketService.disconnect();
  }
  
  // Clear message log
  void clearLog() {
    _webSocketService.clearLog();
  }
  
  @override
  void dispose() {
    _webSocketService.dispose();
    super.dispose();
  }
}