import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/camera_device.dart';

class CameraDevicesProvider with ChangeNotifier {
  final Map<String, DeviceInfo> _devices = {};
  final Map<String, Map<String, dynamic>> _cameraProperties = {};
  final Map<String, Map<String, dynamic>> _cameraReports = {};
  bool _isInitialized = false;

  // Getters
  Map<String, DeviceInfo> get devices => _devices;
  List<DeviceInfo> get devicesList => _devices.values.toList();
  bool get isInitialized => _isInitialized;

  void handleWebSocketMessage(String message) {
    try {
      // Parse the message
      final Map<String, dynamic> data = json.decode(message);
      
      // Check if this is a "changed" message
      if (data['c'] == 'changed' && data.containsKey('data') && data.containsKey('val')) {
        final String dataPath = data['data'];
        final dynamic value = data['val'];
        
        // Check if this is a device-related message (starts with ecs.slaves)
        if (dataPath.startsWith('ecs.slaves.')) {
          _processDeviceData(dataPath, value);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error handling WebSocket message: $e');
    }
  }

  void _processDeviceData(String dataPath, dynamic value) {
    // Extract MAC address from path (format: ecs.slaves.m_XX_XX_XX_XX_XX_XX.property)
    final parts = dataPath.split('.');
    if (parts.length < 3) return;
    
    final String macPart = parts[2]; // e.g., m_26_C1_7A_0B_1F_19
    final String macAddress = macPart.replaceAll('m_', '').replaceAll('_', ':');
    
    // Initialize device if it doesn't exist
    if (!_devices.containsKey(macAddress)) {
      _devices[macAddress] = DeviceInfo.initial(macAddress);
      _cameraProperties[macAddress] = {};
      _cameraReports[macAddress] = {};
    }
    
    // Process based on the property path
    if (parts.length >= 4) {
      final String propertyType = parts[3];
      
      if (propertyType == 'firsttime') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(firstSeen: value.toString());
      } else if (propertyType == 'connected') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(isConnected: value == 1);
      } else if (propertyType == 'ipv4') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(ipv4: value.toString());
      } else if (propertyType == 'ipv6') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(ipv6: value.toString());
      } else if (propertyType == 'last_seen_at') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(lastSeen: value.toString());
      } else if (propertyType == 'test' && parts.length >= 5 && parts[4] == 'uptime') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(uptime: value.toString());
      } else if (propertyType == 'test' && parts.length >= 5 && parts[4] == 'is_error') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(hasError: value == 1);
      } else if (propertyType == 'app' && parts.length >= 5 && parts[4] == 'firmware_version') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(firmwareVersion: value.toString());
      } else if (propertyType == 'app' && parts.length >= 5 && parts[4] == 'deviceType') {
        _devices[macAddress] = _devices[macAddress]!.copyWith(deviceType: value.toString());
      } 
      // Process camera properties
      else if (propertyType == 'cam' && parts.length >= 5) {
        final camIndex = parts[3]; // e.g., cam[0]
        final property = parts[4]; // e.g., name, cameraIp
        
        if (!_cameraProperties[macAddress]!.containsKey(camIndex)) {
          _cameraProperties[macAddress]![camIndex] = {};
        }
        
        // Store the camera property
        _cameraProperties[macAddress]![camIndex][property] = value;
        
        // Update the cameras list in the device
        _updateDeviceCameras(macAddress);
      }
      // Process camera reports
      else if (propertyType == 'camreports' && parts.length >= 6) {
        final camName = parts[4]; // e.g., KAMERA1
        final property = parts[5]; // e.g., connected, recording
        
        if (!_cameraReports[macAddress]!.containsKey(camName)) {
          _cameraReports[macAddress]![camName] = {};
        }
        
        // Store the camera report
        _cameraReports[macAddress]![camName][property] = value;
        
        // Update the cameras list in the device
        _updateDeviceCameras(macAddress);
      }
    }
    
    _isInitialized = true;
  }

  void _updateDeviceCameras(String macAddress) {
    final List<CameraDevice> cameras = [];
    
    // Create camera devices from camera properties
    for (final entry in _cameraProperties[macAddress]!.entries) {
      final String camIndex = entry.key;
      final Map<String, dynamic> props = entry.value;
      
      if (props.containsKey('name')) {
        final CameraDevice camera = CameraDevice.fromJson(props, macAddress);
        
        // Update camera with reports data if available
        final String camName = props['name'];
        if (_cameraReports[macAddress]!.containsKey(camName)) {
          final Map<String, dynamic> reports = _cameraReports[macAddress]![camName];
          
          // Update connected and recording status
          final isConnected = reports['connected'] == 1;
          final isRecording = reports['recording'] == true;
          final lastSeenAt = reports['last_seen_at']?.toString() ?? '';
          
          cameras.add(camera.copyWith(
            isConnected: isConnected,
            isRecording: isRecording,
            lastSeenAt: lastSeenAt,
          ));
        } else {
          cameras.add(camera);
        }
      }
    }
    
    // Update the device with the updated cameras list
    _devices[macAddress] = _devices[macAddress]!.copyWith(cameras: cameras);
  }

  // Get a specific camera by MAC address and camera name
  CameraDevice? getCamera(String macAddress, String cameraName) {
    if (!_devices.containsKey(macAddress)) return null;
    
    final cameras = _devices[macAddress]!.cameras;
    return cameras.firstWhere(
      (camera) => camera.name == cameraName,
      orElse: () => throw Exception('Camera not found')
    );
  }

  // Get all cameras from all devices
  List<CameraDevice> get allCameras {
    final List<CameraDevice> allCameras = [];
    for (final device in _devices.values) {
      allCameras.addAll(device.cameras);
    }
    return allCameras;
  }

  // Get online cameras only
  List<CameraDevice> get onlineCameras {
    return allCameras.where((camera) => camera.isConnected).toList();
  }

  // Get recording cameras only
  List<CameraDevice> get recordingCameras {
    return allCameras.where((camera) => camera.isRecording).toList();
  }
}