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
    print('CameraDevicesProvider set in WebSocketProvider');
    
    // Set up message handler
    _webSocketService.setMessageHandler(_handleParsedMessage);
    print('Message handler set up in WebSocketService');
  }
  
  // Message handler to forward messages to camera devices provider
  void _handleParsedMessage(Map<String, dynamic> message) {
    try {
      print('WebSocketProvider._handleParsedMessage received message type: ${message["c"]}');
      
      if (_cameraDevicesProvider != null) {
        print('CameraDevicesProvider is available for updates');
        
        // Add more detailed debug info for changed messages
        if (message['c'] == 'changed' && message.containsKey('data') && message.containsKey('val')) {
          final String dataPath = message['data'].toString();
          final dynamic value = message['val'];
          
          print('Processing "changed" message. Data path: $dataPath, Value: $value');
          
          // Check if this is a camera device message
          if (dataPath.startsWith('ecs.slaves.m_')) {
            print('Forwarding camera device update: $dataPath');
            _cameraDevicesProvider!.updateDeviceFromChangedMessage(message);
          } else {
            print('Not a camera device message, skipping: $dataPath');
          }
        } else if (message['c'] == 'changed') {
          print('Incomplete changed message: missing data or val fields');
          print('Message content: ${json.encode(message)}');
        }
      } else {
        print('CameraDevicesProvider is NOT available - no updates forwarded');
      }
    } catch (e) {
      print('Error in WebSocketProvider._handleParsedMessage: $e');
      print('Message that caused error: ${json.encode(message)}');
    }
  }
  
  // Connect to WebSocket server
  Future<bool> connect(String address, int port, {String username = '', String password = ''}) async {
    try {
      print('WebSocketProvider attempting connection to $address:$port');
      // Connect to WebSocket server
      final connected = await _webSocketService.connect(address, port.toString(), username, password);
      
      if (connected) {
        print('WebSocketProvider successfully connected');
      } else {
        print('WebSocketProvider connection failed');
      }
      
      notifyListeners();
      return connected;
    } catch (e) {
      debugPrint('Error connecting to WebSocket: $e');
      return false;
    }
  }
  
  // Disconnect from WebSocket server
  void disconnect() {
    print('WebSocketProvider disconnecting');
    _webSocketService.disconnect();
    notifyListeners();
  }
  
  // Send message to WebSocket server
  void sendMessage(String message) {
    print('WebSocketProvider sending message: $message');
    _webSocketService.sendMessage(message);
  }
  
  // Method to specifically request system monitoring data
  void sendSystemMonitorRequest() {
    print('WebSocketProvider sending system monitor request');
    sendMessage("DO MONITORECS");
    debugPrint('Sent system monitor request');
  }
  
  // Login to the server
  void login(String username, String password) {
    print('WebSocketProvider sending login request for user: $username');
    sendMessage('LOGIN $username $password');
    debugPrint('Sent login request');
  }
  
  // Method to clear WebSocket logs
  void clearLogs() {
    print('WebSocketProvider clearing logs');
    _webSocketService.clearLogs();
    notifyListeners();
  }
}
