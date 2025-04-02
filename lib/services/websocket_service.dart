import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../models/system_info.dart';
import '../models/camera_device.dart';

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
  
  // Camera devices state
  final Map<String, DeviceInfo> _devices = {};
  final Map<String, Map<int, Map<String, dynamic>>> _cameraProperties = {};
  final Map<String, Map<String, Map<String, dynamic>>> _cameraReports = {};
  
  bool get isInitialized => _devices.isNotEmpty;
  bool get isConnected => _isConnected;
  List<String> get messageLog => _messageLog;
  SystemInfo? get systemInfo => _systemInfo;
  Map<String, DeviceInfo> get devices => _devices;
  List<DeviceInfo> get devicesList => _devices.values.toList();
  List<CameraDevice> get allCameras {
    final List<CameraDevice> cameras = [];
    for (final device in _devices.values) {
      cameras.addAll(device.cameras);
    }
    return cameras;
  }
  
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
  
  // Track if a monitor command has been sent
  bool _monitorCommandSent = false;
  
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
        
        // Check for login message
        if (jsonMessage is Map) {
          if (jsonMessage['c'] == 'login' && 
              (jsonMessage['msg'] == 'Oturum açılmamış!' || 
               jsonMessage['msg'].toString().contains('Oturum açılmamış'))) {
            
            // If we receive this specific login message, send login credentials
            sendLoginMessage(_username, _password);
            // Reset monitor command flag on new login
            _monitorCommandSent = false;
          }
          
          // Check for system info message
          else if (jsonMessage['c'] == 'sysinfo') {
            // Parse system info
            _systemInfo = SystemInfo.fromJson(jsonMessage);
            debugPrint('System info updated: ${jsonMessage['cpuTemp']}°C');
            
            // Send the monitor command only once after login
            if (!_monitorCommandSent) {
              sendMonitorCommand();
              _monitorCommandSent = true;
            }
            
            notifyListeners();
          }
          
          // Handle camera data changes
          else if (jsonMessage['c'] == 'changed' && 
                  jsonMessage.containsKey('data') && 
                  jsonMessage.containsKey('val')) {
            
            final String dataPath = jsonMessage['data'];
            final dynamic value = jsonMessage['val'];
            
            // Only process device related messages that we're interested in
            if (dataPath.startsWith('ecs.slaves.')) {
              _processDeviceData(dataPath, value);
            }
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
  
  // Process device data received from WebSocket
  void _processDeviceData(String dataPath, dynamic value) {
    // Extract MAC address from path (format: ecs.slaves.m_XX_XX_XX_XX_XX_XX.property)
    final parts = dataPath.split('.');
    if (parts.length < 3) return;
    
    final String macPart = parts[2]; // e.g., m_26_C1_7A_0B_1F_19
    final String macAddress = macPart.replaceAll('m_', '').replaceAll('_', ':');
    
    // Initialize device if it doesn't exist
    if (!_devices.containsKey(macAddress)) {
      _devices[macAddress] = DeviceInfo.initial(macAddress);
      _cameraProperties[macAddress] = {};
      _cameraReports[macAddress] = {};
    }
    
    // Process based on the property path
    if (parts.length >= 4) {
      final String propertyType = parts[3];
      
      if (propertyType == 'firsttime') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(firstSeen: value.toString());
      } else if (propertyType == 'connected') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(isConnected: value == 1);
      } else if (propertyType == 'ipv4') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(ipv4: value.toString());
      } else if (propertyType == 'ipv6') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(ipv6: value.toString());
      } else if (propertyType == 'last_seen_at') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(lastSeen: value.toString());
      } else if (propertyType == 'test' && parts.length >= 5 && parts[4] == 'uptime') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(uptime: value.toString());
      } else if (propertyType == 'test' && parts.length >= 5 && parts[4] == 'is_error') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(hasError: value == 1);
      } else if (propertyType == 'app' && parts.length >= 5 && parts[4] == 'firmware_version') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(firmwareVersion: value.toString());
      } else if (propertyType == 'app' && parts.length >= 5 && parts[4] == 'deviceType') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(deviceType: value.toString());
      } 
      // Process camera properties
      else if (propertyType.startsWith('cam[') && parts.length >= 5) {
        final camIndex = _extractCameraIndex(propertyType); // Get index from cam[0]
        final property = parts[4]; // e.g., name, cameraIp
        
        if (camIndex != null) {
          if (!_cameraProperties[macAddress]!.containsKey(camIndex)) {
            _cameraProperties[macAddress]![camIndex] = {};
          }
          
          // Store the camera property
          _cameraProperties[macAddress]![camIndex][property] = value;
          
          // Update the cameras list in the device
          _updateDeviceCameras(macAddress);
        }
      }
      // Process camera reports
      else if (propertyType == 'camreports' && parts.length >= 6) {
        final camName = parts[4]; // e.g., KAMERA1
        final property = parts[5]; // e.g., connected, recording
        
        if (!_cameraReports[macAddress]!.containsKey(camName)) {
          _cameraReports[macAddress]![camName] = {};
        }
        
        // Store the camera report
        _cameraReports[macAddress]![camName][property] = value;
        
        // Update the cameras list in the device
        _updateDeviceCameras(macAddress);
      }
    }
    
    notifyListeners();
  }
  
  // Extract camera index from cam[X] format
  int? _extractCameraIndex(String camPath) {
    final regex = RegExp(r'cam\[(\d+)\]');
    final match = regex.firstMatch(camPath);
    if (match != null && match.groupCount >= 1) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }
  
  // Update the device's cameras list from the stored properties
  void _updateDeviceCameras(String macAddress) {
    final List<CameraDevice> cameras = [];
    
    // Create camera devices from camera properties
    for (final entry in _cameraProperties[macAddress]!.entries) {
      final int camIndex = entry.key;
      final Map<String, dynamic> props = entry.value;
      
      if (props.containsKey('name')) {
        final camName = props['name'];
        
        // Create camera device from its properties
        final CameraDevice camera = CameraDevice.fromJson(props, macAddress);
        
        // Update camera with reports data if available
        if (_cameraReports[macAddress]!.containsKey(camName)) {
          final Map<String, dynamic> reports = _cameraReports[macAddress]![camName]!;
          
          // Update connected and recording status
          final isConnected = reports['connected'] == 1;
          bool isRecording = false;
          if (reports['recording'] is bool) {
            isRecording = reports['recording'];
          } else if (reports['recording'] is int) {
            isRecording = reports['recording'] == 1;
          } else if (reports['recording'] is String) {
            isRecording = reports['recording'].toLowerCase() == 'true';
          }
          
          final lastSeenAt = reports['last_seen_at']?.toString() ?? '';
          
          cameras.add(camera.copyWith(
            isConnected: isConnected,
            isRecording: isRecording,
            lastSeenAt: lastSeenAt,
          ));
        } else {
          cameras.add(camera);
        }
      }
    }
    
    // Update the device with the updated cameras list
    _devices[macAddress] = _devices[macAddress]!.copyWith(cameras: cameras);
  }
  
  // Get a specific camera by MAC address and camera name
  CameraDevice? getCamera(String macAddress, String cameraName) {
    if (!_devices.containsKey(macAddress)) return null;
    
    final cameras = _devices[macAddress]!.cameras;
    for (final camera in cameras) {
      if (camera.name == cameraName) {
        return camera;
      }
    }
    return null;
  }
  
  // Get online cameras only
  List<CameraDevice> get onlineCameras {
    return allCameras.where((camera) => camera.isConnected).toList();
  }
  
  // Get recording cameras only
  List<CameraDevice> get recordingCameras {
    return allCameras.where((camera) => camera.isRecording).toList();
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
      // Reset the monitor command sent flag on reconnect
      _monitorCommandSent = false;
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
    _monitorCommandSent = false; // Reset flag on disconnect
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