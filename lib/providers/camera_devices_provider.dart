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
    print('Setting selected device: $macKey');
    if (_devices.containsKey(macKey)) {
      _selectedDevice = _devices[macKey];
      _selectedCameraIndex = 0; // Reset camera index when device changes
      print('Selected device: $_selectedDevice');
      notifyListeners();
    } else {
      print('Device not found with key: $macKey');
    }
  }

  void setSelectedCameraIndex(int index) {
    print('Setting selected camera index: $index');
    if (_selectedDevice != null && index >= 0 && index < _selectedDevice!.cameras.length) {
      _selectedCameraIndex = index;
      print('Selected camera: ${_selectedDevice!.cameras[_selectedCameraIndex]}');
      notifyListeners();
    } else {
      print('Invalid camera index: $index for device: $_selectedDevice');
    }
  }
  
  // Refresh cameras - simulates a refresh by triggering UI update
  void refreshCameras() {
    print('Refreshing cameras');
    _isLoading = true;
    notifyListeners();
    
    // Simulate a delay for refresh
    Future.delayed(const Duration(seconds: 1), () {
      _isLoading = false;
      notifyListeners();
      print('Camera refresh completed');
    });
  }

  // Method to handle update messages from WebSocketProvider
  void updateDeviceFromChangedMessage(Map<String, dynamic> message) {
    try {
      print('CameraDevicesProvider.updateDeviceFromChangedMessage received message: ${json.encode(message)}');
      
      // Make sure we have the expected fields
      if (!message.containsKey('data') || !message.containsKey('val')) {
        print('Error: Message missing required fields (data or val)');
        return;
      }
      
      // Get data path and value
      final String dataPath = message['data'].toString();
      final dynamic value = message['val'];
      
      // Make sure this is a camera device message
      if (!dataPath.startsWith('ecs.slaves.m_')) {
        print('Warning: Not a camera device message: $dataPath');
        return;
      }
      
      print('Processing camera device message: $dataPath = $value');
      
      try {
        _processDeviceMessage(dataPath, value);
        notifyListeners();
      } catch (e) {
        print('Error processing device message: $e');
      }
    } catch (e) {
      print('Error in updateDeviceFromChangedMessage: $e');
    }
  }
  
  // Process device message by splitting the data path and extracting MAC and property
  void _processDeviceMessage(String dataPath, dynamic value) {
    // Split the data path to extract MAC address and property
    final parts = dataPath.split('.');
    print('Data path parts: $parts');
    
    if (parts.length < 3) {
      print('Invalid data path format: $dataPath');
      return;
    }
    
    // Extract MAC address with proper formatting
    String macKey = parts[2]; // This will be like 'm_XX_XX_XX_XX_XX_XX' or similar
    print('Extracted MAC key: $macKey');
    
    // Extract the rest of the path as the property
    final propertyPath = parts.sublist(3).join('.');
    print('Property path: $propertyPath');
    
    // Get or create device
    if (!_devices.containsKey(macKey)) {
      _devices[macKey] = CameraDevice(
        macKey: macKey,
        macAddress: _convertMacKeyToAddress(macKey),
      );
      print('Created new device for MAC: $macKey');
    }
    
    final device = _devices[macKey]!;
    
    // If this is a camera entry, it will have a path like 'cam.0.property'
    if (propertyPath.startsWith('cam.')) {
      // Extract camera index and property name
      final propertyParts = propertyPath.split('.');
      print('Property parts: $propertyParts');
      
      if (propertyParts.length < 3) {
        print('Invalid camera property format: $propertyPath');
        return;
      }
      
      final cameraIndex = int.tryParse(propertyParts[1]);
      if (cameraIndex == null) {
        print('Invalid camera index: ${propertyParts[1]}');
        return;
      }
      
      final String cameraProperty = propertyParts.sublist(2).join('.');
      print('Camera index: $cameraIndex, Camera property: $cameraProperty');
      
      // Process this camera property
      _processCameraProperty(device, cameraIndex, cameraProperty, value);
    } else {
      // This is a device property, not a camera property
      print('Processing device property: $propertyPath = $value');
      _processDeviceProperty(device, propertyPath, value);
    }
  }
  
  // Process a device-level property
  void _processDeviceProperty(CameraDevice device, String property, dynamic value) {
    print('Processing device property: Device=${device.macKey}, Property=$property, Value=$value');
    
    try {
      switch (property) {
        case 'ipaddress':
        case 'ipv4':
          device.ipv4 = value.toString();
          print('Updated device IPv4: ${device.ipv4}');
          break;
        case 'lastSeen':
        case 'lastSeenAt':
          device.lastSeenAt = value.toString();
          print('Updated device lastSeenAt: ${device.lastSeenAt}');
          break;
        case 'connected':
          device.connected = value.toString().toLowerCase() == 'true';
          print('Updated device connected: ${device.connected}');
          break;
        case 'uptime':
          device.uptime = value.toString();
          print('Updated device uptime: ${device.uptime}');
          break;
        case 'deviceType':
          device.deviceType = value.toString();
          print('Updated device type: ${device.deviceType}');
          break;
        case 'firmwareVersion':
          device.firmwareVersion = value.toString();
          print('Updated device firmware: ${device.firmwareVersion}');
          break;
        case 'recordPath':
          device.recordPath = value.toString();
          print('Updated device recordPath: ${device.recordPath}');
          break;
        default:
          print('Unhandled device property: $property');
          break;
      }
    } catch (e) {
      print('Error processing device property: $e');
    }
  }
  
  // Process a specific camera property
  void _processCameraProperty(CameraDevice device, int cameraIndex, String property, dynamic value) {
    print('Processing camera property: Device=${device.macKey}, Index=$cameraIndex, Property=$property, Value=$value');
    
    try {
      // Ensure we have enough cameras in the device
      while (device.cameras.length <= cameraIndex) {
        device.cameras.add(Camera(
          index: device.cameras.length,
        ));
        print('Added new camera: ${device.cameras.last}');
      }
      
      // Get reference to the camera
      final camera = device.cameras[cameraIndex];
      
      // Update camera properties
      switch (property) {
        case 'name':
          camera.name = value.toString();
          print('Updated camera name: ${camera.name}');
          break;
        case 'ip':
        case 'cameraIp':
          camera.ip = value.toString();
          print('Updated camera IP: ${camera.ip}');
          break;
        case 'cameraRawIp':
          camera.rawIp = value.toString();
          print('Updated camera raw IP: ${camera.rawIp}');
          break;
        case 'xAddrs':
          camera.xAddrs = value.toString();
          print('Updated camera xAddrs: ${camera.xAddrs}');
          break;
        case 'username':
          camera.username = value.toString();
          print('Updated camera username: ${camera.username}');
          break;
        case 'password':
          camera.password = value.toString();
          print('Updated camera password: ${camera.password}');
          break;
        case 'manufacturer':
          camera.manufacturer = value.toString();
          print('Updated camera manufacturer: ${camera.manufacturer}');
          break;
        case 'brand':
        case 'model':
          camera.brand = value.toString();
          print('Updated camera brand: ${camera.brand}');
          break;
        case 'country':
          camera.country = value.toString();
          print('Updated camera country: ${camera.country}');
          break;
        case 'mediaUri':
          camera.mediaUri = value.toString();
          print('Updated camera mediaUri: ${camera.mediaUri}');
          break;
        case 'recordUri':
          camera.recordUri = value.toString();
          print('Updated camera recordUri: ${camera.recordUri}');
          break;
        case 'subUri':
          camera.subUri = value.toString();
          print('Updated camera subUri: ${camera.subUri}');
          break;
        case 'remoteUri':
          camera.remoteUri = value.toString();
          print('Updated camera remoteUri: ${camera.remoteUri}');
          break;
        case 'connected':
          camera.connected = value.toString().toLowerCase() == 'true';
          print('Updated camera connected: ${camera.connected}');
          break;
        case 'disconnected':
          camera.disconnected = value.toString().toLowerCase() == 'true';
          print('Updated camera disconnected: ${camera.disconnected}');
          break;
        case 'mainSnapShot':
          camera.mainSnapShot = value.toString();
          print('Updated camera mainSnapShot: ${camera.mainSnapShot}');
          break;
        case 'subSnapShot':
          camera.subSnapShot = value.toString();
          print('Updated camera subSnapShot: ${camera.subSnapShot}');
          break;
        case 'mainWidth':
          camera.mainWidth = int.tryParse(value.toString()) ?? 0;
          print('Updated camera mainWidth: ${camera.mainWidth}');
          break;
        case 'mainHeight':
          camera.mainHeight = int.tryParse(value.toString()) ?? 0;
          print('Updated camera mainHeight: ${camera.mainHeight}');
          break;
        case 'subWidth':
          camera.subWidth = int.tryParse(value.toString()) ?? 0;
          print('Updated camera subWidth: ${camera.subWidth}');
          break;
        case 'subHeight':
          camera.subHeight = int.tryParse(value.toString()) ?? 0;
          print('Updated camera subHeight: ${camera.subHeight}');
          break;
        case 'hw':
          camera.hw = value.toString();
          print('Updated camera hw: ${camera.hw}');
          break;
        case 'recording':
          camera.recording = value.toString().toLowerCase() == 'true';
          print('Updated camera recording: ${camera.recording}');
          break;
        case 'motionDetected':
          camera.motionDetected = value.toString().toLowerCase() == 'true';
          print('Updated camera motionDetected: ${camera.motionDetected}');
          break;
        case 'lastSeenAt':
          camera.lastSeenAt = value.toString();
          print('Updated camera lastSeenAt: ${camera.lastSeenAt}');
          break;
        default:
          print('Unhandled camera property: $property');
          break;
      }
    } catch (e) {
      print('Error processing camera property: $e');
    }
  }
  
  // Convert MAC key to MAC address
  String _convertMacKeyToAddress(String macKey) {
    try {
      print('Converting MAC key to address: $macKey');
      
      // Remove 'm_' prefix and replace underscores with colons
      if (macKey.startsWith('m_')) {
        final macWithoutPrefix = macKey.substring(2);
        final macWithColons = macWithoutPrefix.replaceAll('_', ':');
        print('Converted MAC: $macWithColons');
        return macWithColons;
      } else {
        print('MAC key doesn\'t start with "m_", returning as is');
        return macKey;
      }
    } catch (e) {
      print('Error converting MAC key to address: $e');
      return macKey;
    }
  }
  
  // Convert MAC address to MAC key
  String _convertAddressToMacKey(String macAddress) {
    try {
      print('Converting MAC address to key: $macAddress');
      
      // Replace colons with underscores and add 'm_' prefix
      final macWithUnderscores = macAddress.replaceAll(':', '_');
      final macKey = 'm_$macWithUnderscores';
      print('Converted MAC key: $macKey');
      return macKey;
    } catch (e) {
      print('Error converting MAC address to key: $e');
      return macAddress;
    }
  }
  
  // Update connection status for a specific device
  void updateDeviceConnectionStatus(String macAddress, bool isConnected) {
    try {
      print('Updating connection status for MAC: $macAddress to: $isConnected');
      
      // Find the device by MAC address
      final macKey = _convertAddressToMacKey(macAddress);
      
      if (_devices.containsKey(macKey)) {
        final device = _devices[macKey]!;
        device.connected = isConnected;
        print('Updated connection status for device: $device');
        notifyListeners();
      } else {
        print('Device with MAC $macAddress not found');
      }
    } catch (e) {
      print('Error updating connection status: $e');
    }
  }
  
  // Clear all devices
  void clearDevices() {
    print('Clearing all devices');
    _devices.clear();
    _selectedDevice = null;
    _selectedCameraIndex = 0;
    notifyListeners();
  }
}
