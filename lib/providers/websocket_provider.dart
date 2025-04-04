import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../models/system_info.dart';
import 'camera_devices_provider.dart';

class WebSocketProvider with ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  CameraDevicesProvider? _cameraDevicesProvider;
  
  WebSocketProvider() {
    // Listen to WebSocketService changes and forward them to our listeners
    _webSocketService.addListener(_onServiceChanged);
  }
  
  // Handle changes from WebSocketService
  void _onServiceChanged() {
    // Forward the notification to our listeners
    notifyListeners();
  }
  
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
          // Enhanced debug output for camera-related messages
          print('✅ [WebSocket] Forwarding device message: ${message['data']} = ${message['val']}');
          
          // Add additional debug info
          if (dataPath.contains('cam')) {
            print('📷 [WebSocket] Camera message detected - Type: ${message['c']}, Path: ${message['data']}');
            // Check the message value
            if (message['val'] != null) {
              if (message['val'] is Map) {
                print('📦 [WebSocket] Value is a map with ${(message['val'] as Map).length} items');
              } else if (message['val'] is List) {
                print('📚 [WebSocket] Value is a list with ${(message['val'] as List).length} items');
              } else {
                print('📝 [WebSocket] Value type: ${message['val'].runtimeType}');
              }
            }
          }
          
          // Forward message to camera devices provider
          _cameraDevicesProvider!.processWebSocketMessage(message);
        }
      } 
      // Process all other messages as well
      else {
        // Debug other message types
        if (message['c'] != null) {
          print('🔄 [WebSocket] Message type: ${message['c']}');
        }
        _cameraDevicesProvider!.processWebSocketMessage(message);
      }
    } else {
      print('❌ [WebSocket] ERROR: CameraDevicesProvider is null, cannot process message: ${json.encode(message)}');
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
    // Remove listener from service
    _webSocketService.removeListener(_onServiceChanged);
    _webSocketService.dispose();
    super.dispose();
  }
}
