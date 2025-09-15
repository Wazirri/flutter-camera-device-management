import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/camera_device.dart'; // Corrected import path
import '../models/camera_group.dart';

enum MessageCategory {
  camera,
  cameraReport,
  systemInfo,
  appConfig,
  testData,
  configuration,
  basicProperty,
  cameraGroupAssignment,
  cameraGroupDefinition,
  unknown
}

class CameraDevicesProviderOptimized with ChangeNotifier {
  final Map<String, CameraDevice> _devices = {}; // Parent devices, keyed by their canonical MAC
  final Map<String, Camera> _macDefinedCameras = {}; // Master list of cameras, keyed by their own MAC
  final Map<String, CameraGroup> _cameraGroups = {};
  List<CameraGroup>? _cachedGroupsList;
  CameraDevice? _selectedDevice;
  int _selectedCameraIndex = 0;
  bool _isLoading = false;
  String? _selectedGroupName;

  // Camera name to device mapping for faster lookups
  final Map<String, String> _cameraNameToDeviceMap = {};

  // Batch notifications to reduce UI rebuilds
  bool _needsNotification = false;
  Timer? _notificationDebounceTimer;
  final int _notificationBatchWindow = 100; // milliseconds - reduced for faster status updates
  
  // Cache variables to avoid redundant processing
  List<CameraDevice>? _cachedDevicesList;
  List<Camera>? _cachedFlatCameraList; // Cache for the main camera list
  final Map<String, bool> _processedMessages = {};
  final int _maxProcessedMessageCache = 500;

  // Public getters
  Map<String, CameraDevice> get devices => _devices; // Access to parent devices

  List<CameraDevice> get devicesList {
    _cachedDevicesList ??= _devices.values.toList();
    return _cachedDevicesList!;
  }

  // The primary list of all unique cameras
  List<Camera> get cameras {
    _cachedFlatCameraList ??= _macDefinedCameras.values.toList();
    return _cachedFlatCameraList!;
  }
  
  int get selectedCameraIndex => _selectedCameraIndex;
  bool get isLoading => _isLoading;
  
  // Camera groups getters
  Map<String, CameraGroup> get cameraGroups => _cameraGroups;
  List<CameraGroup> get groupsList {
    _cachedGroupsList ??= _cameraGroups.values.toList();
    return _cachedGroupsList!;
  }
  List<CameraGroup> get cameraGroupsList {
    _cachedGroupsList ??= _cameraGroups.values.toList();
    return _cachedGroupsList!;
  }
  String? get selectedGroupName => _selectedGroupName;
  CameraGroup? get selectedGroup => _selectedGroupName != null ? _cameraGroups[_selectedGroupName] : null;
  CameraDevice? get selectedDevice => _selectedDevice;
  
  // Get all cameras as a flat list
  List<Camera> get allCameras {
    return _macDefinedCameras.values.toList();
  }

  // Legacy API compatibility - devicesByMacAddress
  Map<String, CameraDevice> get devicesByMacAddress => _devices;

  // Legacy API compatibility - getDeviceForCamera
  CameraDevice? getDeviceForCamera(Camera camera) {
    return findDeviceForCamera(camera);
  }

  // Legacy API compatibility - preloadDevicesData (no-op for WebSocket version)
  void preloadDevicesData() {
    // WebSocket version doesn't need preloading
    print('CDP_OPT: preloadDevicesData called - no action needed for WebSocket version');
  }
  
  // Get or create camera
  Camera _getOrCreateMacDefinedCamera(String cameraMac) {
    if (!_macDefinedCameras.containsKey(cameraMac)) {
      _macDefinedCameras[cameraMac] = Camera(
        mac: cameraMac,
        name: '',
        ip: '',
        index: -1, // Will be set when device assigns it
        connected: false,
        isPlaceholder: false, // DÜZELTME: Artık placeholder mantığı kullanmıyoruz
      );
      _cachedFlatCameraList = null; // Invalidate cache
    }
    return _macDefinedCameras[cameraMac]!;
  }

  // Find the device that contains a specific camera
  CameraDevice? findDeviceForCamera(Camera camera) {
    print('CDP_OPT: Looking for device for camera: ${camera.mac} (name: ${camera.name}, index: ${camera.index})');
    
    for (var entry in _devices.entries) {
      CameraDevice device = entry.value;
      
      // First try to find by MAC
      for (var deviceCamera in device.cameras) {
        if (deviceCamera.mac == camera.mac && deviceCamera.mac.isNotEmpty) {
          print('CDP_OPT: Found device for camera ${camera.mac}: ${device.macAddress} (${device.ipv4})');
          return device;
        }
      }
      
      // If MAC is empty or not found, try to find by index
      for (var deviceCamera in device.cameras) {
        if (deviceCamera.index == camera.index && camera.index >= 0) {
          print('CDP_OPT: Found device for camera by index ${camera.index}: ${device.macAddress} (${device.ipv4})');
          return device;
        }
      }
    }
    
    print('CDP_OPT: No device found for camera: ${camera.mac} (name: ${camera.name}, index: ${camera.index})');
    print('CDP_OPT: Available devices: ${_devices.keys.toList()}');
    for (var entry in _devices.entries) {
      print('CDP_OPT: Device ${entry.key}: ${entry.value.cameras.map((c) => '${c.mac}(${c.name})').toList()}');
    }
    
    return null;
  }
  
  // Get device MAC for a camera
  String? getDeviceMacForCamera(Camera camera) {
    for (var entry in _devices.entries) {
      String macKey = entry.key;
      CameraDevice device = entry.value;
      
      if (device.cameras.any((c) => c.index == camera.index)) {
        return macKey;
      }
    }
    return null;
  }
  
  // Set selected device
  void selectDevice(String macKey, {int cameraIndex = 0}) {
    if (_devices.containsKey(macKey)) {
      _selectedDevice = _devices[macKey];
      _selectedCameraIndex = cameraIndex;
      _batchNotifyListeners();
    }
  }
  
  // Legacy API compatibility - setSelectedDevice
  void setSelectedDevice(String macKey) {
    selectDevice(macKey);
  }
  
  // Legacy API compatibility - setSelectedCameraIndex
  void setSelectedCameraIndex(int index) {
    if (_selectedDevice != null) {
      _selectedCameraIndex = index;
      _batchNotifyListeners();
    }
  }
  
  // Select a group
  void selectGroup(String groupName) {
    if (_cameraGroups.containsKey(groupName)) {
      _selectedGroupName = groupName;
      _batchNotifyListeners();
    }
  }
  
  // Get cameras in a group
  List<Camera> getCamerasInGroup(String groupName) {
    if (!_cameraGroups.containsKey(groupName)) {
      return [];
    }
    
    final group = _cameraGroups[groupName]!;
    return group.cameraMacs
        .map((mac) => _macDefinedCameras[mac])
        .where((camera) => camera != null)
        .cast<Camera>()
        .toList();
  }

  // Add or remove camera from a group
  void addCameraToGroup(String cameraMac, String groupName) {
    if (!_cameraGroups.containsKey(groupName)) {
      _cameraGroups[groupName] = CameraGroup(name: groupName, cameraMacs: []);
      _cachedGroupsList = null;
    }
    
    if (!_cameraGroups[groupName]!.cameraMacs.contains(cameraMac)) {
      _cameraGroups[groupName]!.cameraMacs.add(cameraMac);
      _batchNotifyListeners();
    }
  }

  void removeCameraFromGroup(String cameraMac, String groupName) {
    if (_cameraGroups.containsKey(groupName)) {
      _cameraGroups[groupName]!.cameraMacs.remove(cameraMac);
      if (_cameraGroups[groupName]!.cameraMacs.isEmpty) {
        _cameraGroups.remove(groupName);
        _cachedGroupsList = null;
      }
      _batchNotifyListeners();
    }
  }

  void createGroup(String groupName) {
    if (!_cameraGroups.containsKey(groupName) && groupName.isNotEmpty) {
      _cameraGroups[groupName] = CameraGroup(name: groupName, cameraMacs: []);
      _cachedGroupsList = null;
      _batchNotifyListeners();
    }
  }

  void deleteGroup(String groupName) {
    if (_cameraGroups.containsKey(groupName)) {
      _cameraGroups.remove(groupName);
      _cachedGroupsList = null;
      if (_selectedGroupName == groupName) {
        _selectedGroupName = null;
      }
      _batchNotifyListeners();
    }
  }

  // Reset all data (for login/logout)
  void resetData() {
    _devices.clear();
    _macDefinedCameras.clear();
    _cameraGroups.clear();
    _selectedDevice = null;
    _selectedCameraIndex = 0;
    _selectedGroupName = null;
    _isLoading = false;
    _cameraNameToDeviceMap.clear();
    _processedMessages.clear();
    
    // Clear caches
    _cachedDevicesList = null;
    _cachedFlatCameraList = null;
    _cachedGroupsList = null;
    
    _batchNotifyListeners();
  }

  // Set loading state
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      _batchNotifyListeners();
    }
  }

  // Update MAC-defined camera property
  Future<void> _updateMacDefinedCameraProperty(Camera camera, List<String> parts, dynamic value) async {
    String propertyName = parts[2];
    print('CDP_OPT: *** CAMERAS_MAC: Processing ${parts[2]} for camera ${camera.mac} = $value ***');
    
    // Handle group assignment
    if (parts.length >= 4 && parts[2] == 'group') {
      try {
        String groupIndexPart = parts[3]; // group[0], group[1], etc.
        if (groupIndexPart.startsWith('group[') && groupIndexPart.endsWith(']')) {
          int groupIndex = int.parse(groupIndexPart.substring(6, groupIndexPart.length - 1));
          String groupValue = value.toString();
          
          // Ensure the camera has enough group slots
          while (camera.groups.length <= groupIndex) {
            camera.groups.add('');
          }
          
          camera.groups[groupIndex] = groupValue;
          print('CDP_OPT: Camera ${camera.mac} group at index $groupIndex updated to "$groupValue". Groups: ${camera.groups}');
          
          // Update the global group structure if this group name is new
          _ensureGroupExists(groupValue);
        }
      } catch (e) {
        print('CDP_OPT: Error parsing group index from ${parts[3]}: $e');
      }
      _batchNotifyListeners();
      return;
    }

    // Handle simple properties
    switch (propertyName.toLowerCase()) {
      // Specific to cameras_mac - MAC-level metadata
      case 'detected': camera.macFirstSeen = value.toString(); break;
      case 'firsttime': camera.macFirstSeen = value.toString(); break;
      case 'lastdetected': camera.macLastDetected = value.toString(); break;
      case 'port': camera.macPort = value is int ? value : int.tryParse(value.toString()); break;
      case 'error': camera.macReportedError = value.toString(); break;
      case 'status': camera.macStatus = value.toString(); break;
      case 'seen': camera.lastSeenAt = value.toString(); break;
      
      // General camera properties that can also be set by cameras_mac
      case 'name': 
        camera.name = value.toString(); 
        break;
      case 'cameraip': // Assuming 'cameraip' from cameras_mac maps to general 'ip'
        camera.ip = value.toString();
        break;
      case 'brand': camera.brand = value.toString(); break;
      case 'hw': camera.hw = value.toString(); break;
      case 'manufacturer': camera.manufacturer = value.toString(); break;
      case 'country': camera.country = value.toString(); break;
      case 'mainsnapshot': camera.mainSnapShot = value.toString(); break;
      case 'subsnapshot': camera.subSnapShot = value.toString(); break;
      case 'mediauri': camera.mediaUri = value.toString(); break;
      case 'recorduri': camera.recordUri = value.toString(); break;
      case 'suburi': camera.subUri = value.toString(); break;
      case 'remoteuri': camera.remoteUri = value.toString(); break;
      case 'username': camera.username = value.toString(); break;
      case 'password': camera.password = value.toString(); break;
      case 'recordcodec': camera.recordCodec = value.toString(); break;
      case 'recordwidth': camera.recordWidth = value is int ? value : int.tryParse(value.toString()) ?? 0; break;
      case 'recordheight': camera.recordHeight = value is int ? value : int.tryParse(value.toString()) ?? 0; break;
      case 'subcodec': camera.subCodec = value.toString(); break;
      case 'subwidth': camera.subWidth = value is int ? value : int.tryParse(value.toString()) ?? 0; break;
      case 'subheight': camera.subHeight = value is int ? value : int.tryParse(value.toString()) ?? 0; break;
      case 'camerarawip': camera.rawIp = value is int ? value : int.tryParse(value.toString()) ?? 0; break;
      case 'soundrec': camera.soundRec = value == true || value.toString().toLowerCase() == 'true'; break;
      case 'recordpath': camera.recordPath = value.toString(); break;
      case 'xaddr': camera.xAddr = value.toString(); break;
      
      // 'connected' from cameras_mac might indicate the camera's own reported connection status
      case 'connected': camera.connected = value == 1 || value == true || value.toString().toLowerCase() == 'true'; break;
      
      // 'record' from cameras_mac
      case 'record': camera.recording = value == true || value.toString().toLowerCase() == 'true'; break;
      
      default:
        print('CDP_OPT: Unhandled MAC-defined camera property: $propertyName for camera ${camera.mac}');
        break;
    }
    
    _batchNotifyListeners();
  }

  // Add or update camera in device list
  void _addOrUpdateCameraInDeviceList(CameraDevice device, int cameraIndex, Camera cameraToAdd) {
    cameraToAdd.index = cameraIndex; // Set the device-specific index
    cameraToAdd.parentDeviceMacKey = device.macKey; // Use the original macKey from path for the device
    
    // Remove any camera with the same index but different MAC (in case of MAC reassignment)
    device.cameras.removeWhere((c) => c.index == cameraIndex && c.mac != cameraToAdd.mac);
    
    // Remove any camera with the same MAC but different index (in case of index reassignment)
    device.cameras.removeWhere((c) => c.mac == cameraToAdd.mac && c.index != cameraIndex);
    
    // Add or update the camera
    if (!device.cameras.any((c) => c.mac == cameraToAdd.mac && c.index == cameraIndex)) {
      device.cameras.add(cameraToAdd);
      print('CDP_OPT: Added camera ${cameraToAdd.mac} (${cameraToAdd.name}) to device ${device.macKey} at index $cameraIndex');
    }
    
    // Sort cameras by index for consistent ordering
    device.cameras.sort((a, b) => a.index.compareTo(b.index));
    
    // Invalidate caches
    _cachedDevicesList = null;
  }

  // Process WebSocket message
  Future<void> processWebSocketMessage(Map<String, dynamic> message) async {
    try {
      String command = message['c'] ?? '';
      
      // Handle sysinfo messages
      if (command == 'sysinfo') {
        await _processSysInfoMessage(message);
        return;
      }
      
      // Handle changed messages
      if (command != 'changed') return;
      
      String dataPath = message['data'] ?? '';
      dynamic value = message['val'];
      
      // Skip duplicate messages
      String messageKey = '${dataPath}_${value.toString()}';
      if (_processedMessages.containsKey(messageKey)) {
        return;
      }
      _processedMessages[messageKey] = true;
      
      // Cleanup old processed messages to prevent memory leaks
      if (_processedMessages.length > _maxProcessedMessageCache) {
        _processedMessages.remove(_processedMessages.keys.first);
      }

      if (dataPath.startsWith('cameras_mac.')) {
        final parts = dataPath.split('.'); // cameras_mac.CAMERA_MAC.property or cameras_mac.CAMERA_MAC.group[0]
        if (parts.length >= 3) {
          final cameraMac = parts[1]; // This is the camera's own MAC address
          if (cameraMac.isNotEmpty) {
            print('CDP_OPT: *** CAMERAS_MAC: Processing ${parts[2]} for camera $cameraMac = $value ***');
            final camera = _getOrCreateMacDefinedCamera(cameraMac);
            await _updateMacDefinedCameraProperty(camera, parts, value);
            print('CDP_OPT: *** MAC-defined camera count: ${_macDefinedCameras.length} ***');
          } else {
            print('CDP_OPT: Received cameras_mac message with empty camera MAC in path: $dataPath');
          }
        } else {
          print('CDP_OPT: Invalid cameras_mac path: $dataPath');
        }
        return; // Message handled
      }
      
      if (!dataPath.startsWith('ecs_slaves.')) {
        return;
      }
      
      final parts = dataPath.split('.');
      if (parts.length < 2) {
        print('CDP_OPT: Path too short, skipping: $dataPath');
        return;
      }
      
      String pathDeviceIdentifier = parts[1];
      String canonicalDeviceMac = pathDeviceIdentifier.replaceAll('_', ':').substring(2);
      
      final device = _getOrCreateDevice(canonicalDeviceMac, pathDeviceIdentifier);
      
      if (parts.length < 3) {
        print('CDP_OPT: Path too short for device property, skipping: $dataPath');
        return;
      }
      
      // Determine message category and process accordingly
      String pathComponent = parts[2];
      List<String> remainingPath = parts.sublist(3);
      MessageCategory category = _categorizeMessage(pathComponent, remainingPath);
      
      switch (category) {
        case MessageCategory.camera:
          if (remainingPath.isNotEmpty) {
            await _processCameraData(device, pathComponent, remainingPath, value);
          } else {
            print('CDP_OPT: Camera message but no property specified: $dataPath');
          }
          // and calls _batchNotifyListeners() and returns.
          break;
        case MessageCategory.basicProperty:
          await _processBasicDeviceProperty(device, pathComponent, value);
          _batchNotifyListeners();
          break;
        case MessageCategory.systemInfo:
          await _processSystemInfo(device, pathComponent, remainingPath, value);
          _batchNotifyListeners();
          break;
        case MessageCategory.appConfig:
          await _processAppConfig(device, pathComponent, remainingPath, value);
          _batchNotifyListeners();
          break;
        case MessageCategory.testData:
          await _processTestData(device, pathComponent, remainingPath, value);
          _batchNotifyListeners();
          break;
        case MessageCategory.configuration:
          await _processConfiguration(device, pathComponent, remainingPath, value);
          break;
        case MessageCategory.cameraGroupDefinition:
          await _processCameraGroupDefinition(device, pathComponent, remainingPath, value);
          break;
        case MessageCategory.cameraGroupAssignment:
          await _processCameraGroupAssignment(device, pathComponent, remainingPath, value);
          break;
        case MessageCategory.cameraReport:
          await _processCameraReport(device, pathComponent, remainingPath, value);
          _batchNotifyListeners();
          break;
        default:
          print('CDP_OPT: Unhandled message category for: $dataPath');
      }
    } catch (e, s) {
      print('CDP_OPT: Error processing WebSocket message: $e\\n$s. Message: $message');
    }
  }
  
  // Categorize messages
  MessageCategory _categorizeMessage(String pathComponent, List<String> remainingPath) {
    // Common basic device properties should always be treated as basic properties
    if (pathComponent == 'online' || 
        pathComponent == 'connected' ||
        pathComponent == 'firsttime' || 
        pathComponent == 'current_time' ||
        pathComponent == 'name' ||
        pathComponent == 'version' ||
        pathComponent == 'smartweb_version' ||
        pathComponent == 'cpuTemp' ||
        pathComponent == 'ipv4' ||
        pathComponent == 'ipv6' ||
        pathComponent == 'last_seen_at' ||
        pathComponent == 'isMaster' ||
        pathComponent == 'last_ts' ||
        pathComponent == 'cam_count' ||
        
        // Ready states from device_info.json
        pathComponent == 'app_ready' ||
        pathComponent == 'system_ready' ||
        pathComponent == 'programs_ready' ||
        pathComponent == 'cam_ready' ||
        pathComponent == 'configuration_ready' ||
        pathComponent == 'camreports_ready' ||
        pathComponent == 'movita_ready' ||
        
        // Device status fields
        pathComponent == 'registered' ||
        pathComponent == 'app_version' ||
        pathComponent == 'system_count' ||
        pathComponent == 'camreports_count' ||
        pathComponent == 'programs_count' ||
        pathComponent == 'is_closed_by_master' ||
        pathComponent == 'last_heartbeat_ts' ||
        pathComponent == 'offline_since') {
      print('Detected basic device property: $pathComponent');
      return MessageCategory.basicProperty;
    }
    
    // Group definition special case
    if (pathComponent == 'configuration' && remainingPath.isNotEmpty && 
        remainingPath[0].startsWith('cameraGroups')) {
      return MessageCategory.cameraGroupDefinition;
    }
    
    // Camera group assignment
    if (pathComponent.startsWith('cam') && remainingPath.isNotEmpty && 
        remainingPath.contains('group')) {
      return MessageCategory.cameraGroupAssignment;
    }
    
    // Other categories
    if (pathComponent.startsWith('cam') && pathComponent != 'camreports') {
      return MessageCategory.camera;
    } else if (pathComponent == 'camreports') {
      return MessageCategory.cameraReport;
    } else if (pathComponent == 'configuration') {
      return MessageCategory.configuration;
    } else if (pathComponent == 'system' || pathComponent == 'cpuTemp' || pathComponent.contains('version')) {
      return MessageCategory.systemInfo;
    } else if (pathComponent == 'sysinfo') {
      return MessageCategory.systemInfo;
    } else if (pathComponent == 'app') {
      return MessageCategory.appConfig;
    } else if (pathComponent == 'test') {
      return MessageCategory.testData;
    } else {
      return MessageCategory.basicProperty; 
    }
  }
  
  // Get or create device
  CameraDevice _getOrCreateDevice(String canonicalDeviceMac, String originalPathMacKey) {
    if (!_devices.containsKey(canonicalDeviceMac)) {
      print('CDP_OPT: *** Creating new device: $canonicalDeviceMac (pathKey: $originalPathMacKey) ***');
      _devices[canonicalDeviceMac] = CameraDevice(
        macAddress: canonicalDeviceMac,
        macKey: originalPathMacKey, // Store the original key from path
        ipv4: '',
        lastSeenAt: '',
        connected: false,
        online: false,
        firstTime: '',
        uptime: '',
        deviceType: '',
        firmwareVersion: '',
        recordPath: '',
        cameras: [],
      );
      _cachedDevicesList = null;
    }
    return _devices[canonicalDeviceMac]!;
  }
  
  // Refactored _processCameraData
  Future<void> _processCameraData(CameraDevice device, String camIndexPath, List<String> camPathProperties, dynamic value) async {
    // camIndexPath is "cam[0]", camPathProperties is ["name"] or ["status", "power"] etc.
    String indexStr = camIndexPath.substring(4, camIndexPath.indexOf(']'));
    int cameraIndex = int.tryParse(indexStr) ?? -1;
    
    if (cameraIndex < 0) {
      print('CDP_OPT: Invalid camera index: $camIndexPath');
      return;
    }

    String propertyName = camPathProperties.first;
    print('CDP_OPT: Processing ecs_slaves data: Device ${device.macAddress}, cam[$cameraIndex].$propertyName = $value');

    Camera? cameraToUpdate;

    if (propertyName == 'mac') { // This is the camera's own MAC address from ecs_slaves path
      String cameraMacFromMessage = value.toString();
      print('CDP_OPT: *** MAC ASSIGNMENT: Device ${device.macKey} cam[$cameraIndex].mac = "$cameraMacFromMessage" ***');
      if (cameraMacFromMessage.isNotEmpty) {
        cameraToUpdate = _getOrCreateMacDefinedCamera(cameraMacFromMessage);
        // Link this MAC-defined camera to the parent device and its index
        _addOrUpdateCameraInDeviceList(device, cameraIndex, cameraToUpdate);
        print('CDP_OPT: *** Successfully linked camera ${cameraToUpdate.mac} to device ${device.macKey} at index $cameraIndex ***');
        print('CDP_OPT: *** Device ${device.macKey} now has ${device.cameras.length} cameras ***');
      } else {
        print('CDP_OPT: *** ERROR: Received empty MAC for cam[$cameraIndex] on device ${device.macAddress}. Cannot link or update. ***');
        return; 
      }
    } else {
      // For other properties (name, ip, etc.), find the camera already associated with this device and index
      // It should have been linked previously by a 'mac' property message.
      var camsInDevice = device.cameras.where((cam) => cam.index == cameraIndex).toList();
      if (camsInDevice.isNotEmpty) {
        cameraToUpdate = camsInDevice.first; // Should ideally be only one
        if (camsInDevice.length > 1) {
            print("CDP_OPT: WARNING - Multiple cameras found for device ${device.macKey} at index $cameraIndex. Using first: ${cameraToUpdate.mac}. All: ${camsInDevice.map((c)=>c.mac).join(',')}");
        }
      } else {
        // DÜZELTME: MAC adresi olmayan kameralar için gerçek kamera yarat
        // Bu kameralar placeholder değil, sadece MAC adresi henüz atanmamış
        String tempMac = "${device.macKey}_cam_$cameraIndex"; // Geçici tanımlayıcı
        print('CDP_OPT: *** Creating camera without MAC for device ${device.macKey} at cam[$cameraIndex] (property: $propertyName) ***');
        
        cameraToUpdate = _getOrCreateMacDefinedCamera(tempMac);
        cameraToUpdate.name = "Kamera $cameraIndex"; // Varsayılan isim
        cameraToUpdate.isPlaceholder = false; // Bu gerçek bir kamera, sadece MAC yok
        _addOrUpdateCameraInDeviceList(device, cameraIndex, cameraToUpdate);
        print('CDP_OPT: *** Camera without MAC created with temp ID: $tempMac ***');
      }
    }

    // Now update the identified cameraToUpdate with the property from ecs_slaves
    // Update property values
    switch (propertyName.toLowerCase()) {
      case 'name': 
        cameraToUpdate.name = value.toString(); 
        break;
      case 'ip':
      case 'cameraip':
        cameraToUpdate.ip = value.toString();
        break;
      case 'connected':
        cameraToUpdate.connected = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'brand':
        cameraToUpdate.brand = value.toString();
        break;
      case 'hw':
        cameraToUpdate.hw = value.toString();
        break;
      case 'manufacturer':
        cameraToUpdate.manufacturer = value.toString();
        break;
      case 'country':
        cameraToUpdate.country = value.toString();
        break;
      case 'mainsnapshot':
        cameraToUpdate.mainSnapShot = value.toString();
        break;
      case 'subsnapshot':
        cameraToUpdate.subSnapShot = value.toString();
        break;
      case 'mediauri':
        cameraToUpdate.mediaUri = value.toString();
        break;
      case 'recorduri':
        cameraToUpdate.recordUri = value.toString();
        break;
      case 'suburi':
        cameraToUpdate.subUri = value.toString();
        break;
      case 'remoteuri':
        cameraToUpdate.remoteUri = value.toString();
        break;
      case 'username':
        cameraToUpdate.username = value.toString();
        break;
      case 'password':
        cameraToUpdate.password = value.toString();
        break;
      case 'recordcodec':
        cameraToUpdate.recordCodec = value.toString();
        break;
      case 'recordwidth':
        cameraToUpdate.recordWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'recordheight':
        cameraToUpdate.recordHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'subcodec':
        cameraToUpdate.subCodec = value.toString();
        break;
      case 'subwidth':
        cameraToUpdate.subWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'subheight':
        cameraToUpdate.subHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'camerarawip':
        cameraToUpdate.rawIp = value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'soundrec':
        cameraToUpdate.soundRec = value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'recordpath':
        cameraToUpdate.recordPath = value.toString();
        break;
      case 'xaddr':
        cameraToUpdate.xAddr = value.toString();
        break;
      default:
        print('CDP_OPT: Unhandled ecs_slaves camera property: $propertyName');
        break;
    }
    
    _batchNotifyListeners();
  }

  // Process basic device properties
  Future<void> _processBasicDeviceProperty(CameraDevice device, String property, dynamic value) async {
    switch (property.toLowerCase()) {
      case 'online':
        device.online = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'connected':
        device.connected = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'firsttime':
        device.firstTime = value.toString();
        break;
      case 'current_time':
        device.currentTime = value.toString();
        break;
      case 'ipv4':
        device.ipv4 = value.toString();
        break;
      case 'last_seen':
        device.lastSeenAt = value.toString();
        break;
      case 'last_seen_at':
        device.lastSeenAt = value.toString();
        print('CDP_OPT: Device ${device.macAddress} last_seen_at updated: ${device.lastSeenAt}');
        break;
      case 'last_heartbeat_ts':
        device.lastHeartbeatTs = int.tryParse(value.toString()) ?? 0;
        print('CDP_OPT: Device ${device.macAddress} last_heartbeat_ts updated: $value');
        break;
      case 'uptime':
        device.uptime = value.toString();
        break;
      case 'device_type':
        device.deviceType = value.toString();
        break;
      case 'firmware_version':
      case 'version':
        device.firmwareVersion = value.toString();
        break;
      case 'record_path':
        device.recordPath = value.toString();
        break;
      case 'cputemp':
        device.cpuTemp = double.tryParse(value.toString()) ?? 0.0;
        print('CDP_OPT: Device ${device.macAddress} cpuTemp updated: ${device.cpuTemp}');
        break;
      case 'totalram':
        device.totalRam = int.tryParse(value.toString()) ?? 0;
        print('CDP_OPT: Device ${device.macAddress} totalRam updated: ${device.totalRam}');
        break;
      case 'freeram':
        device.freeRam = int.tryParse(value.toString()) ?? 0;
        print('CDP_OPT: Device ${device.macAddress} freeRam updated: ${device.freeRam}');
        break;
      case 'totalconns':
        device.totalConnections = int.tryParse(value.toString()) ?? 0;
        print('CDP_OPT: Device ${device.macAddress} totalConnections updated: ${device.totalConnections}');
        break;
      case 'sessions':
        device.totalSessions = int.tryParse(value.toString()) ?? 0;
        print('CDP_OPT: Device ${device.macAddress} totalSessions updated: ${device.totalSessions}');
        break;
      case 'eth0':
        device.networkInfo = value.toString();
        print('CDP_OPT: Device ${device.macAddress} networkInfo updated: ${device.networkInfo}');
        break;
      case 'smartweb_version':
        device.smartwebVersion = value.toString();
        print('CDP_OPT: Device ${device.macAddress} smartwebVersion updated: ${device.smartwebVersion}');
        break;
      case 'cam_count':
        device.camCount = int.tryParse(value.toString()) ?? 0;
        print('CDP_OPT: Device ${device.macAddress} camCount updated: ${device.camCount}');
        break;
      case 'is_master':
      case 'ismaster':
        device.isMaster = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        print('CDP_OPT: Device ${device.macAddress} isMaster updated: ${device.isMaster}');
        break;
      case 'last_ts':
        device.lastTs = value.toString();
        print('CDP_OPT: Device ${device.macAddress} lastTs updated: ${device.lastTs}');
        break;
      case 'name':
        device.deviceName = value.toString();
        print('CDP_OPT: Device ${device.macAddress} name updated: ${device.deviceName}');
        break;
      case 'ipv6':
        device.ipv6 = value.toString();
        break;
        
      // Ready states from device_info.json
      case 'app_ready':
        device.appReady = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'system_ready':
        device.systemReady = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'programs_ready':
        device.programsReady = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'cam_ready':
        device.camReady = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'configuration_ready':
        device.configurationReady = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'camreports_ready':
        device.camreportsReady = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'movita_ready':
        device.movitaReady = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
        
      // Device status fields
      case 'registered':
        device.registered = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'app_version':
        device.appVersion = int.tryParse(value.toString()) ?? 0;
        break;
      case 'system_count':
        device.systemCount = int.tryParse(value.toString()) ?? 0;
        break;
      case 'camreports_count':
        device.camreportsCount = int.tryParse(value.toString()) ?? 0;
        break;
      case 'programs_count':
        device.programsCount = int.tryParse(value.toString()) ?? 0;
        break;
      case 'is_closed_by_master':
        device.isClosedByMaster = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'offline_since':
        device.offlineSince = int.tryParse(value.toString()) ?? 0;
        break;
        
      default:
        print('CDP_OPT: Unhandled basic device property: $property for device ${device.macAddress}');
        break;
    }
  }

  // Process system info
  Future<void> _processSystemInfo(CameraDevice device, String property, List<String> subPath, dynamic value) async {
    // Handle system information updates from device_info.json
    if (subPath.isEmpty) {
      print('CDP_OPT: System info update for ${device.macAddress}: $property = $value');
      return;
    }
    
    String systemProperty = subPath[0];
    switch (systemProperty.toLowerCase()) {
      case 'mac':
        device.systemMac = value.toString();
        break;
      case 'gateway':
        device.gateway = value.toString();
        break;
      case 'gpsok':
        device.gpsOk = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'ignition':
        device.ignition = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'internetexists':
        device.internetExists = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'ip':
        device.systemIp = value.toString();
        break;
      case 'bootcount':
        device.bootCount = int.tryParse(value.toString()) ?? 0;
        break;
      case 'diskfree':
        device.diskFree = value.toString();
        break;
      case 'diskrunning':
        device.diskRunning = value.toString();
        break;
      case 'emptysize':
        device.emptySize = int.tryParse(value.toString()) ?? 0;
        break;
      case 'recordsize':
        device.recordSize = int.tryParse(value.toString()) ?? 0;
        break;
      case 'recording':
        device.recording = int.tryParse(value.toString()) ?? 0;
        break;
      case 'shmc_ready':
        device.shmcReady = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'timeset':
        device.timeset = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'uykumodu':
        device.uykumodu = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      default:
        print('CDP_OPT: Unhandled system property: $systemProperty for device ${device.macAddress}');
        break;
    }
    print('CDP_OPT: System info update for ${device.macAddress}: $property.$systemProperty = $value');
  }

  // Process app config
  Future<void> _processAppConfig(CameraDevice device, String property, List<String> subPath, dynamic value) async {
    // Handle app configuration updates from device_info.json
    if (subPath.isEmpty) {
      print('CDP_OPT: App config update for ${device.macAddress}: $property = $value');
      return;
    }
    
    String appProperty = subPath[0];
    switch (appProperty.toLowerCase()) {
      case 'ip':
        // Could map to device IP or create a new field
        device.ipv4 = value.toString();
        break;
      case 'devicetype':
        device.appDeviceType = value.toString();
        break;
      case 'recordingduration':
        device.maxRecordDuration = int.tryParse(value.toString()) ?? 0;
        break;
      case 'recordpath':
        device.appRecordPath = value.toString();
        break;
      case 'recording':
        device.appRecording = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'group':
        device.group = int.tryParse(value.toString()) ?? 0;
        break;
      case 'firmwareversion':
        device.appFirmwareVersion = value.toString();
        break;
      case 'firmwaredate':
        device.firmwareDate = value.toString();
        break;
      case 'gps_data_flow_status':
      case 'gpsdataflowstatus':
        device.gpsDataFlowStatus = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'int_connection':
      case 'intconnection':
        device.intConnection = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'record_over_tcp':
      case 'recordovertcp':
        device.recordOverTcp = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'ppp':
        device.ppp = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'recording_cameras':
      case 'recordingcameras':
        device.recordingCameras = int.tryParse(value.toString()) ?? 0;
        break;
      case 'min_space_in_mbytes':
      case 'minspaceinmbytes':
        device.minSpaceInMBytes = int.tryParse(value.toString()) ?? 0;
        break;
      case 'restart_player_timeout':
      case 'restartplayertimeout':
        device.restartPlayerTimeout = int.tryParse(value.toString()) ?? 0;
        break;
      default:
        print('CDP_OPT: Unhandled app property: $appProperty for device ${device.macAddress}');
        break;
    }
    print('CDP_OPT: App config update for ${device.macAddress}: $property.$appProperty = $value');
  }

  // Process test data
  Future<void> _processTestData(CameraDevice device, String property, List<String> subPath, dynamic value) async {
    // Handle test data updates from device_info.json
    if (subPath.isEmpty) {
      print('CDP_OPT: Test data update for ${device.macAddress}: $property = $value');
      return;
    }
    
    String testProperty = subPath[0];
    switch (testProperty.toLowerCase()) {
      case 'connection_count':
      case 'connectioncount':
        device.testConnectionCount = int.tryParse(value.toString()) ?? 0;
        break;
      case 'connection_last_update':
      case 'connectionlastupdate':
        device.testConnectionLastUpdate = value.toString();
        break;
      case 'connection_error':
      case 'connectionerror':
        device.testConnectionError = int.tryParse(value.toString()) ?? 0;
        break;
      case 'kamera_baglanti_count':
      case 'kamerabaglanticount':
        device.testKameraBaglantiCount = int.tryParse(value.toString()) ?? 0;
        break;
      case 'kamera_baglanti_last_update':
      case 'kamerabagantilastupdate':
        device.testKameraBaglantiLastUpdate = value.toString();
        break;
      case 'kamera_baglanti_error':
      case 'kamerabaglatierror':
        device.testKameraBaglantiError = int.tryParse(value.toString()) ?? 0;
        break;
      case 'program_count':
      case 'programcount':
        device.testProgramCount = int.tryParse(value.toString()) ?? 0;
        break;
      case 'program_last_update':
      case 'programlastupdate':
        device.testProgramLastUpdate = value.toString();
        break;
      case 'program_error':
      case 'programerror':
        device.testProgramError = int.tryParse(value.toString()) ?? 0;
        break;
      case 'is_error':
      case 'iserror':
        device.testIsError = value == 1 || value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'uptime':
        device.testUptime = value.toString();
        break;
      default:
        print('CDP_OPT: Unhandled test property: $testProperty for device ${device.macAddress}');
        break;
    }
    print('CDP_OPT: Test data update for ${device.macAddress}: $property.$testProperty = $value');
  }

  // Process configuration
  Future<void> _processConfiguration(CameraDevice device, String property, List<String> subPath, dynamic value) async {
    // Handle configuration updates
    print('CDP_OPT: Configuration update for ${device.macAddress}: $property = $value');
  }

  // Process camera group definition
  Future<void> _processCameraGroupDefinition(CameraDevice device, String property, List<String> subPath, dynamic value) async {
    // Handle camera group definition updates
    print('CDP_OPT: Camera group definition update for ${device.macAddress}: $property = $value');
  }

  // Process camera group assignment
  Future<void> _processCameraGroupAssignment(CameraDevice device, String property, List<String> subPath, dynamic value) async {
    // Handle camera group assignment updates
    print('CDP_OPT: Camera group assignment update for ${device.macAddress}: $property = $value');
  }

  // Process camera report
  Future<void> _processCameraReport(CameraDevice device, String property, List<String> subPath, dynamic value) async {
    // Handle camera report updates
    print('CDP_OPT: Camera report update for ${device.macAddress}: $property = $value');
  }

  // Ensure group exists
  void _ensureGroupExists(String groupName) {
    // Create group if it doesn't exist
    if (!_cameraGroups.containsKey(groupName) && groupName.isNotEmpty) {
      _cameraGroups[groupName] = CameraGroup(
        name: groupName,
        cameraMacs: [],
      );
      _cachedGroupsList = null;
    }
  }
  
  // WebSocket'ten gelen CAM_GROUP_ADD komutunu işle
  void addGroupFromWebSocket(String groupName) {
    try {
      // Daha sıkı filtreleme: boş, null, sadece whitespace olanları reddet
      if (groupName.isEmpty || groupName.trim().isEmpty) {
        print("CDP_OPT: Ignoring empty or whitespace-only group name from WebSocket.");
        return;
      }
      
      // Çok kısa grup isimlerini de reddet
      if (groupName.trim().length < 2) {
        print("CDP_OPT: Ignoring too short group name from WebSocket: '$groupName'");
        return;
      }
      
      final String cleanGroupName = groupName.trim();
      
      // Grup zaten varsa, uyarı ver ama hata verme
      if (_cameraGroups.containsKey(cleanGroupName)) {
        print("CDP_OPT: Group '$cleanGroupName' already exists, skipping creation.");
        return;
      }
      
      // Yeni grup oluştur
      _cameraGroups[cleanGroupName] = CameraGroup(
        name: cleanGroupName,
        cameraMacs: [],
      );
      
      _cachedGroupsList = null; // Cache'i invalidate et
      _batchNotifyListeners();
      print("CDP_OPT: Successfully created new group from WebSocket: '$cleanGroupName'");
      
    } catch (e) {
      print("CDP_OPT: Error creating group from WebSocket: $e. Group name: '$groupName'");
    }
  }

  // Print device summary for debugging
  void _printDeviceSummary() {
    print('CDP_OPT: === DEVICE SUMMARY ===');
    print('CDP_OPT: Total devices: ${_devices.length}');
    print('CDP_OPT: MAC-defined cameras: ${_macDefinedCameras.length}');
    
    for (var entry in _devices.entries) {
      CameraDevice device = entry.value;
      print('CDP_OPT: Device ${device.macKey}: ${device.cameras.length} cameras');
      for (var camera in device.cameras) {
        String status = camera.mac.startsWith(device.macKey) ? 'NO_MAC' : 'HAS_MAC';
        print('CDP_OPT:   - Camera[${camera.index}]: ${camera.mac} (${camera.name}) [$status]');
      }
    }
    print('CDP_OPT: ======================');
  }

  // Batch notifications to reduce UI rebuilds
  void _batchNotifyListeners() {
    _needsNotification = true;
    
    // If a timer is already pending, do nothing
    if (_notificationDebounceTimer?.isActive ?? false) {
      return;
    }
    
    // Schedule a delayed notification
    _notificationDebounceTimer = Timer(Duration(milliseconds: _notificationBatchWindow), () {
      if (_needsNotification) {
        _needsNotification = false;
        _printDeviceSummary(); // Print summary before notifying UI
        notifyListeners();
      }
    });
  }
  
  // Process sysinfo message and assign to master device
  Future<void> _processSysInfoMessage(Map<String, dynamic> message) async {
    try {
      // Find the master device (isMaster = true)
      CameraDevice? masterDevice;
      for (CameraDevice device in _devices.values) {
        if (device.isMaster == true) {
          masterDevice = device;
          break;
        }
      }
      
      // If no master device found, try to find one by IP address matching eth0
      if (masterDevice == null && message.containsKey('eth0')) {
        String masterIp = message['eth0'].toString();
        for (CameraDevice device in _devices.values) {
          if (device.ipv4 == masterIp) {
            device.isMaster = true; // Mark it as master
            masterDevice = device;
            break;
          }
        }
      }
      
      // If still no master device, skip processing
      if (masterDevice == null) {
        print('CDP_OPT: No master device found for sysinfo message');
        return;
      }
      
      // Update master device system information
      if (message.containsKey('cpuTemp')) {
        masterDevice.cpuTemp = double.tryParse(message['cpuTemp'].toString()) ?? 0.0;
        print('CDP_OPT: Master device ${masterDevice.macAddress} cpuTemp updated: ${masterDevice.cpuTemp}');
      }
      
      if (message.containsKey('totalRam')) {
        masterDevice.totalRam = int.tryParse(message['totalRam'].toString()) ?? 0;
        print('CDP_OPT: Master device ${masterDevice.macAddress} totalRam updated: ${masterDevice.totalRam}');
      }
      
      if (message.containsKey('freeRam')) {
        masterDevice.freeRam = int.tryParse(message['freeRam'].toString()) ?? 0;
        print('CDP_OPT: Master device ${masterDevice.macAddress} freeRam updated: ${masterDevice.freeRam}');
      }
      
      if (message.containsKey('totalconns')) {
        masterDevice.totalConnections = int.tryParse(message['totalconns'].toString()) ?? 0;
        print('CDP_OPT: Master device ${masterDevice.macAddress} totalConnections updated: ${masterDevice.totalConnections}');
      }
      
      if (message.containsKey('sessions')) {
        masterDevice.totalSessions = int.tryParse(message['sessions'].toString()) ?? 0;
        print('CDP_OPT: Master device ${masterDevice.macAddress} totalSessions updated: ${masterDevice.totalSessions}');
      }
      
      if (message.containsKey('eth0')) {
        masterDevice.networkInfo = message['eth0'].toString();
        print('CDP_OPT: Master device ${masterDevice.macAddress} networkInfo updated: ${masterDevice.networkInfo}');
      }
      
      print('CDP_OPT: Master device ${masterDevice.macAddress} system info updated from sysinfo message');
      _batchNotifyListeners();
      
    } catch (e) {
      print('CDP_OPT: Error processing sysinfo message: $e');
    }
  }
  
  @override
  void dispose() {
    _notificationDebounceTimer?.cancel();
    super.dispose();
  }
}

// Helper extension for firstWhereOrNull if not available (Flutter SDK 2.7.0+)
extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
