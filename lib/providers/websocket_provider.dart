import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../models/system_info.dart';
import 'camera_devices_provider.dart';

class WebSocketProvider with ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  String _serverIp = "85.104.114.145";
  int _serverPort = 1200;
  CameraDevicesProvider? _cameraDevicesProvider;
  
  WebSocketProvider() {
    // WebSocketService'den SystemInfo değişiklik bildirimini dinle
    _webSocketService.addListener(_onWebSocketServiceUpdated);
  }
  
  // WebSocketService değiştiğinde çağrılacak
  void _onWebSocketServiceUpdated() {
    // Provider'ı güncelle ve Widget'ları yeniden oluştur
    notifyListeners();
  }
  
  WebSocketService get websocketService => _webSocketService;
  bool get isConnected => _webSocketService.isConnected;
  String get serverIp => _serverIp;
  int get serverPort => _serverPort;
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
          print('✅ Forwarding device message to CameraDevicesProvider: ${message['data']} = ${message['val']}');
          _cameraDevicesProvider!.processWebSocketMessage(message);
        }
      } 
      // Process all other messages as well
      else {
        _cameraDevicesProvider!.processWebSocketMessage(message);
      }
    } else {
      print('❌ ERROR: CameraDevicesProvider is null, cannot process message: ${json.encode(message)}');
    }
  }
  
  // Connect to WebSocket server
  Future<bool> connect(String address, int port, [String username = "admin", String password = "admin"]) async {
    _serverIp = address;
    _serverPort = port;
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
    // Listener'ı kaldır
    _webSocketService.removeListener(_onWebSocketServiceUpdated);
    _webSocketService.dispose();
    super.dispose();
  }
}
