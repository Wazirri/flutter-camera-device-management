import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/camera_device.dart';
import 'websocket_provider.dart';

class CameraDevicesProvider with ChangeNotifier {
  final WebSocketProvider _webSocketProvider;
  Map<String, dynamic>? _lastMessage;
  List<Device> _devices = [];
  List<Camera> _cameras = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  
  // Group cameras by MAC address
  Map<String, List<Camera>> _cameraGroups = {};
  
  // Timer for periodic updates
  Timer? _updateTimer;
  
  // Constructor
  CameraDevicesProvider(this._webSocketProvider);
  
  // Getters
  List<Device> get devices => _devices;
  List<Camera> get cameras => _cameras;
  Map<String, List<Camera>> get cameraGroups => _cameraGroups;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  
  void initialize() {
    // Listen for changes in the WebSocket connection status
    _webSocketProvider.addListener(_handleWebSocketChanges);
    
    // Start a timer to periodically check for updates
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _processLatestMessage();
    });
  }
  
  // Handle changes in the WebSocket connection status
  void _handleWebSocketChanges() {
    if (_webSocketProvider.isConnected && _webSocketProvider.isAuthenticated) {
      _processLatestMessage();
    }
  }
  
  // Process the latest message from the WebSocket provider
  void _processLatestMessage() {
    final latestMessage = _webSocketProvider.lastMessage;
    
    // If there's no new message or not connected, return
    if (latestMessage == null || !_webSocketProvider.isConnected) {
      return;
    }
    
    // If it's the same message we already processed, return
    if (_lastMessage != null && 
        _lastMessage!['timestamp'] == latestMessage['timestamp']) {
      return;
    }
    
    // Update last message reference
    _lastMessage = latestMessage;
    
    // Process the message based on its type
    if (latestMessage['c'] == 'changed') {
      _processChangedMessage(latestMessage);
    }
  }
  
  // Process 'changed' messages which contain device and camera data
  void _processChangedMessage(Map<String, dynamic> message) {
    final String data = message['data'];
    final dynamic value = message['val'];
    
    // Check if this is a camera-related message
    if (data.startsWith('ecs.slaves.m_') && data.contains('.cam.')) {
      _processCameraData(data, value);
    }
  }
  
  // Process camera data from a 'changed' message
  void _processCameraData(String data, dynamic value) {
    // Extract device mac address, camera index, and property name from the data string
    // Format is typically: ecs.slaves.m_XX_XX_XX_XX_XX_XX.cam.0.property
    final regex = RegExp(r'ecs\.slaves\.m_([^\.]+)\.cam\.(\d+)\.(.+)');
    final match = regex.firstMatch(data);
    
    if (match != null && match.groupCount >= 3) {
      final String macAddress = match.group(1)!;
      final int cameraIndex = int.parse(match.group(2)!);
      final String propertyName = match.group(3)!;
      
      // Update or create the device
      _updateOrCreateDevice(macAddress);
      
      // Update or create the camera
      _updateOrCreateCamera(macAddress, cameraIndex, propertyName, value);
      
      // Update the camera groups
      _updateCameraGroups();
      
      // Notify listeners of the changes
      notifyListeners();
      
      _isInitialized = true;
    }
  }
  
  // Update or create a device with the given MAC address
  void _updateOrCreateDevice(String macAddress) {
    // Format MAC address for display (add colons)
    final formattedMac = _formatMacAddress(macAddress);
    
    // Check if device already exists
    final existingDeviceIndex = _devices.indexWhere((d) => d.macAddress == formattedMac);
    
    if (existingDeviceIndex == -1) {
      // Create new device
      final newDevice = Device(
        id: _devices.length,
        macAddress: formattedMac,
        name: 'Device $formattedMac',
        ip: '',
        connected: true,
      );
      
      _devices.add(newDevice);
    }
  }
  
  // Update or create a camera with the given properties
  void _updateOrCreateCamera(
    String macAddress, 
    int cameraIndex, 
    String propertyName, 
    dynamic value
  ) {
    // Format MAC address for display
    final formattedMac = _formatMacAddress(macAddress);
    
    // Generate a unique camera ID based on MAC and index
    final uniqueId = '$formattedMac-$cameraIndex';
    
    // Find existing camera or create a new one
    Camera? existingCamera = _findCamera(uniqueId);
    
    if (existingCamera == null) {
      // Create new camera and add to list
      existingCamera = Camera(
        id: uniqueId,
        index: _cameras.length, // Use length as index for new camera
        macAddress: formattedMac,
        name: 'Camera $cameraIndex ($formattedMac)',
        localIndex: cameraIndex,
      );
      
      _cameras.add(existingCamera);
    }
    
    // Update the appropriate property
    _updateCameraProperty(existingCamera, propertyName, value);
  }
  
  // Find a camera by its unique ID
  Camera? _findCamera(String uniqueId) {
    try {
      return _cameras.firstWhere((camera) => camera.id == uniqueId);
    } catch (e) {
      return null;
    }
  }
  
  // Update a specific property of a camera
  void _updateCameraProperty(Camera camera, String propertyName, dynamic value) {
    switch (propertyName) {
      case 'name':
        camera.name = value.toString();
        break;
      case 'ip':
        camera.ip = value.toString();
        break;
      case 'connected':
        camera.connected = value.toString() == '1';
        break;
      case 'subUri': // This is the RTSP stream URI
        camera.rtspUri = value.toString();
        break;
      case 'mediaUri': // Alternative stream URI
        camera.mediaUri = value.toString();
        break;
      case 'snapshot': // Camera snapshot image
        camera.mainSnapShot = value.toString();
        break;
      case 'username':
        camera.username = value.toString();
        break;
      case 'password':
        camera.password = value.toString();
        break;
      // Add more properties as needed
    }
  }
  
  // Update camera groups based on MAC address
  void _updateCameraGroups() {
    _cameraGroups.clear();
    
    for (final camera in _cameras) {
      if (!_cameraGroups.containsKey(camera.macAddress)) {
        _cameraGroups[camera.macAddress] = [];
      }
      
      // Check if this camera is already in the group
      final existingIndex = _cameraGroups[camera.macAddress]!
          .indexWhere((c) => c.id == camera.id);
      
      if (existingIndex == -1) {
        _cameraGroups[camera.macAddress]!.add(camera);
      } else {
        _cameraGroups[camera.macAddress]![existingIndex] = camera;
      }
    }
  }
  
  // Format MAC address with colons
  String _formatMacAddress(String macAddress) {
    // Convert from XX_XX_XX_XX_XX_XX to XX:XX:XX:XX:XX:XX
    return macAddress.replaceAll('_', ':');
  }
  
  // Refresh camera data
  void refreshData() {
    if (_webSocketProvider.isConnected && _webSocketProvider.isAuthenticated) {
      _webSocketProvider.sendMessage('DO MONITORECS');
    }
  }
  
  @override
  void dispose() {
    _webSocketProvider.removeListener(_handleWebSocketChanges);
    _updateTimer?.cancel();
    super.dispose();
  }
}