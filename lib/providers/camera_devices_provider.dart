import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/camera_device.dart'; // Corrected import path
import '../models/camera_group.dart';
import 'websocket_provider.dart';

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
  final Map<String, CameraDevice> _devices =
      {}; // Parent devices, keyed by their canonical MAC
  final Map<String, Camera> _macDefinedCameras =
      {}; // Master list of cameras, keyed by their own MAC
  final Map<String, CameraGroup> _cameraGroups = {};
  List<CameraGroup>? _cachedGroupsList;
  CameraDevice? _selectedDevice;
  int _selectedCameraIndex = 0;
  bool _isLoading = false;
  String? _selectedGroupName;

  // Buffer for camera properties that arrive before MAC
  // Key: "deviceMac:cameraIndex", Value: Map of property -> value
  final Map<String, Map<String, dynamic>> _pendingCameraProperties = {};

  // WebSocket provider reference
  WebSocketProviderOptimized? _webSocketProvider;

  // UserGroupProvider reference for syncing camera-group assignments
  dynamic _userGroupProvider;

  // Camera name to device mapping for faster lookups
  final Map<String, String> _cameraNameToDeviceMap = {};

  // ============= MASTER CONFIG DATA =============
  // These values are read from WebSocket and can be modified via settings
  bool _autoScanEnabled = false;
  bool _autoCameraDistributingEnabled = false;
  bool _masterHasCams = false;
  int _imbalanceThreshold = 2;
  int _lastScanTotalCameras = 0;
  int _lastScanConnectedCameras = 0;
  int _lastScanActiveSlaves = 0;
  String _lastCamDistributedAt = '';
  List<String> _onvifPasswords = [];

  // ============= NETWORKING DATA =============
  String _networkDefaultIp = '';
  String _networkDefaultNetmask = '';
  String _networkDefaultGw = '';
  String _networkDefaultDns = '';
  String _networkDefaultIpStart = '';
  String _networkDefaultIpEnd = '';
  String _networkDefaultLeaseTime = '5m';
  bool _networkShareInternet = false;
  bool _networkDhcp = false;

  // Getters for master config
  bool get autoScanEnabled => _autoScanEnabled;
  bool get autoCameraDistributingEnabled => _autoCameraDistributingEnabled;
  bool get masterHasCams => _masterHasCams;
  int get imbalanceThreshold => _imbalanceThreshold;
  int get lastScanTotalCameras => _lastScanTotalCameras;
  int get lastScanConnectedCameras => _lastScanConnectedCameras;
  int get lastScanActiveSlaves => _lastScanActiveSlaves;
  String get lastCamDistributedAt => _lastCamDistributedAt;
  List<String> get onvifPasswords => List.unmodifiable(_onvifPasswords);

  // Getters for networking
  String get networkDefaultIp => _networkDefaultIp;
  String get networkDefaultNetmask => _networkDefaultNetmask;
  String get networkDefaultGw => _networkDefaultGw;
  String get networkDefaultDns => _networkDefaultDns;
  String get networkDefaultIpStart => _networkDefaultIpStart;
  String get networkDefaultIpEnd => _networkDefaultIpEnd;
  String get networkDefaultLeaseTime => _networkDefaultLeaseTime;
  bool get networkShareInternet => _networkShareInternet;
  bool get networkDhcp => _networkDhcp;

  // Batch notifications to reduce UI rebuilds
  bool _needsNotification = false;
  Timer? _notificationDebounceTimer;
  final int _notificationBatchWindow =
      500; // milliseconds - increased for better batching with many cameras

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

  // Get cameras filtered by user authorization
  List<Camera> getAuthorizedCameras(Set<String>? authorizedMacs) {
    print('CDP: 🎬 getAuthorizedCameras called');
    print('CDP: 📋 Total cameras: ${cameras.length}');
    print(
        'CDP: 🔑 Authorized MACs: ${authorizedMacs?.length ?? "ALL (admin)"}');

    if (authorizedMacs == null) {
      print('CDP: 👑 Returning all cameras (admin or no restriction)');
      return cameras;
    }

    if (authorizedMacs.isEmpty) {
      print('CDP: ⚠️ Empty authorized MACs - returning no cameras');
      return [];
    }

    // Filter cameras by authorized MACs
    final filteredCameras = cameras.where((camera) {
      final isAuthorized = authorizedMacs.contains(camera.mac);
      if (!isAuthorized && camera.mac.isNotEmpty) {
        print('CDP: ❌ Camera ${camera.name} (${camera.mac}) - NOT authorized');
      }
      return isAuthorized;
    }).toList();

    print('CDP: ✅ Returning ${filteredCameras.length} authorized cameras');
    for (var cam in filteredCameras) {
      print('CDP: ✓ ${cam.name} (${cam.mac})');
    }

    return filteredCameras;
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
  CameraGroup? get selectedGroup =>
      _selectedGroupName != null ? _cameraGroups[_selectedGroupName] : null;
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
    print(
        'CDP_OPT: preloadDevicesData called - no action needed for WebSocket version');
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
    print(
        'CDP_OPT: Looking for device for camera: ${camera.mac} (name: ${camera.name}, index: ${camera.index})');
    print(
        'CDP_OPT: Camera currentDevices: ${camera.currentDevices.keys.join(", ")}');

    // First check if camera has currentDevices assignment
    if (camera.currentDevices.isNotEmpty) {
      // Use first device (for backward compatibility)
      final deviceMac = camera.currentDevices.keys.first;
      print('CDP_OPT: Camera has currentDevices assignment: $deviceMac');

      // Find device by MAC
      for (var entry in _devices.entries) {
        CameraDevice device = entry.value;
        print(
            'CDP_OPT: Checking device: ${device.macAddress} (key: ${device.macKey}) vs $deviceMac');
        if (device.macAddress == deviceMac ||
            device.macKey == deviceMac ||
            entry.key == deviceMac) {
          print(
              'CDP_OPT: Found device for camera ${camera.mac} via currentDevice: ${device.macAddress} (${device.ipv4})');
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
          print(
              'CDP_OPT: Found device for camera ${camera.mac} by MAC search: ${device.macAddress} (${device.ipv4})');
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
          print(
              'CDP_OPT: WARNING: Found device for camera by index ${camera.index} (may be incorrect): ${device.macAddress} (${device.ipv4})');
          return device;
        }
      }
    }

    print(
        'CDP_OPT: No device found for camera: ${camera.mac} (name: ${camera.name}, index: ${camera.index})');
    print('CDP_OPT: Available devices: ${_devices.keys.toList()}');
    for (var entry in _devices.entries) {
      print(
          'CDP_OPT: Device ${entry.key}: ${entry.value.cameras.map((c) => '${c.mac}(${c.name})').toList()}');
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

  // Update a camera in the master list
  void updateCamera(Camera updatedCamera) {
    if (updatedCamera.mac.isNotEmpty &&
        _macDefinedCameras.containsKey(updatedCamera.mac)) {
      _macDefinedCameras[updatedCamera.mac] = updatedCamera;

      // Clear the flat camera list cache to force rebuild
      _cachedFlatCameraList = null;

      // Also update the camera in all devices that have it
      for (var device in _devices.values) {
        for (int i = 0; i < device.cameras.length; i++) {
          if (device.cameras[i].mac == updatedCamera.mac) {
            device.cameras[i] = updatedCamera;
          }
        }
      }

      _batchNotifyListeners();
      print('CDP_OPT: ✅ Camera ${updatedCamera.mac} updated');
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

  Future<bool> removeCameraFromGroupViaWebSocket(
      String cameraMac, String groupName) async {
    if (_webSocketProvider != null) {
      print(
          'CDP_OPT: Sending remove camera from group command via WebSocket: $cameraMac from $groupName');
      bool success = await _webSocketProvider!
          .sendRemoveGroupFromCamera(cameraMac, groupName);
      if (success) {
        print(
            'CDP_OPT: Successfully sent remove camera from group command via WebSocket');
        // The actual removal will be handled when we receive confirmation from WebSocket
        return true;
      } else {
        print(
            'CDP_OPT: Failed to send remove camera from group command via WebSocket');
        return false;
      }
    } else {
      print(
          'CDP_OPT: WebSocket provider not available, removing camera from group locally only');
      removeCameraFromGroup(cameraMac, groupName);
      return false;
    }
  }

  void createGroup(String groupName, {bool fromWebSocket = false}) async {
    if (!_cameraGroups.containsKey(groupName) && groupName.isNotEmpty) {
      // Note: Camera groups are created locally for camera-to-group assignments.
      // This is separate from user permission groups managed via CREATEGROUP command.
      if (!fromWebSocket) {
        print(
            'CDP_OPT: Creating camera group locally for assignments: $groupName');
      }

      // Create locally
      _cameraGroups[groupName] = CameraGroup(name: groupName, cameraMacs: []);
      _cachedGroupsList = null;
      _batchNotifyListeners();

      if (fromWebSocket) {
        print(
            'CDP_OPT: Created camera group from WebSocket/Master device: $groupName');
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
    print('CDP_OPT: 🧹 resetData() called');
    print(
        'CDP_OPT: Clearing ${_devices.length} devices, ${_macDefinedCameras.length} cameras, ${_cameraGroups.length} groups');

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

    print('CDP_OPT: ✅ All data cleared');
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
  Future<void> _updateMacDefinedCameraProperty(
      Camera camera, List<String> parts, dynamic value) async {
    String propertyName = parts[2];
    print(
        'CDP_OPT: *** CAMERAS_MAC: Processing ${parts[2]} for camera ${camera.mac} = $value ***');

    // Handle group assignment - check if property name contains group[index]
    if (propertyName.startsWith('group[') && propertyName.endsWith(']')) {
      print(
          'CDP_OPT: 🎯 REAL GROUP MESSAGE: $propertyName = $value for camera ${camera.mac}');
      try {
        int groupIndex =
            int.parse(propertyName.substring(6, propertyName.length - 1));
        String groupValue = value.toString();

        // Ensure the camera has enough group slots
        while (camera.groups.length <= groupIndex) {
          camera.groups.add('');
        }

        camera.groups[groupIndex] = groupValue;
        print(
            'CDP_OPT: ✅ Camera ${camera.mac} group at index $groupIndex updated to "$groupValue". Groups: ${camera.groups}');

        // Update the global group structure if this group name is new
        if (groupValue.isNotEmpty) {
          _ensureGroupExists(groupValue);

          // ÖNEMLİ: Kamerayı gruba ekle!
          if (!_cameraGroups[groupValue]!.cameraMacs.contains(camera.mac)) {
            _cameraGroups[groupValue]!.cameraMacs.add(camera.mac);
            print(
                'CDP_OPT: ✅ Camera ${camera.mac} added to group "$groupValue". Group now has ${_cameraGroups[groupValue]!.cameraMacs.length} cameras');
          }

          // Sync to UserGroupProvider
          if (_userGroupProvider != null) {
            _userGroupProvider.syncCameraGroupsFromProvider(_cameraGroups);
          }

          print(
              'CDP_OPT: ✅ Group "$groupValue" ensured in global groups. Total groups: ${_cameraGroups.length}');
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
      case 'detected':
        camera.macFirstSeen = value.toString();
        break;
      case 'firsttime':
        camera.macFirstSeen = value.toString();
        break;
      case 'lastdetected':
        camera.macLastDetected = value.toString();
        break;
      case 'port':
        camera.macPort = value is int ? value : int.tryParse(value.toString());
        break;
      case 'error':
        camera.macReportedError = value.toString();
        break;
      case 'status':
        camera.macStatus = value.toString();
        break;
      case 'seen':
        camera.lastSeenAt = value.toString();
        break;

      // General camera properties that can also be set by cameras_mac
      case 'name':
        camera.name = value.toString();
        break;
      case 'cameraip': // Assuming 'cameraip' from cameras_mac maps to general 'ip'
        camera.ip = value.toString();
        print('CDP_OPT: 🌐 _updateMacDefinedCameraProperty: Set camera.ip for ${camera.mac} = ${camera.ip}');
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
      case 'mainsnapshot':
        camera.mainSnapShot = value.toString();
        break;
      case 'subsnapshot':
        camera.subSnapShot = value.toString();
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
      case 'username':
        camera.username = value.toString();
        break;
      case 'password':
        camera.password = value.toString();
        break;
      case 'recordcodec':
        camera.recordCodec = value.toString();
        break;
      case 'recordwidth':
        camera.recordWidth =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'recordheight':
        camera.recordHeight =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'subcodec':
        camera.subCodec = value.toString();
        break;
      case 'subwidth':
        camera.subWidth =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'subheight':
        camera.subHeight =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'camerarawip':
        camera.rawIp =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'soundrec':
        camera.soundRec =
            value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'recordpath':
        camera.recordPath = value.toString();
        break;
      case 'xaddr':
        camera.xAddr = value.toString();
        break;

      // 'connected' from cameras_mac might indicate the camera's own reported connection status
      case 'connected':
        camera.connected = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;

      // 'record' from cameras_mac/all_cameras - this is CONFIG data, not actual recording status!
      // Real recording status comes from cam[X].record and camreports.*.recording
      // So we IGNORE this value to avoid overwriting actual recording status with config values
      case 'record':
        print(
            'CDP_OPT: Ignoring cameras_mac/all_cameras record value ($value) for camera ${camera.mac} - this is config, not actual status');
        break;

      // Additional all_cameras properties
      case 'httppath':
        camera.recordPath = value.toString();
        break; // HTTP path for recordings
      case 'distribute':
        camera.distribute =
            value == 1 || value == true || value.toString() == '1';
        break; // Distribute flag
      case 'distribute_count':
        camera.distributeCount =
            value is int ? value : int.tryParse(value.toString()) ?? 1;
        print('CDP_OPT: Updated distribute_count for camera ${camera.mac} = ${camera.distributeCount}');
        break; // Distribute count - how many devices camera should be on
      case 'verified':
        camera.verified =
            value == 1 || value == true || value.toString() == '1';
        print('CDP_OPT: Updated verified for camera ${camera.mac} = ${camera.verified}');
        break; // Verified flag - camera is authorized and data accessible
      case 'onvif_connected':
        camera.onvifConnected =
            value == 1 || value == true || value.toString() == '1';
        print('CDP_OPT: Updated onvif_connected for camera ${camera.mac} = ${camera.onvifConnected}');
        break; // ONVIF connection status
      case 'last_onvif_seen':
        camera.lastOnvifSeen = value.toString();
        print('CDP_OPT: Updated last_onvif_seen for camera ${camera.mac} = ${camera.lastOnvifSeen}');
        break; // Last ONVIF seen timestamp
      case 'mac':
        camera.mac = value.toString();
        break; // MAC address

      default:
        print(
            'CDP_OPT: Unhandled MAC-defined camera property: $propertyName for camera ${camera.mac}');
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
  Future<void> _handleDeviceAssignment(
      Camera camera, List<String> parts, dynamic value) async {
    String assignmentType = parts[2]; // 'current' or 'history'

    if (assignmentType == 'current') {
      // Handle current device assignment: cameras_mac.MAC.current.DEVICE_MAC.property
      // parts[3] is the device MAC, parts[4] is the property name
      // A camera can be on MULTIPLE devices, so we use Map<DeviceMac, CameraCurrentDevice>
      if (parts.length >= 5) {
        String deviceMac = parts[3]; // Device MAC that camera is assigned to
        String property = parts[4]; // Property name

        // Update the specific property for this device
        await _updateCurrentDeviceAssignment(
            camera, deviceMac, property, value);
      }
    } else if (assignmentType == 'history') {
      // Handle history device assignment: cameras_mac.MAC.history.TIMESTAMP.property
      if (parts.length >= 5) {
        String timestamp = parts[3];
        String historyProperty = parts[4];
        await _updateHistoryDeviceAssignment(
            camera, timestamp, historyProperty, value);
      }
    }
  }

  // Update current device assignment for camera
  // Now uses deviceMac as key to support multiple device assignments
  Future<void> _updateCurrentDeviceAssignment(
      Camera camera, String deviceMac, String property, dynamic value) async {
    // Get or create the current device entry for this device MAC
    CameraCurrentDevice currentEntry = camera.currentDevices[deviceMac] ??
        CameraCurrentDevice(
          deviceMac: deviceMac,
          deviceIp: '',
          cameraIp: '',
          name: '',
          startDate: 0,
        );

    switch (property.toLowerCase()) {
      case 'device_mac':
        // Device MAC is already set as the key, but update the entry if needed
        currentEntry = currentEntry.copyWith(deviceMac: value.toString());
        
        // NOTE: Do NOT add camera to device.cameras here!
        // device.cameras should ONLY be populated from ecs_slaves.DEVICE_MAC.cam[X].mac data
        // This currentDevices info is just metadata about which device the camera is assigned to
        // The actual camera listing comes from the device's own cam[] array
        String newDeviceMac = value.toString();
        if (newDeviceMac.isNotEmpty) {
          print(
              'CDP_OPT: cameras_mac: Camera ${camera.mac} has current device_mac: $newDeviceMac (metadata only, not adding to device.cameras)');
        }
        break;
      case 'device_ip':
        currentEntry = currentEntry.copyWith(deviceIp: value.toString());
        break;
      case 'cameraip':
        currentEntry = currentEntry.copyWith(cameraIp: value.toString());
        break;
      case 'name':
        currentEntry = currentEntry.copyWith(name: value.toString());
        break;
      case 'start_date':
        int startDate =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
        currentEntry = currentEntry.copyWith(startDate: startDate);
        break;
      default:
        print(
            'CDP_OPT: Unhandled current device property: $property for camera ${camera.mac}');
    }

    // Store/update in the currentDevices map
    camera.currentDevices[deviceMac] = currentEntry;

    print(
        'CDP_OPT: Updated current device for camera ${camera.mac} on device $deviceMac: $currentEntry');
    print(
        'CDP_OPT: Camera ${camera.mac} now has ${camera.currentDevices.length} current device assignment(s)');
  }

  // Update history device assignment for camera
  Future<void> _updateHistoryDeviceAssignment(
      Camera camera, String timestamp, String property, dynamic value) async {
    // Timestamp format can be either:
    // - Single timestamp: "1767886903" 
    // - Combined startDate_endDate: "1767886903_1767886935"
    int startDateInt = 0;
    int endDateInt = 0;
    
    if (timestamp.contains('_')) {
      final parts = timestamp.split('_');
      startDateInt = int.tryParse(parts[0]) ?? 0;
      endDateInt = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    } else {
      startDateInt = int.tryParse(timestamp) ?? 0;
    }

    // Find existing history entry by startDate or create new one
    CameraHistoryDevice? historyEntry = camera.deviceHistory
        .where((h) => h.startDate == startDateInt)
        .firstOrNull;

    if (historyEntry == null) {
      historyEntry = CameraHistoryDevice(
        deviceMac: '',
        deviceIp: '',
        cameraIp: '',
        name: '',
        startDate: startDateInt,
        endDate: endDateInt,
      );
      camera.deviceHistory.add(historyEntry);
    } else if (endDateInt > 0 && historyEntry.endDate == 0) {
      // Update endDate if we have it from timestamp and entry doesn't have it yet
      int index = camera.deviceHistory.indexOf(historyEntry);
      camera.deviceHistory[index] = historyEntry.copyWith(endDate: endDateInt);
      historyEntry = camera.deviceHistory[index];
    }

    // Update the history entry based on property
    switch (property.toLowerCase()) {
      case 'device_mac':
        int index = camera.deviceHistory.indexOf(historyEntry);
        camera.deviceHistory[index] =
            historyEntry.copyWith(deviceMac: value.toString());
        break;
      case 'device_ip':
        int index = camera.deviceHistory.indexOf(historyEntry);
        camera.deviceHistory[index] =
            historyEntry.copyWith(deviceIp: value.toString());
        break;
      case 'cameraip':
        int index = camera.deviceHistory.indexOf(historyEntry);
        camera.deviceHistory[index] =
            historyEntry.copyWith(cameraIp: value.toString());
        break;
      case 'name':
        int index = camera.deviceHistory.indexOf(historyEntry);
        camera.deviceHistory[index] =
            historyEntry.copyWith(name: value.toString());
        break;
      case 'start_date':
        int startDate =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
        int index = camera.deviceHistory.indexOf(historyEntry);
        camera.deviceHistory[index] =
            historyEntry.copyWith(startDate: startDate);
        break;
      case 'end_date':
        int endDate =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
        int index = camera.deviceHistory.indexOf(historyEntry);
        camera.deviceHistory[index] = historyEntry.copyWith(endDate: endDate);
        break;
      default:
        print(
            'CDP_OPT: Unhandled history device property: $property for camera ${camera.mac}');
    }

    // Sort history by start date for consistent ordering
    camera.deviceHistory.sort((a, b) => b.startDate.compareTo(a.startDate));

    print(
        'CDP_OPT: Updated history for camera ${camera.mac}, entry count: ${camera.deviceHistory.length}');
  }

  // Add or update camera in device list
  // NOTE: Each device gets its own Camera instance (copy) to avoid shared state issues
  // with index and parentDeviceMacKey when same camera is on multiple devices
  void _addOrUpdateCameraInDeviceList(
      CameraDevice device, int cameraIndex, Camera sourceCamera) {
    print('CDP_OPT: 📥 _addOrUpdateCameraInDeviceList called:');
    print('CDP_OPT:    Device: ${device.macKey}');
    print('CDP_OPT:    Camera MAC: ${sourceCamera.mac}');
    print('CDP_OPT:    New Index: $cameraIndex');
    print('CDP_OPT:    Current device.cameras count: ${device.cameras.length}');
    
    // Remove any camera with the same index but different MAC (in case of MAC reassignment)
    final removedByIndex = device.cameras.where((c) => c.index == cameraIndex && c.mac != sourceCamera.mac).toList();
    if (removedByIndex.isNotEmpty) {
      print('CDP_OPT:    ⚠️ Removing ${removedByIndex.length} cameras with same index but different MAC');
    }
    device.cameras.removeWhere((c) => c.index == cameraIndex && c.mac != sourceCamera.mac);

    // Check if camera with same MAC already exists in this device
    final existingIndex = device.cameras.indexWhere((c) => c.mac == sourceCamera.mac);
    
    if (existingIndex >= 0) {
      // Camera already exists - update its index if needed
      final existingCamera = device.cameras[existingIndex];
      if (existingCamera.index != cameraIndex) {
        existingCamera.index = cameraIndex;
        print('CDP_OPT:    ℹ️ Updated existing camera ${sourceCamera.mac} index to $cameraIndex');
      }
      // Sync properties from source camera
      _syncCameraProperties(existingCamera, sourceCamera);
    } else {
      // Create a copy of the source camera for this device
      final deviceCamera = sourceCamera.copyWith(
        index: cameraIndex,
        parentDeviceMacKey: device.macKey,
      );
      device.cameras.add(deviceCamera);
      print('CDP_OPT:    ✅ Added camera copy ${sourceCamera.mac} to device at index $cameraIndex');
    }

    // Sort cameras by index for consistent ordering
    device.cameras.sort((a, b) => a.index.compareTo(b.index));
    
    print('CDP_OPT:    Final device.cameras count: ${device.cameras.length}');
  }
  
  // Sync properties from source camera to device camera
  void _syncCameraProperties(Camera target, Camera source) {
    if (source.name.isNotEmpty) target.name = source.name;
    if (source.ip.isNotEmpty) target.ip = source.ip;
    if (source.brand.isNotEmpty) target.brand = source.brand;
    if (source.hw.isNotEmpty) target.hw = source.hw;
    if (source.manufacturer.isNotEmpty) target.manufacturer = source.manufacturer;
    if (source.mediaUri.isNotEmpty) target.mediaUri = source.mediaUri;
    if (source.recordUri.isNotEmpty) target.recordUri = source.recordUri;
    if (source.subUri.isNotEmpty) target.subUri = source.subUri;
    if (source.mainSnapShot.isNotEmpty) target.mainSnapShot = source.mainSnapShot;
    if (source.subSnapShot.isNotEmpty) target.subSnapShot = source.subSnapShot;
    if (source.username.isNotEmpty) target.username = source.username;
    if (source.password.isNotEmpty) target.password = source.password;
    target.connected = source.connected;
    target.recordWidth = source.recordWidth;
    target.recordHeight = source.recordHeight;
    target.subWidth = source.subWidth;
    target.subHeight = source.subHeight;
    target.recordCodec = source.recordCodec;
    target.subCodec = source.subCodec;
    target.soundRec = source.soundRec;
    // Sync distribute properties from all_cameras/cameras_mac
    target.distribute = source.distribute;
    target.distributeCount = source.distributeCount;
    // Merge recording devices (per-device status from camreports)
    target.recordingDevices.addAll(source.recordingDevices);
    target.camReportsRecordingDevices.addAll(source.camReportsRecordingDevices);
    // Merge connected devices (per-device status from camreports)
    target.connectedDevices.addAll(source.connectedDevices);
    target.camReportsConnectedDevices.addAll(source.camReportsConnectedDevices);
    // Merge recordPath devices (per-device paths from camreports)
    target.recordPathDevices.addAll(source.recordPathDevices);
    target.camReportsRecordPathDevices.addAll(source.camReportsRecordPathDevices);
    // Merge disconnected devices (per-device timestamps from camreports)
    target.disconnectedDevices.addAll(source.disconnectedDevices);
    target.camReportsDisconnectedDevices.addAll(source.camReportsDisconnectedDevices);
    // Merge lastSeenAt devices (per-device timestamps from camreports)
    target.lastSeenAtDevices.addAll(source.lastSeenAtDevices);
    target.camReportsLastSeenAtDevices.addAll(source.camReportsLastSeenAtDevices);
    // Merge lastRestartTime devices (per-device timestamps from camreports)
    target.lastRestartTimeDevices.addAll(source.lastRestartTimeDevices);
    target.camReportsLastRestartTimeDevices.addAll(source.camReportsLastRestartTimeDevices);
    // Merge reported devices (per-device timestamps from camreports)
    target.reportedDevices.addAll(source.reportedDevices);
    target.camReportsReportedDevices.addAll(source.camReportsReportedDevices);
  }

  // Merge MAC-defined camera data with device cameras based on MAC address
  void _mergeMacDefinedCameraData() {
    for (var device in devices.values) {
      for (var deviceCamera in device.cameras) {
        // Find corresponding MAC-defined camera with same MAC address
        var macDefinedCamera = _macDefinedCameras[deviceCamera.mac];
        if (macDefinedCamera != null) {
          print(
              'CDP_OPT: Merging MAC-defined data for camera ${deviceCamera.mac}');

          // Merge current device assignments (can be multiple)
          if (macDefinedCamera.currentDevices.isNotEmpty) {
            deviceCamera.currentDevices =
                Map.from(macDefinedCamera.currentDevices);
          }

          // Merge history device assignments
          deviceCamera.deviceHistory =
              List<CameraHistoryDevice>.from(macDefinedCamera.deviceHistory);

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
          
          // Sync distribute properties from all_cameras/cameras_mac
          deviceCamera.distribute = macDefinedCamera.distribute;
          deviceCamera.distributeCount = macDefinedCamera.distributeCount;

          print(
              'CDP_OPT: Merged camera ${deviceCamera.mac}: Current devices: ${deviceCamera.currentDevices.keys.join(", ")}, History entries: ${deviceCamera.deviceHistory.length}');
        }
      }
    }
  }

  // Process WebSocket message
  Future<void> processWebSocketMessage(Map<String, dynamic> message) async {
    print(
        'CDP_OPT: 🔵 processWebSocketMessage CALLED with: ${message['data']}');
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

      if (dataPath.startsWith('cameras_mac.') ||
          dataPath.startsWith('all_cameras.')) {
        final parts = dataPath.split(
            '.'); // cameras_mac.CAMERA_MAC.property or all_cameras.CAMERA_MAC.property
        final sourceType = parts[0]; // cameras_mac or all_cameras
        print(
            'CDP_OPT: DATAPATH SPLIT: $dataPath -> Parts: $parts (length: ${parts.length}) [source: $sourceType]');
        if (parts.length >= 3) {
          final cameraMac = parts[1]; // This is the camera's own MAC address
          if (cameraMac.isNotEmpty) {
            print(
                'CDP_OPT: *** $sourceType: Processing ${parts[2]} for camera $cameraMac = $value ***');
            if (parts[2].startsWith('group[')) {
              print('CDP_OPT: 🎯 GROUP MESSAGE DETECTED: ${parts[2]} = $value');
            }
            final camera = _getOrCreateMacDefinedCamera(cameraMac);
            await _updateMacDefinedCameraProperty(camera, parts, value);
            print(
                'CDP_OPT: *** MAC-defined camera count: ${_macDefinedCameras.length} ***');
          } else {
            print(
                'CDP_OPT: Received $sourceType message with empty camera MAC in path: $dataPath');
          }
        } else {
          print('CDP_OPT: Invalid $sourceType path: $dataPath');
        }
        return; // Message handled
      }

      // Handle ecs.bridge_auto_cam_distributing.* messages (global settings, not per-device)
      if (dataPath.startsWith('ecs.bridge_auto_cam_distributing.')) {
        final settingName = dataPath.split('.').last;
        _processGlobalBridgeAutoSetting(settingName, value);
        return; // Message handled
      }

      // Handle configuration.* messages (global settings)
      if (dataPath.startsWith('configuration.')) {
        _processGlobalConfiguration(dataPath, value);
        return; // Message handled
      }

      // Handle networking.* messages (global network settings)
      if (dataPath.startsWith('networking.')) {
        _processNetworkingSettings(dataPath, value);
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

      final device =
          _getOrCreateDevice(canonicalDeviceMac, pathDeviceIdentifier);

      if (parts.length < 3) {
        print(
            'CDP_OPT: Path too short for device property, skipping: $dataPath');
        return;
      }

      // Determine message category and process accordingly
      String pathComponent = parts[2];
      List<String> remainingPath = parts.sublist(3);
      MessageCategory category =
          _categorizeMessage(pathComponent, remainingPath);

      switch (category) {
        case MessageCategory.camera:
          if (remainingPath.isNotEmpty) {
            await _processCameraData(
                device, pathComponent, remainingPath, value);
          } else {
            print(
                'CDP_OPT: Camera message but no property specified: $dataPath');
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
          await _processConfiguration(
              device, pathComponent, remainingPath, value);
          break;
        case MessageCategory.cameraGroupDefinition:
          await _processCameraGroupDefinition(
              device, pathComponent, remainingPath, value);
          break;
        case MessageCategory.cameraGroupAssignment:
          await _processCameraGroupAssignment(
              device, pathComponent, remainingPath, value);
          break;
        case MessageCategory.cameraReport:
          await _processCameraReport(
              device, pathComponent, remainingPath, value);
          _batchNotifyListeners();
          break;
        default:
          print('CDP_OPT: Unhandled message category for: $dataPath');
      }
    } catch (e, s) {
      print(
          'CDP_OPT: Error processing WebSocket message: $e\\n$s. Message: $message');
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
      print(
          'CDP_OPT: Error processing array message: $e\\n$s. Message: $message');
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

      print(
          'CDP_OPT: Camera array update - Device: $canonicalDeviceMac, Index: $cameraIndex, Property: $property, Value: $value');

      // Get or create the device
      final device = _getOrCreateDevice(canonicalDeviceMac, deviceMacPart);

      // NOTE: Camera array reset is now handled in _processCameraData when cam[0].mac arrives.
      // This function is for array-type val messages (List) which are rare.
      // Removed the reset logic here to avoid conflicts with the new MAC-based system.

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
          parentDeviceMacKey: canonicalDeviceMac,
          index: device.cameras.length,
        );
        device.cameras.add(newCamera);
        print(
            'CDP_OPT: Added camera slot ${device.cameras.length - 1} for device $canonicalDeviceMac');
      }

      // Update the camera property
      final camera = device.cameras[cameraIndex];
      await _updateCameraProperty(camera, property, value,
          deviceMac: canonicalDeviceMac);

      // NOTE: Do NOT add device cameras to global _macDefinedCameras!
      // _macDefinedCameras is for cameras_mac data (cameras/all_cameras screens)
      // device.cameras is for ecs_slaves data (camera_devices screen)
      // These are separate data sources and should not be mixed.

      _batchNotifyListeners();
    } catch (e, s) {
      print(
          'CDP_OPT: Error processing camera array message: $e\\n$s. Message: $message');
    }
  }

  // Update individual camera property
  Future<void> _updateCameraProperty(
      Camera camera, String property, dynamic value,
      {String? deviceMac}) async {
    switch (property) {
      case 'mac':
        final newMac = value?.toString() ?? '';
        if (newMac.isEmpty) break;
        
        // Simply set the MAC address - no global list manipulation
        // device.cameras is independent from _macDefinedCameras
        camera.mac = newMac;
        print('CDP_OPT: ✅ Camera MAC set: ${camera.mac}');
        break;
      case 'name':
        camera.name = value?.toString() ?? '';
        break;
      case 'cameraIp':
      case 'cameraip':
      case 'ip':
        camera.ip = value?.toString() ?? '';
        print('CDP_OPT: 🌐 Set camera.ip for ${camera.mac} (${camera.name}) = ${camera.ip}');
        break;
      case 'username':
        camera.username = value?.toString() ?? '';
        break;
      case 'password':
        camera.password = value?.toString() ?? '';
        break;
      case 'port':
        camera.macPort = value is int
            ? value
            : (int.tryParse(value?.toString() ?? '') ?? 80);
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
        // Recording is per-device, store in recordingDevices map
        final isRecording = (value == 1 ||
            value == true ||
            value?.toString().toLowerCase() == 'true');
        final recordDeviceMac =
            deviceMac ?? camera.parentDeviceMacKey ?? 'unknown';
        camera.recordingDevices[recordDeviceMac] = isRecording;
        print(
            'CDP_OPT: Camera ${camera.mac} recording on device $recordDeviceMac: $isRecording (total: ${camera.recordingCount} devices)');
        break;
      case 'soundRec':
        camera.soundRec =
            (value == true || value?.toString().toLowerCase() == 'true');
        break;
      case 'recordcodec':
        camera.recordCodec = value?.toString() ?? '';
        break;
      case 'subcodec':
        camera.subCodec = value?.toString() ?? '';
        break;
      case 'recordwidth':
        camera.recordWidth =
            value is int ? value : (int.tryParse(value?.toString() ?? '') ?? 0);
        break;
      case 'recordheight':
        camera.recordHeight =
            value is int ? value : (int.tryParse(value?.toString() ?? '') ?? 0);
        break;
      case 'subwidth':
        camera.subWidth =
            value is int ? value : (int.tryParse(value?.toString() ?? '') ?? 0);
        break;
      case 'subheight':
        camera.subHeight =
            value is int ? value : (int.tryParse(value?.toString() ?? '') ?? 0);
        break;
      case 'xAddrs':
        camera.xAddrs = value?.toString() ?? '';
        break;
      default:
        print('CDP_OPT: Unhandled camera property: $property = $value');
    }

    print(
        'CDP_OPT: Updated camera ${camera.name} (${camera.mac}) property $property = $value');
  }

  // Categorize messages
  MessageCategory _categorizeMessage(
      String pathComponent, List<String> remainingPath) {
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
    if (pathComponent == 'configuration' &&
        remainingPath.isNotEmpty &&
        remainingPath[0].startsWith('cameraGroups')) {
      return MessageCategory.cameraGroupDefinition;
    }

    // Camera group assignment
    if (pathComponent.startsWith('cam') &&
        remainingPath.isNotEmpty &&
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
    } else if (pathComponent == 'system' ||
        pathComponent == 'cpuTemp' ||
        pathComponent.contains('version')) {
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
  CameraDevice _getOrCreateDevice(
      String canonicalDeviceMac, String originalPathMacKey) {
    if (!_devices.containsKey(canonicalDeviceMac)) {
      print(
          'CDP_OPT: *** Creating new device: $canonicalDeviceMac (pathKey: $originalPathMacKey) ***');
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
  Future<void> _processCameraData(CameraDevice device, String camIndexPath,
      List<String> camPathProperties, dynamic value) async {
    // camIndexPath is "cam[0]", camPathProperties is ["name"] or ["status", "power"] etc.
    String indexStr = camIndexPath.substring(4, camIndexPath.indexOf(']'));
    int cameraIndex = int.tryParse(indexStr) ?? -1;

    if (cameraIndex < 0) {
      print('CDP_OPT: Invalid camera index: $camIndexPath');
      return;
    }

    String propertyName = camPathProperties.first;
    print(
        'CDP_OPT: Processing ecs_slaves data: Device ${device.macAddress}, cam[$cameraIndex].$propertyName = $value');

    Camera? cameraToUpdate;

    if (propertyName == 'mac') {
      // This is the camera's own MAC address from ecs_slaves path
      String cameraMacFromMessage = value.toString();
      print(
          'CDP_OPT: *** MAC ASSIGNMENT: Device ${device.macKey} cam[$cameraIndex].mac = "$cameraMacFromMessage" ***');
      if (cameraMacFromMessage.isNotEmpty) {
        // When cam[0].mac arrives, this is the start of a new camera configuration.
        // Clear any cameras with index >= current max expected (to handle config changes)
        if (cameraIndex == 0 && device.cameras.isNotEmpty) {
          print('CDP_OPT: *** cam[0].mac received - NEW CONFIG starting for device ${device.macKey} ***');
          print('CDP_OPT: *** Clearing ${device.cameras.length} existing cameras ***');
          device.cameras.clear();
          // Also clear pending properties for this device
          _pendingCameraProperties.removeWhere((key, _) => key.startsWith('${device.macKey}:'));
        }
        
        // Get or create the source camera in _macDefinedCameras
        final sourceCamera = _getOrCreateMacDefinedCamera(cameraMacFromMessage);
        // Add a copy to device's camera list
        _addOrUpdateCameraInDeviceList(device, cameraIndex, sourceCamera);
        print(
            'CDP_OPT: *** Successfully linked camera ${sourceCamera.mac} to device ${device.macKey} at index $cameraIndex ***');
        print(
            'CDP_OPT: *** Device ${device.macKey} now has ${device.cameras.length} cameras ***');
        
        // Apply any buffered properties that arrived before MAC
        final bufferKey = '${device.macKey}:$cameraIndex';
        if (_pendingCameraProperties.containsKey(bufferKey)) {
          final bufferedProps = _pendingCameraProperties[bufferKey]!;
          print('CDP_OPT: *** Applying ${bufferedProps.length} buffered properties for $bufferKey ***');
          
          // Find the device camera copy to update
          final deviceCamera = device.cameras.firstWhere(
            (c) => c.mac == cameraMacFromMessage,
            orElse: () => sourceCamera,
          );
          
          for (var entry in bufferedProps.entries) {
            // Apply to both source and device copy
            _applyCameraProperty(sourceCamera, entry.key, entry.value, device.macKey);
            if (!identical(deviceCamera, sourceCamera)) {
              _applyCameraProperty(deviceCamera, entry.key, entry.value, device.macKey);
            }
          }
          _pendingCameraProperties.remove(bufferKey);
        }
        cameraToUpdate = sourceCamera; // For the final property application
      } else {
        print(
            'CDP_OPT: *** ERROR: Received empty MAC for cam[$cameraIndex] on device ${device.macAddress}. Cannot link or update. ***');
        return;
      }
    } else {
      // For other properties (name, ip, etc.), find the camera already associated with this device and index
      // It should have been linked previously by a 'mac' property message.
      var camsInDevice =
          device.cameras.where((cam) => cam.index == cameraIndex).toList();
      if (camsInDevice.isNotEmpty) {
        cameraToUpdate = camsInDevice.first; // This is the device-specific copy
        if (camsInDevice.length > 1) {
          print(
              "CDP_OPT: WARNING - Multiple cameras found for device ${device.macKey} at index $cameraIndex. Using first: ${cameraToUpdate.mac}. All: ${camsInDevice.map((c) => c.mac).join(',')}");
        }
        
        // Also update the source camera in _macDefinedCameras
        final sourceCamera = _macDefinedCameras[cameraToUpdate.mac];
        if (sourceCamera != null && !identical(sourceCamera, cameraToUpdate)) {
          _applyCameraProperty(sourceCamera, propertyName, value, device.macKey);
        }
      } else {
        // Camera not yet created - buffer this property for when MAC arrives
        final bufferKey = '${device.macKey}:$cameraIndex';
        _pendingCameraProperties.putIfAbsent(bufferKey, () => {});
        _pendingCameraProperties[bufferKey]![propertyName] = value;
        print(
            'CDP_OPT: *** Buffered property $propertyName for $bufferKey (waiting for MAC) ***');
        return;
      }
    }

    // Now update the identified cameraToUpdate with the property from ecs_slaves
    _applyCameraProperty(cameraToUpdate, propertyName, value, device.macKey);

    _batchNotifyListeners();
  }

  // Apply a single property to a camera object
  void _applyCameraProperty(Camera camera, String propertyName, dynamic value, String deviceMacKey) {
    switch (propertyName.toLowerCase()) {
      case 'name':
        camera.name = value.toString();
        break;
      case 'ip':
      case 'cameraip':
        camera.ip = value.toString();
        print('CDP_OPT: 📍 Camera ${camera.mac} IP set to: ${camera.ip}');
        break;
      case 'connected':
        camera.connected = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
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
      case 'mainsnapshot':
        camera.mainSnapShot = value.toString();
        break;
      case 'subsnapshot':
        camera.subSnapShot = value.toString();
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
      case 'username':
        camera.username = value.toString();
        break;
      case 'password':
        camera.password = value.toString();
        break;
      case 'recordcodec':
        camera.recordCodec = value.toString();
        break;
      case 'recordwidth':
        camera.recordWidth =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'recordheight':
        camera.recordHeight =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'subcodec':
        camera.subCodec = value.toString();
        break;
      case 'subwidth':
        camera.subWidth =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'subheight':
        camera.subHeight =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'camerarawip':
        camera.rawIp =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
        break;
      case 'soundrec':
        camera.soundRec =
            value == true || value.toString().toLowerCase() == 'true';
        break;
      case 'record':
        // Recording is per-device, store in recordingDevices map
        final isRecording = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        camera.recordingDevices[deviceMacKey] = isRecording;
        print(
            'CDP_OPT: Camera ${camera.mac} recording on device $deviceMacKey: $isRecording (total: ${camera.recordingCount} devices)');
        break;
      case 'recordpath':
        camera.recordPath = value.toString();
        break;
      case 'xaddr':
      case 'xaddrs':
        camera.xAddr = value.toString();
        break;
      default:
        print('CDP_OPT: Unhandled ecs_slaves camera property: $propertyName');
        break;
    }
  }

  // Process basic device properties
  Future<void> _processBasicDeviceProperty(
      CameraDevice device, String property, dynamic value) async {
    switch (property.toLowerCase()) {
      case 'online':
        device.online = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'connected':
        device.connected = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
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
        print(
            'CDP_OPT: Device ${device.macAddress} last_seen_at updated: ${device.lastSeenAt}');
        break;
      case 'last_heartbeat_ts':
        device.lastHeartbeatTs = int.tryParse(value.toString()) ?? 0;
        print(
            'CDP_OPT: Device ${device.macAddress} last_heartbeat_ts updated: $value');
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
        print(
            'CDP_OPT: Device ${device.macAddress} cpuTemp updated: ${device.cpuTemp}');
        break;
      case 'totalram':
        device.totalRam = int.tryParse(value.toString()) ?? 0;
        print(
            'CDP_OPT: Device ${device.macAddress} totalRam updated: ${device.totalRam}');
        break;
      case 'freeram':
        device.freeRam = int.tryParse(value.toString()) ?? 0;
        print(
            'CDP_OPT: Device ${device.macAddress} freeRam updated: ${device.freeRam}');
        break;
      case 'totalconns':
        device.totalConnections = int.tryParse(value.toString()) ?? 0;
        print(
            'CDP_OPT: Device ${device.macAddress} totalConnections updated: ${device.totalConnections}');
        break;
      case 'sessions':
        device.totalSessions = int.tryParse(value.toString()) ?? 0;
        print(
            'CDP_OPT: Device ${device.macAddress} totalSessions updated: ${device.totalSessions}');
        break;
      case 'eth0':
        device.networkInfo = value.toString();
        print(
            'CDP_OPT: Device ${device.macAddress} networkInfo updated: ${device.networkInfo}');
        break;
      case 'smartweb_version':
        device.smartwebVersion = value.toString();
        print(
            'CDP_OPT: Device ${device.macAddress} smartwebVersion updated: ${device.smartwebVersion}');
        break;
      case 'cam_count':
        device.camCount = int.tryParse(value.toString()) ?? 0;
        print(
            'CDP_OPT: Device ${device.macAddress} camCount updated: ${device.camCount}');
        break;
      case 'is_master':
      case 'ismaster':
        device.isMaster = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        print(
            'CDP_OPT: Device ${device.macAddress} isMaster updated: ${device.isMaster}');
        break;
      case 'last_ts':
        device.lastTs = value.toString();
        print(
            'CDP_OPT: Device ${device.macAddress} lastTs updated: ${device.lastTs}');
        break;
      case 'name':
        device.deviceName = value.toString();
        print(
            'CDP_OPT: Device ${device.macAddress} name updated: ${device.deviceName}');
        break;
      case 'ipv6':
        device.ipv6 = value.toString();
        break;

      // Ready states from device_info.json
      case 'app_ready':
        device.appReady = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'system_ready':
        device.systemReady = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'programs_ready':
        device.programsReady = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'cam_ready':
        device.camReady = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'configuration_ready':
        device.configurationReady = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'camreports_ready':
        device.camreportsReady = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'movita_ready':
        device.movitaReady = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;

      // Device status fields
      case 'registered':
        device.registered = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
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
        device.isClosedByMaster = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'offline_since':
        device.offlineSince = int.tryParse(value.toString()) ?? 0;
        break;

      default:
        print(
            'CDP_OPT: Unhandled basic device property: $property for device ${device.macAddress}');
        break;
    }
  }

  // Process system info
  Future<void> _processSystemInfo(CameraDevice device, String property,
      List<String> subPath, dynamic value) async {
    // Handle system information updates from device_info.json
    if (subPath.isEmpty) {
      print(
          'CDP_OPT: System info update for ${device.macAddress}: $property = $value');
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
        device.gpsOk = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'ignition':
        device.ignition = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'internetexists':
        device.internetExists = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
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
        device.shmcReady = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'timeset':
        device.timeset = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'uykumodu':
        device.uykumodu = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      default:
        print(
            'CDP_OPT: Unhandled system property: $systemProperty for device ${device.macAddress}');
        break;
    }
    print(
        'CDP_OPT: System info update for ${device.macAddress}: $property.$systemProperty = $value');
  }

  // Process app config
  Future<void> _processAppConfig(CameraDevice device, String property,
      List<String> subPath, dynamic value) async {
    // Handle app configuration updates from device_info.json
    if (subPath.isEmpty) {
      print(
          'CDP_OPT: App config update for ${device.macAddress}: $property = $value');
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
        device.appRecording = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
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
        device.gpsDataFlowStatus = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'int_connection':
      case 'intconnection':
        device.intConnection = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'record_over_tcp':
      case 'recordovertcp':
        device.recordOverTcp = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'ppp':
        device.ppp = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
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
        print(
            'CDP_OPT: Unhandled app property: $appProperty for device ${device.macAddress}');
        break;
    }
    print(
        'CDP_OPT: App config update for ${device.macAddress}: $property.$appProperty = $value');
  }

  // Process test data
  Future<void> _processTestData(CameraDevice device, String property,
      List<String> subPath, dynamic value) async {
    // Handle test data updates from device_info.json
    if (subPath.isEmpty) {
      print(
          'CDP_OPT: Test data update for ${device.macAddress}: $property = $value');
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
        device.testIsError = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        break;
      case 'uptime':
        device.testUptime = value.toString();
        break;
      default:
        print(
            'CDP_OPT: Unhandled test property: $testProperty for device ${device.macAddress}');
        break;
    }
    print(
        'CDP_OPT: Test data update for ${device.macAddress}: $property.$testProperty = $value');
  }

  // Process global bridge_auto_cam_distributing settings (from ecs.bridge_auto_cam_distributing.*)
  void _processGlobalBridgeAutoSetting(String settingName, dynamic value) {
    switch (settingName) {
      case 'masterhascams':
        _masterHasCams = value == 1 || value == true;
        print('CDP_OPT: ⚙️ Global MasterHasCams updated: $_masterHasCams');
        break;
      case 'auto_cam_distribute':
        _autoCameraDistributingEnabled = value == 1 || value == true;
        print(
            'CDP_OPT: ⚙️ Global AutoCamDistribute updated: $_autoCameraDistributingEnabled');
        break;
      case 'last_scan_imbalance':
        _imbalanceThreshold = int.tryParse(value.toString()) ?? 2;
        print(
            'CDP_OPT: ⚙️ Global ImbalanceThreshold updated: $_imbalanceThreshold');
        break;
      case 'last_scan_total_cameras':
        _lastScanTotalCameras = int.tryParse(value.toString()) ?? 0;
        print(
            'CDP_OPT: ⚙️ Global LastScanTotalCameras updated: $_lastScanTotalCameras');
        break;
      case 'last_scan_connected_cameras':
        _lastScanConnectedCameras = int.tryParse(value.toString()) ?? 0;
        print(
            'CDP_OPT: ⚙️ Global LastScanConnectedCameras updated: $_lastScanConnectedCameras');
        break;
      case 'last_scan_active_slaves':
        _lastScanActiveSlaves = int.tryParse(value.toString()) ?? 0;
        print(
            'CDP_OPT: ⚙️ Global LastScanActiveSlaves updated: $_lastScanActiveSlaves');
        break;
      case 'last_cam_distributed_at':
        _lastCamDistributedAt = value.toString();
        print(
            'CDP_OPT: ⚙️ Global LastCamDistributedAt updated: $_lastCamDistributedAt');
        break;
      case 'is_cam_distributed':
        // Could be used for status
        print('CDP_OPT: ⚙️ Global IsCamDistributed: $value');
        break;
      default:
        print(
            'CDP_OPT: ⚙️ Unhandled global bridge setting: $settingName = $value');
    }
    _batchNotifyListeners();
  }

  // Process global configuration settings (from configuration.*)
  void _processGlobalConfiguration(String dataPath, dynamic value) {
    // configuration.autoscan
    if (dataPath == 'configuration.autoscan') {
      _autoScanEnabled = value == true ||
          value == 1 ||
          value.toString().toLowerCase() == 'true';
      print('CDP_OPT: ⚙️ Global AutoScan updated: $_autoScanEnabled');
      _batchNotifyListeners();
      return;
    }

    // configuration.onvif.passwords[X]
    if (dataPath.contains('onvif.passwords')) {
      final indexMatch = RegExp(r'passwords\[(\d+)\]').firstMatch(dataPath);
      if (indexMatch != null) {
        final index = int.parse(indexMatch.group(1)!);
        final passwordValue = value.toString();

        // Ensure list is large enough
        while (_onvifPasswords.length <= index) {
          _onvifPasswords.add('');
        }
        _onvifPasswords[index] = passwordValue;

        // Remove empty entries
        _onvifPasswords = _onvifPasswords.where((p) => p.isNotEmpty).toList();

        print('CDP_OPT: ⚙️ Global ONVIF Passwords updated: $_onvifPasswords');
        _batchNotifyListeners();
      }
    }
  }

  // Process networking settings (from networking.*)
  void _processNetworkingSettings(String dataPath, dynamic value) {
    final settingName = dataPath.replaceFirst('networking.', '');

    switch (settingName) {
      case 'default_ip':
        _networkDefaultIp = value.toString();
        print('CDP_OPT: 🌐 Network DefaultIP updated: $_networkDefaultIp');
        break;
      case 'default_netmask':
        _networkDefaultNetmask = value.toString();
        print(
            'CDP_OPT: 🌐 Network DefaultNetmask updated: $_networkDefaultNetmask');
        break;
      case 'default_gw':
        _networkDefaultGw = value.toString();
        print('CDP_OPT: 🌐 Network DefaultGW updated: $_networkDefaultGw');
        break;
      case 'default_dns':
        _networkDefaultDns = value.toString();
        print('CDP_OPT: 🌐 Network DefaultDNS updated: $_networkDefaultDns');
        break;
      case 'default_ip_start':
        _networkDefaultIpStart = value.toString();
        print(
            'CDP_OPT: 🌐 Network DefaultIpStart updated: $_networkDefaultIpStart');
        break;
      case 'default_ip_end':
        _networkDefaultIpEnd = value.toString();
        print(
            'CDP_OPT: 🌐 Network DefaultIpEnd updated: $_networkDefaultIpEnd');
        break;
      case 'default_lease_time':
        _networkDefaultLeaseTime = value.toString();
        print(
            'CDP_OPT: 🌐 Network LeaseTime updated: $_networkDefaultLeaseTime');
        break;
      case 'share_internet':
        _networkShareInternet = value == 1 || value == true;
        print(
            'CDP_OPT: 🌐 Network ShareInternet updated: $_networkShareInternet');
        break;
      case 'dhcp':
        _networkDhcp = value == 1 || value == true;
        print('CDP_OPT: 🌐 Network DHCP updated: $_networkDhcp');
        break;
      default:
        print('CDP_OPT: 🌐 Unhandled network setting: $settingName = $value');
    }
    _batchNotifyListeners();
  }

  // Process configuration
  Future<void> _processConfiguration(CameraDevice device, String property,
      List<String> subPath, dynamic value) async {
    // Handle configuration updates
    print(
        'CDP_OPT: Configuration update for ${device.macAddress}: $property.$subPath = $value');

    final fullPath =
        subPath.isNotEmpty ? '$property.${subPath.join('.')}' : property;

    // Process autoscan setting
    if (fullPath == 'configuration.autoscan' || property == 'autoscan') {
      _autoScanEnabled = value == true ||
          value == 1 ||
          value.toString().toLowerCase() == 'true';
      print('CDP_OPT: ⚙️ AutoScan updated: $_autoScanEnabled');
      _batchNotifyListeners();
    }

    // Process bridge_auto_cam_distributing settings
    if (fullPath.contains('bridge_auto_cam_distributing') ||
        property.contains('bridge_auto_cam_distributing')) {
      final settingName =
          subPath.isNotEmpty ? subPath.last : property.split('.').last;

      switch (settingName) {
        case 'masterhascams':
          _masterHasCams = value == 1 || value == true;
          print('CDP_OPT: ⚙️ MasterHasCams updated: $_masterHasCams');
          break;
        case 'auto_cam_distribute':
          _autoCameraDistributingEnabled = value == 1 || value == true;
          print(
              'CDP_OPT: ⚙️ AutoCamDistribute updated: $_autoCameraDistributingEnabled');
          break;
        case 'last_scan_imbalance':
          _imbalanceThreshold = int.tryParse(value.toString()) ?? 2;
          print('CDP_OPT: ⚙️ ImbalanceThreshold updated: $_imbalanceThreshold');
          break;
        case 'last_scan_total_cameras':
          _lastScanTotalCameras = int.tryParse(value.toString()) ?? 0;
          print(
              'CDP_OPT: ⚙️ LastScanTotalCameras updated: $_lastScanTotalCameras');
          break;
        case 'last_scan_connected_cameras':
          _lastScanConnectedCameras = int.tryParse(value.toString()) ?? 0;
          print(
              'CDP_OPT: ⚙️ LastScanConnectedCameras updated: $_lastScanConnectedCameras');
          break;
        case 'last_scan_active_slaves':
          _lastScanActiveSlaves = int.tryParse(value.toString()) ?? 0;
          print(
              'CDP_OPT: ⚙️ LastScanActiveSlaves updated: $_lastScanActiveSlaves');
          break;
        case 'last_cam_distributed_at':
          _lastCamDistributedAt = value.toString();
          print(
              'CDP_OPT: ⚙️ LastCamDistributedAt updated: $_lastCamDistributedAt');
          break;
      }
      _batchNotifyListeners();
    }

    // Process ONVIF passwords (e.g., configuration.onvif.passwords[0])
    if (fullPath.contains('onvif.passwords')) {
      final indexMatch = RegExp(r'passwords\[(\d+)\]').firstMatch(fullPath);
      if (indexMatch != null) {
        final index = int.parse(indexMatch.group(1)!);
        final passwordValue = value.toString();

        // Ensure list is large enough
        while (_onvifPasswords.length <= index) {
          _onvifPasswords.add('');
        }
        _onvifPasswords[index] = passwordValue;

        // Remove empty entries
        _onvifPasswords = _onvifPasswords.where((p) => p.isNotEmpty).toList();

        print('CDP_OPT: ⚙️ ONVIF Passwords updated: $_onvifPasswords');
        _batchNotifyListeners();
      }
    }
    
    // Process service.smart_player.on and service.recorder.on for this device
    // Path format: configuration.service.smart_player.on or configuration.service.recorder.on
    if (fullPath.contains('service.smart_player.on') || 
        (subPath.length >= 3 && subPath[0] == 'service' && subPath[1] == 'smart_player' && subPath[2] == 'on')) {
      final isOn = value == 1 || value == true || value.toString() == '1';
      device.smartPlayerServiceOn = isOn;
      print('CDP_OPT: ⚙️ Smart Player Service for ${device.macAddress}: ${isOn ? "ON" : "OFF"}');
      _batchNotifyListeners();
    }
    
    if (fullPath.contains('service.recorder.on') || 
        (subPath.length >= 3 && subPath[0] == 'service' && subPath[1] == 'recorder' && subPath[2] == 'on')) {
      final isOn = value == 1 || value == true || value.toString() == '1';
      device.recorderServiceOn = isOn;
      print('CDP_OPT: ⚙️ Recorder Service for ${device.macAddress}: ${isOn ? "ON" : "OFF"}');
      _batchNotifyListeners();
    }
  }

  // Process camera group definition
  Future<void> _processCameraGroupDefinition(CameraDevice device,
      String property, List<String> subPath, dynamic value) async {
    // Handle camera group definition updates
    print(
        'CDP_OPT: Camera group definition update for ${device.macAddress}: $property = $value');
  }

  // Process camera group assignment
  Future<void> _processCameraGroupAssignment(CameraDevice device,
      String property, List<String> subPath, dynamic value) async {
    // Handle camera group assignment updates
    print(
        'CDP_OPT: Camera group assignment update for ${device.macAddress}: $property = $value');
  }

  // Process camera report
  // NOTE: camreports data is DEVICE-SPECIFIC - each device reports its own view of the camera
  // connected, recording, last_seen_at etc. are per-device values
  Future<void> _processCameraReport(CameraDevice device, String property,
      List<String> subPath, dynamic value) async {
    // Handle camera report updates
    // Path format: camreports.CAMERA_NAME.property (e.g., camreports.KAMERA35.connected)
    print(
        'CDP_OPT: 📊 Camera report update for device ${device.macKey}: $property subPath=$subPath val=$value');

    if (subPath.isEmpty) return;

    final cameraName = subPath[0]; // e.g., "KAMERA35"
    final reportProperty =
        subPath.length > 1 ? subPath[1] : ''; // e.g., "connected", "recording"

    // Find camera in THIS DEVICE's camera list (device-specific copy)
    Camera? deviceCamera;
    for (var camera in device.cameras) {
      if (camera.name == cameraName) {
        deviceCamera = camera;
        break;
      }
    }

    if (deviceCamera == null) {
      print(
          'CDP_OPT: ⚠️ Camera $cameraName not found in device ${device.macKey} cameras list');
      return;
    }

    print('CDP_OPT: 🎯 Found camera $cameraName in device ${device.macKey} (MAC: ${deviceCamera.mac})');

    // Update device-specific camera properties based on report
    switch (reportProperty) {
      case 'connected':
        final isConnected = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        final oldValue = deviceCamera.connectedDevices[device.macKey];
        // Connected is per-device, store with device key
        deviceCamera.connectedDevices[device.macKey] = isConnected;
        // Mark that we received camreports connected info for this device
        deviceCamera.camReportsConnectedDevices.add(device.macKey);
        // Also update the general connected property for backward compatibility
        deviceCamera.connected = isConnected;
        print(
            'CDP_OPT: ⚡ Device ${device.macKey} camera ${deviceCamera.name} connected: $oldValue -> $isConnected (device-specific)');
        break;
        
      case 'recording':
        final isRecording = value == 1 ||
            value == true ||
            value.toString().toLowerCase() == 'true';
        // Recording is per-device, store with device key
        deviceCamera.recordingDevices[device.macKey] = isRecording;
        // Mark that we received camreports recording info for this device
        deviceCamera.camReportsRecordingDevices.add(device.macKey);
        print(
            'CDP_OPT: 🔴 Device ${device.macKey} camera ${deviceCamera.name} recording: $isRecording (device-specific)');
        break;
        
      case 'last_seen_at':
        final lastSeenAtValue = value.toString();
        // LastSeenAt is per-device, store with device key
        deviceCamera.lastSeenAtDevices[device.macKey] = lastSeenAtValue;
        deviceCamera.camReportsLastSeenAtDevices.add(device.macKey);
        // Also update the general lastSeenAt property for backward compatibility
        deviceCamera.lastSeenAt = lastSeenAtValue;
        print(
            'CDP_OPT: 📅 Device ${device.macKey} camera ${deviceCamera.name} lastSeenAt: $lastSeenAtValue (device-specific)');
        break;
        
      case 'last_restart_time':
        final lastRestartTimeValue = value.toString();
        // LastRestartTime is per-device, store with device key
        deviceCamera.lastRestartTimeDevices[device.macKey] = lastRestartTimeValue;
        deviceCamera.camReportsLastRestartTimeDevices.add(device.macKey);
        // Also update the general lastRestartTime property for backward compatibility
        deviceCamera.lastRestartTime = lastRestartTimeValue;
        print(
            'CDP_OPT: 🔄 Device ${device.macKey} camera ${deviceCamera.name} lastRestartTime: $lastRestartTimeValue (device-specific)');
        break;
        
      case 'reported':
        final reportedValue = value.toString();
        // Reported is per-device, store with device key
        deviceCamera.reportedDevices[device.macKey] = reportedValue;
        deviceCamera.camReportsReportedDevices.add(device.macKey);
        // Also update the general reportName property for backward compatibility
        deviceCamera.reportName = reportedValue;
        print(
            'CDP_OPT: 📋 Device ${device.macKey} camera ${deviceCamera.name} reported: $reportedValue (device-specific)');
        break;
        
      case 'health':
        deviceCamera.health = value.toString();
        print(
            'CDP_OPT: 💚 Device ${device.macKey} camera ${deviceCamera.name} health: ${deviceCamera.health}');
        break;
        
      case 'report_error':
        deviceCamera.reportError = value.toString();
        print(
            'CDP_OPT: ⚠️ Device ${device.macKey} camera ${deviceCamera.name} reportError: ${deviceCamera.reportError}');
        break;
        
      case 'recordingpath':
      case 'recordingPath':
        final recordPathValue = value.toString();
        // RecordPath is per-device, store with device key
        deviceCamera.recordPathDevices[device.macKey] = recordPathValue;
        // Mark that we received camreports recordPath info for this device
        deviceCamera.camReportsRecordPathDevices.add(device.macKey);
        // Also update the general recordPath property for backward compatibility
        deviceCamera.recordPath = recordPathValue;
        print(
            'CDP_OPT: 📁 Device ${device.macKey} camera ${deviceCamera.name} recordPath: $recordPathValue (device-specific)');
        break;
        
      case 'disconnected':
        final disconnectedValue = value.toString();
        // Disconnected timestamp is per-device, store with device key
        deviceCamera.disconnectedDevices[device.macKey] = disconnectedValue;
        deviceCamera.camReportsDisconnectedDevices.add(device.macKey);
        // Also update the general disconnected property for backward compatibility
        deviceCamera.disconnected = disconnectedValue;
        print(
            'CDP_OPT: 🔌 Device ${device.macKey} camera ${deviceCamera.name} disconnected: $disconnectedValue (device-specific)');
        break;
        
      default:
        print(
            'CDP_OPT: ❓ Unknown camreport property: $reportProperty for camera $cameraName on device ${device.macKey}');
    }

    // CRITICAL: Sync camreports data to _macDefinedCameras so UI can see it
    // The UI uses _macDefinedCameras for display, so we must sync device-specific data there
    final macDefinedCamera = _macDefinedCameras[deviceCamera.mac];
    if (macDefinedCamera != null) {
      // Sync only if deviceCamera has data for this device
      if (deviceCamera.connectedDevices.containsKey(device.macKey)) {
        macDefinedCamera.connectedDevices[device.macKey] = deviceCamera.connectedDevices[device.macKey]!;
        macDefinedCamera.camReportsConnectedDevices.add(device.macKey);
      }
      
      if (deviceCamera.recordingDevices.containsKey(device.macKey)) {
        macDefinedCamera.recordingDevices[device.macKey] = deviceCamera.recordingDevices[device.macKey]!;
        macDefinedCamera.camReportsRecordingDevices.add(device.macKey);
      }
      
      if (deviceCamera.recordPathDevices.containsKey(device.macKey)) {
        macDefinedCamera.recordPathDevices[device.macKey] = deviceCamera.recordPathDevices[device.macKey]!;
        macDefinedCamera.camReportsRecordPathDevices.add(device.macKey);
      }
      
      if (deviceCamera.disconnectedDevices.containsKey(device.macKey)) {
        macDefinedCamera.disconnectedDevices[device.macKey] = deviceCamera.disconnectedDevices[device.macKey]!;
        macDefinedCamera.camReportsDisconnectedDevices.add(device.macKey);
      }
      
      if (deviceCamera.lastSeenAtDevices.containsKey(device.macKey)) {
        macDefinedCamera.lastSeenAtDevices[device.macKey] = deviceCamera.lastSeenAtDevices[device.macKey]!;
        macDefinedCamera.camReportsLastSeenAtDevices.add(device.macKey);
      }
      
      if (deviceCamera.lastRestartTimeDevices.containsKey(device.macKey)) {
        macDefinedCamera.lastRestartTimeDevices[device.macKey] = deviceCamera.lastRestartTimeDevices[device.macKey]!;
        macDefinedCamera.camReportsLastRestartTimeDevices.add(device.macKey);
      }
      
      if (deviceCamera.reportedDevices.containsKey(device.macKey)) {
        macDefinedCamera.reportedDevices[device.macKey] = deviceCamera.reportedDevices[device.macKey]!;
        macDefinedCamera.camReportsReportedDevices.add(device.macKey);
      }
      
      // Also sync general properties for backward compatibility
      macDefinedCamera.connected = deviceCamera.connected;
      macDefinedCamera.lastSeenAt = deviceCamera.lastSeenAt;
      macDefinedCamera.disconnected = deviceCamera.disconnected;
      macDefinedCamera.lastRestartTime = deviceCamera.lastRestartTime;
      macDefinedCamera.recordPath = deviceCamera.recordPath;
      macDefinedCamera.reportName = deviceCamera.reportName;
      
      print('CDP_OPT: 🔄 Synced camreports data to _macDefinedCameras for ${deviceCamera.mac} (device: ${device.macKey})');
    }

    _batchNotifyListeners();
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
  
  // Public method to trigger UI update
  void triggerUpdate() {
    _cachedFlatCameraList = null;
    _cachedDevicesList = null;
    notifyListeners();
  }

  // Batch notifications to reduce UI rebuilds
  void _batchNotifyListeners() {
    _needsNotification = true;

    // If a timer is already pending, do nothing
    if (_notificationDebounceTimer?.isActive ?? false) {
      return;
    }

    // Schedule a delayed notification
    _notificationDebounceTimer =
        Timer(Duration(milliseconds: _notificationBatchWindow), () {
      if (_needsNotification) {
        _needsNotification = false;
        // Invalidate caches before notifying to ensure fresh data
        _cachedFlatCameraList = null;
        _cachedDevicesList = null;
        // Don't print summary on every notify - too much logging with many cameras
        // _printDeviceSummary();
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
        masterDevice.cpuTemp =
            double.tryParse(message['cpuTemp'].toString()) ?? 0.0;
        print(
            'CDP_OPT: Master device ${masterDevice.macAddress} cpuTemp updated: ${masterDevice.cpuTemp}');
      }

      if (message.containsKey('totalRam')) {
        masterDevice.totalRam =
            int.tryParse(message['totalRam'].toString()) ?? 0;
        print(
            'CDP_OPT: Master device ${masterDevice.macAddress} totalRam updated: ${masterDevice.totalRam}');
      }

      if (message.containsKey('freeRam')) {
        masterDevice.freeRam = int.tryParse(message['freeRam'].toString()) ?? 0;
        print(
            'CDP_OPT: Master device ${masterDevice.macAddress} freeRam updated: ${masterDevice.freeRam}');
      }

      if (message.containsKey('totalconns')) {
        masterDevice.totalConnections =
            int.tryParse(message['totalconns'].toString()) ?? 0;
        print(
            'CDP_OPT: Master device ${masterDevice.macAddress} totalConnections updated: ${masterDevice.totalConnections}');
      }

      if (message.containsKey('sessions')) {
        masterDevice.totalSessions =
            int.tryParse(message['sessions'].toString()) ?? 0;
        print(
            'CDP_OPT: Master device ${masterDevice.macAddress} totalSessions updated: ${masterDevice.totalSessions}');
      }

      if (message.containsKey('eth0')) {
        masterDevice.networkInfo = message['eth0'].toString();
        print(
            'CDP_OPT: Master device ${masterDevice.macAddress} networkInfo updated: ${masterDevice.networkInfo}');
      }

      print(
          'CDP_OPT: Master device ${masterDevice.macAddress} system info updated from sysinfo message');
      _batchNotifyListeners();
    } catch (e) {
      print('CDP_OPT: Error processing sysinfo message: $e');
    }
  }

  /// Send network configuration command to device
  Future<bool> sendSetNetwork({
    required String ip,
    required String gateway,
    required String dhcp,
    required String mac,
  }) async {
    if (_webSocketProvider == null) {
      print('❌ CDP: WebSocketProvider not set');
      return false;
    }

    print(
        '🌐 CDP: Sending SET_NETWORK for device $mac: IP=$ip, GW=$gateway, DHCP=$dhcp');
    return await _webSocketProvider!.sendSetNetwork(
      ip: ip,
      gateway: gateway,
      dhcp: dhcp,
      mac: mac,
    );
  }
  
  /// Toggle Smart Player service on a device
  /// Format: <MAC> SHMC configuration.service.smart_player.on <0|1>
  Future<bool> setSmartPlayerService(String deviceMac, bool enabled) async {
    if (_webSocketProvider == null) {
      print('❌ CDP: WebSocketProvider not set');
      _showOperationResult(false, 'WebSocket bağlantısı yok');
      return false;
    }
    
    final value = enabled ? 1 : 0;
    final command = '$deviceMac SHMC configuration.service.smart_player.on $value';
    print('CDP: 🎬 Sending Smart Player service command: $command');
    
    final success = await _webSocketProvider!.sendCommand(command);
    
    if (success) {
      // Update device state
      final device = _devices[deviceMac];
      if (device != null) {
        device.smartPlayerServiceOn = enabled;
        triggerUpdate();
      }
      _showOperationResult(true, 'Smart Player ${enabled ? "başlatıldı" : "durduruldu"}\n\nKomut: $command');
    } else {
      _showOperationResult(false, 'Smart Player komutu gönderilemedi');
    }
    
    return success;
  }
  
  /// Toggle Recorder service on a device
  /// Format: <MAC> SHMC configuration.service.recorder.on <0|1>
  Future<bool> setRecorderService(String deviceMac, bool enabled) async {
    if (_webSocketProvider == null) {
      print('❌ CDP: WebSocketProvider not set');
      _showOperationResult(false, 'WebSocket bağlantısı yok');
      return false;
    }
    
    final value = enabled ? 1 : 0;
    final command = '$deviceMac SHMC configuration.service.recorder.on $value';
    print('CDP: 🔴 Sending Recorder service command: $command');
    
    final success = await _webSocketProvider!.sendCommand(command);
    
    if (success) {
      // Update device state
      final device = _devices[deviceMac];
      if (device != null) {
        device.recorderServiceOn = enabled;
        triggerUpdate();
      }
      _showOperationResult(true, 'Recorder ${enabled ? "başlatıldı" : "durduruldu"}\n\nKomut: $command');
    } else {
      _showOperationResult(false, 'Recorder komutu gönderilemedi');
    }
    
    return success;
  }
  
  /// Clear all cameras from a device
  /// Format: <MAC> CLEARCAMS
  Future<bool> clearDeviceCameras(String deviceMac) async {
    if (_webSocketProvider == null) {
      print('❌ CDP: WebSocketProvider not set');
      _showOperationResult(false, 'WebSocket bağlantısı yok');
      return false;
    }
    
    final command = '$deviceMac CLEARCAMS';
    print('CDP: 🗑️ Sending CLEARCAMS command: $command');
    
    final success = await _webSocketProvider!.sendCommand(command);
    
    if (success) {
      // Popup gösterme - sunucudan yanıt geldiğinde popup gösterilecek
      print('CDP: ✅ CLEARCAMS komutu gönderildi, sunucu yanıtı bekleniyor...');
    } else {
      _showOperationResult(false, 'Kamera silme komutu gönderilemedi');
    }
    
    return success;
  }
  
  /// Clear cameras locally when server confirms the operation
  /// Called by WebSocketProvider when 'deleted' message with ecs_slaves.*.cam is received
  /// This removes cameras from both the device AND the global camera list
  void clearDeviceCamerasLocally(String deviceMac) {
    print('CDP: 🗑️ Clearing cameras locally for device: $deviceMac');
    
    // Normalize MAC
    final canonicalDeviceMac = deviceMac.toUpperCase().replaceAll('-', ':');
    
    // Try both normalized and original MAC
    final device = _devices[canonicalDeviceMac] ?? _devices[deviceMac];
    
    if (device != null) {
      final cameraCount = device.cameras.length;
      
      // Collect camera MACs before clearing
      final cameraMacsToRemove = device.cameras.map((c) => c.mac.toUpperCase().replaceAll('-', ':')).toList();
      
      // Clear device cameras
      device.cameras.clear();
      
      // Also remove from global _macDefinedCameras list
      int globalRemoved = 0;
      for (final cameraMac in cameraMacsToRemove) {
        if (_macDefinedCameras.containsKey(cameraMac)) {
          _macDefinedCameras.remove(cameraMac);
          globalRemoved++;
        }
        // Also try original case
        final lowerMac = cameraMac.toLowerCase();
        if (_macDefinedCameras.containsKey(lowerMac)) {
          _macDefinedCameras.remove(lowerMac);
          globalRemoved++;
        }
      }
      
      // Clear caches
      _cachedDevicesList = null;
      _cachedFlatCameraList = null;
      
      print('CDP: ✅ Cameras cleared for device $deviceMac (removed $cameraCount cameras from device, $globalRemoved from global list)');
      
      triggerUpdate();
    } else {
      print('CDP: ⚠️ Device not found for clearing cameras: $deviceMac');
    }
  }
  
  /// Remove a specific camera from a device locally AND from global camera list
  /// Called by WebSocketProvider when cameras_mac.*.current.* deletion is received
  void removeCameraLocally(String deviceMac, String cameraMac) {
    print('CDP: 🗑️ Removing camera locally: $cameraMac from device: $deviceMac');
    
    // Normalize MAC addresses
    final canonicalDeviceMac = deviceMac.toUpperCase().replaceAll('-', ':');
    final canonicalCameraMac = cameraMac.toUpperCase().replaceAll('-', ':');
    
    bool anyRemoved = false;
    
    // 1. Remove from device's camera list
    final device = _devices[canonicalDeviceMac];
    if (device != null) {
      final beforeCount = device.cameras.length;
      
      // Remove camera by MAC
      device.cameras.removeWhere((camera) => 
          camera.mac.toUpperCase().replaceAll('-', ':') == canonicalCameraMac);
      
      final afterCount = device.cameras.length;
      
      if (beforeCount != afterCount) {
        print('CDP: ✅ Camera $canonicalCameraMac removed from device $canonicalDeviceMac');
        anyRemoved = true;
      }
    }
    
    // 2. Remove from global _macDefinedCameras (all_cameras / active_cameras list)
    if (_macDefinedCameras.containsKey(canonicalCameraMac)) {
      _macDefinedCameras.remove(canonicalCameraMac);
      print('CDP: ✅ Camera $canonicalCameraMac removed from global camera list');
      anyRemoved = true;
    }
    
    // Also try lowercase version just in case
    if (_macDefinedCameras.containsKey(cameraMac)) {
      _macDefinedCameras.remove(cameraMac);
      print('CDP: ✅ Camera $cameraMac removed from global camera list (lowercase)');
      anyRemoved = true;
    }
    
    // 3. Remove from all devices (camera might be on multiple devices)
    for (final dev in _devices.values) {
      final beforeCount = dev.cameras.length;
      dev.cameras.removeWhere((camera) => 
          camera.mac.toUpperCase().replaceAll('-', ':') == canonicalCameraMac);
      if (beforeCount != dev.cameras.length) {
        print('CDP: ✅ Camera $canonicalCameraMac also removed from device ${dev.macAddress}');
        anyRemoved = true;
      }
    }
    
    if (anyRemoved) {
      // Clear caches
      _cachedDevicesList = null;
      _cachedFlatCameraList = null;
      triggerUpdate();
    } else {
      print('CDP: ⚠️ Camera $canonicalCameraMac not found anywhere');
    }
  }
  
  /// Remove a camera from global list only (not from devices)
  /// Called when all_cameras.* deletion is received
  void removeCameraFromGlobalList(String cameraMac) {
    print('CDP: 🗑️ Removing camera from global list only: $cameraMac');
    
    final canonicalCameraMac = cameraMac.toUpperCase().replaceAll('-', ':');
    bool removed = false;
    
    if (_macDefinedCameras.containsKey(canonicalCameraMac)) {
      _macDefinedCameras.remove(canonicalCameraMac);
      removed = true;
    }
    
    // Also try original case
    if (_macDefinedCameras.containsKey(cameraMac)) {
      _macDefinedCameras.remove(cameraMac);
      removed = true;
    }
    
    if (removed) {
      _cachedDevicesList = null;
      _cachedFlatCameraList = null;
      print('CDP: ✅ Camera $cameraMac removed from global list');
      triggerUpdate();
    } else {
      print('CDP: ⚠️ Camera $cameraMac not found in global list');
    }
  }
  
  /// Remove device completely when server confirms deletion
  /// Called by WebSocketProvider when device system data is deleted
  void removeDeviceLocally(String deviceMac) {
    print('CDP: 🗑️ Removing device locally: $deviceMac');
    
    // Normalize MAC address for lookup
    final canonicalMac = deviceMac.toUpperCase().replaceAll('-', ':');
    
    if (_devices.containsKey(canonicalMac)) {
      final device = _devices[canonicalMac]!;
      final cameraCount = device.cameras.length;
      
      // Remove device from devices map
      _devices.remove(canonicalMac);
      
      // Clear caches
      _cachedDevicesList = null;
      _cachedFlatCameraList = null;
      
      // If this was the selected device, clear selection
      if (_selectedDevice?.macAddress == canonicalMac || _selectedDevice?.macKey == canonicalMac) {
        _selectedDevice = null;
      }
      
      print('CDP: ✅ Device removed: $canonicalMac (had $cameraCount cameras)');
      
      triggerUpdate();
    } else {
      print('CDP: ⚠️ Device not found for removal: $deviceMac (tried: $canonicalMac)');
    }
  }
  
  /// Mark device as disconnected (offline) when system data is partially deleted
  /// This keeps the device in the list but marks it as inactive
  void markDeviceDisconnected(String deviceMac) {
    print('CDP: 📴 Marking device as disconnected: $deviceMac');
    
    // Normalize MAC address for lookup
    final canonicalMac = deviceMac.toUpperCase().replaceAll('-', ':');
    
    final device = _devices[canonicalMac];
    if (device != null) {
      // Mark device as disconnected/offline
      device.lastSeenAt = 'Bağlantı Kesildi';
      device.connected = false;
      device.online = false;
      
      // Clear caches
      _cachedDevicesList = null;
      
      print('CDP: ✅ Device marked as disconnected: $canonicalMac');
      
      triggerUpdate();
    } else {
      print('CDP: ⚠️ Device not found for disconnect marking: $deviceMac');
    }
  }

  /// Add a camera to a device manually
  /// Format: ADD_CAM <CAM_MAC> <SLAVE_MAC>
  Future<bool> addCameraToDevice(String cameraMac, String deviceMac) async {
    if (_webSocketProvider == null) {
      print('❌ CDP: WebSocketProvider not set');
      _showOperationResult(false, 'WebSocket bağlantısı yok');
      return false;
    }
    
    final command = 'ADD_CAM $cameraMac $deviceMac';
    print('CDP: 📷 Sending ADD_CAM command: $command');
    
    final success = await _webSocketProvider!.sendCommand(command);
    
    if (success) {
      print('CDP: ✅ ADD_CAM komutu gönderildi, sunucu yanıtı bekleniyor...');
    } else {
      _showOperationResult(false, 'Kamera ekleme komutu gönderilemedi');
    }
    
    return success;
  }
  
  /// Add a camera to device locally when server confirms the operation
  /// Called by WebSocketProvider when addcam response is received
  void addCameraToDeviceLocally(String cameraMac, String deviceMac) {
    print('CDP: 📷 Adding camera $cameraMac to device $deviceMac locally');
    
    final device = _devices[deviceMac];
    if (device != null) {
      // Check if camera already exists on this device
      final existingCamera = device.cameras.firstWhereOrNull((c) => c.mac == cameraMac);
      if (existingCamera != null) {
        print('CDP: ⚠️ Camera $cameraMac already exists on device $deviceMac');
        return;
      }
      
      // Check if camera exists in global list
      Camera? camera = _macDefinedCameras[cameraMac];
      if (camera == null) {
        // Create a new camera entry
        camera = Camera(
          mac: cameraMac,
          name: 'Camera $cameraMac',
          ip: '',
          index: device.cameras.length,
          parentDeviceMacKey: deviceMac,
        );
        _macDefinedCameras[cameraMac] = camera;
        print('CDP: 📷 Created new camera entry for $cameraMac');
      } else {
        // Update existing camera's parent device
        camera = camera.copyWith(
          parentDeviceMacKey: deviceMac,
          index: device.cameras.length,
        );
        _macDefinedCameras[cameraMac] = camera;
      }
      
      // Add to device
      device.cameras.add(camera);
      
      // Clear caches
      _cachedDevicesList = null;
      _cachedFlatCameraList = null;
      
      print('CDP: ✅ Camera $cameraMac added to device $deviceMac');
      
      triggerUpdate();
    } else {
      print('CDP: ⚠️ Device not found for adding camera: $deviceMac');
    }
  }
  
  /// Helper method to show operation result popup via UserGroupProvider
  void _showOperationResult(bool success, String message) {
    if (_userGroupProvider != null) {
      _userGroupProvider.handleOperationResult(success: success, message: message);
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
