import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/camera_device.dart'; // Corrected import path
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
  final Map<String, CameraDevice> _devices = {}; // Parent devices, keyed by their canonical MAC
  final Map<String, Camera> _macDefinedCameras = {}; // Master list of cameras, keyed by their own MAC
  final Map<String, CameraGroup> _cameraGroups = {};
  List<CameraGroup>? _cachedGroupsList; // Added declaration
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
  
  // Get all cameras as a flat list
  List<Camera> get allCameras {
    return _macDefinedCameras.values.toList();
  }
  
  // Get devices grouped by MAC
  Map<String, List<Camera>> getCamerasByMacAddress() {
    Map<String, List<Camera>> result = {};
    
    // Group cameras by their parent device MAC
    for (var camera in _macDefinedCameras.values) {
      final parentMac = camera.parentDeviceMacKey;
      if (parentMac != null) {
        result[parentMac] ??= [];
        result[parentMac]!.add(camera);
      }
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
    
    final List<Camera> camerasInGroup = [];
    
    // Scan all mac-defined cameras for ones that belong to this group
    for (final camera in _macDefinedCameras.values) {
      if (camera.groups.contains(groupName)) {
        camerasInGroup.add(camera);
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

  // Helper to get or create a camera from the master list
  Camera _getOrCreateMacDefinedCamera(String cameraMac) {
    if (cameraMac.isEmpty) {
      // This case should ideally be prevented by upstream validation or a placeholder.
      // For now, let's log and return a temporary camera object if absolutely necessary,
      // but this indicates a data issue.
      debugPrint("CDP_OPT: CRITICAL - Attempted to get/create camera with empty MAC.");
      // Returning a dummy or throwing an error might be better.
      // For now, to avoid crashing, let's create one, but it won't be useful.
      // Assign a temporary, non-colliding index. This camera is problematic anyway.
      int tempIndex = -DateTime.now().millisecondsSinceEpoch; 
      return _macDefinedCameras.putIfAbsent("EMPTY_MAC_${DateTime.now().millisecondsSinceEpoch}", () {
        _cachedFlatCameraList = null;
        return Camera(mac: "EMPTY_MAC_${DateTime.now().millisecondsSinceEpoch}", index: tempIndex); 
      });
    }
    return _macDefinedCameras.putIfAbsent(cameraMac, () {
      debugPrint('CDP_OPT: Creating new MAC-defined camera: $cameraMac');
      _cachedFlatCameraList = null; // Invalidate flat list cache
      // Assign a temporary index; it will be updated when linked to a device by _addOrUpdateCameraInDeviceList
      return Camera(mac: cameraMac, index: -1); 
    });
  }

  // Helper to update properties of a MAC-defined camera
  Future<void> _updateMacDefinedCameraProperty(Camera camera, List<String> pathParts, dynamic value) async {
    if (pathParts.length < 3) return;
    String propertyName = pathParts[2].toLowerCase(); // property name is at index 2

    debugPrint('CDP_OPT: Updating MAC-cam ${camera.mac}: $propertyName = $value');

    if (propertyName.startsWith('group[')) {
      Match? match = RegExp(r'group\[(\d+)\]').firstMatch(propertyName);
      if (match != null) {
        try {
          int groupIndex = int.parse(match.group(1)!);
          String groupValue = value.toString();

          // Ensure groups list is long enough, padding with empty strings
          while (camera.groups.length <= groupIndex) {
            camera.groups.add('');
          }
          
          camera.groups[groupIndex] = groupValue; // Assign value (can be empty)
          
          debugPrint('CDP_OPT: Camera ${camera.mac} group at index $groupIndex updated to "$groupValue". Groups: ${camera.groups}');
          
          // Create or update the camera group if it doesn't exist
          if (groupValue.isNotEmpty && !_cameraGroups.containsKey(groupValue)) {
            _cameraGroups[groupValue] = CameraGroup(
              name: groupValue,
              cameraMacs: []
            );
            _cachedGroupsList = null;
            debugPrint('CDP_OPT: Created new camera group: $groupValue');
          }
        } catch (e) {
          debugPrint('CDP_OPT: Error parsing group index from $propertyName: $e');
        }
      }
    } else {
      switch (propertyName) {
        // Mapping to new Camera model fields for cameras_mac specific data
        case 'firsttime': camera.macFirstSeen = value.toString(); break;
        case 'lastdetected': camera.macLastDetected = value.toString(); break;
        case 'port': camera.macPort = value is int ? value : int.tryParse(value.toString()); break;
        case 'error': camera.macReportedError = value.toString(); break;
        case 'status': camera.macStatus = value.toString(); break;

        // General camera properties that can also be set by cameras_mac
        case 'name':
          camera.name = value.toString();
          // If camera.parentDeviceMacKey is known and name is used for mapping, update here.
          // For now, _cameraNameToDeviceMap is updated in _processCameraData if name comes from there.
          // If cameras_mac is the authority for name, this is the place.
          break;
        case 'cameraip': // Assuming 'cameraip' from cameras_mac maps to general 'ip'
        case 'ip':
          camera.ip = value.toString();
          break;
        case 'xaddr': camera.xAddr = value.toString(); break;
        case 'username': camera.username = value.toString(); break;
        case 'password': camera.password = value.toString(); break;
        case 'brand': camera.brand = value.toString(); break;
        case 'hw': camera.hw = value.toString(); break;
        case 'country': camera.country = value.toString(); break;
        case 'manufacturer': camera.manufacturer = value.toString(); break;
        case 'suburi': camera.subUri = value.toString(); break;
        case 'recorduri': camera.recordUri = value.toString(); break;
        case 'subsnapshot': camera.subSnapShot = value.toString(); break;
        case 'mainsnapshot': camera.mainSnapShot = value.toString(); break;
        case 'camerarawip': camera.rawIp = value is int ? value : int.tryParse(value.toString()) ?? 0; break;
        case 'recordcodec': camera.recordCodec = value.toString(); break;
        case 'recordwidth': camera.recordWidth = value is int ? value : int.tryParse(value.toString()) ?? 0; break;
        case 'recordheight': camera.recordHeight = value is int ? value : int.tryParse(value.toString()) ?? 0; break;
        case 'subcodec': camera.subCodec = value.toString(); break;
        case 'subwidth': camera.subWidth = value is int ? value : int.tryParse(value.toString()) ?? 0; break;
        case 'subheight': camera.subHeight = value is int ? value : int.tryParse(value.toString()) ?? 0; break;
        
        // 'seen' from cameras_mac might map to macLastDetected or a general lastSeenAt.
        // Using macLastDetected for 'lastdetected' property.
        // If 'seen' is a distinct property from cameras_mac, add a case for it.
        // case 'seen': camera.lastSeenAt = value.toString(); break; // General last seen

        // 'connected' from cameras_mac might indicate the camera's own reported connection status
        // This is different from the device's connection to the camera.
        // For now, let's assume 'status' field from cameras_mac covers this.
        // If 'connected' is a specific boolean from cameras_mac:
        // case 'connected': camera.setConnectedStatus(value); break; 

        // 'record' from cameras_mac
        case 'record': camera.recording = value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1'); break;
        
        default:
          debugPrint('CDP_OPT: Unhandled MAC-defined camera property: $propertyName for camera ${camera.mac}');
      }
    }
    _cachedFlatCameraList = null;
    _batchNotifyListeners();
  }
  
  // Helper to manage adding/updating cameras in a device's list
  void _addOrUpdateCameraInDeviceList(CameraDevice device, int cameraIndex, Camera cameraToAdd) {
    // Ensure the camera to add knows its parent and index
    cameraToAdd.parentDeviceMacKey = device.macKey; // Use the original macKey from path for the device
    cameraToAdd.index = cameraIndex;

    // Remove any camera at the target index if its MAC is different (it's being replaced)
    device.cameras.removeWhere((c) => c.index == cameraIndex && c.mac != cameraToAdd.mac);

    // Remove cameraToAdd if it exists elsewhere in this device's list (e.g., had a different index before)
    device.cameras.removeWhere((c) => c.mac == cameraToAdd.mac && c.index != cameraIndex);

    // If no camera with cameraToAdd.mac is now in the list for this device, add it.
    if (!device.cameras.any((c) => c.mac == cameraToAdd.mac)) {
        device.cameras.add(cameraToAdd);
    }
    // The camera (cameraToAdd) is now definitely in device.cameras.
    // Its .index and .parentDeviceMacKey are set.
    // The list itself isn't strictly ordered by index; sorting for display should use camera.index.
    _cachedDevicesList = null; // Invalidate device list cache as a device's camera list changed
  }


  // Process WebSocket messages
  void processWebSocketMessage(Map<String, dynamic> message) async {
    try {
      if (message['c'] != 'changed' || !message.containsKey('data') || !message.containsKey('val')) {
        return;
      }
      
      final String dataPath = message['data'];
      final dynamic value = message['val'];
      
      final String messageKey = '$dataPath:${value.toString()}';
      if (_processedMessages.containsKey(messageKey)) {
        return;
      }
      _processedMessages[messageKey] = true;
      if (_processedMessages.length > _maxProcessedMessageCache) {
        _processedMessages.remove(_processedMessages.keys.first);
      }

      if (dataPath.startsWith('cameras_mac.')) {
        final parts = dataPath.split('.'); // cameras_mac.CAMERA_MAC.property or cameras_mac.CAMERA_MAC.group[0]
        if (parts.length >= 3) {
          final cameraMac = parts[1]; // This is the camera's own MAC address
          if (cameraMac.isNotEmpty) {
            final camera = _getOrCreateMacDefinedCamera(cameraMac);
            await _updateMacDefinedCameraProperty(camera, parts, value);
          } else {
            debugPrint('CDP_OPT: Received cameras_mac message with empty camera MAC in path: $dataPath');
          }
        } else {
          debugPrint('CDP_OPT: Invalid cameras_mac path: $dataPath');
        }
        return; // Message handled
      }
      
      if (!dataPath.startsWith('ecs_slaves.')) {
        return;
      }
      
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
        debugPrint('CDP_OPT: Could not extract MAC address from device path component: "$pathDeviceIdentifier". Skipping message.');
        return;
      }
      
      // Use canonicalMacAddress for device identification, pathDeviceIdentifier is the original key
      final device = _getOrCreateDevice(canonicalMacAddress, pathDeviceIdentifier);
      
      // Early handling for specific device properties (online, connected, firsttime, current_time)
      if (parts.length >= 3) {
        String deviceProperty = parts[2];
        if (deviceProperty == 'online' || deviceProperty == 'connected' || deviceProperty == 'firsttime' || deviceProperty == 'current_time') {
          // This logic was previously here, ensure it correctly updates 'device' object
          // For brevity, assuming this part is correctly implemented as before to update device.connected, device.uptime etc.
          // and calls _batchNotifyListeners() and returns.
          // Example for 'online':
          if (deviceProperty == 'online') {
            final onlineValue = value.toString();
            final bool previousStatus = device.connected; // Assuming CameraDevice has 'connected'
            final bool newStatus = value is bool ? value : (onlineValue == '1' || onlineValue.toLowerCase() == 'true');
            device.connected = newStatus;
            device.updateStatus(); // Assuming CameraDevice has 'updateStatus'
            debugPrint('Direct online handling: Device ${device.macAddress} online status changed from $previousStatus to ${device.connected} (value: $onlineValue)');
            _cachedDevicesList = null;
            _batchNotifyListeners();
            return;
          }
           // Add similar handlers for 'connected', 'firsttime', 'current_time' for the CameraDevice object
        }
      }

      // Categorize and process message for ecs_slaves (cam[index] or other device properties)
      if (parts.length >= 3) {
        final String componentAfterDevice = parts[2]; // e.g., "cam[0]" or "system" or "configuration"
        
        if (componentAfterDevice.startsWith('cam[')) { // This is an ecs_slaves.DEVICE.cam[INDEX].PROPERTY message
            List<String> camProperties;
            if (parts.length > 3) {
                camProperties = parts.sublist(3); // e.g., ["name"], or ["status", "active"]
            } else {
                camProperties = []; // Should not happen if it's a property update
            }
            await _processCameraData(device, componentAfterDevice, camProperties, value);
        } else {
            // Handle other ecs_slaves device properties (systemInfo, configuration, basicProperty)
            // This reuses the existing categorization and processing logic for non-cam[index] properties
            final messageCategory = _categorizeMessage(componentAfterDevice, parts.length > 3 ? parts.sublist(3) : []);
            switch (messageCategory) {
              case MessageCategory.camera: // Added case for MessageCategory.camera
                // This case should ideally not be hit if cam[ startsWith is handled above.
                // However, if _categorizeMessage can return it for other paths, handle appropriately.
                debugPrint('CDP_OPT: MessageCategory.camera reached for $dataPath. This might indicate an unexpected path format.');
                // Potentially call _processCameraData or a similar handler if applicable.
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
                await _processBasicDeviceProperty(device, componentAfterDevice, value);
                break;
              case MessageCategory.cameraGroupAssignment: 
                // This is now handled by cameras_mac.CAMERA_MAC.group[index]
                // So, this case can be removed or logged as deprecated if messages still arrive.
                debugPrint("CDP_OPT: Deprecated message type CameraGroupAssignment received for ecs_slaves: $dataPath. Group assignments are now handled by 'cameras_mac'.");
                // if (parts.length > 3 && componentAfterDevice.startsWith('cam')) {
                //    final cameraIndex = componentAfterDevice.replaceAll('cam', '').replaceAll(RegExp(r'\\\\[|\\\\]'), '');
                //    await _processCameraGroupAssignment(device, cameraIndex, value.toString());
                // }
                break;
              case MessageCategory.cameraGroupDefinition: // This was for configuration.cameraGroups[X] = Y
                if (parts.length > 3 && componentAfterDevice == 'configuration' && parts[3].startsWith('cameraGroups')) {
                    final groupIndex = parts[3].replaceAll('cameraGroups', '').replaceAll(RegExp(r'\\[|\\]'), '');
                    await _processGroupDefinition(device, groupIndex, value.toString()); // This defines a CameraGroup
                }
                break;
              case MessageCategory.unknown:
                // Legacy format support as before
                break;
            }
        }
        _cachedDevicesList = null; // A device or its sub-properties changed
        _batchNotifyListeners();
      }
    } catch (e, s) {
      debugPrint('CDP_OPT: Error processing WebSocket message: $e\\n$s. Message: $message');
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
    if (!_devices.containsKey(canonicalDeviceMac)) {
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
    
    if (cameraIndex < 0 || camPathProperties.isEmpty) {
      debugPrint('CDP_OPT: Invalid camIndex or no properties for ecs_slaves camera data. Device: ${device.macAddress}, Path: $camIndexPath');
      return;
    }
    
    String propertyName = camPathProperties[0].toLowerCase();
    // String subProperty = camPathProperties.length > 1 ? camPathProperties[1].toLowerCase() : '';

    debugPrint('CDP_OPT: Processing ecs_slaves data: Device ${device.macAddress}, cam[$cameraIndex].$propertyName = $value');

    Camera? cameraToUpdate;

    if (propertyName == 'mac') { // This is the camera's own MAC address from ecs_slaves path
      String cameraMacFromMessage = value.toString();
      if (cameraMacFromMessage.isNotEmpty) {
        cameraToUpdate = _getOrCreateMacDefinedCamera(cameraMacFromMessage);
        // Link this MAC-defined camera to the parent device and its index
        _addOrUpdateCameraInDeviceList(device, cameraIndex, cameraToUpdate);
        debugPrint('CDP_OPT: Linked camera ${cameraToUpdate.mac} to device ${device.macKey} at index $cameraIndex.');
      } else {
        debugPrint('CDP_OPT: Received empty MAC for cam[$cameraIndex] on device ${device.macAddress}. Cannot link or update.');
        return; 
      }
    } else {
      // For other properties (name, ip, etc.), find the camera already associated with this device and index
      // It should have been linked previously by a 'mac' property message.
      var camsInDevice = device.cameras.where((cam) => cam.index == cameraIndex).toList();
      if (camsInDevice.isNotEmpty) {
        cameraToUpdate = camsInDevice.first; // Should ideally be only one
        if (camsInDevice.length > 1) {
            debugPrint("CDP_OPT: WARNING - Multiple cameras found for device ${device.macKey} at index $cameraIndex. Using first: ${cameraToUpdate.mac}. All: ${camsInDevice.map((c)=>c.mac).join(',')}");
        }
      } else {
        debugPrint('CDP_OPT: No camera found for device ${device.macKey} at cam[$cameraIndex] to update property $propertyName. MAC message might not have arrived yet.');
        return; // Cannot update if we don't know which camera it is.
      }
    }

    // Now update the identified cameraToUpdate with the property from ecs_slaves
    // Be mindful of data authority: if cameras_mac also provides 'name', which one wins?
    // For now, let ecs_slaves also update.
    if (cameraToUpdate != null) {
      switch (propertyName) {
        case 'name':
          cameraToUpdate.name = value.toString();
          // Update _cameraNameToDeviceMap if necessary
          // _cameraNameToDeviceMap[cameraToUpdate.name] = device.macKey; // or canonicalDeviceMac?
          break;
        case 'ip':
          cameraToUpdate.ip = value.toString();
          break;
        case 'connected': // Example, if ecs_slaves provides cam-specific connection status
          cameraToUpdate.setConnectedStatus(value);
          break;
        // Handle other cam[index] specific properties from ecs_slaves if any.
        // These are properties that are specific to the camera *in the context of this device*
        // or are an alternative source for common camera properties.
        default:
          // If not 'mac', 'name', 'ip', 'connected', it might be a property for _updateCameraProperty
          // This part needs to be mapped to your Camera model's fields carefully.
          // For now, we assume 'mac' is the linker, and 'name'/'ip' can be updated.
          // Other properties from ecs_slaves.cam[X] need explicit handling if they map to Camera object fields.
          debugPrint('CDP_OPT: ecs_slaves cam[$cameraIndex] property \'$propertyName\' for ${cameraToUpdate.mac} - specific update logic may be needed.');
      }
      _cachedFlatCameraList = null; // Camera property changed
      _batchNotifyListeners();
    }
  }

  // _createCamera is likely no longer needed if cameras are created via _getOrCreateMacDefinedCamera
  // and then linked. The old _createCamera was adding to device.cameras directly.

  // _updateCameraProperty might be merged into _updateMacDefinedCameraProperty or adapted.
  // For now, let's assume _updateMacDefinedCameraProperty is the main one for camera's own props.

  // _processCameraReport needs to find cameras in _macDefinedCameras by name.
  Future<void> _processCameraReport(CameraDevice device, List<String> properties, dynamic value) async {
    if (properties.isEmpty) {
      debugPrint('CDP_OPT: ProcessCameraReport - No properties, skipping. Device: ${device.macAddress}');
      return;
    }
    
    final cameraName = properties[0];
    if (properties.length < 2) {
      debugPrint('CDP_OPT: ProcessCameraReport - Not enough properties for $cameraName on device ${device.macAddress}. Skipping.');
      return;
    }
    
    final reportProperty = properties[1].toLowerCase();
    
    debugPrint('CDP_OPT: Processing camera report: device=${device.macAddress}, cameraNameInReport=$cameraName, property=$reportProperty, value=$value');

    Camera? targetCamera;
    String? deviceMacFromIndex = _cameraNameToDeviceMap[cameraName];
    
    if (deviceMacFromIndex != null && deviceMacFromIndex == device.macAddress) {
      // If the camera name is in our map and belongs to the current device,
      // try to find it in the device's actual camera list.
      try {
        targetCamera = device.cameras.firstWhere((cam) => cam.name == cameraName);
        // If firstWhere completes, camera is found and targetCamera is non-null.
        debugPrint('CDP_OPT: ProcessCameraReport - Found camera "$cameraName" via _cameraNameToDeviceMap (and confirmed in device.cameras) for device ${device.macAddress}.');
      } catch (e) {
        // Element not found in device.cameras, even if map suggested it.
        // This could happen if the camera was removed or its name changed after the map was populated.
        targetCamera = null; 
        debugPrint('CDP_OPT: ProcessCameraReport - Camera "$cameraName" was in _cameraNameToDeviceMap but NOT found in device.cameras list for ${device.macAddress}. Map might be stale or name changed.');
      }
    }
    
    // Fallback: if not found via map (or if map was stale/incorrect), iterate all cameras for this device.
    // This also covers the case where deviceMacFromIndex was null (camera name not in map).
    if (targetCamera == null) {
      debugPrint('CDP_OPT: ProcessCameraReport - Camera "$cameraName" not found via map or map was stale. Iterating all cameras for device ${device.macAddress}.');
      for (var camInLoop in device.cameras) {
        if (camInLoop.name == cameraName) {
          targetCamera = camInLoop;
          debugPrint('CDP_OPT: ProcessCameraReport - Found camera "$cameraName" by iterating all cameras for device ${device.macAddress}.');
          break;
        }
      }
    }
    
    if (targetCamera == null) {
      debugPrint('CDP_OPT: ProcessCameraReport - Camera "$cameraName" not found on device ${device.macAddress} and will NOT be created from report. Report for property $reportProperty skipped.');
      return;
    }
    
    // Update camera report properties for the found targetCamera
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
  // This method is likely deprecated as group assignments are now handled by 
  // cameras_mac.CAMERA_MAC.group[index] via _updateMacDefinedCameraProperty
  Future<void> _processCameraGroupAssignment(CameraDevice device, String cameraIndex, String groupName) async {
    debugPrint("CDP_OPT: _processCameraGroupAssignment called for device ${device.macKey}, camIndex $cameraIndex, group $groupName. This path is likely deprecated.");
    // Original logic (if any was here) might involve finding the camera by index in device.cameras
    // and updating its 'groups' list. However, 'cameras_mac' is now the authority for groups.
    // Consider removing this method if no ecs_slaves messages are expected for this.
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

// Helper extension for firstWhereOrNull if not available (Flutter SDK 2.7.0+)
extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
