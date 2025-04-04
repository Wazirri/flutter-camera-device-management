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
    print('Requesting camera refresh via WebSocket...');
    
    // Print current state for debugging
    debugPrintDevices();
  }
  
  // Process a WebSocket message and update our devices
  void processWebSocketMessage(Map<String, dynamic> message) {
    if (message['c'] == 'changed' && 
        message.containsKey('data') && 
        message.containsKey('val')) {
      
      final String dataPath = message['data'].toString();
      
      // Check if this is a device message (starts with ecs.slaves.m_)
      if (dataPath.startsWith('ecs.slaves.m_')) {
        print('🔍 [CameraProvider] Processing device message: ${json.encode(message)}');
        
        // Extract device ID (MAC address)
        // Path format: ecs.slaves.m_XX_XX_XX_XX_XX_XX or ecs.slaves.m_XX_XX_XX_XX_XX_XXcam
        List<String> pathParts = dataPath.split('.');
        String deviceIdPath = pathParts[2]; // Get the m_XX... part
        
        // Enhanced debugging for path parts
        print('🔍 [CameraProvider] Analyzing path: $dataPath');
        print('🔍 [CameraProvider] Path parts: ${pathParts.join(' >> ')}');
        
        // Basic processing of device ID
        String deviceId = deviceIdPath;
        bool isCameraProperty = false;
        
        // Determine if this is a camera property by checking for 'cam' in the path
        for (int i = 3; i < pathParts.length; i++) {
          if (pathParts[i].startsWith('cam[') || pathParts[i] == 'cameras') {
            isCameraProperty = true;
            break;
          }
        }
        
        // Extract the base device ID (without cam suffix) for device lookup 
        String baseDeviceId = deviceId;

        // Create device if it doesn't exist yet
        if (!_devices.containsKey(baseDeviceId)) {
          print('🆕 [CameraProvider] Creating new device: $baseDeviceId');
          final newDevice = CameraDevice(
            macAddress: baseDeviceId.replaceAll('m_', '').replaceAll('_', ':'), 
            macKey: baseDeviceId,
            ipv4: '',
            lastSeenAt: DateTime.now().toIso8601String(),
            connected: true,
            uptime: '0',
            deviceType: 'Unknown',
            firmwareVersion: 'Unknown',
            recordPath: '',
            cameras: [],
          );
          _devices[baseDeviceId] = newDevice;
          print('🆕 [CameraProvider] Created new device with key: $baseDeviceId');
        }
        
        // Get the device
        CameraDevice? targetDevice = _devices[baseDeviceId];
        
        if (targetDevice != null) {
          print('🔄 [CameraProvider] Updating device: ${targetDevice.macKey}');
          
          // Handle device property update
          if (message['val'] is Map) {
            print('📦 [CameraProvider] Processing properties map');
            // Extract and convert properties
            Map<String, dynamic> properties = {};
            final rawProps = message['val'] as Map;
            rawProps.forEach((key, value) {
              if (key is String) {
                properties[key] = value;
              }
            });
            
            // Update device properties
            _updateDeviceProperties(targetDevice, properties);
            
            // Extract camera information if available
            if (properties.containsKey('cameras') && properties['cameras'] is List) {
              print('📷 [CameraProvider] Processing cameras list. Count: ${(properties['cameras'] as List).length}');
              List<dynamic> cameraData = properties['cameras'];
              for (var cam in cameraData) {
                if (cam is Map) {
                  print('   📸 [CameraProvider] Updating camera: ${cam['name'] ?? 'Unknown'}');
                  _updateCameraData(targetDevice, cam);
                }
              }
            }
          }
          
          // Handle direct path updates (with value as String or other primitive)
          else {
            // Extract property name from path (everything after the first 3 segments)
            if (pathParts.length > 3) {
              String propertyPath = pathParts.sublist(3).join('.');
              dynamic propertyValue = message['val'];
              
              print('📐 [CameraProvider] Property path: $propertyPath');
              
              // Handle properties differently based on their path
              if (isCameraProperty) {
                // This is a camera-specific property
                _updateCameraProperty(targetDevice, propertyPath, propertyValue);
              } else {
                // This is a device property
                _setDeviceProperty(targetDevice, propertyPath, propertyValue);
              }
            }
          }
          
          // If this is our first device, make it the selected one
          if (_selectedDevice == null) {
            _selectedDevice = targetDevice;
          }
          
          notifyListeners();
        } else {
          print('❌ [CameraProvider] Device not found for ID: $baseDeviceId after creation attempt');
        }
      }
    }
  }
  
  // Update a specific camera property
  void _updateCameraProperty(CameraDevice device, String propertyPath, dynamic value) {
    // Camera properties can come in different formats
    List<String> parts = propertyPath.split('.');
    print('🔧 [CameraProvider] Parsing camera property path: $propertyPath');
    print('🔧 [CameraProvider] Path parts: ${parts.join(' | ')}');
    
    // Format 1: cam[0].property (or just cam[0] for direct path) - Extract camera index from brackets
    if (parts.length >= 1 && parts[0].startsWith('cam[') && parts[0].contains(']')) {
      String indexStr = parts[0].substring(4, parts[0].indexOf(']'));
      int? cameraIndex = int.tryParse(indexStr);
      
      if (cameraIndex == null) {
        print('❌ [CameraProvider] Invalid camera index: $indexStr');
        return;
      }
      
      print('📷 [CameraProvider] Found camera index: $cameraIndex from $parts[0]');
      
      // Ensure we have the camera at this index
      _ensureCameraExists(device, cameraIndex);
      
      // Extract the property name (after the cam[0] part)
      String propertyName = parts.length > 1 ? parts.sublist(1).join('.') : '';
      
      if (propertyName.isNotEmpty) {
        // Update the camera property
        _updateCameraPropertyByIndex(device, cameraIndex, propertyName, value);
      } else {
        print('⚠️ [CameraProvider] No property name in path: $propertyPath');
      }
      
      return;
    }
    
    // Format 2: cameras.0.property - Extract camera index as an integer
    if (parts.length >= 2 && parts[0] == 'cameras') {
      // Try to parse the camera index
      int? cameraIndex;
      try {
        cameraIndex = int.parse(parts[1]);
      } catch (e) {
        print('❌ [CameraProvider] Invalid camera index from format cameras.idx: ${parts[1]}');
        return;
      }
      
      // Ensure we have the camera at this index
      _ensureCameraExists(device, cameraIndex);
      
      // Extract the property name (after cameras.INDEX part)
      String propertyName = parts.length > 2 ? parts.sublist(2).join('.') : '';
      
      if (propertyName.isNotEmpty) {
        // Update the camera property
        _updateCameraPropertyByIndex(device, cameraIndex, propertyName, value);
      } else {
        print('⚠️ [CameraProvider] No property name in path: $propertyPath');
      }
      
      return;
    }
    
    // If we get here, the format was not recognized
    print('⚠️ [CameraProvider] Unrecognized camera property path format: $propertyPath');
  }
  
  // Ensure a camera exists at the given index, create if needed
  void _ensureCameraExists(CameraDevice device, int cameraIndex) {
    if (cameraIndex < 0) {
      print('❌ [CameraProvider] Invalid negative camera index: $cameraIndex');
      return;
    }
    
    // Check if we need to create new cameras
    if (device.cameras.length <= cameraIndex) {
      print('📷 [CameraProvider] Creating camera at index $cameraIndex for device: ${device.macKey}');
      
      List<Camera> updatedCameras = List.from(device.cameras);
      
      // Add cameras until we reach the desired index
      while (updatedCameras.length <= cameraIndex) {
        int newIndex = updatedCameras.length;
        Camera newCamera = Camera(
          index: newIndex,
          name: 'Camera $newIndex',
          ip: '',
          rawIp: 0,
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
          lastSeenAt: DateTime.now().toIso8601String(),
          recording: false,
        );
        updatedCameras.add(newCamera);
      }
      
      // Update the device with the new cameras list
      _devices[device.macKey] = device.copyWith(cameras: updatedCameras);
    }
  }
  
  // Update a camera property by index
  void _updateCameraPropertyByIndex(CameraDevice device, int cameraIndex, String propertyName, dynamic value) {
    if (cameraIndex < 0 || cameraIndex >= device.cameras.length) {
      print('❌ [CameraProvider] Camera index out of range: $cameraIndex, available: ${device.cameras.length}');
      return;
    }
    
    print('🔄 [CameraProvider] Updating property for camera $cameraIndex: $propertyName = $value');
    
    List<Camera> updatedCameras = List.from(device.cameras);
    Camera camera = updatedCameras[cameraIndex];
    
    // Update the specific property
    Camera updatedCamera = _updateCameraWithProperty(camera, propertyName, value);
    updatedCameras[cameraIndex] = updatedCamera;
    
    // Update the device with the new cameras list
    _devices[device.macKey] = device.copyWith(cameras: updatedCameras);
  }
  
  // Helper method to update a single property on a camera
  Camera _updateCameraWithProperty(Camera camera, String propertyName, dynamic value) {
    // Handle each known property - add more as needed
    print('🔍 [CameraProvider] Updating camera property: $propertyName = $value');
    
    switch (propertyName) {
      case 'name':
        return camera.copyWith(name: value.toString());
      
      // IP address properties
      case 'ip':
      case 'cameraIp': // Handle both property naming formats
        return camera.copyWith(ip: value.toString());
      
      // Raw IP address properties
      case 'rawIp':
      case 'cameraRawIp': // Handle both property naming formats
        return camera.copyWith(rawIp: value is int ? value : int.tryParse(value.toString()) ?? 0);
      
      // Connection status properties
      case 'connected':
        return camera.copyWith(connected: value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1'));
      
      // Authentication properties
      case 'username':
        return camera.copyWith(username: value.toString());
      case 'password':
        return camera.copyWith(password: value.toString());
      
      // ONVIF properties
      case 'xAddrs':
        return camera.copyWith(xAddrs: value.toString());
      case 'xAddr': // Handle both xAddrs and xAddr
        return camera.copyWith(xAddrs: value.toString());
      
      // Stream URI properties
      case 'mediaUri':
        return camera.copyWith(mediaUri: value.toString());
      case 'recordUri':
        return camera.copyWith(recordUri: value.toString());
      case 'subUri':
        return camera.copyWith(subUri: value.toString());
      case 'remoteUri':
        return camera.copyWith(remoteUri: value.toString());
      
      // Snapshot properties
      case 'mainSnapShot':
        return camera.copyWith(mainSnapShot: value.toString());
      case 'subSnapShot':
        return camera.copyWith(subSnapShot: value.toString());
      
      // Camera identification properties
      case 'brand':
      case 'model':
        return camera.copyWith(brand: value.toString());
      case 'hw':
        return camera.copyWith(hw: value.toString());
      case 'manufacturer':
        return camera.copyWith(manufacturer: value.toString());
      case 'country':
        return camera.copyWith(country: value.toString());
      
      // Camera status properties
      case 'recording':
        return camera.copyWith(recording: value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1'));
      case 'disconnected':
        return camera.copyWith(disconnected: value.toString());
      case 'last_seen_at':
        return camera.copyWith(lastSeenAt: value.toString());
      
      // Recording properties
      case 'recordPath':
        return camera.copyWith(recordPath: value.toString());
      case 'recordcodec':
        return camera.copyWith(recordCodec: value.toString());
      case 'recordwidth':
        return camera.copyWith(recordWidth: value is int ? value : int.tryParse(value.toString()) ?? 0);
      case 'recordheight':
        return camera.copyWith(recordHeight: value is int ? value : int.tryParse(value.toString()) ?? 0);
      
      // Sub-stream properties
      case 'subcodec':
        return camera.copyWith(subCodec: value.toString());
      case 'subwidth':
        return camera.copyWith(subWidth: value is int ? value : int.tryParse(value.toString()) ?? 0);
      case 'subheight':
        return camera.copyWith(subHeight: value is int ? value : int.tryParse(value.toString()) ?? 0);
        
      // Group property
      case 'group':
        return camera.copyWith(group: value.toString());
        
      // Sound recording property
      case 'soundRec':
        return camera.copyWith(soundRec: value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1'));
        
      default:
        print('⚠️ [CameraProvider] Unknown camera property: $propertyName = $value');
        return camera; // No change for unknown properties
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
    
    // Ensure we have the camera at this index
    _ensureCameraExists(device, cameraIndex);
    
    // Now update all its properties
    List<Camera> updatedCameras = List.from(device.cameras);
    Camera camera = updatedCameras[cameraIndex];
    
    // Update with all provided properties
    Camera updatedCamera = camera.copyWith(
      name: cameraData['name'] ?? camera.name,
      ip: cameraData['ip'] ?? cameraData['cameraIp'] ?? camera.ip,
      rawIp: cameraData['rawIp'] ?? cameraData['cameraRawIp'] ?? camera.rawIp,
      username: cameraData['username'] ?? camera.username,
      password: cameraData['password'] ?? camera.password,
      brand: cameraData['brand'] ?? cameraData['model'] ?? camera.brand,
      hw: cameraData['hw'] ?? camera.hw,
      manufacturer: cameraData['manufacturer'] ?? camera.manufacturer,
      country: cameraData['country'] ?? camera.country,
      xAddrs: cameraData['xAddrs'] ?? cameraData['xAddr'] ?? camera.xAddrs,
      mediaUri: cameraData['mediaUri'] ?? camera.mediaUri,
      recordUri: cameraData['recordUri'] ?? camera.recordUri,
      subUri: cameraData['subUri'] ?? camera.subUri,
      remoteUri: cameraData['remoteUri'] ?? camera.remoteUri,
      mainSnapShot: cameraData['mainSnapShot'] ?? camera.mainSnapShot,
      subSnapShot: cameraData['subSnapShot'] ?? camera.subSnapShot,
      recordPath: cameraData['recordPath'] ?? camera.recordPath,
      recordCodec: cameraData['recordCodec'] ?? camera.recordCodec,
      recordWidth: cameraData['recordWidth'] ?? camera.recordWidth,
      recordHeight: cameraData['recordHeight'] ?? camera.recordHeight,
      subCodec: cameraData['subCodec'] ?? camera.subCodec,
      subWidth: cameraData['subWidth'] ?? camera.subWidth,
      subHeight: cameraData['subHeight'] ?? camera.subHeight,
      connected: cameraData['connected'] ?? camera.connected,
      disconnected: cameraData['disconnected'] ?? camera.disconnected,
      group: cameraData['group'] ?? camera.group,
      soundRec: cameraData['soundRec'] ?? camera.soundRec,
      lastSeenAt: cameraData['lastSeenAt'] ?? camera.lastSeenAt,
      recording: cameraData['recording'] ?? camera.recording,
    );
    
    updatedCameras[cameraIndex] = updatedCamera;
    
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
        print('      Index: ${cam.index}');
        print('      IP: ${cam.ip}');
        print('      Connected: ${cam.connected}');
        print('      Brand: ${cam.brand}');
        print('      Media URI: ${cam.mediaUri}');
        print('      Record URI: ${cam.recordUri}');
        print('      Group: ${cam.group ?? "None"}');
        print('      Sound Rec: ${cam.soundRec ?? false}');
        print('      xAddrs: ${cam.xAddrs}');
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
