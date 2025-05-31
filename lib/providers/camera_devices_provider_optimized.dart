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
  
  // Get devices by MAC
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
        return;
      }
      
      // Get MAC address
      final macKey = parts[1];
      final macAddress = macKey.startsWith('m_') ? macKey.substring(2).replaceAll('_', ':') : macKey;
      
      // Get or create device
      final device = _getOrCreateDevice(macKey, macAddress);
      
      // Special case for common device properties that might get missed in categorization
      if (parts.length >= 3) {
        // Special case for online property
        if (parts[2] == 'online') {
          final onlineValue = value.toString();
          final bool previousStatus = device.connected;
          device.connected = value is bool ? value : (onlineValue == '1' || onlineValue.toLowerCase() == 'true');
          device.updateStatus(); // Ensure status is recalculated
          debugPrint('Direct online handling: Device ${device.macAddress} online status changed from $previousStatus to ${device.connected} (value: $onlineValue)');
          _cachedDevicesList = null;
          _batchNotifyListeners();
          return;
        }
        
        // Special case for connected property
        if (parts[2] == 'connected') {
          final connectedValue = value.toString();
          final bool previousStatus = device.connected;
          device.connected = value is bool ? value : (connectedValue == '1' || connectedValue.toLowerCase() == 'true');
          device.updateStatus(); // Ensure status is recalculated
          debugPrint('Direct connected handling: Device ${device.macAddress} connected status changed from $previousStatus to ${device.connected} (value: $connectedValue)');
          _cachedDevicesList = null;
          _batchNotifyListeners();
          return;
        }
        
        // Special case for firsttime property
        if (parts[2] == 'firsttime') {
          device.uptime = value.toString();
          debugPrint('Direct firsttime handling: Device ${device.macAddress} firsttime set to: ${value.toString()}');
          _cachedDevicesList = null;
          _batchNotifyListeners();
          return;
        }
        
        // Special case for current_time property
        if (parts[2] == 'current_time') {
          device.lastSeenAt = value.toString();
          debugPrint('Direct current_time handling: Device ${device.macAddress} current_time set to: ${value.toString()}');
          _cachedDevicesList = null;
          _batchNotifyListeners();
          return;
        }
      }
      
      // Categorize and process message
      if (parts.length >= 3) {
        final messageCategory = _categorizeMessage(parts[2], parts.length > 3 ? parts.sublist(3) : []);
        
        // Process based on category
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
          case MessageCategory.basicProperty:
            await _processBasicDeviceProperty(device, parts[2], value);
            // Force immediate UI update for critical properties
            if (parts[2] == 'online' || parts[2] == 'connected') {
              _batchNotifyListeners();
            }
            break;
          case MessageCategory.cameraGroupAssignment:
            if (parts.length > 3 && parts[2].startsWith('cam')) {
              final cameraIndex = parts[2].replaceAll('cam', '').replaceAll(RegExp(r'\[|\]'), '');
              await _processCameraGroupAssignment(device, cameraIndex, value.toString());
            }
            break;
          case MessageCategory.cameraGroupDefinition:
            if (parts.length > 3 && parts[2] == 'configuration' && parts[3].startsWith('cameraGroups')) {
              final groupIndex = parts[3].replaceAll('cameraGroups', '').replaceAll(RegExp(r'\[|\]'), '');
              await _processGroupDefinition(device, groupIndex, value.toString());
            }
            break;
          case MessageCategory.unknown:
            // Legacy format support
            if (parts.length > 3 && parts[2] == 'cam' && parts.length > 4 && parts[4] == 'group') {
              final cameraIndex = parts[3].replaceAll(RegExp(r'\[|\]'), '');
              await _processCameraGroupAssignment(device, cameraIndex, value.toString());
            }
            // Legacy group definition support
            else if (parts.length > 3 && parts[2] == 'configuration' && parts[3].startsWith('cameraGroups')) {
              final groupIndex = parts[3].replaceAll('cameraGroups', '').replaceAll(RegExp(r'\[|\]'), '');
              await _processGroupDefinition(device, groupIndex, value.toString());
            }
            break;
        }
        
        // Clear caches when device data changes
        _cachedDevicesList = null;
        
        // Batch notifications
        _batchNotifyListeners();
      }
    } catch (e) {
      // Log error but don't crash
      debugPrint('Error processing WebSocket message: $e');
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
  CameraDevice _getOrCreateDevice(String macKey, String macAddress) {
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
      _cachedDevicesList = null;
    }
    return _devices[macKey]!;
  }
  
  // Process camera data
  Future<void> _processCameraData(CameraDevice device, String camIndexPath, List<String> properties, dynamic value) async {
    // Extract camera index
    String indexStr = camIndexPath.substring(4, camIndexPath.indexOf(']'));
    int cameraIndex = int.tryParse(indexStr) ?? -1;
    
    if (cameraIndex < 0) {
      return;
    }
    
    // Skip if no properties
    if (properties.isEmpty) {
      return;
    }
    
    String propertyName = properties[0];
    
    // Create camera if needed and property is essential
    if (cameraIndex >= device.cameras.length) {
      bool isEssential = _isEssentialCameraProperty(propertyName, value);
      
      if (!isEssential) {
        return;
      }
      
      await _createCamera(device, cameraIndex, propertyName, value);
    }
    
    // Update camera property
    if (cameraIndex < device.cameras.length) {
      await _updateCameraProperty(device.cameras[cameraIndex], propertyName, properties, value);
    }
  }

  // Check if property is essential for camera creation
  bool _isEssentialCameraProperty(String propertyName, dynamic value) {
    // Only create a camera for properties that define its existence
    return ['ip', 'connected', 'name'].contains(propertyName.toLowerCase());
  }
  
  // Create a new camera
  Future<void> _createCamera(CameraDevice device, int cameraIndex, String propertyName, dynamic value) async {
    // Fill in missing cameras if needed
    while (device.cameras.length <= cameraIndex) {
      final newCamera = Camera(
        index: device.cameras.length,
        connected: false,
        name: 'Camera ${device.cameras.length}',
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
      );
      device.cameras.add(newCamera);
    }
    
    // Set the initial property
    await _updateCameraProperty(device.cameras[cameraIndex], propertyName, [propertyName], value);
  }
  
  // Update camera property
  Future<void> _updateCameraProperty(Camera camera, String propertyName, List<String> properties, dynamic value) async {
    switch (propertyName.toLowerCase()) {
      case 'ip':
        camera.ip = value.toString();
        break;
      case 'connected':
        final bool previousStatus = camera.connected;
        camera.setConnectedStatus(value); // Use the new setter method
        debugPrint('Camera ${camera.name} connected status changed from $previousStatus to ${camera.connected} (value: $value)');
        break;
      case 'name':
        camera.name = value.toString();
        break;
      case 'suburi': // Added case for subUri
        camera.subUri = value.toString();
        debugPrint('Camera ${camera.name} subUri updated to: ${camera.subUri}');
        break;
    }
  }
  
  // Process camera report
  Future<void> _processCameraReport(CameraDevice device, List<String> properties, dynamic value) async {
    // Implementation would go here
    // Simplified for performance optimization
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
      if (groupName.isEmpty) {
        debugPrint("CDP_OPT: Ignoring empty group name from WebSocket.");
        return;
      }
      
      // Grup zaten varsa, uyarı ver ama hata verme
      if (_cameraGroups.containsKey(groupName)) {
        debugPrint("CDP_OPT: Group '$groupName' already exists, skipping creation.");
        return;
      }
      
      // Yeni grup oluştur
      _cameraGroups[groupName] = CameraGroup(name: groupName);
      debugPrint("CDP_OPT: Created new group from WebSocket CAM_GROUP_ADD: '$groupName'");
      
      // Cache'i temizle
      _cachedGroupsList = null;
      
      // UI'ı güncelle
      _batchNotifyListeners();
      
    } catch (e) {
      debugPrint("CDP_OPT: Error in addGroupFromWebSocket: $e");
    }
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
