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
  
  // Find the parent device for a specific camera
  CameraDevice? getDeviceForCamera(Camera camera) {
    for (var device in _devices.values) {
      for (var cam in device.cameras) {
        if (cam.id == camera.id) {
          return device;
        }
      }
    }
    return null;
  }
  
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

  void setSelectedDevice(String macAddress) {
    if (_devices.containsKey(macAddress)) {
      _selectedDevice = _devices[macAddress];
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

  // Process "changed" messages from WebSocket
  void processWebSocketMessage(Map<String, dynamic> message) {
    if (message['c'] == 'changed' && message.containsKey('data') && message.containsKey('val')) {
      final String dataPath = message['data'];
      final dynamic value = message['val'];
      
      // Debugging log the message
      print('Processing WebSocket message: ${json.encode(message)}');
      
      // Check if this is a camera device-related message
      if (dataPath.startsWith('ecs.slaves.m_')) {
        // Extract the MAC address from the data path
        // Format is like: ecs.slaves.m_26_C1_7A_0B_1F_19.property
        final parts = dataPath.split('.');
        if (parts.length >= 3) {
          final macKey = parts[2]; // Get m_26_C1_7A_0B_1F_19
          final macAddress = macKey.substring(2).replaceAll('_', ':'); // Convert to proper MAC format
          
          print('Extracted macKey: $macKey, macAddress: $macAddress');
          
          // Create the device if it doesn't exist yet
          if (!_devices.containsKey(macKey)) {
            print('Creating new device with macKey: $macKey');
            _devices[macKey] = CameraDevice(
              macAddress: macAddress,
              macKey: macKey,
              ipv4: '',
              lastSeenAt: '',
              connected: false,
              uptime: '',
              deviceType: '',
              firmwareVersion: '',
              recordPath: '',
              cameras: [],
            );
            
            // If this is the first device we're seeing, select it automatically
            if (_selectedDevice == null) {
              _selectedDevice = _devices[macKey];
              print('Auto-selected first device: $macKey');
            }
          }
          
          _updateDeviceProperty(macKey, parts, value);
          notifyListeners(); // Notify after any device update
        }
      }
    }
  }
  
  // Update specific device property based on the data path
  void _updateDeviceProperty(String macKey, List<String> parts, dynamic value) {
    final device = _devices[macKey]!;
    
    // Skip ecs.slaves.macKey prefix to get the actual property path
    final propertyPath = parts.sublist(3);
    
    if (propertyPath.isNotEmpty) {
      switch (propertyPath[0]) {
        case 'ipv4':
          device.ipv4 = value.toString();
          break;
        case 'connected':
          device.connected = value == 1;
          break;
        case 'last_seen_at':
          device.lastSeenAt = value.toString();
          break;
        case 'test':
          if (propertyPath.length > 1 && propertyPath[1] == 'uptime') {
            device.uptime = value.toString();
          }
          break;
        case 'app':
          if (propertyPath.length > 1) {
            switch (propertyPath[1]) {
              case 'deviceType':
                device.deviceType = value.toString();
                break;
              case 'firmware_version':
                device.firmwareVersion = value.toString();
                break;
              case 'recordPath':
                device.recordPath = value.toString();
                break;
            }
          }
          break;
        default:
          // Check if this is a camera property pattern (cam[X])
          final camPattern = RegExp(r'cam\[(\d+)\]');
          final match = camPattern.firstMatch(propertyPath[0]);
          
          if (match != null) {
            // Extract camera index from the match
            final cameraIndex = int.tryParse(match.group(1) ?? '-1') ?? -1;
            
            if (cameraIndex >= 0) {
              print('Updating camera $cameraIndex property: ${propertyPath.join('.')} = $value');
              _updateCameraProperty(device, cameraIndex, propertyPath, value);
            } else {
              print('Error parsing camera index from ${propertyPath[0]}');
            }
          }
          
          // Handle camera reports which come separately with camera name as key
          else if (propertyPath[0] == 'camreports' && propertyPath.length > 2) {
            final cameraName = propertyPath[1];
            final propertyName = propertyPath[2];
            
            print('Processing camera report for $cameraName: $propertyName = $value');
            
            // Find camera by name first
            int cameraIndex = device.cameras.indexWhere((cam) => cam.name == cameraName);
            
            // If camera doesn't exist yet, we need to create a placeholder
            if (cameraIndex < 0) {
              print('Camera $cameraName not found in device - creating placeholder');
              
              // Find the next available index
              int nextIndex = device.cameras.length;
              
              // Create a new camera with the name from the report
              Camera newCamera = Camera(
                index: nextIndex,
                name: cameraName,
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
              );
              
              // Add the new camera to the device
              device.cameras.add(newCamera);
              cameraIndex = nextIndex;
              print('Created placeholder camera at index $cameraIndex');
            }
            
            // Now we have a valid camera index, update the property
            final camera = device.cameras[cameraIndex];
            
            // Update camera status properties from the report
            switch (propertyName) {
              case 'connected':
                camera.connected = value == 1;
                print('Updated camera $cameraName connected status: ${camera.connected}');
                break;
              case 'disconnected':
                camera.disconnected = value.toString();
                break;
              case 'last_seen_at':
                camera.lastSeenAt = value.toString();
                break;
              case 'recording':
                camera.recording = value == true || value == 1;
                break;
            }
          }
          break;
      }
    }
  }
  
  // Update camera properties within a device
  void _updateCameraProperty(CameraDevice device, int cameraIndex, List<String> propertyPath, dynamic value) {
    // Ensure we have enough cameras in the array
    while (device.cameras.length <= cameraIndex) {
      int nextIndex = device.cameras.length;
      print('Creating camera at index $nextIndex because we need index $cameraIndex');
      
      device.cameras.add(Camera(
        index: nextIndex,
        name: 'Camera ${nextIndex + 1}',
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
    
    final camera = device.cameras[cameraIndex];
    
    // Extract the property name after cam[X]
    final propertyName = propertyPath.length > 1 ? propertyPath[1] : '';
    
    // Update the camera property based on name
    switch (propertyName) {
      case 'name':
        camera.name = value.toString();
        print('Set camera[$cameraIndex] name to: ${camera.name}');
        break;
      case 'cameraIp':
        camera.ip = value.toString();
        break;
      case 'cameraRawIp':
        camera.rawIp = value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'username':
        camera.username = value.toString();
        break;
      case 'password':
        camera.password = value.toString();
        break;
      case 'brand':
        camera.brand = value.toString();
        break;
      case 'hw':
        camera.hw = value.toString();
        break;
      case 'manufacturer':
        camera.manufacturer = value.toString();
        break;
      case 'country':
        camera.country = value.toString();
        break;
      case 'xAddrs':
        camera.xAddrs = value.toString();
        break;
      case 'mediaUri':
        camera.mediaUri = value.toString();
        break;
      case 'recordUri':
        camera.recordUri = value.toString();
        break;
      case 'subUri':
        camera.subUri = value.toString();
        break;
      case 'remoteUri':
        camera.remoteUri = value.toString();
        break;
      case 'mainSnapShot':
        camera.mainSnapShot = value.toString();
        break;
      case 'subSnapShot':
        camera.subSnapShot = value.toString();
        break;
      case 'recordPath':
        camera.recordPath = value.toString();
        break;
      case 'recordcodec':
        camera.recordCodec = value.toString();
        break;
      case 'recordwidth':
        camera.recordWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'recordheight':
        camera.recordHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'subcodec':
        camera.subCodec = value.toString();
        break;
      case 'subwidth':
        camera.subWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'subheight':
        camera.subHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
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
