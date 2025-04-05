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
  
  // Compatibility method for setSelectedDevice
  void setSelectedDevice(String deviceKey) {
    selectDevice(deviceKey);
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
  
  // Compatibility method for setSelectedCameraIndex
  void setSelectedCameraIndex(int index) {
    selectCamera(index);
  }
  
  // Refresh cameras (dummy method for compatibility)
  void refreshCameras() {
    // This method is kept for compatibility with existing code
    // In the current implementation, cameras are refreshed through WebSocket messages
    debugPrint('Requesting camera refresh (no-op in current implementation)');
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
        
        // Extract MAC address in standard format and as key for the device
        String macAddress = deviceKey.replaceAll('m_', '').replaceAll('_', ':');
        if (macAddress.contains('cam')) {
          macAddress = macAddress.split('cam')[0];
        }
        
        // Create device if it doesn't exist yet
        if (!_devices.containsKey(deviceKey) && !isCameraProperty) {
          final newDevice = CameraDevice(
            macAddress: macAddress,
            macKey: deviceKey,
            ipv4: '',
            lastSeenAt: DateTime.now().toIso8601String(),
            connected: true,
            uptime: '0',
            deviceType: 'Unknown',
            firmwareVersion: 'Unknown',
            recordPath: '',
            cameras: [],
          );
          _devices[deviceKey] = newDevice;
        }
        
        // Update device properties
        if (_devices.containsKey(deviceKey)) {
          final device = _devices[deviceKey]!;
          
          // Handle device property update
          if (message['val'] is Map) {
            // Check for key-value map data
            Map<String, dynamic> properties = Map<String, dynamic>.from(message['val']);
            _updateDeviceProperties(device, properties);
            
            // Extract camera information if available
            if (properties.containsKey('cameras') && properties['cameras'] is List) {
              List<dynamic> cameraData = properties['cameras'];
              for (var cam in cameraData) {
                if (cam is Map) {
                  _updateCameraData(device, cam);
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
              _setDeviceProperty(device, propertyName, propertyValue);
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
  
  // Helper method to update device properties
  void _updateDeviceProperties(CameraDevice device, Map<String, dynamic> properties) {
    // Create a copy of the device with updated properties
    CameraDevice updatedDevice = device.copyWith(
      ipv4: properties['ipv4'] ?? device.ipv4,
      lastSeenAt: properties['lastSeenAt'] ?? device.lastSeenAt,
      connected: properties['connected'] ?? device.connected,
      uptime: properties['uptime']?.toString() ?? device.uptime,
      deviceType: properties['deviceType'] ?? device.deviceType,
      firmwareVersion: properties['firmwareVersion'] ?? device.firmwareVersion,
      recordPath: properties['recordPath'] ?? device.recordPath,
    );
    
    // Update the device in our map
    _devices[device.macKey] = updatedDevice;
  }
  
  // Helper method to update camera data
  void _updateCameraData(CameraDevice device, Map<dynamic, dynamic> cameraData) {
    int cameraIndex = cameraData['index'] ?? 0;
    List<Camera> updatedCameras = List.from(device.cameras);
    
    // Check if this camera already exists
    int existingIndex = updatedCameras.indexWhere((cam) => cam.index == cameraIndex);
    
    if (existingIndex >= 0) {
      // Update existing camera
      Camera updatedCamera = updatedCameras[existingIndex].copyWith(
        name: cameraData['name'] ?? updatedCameras[existingIndex].name,
        ip: cameraData['ip'] ?? updatedCameras[existingIndex].ip,
        rawIp: cameraData['rawIp'] ?? updatedCameras[existingIndex].rawIp,
        username: cameraData['username'] ?? updatedCameras[existingIndex].username,
        password: cameraData['password'] ?? updatedCameras[existingIndex].password,
        brand: cameraData['brand'] ?? updatedCameras[existingIndex].brand,
        hw: cameraData['hw'] ?? updatedCameras[existingIndex].hw,
        manufacturer: cameraData['manufacturer'] ?? updatedCameras[existingIndex].manufacturer,
        country: cameraData['country'] ?? updatedCameras[existingIndex].country,
        xAddrs: cameraData['xAddrs'] ?? updatedCameras[existingIndex].xAddrs,
        mediaUri: cameraData['mediaUri'] ?? updatedCameras[existingIndex].mediaUri,
        recordUri: cameraData['recordUri'] ?? updatedCameras[existingIndex].recordUri,
        subUri: cameraData['subUri'] ?? updatedCameras[existingIndex].subUri,
        remoteUri: cameraData['remoteUri'] ?? updatedCameras[existingIndex].remoteUri,
        mainSnapShot: cameraData['mainSnapShot'] ?? updatedCameras[existingIndex].mainSnapShot,
        subSnapShot: cameraData['subSnapShot'] ?? updatedCameras[existingIndex].subSnapShot,
        recordPath: cameraData['recordPath'] ?? updatedCameras[existingIndex].recordPath,
        recordCodec: cameraData['recordCodec'] ?? updatedCameras[existingIndex].recordCodec,
        recordWidth: cameraData['recordWidth'] ?? updatedCameras[existingIndex].recordWidth,
        recordHeight: cameraData['recordHeight'] ?? updatedCameras[existingIndex].recordHeight,
        subCodec: cameraData['subCodec'] ?? updatedCameras[existingIndex].subCodec,
        subWidth: cameraData['subWidth'] ?? updatedCameras[existingIndex].subWidth,
        subHeight: cameraData['subHeight'] ?? updatedCameras[existingIndex].subHeight,
        connected: cameraData['connected'] ?? updatedCameras[existingIndex].connected,
        disconnected: cameraData['disconnected'] ?? updatedCameras[existingIndex].disconnected,
        lastSeenAt: cameraData['lastSeenAt'] ?? updatedCameras[existingIndex].lastSeenAt,
        recording: cameraData['recording'] ?? updatedCameras[existingIndex].recording,
      );
      updatedCameras[existingIndex] = updatedCamera;
    } else {
      // Add new camera
      Camera newCamera = Camera(
        index: cameraIndex,
        name: cameraData['name'] ?? 'Camera $cameraIndex',
        ip: cameraData['ip'] ?? '',
        rawIp: cameraData['rawIp'] ?? 0,
        username: cameraData['username'] ?? '',
        password: cameraData['password'] ?? '',
        brand: cameraData['brand'] ?? '',
        mediaUri: cameraData['mediaUri'] ?? '',
        recordUri: cameraData['recordUri'] ?? '',
        subUri: cameraData['subUri'] ?? '',
        remoteUri: cameraData['remoteUri'] ?? '',
        mainSnapShot: cameraData['mainSnapShot'] ?? '',
        subSnapShot: cameraData['subSnapShot'] ?? '',
        recordWidth: cameraData['recordWidth'] ?? 0,
        recordHeight: cameraData['recordHeight'] ?? 0,
        subWidth: cameraData['subWidth'] ?? 0,
        subHeight: cameraData['subHeight'] ?? 0,
        connected: cameraData['connected'] ?? false,
        lastSeenAt: cameraData['lastSeenAt'] ?? DateTime.now().toIso8601String(),
        recording: cameraData['recording'] ?? false,
      );
      updatedCameras.add(newCamera);
    }
    
    // Update the device with the new cameras list
    _devices[device.macKey] = device.copyWith(cameras: updatedCameras);
  }
  
  // Helper method to set a specific property on a device
  void _setDeviceProperty(CameraDevice device, String propertyName, dynamic propertyValue) {
    // Create a map with the property
    Map<String, dynamic> propertyMap = {};
    propertyMap[propertyName] = propertyValue;
    
    // Use the update properties method
    _updateDeviceProperties(device, propertyMap);
  }
  
  // Debug function to dump all devices and their properties
  void debugPrintDevices() {
    print('=== Device Debug Info ===');
    print('Total devices: ${_devices.length}');
    
    for (var entry in _devices.entries) {
      print('Device ID: ${entry.key}');
      print('  MAC Address: ${entry.value.macAddress}');
      print('  MAC Key: ${entry.value.macKey}');
      print('  IP: ${entry.value.ipv4}');
      print('  Connected: ${entry.value.connected}');
      print('  Last Seen: ${entry.value.lastSeenAt}');
      print('  Uptime: ${entry.value.uptime}');
      print('  Device Type: ${entry.value.deviceType}');
      print('  Firmware: ${entry.value.firmwareVersion}');
      print('  Cameras: ${entry.value.cameras.length}');
      
      // Print camera details
      for (int i = 0; i < entry.value.cameras.length; i++) {
        final cam = entry.value.cameras[i];
        print('    Camera $i: ${cam.name}');
        print('      IP: ${cam.ip}');
        print('      Connected: ${cam.connected}');
        print('      Brand: ${cam.brand}');
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
