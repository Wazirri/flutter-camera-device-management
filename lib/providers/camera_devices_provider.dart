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
      
      // Check if this is a camera device-related message
      if (dataPath.startsWith('ecs.slaves.m_')) {
        // Extract the MAC address from the data path
        // Format is like: ecs.slaves.m_26_C1_7A_0B_1F_19.property
        final parts = dataPath.split('.');
        if (parts.length >= 3) {
          final macKey = parts[2]; // Get m_26_C1_7A_0B_1F_19
          final macAddress = macKey.substring(2).replaceAll('_', ':'); // Convert to proper MAC format
          
          // Create the device if it doesn't exist yet
          if (!_devices.containsKey(macKey)) {
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
          }
          
          _updateDeviceProperty(macKey, parts, value);
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
          if (propertyPath.length > 0 && propertyPath[0].startsWith('cam[')) {
            // Extract camera index
            final indexStr = propertyPath[0].substring(4, propertyPath[0].length - 1);
            final cameraIndex = int.tryParse(indexStr);
            
            if (cameraIndex != null) {
              _updateCameraProperty(device, cameraIndex, propertyPath, value);
            }
          }
          break;
        case 'camreports':
          if (propertyPath.length > 2) {
            final cameraName = propertyPath[1];
            final propertyName = propertyPath[2];
            
            // Find camera by name
            final camera = device.cameras.firstWhere(
              (cam) => cam.name == cameraName, 
              orElse: () => Camera(
                index: device.cameras.length,
                name: cameraName,
                ip: '',
                username: '',
                password: '',
                brand: '',
                model: '',
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
              ),
            );
            
            // If camera isn't already in the list, add it
            if (!device.cameras.contains(camera)) {
              device.cameras.add(camera);
            }
            
            // Update camera status properties
            switch (propertyName) {
              case 'connected':
                camera.connected = value == 1;
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
    
    // If we modified the selected device, notify listeners
    if (_selectedDevice != null && _selectedDevice!.macKey == macKey) {
      notifyListeners();
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
        model: '',
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
    
    // Update the property if it has a sub-property
    if (propertyPath.length > 1) {
      final propertyName = propertyPath[1];
      
      switch (propertyName) {
        case 'name':
          camera.name = value.toString();
          break;
        case 'cameraIp':
          camera.ip = value.toString();
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
          camera.model = value.toString();
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
        case 'recordwidth':
          camera.recordWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
          break;
        case 'recordheight':
          camera.recordHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
          break;
        case 'subwidth':
          camera.subWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
          break;
        case 'subheight':
          camera.subHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
          break;
      }
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