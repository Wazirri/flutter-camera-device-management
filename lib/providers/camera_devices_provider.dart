import 'dart:convert';
import 'package:flutter/foundation.dart';
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
    if (message['c'] == 'changed' && message.containsKey('data') && message.containsKey('val')) {
      final String dataPath = message['data'];
      final dynamic value = message['val'];
      
      // Debugging log the message
      print('Processing WebSocket message: ${json.encode(message)}');
      await FileLogger.log('Processing camera device message: $dataPath = $value', tag: 'CAMERA_PROC');
      
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
          _updateDeviceProperty(macKey, propertyPathParts, value);
          
          // Notify listeners of the change
          notifyListeners();
        } else {
          await FileLogger.log('Invalid data path format: $dataPath, parts count: ${parts.length}', tag: 'CAMERA_ERROR');
        }
      }
    } else {
      // Log non-changed messages or ones missing data/val
      if (message['c'] != 'changed') {
        await FileLogger.log('Not a changed message: ${message['c']}', tag: 'CAMERA_SKIP');
      } else {
        await FileLogger.log('Missing data or val fields in message', tag: 'CAMERA_ERROR');
      }
    }
  }

  void _updateDeviceProperty(String macKey, List<String> parts, dynamic value) async {
    try {
      // Get the device, handle potential null if key is invalid (shouldn't happen if called correctly)
      final CameraDevice? device = _devices[macKey];
      if (device == null) {
        await FileLogger.log('Attempted to update property for non-existent device: $macKey', tag: 'CAMERA_ERROR');
        return;
      }
      
      // Log the update attempt
      await FileLogger.logCameraPropertyUpdate(
        macKey: macKey,
        property: parts.isEmpty ? 'empty_property' : parts.join('.'),
        value: value,
        dataPath: 'ecs_slaves.$macKey.${parts.join('.')}'  
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
      } else if (propName == 'lastseenat') {
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
          _updateCameraProperty(device, cameraIdx, cameraPropertyPath, value);
        } else {
          await FileLogger.log('Missing property path for legacy camera format: $propName', tag: 'CAMERA_WARN');
        }
      }
      // Camera specific properties, check if we got a cameras structure (legacy format)
      else if (propName == 'cameras' && parts.length >= 2) {
        // Ensure there is a device associated with this macKey
        // Note: device is guaranteed non-null here due to check at start of function
        // var device = _devices[macKey]!; // Device already fetched at the start
        await FileLogger.log('Received camera list payload for device: ${device.macAddress}', tag: 'CAMERA_PAYLOAD');
        try {
          _updateCameraData(device, value); // Call the dedicated function
        } catch (e, stackTrace) {
          await FileLogger.log('Error updating camera data for device ${device.macAddress}: $e\nStackTrace: $stackTrace\nPayload: $value', tag: 'CAMERA_ERROR');
        }
        notifyListeners(); // Notify after potential camera list update
      }
      // Handle camreport (singular) and camreports (plural) formats
      else if((propName == 'camreport' || propName == 'camreports') && parts.length >= 3) {
        String cameraName = parts[1].toLowerCase();
        String reportProperty = parts[2].toLowerCase();
        
        await FileLogger.log('Processing camera report for device $macKey: Camera Name=$cameraName, Property=$reportProperty, Value=$value', tag: 'CAMERA_REPORT');
        
        // Find the camera with matching name (case insensitive)
        int cameraIndex = device.cameras.indexWhere((cam) => cam.name.toLowerCase() == cameraName);
        
        if(cameraIndex >= 0) {
          // Update the specific property based on the report
          // Example: update connection status, recording status etc.
          var camera = device.cameras[cameraIndex];
          if (reportProperty == 'connected') {
            camera.connected = value is bool ? value : (value.toString().toLowerCase() == 'true');
            await FileLogger.log('Updated camera[$cameraIndex] (${camera.name}) connected status via report: ${camera.connected}', tag: 'CAMERA_REPORT');
          } else if (reportProperty == 'recording') {
            camera.recording = value is bool ? value : (value.toString().toLowerCase() == 'true');
             await FileLogger.log('Updated camera[$cameraIndex] (${camera.name}) recording status via report: ${camera.recording}', tag: 'CAMERA_REPORT');
          } else {
            await FileLogger.log('Unknown camera report property: $reportProperty for camera $cameraName', tag: 'CAMERA_WARN');
          }
        } else {
          await FileLogger.log('Warning: Received camera report for unknown camera name: $cameraName on device $macKey. Ignoring.', tag: 'CAMERA_ERROR');
          await FileLogger.log('Device cameras: ${device.cameras.map((c) => c.name).join(', ')}', tag: 'CAMERA_ERROR');
        }
      } else {
        await FileLogger.log('Unknown or unhandled device property for device $macKey: ${parts.join('.')}', tag: 'CAMERA_WARN');
      }
    } catch (e, stackTrace) {
      // Catch errors during property processing
      await FileLogger.log('Error processing property for device $macKey: ${parts.join('.')} = $value\nError: $e\nStackTrace: $stackTrace', tag: 'PROPERTY_ERROR');
    }
    
    // Notify listeners after processing any property update
    notifyListeners();
  }

  void _updateCameraProperty(CameraDevice device, int cameraIndex, List<String> propertyPath, dynamic value) async {
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
      
      await FileLogger.log('New camera created with default properties', tag: 'CAMERA_NEW');
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

  void _updateCameraData(CameraDevice device, dynamic payload) async {
    try {
      if (payload is List) {
        // Log the camera data with details
        await FileLogger.log('Updating cameras for device ${device.macAddress}. Received ${payload.length} cameras', tag: 'CAMERA_INFO');
        await FileLogger.log('Camera payload: ${jsonEncode(payload)}', tag: 'CAMERA_PAYLOAD');

        List<Camera> newCameras = [];

        // Create new cameras from payload
        for (var i = 0; i < payload.length; i++) {
          var cameraData = payload[i];
          if (cameraData != null && cameraData is Map<String, dynamic>) {
            try {
              // Inject the index into the data before parsing
              cameraData['index'] = i;
              await FileLogger.log('Processing camera data for index $i on device ${device.macAddress}: ${jsonEncode(cameraData)}', tag: 'CAMERA_UPDATE');
              newCameras.add(Camera.fromJson(cameraData));
            } catch (e, stackTrace) {
              await FileLogger.log('Error parsing camera data at index $i for device ${device.macAddress}: $e\nStackTrace: $stackTrace\nData: $cameraData', tag: 'CAMERA_ERROR');
              // Optionally add a placeholder or skip
            }
          } else {
            await FileLogger.log('Invalid or null camera data format at index $i on device ${device.macAddress}: $cameraData (${cameraData?.runtimeType})', tag: 'CAMERA_ERROR');
          }
        }

        // Atomically update the device's camera list
        device.cameras = newCameras;

        // Log final camera count
        await FileLogger.log('Device ${device.macAddress} now has ${device.cameras.length} cameras: ${device.cameras.map((c) => 'Camera(${c.index}:${c.name})').join(', ')}', tag: 'CAMERA_RESULT');
        
        // Ensure UI updates after camera data changes
        // notifyListeners(); // Moved notification to the caller (_updateDeviceProperty)

      } else {
        await FileLogger.log('Invalid camera data format for device ${device.macAddress}. Expected List but got: ${payload.runtimeType}\nPayload: $payload', tag: 'CAMERA_ERROR');
      }
    } catch (e, stackTrace) {
      await FileLogger.log('Error updating camera data for device ${device.macAddress}: $e\nStackTrace: $stackTrace\nPayload: $payload', tag: 'CAMERA_ERROR');
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
