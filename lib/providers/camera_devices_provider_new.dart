import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/camera_device.dart';

class CameraDevicesProvider with ChangeNotifier {
  final Map<String, CameraDevice> _devices = {};
  CameraDevice? _selectedDevice;
  int _selectedCameraIndex = 0;
  final bool _isLoading = false;

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
      if (device.cameras.any((c) => c.index == camera.index)) {
        return device;
      }
    }
    return null;
  }
  
  // Set the selected device
  void selectDevice(String macKey, {int cameraIndex = 0}) {
    if (_devices.containsKey(macKey)) {
      _selectedDevice = _devices[macKey];
      _selectedCameraIndex = cameraIndex;
      notifyListeners();
    }
  }

  // WebSocket mesajlarını işle
  void processWebSocketMessage(String message) {
    // Mesajın geçerli olup olmadığını kontrol et
    if (message['c'] != 'changed' || !message.containsKey('data') || !message.containsKey('val')) {
      if (message['c'] != 'changed') {
        // await FileLogger.log("Skipping message (type is not 'changed': ${message['c']}).", tag: 'CAMERA_INFO');
      } else {
        // await FileLogger.log("Skipping message (missing 'data' or 'val' fields).", tag: 'CAMERA_INFO');
      }
      return;
    }
    
    final String dataPath = message['data'];
    final dynamic value = message['val'];
    
    // Veri yolu ecs_slaves ile başlamıyorsa, işleme
    if (!dataPath.startsWith('ecs_slaves.')) {
      return;
    }
    
    // Veri yolunu parçalara ayır ve MAC adresini çıkar
    final parts = dataPath.split('.');
    if (parts.length < 2) {
      // await FileLogger.log('Invalid data path format: $dataPath', tag: 'CAMERA_ERROR');
      return;
    }
    
    // MAC adresi bileşenini al
    final macKey = parts[1];
    final macAddress = macKey.startsWith('m_') ? macKey.substring(2).replaceAll('_', ':') : macKey;
    
    // Cihazı al veya oluştur
    final device = _getOrCreateDevice(macKey, macAddress);
    
    // Mesajı kategorize et ve işle
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
        case MessageCategory.basicProperty:
          await _processBasicDeviceProperty(device, parts[2], value);
          break;
        case MessageCategory.unknown:
          // await FileLogger.log('Unknown message category: ${parts[2]}', tag: 'CAMERA_WARN');
          break;
      }
      
      // Değişiklikleri bildir
      notifyListeners();
    }
  }
  
  // Mesaj kategorisini belirle
  MessageCategory _categorizeMessage(String pathComponent, List<String> remainingPath) {
    if (pathComponent.startsWith('cam[') && pathComponent.contains(']')) {
      return MessageCategory.camera;
    } else if (pathComponent == 'camreports') {
      return MessageCategory.cameraReport;
    } else if (pathComponent == 'sysinfo') {
      return MessageCategory.systemInfo;
    } else if (pathComponent == 'configuration') {
      return MessageCategory.configuration;
    } else {
      return MessageCategory.basicProperty;
    }
  }
  
  // Cihazı getir veya yeni oluştur
  CameraDevice _getOrCreateDevice(String macKey, String macAddress) {
    if (!_devices.containsKey(macKey)) {
      _devices[macKey] = CameraDevice(
        macAddress: macAddress,
        macKey: macKey,
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
      // FileLogger.log('New device created with macKey: $macKey', tag: 'CAMERA_NEW');
    }
    return _devices[macKey]!;
  }
  
  // Kamera verilerini işle
  Future<void> _processCameraData(CameraDevice device, String camIndexPath, List<String> properties, dynamic value) async {
    // Kamera indeksini çıkar: cam[0] -> 0
    String indexStr = camIndexPath.substring(4, camIndexPath.indexOf(']'));
    int cameraIndex = int.tryParse(indexStr) ?? -1;
    
    if (cameraIndex < 0) {
      // await FileLogger.log('Invalid camera index in path: $camIndexPath', tag: 'CAMERA_ERROR');
      return;
    }
    
    // Özellik yolu boşsa işlemi atla
    if (properties.isEmpty) {
      // await FileLogger.log('Missing camera property for camera index $cameraIndex', tag: 'CAMERA_WARN');
      return;
    }
    
    String propertyName = properties[0];
    
    // Kamera mevcut değilse ve kritik bir özellikse kamera oluştur
    if (cameraIndex >= device.cameras.length) {
      // Sadece önemli özelliklerde kamera oluştur
      if (!_isEssentialCameraProperty(propertyName, value)) {
        // await FileLogger.log(
        //   'Skipping camera creation for non-essential property: $propertyName = $value', 
        //   tag: 'CAMERA_SKIP'
        // );
        return;
      }
      
      // Önemli özellikle yeni kamera oluştur
      await _createCamera(device, cameraIndex, propertyName, value);
    }
    
    // Kamera özelliğini güncelle
    if (cameraIndex < device.cameras.length) {
      await _updateCameraProperty(device.cameras[cameraIndex], propertyName, value);
    }
  }
  
  // Kamera raporlarını işle
  Future<void> _processCameraReport(CameraDevice device, List<String> reportPath, dynamic value) async {
    if (reportPath.isEmpty) {
      // await FileLogger.log('Empty camera report path for device: ${device.macKey}', tag: 'CAMERA_WARN');
      return;
    }
    
    String reportName = reportPath[0];
    List<String> reportProperties = reportPath.length > 1 ? reportPath.sublist(1) : [];
    
    // Rapor adını ve özelliklerini logla
    // await FileLogger.log(
    //   'Camera report: $reportName, properties: ${reportProperties.join('.')}, value: $value',
    //   tag: 'CAMREPORT'
    // );
    
    // Burada raporlara özgü işlemler yapılabilir
  }
  
  // Sistem bilgilerini işle
  Future<void> _processSystemInfo(CameraDevice device, List<String> infoPath, dynamic value) async {
    if (infoPath.isEmpty) {
      // await FileLogger.log('Empty system info path for device: ${device.macKey}', tag: 'CAMERA_WARN');
      return;
    }
    
    String infoType = infoPath[0];
    
    // Belirli sistem bilgilerini cihaza aktar
    switch (infoType) {
      case 'upTime':
        device.uptime = value.toString();
        // await FileLogger.log('Set device ${device.macKey} uptime to: ${device.uptime} from sysinfo', tag: 'SYSINFO');
        break;
      case 'cpuTemp':
        // await FileLogger.log('System CPU Temperature: $value', tag: 'CPU_TEMP');
        break;
      case 'eth0':
        // await FileLogger.log('System eth0 network info: $value', tag: 'SYSINFO');
        break;
      case 'freeRam':
        // await FileLogger.log('System free RAM: $value', tag: 'SYSINFO');
        break;
      case 'totalRam':
        // await FileLogger.log('System total RAM: $value', tag: 'SYSINFO');
        break;
      // Diğer sistem bilgilerini işle
      default:
        // await FileLogger.log('Unhandled sysinfo property: $infoType with value: $value', tag: 'SYSINFO');
        break;
    }
  }
  
  // Konfigürasyon verilerini işle
  Future<void> _processConfiguration(CameraDevice device, List<String> configPath, dynamic value) async {
    if (configPath.isEmpty) {
      // await FileLogger.log('Empty configuration path for device: ${device.macKey}', tag: 'CAMERA_WARN');
      return;
    }
    
    String configType = configPath[0];
    List<String> configProps = configPath.length > 1 ? configPath.sublist(1) : [];
    
    // await FileLogger.log(
    //   'Processing configuration property: ${configProps.isNotEmpty ? configProps.join('.') : configType} for device ${device.macKey} with value: $value',
    //   tag: 'CONFIG'
    // );
  }
  
  // Temel cihaz özelliklerini işle
  Future<void> _processBasicDeviceProperty(CameraDevice device, String propertyName, dynamic value) async {
    propertyName = propertyName.toLowerCase();
    
    switch (propertyName) {
      case 'ipv4':
        device.ipv4 = value.toString();
        // await FileLogger.log('Set device ${device.macKey} ipv4 to: ${device.ipv4}', tag: 'DEVICE_PROP');
        break;
      case 'lastseenat':
      case 'last_seen_at':
        device.lastSeenAt = value.toString();
        // await FileLogger.log('Set device ${device.macKey} lastSeenAt to: ${device.lastSeenAt}', tag: 'DEVICE_PROP');
        break;
      case 'connected':
        device.connected = value is bool ? value : (value.toString().toLowerCase() == 'true');
        // await FileLogger.log('Set device ${device.macKey} connected to: ${device.connected}', tag: 'DEVICE_PROP');
        break;
      case 'uptime':
        device.uptime = value.toString();
        // await FileLogger.log('Set device ${device.macKey} uptime to: ${device.uptime}', tag: 'DEVICE_PROP');
        break;
      case 'version':
        device.firmwareVersion = value.toString();
        // await FileLogger.log('Set device ${device.macKey} version/firmwareVersion to: ${device.firmwareVersion}', tag: 'DEVICE_PROP');
        break;
      case 'current_time':
      case 'firsttime':
      case 'name':
      case 'smartweb_version':
      case 'cputemp':
      case 'ismaster':
      case 'is_master':
      case 'last_ts':
      case 'online':
      case 'app_ready':
      case 'system_ready':
      case 'cam_ready':
      case 'configuration_ready':
      case 'camreports_ready':
      case 'movita_ready':
        // await FileLogger.log('Device $propertyName: $value - Not storing this value currently', tag: 'DEVICE_PROP');
        break;
      default:
        // await FileLogger.log('Unknown device property: $propertyName with value: $value', tag: 'DEVICE_PROP');
        break;
    }
  }
  
  // Kamera oluşturma
  Future<void> _createCamera(CameraDevice device, int cameraIndex, String initialPropertyName, dynamic initialValue) async {
    // Tüm ara kameraları doldur
    while (device.cameras.length <= cameraIndex) {
      int nextIndex = device.cameras.length;
      
      // Kamera oluşturma hakkında bilgi logla
      // await FileLogger.log('Creating camera at index $nextIndex with initial property: $initialPropertyName', tag: 'CAMERA_NEW');
      
      // Kamera adını belirle - özellik "name" ise değerini kullan, değilse indekse göre oluştur
      String cameraName = initialPropertyName == 'name' ? initialValue.toString() : 'Camera ${nextIndex + 1}';
      
      // Kamera IP'sini belirle - özellik "cameraIp" ise değerini kullan
      String cameraIp = initialPropertyName == 'cameraIp' ? initialValue.toString() : '';
      
      // Kamera markasını belirle - özellik "brand" ise değerini kullan
      String brand = initialPropertyName == 'brand' ? initialValue.toString() : '';
      
      // Yeni kamerayı oluştur
      device.cameras.add(Camera(
        index: nextIndex,
        name: cameraName,
        ip: cameraIp,
        rawIp: 0,
        username: '',
        password: '',
        brand: brand,
        mediaUri: initialPropertyName == 'mediaUri' ? initialValue.toString() : '',
        recordUri: initialPropertyName == 'recordUri' ? initialValue.toString() : '',
        subUri: initialPropertyName == 'subUri' ? initialValue.toString() : '',
        remoteUri: '',
        mainSnapShot: '',
        subSnapShot: '',
        recordWidth: 0,
        recordHeight: 0,
        subWidth: 0, 
        subHeight: 0,
        connected: initialPropertyName == 'connected' ? 
                  (initialValue is bool ? initialValue : initialValue.toString().toLowerCase() == 'true') : 
                  false,
        disconnected: '-',
        lastSeenAt: '',
        recording: false,
      ));
      
      // await FileLogger.log('New camera created with $initialPropertyName: $initialValue', tag: 'CAMERA_NEW');
    }
  }
  
  // Kamera özelliği güncellemesi
  Future<void> _updateCameraProperty(Camera camera, String propertyName, dynamic value) async {
    // Özellik güncellemesini logla
    // await FileLogger.log(
    //   'Updating camera[${camera.index}] property: $propertyName, value: $value (${value.runtimeType})', 
    //   tag: 'CAMERA_PROP'
    // );
    
    // Özelliği güncelle
    switch (propertyName) {
      case 'name':
        String oldName = camera.name;
        camera.name = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] name from "$oldName" to: "${camera.name}"', tag: 'CAMERA_PROP');
        break;
      case 'cameraIp':
        camera.ip = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] IP to: ${camera.ip}', tag: 'CAMERA_PROP');
        break;
      case 'cameraRawIp':
        camera.rawIp = value is int ? value : int.tryParse(value.toString()) ?? 0;
        // await FileLogger.log('Set camera[${camera.index}] rawIp to: ${camera.rawIp}', tag: 'CAMERA_PROP');
        break;
      case 'username':
        camera.username = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] username to: ${camera.username}', tag: 'CAMERA_PROP');
        break;
      case 'password':
        camera.password = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] password to: [REDACTED]', tag: 'CAMERA_PROP');
        break;
      case 'brand':
        camera.brand = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] brand to: ${camera.brand}', tag: 'CAMERA_PROP');
        break;
      case 'hw':
        camera.hw = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] hw to: ${camera.hw}', tag: 'CAMERA_PROP');
        break;
      case 'manufacturer':
        camera.manufacturer = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] manufacturer to: ${camera.manufacturer}', tag: 'CAMERA_PROP');
        break;
      case 'country':
        camera.country = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] country to: ${camera.country}', tag: 'CAMERA_PROP');
        break;
      case 'xAddrs':
        camera.xAddrs = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] xAddrs to: ${camera.xAddrs}', tag: 'CAMERA_PROP');
        break;
      case 'mediaUri':
        camera.mediaUri = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] mediaUri to: ${camera.mediaUri}', tag: 'CAMERA_PROP');
        break;
      case 'recordUri':
        camera.recordUri = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] recordUri to: ${camera.recordUri}', tag: 'CAMERA_PROP');
        break;
      case 'subUri':
        camera.subUri = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] subUri to: ${camera.subUri}', tag: 'CAMERA_PROP');
        break;
      case 'remoteUri':
        camera.remoteUri = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] remoteUri to: ${camera.remoteUri}', tag: 'CAMERA_PROP');
        break;
      case 'mainSnapShot':
        camera.mainSnapShot = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] mainSnapShot to: ${camera.mainSnapShot}', tag: 'CAMERA_PROP');
        break;
      case 'subSnapShot':
        camera.subSnapShot = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] subSnapShot to: ${camera.subSnapShot}', tag: 'CAMERA_PROP');
        break;
      case 'recordPath':
        camera.recordPath = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] recordPath to: ${camera.recordPath}', tag: 'CAMERA_PROP');
        break;
      case 'recordWidth':
        camera.recordWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
        // await FileLogger.log('Set camera[${camera.index}] recordWidth to: ${camera.recordWidth}', tag: 'CAMERA_PROP');
        break;
      case 'recordHeight':
        camera.recordHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
        // await FileLogger.log('Set camera[${camera.index}] recordHeight to: ${camera.recordHeight}', tag: 'CAMERA_PROP');
        break;
      case 'subWidth':
        camera.subWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
        // await FileLogger.log('Set camera[${camera.index}] subWidth to: ${camera.subWidth}', tag: 'CAMERA_PROP');
        break;
      case 'subHeight':
        camera.subHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
        // await FileLogger.log('Set camera[${camera.index}] subHeight to: ${camera.subHeight}', tag: 'CAMERA_PROP');
        break;
      case 'connected':
        camera.connected = value is bool ? value : (value.toString().toLowerCase() == 'true');
        // await FileLogger.log('Set camera[${camera.index}] connected to: ${camera.connected}', tag: 'CAMERA_PROP');
        break;
      case 'disconnected':
        camera.disconnected = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] disconnected to: ${camera.disconnected}', tag: 'CAMERA_PROP');
        break;
      case 'lastSeenAt':
        camera.lastSeenAt = value.toString();
        // await FileLogger.log('Set camera[${camera.index}] lastSeenAt to: ${camera.lastSeenAt}', tag: 'CAMERA_PROP');
        break;
      case 'recording':
        camera.recording = value is bool ? value : (value.toString().toLowerCase() == 'true');
        // await FileLogger.log('Set camera[${camera.index}] recording to: ${camera.recording}', tag: 'CAMERA_PROP');
        break;
      default:
        // await FileLogger.log('Unknown camera property: $propertyName with value: $value', tag: 'CAMERA_WARN');
        break;
    }
  }
  
  // Bir özelliğin kamera oluşturmak için kritik olup olmadığını kontrol et
  bool _isEssentialCameraProperty(String propertyName, dynamic value) {
    // Özellik adlarını listeye dönüştür ve kontrol et
    final List<String> criticalProperties = ['name', 'cameraIp', 'mediaUri', 'subUri', 'recordUri'];
    
    // Boş, null veya anlamsız değerler oluşturulmamalı
    bool hasSubstantiveValue = value != null && 
                             value.toString().isNotEmpty && 
                             value.toString() != '0' && 
                             value.toString() != 'false' &&
                             value.toString() != '-';
    
    return criticalProperties.contains(propertyName) && hasSubstantiveValue;
  }
}

// Mesaj kategorilerini tanımla
enum MessageCategory {
  camera,        // cam[INDEX].*
  cameraReport,  // camreports.*
  systemInfo,    // sysinfo.*
  configuration, // configuration.*
  basicProperty, // doğrudan cihaz özellikleri
  unknown        // bilinmeyen mesaj tipi
}
