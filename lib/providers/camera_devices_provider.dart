import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/camera_device.dart';
import 'websocket_provider.dart';

class CameraDevicesProvider with ChangeNotifier {
  final Map<String, List<CameraDevice>> _devicesByMacAddress = {};
  
  // Getter for all cameras grouped by MAC address
  Map<String, List<CameraDevice>> get devicesByMacAddress => _devicesByMacAddress;
  
  // Getter for all cameras as a flat list
  List<CameraDevice> get allDevices {
    final allDevices = <CameraDevice>[];
    _devicesByMacAddress.forEach((_, devices) {
      allDevices.addAll(devices);
    });
    return allDevices;
  }
  
  // Update or add a device from a WebSocket changed message
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
      _processCameraProperty(macKey, cameraIndex, cameraProperty, value);
    } else {
      // This is a device property, not a camera property
      print('Device property (not camera): $propertyPath');
    }
  }
  
  // Process a specific camera property
  void _processCameraProperty(String macKey, int cameraIndex, String property, dynamic value) {
    print('Processing camera property: MAC=$macKey, Index=$cameraIndex, Property=$property, Value=$value');
    
    try {
      // Get or create the list of devices for this MAC
      if (!_devicesByMacAddress.containsKey(macKey)) {
        _devicesByMacAddress[macKey] = [];
        print('Created new device list for MAC: $macKey');
      }
      
      // Ensure we have enough devices in the list
      while (_devicesByMacAddress[macKey]!.length <= cameraIndex) {
        final newDevice = CameraDevice(
          macKey: macKey,
          macAddress: _convertMacKeyToAddress(macKey),
          index: _devicesByMacAddress[macKey]!.length,
        );
        _devicesByMacAddress[macKey]!.add(newDevice);
        print('Added new camera device for MAC: $macKey, Index: ${newDevice.index}');
      }
      
      // Update the specific property
      final device = _devicesByMacAddress[macKey]![cameraIndex];
      print('Updating device: $device with property: $property');
      
      // Handle different properties
      switch (property) {
        case 'xAddrs':
          device.xAddrs = value.toString();
          print('Updated xAddrs to: ${device.xAddrs}');
          break;
        case 'username':
          device.username = value.toString();
          print('Updated username to: ${device.username}');
          break;
        case 'password':
          device.password = value.toString();
          print('Updated password to: ${device.password}');
          break;
        case 'manufacturer':
          device.manufacturer = value.toString();
          print('Updated manufacturer to: ${device.manufacturer}');
          break;
        case 'ipv4':
          device.ipv4 = value.toString();
          print('Updated IPv4 to: ${device.ipv4}');
          break;
        case 'model':
          device.brand = value.toString(); // Using brand field for model value
          print('Updated brand/model to: ${device.brand}');
          break;
        case 'mediaUri':
          device.mediaUri = value.toString();
          print('Updated mediaUri to: ${device.mediaUri}');
          break;
        case 'recordUri':
          device.recordUri = value.toString();
          print('Updated recordUri to: ${device.recordUri}');
          break;
        case 'subUri':
          device.subUri = value.toString();
          print('Updated subUri to: ${device.subUri}');
          break;
        case 'remoteUri':
          device.remoteUri = value.toString();
          print('Updated remoteUri to: ${device.remoteUri}');
          break;
        case 'subSnapShot':
          device.subSnapShot = value.toString();
          print('Updated subSnapShot to: ${device.subSnapShot}');
          break;
        case 'mainSnapShot':
          device.mainSnapShot = value.toString();
          print('Updated mainSnapShot to: ${device.mainSnapShot}');
          break;
        case 'cameraRawIp':
          device.cameraRawIp = value.toString();
          print('Updated cameraRawIp to: ${device.cameraRawIp}');
          break;
        case 'recordPath':
          device.recordPath = value.toString();
          print('Updated recordPath to: ${device.recordPath}');
          break;
        case 'country':
          device.country = value.toString();
          print('Updated country to: ${device.country}');
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
  
  // Update connection status for a specific device
  void updateDeviceConnectionStatus(String macAddress, bool isConnected) {
    try {
      print('Updating connection status for MAC: $macAddress to: $isConnected');
      
      // Find the device by MAC address
      final macKey = _convertAddressToMacKey(macAddress);
      
      if (_devicesByMacAddress.containsKey(macKey)) {
        for (final device in _devicesByMacAddress[macKey]!) {
          device.isConnected = isConnected;
          print('Updated connection status for device: $device');
        }
        notifyListeners();
      } else {
        print('Device with MAC $macAddress not found');
      }
    } catch (e) {
      print('Error updating connection status: $e');
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
  
  // Clear all devices
  void clearDevices() {
    print('Clearing all devices');
    _devicesByMacAddress.clear();
    notifyListeners();
  }
}
