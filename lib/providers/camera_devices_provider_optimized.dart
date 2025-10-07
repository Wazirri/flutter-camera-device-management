import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/camera_device.dart'; // Corrected import path
import '../models/camera_group.dart';
import 'websocket_provider_optimized.dart';

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

  // WebSocket provider reference
  WebSocketProviderOptimized? _webSocketProvider;
  
  // UserGroupProvider reference for syncing camera-group assignments
  dynamic _userGroupProvider;

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

  // Set WebSocket provider reference
  void setWebSocketProvider(WebSocketProviderOptimized webSocketProvider) {
    _webSocketProvider = webSocketProvider;
  }
  
  // Set UserGroupProvider reference for syncing camera-group assignments
  void setUserGroupProvider(dynamic userGroupProvider) {
    _userGroupProvider = userGroupProvider;
    // Initial sync of existing groups
    if (_userGroupProvider != null) {
      _userGroupProvider.syncCameraGroupsFromProvider(_cameraGroups);
    }
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
        isPlaceholder: false,
      );
      _cachedFlatCameraList = null; // Invalidate cache
    }
    return _macDefinedCameras[cameraMac]!;
  }

  // Find the device that contains a specific camera
  CameraDevice? findDeviceForCamera(Camera camera) {
    print('CDP_OPT: Looking for device for camera: ${camera.mac} (name: ${camera.name}, index: ${camera.index})');
    print('CDP_OPT: Camera currentDevice: ${camera.currentDevice?.deviceMac ?? "NULL"}');
    
    // First check if camera has currentDevice assignment
    if (camera.currentDevice != null) {
      final deviceMac = camera.currentDevice!.deviceMac;
      print('CDP_OPT: Camera has currentDevice assignment: $deviceMac');
      
      // Find device by MAC
      for (var entry in _devices.entries) {
        CameraDevice device = entry.value;
        print('CDP_OPT: Checking device: ${device.macAddress} (key: ${device.macKey}) vs $deviceMac');
        if (device.macAddress == deviceMac || device.macKey == deviceMac || entry.key == deviceMac) {
          print('CDP_OPT: Found device for camera ${camera.mac} via currentDevice: ${device.macAddress} (${device.ipv4})');
          return device;
        }
      }
      
      print('CDP_OPT: currentDevice not found in devices list: $deviceMac');
    }
    
    // Fallback: try to find by MAC address in device cameras
    print('CDP_OPT: Fallback: Searching by MAC address in device cameras');
    for (var entry in _devices.entries) {
      CameraDevice device = entry.value;
      
      // First try to find by MAC
      for (var deviceCamera in device.cameras) {
        if (deviceCamera.mac == camera.mac && deviceCamera.mac.isNotEmpty) {
          print('CDP_OPT: Found device for camera ${camera.mac} by MAC search: ${device.macAddress} (${device.ipv4})');
          return device;
        }
      }
    }
    
    // Last resort: try to find by index (this is often wrong!)
    print('CDP_OPT: Last resort: Searching by index (often wrong!)');
    for (var entry in _devices.entries) {
      CameraDevice device = entry.value;
      for (var deviceCamera in device.cameras) {
        if (deviceCamera.index == camera.index && camera.index >= 0) {
          print('CDP_OPT: WARNING: Found device for camera by index ${camera.index} (may be incorrect): ${device.macAddress} (${device.ipv4})');
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

  Future<bool> removeCameraFromGroupViaWebSocket(String cameraMac, String groupName) async {
    if (_webSocketProvider != null) {
      print('CDP_OPT: Sending remove camera from group command via WebSocket: $cameraMac from $groupName');
      bool success = await _webSocketProvider!.sendRemoveGroupFromCamera(cameraMac, groupName);
      if (success) {
        print('CDP_OPT: Successfully sent remove camera from group command via WebSocket');
        // The actual removal will be handled when we receive confirmation from WebSocket
        return true;
      } else {
        print('CDP_OPT: Failed to send remove camera from group command via WebSocket');
        return false;
      }
    } else {
      print('CDP_OPT: WebSocket provider not available, removing camera from group locally only');
      removeCameraFromGroup(cameraMac, groupName);
      return false;
    }
  }

  void createGroup(String groupName, {bool fromWebSocket = false}) async {
    if (!_cameraGroups.containsKey(groupName) && groupName.isNotEmpty) {
      // Note: Camera groups are created locally for camera-to-group assignments.
      // This is separate from user permission groups managed via CREATEGROUP command.
      if (!fromWebSocket) {
        print('CDP_OPT: Creating camera group locally for assignments: $groupName');
      }
      
      // Create locally
      _cameraGroups[groupName] = CameraGroup(name: groupName, cameraMacs: []);
      _cachedGroupsList = null;
      _batchNotifyListeners();
      
      if (fromWebSocket) {
        print('CDP_OPT: Created camera group from WebSocket/Master device: $groupName');
      } else {
        print('CDP_OPT: Created camera group locally: $groupName');
      }
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
    
    // Handle group assignment - check if property name contains group[index]
    if (propertyName.startsWith('group[') && propertyName.endsWith(']')) {
      print('CDP_OPT: 🎯 REAL GROUP MESSAGE: $propertyName = $value for camera ${camera.mac}');
      try {
        int groupIndex = int.parse(propertyName.substring(6, propertyName.length - 1));
        String groupValue = value.toString();
        
        // Ensure the camera has enough group slots
        while (camera.groups.length <= groupIndex) {
          camera.groups.add('');
        }
        
        camera.groups[groupIndex] = groupValue;
        print('CDP_OPT: ✅ Camera ${camera.mac} group at index $groupIndex updated to "$groupValue". Groups: ${camera.groups}');
        
        // Update the global group structure if this group name is new
        if (groupValue.isNotEmpty) {
          _ensureGroupExists(groupValue);
          
          // ÖNEMLİ: Kamerayı gruba ekle!
          if (!_cameraGroups[groupValue]!.cameraMacs.contains(camera.mac)) {
            _cameraGroups[groupValue]!.cameraMacs.add(camera.mac);
            print('CDP_OPT: ✅ Camera ${camera.mac} added to group "$groupValue". Group now has ${_cameraGroups[groupValue]!.cameraMacs.length} cameras');
          }
          
          // Sync to UserGroupProvider
          if (_userGroupProvider != null) {
            _userGroupProvider.syncCameraGroupsFromProvider(_cameraGroups);
          }
          
          print('CDP_OPT: ✅ Group "$groupValue" ensured in global groups. Total groups: ${_cameraGroups.length}');
        }
      } catch (e) {
        print('CDP_OPT: ❌ Error parsing group index from $propertyName: $e');
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
    
    // Handle current and history device assignments
    if (parts.length >= 4) {
      await _handleDeviceAssignment(camera, parts, value);
    }
    
    // Merge updated MAC-defined camera data with device cameras
    _mergeMacDefinedCameraData();
    
    _batchNotifyListeners();
  }

  // Handle current and history device assignment data
  Future<void> _handleDeviceAssignment(Camera camera, List<String> parts, dynamic value) async {
    String assignmentType = parts[2]; // 'current' or 'history'
    
    if (assignmentType == 'current') {
      // Handle current device assignment: cameras_mac.MAC.current.DEVICE_MAC.property
      // parts[3] is the device MAC, parts[4] is the property name
      if (parts.length >= 5) {
        String deviceMac = parts[3]; // Device MAC that camera is assigned to
        String property = parts[4]; // Property name
        
        // First, ensure we set the device_mac if we haven't already
        if (camera.currentDevice == null || camera.currentDevice!.deviceMac.isEmpty) {
          await _updateCurrentDeviceAssignment(camera, 'device_mac', deviceMac);
        }
        
        // Then update the specific property
        await _updateCurrentDeviceAssignment(camera, property, value);
      }
    } else if (assignmentType == 'history') {
      // Handle history device assignment: cameras_mac.MAC.history.TIMESTAMP.property
      if (parts.length >= 5) {
        String timestamp = parts[3];
        String historyProperty = parts[4];
        await _updateHistoryDeviceAssignment(camera, timestamp, historyProperty, value);
      }
    }
  }

  // Update current device assignment for camera
  Future<void> _updateCurrentDeviceAssignment(Camera camera, String property, dynamic value) async {
    if (camera.currentDevice == null) {
      camera.currentDevice = CameraCurrentDevice(
        deviceMac: '',
        deviceIp: '',
        cameraIp: '',
        name: '',
        startDate: 0,
      );
    }
    
    switch (property.toLowerCase()) {
      case 'device_mac':
        String deviceMac = value.toString();
        camera.currentDevice = camera.currentDevice!.copyWith(deviceMac: deviceMac);
        
        // Link camera to device when device_mac is set
        if (deviceMac.isNotEmpty) {
          CameraDevice? device = _devices[deviceMac];
          
          if (device != null) {
            // Check if camera is already in device's cameras list
            bool alreadyLinked = device.cameras.any((c) => c.mac == camera.mac);
            
            if (!alreadyLinked) {
              // Find next available index
              int nextIndex = device.cameras.length;
              
              // Add camera to device with proper index
              camera.index = nextIndex;
              camera.parentDeviceMacKey = device.macKey;
              device.cameras.add(camera);
              
              print('CDP_OPT: ✅ Linked MAC-defined camera ${camera.mac} (${camera.name}) to device ${device.macKey} at index $nextIndex');
              
              // Invalidate caches
              _cachedDevicesList = null;
            } else {
              print('CDP_OPT: Camera ${camera.mac} already linked to device ${device.macKey}');
            }
          } else {
            print('CDP_OPT: Device $deviceMac not found for camera ${camera.mac}, camera will appear when device comes online');
          }
        }
        break;
      case 'device_ip':
        camera.currentDevice = camera.currentDevice!.copyWith(deviceIp: value.toString());
        break;
      case 'cameraip':
        camera.currentDevice = camera.currentDevice!.copyWith(cameraIp: value.toString());
        break;
      case 'name':
        camera.currentDevice = camera.currentDevice!.copyWith(name: value.toString());
        break;
      case 'start_date':
        int startDate = value is int ? value : int.tryParse(value.toString()) ?? 0;
        camera.currentDevice = camera.currentDevice!.copyWith(startDate: startDate);
        break;
      default:
        print('CDP_OPT: Unhandled current device property: $property for camera ${camera.mac}');
    }
    
    print('CDP_OPT: Updated current device for camera ${camera.mac}: ${camera.currentDevice}');
  }

  // Update history device assignment for camera
  Future<void> _updateHistoryDeviceAssignment(Camera camera, String timestamp, String property, dynamic value) async {
    int timestampInt = int.tryParse(timestamp) ?? 0;
    
    // Find existing history entry or create new one
    CameraHistoryDevice? historyEntry = camera.deviceHistory
        .where((h) => h.startDate == timestampInt)
        .firstOrNull;
    
    if (historyEntry == null) {
      historyEntry = CameraHistoryDevice(
        deviceMac: '',
        deviceIp: '',
        cameraIp: '',
        name: '',
        startDate: timestampInt,
        endDate: 0,
      );
      camera.deviceHistory.add(historyEntry);
    }
    
    // Update the history entry based on property
    switch (property.toLowerCase()) {
      case 'device_mac':
        int index = camera.deviceHistory.indexOf(historyEntry);
        camera.deviceHistory[index] = historyEntry.copyWith(deviceMac: value.toString());
        break;
      case 'device_ip':
        int index = camera.deviceHistory.indexOf(historyEntry);
        camera.deviceHistory[index] = historyEntry.copyWith(deviceIp: value.toString());
        break;
      case 'cameraip':
        int index = camera.deviceHistory.indexOf(historyEntry);
        camera.deviceHistory[index] = historyEntry.copyWith(cameraIp: value.toString());
        break;
      case 'name':
        int index = camera.deviceHistory.indexOf(historyEntry);
        camera.deviceHistory[index] = historyEntry.copyWith(name: value.toString());
        break;
      case 'start_date':
        int startDate = value is int ? value : int.tryParse(value.toString()) ?? 0;
        int index = camera.deviceHistory.indexOf(historyEntry);
        camera.deviceHistory[index] = historyEntry.copyWith(startDate: startDate);
        break;
      case 'end_date':
        int endDate = value is int ? value : int.tryParse(value.toString()) ?? 0;
        int index = camera.deviceHistory.indexOf(historyEntry);
        camera.deviceHistory[index] = historyEntry.copyWith(endDate: endDate);
        break;
      default:
        print('CDP_OPT: Unhandled history device property: $property for camera ${camera.mac}');
    }
    
    // Sort history by start date for consistent ordering
    camera.deviceHistory.sort((a, b) => b.startDate.compareTo(a.startDate));
    
    print('CDP_OPT: Updated history for camera ${camera.mac}, entry count: ${camera.deviceHistory.length}');
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
    
    // Merge MAC-defined camera data with device camera data
    _mergeMacDefinedCameraData();
    
    // Invalidate caches
    _cachedDevicesList = null;
  }

  // Merge MAC-defined camera data with device cameras based on MAC address
  void _mergeMacDefinedCameraData() {
    for (var device in devices.values) {
      for (var deviceCamera in device.cameras) {
        // Find corresponding MAC-defined camera with same MAC address
        var macDefinedCamera = _macDefinedCameras[deviceCamera.mac];
        if (macDefinedCamera != null) {
          print('CDP_OPT: Merging MAC-defined data for camera ${deviceCamera.mac}');
          
          // Merge current device assignment
          if (macDefinedCamera.currentDevice != null) {
            deviceCamera.currentDevice = macDefinedCamera.currentDevice;
          }
          
          // Merge history device assignments
          deviceCamera.deviceHistory = List<CameraHistoryDevice>.from(macDefinedCamera.deviceHistory);
          
          // Merge other MAC-specific properties
          if (macDefinedCamera.macFirstSeen != null) {
            deviceCamera.macFirstSeen = macDefinedCamera.macFirstSeen;
          }
          if (macDefinedCamera.macLastDetected != null) {
            deviceCamera.macLastDetected = macDefinedCamera.macLastDetected;
          }
          if (macDefinedCamera.macPort != null) {
            deviceCamera.macPort = macDefinedCamera.macPort;
          }
          if (macDefinedCamera.macReportedError != null) {
            deviceCamera.macReportedError = macDefinedCamera.macReportedError;
          }
          if (macDefinedCamera.macStatus != null) {
            deviceCamera.macStatus = macDefinedCamera.macStatus;
          }
          
          // Merge other enhanced properties from MAC-defined camera
          if (macDefinedCamera.username.isNotEmpty) {
            deviceCamera.username = macDefinedCamera.username;
          }
          if (macDefinedCamera.password.isNotEmpty) {
            deviceCamera.password = macDefinedCamera.password;
          }
          if (macDefinedCamera.brand.isNotEmpty) {
            deviceCamera.brand = macDefinedCamera.brand;
          }
          if (macDefinedCamera.manufacturer.isNotEmpty) {
            deviceCamera.manufacturer = macDefinedCamera.manufacturer;
          }
          if (macDefinedCamera.recordCodec.isNotEmpty) {
            deviceCamera.recordCodec = macDefinedCamera.recordCodec;
          }
          if (macDefinedCamera.recordWidth > 0) {
            deviceCamera.recordWidth = macDefinedCamera.recordWidth;
          }
          if (macDefinedCamera.recordHeight > 0) {
            deviceCamera.recordHeight = macDefinedCamera.recordHeight;
          }
          if (macDefinedCamera.subCodec.isNotEmpty) {
            deviceCamera.subCodec = macDefinedCamera.subCodec;
          }
          if (macDefinedCamera.subWidth > 0) {
            deviceCamera.subWidth = macDefinedCamera.subWidth;
          }
          if (macDefinedCamera.subHeight > 0) {
            deviceCamera.subHeight = macDefinedCamera.subHeight;
          }
          if (macDefinedCamera.recordUri.isNotEmpty) {
            deviceCamera.recordUri = macDefinedCamera.recordUri;
          }
          if (macDefinedCamera.subUri.isNotEmpty) {
            deviceCamera.subUri = macDefinedCamera.subUri;
          }
          if (macDefinedCamera.mainSnapShot.isNotEmpty) {
            deviceCamera.mainSnapShot = macDefinedCamera.mainSnapShot;
          }
          if (macDefinedCamera.subSnapShot.isNotEmpty) {
            deviceCamera.subSnapShot = macDefinedCamera.subSnapShot;
          }
          
          print('CDP_OPT: Merged camera ${deviceCamera.mac}: Current device: ${deviceCamera.currentDevice?.deviceMac}, History entries: ${deviceCamera.deviceHistory.length}');
        }
      }
    }
  }

  // Process WebSocket message
  Future<void> processWebSocketMessage(Map<String, dynamic> message) async {
    print('CDP_OPT: 🔵 processWebSocketMessage CALLED with: ${message['data']}');
    try {
      String command = message['c'] ?? '';
      
      // Check if message contains array data
      if (message.containsKey('val') && message['val'] is List) {
        print('CDP_OPT: *** ARRAY DATA DETECTED ***');
        print('CDP_OPT: Array path: ${message['data']}');
        print('CDP_OPT: Array length: ${(message['val'] as List).length}');
        print('CDP_OPT: Array content: ${message['val']}');
        await _processArrayMessage(message);
        return;
      }
      
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
        print('CDP_OPT: ⚠️ DUPLICATE MESSAGE SKIPPED: $messageKey');
        return;
      }
      print('CDP_OPT: ✅ PROCESSING NEW MESSAGE: $messageKey');
      _processedMessages[messageKey] = true;
      
      // Cleanup old processed messages to prevent memory leaks
      if (_processedMessages.length > _maxProcessedMessageCache) {
        _processedMessages.remove(_processedMessages.keys.first);
      }

      if (dataPath.startsWith('cameras_mac.')) {
        final parts = dataPath.split('.'); // cameras_mac.CAMERA_MAC.property or cameras_mac.CAMERA_MAC.group[0]
        print('CDP_OPT: DATAPATH SPLIT: $dataPath -> Parts: $parts (length: ${parts.length})');
        if (parts.length >= 3) {
          final cameraMac = parts[1]; // This is the camera's own MAC address
          if (cameraMac.isNotEmpty) {
            print('CDP_OPT: *** CAMERAS_MAC: Processing ${parts[2]} for camera $cameraMac = $value ***');
            if (parts[2].startsWith('group[')) {
              print('CDP_OPT: 🎯 GROUP MESSAGE DETECTED: ${parts[2]} = $value');
            }
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
      String canonicalDeviceMac = pathDeviceIdentifier;
      
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
  
  // Process array-based camera updates
  Future<void> _processArrayMessage(Map<String, dynamic> message) async {
    try {
      String dataPath = message['data'] ?? '';
      
      // Check if this is a camera array message (cam[index].property)
      if (dataPath.contains('.cam[') && dataPath.contains('].')) {
        print('CDP_OPT: *** CAMERA ARRAY MESSAGE DETECTED ***');
        await _processCameraArrayMessage(message);
        return;
      }
      
      print('CDP_OPT: Non-camera array message: $dataPath');
    } catch (e, s) {
      print('CDP_OPT: Error processing array message: $e\\n$s. Message: $message');
    }
  }
  
  // Process camera array messages and handle array reset
  Future<void> _processCameraArrayMessage(Map<String, dynamic> message) async {
    try {
      String dataPath = message['data'] ?? '';
      dynamic value = message['val'];
      
      // Parse the path: ecs_slaves.DEVICE_MAC.cam[INDEX].PROPERTY
      final pathParts = dataPath.split('.');
      if (pathParts.length < 4) {
        print('CDP_OPT: Invalid camera array path: $dataPath');
        return;
      }
      
      // Extract device MAC and camera index
      final deviceMacPart = pathParts[1]; // Use MAC as-is
      final canonicalDeviceMac = deviceMacPart;
      
      // Parse cam[index].property
      final camPart = pathParts[2]; // cam[index]
      final property = pathParts[3]; // property name
      
      final camIndexMatch = RegExp(r'cam\[(\d+)\]').firstMatch(camPart);
      if (camIndexMatch == null) {
        print('CDP_OPT: Could not parse camera index from: $camPart');
        return;
      }
      
      final cameraIndex = int.parse(camIndexMatch.group(1)!);
      
      print('CDP_OPT: Camera array update - Device: $canonicalDeviceMac, Index: $cameraIndex, Property: $property, Value: $value');
      
      // Get or create the device
      final device = _getOrCreateDevice(canonicalDeviceMac, deviceMacPart);
      
      // Check if this is the start of a new camera array (index 0 with a key property)
      if (cameraIndex == 0 && (property == 'name' || property == 'mac' || property == 'brand')) {
        print('CDP_OPT: *** RESETTING CAMERA ARRAY for device $canonicalDeviceMac ***');
        // Clear existing cameras for this device
        device.cameras.clear();
        
        // Also remove these cameras from global MAC-defined cameras
        final camerasToRemove = <String>[];
        for (final entry in _macDefinedCameras.entries) {
          if (entry.value.parentDeviceMacKey == canonicalDeviceMac) {
            camerasToRemove.add(entry.key);
          }
        }
        
        for (final cameraKey in camerasToRemove) {
          _macDefinedCameras.remove(cameraKey);
          print('CDP_OPT: Removed camera $cameraKey from global list');
        }
        
        // Clear caches
        _cachedDevicesList = null;
        _cachedFlatCameraList = null;
        _cachedGroupsList = null;
      }
      
      // Ensure device has enough camera slots
      while (device.cameras.length <= cameraIndex) {
        final newCamera = Camera(
          mac: '',
          name: '',
          ip: '',
          username: '',
          password: '',
          macPort: 80,
          mediaUri: '',
          recordUri: '',
          mainSnapShot: '',
          subUri: '',
          subSnapShot: '',
          recording: false,
          parentDeviceMacKey: canonicalDeviceMac,
          index: device.cameras.length,
        );
        device.cameras.add(newCamera);
        print('CDP_OPT: Added camera slot ${device.cameras.length - 1} for device $canonicalDeviceMac');
      }
      
      // Update the camera property
      final camera = device.cameras[cameraIndex];
      await _updateCameraProperty(camera, property, value);
      
      // Always update camera in global list if it has MAC (even if name/other props changed)
      if (camera.mac.isNotEmpty) {
        _macDefinedCameras[camera.mac] = camera;
        print('CDP_OPT: Updated camera ${camera.mac} (${camera.name}) in global list');
      }
      
      _batchNotifyListeners();
      
    } catch (e, s) {
      print('CDP_OPT: Error processing camera array message: $e\\n$s. Message: $message');
    }
  }
  
  // Update individual camera property
  Future<void> _updateCameraProperty(Camera camera, String property, dynamic value) async {
    switch (property) {
      case 'mac':
        // Remove old MAC from global list if it exists
        if (camera.mac.isNotEmpty && _macDefinedCameras.containsKey(camera.mac)) {
          _macDefinedCameras.remove(camera.mac);
        }
        camera.mac = value?.toString() ?? '';
        // Add camera with new MAC to global list
        if (camera.mac.isNotEmpty) {
          _macDefinedCameras[camera.mac] = camera;
        }
        break;
      case 'name':
        camera.name = value?.toString() ?? '';
        break;
      case 'cameraIp':
        camera.ip = value?.toString() ?? '';
        break;
      case 'username':
        camera.username = value?.toString() ?? '';
        break;
      case 'password':
        camera.password = value?.toString() ?? '';
        break;
      case 'port':
        camera.macPort = value is int ? value : (int.tryParse(value?.toString() ?? '') ?? 80);
        break;
      case 'mediaUri':
        camera.mediaUri = value?.toString() ?? '';
        break;
      case 'recordUri':
        camera.recordUri = value?.toString() ?? '';
        break;
      case 'remoteUri':
        camera.remoteUri = value?.toString() ?? '';
        break;
      case 'mainSnapShot':
        camera.mainSnapShot = value?.toString() ?? '';
        break;
      case 'subUri':
        camera.subUri = value?.toString() ?? '';
        break;
      case 'subSnapShot':
        camera.subSnapShot = value?.toString() ?? '';
        break;
      case 'brand':
        camera.brand = value?.toString() ?? '';
        break;
      case 'manufacturer':
        camera.manufacturer = value?.toString() ?? '';
        break;
      case 'hw':
        camera.hw = value?.toString() ?? '';
        break;
      case 'country':
        camera.country = value?.toString() ?? '';
        break;
      case 'record':
        camera.recording = (value == 1 || value == true || value?.toString().toLowerCase() == 'true');
        break;
      case 'soundRec':
        camera.soundRec = (value == true || value?.toString().toLowerCase() == 'true');
        break;
      case 'recordcodec':
        camera.recordCodec = value?.toString() ?? '';
        break;
      case 'subcodec':
        camera.subCodec = value?.toString() ?? '';
        break;
      case 'recordwidth':
        camera.recordWidth = value is int ? value : (int.tryParse(value?.toString() ?? '') ?? 0);
        break;
      case 'recordheight':
        camera.recordHeight = value is int ? value : (int.tryParse(value?.toString() ?? '') ?? 0);
        break;
      case 'subwidth':
        camera.subWidth = value is int ? value : (int.tryParse(value?.toString() ?? '') ?? 0);
        break;
      case 'subheight':
        camera.subHeight = value is int ? value : (int.tryParse(value?.toString() ?? '') ?? 0);
        break;
      case 'xAddrs':
        camera.xAddrs = value?.toString() ?? '';
        break;
      default:
        print('CDP_OPT: Unhandled camera property: $property = $value');
    }
    
    print('CDP_OPT: Updated camera ${camera.name} (${camera.mac}) property $property = $value');
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
        // Kamera slot'u henüz oluşturulmamış
        // MAC adresi olmadan kamera yaratmıyoruz - önce MAC gelmeli
        print('CDP_OPT: *** No camera found at index $cameraIndex for device ${device.macKey}. Waiting for MAC assignment. Property $propertyName will be ignored for now. ***');
        return; // MAC olmadan kamera property'leri işlenmiyor
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
