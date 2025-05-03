import 'dart:convert';
// import 'dart:math'; // Unused import removed
import 'dart:async';

import 'package:flutter/foundation.dart';
// import 'package:universal_io/io.dart'; // Commented out - Target URI doesn't exist (dependency missing?)
import 'package:collection/collection.dart'; // Import for firstWhereOrNull

import '../models/camera_device.dart';
import '../utils/file_logger.dart';

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
  void processWebSocketMessage(Map<String, dynamic> message) async {
    // Check if message is valid for processing
    if (message['c'] == 'changed' && message.containsKey('data') && message.containsKey('val')) {
      final String dataPath = message['data'];
      final dynamic value = message['val'];
      
      // Kamera tespiti için pattern'ler
      final bool isCameraData = 
          // ecs_slaves.MAC.cam[INDEX] pattern
          dataPath.contains('cam[') || 
          // ecs_slaves.MAC.camreports pattern
          dataPath.contains('camreports') ||
          // Diğer olası kamera veri pattern'leri
          dataPath.contains('cameras.');
          
      // Eğer herhangi bir kamera verisi ile ilgili mesaj ise log at
      if (isCameraData) {
        // Kamera verisi bulundu - tam kamera mesajı olduğu anda log at
        await FileLogger.log('[CAM FOUND!] PATH: $dataPath, VALUE: $value', tag: 'CAMERA_FOUND');
        try {
          await FileLogger.log('[CAM RAW DATA] ${json.encode(message)}', tag: 'CAM_RAW_DATA');
        } catch (e) {
          await FileLogger.log('Error logging raw message data: $e', tag: 'LOGGING_ERROR');
        }
      }
      
      // Check if this is a camera device-related message
      if (dataPath.startsWith('ecs_slaves.m_')) {
        // Extract the MAC address from the data path
        // Format is like: ecs_slaves.m_26_C1_7A_0B_1F_19.property
        final parts = dataPath.split('.');
        if (parts.length >= 3) {
          final macKey = parts[1]; // Get m_26_C1_7A_0B_1F_19 (index changed from 2 to 1 after ecs_slaves format change)
          final macAddress = macKey.substring(2).replaceAll('_', ':'); // Convert to proper MAC format
          
          print('Extracted macKey: $macKey, macAddress: $macAddress');
          await FileLogger.log('Extracted macKey: $macKey, macAddress: $macAddress', tag: 'CAMERA_MAC');
          
          // Create the device if it doesn't exist yet
          if (!_devices.containsKey(macKey)) {
            print('Creating new device with macKey: $macKey');
            await FileLogger.log('Creating new device with macKey: $macKey', tag: 'CAMERA_NEW');
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
            await FileLogger.log('New device created: ${_devices[macKey].toString()}', tag: 'CAMERA_NEW');
          }

          // Get property path without the device part
          List<String> propertyPathParts = [];
          if (parts.length > 2) {
            propertyPathParts = parts.sublist(2);
          }
          
          // Log the property path parts for debugging
          await FileLogger.log('Property path parts: ${propertyPathParts.join(".")}, value: $value', tag: 'CAMERA_PROP');
          
          // Update the device property
          _updateDeviceProperty(macKey, propertyPathParts, value, message);
          
          // Notify listeners of the change
          notifyListeners();
        } else {
          await FileLogger.log('Invalid data path format: $dataPath, parts count: ${parts.length}', tag: 'CAMERA_ERROR');
        }
      }
    } else {
      // 2b. Log reason for skipping
      if (message['c'] != 'changed') {
        await FileLogger.log("Skipping message (type is not 'changed': ${message['c']}).", tag: 'CAMERA_INFO');
        await FileLogger.log('Not a changed message: ${message['c']}', tag: 'CAMERA_SKIP'); // Keep original skip log
      } else {
        await FileLogger.log("Skipping message (missing 'data' or 'val' fields).", tag: 'CAMERA_INFO');
        await FileLogger.log('Missing data or val fields in message', tag: 'CAMERA_ERROR'); // Keep original error log
      }
    }
  }

  void _updateDeviceProperty(String macKey, List<String> parts, dynamic value, Map<String, dynamic> fullMessage) async {
    try {
      // Get the device, handle potential null if key is invalid (shouldn't happen if called correctly)
      final CameraDevice? device = _devices[macKey];
      if (device == null) {
        await FileLogger.log('Attempted to update property for non-existent device: $macKey', tag: 'CAMERA_ERROR');
        return;
      }
      
      // Log the update attempt
      await FileLogger.log(
        'Camera property update - Device: $macKey, ' +
        'Property: ${parts.join('.')}, Value: $value', 
        tag: 'CAMERA_PROP_UPDATE'
      );
      
      // Simple device properties
      if (parts.isEmpty) {
        await FileLogger.log('Empty property parts for device: $macKey', tag: 'CAMERA_WARN');
        return; // Exit early if parts are empty
      }

      String propName = parts[0].toLowerCase();

      // Handle basic device properties
      if (propName == 'ipv4') {
        device.ipv4 = value.toString();
        await FileLogger.log('Set device $macKey ipv4 to: ${device.ipv4}', tag: 'DEVICE_PROP');
      } else if (propName == 'lastseenat' || propName == 'last_seen_at') { 
        device.lastSeenAt = value.toString();
        await FileLogger.log('Set device $macKey lastSeenAt to: ${device.lastSeenAt}', tag: 'DEVICE_PROP');
      } else if (propName == 'connected') {
        device.connected = value is bool ? value : (value.toString().toLowerCase() == 'true');
        await FileLogger.log('Set device $macKey connected to: ${device.connected}', tag: 'DEVICE_PROP');
      } else if (propName == 'uptime') {
        device.uptime = value.toString();
        await FileLogger.log('Set device $macKey uptime to: ${device.uptime}', tag: 'DEVICE_PROP');
      } else if (propName == 'devicetype') {
        device.deviceType = value.toString();
        await FileLogger.log('Set device $macKey deviceType to: ${device.deviceType}', tag: 'DEVICE_PROP');
      } else if (propName == 'firmwareversion') {
        device.firmwareVersion = value.toString();
        await FileLogger.log('Set device $macKey firmwareVersion to: ${device.firmwareVersion}', tag: 'DEVICE_PROP');
      } else if (propName == 'recordpath') {
        device.recordPath = value.toString();
        await FileLogger.log('Set device $macKey recordPath to: ${device.recordPath}', tag: 'DEVICE_PROP');
      }
      // Handle nested properties like 'system.cpuTemp'
      else if (propName == 'system' && parts.length > 1) {
        String systemProp = parts[1].toLowerCase();
        await FileLogger.log('Processing system property: $systemProp for device $macKey with value: $value', tag: 'SYSINFO');
        if (systemProp == 'cputemp') {
          // Potentially update a specific field if you add it to CameraDevice model
          await FileLogger.log('System CPU Temperature: $value', tag: 'CPU_TEMP');
        }
        // Add other system properties if needed
      }
      // Handle 'configuration' properties if they are structured (e.g., configuration.network.ip)
      else if (propName == 'configuration' && parts.length > 1) {
        String configPath = parts.sublist(1).join('.');
        await FileLogger.log('Processing configuration property: $configPath for device $macKey with value: $value', tag: 'CONFIG');
        // Potentially parse and store configuration details if needed
      }
      // Handle direct 'current_time' or 'cpuTemp' if sent at the device level
      else if (propName == 'current_time') {
        await FileLogger.log('Device $macKey current time: $value', tag: 'DEVICE_TIME');
        // Potentially update lastSeenAt or a dedicated field
        device.lastSeenAt = value.toString(); 
      } else if (propName == 'cputemp') {
        await FileLogger.log('Device $macKey CPU Temp: $value', tag: 'CPU_TEMP');
        // Potentially update a specific field
      }
      // Handle legacy 'cam[x].property' format
      else if (propName.startsWith('cam[') && propName.contains(']')) {
        // Extract the camera index from cam[x]
        String indexStr = propName.substring(4, propName.indexOf(']'));
        int cameraIdx = int.tryParse(indexStr) ?? -1;
        
        // Skip if we couldn't parse the camera index
        if (cameraIdx < 0) {
          await FileLogger.log('Invalid camera index in legacy format: $propName', tag: 'CAMERA_ERROR');
          return;
        }

        // Process the rest of the path if available
        if (parts.length >= 2) {
           List<String> cameraPropertyPath = parts.sublist(1);
          // Artık bu kısımda log atmıyoruz, tüm loglar processWebSocketMessage'da yapılıyor
          _updateCameraProperty(device, cameraIdx, cameraPropertyPath, value);
        } else {
          await FileLogger.log('Missing property path for legacy camera format: $propName', tag: 'CAMERA_WARN');
        }
      }
      // Camera specific properties, check if we got a cameras structure (legacy format)
      else if (propName == 'cameras' && parts.length >= 3) { 
        // Extract camera name (e.g., me8_b7_23_0c_12_4b or KAMERA76)
        String cameraName = parts[1];
        // Extract property path for the camera (e.g., ['status'] or ['config', 'resolution'])
        List<String> cameraPropertyPath = parts.sublist(2);

        // Find the camera by name in the device's list
        Camera? targetCamera;
        try {
          targetCamera = device.cameras.firstWhere((cam) => cam.name.toLowerCase() == cameraName.toLowerCase());
        } catch (e) {
          targetCamera = null; // Not found
        }

        // If camera not found, create it
        if (targetCamera == null) {
          await FileLogger.log('[CAM FOUND!] New camera "$cameraName" for device $macKey', tag: 'CAMERA_FOUND');
          await FileLogger.log('CAM RAW DATA: CameraName=$cameraName, Value=$value', tag: 'CAM_RAW_DATA');
          await FileLogger.log('Camera "$cameraName" not found for device $macKey. Creating new camera entry.', tag: 'CAMERA_NEW');
          targetCamera = Camera(
            index: device.cameras.length, // Assign next available index
            name: cameraName, 
            ip: '', // Default value
            rawIp: 0, // Default value
            username: '', // Default value
            password: '', // Default value
            brand: '', // Default value
            hw: '', // Default value
            manufacturer: '', // Default value
            country: '', // Default value
            xAddrs: '', // Default value
            mediaUri: '', // Default value
            recordUri: '', // Default value
            subUri: '', // Default value
            remoteUri: '', // Default value
            mainSnapShot: '', // Default value
            subSnapShot: '', // Default value
            recordPath: '', // Default value
            recordCodec: '', // Default value
            recordWidth: 0, // Default value
            recordHeight: 0, // Default value
            subCodec: '', // Default value
            subWidth: 0, // Default value
            subHeight: 0, // Default value
            connected: false, // Default value
            disconnected: '-', // Default value
            lastSeenAt: '', // Default value
            recording: false, // Default value
            soundRec: false, // Default value
            xAddr: '', // Default value
          );
          device.cameras.add(targetCamera);
          await FileLogger.log('Added new camera "$cameraName" to device $macKey.', tag: 'CAMERA_NEW');
          // Log the raw message that caused the new camera addition
          await FileLogger.log('Source message for new camera[$cameraName]: ${json.encode(fullMessage)}', tag: 'CAMERA_NEW_SOURCE');
        }
        
        // Update the property of the found or newly created camera
        _updateCameraPropertyByName(device, cameraName, cameraPropertyPath, value);

      }
      // Handle camera reports which might not follow the full path
      else if (parts.length >= 2 && parts[0] == 'camreports') {
        // Extract camera name and property path
        final String cameraName = parts[1];
        final List<String> cameraPropertyPath = parts.sublist(2);

        // Find the camera by NAME.
        var targetCamera = device.cameras.firstWhereOrNull((c) => c.name.toLowerCase() == cameraName.toLowerCase());

        if (targetCamera != null) {
          // If camera found by name, assign the property directly
          if (cameraPropertyPath.isNotEmpty) {
            final String propertyName = cameraPropertyPath[0];
            // Determine the actual value to assign (handle potential sub-properties if needed)
            final dynamic propertyValue = cameraPropertyPath.length > 1 
                ? { cameraPropertyPath.sublist(1).join('.'): value } // Handle nested properties if necessary
                : value;
                
            await FileLogger.log('Assigning property via camreports to camera "$cameraName": $propertyName = $propertyValue', tag: 'CAMERA_ASSIGN_REPORT');
            
            // Update known camera properties directly
            switch (propertyName) {
              case 'connected':
                targetCamera.connected = propertyValue is bool ? propertyValue : (propertyValue.toString().toLowerCase() == 'true');
                await FileLogger.log('Set camera ${targetCamera.name} connected to: ${targetCamera.connected}', tag: 'CAMERA_PROP');
                break;
              case 'recording':
                 targetCamera.recording = propertyValue is bool ? propertyValue : (propertyValue.toString().toLowerCase() == 'true');
                 await FileLogger.log('Set camera ${targetCamera.name} recording to: ${targetCamera.recording}', tag: 'CAMERA_PROP');
                break;
              // Add other properties from camreports if needed
              default:
                 await FileLogger.log('Unknown camera property via camreports: $propertyName for camera ${targetCamera.name}', tag: 'CAMERA_WARN');
            }
            
          } else {
            await FileLogger.log('Received update for camreports.$cameraName itself, but no specific property. Value: $value', tag: 'CAMERA_WARN');
          }
        } else {
          // If camera NOT found by name, DO NOT create a new one.
          // Log a warning that the report is for an unknown/unnamed camera.
          await FileLogger.log('Received camreport for unknown or not-yet-named camera "$cameraName" on device $macKey. Property: ${cameraPropertyPath.join('.')}, Value: $value. Ignoring.', tag: 'CAMERA_WARN');
        }
      }
      // Handle app specific properties (path starts with 'app.')
      else if (propName == 'app' && parts.length > 1) {
        String appProp = parts[1].toLowerCase();
        await FileLogger.log('Processing app property: $appProp for device $macKey with value: $value', tag: 'APP_INFO');
        // Handle app properties as needed
      } else {
        // Reverted: Log all unknown properties again
        await FileLogger.log('Unknown or unhandled device property for device $macKey: ${parts.join('.')}', tag: 'CAMERA_WARN');
      }
    } catch (e, stackTrace) {
      // Catch errors during property processing
      await FileLogger.log('Error processing property for device $macKey: ${parts.join('.')} = $value\nError: $e\nStackTrace: $stackTrace', tag: 'PROPERTY_ERROR');
    }
    
    // Notify listeners after processing any property update
    notifyListeners();
  }

  void _updateCameraPropertyByName(CameraDevice device, String cameraName, List<String> propertyPath, dynamic value) async {
    // Artık bu kısımda log atmıyoruz, tüm loglar processWebSocketMessage'da yapılıyor
    // Log the camera property update
    await FileLogger.log(
      'Camera property update - Device: ${device.macAddress}, Camera: $cameraName, ' +
      'Property: ${propertyPath.join('.')}, Value: $value', 
      tag: 'CAMERA_PROP_UPDATE'
    );
    
    // Find the camera by name
    Camera? targetCamera;
    try {
      targetCamera = device.cameras.firstWhere((cam) => cam.name.toLowerCase() == cameraName.toLowerCase());
    } catch (e) {
      targetCamera = null; // Not found
    }

    if (targetCamera == null) {
      await FileLogger.log('Camera "$cameraName" not found for device ${device.macAddress}. Cannot update property.', tag: 'CAMERA_ERROR');
      return;
    }
    
    // Extract the property name after cam[X]
    final propertyName = propertyPath.isNotEmpty ? propertyPath[0] : '';
    
    if (propertyName.isEmpty) {
      await FileLogger.log('Empty property name for camera[$cameraName]', tag: 'CAMERA_ERROR');
      return;
    }
    
    await FileLogger.log(
      'Updating camera[$cameraName] property: $propertyName, value: $value (${value.runtimeType})', 
      tag: 'CAMERA_PROP'
    );
    
    // Update the camera property based on name
    switch (propertyName) {
      case 'name':
        String oldName = targetCamera.name;
        targetCamera.name = value.toString();
        print('Set camera[$cameraName] name to: ${targetCamera.name}');
        await FileLogger.log('Set camera[$cameraName] name from "$oldName" to: "${targetCamera.name}"', tag: 'CAMERA_PROP');
        break;
      case 'cameraIp':
        targetCamera.ip = value.toString();
        await FileLogger.log('Set camera[$cameraName] IP to: ${targetCamera.ip}', tag: 'CAMERA_PROP');
        break;
      case 'cameraRawIp':
        targetCamera.rawIp = value is int ? value : int.tryParse(value.toString()) ?? 0;
        await FileLogger.log('Set camera[$cameraName] rawIp to: ${targetCamera.rawIp}', tag: 'CAMERA_PROP');
        break;
      case 'username':
        targetCamera.username = value.toString();
        await FileLogger.log('Set camera[$cameraName] username to: ${targetCamera.username}', tag: 'CAMERA_PROP');
        break;
      case 'password':
        targetCamera.password = value.toString();
        await FileLogger.log('Set camera[$cameraName] password to: [REDACTED]', tag: 'CAMERA_PROP');
        break;
      case 'brand':
        targetCamera.brand = value.toString();
        await FileLogger.log('Set camera[$cameraName] brand to: ${targetCamera.brand}', tag: 'CAMERA_PROP');
        break;
      case 'hw':
        targetCamera.hw = value.toString();
        await FileLogger.log('Set camera[$cameraName] hw to: ${targetCamera.hw}', tag: 'CAMERA_PROP');
        break;
      case 'manufacturer':
        targetCamera.manufacturer = value.toString();
        await FileLogger.log('Set camera[$cameraName] manufacturer to: ${targetCamera.manufacturer}', tag: 'CAMERA_PROP');
        break;
      case 'country':
        targetCamera.country = value.toString();
        await FileLogger.log('Set camera[$cameraName] country to: ${targetCamera.country}', tag: 'CAMERA_PROP');
        break;
      case 'xAddrs':
        targetCamera.xAddrs = value.toString();
        await FileLogger.log('Set camera[$cameraName] xAddrs to: ${targetCamera.xAddrs}', tag: 'CAMERA_PROP');
        break;
      case 'mediaUri':
        targetCamera.mediaUri = value.toString();
        await FileLogger.log('Set camera[$cameraName] mediaUri to: ${targetCamera.mediaUri}', tag: 'CAMERA_PROP');
        break;
      case 'recordUri':
        targetCamera.recordUri = value.toString();
        await FileLogger.log('Set camera[$cameraName] recordUri to: ${targetCamera.recordUri}', tag: 'CAMERA_PROP');
        break;
      case 'subUri':
        targetCamera.subUri = value.toString();
        await FileLogger.log('Set camera[$cameraName] subUri to: ${targetCamera.subUri}', tag: 'CAMERA_PROP');
        break;
      case 'remoteUri':
        targetCamera.remoteUri = value.toString();
        await FileLogger.log('Set camera[$cameraName] remoteUri to: ${targetCamera.remoteUri}', tag: 'CAMERA_PROP');
        break;
      case 'mainSnapShot':
        targetCamera.mainSnapShot = value.toString();
        await FileLogger.log('Set camera[$cameraName] mainSnapShot to: ${targetCamera.mainSnapShot}', tag: 'CAMERA_PROP');
        break;
      case 'subSnapShot':
        targetCamera.subSnapShot = value.toString();
        await FileLogger.log('Set camera[$cameraName] subSnapShot to: ${targetCamera.subSnapShot}', tag: 'CAMERA_PROP');
        break;
      case 'recordPath':
        targetCamera.recordPath = value.toString();
        await FileLogger.log('Set camera[$cameraName] recordPath to: ${targetCamera.recordPath}', tag: 'CAMERA_PROP');
        break;
      case 'recordcodec':
        targetCamera.recordCodec = value.toString();
        await FileLogger.log('Set camera[$cameraName] recordCodec to: ${targetCamera.recordCodec}', tag: 'CAMERA_PROP');
        break;
      case 'recordwidth':
        targetCamera.recordWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
        await FileLogger.log('Set camera[$cameraName] recordWidth to: ${targetCamera.recordWidth}', tag: 'CAMERA_PROP');
        break;
      case 'recordheight':
        targetCamera.recordHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
        await FileLogger.log('Set camera[$cameraName] recordHeight to: ${targetCamera.recordHeight}', tag: 'CAMERA_PROP');
        break;
      case 'subcodec':
        targetCamera.subCodec = value.toString();
        await FileLogger.log('Set camera[$cameraName] subCodec to: ${targetCamera.subCodec}', tag: 'CAMERA_PROP');
        break;
      case 'subwidth':
        targetCamera.subWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
        await FileLogger.log('Set camera[$cameraName] subWidth to: ${targetCamera.subWidth}', tag: 'CAMERA_PROP');
        break;
      case 'subheight':
        targetCamera.subHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
        await FileLogger.log('Set camera[$cameraName] subHeight to: ${targetCamera.subHeight}', tag: 'CAMERA_PROP');
        break;
      default:
        await FileLogger.log('Unknown camera property: $propertyName', tag: 'CAMERA_WARN');
    }
    
    // After updating a property, log the updated camera state
    if (propertyName == 'name' || propertyName == 'ip' || propertyName == 'brand') {
      await FileLogger.log(
        'Current camera[$cameraName] state - Name: "${targetCamera.name}", IP: ${targetCamera.ip}, ' +
        'Brand: ${targetCamera.brand}, Connected: ${targetCamera.connected}',
        tag: 'CAMERA_STATE'
      );
    }
  }

  void _updateCameraProperty(CameraDevice device, int cameraIndex, List<String> propertyPath, dynamic value) async {
    // Artık bu kısımda log atmıyoruz, tüm loglar processWebSocketMessage'da yapılıyor
    // Log the camera property update
    await FileLogger.log(
      'Camera property update - Device: ${device.macAddress}, Camera: $cameraIndex, ' +
      'Property: ${propertyPath.join('.')}, Value: $value', 
      tag: 'CAMERA_PROP_UPDATE'
    );
    
    // Ensure we have enough cameras in the array
    while (device.cameras.length <= cameraIndex) {
      int nextIndex = device.cameras.length;
      print('Creating camera at index $nextIndex because we need index $cameraIndex');
      await FileLogger.log('Creating camera at index $nextIndex because we need index $cameraIndex', tag: 'CAMERA_NEW');
      
      device.cameras.add(Camera(
        index: nextIndex,
        name: 'Camera ${nextIndex + 1}',
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
        disconnected: '-',
        lastSeenAt: '',
        recording: false,
      ));
      
      await FileLogger.log('New camera created with default properties', tag: 'CAMERA_NEW');
      // Artık burada log atmıyoruz
    }
    
    final camera = device.cameras[cameraIndex];
    
    // Extract the property name after cam[X]
    final propertyName = propertyPath.isNotEmpty ? propertyPath[0] : '';
    
    if (propertyName.isEmpty) {
      await FileLogger.log('Empty property name for camera[$cameraIndex]', tag: 'CAMERA_ERROR');
      return;
    }
    
    await FileLogger.log(
      'Updating camera[$cameraIndex] property: $propertyName, value: $value (${value.runtimeType})', 
      tag: 'CAMERA_PROP'
    );
    
    // Update the camera property based on name
    switch (propertyName) {
      case 'name':
        String oldName = camera.name;
        camera.name = value.toString();
        print('Set camera[$cameraIndex] name to: ${camera.name}');
        await FileLogger.log('Set camera[$cameraIndex] name from "$oldName" to: "${camera.name}"', tag: 'CAMERA_PROP');
        break;
      case 'cameraIp':
        camera.ip = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] IP to: ${camera.ip}', tag: 'CAMERA_PROP');
        break;
      case 'cameraRawIp':
        camera.rawIp = value is int ? value : int.tryParse(value.toString()) ?? 0;
        await FileLogger.log('Set camera[$cameraIndex] rawIp to: ${camera.rawIp}', tag: 'CAMERA_PROP');
        break;
      case 'username':
        camera.username = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] username to: ${camera.username}', tag: 'CAMERA_PROP');
        break;
      case 'password':
        camera.password = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] password to: [REDACTED]', tag: 'CAMERA_PROP');
        break;
      case 'brand':
        camera.brand = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] brand to: ${camera.brand}', tag: 'CAMERA_PROP');
        break;
      case 'hw':
        camera.hw = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] hw to: ${camera.hw}', tag: 'CAMERA_PROP');
        break;
      case 'manufacturer':
        camera.manufacturer = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] manufacturer to: ${camera.manufacturer}', tag: 'CAMERA_PROP');
        break;
      case 'country':
        camera.country = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] country to: ${camera.country}', tag: 'CAMERA_PROP');
        break;
      case 'xAddrs':
        camera.xAddrs = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] xAddrs to: ${camera.xAddrs}', tag: 'CAMERA_PROP');
        break;
      case 'mediaUri':
        camera.mediaUri = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] mediaUri to: ${camera.mediaUri}', tag: 'CAMERA_PROP');
        break;
      case 'recordUri':
        camera.recordUri = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] recordUri to: ${camera.recordUri}', tag: 'CAMERA_PROP');
        break;
      case 'subUri':
        camera.subUri = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] subUri to: ${camera.subUri}', tag: 'CAMERA_PROP');
        break;
      case 'remoteUri':
        camera.remoteUri = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] remoteUri to: ${camera.remoteUri}', tag: 'CAMERA_PROP');
        break;
      case 'mainSnapShot':
        camera.mainSnapShot = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] mainSnapShot to: ${camera.mainSnapShot}', tag: 'CAMERA_PROP');
        break;
      case 'subSnapShot':
        camera.subSnapShot = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] subSnapShot to: ${camera.subSnapShot}', tag: 'CAMERA_PROP');
        break;
      case 'recordPath':
        camera.recordPath = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] recordPath to: ${camera.recordPath}', tag: 'CAMERA_PROP');
        break;
      case 'recordcodec':
        camera.recordCodec = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] recordCodec to: ${camera.recordCodec}', tag: 'CAMERA_PROP');
        break;
      case 'recordwidth':
        camera.recordWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
        await FileLogger.log('Set camera[$cameraIndex] recordWidth to: ${camera.recordWidth}', tag: 'CAMERA_PROP');
        break;
      case 'recordheight':
        camera.recordHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
        await FileLogger.log('Set camera[$cameraIndex] recordHeight to: ${camera.recordHeight}', tag: 'CAMERA_PROP');
        break;
      case 'subcodec':
        camera.subCodec = value.toString();
        await FileLogger.log('Set camera[$cameraIndex] subCodec to: ${camera.subCodec}', tag: 'CAMERA_PROP');
        break;
      case 'subwidth':
        camera.subWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
        await FileLogger.log('Set camera[$cameraIndex] subWidth to: ${camera.subWidth}', tag: 'CAMERA_PROP');
        break;
      case 'subheight':
        camera.subHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
        await FileLogger.log('Set camera[$cameraIndex] subHeight to: ${camera.subHeight}', tag: 'CAMERA_PROP');
        break;
      default:
        await FileLogger.log('Unknown camera property: $propertyName', tag: 'CAMERA_WARN');
    }
    
    // After updating a property, log the updated camera state
    if (propertyName == 'name' || propertyName == 'ip' || propertyName == 'brand') {
      await FileLogger.log(
        'Current camera[$cameraIndex] state - Name: "${camera.name}", IP: ${camera.ip}, ' +
        'Brand: ${camera.brand}, Connected: ${camera.connected}',
        tag: 'CAMERA_STATE'
      );
    }
  }

  // Ek bilgi güncelleyici (camreports)
  Future<void> _updateCameraReportProperty(Camera camera, List<String> propertyPath, dynamic value) async {
    // Burada camreports ile gelen ek bilgiler kameraya işlenir
    // Örneğin: camreports[$i].health, camreports[$i].temperature gibi
    if (propertyPath.isEmpty) return;
    final propertyName = propertyPath[0];
    switch (propertyName) {
      case 'health':
        camera.health = value.toString();
        await FileLogger.log('Set camera[${camera.name}] health to: ${camera.health}', tag: 'CAMERA_REPORT');
        break;
      case 'temperature':
        camera.temperature = value is num ? (value as num).toDouble() : double.tryParse(value.toString()) ?? 0.0;
        await FileLogger.log('Set camera[${camera.name}] temperature to: ${camera.temperature}', tag: 'CAMERA_REPORT');
        break;
      // Diğer camreports özellikleri buraya eklenebilir
      default:
        await FileLogger.log('Unknown camreports property: $propertyName', tag: 'CAMERA_REPORT_WARN');
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
