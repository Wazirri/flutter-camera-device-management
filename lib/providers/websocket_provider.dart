import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../models/system_info.dart';
import 'camera_devices_provider.dart';

class WebSocketProvider extends ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  CameraDevicesProvider? _cameraDevicesProvider;
  
  WebSocketService get websocketService => _webSocketService;
  bool get isConnected => _webSocketService.isConnected;
  List<String> get messageLog => _webSocketService.messageLog;
  SystemInfo? get systemInfo => _webSocketService.systemInfo;
  
  // Set the reference to the camera devices provider
  void setCameraDevicesProvider(CameraDevicesProvider provider) {
    _cameraDevicesProvider = provider;
    
    // Set up message handler
    _webSocketService.setMessageHandler(_handleParsedMessage);
  }
  
  // Message handler to forward messages to camera devices provider
  void _handleParsedMessage(Map<String, dynamic> message) {
    if (_cameraDevicesProvider != null) {
      // Add more detailed debug info for changed messages
      if (message['c'] == 'changed' && message.containsKey('data') && message.containsKey('val')) {
        final String dataPath = message['data'].toString();
        if (dataPath.startsWith('ecs.slaves.m_')) {
          debugPrint('✅ Forwarding device message to CameraDevicesProvider: ${message['data']} = ${message['val']}');
          _cameraDevicesProvider!.processWebSocketMessage(message);
        }
      } 
      // Process all other messages as well
      else {
        _cameraDevicesProvider!.processWebSocketMessage(message);
      }
    } else {
      debugPrint('❌ ERROR: CameraDevicesProvider is null, cannot process message: ${json.encode(message)}');
    }
  }
  
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
