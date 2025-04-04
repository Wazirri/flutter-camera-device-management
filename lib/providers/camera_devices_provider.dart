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
  
  // Enhanced debug print for all devices and cameras
  void debugPrintDevices() {
    print('📊 [CameraProvider] ===== DEVICE REPORT =====');
    print('📊 [CameraProvider] Total unique devices: ${_devices.length}');
    
    for (var entry in _devices.entries) {
      String deviceId = entry.key;
      CameraDevice device = entry.value;
      print('🔌 Device: $deviceId (${device.macAddress})');
      print('   IP: ${device.ipv4}, Connected: ${device.connected}');
      print('   Total cameras: ${device.cameras.length}');
      
      for (int i = 0; i < device.cameras.length; i++) {
        Camera camera = device.cameras[i];
        print('     📷 Camera $i: ${camera.name}');
        print('        IP: ${camera.ip}, Connected: ${camera.connected}');
        print('        Media URI: ${camera.mediaUri}');
        print('        Record URI: ${camera.recordUri}');
      }
    }
    print('📊 [CameraProvider] ========================');
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
        int cameraIndex = -1;
        String cameraName = "";
        
        // Check if this is a camera property by analyzing the path structure
        // Pattern 1: cam[X]
        if (pathParts.length > 3 && pathParts[3].startsWith('cam[')) {
          isCameraProperty = true;
          String indexStr = pathParts[3].substring(4, pathParts[3].indexOf(']'));
          cameraIndex = int.tryParse(indexStr) ?? -1;
          print('📷 [CameraProvider] Found cam[] pattern with index: $cameraIndex');
        }
        // Pattern 2: camreports.CAMERANAME
        else if (pathParts.length > 3 && pathParts[3] == 'camreports' && pathParts.length > 4) {
          isCameraProperty = true;
          cameraName = pathParts[4];
          print('📹 [CameraProvider] Found camreports pattern with camera name: $cameraName');
        }
        // Pattern 3: cameras.X
        else if (pathParts.length > 3 && pathParts[3] == 'cameras' && pathParts.length > 4) {
          isCameraProperty = true;
          cameraIndex = int.tryParse(pathParts[4]) ?? -1;
          print('🎬 [CameraProvider] Found cameras.X pattern with index: $cameraIndex');
        }
        
        // Extract the base device ID (without cam suffix) for device lookup 
        String baseDeviceId = deviceId;
        
        // Strip any cam suffix if present
        if (baseDeviceId.endsWith('cam')) {
          baseDeviceId = baseDeviceId.substring(0, baseDeviceId.length - 3);
        }

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
                if (cameraIndex >= 0) {
                  // Direct cam[X] update
                  print('📝 [CameraProvider] Updating camera at index $cameraIndex with property from path: $propertyPath');
                  _updateCameraPropertyByPath(targetDevice, propertyPath, propertyValue, cameraIndex);
                } 
                else if (cameraName.isNotEmpty) {
                  // camreports.CAMERANAME update
                  print('📝 [CameraProvider] Updating camera by name $cameraName with property from path: $propertyPath');
                  _updateCameraPropertyByName(targetDevice, propertyPath, propertyValue, cameraName);
                }
                else {
                  // Generic path update
                  print('📝 [CameraProvider] Updating camera via generic path: $propertyPath');
                  _updateCameraProperty(targetDevice, propertyPath, propertyValue);
                }
              } else {
                // This is a device property
                print('📝 [CameraProvider] Updating device property: $propertyPath');
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
  
  // Update a camera by name (for camreports format)
  void _updateCameraPropertyByName(CameraDevice device, String propertyPath, dynamic value, String cameraName) {
    print('🔎 [CameraProvider] Searching for camera with name: $cameraName among ${device.cameras.length} cameras');
    
    // Find camera with this name or return the first one if none found
    int indexToUpdate = -1;
    for (int i = 0; i < device.cameras.length; i++) {
      print('   Checking camera $i: ${device.cameras[i].name}');
      if (device.cameras[i].name == cameraName) {
        indexToUpdate = i;
        print('   ✅ Found matching camera at index $i');
        break;
      }
    }
    
    // If camera not found, create it if we have a valid name
    if (indexToUpdate < 0 && cameraName.isNotEmpty) {
      print('🆕 [CameraProvider] Creating new camera with name: $cameraName');
      
      List<Camera> updatedCameras = List.from(device.cameras);
      int newIndex = updatedCameras.length;
      
      Camera newCamera = Camera(
        index: newIndex,
        name: cameraName,
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
      _devices[device.macKey] = device.copyWith(cameras: updatedCameras);
      
      // Update index to the newly added camera
      indexToUpdate = newIndex;
    }
    
    // Now update the property if we found or created a camera
    if (indexToUpdate >= 0) {
      List<String> parts = propertyPath.split('.');
      String finalProperty = parts.length > 1 ? parts.last : parts[0];
      print('📝 [CameraProvider] Updating camera at index $indexToUpdate, property: $finalProperty = $value');
      _updateCameraPropertyByIndex(device, indexToUpdate, finalProperty, value);
    } else {
      print('❌ [CameraProvider] Could not find or create camera with name: $cameraName');
    }
  }
  
  // Update a camera property by direct path and index
  void _updateCameraPropertyByPath(CameraDevice device, String propertyPath, dynamic value, int cameraIndex) {
    // Ensure we have the camera at this index
    _ensureCameraExists(device, cameraIndex);
    
    // Extract the property name (after the cam[X] part)
    List<String> parts = propertyPath.split('.');
    String propertyName = parts.length > 1 ? parts.sublist(1).join('.') : '';
    
    if (propertyName.isNotEmpty) {
      // Update the camera property
      print('📝 [CameraProvider] Updating camera $cameraIndex property: $propertyName = $value');
      _updateCameraPropertyByIndex(device, cameraIndex, propertyName, value);
    } else {
      print('⚠️ [CameraProvider] No property name in path: $propertyPath');
    }
  }
  
  // Update a specific camera property (legacy path parsing)
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
    
    // Format 3: camreports.CAMERANAME.property - Look up camera by name
    if (parts.length >= 2 && parts[0] == 'camreports') {
      String cameraName = parts[1];
      print('📹 [CameraProvider] Found camreports pattern with camera name: $cameraName');
      
      // Extract the property name (after camreports.CAMERANAME part)
      String propertyName = parts.length > 2 ? parts.sublist(2).join('.') : '';
      
      if (propertyName.isNotEmpty) {
        // Find camera with this name
        _updateCameraPropertyByName(device, propertyName, value, cameraName);
      } else {
        print('⚠️ [CameraProvider] No property name in camreports path: $propertyPath');
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
        bool boolValue = value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1');
        return camera.copyWith(connected: boolValue);
      
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
        bool boolValue = value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1');
        return camera.copyWith(recording: boolValue);
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
        int intValue = value is int ? value : int.tryParse(value.toString()) ?? 0;
        return camera.copyWith(recordWidth: intValue);
      case 'recordheight':
        int intValue = value is int ? value : int.tryParse(value.toString()) ?? 0;
        return camera.copyWith(recordHeight: intValue);
      
      // Sub-stream properties
      case 'subcodec':
        return camera.copyWith(subCodec: value.toString());
      case 'subwidth':
        int intValue = value is int ? value : int.tryParse(value.toString()) ?? 0;
        return camera.copyWith(subWidth: intValue);
      case 'subheight':
        int intValue = value is int ? value : int.tryParse(value.toString()) ?? 0;
        return camera.copyWith(subHeight: intValue);
      
      // Group properties
      case 'group':
        return camera.copyWith(group: value.toString());
      
      // Audio properties
      case 'soundRec':
        bool boolValue = value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1');
        return camera.copyWith(soundRec: boolValue);
        
      default:
        print('⚠️ [CameraProvider] Unknown camera property: $propertyName');
        return camera;
    }
  }
  
  // Update camera data from a map
  void _updateCameraData(CameraDevice device, Map<dynamic, dynamic> cameraData) {
    // Extract camera index
    int? index = cameraData['index'];
    if (index == null) {
      print('❌ [CameraProvider] Camera data missing index');
      return;
    }
    
    // Convert map values to specific types
    Map<String, dynamic> typedData = {};
    cameraData.forEach((key, value) {
      if (key is String) {
        typedData[key] = value;
      }
    });
    
    // Ensure we have the camera at this index
    _ensureCameraExists(device, index);
    
    // Update each property from the map
    typedData.forEach((propertyName, propertyValue) {
      if (propertyName != 'index') { // Skip index itself
        _updateCameraPropertyByIndex(device, index, propertyName, propertyValue);
      }
    });
  }
  
  // Update device properties
  void _updateDeviceProperties(CameraDevice device, Map<String, dynamic> properties) {
    Map<String, dynamic> deviceUpdates = {};
    
    // Extract known device properties
    if (properties.containsKey('ipv4')) {
      deviceUpdates['ipv4'] = properties['ipv4'].toString();
    }
    if (properties.containsKey('lastSeenAt')) {
      deviceUpdates['lastSeenAt'] = properties['lastSeenAt'].toString();
    }
    if (properties.containsKey('connected')) {
      deviceUpdates['connected'] = properties['connected'] is bool ? 
        properties['connected'] : 
        (properties['connected'].toString().toLowerCase() == 'true' || properties['connected'].toString() == '1');
    }
    if (properties.containsKey('uptime')) {
      deviceUpdates['uptime'] = properties['uptime'].toString();
    }
    if (properties.containsKey('deviceType')) {
      deviceUpdates['deviceType'] = properties['deviceType'].toString();
    }
    if (properties.containsKey('firmwareVersion')) {
      deviceUpdates['firmwareVersion'] = properties['firmwareVersion'].toString();
    }
    if (properties.containsKey('recordPath')) {
      deviceUpdates['recordPath'] = properties['recordPath'].toString();
    }
    
    // Apply updates if we have any
    if (deviceUpdates.isNotEmpty) {
      _devices[device.macKey] = device.copyWith(
        ipv4: deviceUpdates.containsKey('ipv4') ? deviceUpdates['ipv4'] : device.ipv4,
        lastSeenAt: deviceUpdates.containsKey('lastSeenAt') ? deviceUpdates['lastSeenAt'] : device.lastSeenAt,
        connected: deviceUpdates.containsKey('connected') ? deviceUpdates['connected'] : device.connected,
        uptime: deviceUpdates.containsKey('uptime') ? deviceUpdates['uptime'] : device.uptime,
        deviceType: deviceUpdates.containsKey('deviceType') ? deviceUpdates['deviceType'] : device.deviceType,
        firmwareVersion: deviceUpdates.containsKey('firmwareVersion') ? deviceUpdates['firmwareVersion'] : device.firmwareVersion,
        recordPath: deviceUpdates.containsKey('recordPath') ? deviceUpdates['recordPath'] : device.recordPath,
      );
    }
  }
  
  // Set a single device property
  void _setDeviceProperty(CameraDevice device, String propertyName, dynamic value) {
    print('🏠 [CameraProvider] Setting device property: $propertyName = $value');
    
    switch (propertyName) {
      case 'ipv4':
        _devices[device.macKey] = device.copyWith(ipv4: value.toString());
        break;
      case 'lastSeenAt':
        _devices[device.macKey] = device.copyWith(lastSeenAt: value.toString());
        break;
      case 'connected':
        bool boolValue = value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1');
        _devices[device.macKey] = device.copyWith(connected: boolValue);
        break;
      case 'uptime':
        _devices[device.macKey] = device.copyWith(uptime: value.toString());
        break;
      case 'deviceType':
        _devices[device.macKey] = device.copyWith(deviceType: value.toString());
        break;
      case 'firmwareVersion':
        _devices[device.macKey] = device.copyWith(firmwareVersion: value.toString());
        break;
      case 'recordPath':
        _devices[device.macKey] = device.copyWith(recordPath: value.toString());
        break;
      default:
        print('⚠️ [CameraProvider] Unknown device property: $propertyName');
        break;
    }
  }
}
