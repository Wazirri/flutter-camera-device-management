import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/camera_device.dart';
import 'websocket_provider.dart';

class CameraDevicesProvider with ChangeNotifier {
  final Map<String, CameraDevice> _devices = {};
  CameraDevice? _selectedDevice;
  int _selectedCameraIndex = 0;
  bool _isLoading = false;

  Map<String, CameraDevice> get devices => _devices;
  List<CameraDevice> get devicesList => _devices.values.toList();
  CameraDevice? get selectedDevice => _selectedDevice;
  int get selectedCameraIndex => _selectedCameraIndex;
  bool get isLoading => _isLoading;
  
  // Get all cameras from all devices as a flat list
  List<Camera> get cameras {
    List<Camera> camerasList = [];
    for (var device in _devices.values) {
      camerasList.addAll(device.cameras);
    }
    return camerasList;
  }
  
  // Get devices grouped by MAC address (for UI display and filtering)
  Map<String, List<Camera>> getCamerasByMacAddress() {
    Map<String, List<Camera>> result = {};
    
    for (var deviceEntry in _devices.entries) {
      String macAddress = deviceEntry.key;
      CameraDevice device = deviceEntry.value;
      result[macAddress] = device.cameras;
    }
    
    return result;
  }
  
  // Get devices grouped by MAC address as a map of key to device
  Map<String, CameraDevice> get devicesByMacAddress => _devices;
  
  // Get the selected camera from the selected device
  Camera? get selectedCamera {
    if (_selectedDevice == null || _selectedDevice!.cameras.isEmpty) {
      return null;
    }
    
    // Make sure the selected index is valid
    if (_selectedCameraIndex >= _selectedDevice!.cameras.length) {
      _selectedCameraIndex = 0;
    }
    
    return _selectedDevice!.cameras[_selectedCameraIndex];
  }

  void setSelectedDevice(String macKey) {
    if (_devices.containsKey(macKey)) {
      _selectedDevice = _devices[macKey];
      _selectedCameraIndex = 0; // Reset camera index when device changes
      notifyListeners();
    }
  }

  void setSelectedCameraIndex(int index) {
    if (_selectedDevice != null && index >= 0 && index < _selectedDevice!.cameras.length) {
      _selectedCameraIndex = index;
      notifyListeners();
    }
  }
  
  // Refresh cameras - simulates a refresh by triggering UI update
  void refreshCameras() {
    _isLoading = true;
    notifyListeners();
    
    // Simulate a delay for refresh
    Future.delayed(const Duration(seconds: 1), () {
      _isLoading = false;
      notifyListeners();
    });
  }

  // Method to handle update messages from WebSocketProvider
  void updateDeviceFromChangedMessage(Map<String, dynamic> message) {
    if (message['c'] == 'changed' && message.containsKey('data') && message.containsKey('val')) {
      final String dataPath = message['data'];
      final dynamic value = message['val'];
      
      // Debugging log the message
      debugPrint('Processing WebSocket message: ${json.encode(message)}');
      
      // Check if this is a camera device-related message
      if (dataPath.startsWith('ecs.slaves.m_')) {
        // Extract the MAC address from the data path
        // Format is like: ecs.slaves.m_26_C1_7A_0B_1F_19.property
        final parts = dataPath.split('.');
        if (parts.length >= 3) {
          _processDeviceMessage(parts, dataPath, value);
        }
      }
    }
  }

  // Helper method to process device messages
  void _processDeviceMessage(List<String> parts, String dataPath, dynamic value) {
    final macKey = parts[2]; // Get m_26_C1_7A_0B_1F_19
    
    // Format MAC address from macKey (m_26_C1_7A_0B_1F_19 -> 26:C1:7A:0B:1F:19)
    final String formattedMac = macKey.substring(2).replaceAll('_', ':');
    
    // Create device if it doesn't exist
    if (!_devices.containsKey(macKey)) {
      _devices[macKey] = CameraDevice(
        macAddress: formattedMac,
        macKey: macKey,
        ipv4: 'Unknown',
        lastSeenAt: DateTime.now().toIso8601String(),
        connected: false,
        uptime: '0',
        deviceType: 'Unknown',
        firmwareVersion: 'Unknown',
        recordPath: '',
        cameras: [],
      );
    }
    
    final device = _devices[macKey]!;
    
    // Update device properties based on the data path
    if (parts.length > 3) {
      final property = parts[3];
      
      switch (property) {
        case 'cam':
          _processCameraProperty(device, parts, dataPath, value);
          break;
        case 'brand':
          // Update device deviceType with brand
          final updatedDevice = device.copyWith(deviceType: value.toString());
          _devices[macKey] = updatedDevice;
          break;
        case 'model':
          // No direct match, could be used to enhance deviceType
          final updatedDevice = device.copyWith(deviceType: "${device.deviceType} ${value.toString()}");
          _devices[macKey] = updatedDevice;
          break;
        case 'ip':
          // Update device IP address
          final updatedDevice = device.copyWith(ipv4: value.toString());
          _devices[macKey] = updatedDevice;
          break;
        case 'version':
          // Update firmware version
          final updatedDevice = device.copyWith(firmwareVersion: value.toString());
          _devices[macKey] = updatedDevice;
          break;
        default:
          // Handle other device properties
          break;
      }
    }
    
    // Notify listeners of the change
    notifyListeners();
  }
  
  // Helper method to process camera-specific properties
  void _processCameraProperty(
    CameraDevice device, 
    List<String> parts, 
    String dataPath, 
    dynamic value
  ) {
    if (parts.length < 5) return;
    
    final camIndex = int.tryParse(parts[4]) ?? -1;
    if (camIndex < 0) return;
    
    // Create a camera list with enough capacity
    final cameras = List<Camera>.from(device.cameras);
    while (cameras.length <= camIndex) {
      cameras.add(Camera(
        index: cameras.length,
        name: 'Camera ${cameras.length}',
        ip: '',
        username: '',
        password: '',
        brand: '',
        mediaUri: '',
        recordUri: '',
        subUri: '',
        remoteUri: '',
        mainSnapShot: '',
        subSnapShot: '',
        recordWidth: 0,
        recordHeight: 0,
        subWidth: 0,
        subHeight: 0,
        connected: false,
        lastSeenAt: '',
        recording: false,
      ));
    }
    
    // Update the camera property
    if (parts.length > 5) {
      final camera = cameras[camIndex];
      final property = parts[5];
      
      Camera updatedCamera;
      
      switch (property) {
        case 'mediaUri':
          updatedCamera = camera.copyWith(mediaUri: value.toString());
          break;
        case 'mainSnapShot':
          updatedCamera = camera.copyWith(mainSnapShot: value.toString());
          break;
        case 'username':
          updatedCamera = camera.copyWith(username: value.toString());
          break;
        case 'password':
          updatedCamera = camera.copyWith(password: value.toString());
          break;
        case 'xAddrs':
          updatedCamera = camera.copyWith(xAddrs: value.toString());
          break;
        case 'name':
          updatedCamera = camera.copyWith(name: value.toString());
          break;
        default:
          updatedCamera = camera;
          break;
      }
      
      cameras[camIndex] = updatedCamera;
      
      // Update the device with the new camera list
      _devices[macKey] = device.copyWith(cameras: cameras);
    }
  }
}
