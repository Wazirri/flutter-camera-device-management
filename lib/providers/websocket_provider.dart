import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../models/system_info.dart';
import 'camera_devices_provider.dart';

class WebSocketProvider with ChangeNotifier {
  final WebSocketService _service = WebSocketService();
  CameraDevicesProvider? _cameraDevicesProvider;
  SystemInfo? _systemInfo;
  
  // Constructor
  WebSocketProvider() {
    // Set up the message handler
    _service.setMessageHandler(_handleMessage);
  }
  
  // Expose the service for direct access
  WebSocketService get service => _service;
  
  // Expose system info for dashboard
  SystemInfo? get systemInfo => _systemInfo;
  
  // Connection status
  bool get isConnected => _service.isConnected;
  List<String> get messageLog => _service.messageLog;
  
  // Connect the camera devices provider
  void setCameraDevicesProvider(CameraDevicesProvider provider) {
    _cameraDevicesProvider = provider;
  }
  
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
    // Process system info updates
    if (message.containsKey('c') && message['c'] == 'sysinfo') {
      _systemInfo = SystemInfo.fromJson(message);
      notifyListeners();
    }
    
    // Forward to camera devices provider if available
    if (_cameraDevicesProvider != null && 
        message.containsKey('c') && message['c'] == 'changed') {
      _cameraDevicesProvider!.processMessage(message);
    }
  }
}
