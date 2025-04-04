import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../models/system_info.dart';
import 'camera_devices_provider.dart';

class WebSocketProvider with ChangeNotifier {
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
        
        // Check if this is a camera device message
        if (dataPath.startsWith('ecs.slaves.m_')) {
          debugPrint('Received camera device update: $dataPath');
          _cameraDevicesProvider!.updateDeviceFromChangedMessage(message);
        }
      }
    }
  }
  
  // Connect to WebSocket server
  Future<void> connect(String host, int port) async {
    try {
      await _webSocketService.connect(host, port);
      notifyListeners();
    } catch (e) {
      debugPrint('Error connecting to WebSocket: $e');
      rethrow;
    }
  }
  
  // Disconnect from WebSocket server
  void disconnect() {
    _webSocketService.disconnect();
    notifyListeners();
  }
  
  // Send message to WebSocket server
  void sendMessage(String message) {
    _webSocketService.sendMessage(message);
  }
  
  // Method to specifically request system monitoring data
  void sendSystemMonitorRequest() {
    sendMessage("DO MONITORECS");
    debugPrint('Sent system monitor request');
  }
  
  // Login to the server
  void login(String username, String password) {
    sendMessage('LOGIN $username $password');
    debugPrint('Sent login request');
  }
}
