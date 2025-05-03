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
      if (dataPath.startsWith('ecs_slaves.')) {
        // Extract the MAC address from the data path
        // Format is like: ecs_slaves.$mac_address.property
        final parts = dataPath.split('.');
        if (parts.length >= 2) {
          final macKey = parts[1]; // Get the mac address part
          final macAddress = macKey.startsWith('m_') ? macKey.substring(2).replaceAll('_', ':') : macKey; // Handle both formats
          
          // Yeni cihaz oluştur ve sadece önemli bilgiyi logla
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
            await FileLogger.log('New device created with macKey: $macKey', tag: 'CAMERA_NEW');
          }

          // Get property path without the device part
          List<String> propertyPathParts = [];
          if (parts.length > 2) {
            propertyPathParts = parts.sublist(2);
          }
          
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
    // Parse all the device-level properties as listed in requirements
    if (propName == 'ipv4') {
      device.ipv4 = value.toString();
      await FileLogger.log('Set device $macKey ipv4 to: ${device.ipv4}', tag: 'DEVICE_PROP');
    } else if (propName == 'ipv6') {
      // Assuming you want to add ipv6 to the device model
      await FileLogger.log('Device ipv6: $value - Not storing this value currently', tag: 'DEVICE_PROP');
    } else if (propName == 'lastseenat' || propName == 'last_seen_at') { 
      device.lastSeenAt = value.toString();
      await FileLogger.log('Set device $macKey lastSeenAt to: ${device.lastSeenAt}', tag: 'DEVICE_PROP');
    } else if (propName == 'connected') {
      device.connected = value is bool ? value : (value.toString().toLowerCase() == 'true');
      await FileLogger.log('Set device $macKey connected to: ${device.connected}', tag: 'DEVICE_PROP');
    } else if (propName == 'firsttime') {
      // Could add this to your device model if needed
      await FileLogger.log('Device firsttime: $value - Not storing this value currently', tag: 'DEVICE_PROP');
    } else if (propName == 'name') {
      // You might want to add a name property to your CameraDevice model
      await FileLogger.log('Device name: $value - Not storing this value currently', tag: 'DEVICE_PROP');
    } else if (propName == 'current_time') {
      // This is the device's current time
      await FileLogger.log('Device current_time: $value - Not storing this value currently', tag: 'DEVICE_PROP');
    } else if (propName == 'version') {
      device.firmwareVersion = value.toString();
      await FileLogger.log('Set device $macKey version/firmwareVersion to: ${device.firmwareVersion}', tag: 'DEVICE_PROP');
    } else if (propName == 'smartweb_version') {
      // Add to model if needed
      await FileLogger.log('Device smartweb_version: $value - Not storing this value currently', tag: 'DEVICE_PROP');
    } else if (propName == 'cputemp') {
      // Add cpuTemp to CameraDevice model if needed
      await FileLogger.log('Device cpuTemp: $value - Not storing this value currently', tag: 'DEVICE_PROP');
    } else if (propName == 'uptime') {
      device.uptime = value.toString();
      await FileLogger.log('Set device $macKey uptime to: ${device.uptime}', tag: 'DEVICE_PROP');
    } else if (propName == 'ismaster' || propName == 'is_master') {
      // Add to model if needed
      await FileLogger.log('Device isMaster: $value - Not storing this value currently', tag: 'DEVICE_PROP');
    } else if (propName == 'last_ts') {
      // Add to model if needed
      await FileLogger.log('Device last_ts: $value - Not storing this value currently', tag: 'DEVICE_PROP');
    } else if (propName == 'online') {
      // This might be redundant with 'connected' but could be stored separately
      final bool isOnline = value is bool ? value : (value.toString().toLowerCase() == 'true');
      await FileLogger.log('Device online: $isOnline - Treating as connected status', tag: 'DEVICE_PROP');
      device.connected = isOnline; // Use online status as connected status
    } else if (propName == 'app_ready') {
      // App readiness status
      await FileLogger.log('Device app_ready: $value - Not storing this value currently', tag: 'DEVICE_PROP'); 
    } else if (propName == 'system_ready') {
      // System readiness status
      await FileLogger.log('Device system_ready: $value - Not storing this value currently', tag: 'DEVICE_PROP');
    } else if (propName == 'cam_ready') {
      // Camera subsystem readiness
      await FileLogger.log('Device cam_ready: $value - Not storing this value currently', tag: 'DEVICE_PROP');
    } else if (propName == 'configuration_ready') {
      // Configuration subsystem readiness
      await FileLogger.log('Device configuration_ready: $value - Not storing this value currently', tag: 'DEVICE_PROP');
    } else if (propName == 'camreports_ready') {
      // Camera reports readiness
      await FileLogger.log('Device camreports_ready: $value - Not storing this value currently', tag: 'DEVICE_PROP');
    } else if (propName == 'movita_ready') {
      // Movita subsystem readiness
      await FileLogger.log('Device movita_ready: $value - Not storing this value currently', tag: 'DEVICE_PROP');
    } else if (propName == 'cam_count') {
      // Number of cameras - useful for validation
      int camCount = value is int ? value : int.tryParse(value.toString()) ?? 0;
      await FileLogger.log('Device cam_count: $camCount - Validating against actual camera count: ${device.cameras.length}', tag: 'DEVICE_PROP');
    } else if (propName == 'devicetype') {
      device.deviceType = value.toString();
      await FileLogger.log('Set device $macKey deviceType to: ${device.deviceType}', tag: 'DEVICE_PROP');
    } else if (propName == 'recordpath') {
      device.recordPath = value.toString();
      await FileLogger.log('Set device $macKey recordPath to: ${device.recordPath}', tag: 'DEVICE_PROP');
    }
      // Handle sysinfo properties (ecs_slaves.$mac_address.sysinfo.*)
      else if (propName == 'sysinfo' && parts.length > 1) {
        String sysinfoProp = parts[1].toLowerCase();
        // Önemli sistem özellikleri logu kaldırıldı
        
        // Parse all the system info properties you specified
        if (sysinfoProp == 'cputemp') {
          // Store CPU temperature
          await FileLogger.log('System CPU Temperature: $value', tag: 'CPU_TEMP');
        } else if (sysinfoProp == 'uptime') {
          // Update uptime from sysinfo
          device.uptime = value.toString();
          await FileLogger.log('Set device $macKey uptime to: ${device.uptime} from sysinfo', tag: 'DEVICE_PROP');
        } else if (sysinfoProp == 'srvtime') {
          await FileLogger.log('System server time: $value', tag: 'SYSINFO');
        } else if (sysinfoProp == 'totalram') {
          await FileLogger.log('System total RAM: $value', tag: 'SYSINFO');
        } else if (sysinfoProp == 'freeram') {
          await FileLogger.log('System free RAM: $value', tag: 'SYSINFO');
        } else if (sysinfoProp == 'totalconns') {
          await FileLogger.log('System total connections: $value', tag: 'SYSINFO');
        } else if (sysinfoProp == 'sessions') {
          await FileLogger.log('System sessions: $value', tag: 'SYSINFO');
        } else if (sysinfoProp == 'eth0') {
          await FileLogger.log('System eth0 network info: $value', tag: 'SYSINFO');
        } else if (sysinfoProp == 'ppp0') {
          await FileLogger.log('System ppp0 network info: $value', tag: 'SYSINFO');
        } else if (sysinfoProp == 'thermal[0].soc-thermal' || sysinfoProp.startsWith('thermal[0]')) {
          await FileLogger.log('System SOC thermal: $value', tag: 'SYSINFO');
        } else if (sysinfoProp == 'thermal[1].gpu-thermal' || sysinfoProp.startsWith('thermal[1]')) {
          await FileLogger.log('System GPU thermal: $value', tag: 'SYSINFO');
        } else if (sysinfoProp == 'gps.lat' || (sysinfoProp == 'gps' && parts.length > 2 && parts[2] == 'lat')) {
          await FileLogger.log('System GPS latitude: $value', tag: 'SYSINFO');
        } else if (sysinfoProp == 'gps.lon' || (sysinfoProp == 'gps' && parts.length > 2 && parts[2] == 'lon')) {
          await FileLogger.log('System GPS longitude: $value', tag: 'SYSINFO');
        } else if (sysinfoProp == 'gps.speed' || (sysinfoProp == 'gps' && parts.length > 2 && parts[2] == 'speed')) {
          await FileLogger.log('System GPS speed: $value', tag: 'SYSINFO');
        } else {
          // Log other sysinfo properties
          await FileLogger.log('Unhandled sysinfo property: $sysinfoProp with value: $value', tag: 'SYSINFO');
        }
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
      // Handle 'cam[$index].*' property format (ecs_slaves.$mac_address.cam[$index].property)
      else if (propName.startsWith('cam[') && propName.contains(']')) {
        // Extract the camera index from cam[x]
        String indexStr = propName.substring(4, propName.indexOf(']'));
        int cameraIdx = int.tryParse(indexStr) ?? -1;
        
        // Skip if we couldn't parse the camera index
        if (cameraIdx < 0) {
          await FileLogger.log('Invalid camera index format: $propName', tag: 'CAMERA_ERROR');
          return;
        }
        
        // Kamera özelliği işleme logu kaldırıldı

        // Process the rest of the path if available
        if (parts.length >= 2) {
          List<String> cameraPropertyPath = parts.sublist(1);
          // Process all camera properties as specified in requirements
          _updateCameraProperty(device, cameraIdx, cameraPropertyPath, value);
        } else {
          await FileLogger.log('Missing property path for camera: $propName', tag: 'CAMERA_WARN');
        }
      }
      // Skip cameras structure - per requirements, we don't parse ecs_slaves.$mac_address.cameras
      else if (propName == 'cameras') {
        // Atlanan veri yolu logu kaldırıldı
      }
      // Handle camera reports (ecs_slaves.$mac_address.camreports.$name.*) format
      else if (propName == 'camreports' && parts.length >= 2) {
        // Extract camera name and property path
        final String cameraName = parts[1];
        final List<String> cameraPropertyPath = parts.length > 2 ? parts.sublist(2) : [];

        // Find the camera by NAME.
        var targetCamera = device.cameras.firstWhereOrNull((c) => c.name.toLowerCase() == cameraName.toLowerCase());

        if (targetCamera != null) {
          // If camera found by name, assign the property directly
          if (cameraPropertyPath.isNotEmpty) {
            final String propertyName = cameraPropertyPath[0].toLowerCase();
            final dynamic propertyValue = value;
                
            // Kamera raporu işleme logu kaldırıldı
            
            // Update camera report properties based on the specification
            switch (propertyName) {
              case 'connected':
                targetCamera.connected = propertyValue is bool ? propertyValue : (propertyValue.toString().toLowerCase() == 'true');
                await FileLogger.log('Set camera ${targetCamera.name} connected to: ${targetCamera.connected}', tag: 'CAMERA_PROP');
                break;
              case 'disconnected':
                targetCamera.disconnected = propertyValue.toString();
                await FileLogger.log('Set camera ${targetCamera.name} disconnected to: ${targetCamera.disconnected}', tag: 'CAMERA_PROP');
                break;
              case 'last_seen_at':
                targetCamera.lastSeenAt = propertyValue.toString();
                await FileLogger.log('Set camera ${targetCamera.name} lastSeenAt to: ${targetCamera.lastSeenAt}', tag: 'CAMERA_PROP');
                break;
              case 'recording':
                targetCamera.recording = propertyValue is bool ? propertyValue : (propertyValue.toString().toLowerCase() == 'true');
                await FileLogger.log('Set camera ${targetCamera.name} recording to: ${targetCamera.recording}', tag: 'CAMERA_PROP');
                break;
              case 'last_restart_time':
                // Add this property to the Camera model if needed
                await FileLogger.log('Camera ${targetCamera.name} last_restart_time: $propertyValue - Not storing this value currently', tag: 'CAMERA_PROP');
                break;
              case 'reported':
                // Add this property to the Camera model if needed
                await FileLogger.log('Camera ${targetCamera.name} reported: $propertyValue - Not storing this value currently', tag: 'CAMERA_PROP');
                break;
              default:
                await FileLogger.log('Unknown camera report property: $propertyName for camera ${targetCamera.name}', tag: 'CAMERA_WARN');
                break;
            }
          } else {
            // Handle the case where cameraPropertyPath is empty
            await FileLogger.log('Received camreports.$cameraName with no specific property. Value: $value', tag: 'CAMERA_REPORT');
          }
        } else {
          // If camera NOT found by name, DO NOT create a new one.
          // Log a warning that the report is for an unknown/unnamed camera.
          await FileLogger.log('Received camreport for unknown camera "$cameraName" on device $macKey. Property: ${cameraPropertyPath.join('.')}, Value: $value. Ignoring.', tag: 'CAMERA_WARN');
        }
      }
      // Skip app properties - per requirements
      else if (propName == 'app') {
        // Atlanan veri yolu logu kaldırıldı
      }
      // Skip system properties - per requirements 
      else if (propName == 'system') {
        // Atlanan veri yolu logu kaldırıldı
      }
      // Skip configuration properties - per requirements
      else if (propName == 'configuration') {
        // Atlanan veri yolu logu kaldırıldı
      }
      // Skip movita properties - per requirements
      else if (propName == 'movita') {
        // Atlanan veri yolu logu kaldırıldı
      }
      // Skip test.error properties - per requirements
      else if (propName == 'test' && parts.length > 1 && parts[1] == 'error') {
        // Atlanan veri yolu logu kaldırıldı
      }
      // Skip test.is_error properties - per requirements
      else if (propName == 'test' && parts.length > 1 && parts[1] == 'is_error') {
        // Atlanan veri yolu logu kaldırıldı
      }
      else {
        // Log all other unknown properties
        await FileLogger.log('Unknown or unhandled device property for device $macKey: ${parts.join('.')}', tag: 'PROPERTY_WARN');
      }
    } catch (e, stackTrace) {
      // Catch errors during property processing
      await FileLogger.log('Error processing property for device $macKey: ${parts.join('.')} = $value\nError: $e\nStackTrace: $stackTrace', tag: 'PROPERTY_ERROR');
    }
    
    // Notify listeners after processing any property update
    notifyListeners();
  }

  // _updateCameraPropertyByName method removed as it's no longer used

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
      await FileLogger.log('Creating camera at index $nextIndex', tag: 'CAMERA_NEW');
      
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
