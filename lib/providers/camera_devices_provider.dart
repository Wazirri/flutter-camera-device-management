import 'package:flutter/material.dart';
import '../models/camera_device.dart';

class CameraDevicesProvider with ChangeNotifier {
  // Map of device MAC addresses to devices
  final Map<String, CameraDevice> _devices = {};
  String _selectedDeviceId = '';
  int _selectedCameraIndex = 0;
  
  // Getters
  Map<String, CameraDevice> get devices => _devices;
  List<CameraDevice> get devicesList => _devices.values.toList();
  String get selectedDeviceId => _selectedDeviceId;
  int get selectedCameraIndex => _selectedCameraIndex;
  
  // Selectors
  void selectDevice(String deviceId) {
    if (_devices.containsKey(deviceId)) {
      _selectedDeviceId = deviceId;
      notifyListeners();
    }
  }
  
  void selectCamera(int cameraIndex) {
    _selectedCameraIndex = cameraIndex;
    notifyListeners();
  }
  
  // Get the currently selected device
  CameraDevice? get selectedDevice {
    if (_selectedDeviceId.isNotEmpty && _devices.containsKey(_selectedDeviceId)) {
      return _devices[_selectedDeviceId];
    }
    return null;
  }
  
  // Get the currently selected camera
  Camera? get selectedCamera {
    final device = selectedDevice;
    if (device != null && device.cameras.isNotEmpty) {
      if (_selectedCameraIndex >= 0 && _selectedCameraIndex < device.cameras.length) {
        return device.cameras[_selectedCameraIndex];
      } else if (device.cameras.isNotEmpty) {
        return device.cameras.first;
      }
    }
    return null;
  }
  
  // Process websocket messages to update camera devices
  void processMessage(Map<String, dynamic> message) {
    if (message['c'] != 'changed' || !message.containsKey('data') || !message.containsKey('value')) {
      return;
    }
    
    String data = message['data'];
    dynamic value = message['value'];
    
    // Process device and camera data
    if (data.startsWith('ecs.slaves.')) {
      _processEcsSlaveMessage(data, value);
      notifyListeners();
    } else if (data.startsWith('cameras.')) {
      _processCameraDataMessage(data, value);
      notifyListeners();
    } else if (data.startsWith('camreports.')) {
      _processCameraReportMessage(data, value);
      notifyListeners();
    }
  }
  
  // Process message for camera/device data
  void _processEcsSlaveMessage(String data, dynamic value) {
    // Extract the device ID (MAC address) from the data path
    // Format: ecs.slaves.m_XX_XX_XX_XX_XX_XX.prop or ecs.slaves.m_XX_XX_XX_XX_XX_XX.cam[0].prop
    try {
      // Extract device key (m_XX_XX_XX_XX_XX_XX)
      RegExpMatch? deviceMatch = RegExp(r'ecs\.slaves\.(m_[A-F0-9_]+)').firstMatch(data);
      if (deviceMatch == null) return;
      
      String deviceKey = deviceMatch.group(1)!;
      
      // Make sure device exists in our map
      if (!_devices.containsKey(deviceKey)) {
        _devices[deviceKey] = CameraDevice(
          macKey: deviceKey,
          macAddress: _formatMacAddress(deviceKey),
          ipv4: '',
          status: DeviceStatus.unknown,
          cameras: [],
        );
      }
      
      // Check if this is a camera property
      RegExpMatch? cameraMatch = RegExp(r'ecs\.slaves\.' + deviceKey + r'\.cam\[(\d+)\]\.(.+)').firstMatch(data);
      if (cameraMatch != null) {
        // This is a camera property
        int cameraIndex = int.parse(cameraMatch.group(1)!);
        String propertyName = cameraMatch.group(2)!;
        
        // Make sure the camera exists in our device
        _ensureCameraExists(_devices[deviceKey]!, cameraIndex);
        
        // Update the camera property
        _updateCameraProperty(_devices[deviceKey]!.cameras[cameraIndex], propertyName, value);
      } else {
        // This is a device property
        RegExpMatch? propertyMatch = RegExp(r'ecs\.slaves\.' + deviceKey + r'\.(.+)').firstMatch(data);
        if (propertyMatch != null) {
          String propertyName = propertyMatch.group(1)!;
          
          // Update the device property
          _updateDeviceProperty(_devices[deviceKey]!, propertyName, value);
        }
      }
    } catch (e) {
      print('Error processing ECS slave message: $e');
    }
  }
  
  // Process message for camera data
  void _processCameraDataMessage(String data, dynamic value) {
    try {
      // Format: cameras.index.property
      RegExpMatch? match = RegExp(r'cameras\.(\d+)\.(.+)').firstMatch(data);
      if (match == null) return;
      
      int cameraGlobalIndex = int.parse(match.group(1)!);
      String propertyName = match.group(2)!;
      
      // Find the device and camera this belongs to
      for (var device in _devices.values) {
        for (var camera in device.cameras) {
          if (camera.globalIndex == cameraGlobalIndex) {
            _updateCameraProperty(camera, propertyName, value);
            return;
          }
        }
      }
    } catch (e) {
      print('Error processing camera data message: $e');
    }
  }
  
  // Process message for camera reports
  void _processCameraReportMessage(String data, dynamic value) {
    try {
      // Format: camreports.NAME.property
      RegExpMatch? match = RegExp(r'camreports\.([^\.]+)\.(.+)').firstMatch(data);
      if (match == null) return;
      
      String cameraName = match.group(1)!;
      String propertyName = match.group(2)!;
      
      // Find the camera by name
      for (var device in _devices.values) {
        for (var camera in device.cameras) {
          if (camera.name == cameraName) {
            _updateCameraProperty(camera, propertyName, value);
            return;
          }
        }
      }
    } catch (e) {
      print('Error processing camera report message: $e');
    }
  }
  
  // Make sure a camera exists at the given index
  void _ensureCameraExists(CameraDevice device, int index) {
    while (device.cameras.length <= index) {
      device.cameras.add(Camera(
        index: device.cameras.length,
        globalIndex: -1,
        name: 'Camera ${device.cameras.length + 1}',
        ip: '',
        username: '',
        password: '',
        connected: false,
        recording: false,
        mainSnapShot: '',
        subSnapShot: '',
        mediaUri: '',
        recordUri: '',
        remoteUri: '',
        subUri: '',
      ));
    }
  }
  
  // Update a camera property
  void _updateCameraProperty(Camera camera, String propertyName, dynamic value) {
    switch (propertyName) {
      case 'name':
        camera.name = value.toString();
        break;
      case 'ip':
      case 'cameraIp':
      case 'cameraRawIp':
      case 'rawIp':
        camera.ip = value.toString();
        break;
      case 'username':
        camera.username = value.toString();
        break;
      case 'password':
        camera.password = value.toString();
        break;
      case 'connected':
        camera.connected = value.toString().toLowerCase() == 'true';
        break;
      case 'recording':
        camera.recording = value.toString().toLowerCase() == 'true';
        break;
      case 'mainSnapShot':
        camera.mainSnapShot = value.toString();
        break;
      case 'subSnapShot':
        camera.subSnapShot = value.toString();
        break;
      case 'mediaUri':
        camera.mediaUri = value.toString();
        break;
      case 'recordUri':
        camera.recordUri = value.toString();
        break;
      case 'remoteUri':
        camera.remoteUri = value.toString();
        break;
      case 'subUri':
        camera.subUri = value.toString();
        break;
      case 'globalIndex':
        camera.globalIndex = int.tryParse(value.toString()) ?? -1;
        break;
    }
  }
  
  // Update a device property
  void _updateDeviceProperty(CameraDevice device, String propertyName, dynamic value) {
    switch (propertyName) {
      case 'ip':
      case 'ipv4':
        device.ipv4 = value.toString();
        break;
      case 'status':
        device.status = _parseDeviceStatus(value.toString());
        break;
    }
  }
  
  // Parse device status
  DeviceStatus _parseDeviceStatus(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return DeviceStatus.online;
      case 'offline':
        return DeviceStatus.offline;
      case 'warning':
        return DeviceStatus.warning;
      case 'error':
        return DeviceStatus.error;
      default:
        return DeviceStatus.unknown;
    }
  }
  
  // Format MAC address for display
  String _formatMacAddress(String macKey) {
    // Convert from m_XX_XX_XX_XX_XX_XX to XX:XX:XX:XX:XX:XX
    if (macKey.startsWith('m_')) {
      return macKey.substring(2).replaceAll('_', ':');
    }
    return macKey;
  }
  
  // Debug print devices
  void debugPrintDevices() {
    print('------ DEVICES (${_devices.length}) ------');
    _devices.forEach((key, device) {
      print('Device: ${device.macAddress} (${device.ipv4}) - ${device.status}');
      print('Cameras: ${device.cameras.length}');
      device.cameras.forEach((camera) {
        print('  - ${camera.name} (${camera.ip}) Connected: ${camera.connected}');
      });
    });
    print('------ END DEVICES ------');
  }
}
