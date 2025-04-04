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
  
  // Get unique device IDs (typically MAC addresses)
  List<String> get uniqueDevices => _devices.keys.toList();
  
  // Get the count of unique devices
  int get uniqueDeviceCount => _devices.length;
  
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
    if (_selectedCameraIndex >= 0 && _selectedCameraIndex < _selectedDevice!.cameras.length) {
      return _selectedDevice!.cameras[_selectedCameraIndex];
    }
    
    return null;
  }
  
  // Set loading state
  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  // Select a device by its key (typically MAC address)
  void selectDevice(String deviceKey) {
    if (_devices.containsKey(deviceKey)) {
      _selectedDevice = _devices[deviceKey];
      _selectedCameraIndex = 0; // Reset to first camera
      notifyListeners();
    }
  }
  
  // Select a camera on the current device
  void selectCamera(int index) {
    if (_selectedDevice != null && 
        index >= 0 && 
        index < _selectedDevice!.cameras.length) {
      _selectedCameraIndex = index;
      notifyListeners();
    }
  }
  
  // Process a WebSocket message and update our devices
  void processWebSocketMessage(Map<String, dynamic> message) {
    if (message['c'] == 'changed' && 
        message.containsKey('data') && 
        message.containsKey('val')) {
      
      String dataPath = message['data'].toString();
      
      // Check if this is a device message (starts with ecs.slaves.m_)
      if (dataPath.startsWith('ecs.slaves.m_')) {
        // Extract device ID (MAC address)
        // Path format: ecs.slaves.m_XX_XX_XX_XX_XX_XX or ecs.slaves.m_XX_XX_XX_XX_XX_XXcam
        String deviceIdWithPath = dataPath.split('.')[2]; // Get the m_XX... part
        
        // If it contains 'cam', it's a camera property update
        bool isCameraProperty = deviceIdWithPath.contains('cam');
        
        // Extract the device ID part (with or without cam) from path
        String deviceKey = deviceIdWithPath;
        
        // Create device if it doesn't exist yet
        if (!_devices.containsKey(deviceKey) && !isCameraProperty) {
          final newDevice = CameraDevice(id: deviceKey, brand: 'Unknown', model: 'Unknown');
          _devices[deviceKey] = newDevice;
        }
        
        // Update device properties
        if (_devices.containsKey(deviceKey)) {
          final device = _devices[deviceKey]!;
          
          // Handle device property update
          if (message['val'] is Map) {
            // Check for key-value map data
            Map<String, dynamic> properties = Map<String, dynamic>.from(message['val']);
            device.updateProperties(properties);
            
            // Extract camera information if available
            if (properties.containsKey('cameras') && properties['cameras'] is List) {
              List<dynamic> cameraData = properties['cameras'];
              for (var cam in cameraData) {
                if (cam is Map) {
                  device.updateCamera(cam);
                }
              }
            }
          }
          
          // Handle direct path updates (with value as String or other primitive)
          else {
            // Extract property name from path (everything after the last dot)
            List<String> pathParts = dataPath.split('.');
            if (pathParts.length > 3) {
              String propertyName = pathParts.sublist(3).join('.');
              var propertyValue = message['val'];
              
              // Update the property on the device
              device.setRawProperty(propertyName, propertyValue);
            }
          }
          
          // If this is our first device, make it the selected one
          if (_selectedDevice == null) {
            _selectedDevice = device;
          }
          
          notifyListeners();
        }
      }
    }
  }
  
  // Debug function to dump all devices and their properties
  void debugPrintDevices() {
    print('=== Device Debug Info ===');
    print('Total devices: ${_devices.length}');
    
    for (var entry in _devices.entries) {
      print('Device ID: ${entry.key}');
      print('  Brand: ${entry.value.brand}');
      print('  Model: ${entry.value.model}');
      print('  Active: ${entry.value.active}');
      print('  IP: ${entry.value.ip}');
      print('  Cameras: ${entry.value.cameras.length}');
      
      // Print camera details
      for (int i = 0; i < entry.value.cameras.length; i++) {
        final cam = entry.value.cameras[i];
        print('    Camera $i: ${cam.name ?? 'Unnamed'}');
        print('      Media URI: ${cam.mediaUri}');
        print('      Record URI: ${cam.recordUri}');
      }
      
      print('-----------------------');
    }
  }
  
  // Clear all devices
  void clearDevices() {
    _devices.clear();
    _selectedDevice = null;
    _selectedCameraIndex = 0;
    notifyListeners();
  }
}
