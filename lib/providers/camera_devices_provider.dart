import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/camera_device.dart';
import 'websocket_provider.dart';

class CameraDevicesProvider with ChangeNotifier {
  final Map<String, CameraDevice> _devices = {};
  CameraDevice? _selectedDevice;
  int _selectedCameraIndex = 0;

  Map<String, CameraDevice> get devices => _devices;
  List<CameraDevice> get devicesList => _devices.values.toList();
  CameraDevice? get selectedDevice => _selectedDevice;
  int get selectedCameraIndex => _selectedCameraIndex;
  
  // Get devices grouped by MAC address
  Map<String, CameraDevice> get devicesByMacAddress => _devices;
  
  // Get all cameras from all devices as a flat list
  List<Camera> get allCameras {
    List<Camera> cameras = [];
    for (var device in _devices.values) {
      cameras.addAll(device.cameras);
    }
    return cameras;
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

  // Process "changed" messages from WebSocket
  void processWebSocketMessage(Map<String, dynamic> message) {
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
          final macKey = parts[2]; // Get m_26_C1_7A_0B_1F_19
          final macAddress = macKey.substring(2).replaceAll('_', ':'); // Convert to proper MAC format
          
          debugPrint('Extracted macKey: $macKey, macAddress: $macAddress');
          
          // Create the device if it doesn't exist yet
          if (!_devices.containsKey(macKey)) {
            debugPrint('Creating new device with macKey: $macKey');
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
              debugPrint('Auto-selected first device: $macKey');
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
        case 'cam':
          // Check if this is a camera property pattern with cam[X]
          final camPattern = RegExp(r'cam\[(\d+)\]');
          final match = camPattern.firstMatch(propertyPath[0]);
          
          if (match != null) {
            // Extract camera index from the match
            final cameraIndex = int.tryParse(match.group(1) ?? '-1') ?? -1;
            
            if (cameraIndex >= 0) {
              debugPrint('Updating camera $cameraIndex property: ${propertyPath.join('.')} = $value');
              _updateCameraProperty(device, cameraIndex, propertyPath, value);
            } else {
              debugPrint('Error parsing camera index from ${propertyPath[0]}');
            }
          }
          break;
        case 'camreports':
          if (propertyPath.length > 2) {
            final cameraName = propertyPath[1];
            final propertyName = propertyPath[2];
            
            // Find camera by name
            final cameraIndex = device.cameras.indexWhere((cam) => cam.name == cameraName);
            
            if (cameraIndex >= 0) {
              debugPrint('Found camera with name $cameraName at index $cameraIndex');
              final camera = device.cameras[cameraIndex];
              
              // Update camera status properties
              switch (propertyName) {
                case 'connected':
                  camera.connected = value == 1;
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
            } else {
              debugPrint('Warning: Camera report for $cameraName but no camera with that name found');
            }
          }
          break;
      }
    }
  }
  
  // Update camera properties within a device
  void _updateCameraProperty(CameraDevice device, int cameraIndex, List<String> propertyPath, dynamic value) {
    // Find or create the camera
    while (device.cameras.length <= cameraIndex) {
      device.cameras.add(Camera(
        index: device.cameras.length,
        name: 'Camera ${device.cameras.length + 1}',
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
