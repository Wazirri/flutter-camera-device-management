import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/camera_device.dart';
import '../models/camera_group.dart';

enum MessageCategory {
  camera,
  cameraReport,
  systemInfo,
  configuration,
  basicProperty,
  cameraGroupAssignment,
  cameraGroupDefinition,
  unknown
}

class CameraDevicesProviderOptimized with ChangeNotifier {
  final Map<String, CameraDevice> _devices = {};
  final Map<String, CameraGroup> _cameraGroups = {};
  CameraDevice? _selectedDevice;
  int _selectedCameraIndex = 0;
  bool _isLoading = false;
  String? _selectedGroupName;

  // Camera name to device mapping for faster lookups
  final Map<String, String> _cameraNameToDeviceMap = {};

  // Notification batching to reduce UI rebuilds
  bool _needsNotification = false;
  Timer? _notificationDebounceTimer;
  final int _notificationBatchWindow = 100; // milliseconds - reduced for faster status updates
  
  // Cache variables to avoid redundant processing
  List<CameraDevice>? _cachedDevicesList;
  List<CameraGroup>? _cachedGroupsList;
  final Map<String, bool> _processedMessages = {};
  final int _maxProcessedMessageCache = 500;

  // Public getters
  Map<String, CameraDevice> get devices => _devices;
  List<CameraDevice> get devicesList {
    _cachedDevicesList ??= _devices.values.toList();
    return _cachedDevicesList!;
  }
  
  CameraDevice? get selectedDevice => _selectedDevice;
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
  
  // Get all cameras as a flat list
  List<Camera> get cameras {
    List<Camera> camerasList = [];
    for (var device in _devices.values) {
      camerasList.addAll(device.cameras);
    }
    return camerasList;
  }
  
  // Get devices grouped by MAC
  Map<String, List<Camera>> getCamerasByMacAddress() {
    Map<String, List<Camera>> result = {};
    
    for (var deviceEntry in _devices.entries) {
      String macAddress = deviceEntry.key;
      CameraDevice device = deviceEntry.value;
      result[macAddress] = device.cameras;
    }
    
    return result;
  }
  
  // Device access by MAC key
  Map<String, CameraDevice> get devicesByMacAddress => _devices;
  
  // Find parent device for a camera
  CameraDevice? getDeviceForCamera(Camera camera) {
    for (var device in _devices.values) {
      if (device.cameras.any((c) => c.index == camera.index)) {
        return device;
      }
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
    final List<Camera> camerasInGroup = [];
    
    // Scan all devices
    for (final deviceEntry in _devices.entries) {
      final deviceMac = deviceEntry.key;
      final device = deviceEntry.value;
      
      // For each camera
      for (int i = 0; i < device.cameras.length; i++) {
        final Camera camera = device.cameras[i];
        
        // Check if camera is in group in any format
        final String simpleIndex = i.toString();
        final String camFormat = "cam[$i]";
        final String fullFormat = "$deviceMac.cam[$i]";
        
        if (group.cameraMacs.contains(simpleIndex) || 
            group.cameraMacs.contains(camFormat) || 
            group.cameraMacs.contains(fullFormat)) {
          
          camerasInGroup.add(camera);
        }
      }
    }
    
    return camerasInGroup;
  }
  
  // Clear groups
  void clearGroups() {
    _cameraGroups.clear();
    _selectedGroupName = null;
    _cachedGroupsList = null;
    _batchNotifyListeners();
  }
  
  // Refresh cameras
  void refreshCameras() {
    _isLoading = true;
    _batchNotifyListeners();
    
    // Simulate refresh completion
    Future.delayed(const Duration(milliseconds: 300), () {
      _isLoading = false;
      _batchNotifyListeners();
    });
  }

  // Preload devices data asynchronously
  Future<void> preloadDevicesData() async {
    // Skip if data already loaded
    if (_devices.isNotEmpty) return;
    
    _isLoading = true;
    _batchNotifyListeners();
    
    // Wait a short time to allow UI to render
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Set loading to false regardless of result
    _isLoading = false;
    _batchNotifyListeners();
  }

  // Process WebSocket messages
  void processWebSocketMessage(Map<String, dynamic> message) async {
    try {
      // Skip invalid messages
      if (message['c'] != 'changed' || !message.containsKey('data') || !message.containsKey('val')) {
        return;
      }
      
      final String dataPath = message['data'];
      final dynamic value = message['val'];
      
      // Skip non-ecs_slaves messages
      if (!dataPath.startsWith('ecs_slaves.')) {
        return;
      }
      
      // Deduplication - Skip if we've seen this exact message recently
      final String messageKey = '$dataPath:${value.toString()}';
      if (_processedMessages.containsKey(messageKey)) {
        return;
      }
      
      // Add to processed cache (with eviction if needed)
      _processedMessages[messageKey] = true;
      if (_processedMessages.length > _maxProcessedMessageCache) {
        _processedMessages.remove(_processedMessages.keys.first);
      }
      
      // Parse data path
      final parts = dataPath.split('.');
      if (parts.length < 2) {
        debugPrint('CDP_OPT: Path too short, skipping: $dataPath');
        return;
      }
      
      String pathDeviceIdentifier = parts[1];
      String canonicalMacAddress;

      RegExp macRegex = RegExp(r'([0-9A-Fa-f]{2}[_:]){5}([0-9A-Fa-f]{2})');
      Match? macMatch = macRegex.firstMatch(pathDeviceIdentifier);

      if (macMatch != null) {
        canonicalMacAddress = macMatch.group(0)!.replaceAll('_', ':');
        if (canonicalMacAddress.length != 17) {
           debugPrint('CDP_OPT: Extracted MAC "$canonicalMacAddress" from "$pathDeviceIdentifier" has invalid length. Skipping message.');
           return;
        }
      } else {
        debugPrint('CDP_OPT: Could not extract MAC address from path component: "$pathDeviceIdentifier". Skipping message.');
        return;
      }
      
      final device = _getOrCreateDevice(canonicalMacAddress, pathDeviceIdentifier);
      
      // Special case for common device properties that might get missed in categorization
      // These should be handled before the general categorization switch
      if (parts.length >= 3) {
        if (parts[2] == 'online') {
          final onlineValue = value.toString();
          final bool previousStatus = device.connected;
          final bool newStatus = value is bool ? value : (onlineValue == '1' || onlineValue.toLowerCase() == 'true');
          
          if (!previousStatus && newStatus) {
            debugPrint('Device ${device.macAddress} coming online - potential camera clear logic was here');
          }
          
          device.connected = newStatus;
          device.updateStatus();
          debugPrint('Direct online handling: Device ${device.macAddress} online status changed from $previousStatus to ${device.connected} (value: $onlineValue)');
          _cachedDevicesList = null;
          _batchNotifyListeners();
          return; // Return after handling
        }
        
        if (parts[2] == 'connected') {
          final connectedValue = value.toString();
          final bool previousStatus = device.connected;
          final bool newStatus = value is bool ? value : (connectedValue == '1' || connectedValue.toLowerCase() == 'true');
          
          if (!previousStatus && newStatus) {
            debugPrint('Device ${device.macAddress} connecting - potential camera clear logic was here');
          }
          
          device.connected = newStatus;
          device.updateStatus();
          debugPrint('Direct connected handling: Device ${device.macAddress} connected status changed from $previousStatus to ${device.connected} (value: $connectedValue)');
          _cachedDevicesList = null;
          _batchNotifyListeners();
          return; // Return after handling
        }
        
        if (parts[2] == 'firsttime') {
          device.uptime = value.toString();
          debugPrint('Direct firsttime handling: Device ${device.macAddress} firsttime set to: ${value.toString()}');
          _cachedDevicesList = null;
          _batchNotifyListeners();
          return; // Return after handling
        }
        
        if (parts[2] == 'current_time') {
          device.lastSeenAt = value.toString();
          debugPrint('Direct current_time handling: Device ${device.macAddress} current_time set to: ${value.toString()}');
          _cachedDevicesList = null;
          _batchNotifyListeners();
          return; // Return after handling
        }
      } // End of early handling for specific device properties

      // Categorize and process message if not handled above
      if (parts.length >= 3) {
        final messageCategory = _categorizeMessage(parts[2], parts.length > 3 ? parts.sublist(3) : []);
        
        switch (messageCategory) {
          case MessageCategory.camera:
            await _processCameraData(device, parts[2], parts.length > 3 ? parts.sublist(3) : [], value);
            break;
          case MessageCategory.cameraReport:
            await _processCameraReport(device, parts.length > 3 ? parts.sublist(3) : [], value);
            break;
          case MessageCategory.systemInfo:
            await _processSystemInfo(device, parts.length > 3 ? parts.sublist(3) : [], value);
            break;
          case MessageCategory.configuration:
            await _processConfiguration(device, parts.length > 3 ? parts.sublist(3) : [], value);
            break;
          case MessageCategory.basicProperty: // This will be hit if not one of the special cases above
            await _processBasicDeviceProperty(device, parts[2], value);
            // Note: The original code had a specific check here:
            // if (parts[2] == 'online' || parts[2] == 'connected') { _batchNotifyListeners(); }
            // This is now handled by the early returns above for 'online' and 'connected'.
            // If other basic properties need immediate notification, that logic would go here.
            break;
          case MessageCategory.cameraGroupAssignment:
            if (parts.length > 3 && parts[2].startsWith('cam')) {
              final cameraIndex = parts[2].replaceAll('cam', '').replaceAll(RegExp(r'\\[|\\]'), '');
              await _processCameraGroupAssignment(device, cameraIndex, value.toString());
            }
            break;
          case MessageCategory.cameraGroupDefinition:
            if (parts.length > 3 && parts[2] == 'configuration' && parts[3].startsWith('cameraGroups')) {
              final groupIndex = parts[3].replaceAll('cameraGroups', '').replaceAll(RegExp(r'\\[|\\]'), '');
              await _processGroupDefinition(device, groupIndex, value.toString());
            }
            break;
          case MessageCategory.unknown:
            // Legacy format support
            if (parts.length > 3 && parts[2] == 'cam' && parts.length > 4 && parts[4] == 'group') {
              final cameraIndex = parts[3].replaceAll(RegExp(r'\\[|\\]'), '');
              await _processCameraGroupAssignment(device, cameraIndex, value.toString());
            }
            else if (parts.length > 3 && parts[2] == 'configuration' && parts[3].startsWith('cameraGroups')) {
              final groupIndex = parts[3].replaceAll('cameraGroups', '').replaceAll(RegExp(r'\\[|\\]'), '');
              await _processGroupDefinition(device, groupIndex, value.toString());
            }
            break;
        }
        
        _cachedDevicesList = null;
        _batchNotifyListeners();
      } // End of if (parts.length >= 3) for categorization
    } catch (e) { // This catch block should correctly follow the try block
      debugPrint('CDP_OPT: Error processing WebSocket message: $e. Message: $message');
    }
  }
  
  // Categorize messages
  MessageCategory _categorizeMessage(String pathComponent, List<String> remainingPath) {
    // Common basic device properties should always be treated as basic properties
    if (pathComponent == 'online' || 
        pathComponent == 'connected' ||
        pathComponent == 'firsttime' || 
        pathComponent == 'current_time') {
      debugPrint('Detected basic device property: $pathComponent');
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
    } else {
      return MessageCategory.basicProperty; 
    }
  }
  
  // Get or create device
  CameraDevice _getOrCreateDevice(String canonicalDeviceMac, String originalPathMacKey) {
    // Use canonicalDeviceMac as the key for the _devices map
    if (!_devices.containsKey(canonicalDeviceMac)) {
      _devices[canonicalDeviceMac] = CameraDevice(
        macAddress: canonicalDeviceMac, // Store the canonical MAC
        macKey: originalPathMacKey,     // Store the original key from path
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
  
  // Process camera data
  Future<void> _processCameraData(CameraDevice device, String camIndexPath, List<String> properties, dynamic value) async {
    // Extract camera index
    String indexStr = camIndexPath.substring(4, camIndexPath.indexOf(']')); // e.g., "0" from "cam[0]"
    int cameraIndex = int.tryParse(indexStr) ?? -1;
    
    if (cameraIndex < 0) {
      debugPrint('CDP_OPT: Invalid camera index $cameraIndex from $camIndexPath. Skipping.');
      return;
    }
    
    // Skip if no properties
    if (properties.isEmpty) {
      debugPrint('CDP_OPT: No properties for camera index $cameraIndex in $camIndexPath. Skipping.');
      return;
    }
    
    String propertyName = properties[0];
    
    debugPrint('CDP_OPT: Processing camera data: device=${device.macAddress}, index=$cameraIndex, property=$propertyName, value=$value, current_cameras_count=${device.cameras.length}');

    // Find existing camera or create a new one
    Camera? cameraToProcess;
    int existingCameraObjectIndex = device.cameras.indexWhere((c) => c.index == cameraIndex);

    if (existingCameraObjectIndex != -1) {
      cameraToProcess = device.cameras[existingCameraObjectIndex];
      debugPrint('CDP_OPT: Found existing camera at object index $existingCameraObjectIndex for logical index $cameraIndex on device ${device.macAddress}.');
    } else {
      debugPrint('CDP_OPT: No camera found for logical index $cameraIndex on device ${device.macAddress}. Creating new one.');
      // _createCamera will add the camera to device.cameras list.
      await _createCamera(device, cameraIndex); 
      
      // After creation, find it again to ensure it was added correctly.
      int newCameraObjectIndex = device.cameras.indexWhere((c) => c.index == cameraIndex);
      if (newCameraObjectIndex != -1) {
          cameraToProcess = device.cameras[newCameraObjectIndex];
          debugPrint('CDP_OPT: Successfully created and retrieved camera for logical index $cameraIndex on device ${device.macAddress}.');
      } else {
          // This indicates a problem with _createCamera or concurrent modification.
          debugPrint('CDP_OPT: CRITICAL ERROR - _createCamera was called for index $cameraIndex but camera not found afterwards in device ${device.macAddress}. Skipping update for property $propertyName.');
          return; 
      }
    }
    
    // At this point, cameraToProcess should be non-null if everything worked.
    if (cameraToProcess != null) {
      await _updateCameraProperty(cameraToProcess, propertyName, properties, value);
    } else {
      // This case should ideally not be reached if the logic above is sound.
      debugPrint('CDP_OPT: CRITICAL ERROR - cameraToProcess is null for index $cameraIndex on device ${device.macAddress} before updating property $propertyName. Path: $camIndexPath');
    }
  }

  // Create a new camera at specific index
  Future<void> _createCamera(CameraDevice device, int cameraIndex) async {
    debugPrint('CDP_OPT: _createCamera attempting for index $cameraIndex on device ${device.macAddress}');
    
    // Defensive check: ensure we are not accidentally adding a duplicate index.
    if (device.cameras.any((c) => c.index == cameraIndex)) {
        debugPrint('CDP_OPT: WARNING in _createCamera - Camera with logical index $cameraIndex already exists on device ${device.macAddress}. Not creating another.');
        return; 
    }

    final newCamera = Camera(
      index: cameraIndex,
      connected: false,
      name: 'Camera $cameraIndex', // Default name, will be updated by properties if 'name' comes through
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
      lastSeenAt: '',
      recording: false,
      mac: '${device.macAddress}_cam$cameraIndex', // Generate MAC format for camera
    );
    device.cameras.add(newCamera);
    _cachedDevicesList = null; // Invalidate cache as device's camera list has changed
    debugPrint('CDP_OPT: Camera created and added: ${newCamera.name} with index $cameraIndex for device ${device.macAddress}');
  }
  
  // Update camera property
  Future<void> _updateCameraProperty(Camera camera, String propertyName, List<String> properties, dynamic value) async {
    switch (propertyName.toLowerCase()) {
      case 'ip':
      case 'cameraip':
        camera.ip = value.toString();
        break;
      case 'connected':
        final bool previousStatus = camera.connected;
        camera.setConnectedStatus(value); // Use the new setter method
        debugPrint('Camera ${camera.name} connected status changed from $previousStatus to ${camera.connected} (value: $value)');
        break;
      case 'name':
        // Find which device this camera belongs to
        String? deviceMacOwner; 
        // The 'camera' object knows its parent device implicitly via the list it's in.
        // We need the device's canonical MAC for the _cameraNameToDeviceMap.
        // This loop is a bit inefficient but necessary if camera doesn't store parent MAC.
        // A better approach might be to pass the ownerDevice directly to _updateCameraProperty.
        for (var entry in _devices.entries) { // _devices uses canonical MAC as key
          if (entry.value.cameras.contains(camera)) {
            deviceMacOwner = entry.key; 
            break;
          }
        }
        
        // Remove old mapping if camera had a name and was previously mapped
        if (camera.name.isNotEmpty && _cameraNameToDeviceMap.containsKey(camera.name)) {
          // Only remove if it was mapped to THIS device.
          // This check might be overly cautious if names are globally unique in the map,
          // or if the map stores deviceMacOwner along with the camera.
          // For now, assume simple removal is okay, or that deviceMacOwner check is implicit.
          _cameraNameToDeviceMap.remove(camera.name);
        }
        
        String newName = value.toString();

        // Check for name conflicts within the same device
        if (deviceMacOwner != null) {
            CameraDevice? ownerDevice = _devices[deviceMacOwner];
            if (ownerDevice != null) {
                for (var otherCamera in ownerDevice.cameras) {
                    // If another camera (not this one) in the same device already has the new name
                    if (otherCamera != camera && otherCamera.name == newName) {
                        debugPrint("CDP_OPT: Name conflict. Camera with index ${camera.index} and camera with index ${otherCamera.index} in device ${ownerDevice.macAddress} both want name '$newName'. Appending index to new name for cam ${camera.index}.");
                        newName = "$newName (cam ${camera.index})"; 
                        break; 
                    }
                }
            }
        }

        camera.name = newName; // Assign potentially modified name
        
        // Add new mapping using the canonical device MAC
        if (deviceMacOwner != null && camera.name.isNotEmpty) {
          _cameraNameToDeviceMap[camera.name] = deviceMacOwner;
        }
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
      case 'mac':
        camera.mac = value.toString();
        break;
      case 'xaddrs':
        camera.xAddrs = value.toString();
        break;
      case 'xaddr':
        camera.xAddr = value.toString();
        break;
      case 'mediauri':
        camera.mediaUri = value.toString();
        break;
      case 'recorduri':
        camera.recordUri = value.toString();
        break;
      case 'suburi':
        camera.subUri = value.toString();
        break;
      case 'remoteuri':
        camera.remoteUri = value.toString();
        break;
      case 'mainsnapshot':
        camera.mainSnapShot = value.toString();
        break;
      case 'subsnapshot':
        camera.subSnapShot = value.toString();
        break;
      case 'cameraip':
        camera.ip = value.toString();
        break;
      case 'camerarawip':
        camera.rawIp = value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'record':
        camera.recording = value is bool ? value : (value.toString() == '1' || value.toString().toLowerCase() == 'true');
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
      case 'recordcodec':
        camera.recordCodec = value.toString();
        break;
      case 'subcodec':
        camera.subCodec = value.toString();
        break;
      case 'soundrec':
        camera.soundRec = value is bool ? value : (value.toString() == '1' || value.toString().toLowerCase() == 'true');
        break;
      case 'recordpath':
        camera.recordPath = value.toString();
        break;
      case 'xaddrs':
        camera.xAddrs = value.toString();
        break;
      case 'xaddr':
        camera.xAddr = value.toString();
        break;
      default:
        debugPrint('Unhandled camera property: $propertyName = $value');
        break;
    }
  }
  
  // Process camera report - optimized with camera name index
  Future<void> _processCameraReport(CameraDevice device, List<String> properties, dynamic value) async {
    if (properties.isEmpty) return;
    
    // Extract camera name from first property (the camera identifier)
    final cameraName = properties[0];
    if (properties.length < 2) return;
    
    final reportProperty = properties[1].toLowerCase();
    
    // Use fast lookup via camera name mapping first
    String? deviceMacFromIndex = _cameraNameToDeviceMap[cameraName];
    Camera? targetCamera;
    
    // device.macAddress is already the canonical one here
    if (deviceMacFromIndex != null && deviceMacFromIndex == device.macAddress) {
      // Fast path: find camera directly using index
      targetCamera = device.cameras.firstWhere(
        (camera) => camera.name == cameraName,
        orElse: () => null as Camera, // Explicitly cast to Camera? or Camera
      );
    }
    
    // Fallback: search through all cameras if index lookup failed
    if (targetCamera == null) {
      for (var cam in device.cameras) { // Changed variable name from camera to cam to avoid conflict
        if (cam.name == cameraName) {
          targetCamera = cam;
          // Update the index for future lookups using canonical MAC
          _cameraNameToDeviceMap[cameraName] = device.macAddress;
          break;
        }
      }
    }
    
    // If camera still not found, try to create it if this is a connection report
    if (targetCamera == null && (reportProperty == 'connected' || reportProperty == 'last_seen_at')) {
      // Create a new camera for this report
      final newCamera = Camera(
        index: device.cameras.length,
        connected: false,
        name: cameraName,
        ip: '',
        username: '',
        password: '',
        brand: '',
        mediaUri: '',
        recordUri: '',
        subUri: '',
        remoteUri: '',
        hw: '',
        manufacturer: '',
        country: '',
        xAddrs: '',
        xAddr: '',
        mainSnapShot: '',
        subSnapShot: '',
        recordPath: '',
        recordWidth: 0,
        recordHeight: 0,
        subWidth: 0,
        subHeight: 0,
        recordCodec: '',
        subCodec: '',
        rawIp: 0,
        soundRec: false,
        lastSeenAt: '',
        recording: false,
        mac: '${device.macAddress}_${cameraName}',
      );
      device.cameras.add(newCamera);
      targetCamera = newCamera;
      
      // Update the index with canonical MAC
      _cameraNameToDeviceMap[cameraName] = device.macAddress;
      debugPrint('CDP_OPT: Created new camera from report: $cameraName in device ${device.macAddress}');
    }
    
    // If camera still not found, skip
    if (targetCamera == null) {
      debugPrint('Camera report: Camera $cameraName not found in device ${device.macAddress}');
      return;
    }
    
    // Update camera report properties
    switch (reportProperty) {
      case 'disconnected':
        targetCamera.disconnected = value.toString();
        break;
      case 'connected':
        final bool previousStatus = targetCamera.connected;
        targetCamera.setConnectedStatus(value);
        debugPrint('Camera report: ${targetCamera.name} connected status changed from $previousStatus to ${targetCamera.connected}');
        break;
      case 'last_seen_at':
        targetCamera.lastSeenAt = value.toString();
        break;
      case 'recording':
        targetCamera.recording = value is bool ? value : (value.toString() == '1' || value.toString().toLowerCase() == 'true');
        break;
      case 'last_restart_time':
        targetCamera.lastRestartTime = value.toString();
        break;
      case 'health':
        targetCamera.health = value.toString();
        break;
      case 'temperature':
        targetCamera.temperature = double.tryParse(value.toString()) ?? 0.0;
        break;
      case 'report_error':
        targetCamera.reportError = value.toString();
        break;
      case 'report_name':
        targetCamera.reportName = value.toString();
        break;
      default:
        debugPrint('Unhandled camera report property: $reportProperty = $value for camera $cameraName');
        break;
    }
  }
  
  // Process system info
  Future<void> _processSystemInfo(CameraDevice device, List<String> properties, dynamic value) async {
    if (properties.isEmpty) return;
    
    final property = properties[0].toLowerCase();
    
    // Handle uptime in all formats (uptime, upTime)
    if (property == 'uptime' || property == 'uptime') {
      device.uptime = value.toString();
    } else if (property == 'connected') {
      final bool previousStatus = device.connected;
      device.connected = value is bool ? value : (value.toString() == '1' || value.toString().toLowerCase() == 'true');
      device.updateStatus(); // Force status update
      debugPrint('System info update: Device ${device.macAddress} connected status changed from $previousStatus to ${device.connected}');
    } else if (property == 'online') {
      final bool previousStatus = device.connected;
      device.connected = value is bool ? value : (value.toString() == '1' || value.toString().toLowerCase() == 'true');
      device.updateStatus(); // Force status update
      debugPrint('System info update: Device ${device.macAddress} online status changed from $previousStatus to ${device.connected}');
    } else if (property == 'lastupdate' || property == 'lastseen') {
      device.lastSeenAt = value.toString();
    }
  }
  
  // Process configuration
  Future<void> _processConfiguration(CameraDevice device, List<String> properties, dynamic value) async {
    // Implementation would go here
    // Simplified for performance optimization
  }
  
  // Process basic device property
  Future<void> _processBasicDeviceProperty(CameraDevice device, String propertyName, dynamic value) async {
    switch (propertyName.toLowerCase()) {
      case 'ipv4':
        device.ipv4 = value.toString();
        break;
      case 'type':
      case 'devicetype':
        device.deviceType = value.toString();
        break;
      case 'firmware':
      case 'version':
        device.firmwareVersion = value.toString();
        break;
      case 'connected':
        final bool previousStatus = device.connected;
        device.connected = value is bool ? value : (value.toString() == '1' || value.toString().toLowerCase() == 'true');
        device.updateStatus(); // Force status update
        debugPrint('Device ${device.macAddress} connected status changed from $previousStatus to ${device.connected} (original value: ${value.toString()})');
        break;
      case 'online':
        // Parse 'online' property from numeric value (1 for online, 0 for offline)
        final onlineValue = value.toString();
        final bool previousStatus = device.connected;
        device.connected = value is bool ? value : (onlineValue == '1' || onlineValue.toLowerCase() == 'true');
        device.updateStatus(); // Force status update
        debugPrint('Device ${device.macAddress} online status changed from $previousStatus to ${device.connected} (original value: $onlineValue)');
        break;
      case 'firsttime':
        // Store first time property in device uptime field
        device.uptime = value.toString();
        debugPrint('Device ${device.macAddress} firsttime set to: ${value.toString()}');
        break;
      case 'current_time':
        // Store current time in device lastSeenAt field
        device.lastSeenAt = value.toString();
        debugPrint('Device ${device.macAddress} current_time set to: ${value.toString()}');
        break;
    }
  }
  
  // Process camera group assignment
  Future<void> _processCameraGroupAssignment(CameraDevice device, String cameraIndex, String groupName) async {
    // Implementation would go here
    // Simplified for performance optimization
  }
  
  // Process group definition
  Future<void> _processGroupDefinition(CameraDevice device, String groupIndex, String groupName) async {
    // Daha sıkı filtreleme: boş, null, sadece whitespace olanları reddet
    if (groupName.isEmpty || groupName.trim().isEmpty) {
      return;
    }
    
    // Çok kısa grup isimlerini de reddet
    if (groupName.trim().length < 2) {
      return;
    }
    
    final String cleanGroupName = groupName.trim();
    
    // Create group if it doesn't exist
    if (!_cameraGroups.containsKey(cleanGroupName) && cleanGroupName.isNotEmpty) {
      _cameraGroups[cleanGroupName] = CameraGroup(
        name: cleanGroupName,
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
        debugPrint("CDP_OPT: Ignoring empty or whitespace-only group name from WebSocket.");
        return;
      }
      
      // Çok kısa grup isimlerini de reddet
      if (groupName.trim().length < 2) {
        debugPrint("CDP_OPT: Ignoring too short group name from WebSocket: '$groupName'");
        return;
      }
      
      final String cleanGroupName = groupName.trim();
      
      // Grup zaten varsa, uyarı ver ama hata verme
      if (_cameraGroups.containsKey(cleanGroupName)) {
        debugPrint("CDP_OPT: Group '$cleanGroupName' already exists, skipping creation.");
        return;
      }
      
      // Yeni grup oluştur
      _cameraGroups[cleanGroupName] = CameraGroup(name: cleanGroupName);
      debugPrint("CDP_OPT: Created new group from WebSocket CAM_GROUP_ADD: '$cleanGroupName'");
      
      // Cache'i temizle
      _cachedGroupsList = null;
      
      // UI'ı güncelle
      _batchNotifyListeners();
      
    } catch (e) {
      debugPrint("CDP_OPT: Error in addGroupFromWebSocket: $e");
    }
  }

  // clearDeviceCameras kaldırıldı. Kameralar asla topluca silinmez.

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
        notifyListeners();
      }
    });
  }
  
  @override
  void dispose() {
    _notificationDebounceTimer?.cancel();
    super.dispose();
  }
}
