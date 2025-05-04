import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/camera_device.dart';
import '../models/camera_group.dart';
import '../utils/file_logger.dart';

class CameraDevicesProvider with ChangeNotifier {
  final Map<String, CameraDevice> _devices = {};
  final Map<String, CameraGroup> _cameraGroups = {}; // Kamera grupları
  CameraDevice? _selectedDevice;
  int _selectedCameraIndex = 0;
  bool _isLoading = false;
  String? _selectedGroupName; // Seçilen grup

  Map<String, CameraDevice> get devices => _devices;
  List<CameraDevice> get devicesList => _devices.values.toList();
  CameraDevice? get selectedDevice => _selectedDevice;
  int get selectedCameraIndex => _selectedCameraIndex;
  bool get isLoading => _isLoading;
  
  // Kamera grupları ile ilgili getters
  Map<String, CameraGroup> get cameraGroups => _cameraGroups;
  List<CameraGroup> get cameraGroupsList => _cameraGroups.values.toList();
  String? get selectedGroupName => _selectedGroupName;
  CameraGroup? get selectedGroup => _selectedGroupName != null ? _cameraGroups[_selectedGroupName] : null;
  
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
  
  // Eski API uyumluluğu için - setSelectedDevice metodu
  void setSelectedDevice(String macKey) {
    selectDevice(macKey);
  }
  
  // Eski API uyumluluğu için - setSelectedCameraIndex metodu
  void setSelectedCameraIndex(int index) {
    if (_selectedDevice != null) {
      _selectedCameraIndex = index;
      notifyListeners();
    }
  }
  
  // Grup seçme metodu
  void selectGroup(String groupName) {
    if (_cameraGroups.containsKey(groupName)) {
      _selectedGroupName = groupName;
      notifyListeners();
    }
  }
  
  // Gruba göre kameraları getir
  List<Camera> getCamerasInGroup(String groupName) {
    if (!_cameraGroups.containsKey(groupName)) {
      FileLogger.log('Grup bulunamadı: $groupName', tag: 'GROUP_ERROR').then((_) {});
      return [];
    }
    
    final group = _cameraGroups[groupName]!;
    final List<Camera> camerasInGroup = [];
    
    FileLogger.log('Grup için kamera listesi kontrol ediliyor: $groupName, ${group.cameraMacs.length} kamera tanımlayıcısı var', 
      tag: 'GROUP_INFO').then((_) {});
    FileLogger.log('Kamera tanımlayıcıları: ${group.cameraMacs.join(", ")}', tag: 'GROUP_DEBUG').then((_) {});
    
    // Tüm cihazları tara
    for (final deviceEntry in _devices.entries) {
      final deviceMac = deviceEntry.key;
      final device = deviceEntry.value;
      
      // Her bir kamera için
      for (int i = 0; i < device.cameras.length; i++) {
        final Camera camera = device.cameras[i];
        
        // Bu kamera herhangi bir formatta grup listesinde var mı?
        // Bu kamera için kontrol edilecek üç format:
        final String simpleIndex = i.toString(); // örn: "0", "1", "2"...
        final String camFormat = "cam[$i]"; // örn: "cam[0]", "cam[1]"...
        final String fullFormat = "$deviceMac.cam[$i]"; // örn: "m_XX_XX_XX_XX_XX_XX.cam[0]"...
        
        // Grup bu tanımlayıcılardan birini içeriyor mu?
        if (group.cameraMacs.contains(simpleIndex) || 
            group.cameraMacs.contains(camFormat) || 
            group.cameraMacs.contains(fullFormat)) {
          
          camerasInGroup.add(camera);
          FileLogger.log('Kamera gruba eklendi: Cihaz=$deviceMac, Kamera=${camera.name}, Format=(${simpleIndex}/${camFormat})',
            tag: 'GROUP_DEBUG').then((_) {});
        }
      }
    }
    
    // Test amaçlı olarak cihazların tüm kameralarını görelim
    for (final deviceEntry in _devices.entries) {
      final deviceMac = deviceEntry.key;
      final device = deviceEntry.value;
      FileLogger.log('Cihaz $deviceMac - ${device.cameras.length} kamera var', tag: 'GROUP_DEBUG').then((_) {});
      for (int i = 0; i < device.cameras.length; i++) {
        final camera = device.cameras[i];
        FileLogger.log('  Kamera[$i]: ${camera.name} (${camera.ip})', tag: 'GROUP_DEBUG').then((_) {});
      }
    }
    
    FileLogger.log('Grupta toplam ${camerasInGroup.length} kamera bulundu: $groupName', tag: 'GROUP_INFO').then((_) {});
    return camerasInGroup;
  }
  
  // Grupları temizle (reset)
  void clearGroups() {
    _cameraGroups.clear();
    _selectedGroupName = null;
    notifyListeners();
  }
  
  // Kameraları yenile - UI için gerekli
  void refreshCameras() {
    // Kameraları yeniden yükleme işlemini başlat
    _isLoading = true;
    notifyListeners();
    
    // Yenileme işlemi tamamlandı (gerçekte websocket üzerinden zaten güncel verileri alıyoruz)
    _isLoading = false;
    notifyListeners();
  }

  // WebSocket mesajlarını işle
  void processWebSocketMessage(Map<String, dynamic> message) async {
    try {
      // Mesajın geçerli olup olmadığını kontrol et
      if (message['c'] != 'changed' || !message.containsKey('data') || !message.containsKey('val')) {
        if (message['c'] != 'changed') {
          await FileLogger.log("Skipping message (type is not 'changed': ${message['c']}).", tag: 'CAMERA_INFO');
        } else {
          await FileLogger.log("Skipping message (missing 'data' or 'val' fields).", tag: 'CAMERA_INFO');
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
        await FileLogger.log('Invalid data path format: $dataPath', tag: 'CAMERA_ERROR');
        return;
      }
      
      // MAC adresi bileşenini al
      final macKey = parts[1];
      final macAddress = macKey.startsWith('m_') ? macKey.substring(2).replaceAll('_', ':') : macKey;
      
      // Cihazı al veya oluştur
      final device = _getOrCreateDevice(macKey, macAddress);
      
      // Mesajı kategorize et ve sadece ilgili alanı güncelleyerek işle
      if (parts.length >= 3) {
        final messageCategory = _categorizeMessage(parts[2], parts.length > 3 ? parts.sublist(3) : []);
        
        // Her bir veri tipi için ayrı işleme ve sadece ilgili alanları güncelleme
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
          case MessageCategory.cameraGroupAssignment:
            // Format: ecs_slaves.mac_address.cam[index].group = group_name
            if (parts.length > 3 && parts[2].startsWith('cam')) {
              final cameraIndex = parts[2].replaceAll('cam', '').replaceAll(RegExp(r'\[|\]'), '');
              await FileLogger.log('Kamera-grup ataması (Yeni kategori): ${parts[0]}.${parts[1]}.${parts[2]}.group = $value', tag: 'GROUP_DEBUG');
              await _processCameraGroupAssignment(device, cameraIndex, value.toString());
            }
            break;
          case MessageCategory.cameraGroupDefinition:
            // Format: ecs_slaves.mac_address.configuration.cameraGroups[index] = group_name
            if (parts.length > 3 && parts[2] == 'configuration' && parts[3].startsWith('cameraGroups')) {
              final groupIndex = parts[3].replaceAll('cameraGroups', '').replaceAll(RegExp(r'\[|\]'), '');
              await FileLogger.log('Grup tanımı (Yeni kategori): ${parts[0]}.${parts[1]}.${parts[2]}.${parts[3]} = $value', tag: 'GROUP_DEBUG');
              await _processGroupDefinition(device, groupIndex, value.toString());
            }
            break;
          case MessageCategory.unknown:
            // Eski kodlardan gelebilecek mesajları desteklemek için bırakıyoruz
            // Format: ecs_slaves.mac_address.cam[index].group = group_name
            if (parts.length > 3 && parts[2] == 'cam' && parts.length > 4 && parts[4] == 'group') {
              final cameraIndex = parts[3].replaceAll(RegExp(r'\[|\]'), '');
              await FileLogger.log('Kamera-grup ataması (Eski format): ${parts[0]}.${parts[1]}.cam[$cameraIndex].group = $value', tag: 'GROUP_DEBUG');
              await _processCameraGroupAssignment(device, cameraIndex, value.toString());
            }
            // Format: ecs_slaves.mac_address.configuration.cameraGroups[index] = group_name
            else if (parts.length > 3 && parts[2] == 'configuration' && parts[3].startsWith('cameraGroups')) {
              final groupIndex = parts[3].replaceAll('cameraGroups', '').replaceAll(RegExp(r'\[|\]'), '');
              await FileLogger.log('Grup tanımı: ${parts[0]}.${parts[1]}.configuration.cameraGroups[$groupIndex] = $value', tag: 'GROUP_DEBUG');
              await _processGroupDefinition(device, groupIndex, value.toString());
            } 
            else {
              await FileLogger.log('Unknown message category: ${parts[2]}', tag: 'CAMERA_WARN');
            }
            break;
        }
        
        // Her alan güncellemesinden sonra değişiklikleri bildir
        notifyListeners();
      }
    } catch (e) {
      // Hata durumunda güvenli şekilde işle ve loglama yap
      await FileLogger.log('Error processing WebSocket message: $e', tag: 'CAMERA_ERROR');
      debugPrint('Error processing WebSocket message: $e');
    }
  }
  
  // Mesaj kategorilerini belirle - WebSocket mesajı ne tür bir veri içeriyor?
  MessageCategory _categorizeMessage(String pathComponent, List<String> remainingPath) {
    // Önce log tut
    FileLogger.log('Mesaj kategorizasyon: component=$pathComponent, remaining=${remainingPath.join(", ")}', 
      tag: 'CAT_DEBUG').then((_) {});
      
    // Grup ilgili özel durumlar
    if (pathComponent == 'configuration' && remainingPath.isNotEmpty && 
        remainingPath[0].startsWith('cameraGroups')) {
      FileLogger.log('Grup tanımı bulundu: $pathComponent ${remainingPath.join(", ")}', 
        tag: 'GROUP_DEBUG').then((_) {});
      return MessageCategory.cameraGroupDefinition;
    }
    
    // Kamera grubu ataması
    if (pathComponent.startsWith('cam') && remainingPath.isNotEmpty && 
        remainingPath.contains('group')) {
      FileLogger.log('Kamera grup ataması bulundu: $pathComponent ${remainingPath.join(", ")}', 
        tag: 'GROUP_DEBUG').then((_) {});
      return MessageCategory.cameraGroupAssignment;
    }
    
    // Diğer kategoriler
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
      FileLogger.log('Kategori belirlenemeyen mesaj: $pathComponent ${remainingPath.join(", ")}', 
        tag: 'CAT_DEBUG').then((_) {});
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
        uptime: '',
        deviceType: '',
        firmwareVersion: '',
        recordPath: '',
        cameras: [],
      );
      FileLogger.log('New device created with macKey: $macKey', tag: 'CAMERA_NEW');
    }
    return _devices[macKey]!;
  }
  
  // Kamera verilerini işle
  Future<void> _processCameraData(CameraDevice device, String camIndexPath, List<String> properties, dynamic value) async {
    // TAM LOG: Gelen kamera veri mesajının detaylarını kaydet
    await FileLogger.log(
      "KAMERA VERİSİ - Device: ${device.macKey}, Path: $camIndexPath, Properties: ${properties.join('.')}, Value: $value",
      tag: 'CAMERA_TRACE'
    );
    
    // Kamera indeksini çıkar: cam[0] -> 0
    String indexStr = camIndexPath.substring(4, camIndexPath.indexOf(']'));
    int cameraIndex = int.tryParse(indexStr) ?? -1;
    
    if (cameraIndex < 0) {
      await FileLogger.log('Invalid camera index in path: $camIndexPath', tag: 'CAMERA_ERROR');
      return;
    }
    
    // Özellik yolu boşsa işlemi atla
    if (properties.isEmpty) {
      await FileLogger.log('Missing camera property for camera index $cameraIndex', tag: 'CAMERA_WARN');
      return;
    }
    
    String propertyName = properties[0];
    await FileLogger.log(
      "Mevcut kameralar: ${device.cameras.length} - İşlenen indeks: $cameraIndex - İşlenen özellik: $propertyName=$value",
      tag: 'CAMERA_DEBUG'
    );
    
    // Kamera mevcut mu kontrol et
    bool cameraExists = cameraIndex < device.cameras.length;
    await FileLogger.log(
      "Kamera #$cameraIndex mevcut mu: $cameraExists - Device: ${device.macKey}", 
      tag: 'CAMERA_DEBUG'
    );
    
    // Kamera mevcut değilse ve kritik bir özellikse kamera oluştur
    if (cameraIndex >= device.cameras.length) {
      // Sadece önemli özelliklerde kamera oluştur
      bool isEssential = _isEssentialCameraProperty(propertyName, value);
      await FileLogger.log(
        "Kamera #$cameraIndex yok - Özellik '$propertyName=$value' kritik mi: $isEssential",
        tag: 'CAMERA_DEBUG'
      );
      
      if (!isEssential) {
        await FileLogger.log(
          'Kamera yaratma atlandı - Kritik olmayan özellik: $propertyName = $value', 
          tag: 'CAMERA_SKIP'
        );
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
      await FileLogger.log('Empty camera report path for device: ${device.macKey}', tag: 'CAMERA_WARN');
      return;
    }
    
    // camreports.KAMERA1.property formatindaki veriyi isle
    String reportName = reportPath[0]; // Ornek: KAMERA1
    
    // Eger property kismi yoksa isleme
    if (reportPath.length < 2) {
      await FileLogger.log('Missing property in camera report: $reportName', tag: 'CAMREPORT_WARN');
      return;
    }
    
    // Rapor ozelligini al (ornek: connected, disconnected, last_seen_at vs.)
    String reportProperty = reportPath[1];
    
    // Rapor verilerini logla
    await FileLogger.log(
      'Camera report: $reportName, property: $reportProperty, value: $value',
      tag: 'CAMREPORT'
    );
    
    // Bu rapor adina karsilik gelen kamerayi bul
    // Not: Kamera adi ile rapor adi genellikle ayni oluyor (ornek: KAMERA1)
    Camera? matchingCamera;
    
    // Mevcut kameralari kontrol et
    for (var camera in device.cameras) {
      if (camera.name == reportName) {
        matchingCamera = camera;
        break;
      }
    }
    
    // Eslesen kamera yoksa, yeni bir log olustur
    if (matchingCamera == null) {
      await FileLogger.log(
        'No matching camera found for report: $reportName, property: $reportProperty',
        tag: 'CAMREPORT_MISS'
      );
      // Kamera durumu guncellemek istiyorsak kamera raporlarini saklayabiliriz
      // Buraya kod ekleyebiliriz
      return;
    }
    
    // Eslesen kameranin rapor bilgilerini guncelle
    await _updateCameraReportProperty(matchingCamera, reportProperty, value);
  }
  
  // Kamera rapor ozelliklerini guncelleme
  Future<void> _updateCameraReportProperty(Camera camera, String propertyName, dynamic value) async {
    // Ozellige gore kamera raporunu guncelle
    switch (propertyName.toLowerCase()) {
      case 'connected':
        bool isConnected = value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1');
        camera.connected = isConnected;
        await FileLogger.log('Updated camera ${camera.name} connected status to: $isConnected from report', tag: 'CAMREPORT_UPDATE');
        break;
        
      case 'disconnected':
        camera.disconnected = value.toString();
        await FileLogger.log('Updated camera ${camera.name} disconnected time to: ${camera.disconnected} from report', tag: 'CAMREPORT_UPDATE');
        break;
        
      case 'last_seen_at':
        camera.lastSeenAt = value.toString();
        await FileLogger.log('Updated camera ${camera.name} last seen time to: ${camera.lastSeenAt} from report', tag: 'CAMREPORT_UPDATE');
        break;
        
      case 'recording':
        bool isRecording = value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1');
        camera.recording = isRecording;
        await FileLogger.log('Updated camera ${camera.name} recording status to: $isRecording from report', tag: 'CAMREPORT_UPDATE');
        break;
        
      case 'last_restart_time':
        camera.lastRestartTime = value.toString();
        await FileLogger.log('Updated camera ${camera.name} last restart time to: ${camera.lastRestartTime} from report', tag: 'CAMREPORT_UPDATE');
        break;
        
      case 'reported':
        camera.reportError = value.toString();
        await FileLogger.log('Updated camera ${camera.name} report error to: ${camera.reportError} from report', tag: 'CAMREPORT_UPDATE');
        break;
        
      default:
        await FileLogger.log('Unhandled camera report property: $propertyName with value: $value', tag: 'CAMREPORT_UNKNOWN');
        break;
    }
    
    // Rapor icin kamera adini kaydet
    camera.reportName = camera.name;
  }
  
  // Sistem bilgilerini işle
  Future<void> _processSystemInfo(CameraDevice device, List<String> infoPath, dynamic value) async {
    if (infoPath.isEmpty) {
      await FileLogger.log('Empty system info path for device: ${device.macKey}', tag: 'CAMERA_WARN');
      return;
    }
    
    String infoType = infoPath[0];
    
    // Her bir sistem bilgisi alanı için sadece o alanı güncelle
    try {
      switch (infoType) {
        case 'upTime':
          // Sadece uptime bilgisini güncelle, diğerlerini etkileme
          device.uptime = value.toString();
          await FileLogger.log('Güncelleme - device ${device.macKey} uptime: ${device.uptime}', tag: 'SYSINFO');
          break;
          
        case 'cpuTemp':
          // Sadece CPU sıcaklığını güncelle
          double temp = double.tryParse(value.toString()) ?? 0.0;
          device.cpuTemp = temp;
          await FileLogger.log('Güncelleme - CPU Temperature: $temp°C', tag: 'CPU_TEMP');
          break;
          
        case 'thermal[0]': // Alternatif sıcaklık bilgisi
          double temp = double.tryParse(value.toString()) ?? 0.0;
          // CPU sıcaklığı henüz ayarlanmamışsa veya bu değer daha yüksekse güncelle
          if (device.cpuTemp == 0.0 || temp > device.cpuTemp) {
            device.cpuTemp = temp;
            await FileLogger.log('Güncelleme - Thermal Temperature: $temp°C', tag: 'CPU_TEMP');
          }
          break;
          
        case 'eth0':
          // Sadece ağ bilgisini güncelle
          device.networkInfo = value.toString();
          await FileLogger.log('Güncelleme - Network Info: ${device.networkInfo}', tag: 'SYSINFO');
          break;
          
        case 'freeRam':
          // Sadece boş RAM bilgisini güncelle
          int ram = int.tryParse(value.toString()) ?? 0;
          device.freeRam = ram;
          await FileLogger.log('Güncelleme - Free RAM: ${_formatBytes(ram)}', tag: 'SYSINFO');
          break;
          
        case 'totalRam':
          // Sadece toplam RAM bilgisini güncelle
          int ram = int.tryParse(value.toString()) ?? 0;
          device.totalRam = ram;
          await FileLogger.log('Güncelleme - Total RAM: ${_formatBytes(ram)}', tag: 'SYSINFO');
          break;
          
        case 'totalconns': // Toplam bağlantı sayısı
          // Sadece bağlantı sayısını güncelle
          int conns = int.tryParse(value.toString()) ?? 0;
          device.totalConnections = conns;
          await FileLogger.log('Güncelleme - Total Connections: $conns', tag: 'SYSINFO');
          break;
          
        case 'sessions': // Oturum sayısı
          // Sadece oturum sayısını güncelle
          int sessions = int.tryParse(value.toString()) ?? 0;
          device.totalSessions = sessions;
          await FileLogger.log('Güncelleme - Total Sessions: $sessions', tag: 'SYSINFO');
          break;
          
        // Diğer sistem bilgilerini işle ama zaten var olan değerleri değiştirme
        default:
          await FileLogger.log('İşlenmeyen sistem bilgisi: $infoType = $value', tag: 'SYSINFO');
          break;
      }
    } catch (e) {
      // Hata durumunda htanın hangi alanda oluştuğunu kaydet
      await FileLogger.log('Sistem bilgisi güncelleme hatası - $infoType: $e', tag: 'SYSINFO_ERROR');
    }
  }

  // Byte değerlerini insan okunabilir formata çevirir
  String _formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
  
  // Konfigürasyon verilerini işle
  Future<void> _processConfiguration(CameraDevice device, List<String> configPath, dynamic value) async {
    if (configPath.isEmpty) {
      await FileLogger.log('Empty configuration path for device: ${device.macKey}', tag: 'CAMERA_WARN');
      return;
    }
    
    String configType = configPath[0];
    List<String> configProps = configPath.length > 1 ? configPath.sublist(1) : [];
    
    await FileLogger.log(
      'Processing configuration property: ${configProps.isNotEmpty ? configProps.join('.') : configType} for device ${device.macKey} with value: $value',
      tag: 'CONFIG'
    );
  }
  
  // Temel cihaz özelliklerini işle
  Future<void> _processBasicDeviceProperty(CameraDevice device, String propertyName, dynamic value) async {
    propertyName = propertyName.toLowerCase();
    
    switch (propertyName) {
      case 'ipv4':
        device.ipv4 = value.toString();
        await FileLogger.log('Set device ${device.macKey} ipv4 to: ${device.ipv4}', tag: 'DEVICE_PROP');
        break;
      case 'lastseenat':
      case 'last_seen_at':
        device.lastSeenAt = value.toString();
        await FileLogger.log('Set device ${device.macKey} lastSeenAt to: ${device.lastSeenAt}', tag: 'DEVICE_PROP');
        break;
      case 'connected':
        device.connected = value is bool ? value : (value.toString().toLowerCase() == 'true');
        await FileLogger.log('Set device ${device.macKey} connected to: ${device.connected}', tag: 'DEVICE_PROP');
        break;
      case 'uptime':
        device.uptime = value.toString();
        await FileLogger.log('Set device ${device.macKey} uptime to: ${device.uptime}', tag: 'DEVICE_PROP');
        break;
      case 'version':
        device.firmwareVersion = value.toString();
        await FileLogger.log('Set device ${device.macKey} version/firmwareVersion to: ${device.firmwareVersion}', tag: 'DEVICE_PROP');
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
        await FileLogger.log('Device $propertyName: $value - Not storing this value currently', tag: 'DEVICE_PROP');
        break;
      default:
        await FileLogger.log('Unknown device property: $propertyName with value: $value', tag: 'DEVICE_PROP');
        break;
    }
  }
  
  // Kamera oluşturma (SADECE BELLİ BİR İNDEKS İÇİN)
  Future<void> _createCamera(CameraDevice device, int cameraIndex, String initialPropertyName, dynamic initialValue) async {
    // ÖNEMLİ LOG: Kamera oluşturma isteğinin ayrıntılarını kaydet
    await FileLogger.log(
      "!!! KAMERA OLUSTURMA BASLATILIYOR !!! - Device: ${device.macKey}, Index: $cameraIndex, Ozellik: $initialPropertyName, Deger: $initialValue",
      tag: 'CAMERA_CREATE'
    );
    
    // Mevcut kamera sayısı ile hedef indeks arasında boşluk var mı kontrol et
    if (device.cameras.length < cameraIndex) {
      await FileLogger.log(
        "ARA BOSLUK MEVCUT: ${device.cameras.length} --> $cameraIndex. Bu boslukta kamera olusturulmayacak.",
        tag: 'CAMERA_SKIP'
      );
    }
    
    int indexDiff = cameraIndex - device.cameras.length;
    if (indexDiff > 0) {
      await FileLogger.log(
        "ATLANAN KAMERA SAYISI: $indexDiff (Index $cameraIndex icin dogrudan olusturuluyor)",
        tag: 'CAMERA_SKIP'
      );
    }
    
    // Kamera verilerini hazırla
    // Kamera adını belirle - özellik "name" ise değerini kullan, değilse indekse göre oluştur
    String cameraName = initialPropertyName == 'name' ? initialValue.toString() : 'Camera ${cameraIndex + 1}';
    
    // Kamera IP'sini belirle - özellik "cameraIp" ise değerini kullan
    String cameraIp = initialPropertyName == 'cameraIp' ? initialValue.toString() : '';
    
    // Kamera markasını belirle - özellik "brand" ise değerini kullan
    String brand = initialPropertyName == 'brand' ? initialValue.toString() : '';
    
    // Listeyi genislet - SADECE TAM KAMERALARIN SAYISINI GENISLET, ARA BOSLUKLARA KAMERA EKLEME
    if (device.cameras.length != cameraIndex) {
      // Bosluk durumunda liste boyutunu ayarla (dart'ta dogrudan indeksle eleman ekleyemiyoruz)
      // Bosluklari ekleyip sonra bunlari silecegiz
      while (device.cameras.length < cameraIndex) {
        await FileLogger.log(
          "Bos liste boyutu artirildi ${device.cameras.length} -> ${device.cameras.length + 1}",
          tag: 'CAMERA_INTERNAL'
        );
        
        // Bos kamera ekle (sonra temizlenecek)
        String tempName = "DUMMY_KAMERA_${device.cameras.length}";
        device.cameras.add(Camera(
          index: device.cameras.length,
          name: tempName,
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
      }
    }
   
    // Istenilen indekse yeni kamerayi olustur/guncelle
    Camera newCamera = Camera(
      index: cameraIndex,
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
    );
    
    // Kamerayi ekle veya guncelle
    if (device.cameras.length <= cameraIndex) {
      device.cameras.add(newCamera);  // Yeni kamera ekle
      await FileLogger.log(
        "YENI KAMERA EKLENDI: $cameraIndex, Name: $cameraName, Ozellik: $initialPropertyName=$initialValue",
        tag: 'CAMERA_NEW'
      );
    } else {
      // Mevcut bos kamerayi guncelle
      device.cameras[cameraIndex] = newCamera;
      await FileLogger.log(
        "MEVCUT KAMERA GUNCELLENDI: $cameraIndex, Name: $cameraName, Ozellik: $initialPropertyName=$initialValue",
        tag: 'CAMERA_UPDATE'
      );
    }
    
    // Bos (DUMMY) kameralari temizle
    device.cameras.removeWhere((camera) => camera.name.startsWith('DUMMY_KAMERA_'));
    
    // Islem tamamlandi
    await FileLogger.log(
      "KAMERA OLUSTURMA TAMAMLANDI - Device: ${device.macKey}, Kamera Listesi Boyutu: ${device.cameras.length}, Son Eklenen: $cameraName",
      tag: 'CAMERA_CREATE_DONE'
    );
  }
  
  // Kamera özelliği güncellemesi
  Future<void> _updateCameraProperty(Camera camera, String propertyName, dynamic value) async {
    // Özellik güncellemesini logla
    await FileLogger.log(
      'Updating camera[${camera.index}] property: $propertyName, value: $value (${value.runtimeType})', 
      tag: 'CAMERA_PROP'
    );
    
    // Özelliği güncelle
    switch (propertyName) {
      case 'name':
        String oldName = camera.name;
        camera.name = value.toString();
        await FileLogger.log('Set camera[${camera.index}] name from "$oldName" to: "${camera.name}"', tag: 'CAMERA_PROP');
        break;
      case 'cameraIp':
        camera.ip = value.toString();
        await FileLogger.log('Set camera[${camera.index}] IP to: ${camera.ip}', tag: 'CAMERA_PROP');
        break;
      case 'cameraRawIp':
        camera.rawIp = value is int ? value : int.tryParse(value.toString()) ?? 0;
        await FileLogger.log('Set camera[${camera.index}] rawIp to: ${camera.rawIp}', tag: 'CAMERA_PROP');
        break;
      case 'username':
        camera.username = value.toString();
        await FileLogger.log('Set camera[${camera.index}] username to: ${camera.username}', tag: 'CAMERA_PROP');
        break;
      case 'password':
        camera.password = value.toString();
        await FileLogger.log('Set camera[${camera.index}] password to: [REDACTED]', tag: 'CAMERA_PROP');
        break;
      case 'brand':
        camera.brand = value.toString();
        await FileLogger.log('Set camera[${camera.index}] brand to: ${camera.brand}', tag: 'CAMERA_PROP');
        break;
      case 'hw':
        camera.hw = value.toString();
        await FileLogger.log('Set camera[${camera.index}] hw to: ${camera.hw}', tag: 'CAMERA_PROP');
        break;
      case 'manufacturer':
        camera.manufacturer = value.toString();
        await FileLogger.log('Set camera[${camera.index}] manufacturer to: ${camera.manufacturer}', tag: 'CAMERA_PROP');
        break;
      case 'country':
        camera.country = value.toString();
        await FileLogger.log('Set camera[${camera.index}] country to: ${camera.country}', tag: 'CAMERA_PROP');
        break;
      case 'xAddrs':
        camera.xAddrs = value.toString();
        await FileLogger.log('Set camera[${camera.index}] xAddrs to: ${camera.xAddrs}', tag: 'CAMERA_PROP');
        break;
      case 'mediaUri':
        camera.mediaUri = value.toString();
        await FileLogger.log('Set camera[${camera.index}] mediaUri to: ${camera.mediaUri}', tag: 'CAMERA_PROP');
        break;
      case 'recordUri':
        camera.recordUri = value.toString();
        await FileLogger.log('Set camera[${camera.index}] recordUri to: ${camera.recordUri}', tag: 'CAMERA_PROP');
        break;
      case 'subUri':
        camera.subUri = value.toString();
        await FileLogger.log('Set camera[${camera.index}] subUri to: ${camera.subUri}', tag: 'CAMERA_PROP');
        break;
      case 'remoteUri':
        camera.remoteUri = value.toString();
        await FileLogger.log('Set camera[${camera.index}] remoteUri to: ${camera.remoteUri}', tag: 'CAMERA_PROP');
        break;
      case 'mainSnapShot':
        camera.mainSnapShot = value.toString();
        await FileLogger.log('Set camera[${camera.index}] mainSnapShot to: ${camera.mainSnapShot}', tag: 'CAMERA_PROP');
        break;
      case 'subSnapShot':
        camera.subSnapShot = value.toString();
        await FileLogger.log('Set camera[${camera.index}] subSnapShot to: ${camera.subSnapShot}', tag: 'CAMERA_PROP');
        break;
      case 'recordPath':
        camera.recordPath = value.toString();
        await FileLogger.log('Set camera[${camera.index}] recordPath to: ${camera.recordPath}', tag: 'CAMERA_PROP');
        break;
        
      case 'disconnected':
        camera.disconnected = value.toString();
        await FileLogger.log('Set camera[${camera.index}] disconnected to: ${camera.disconnected}', tag: 'CAMERA_PROP');
        break;
        
      case 'lastSeenAt':
        camera.lastSeenAt = value.toString();
        await FileLogger.log('Set camera[${camera.index}] lastSeenAt to: ${camera.lastSeenAt}', tag: 'CAMERA_PROP');
        break;
        
      case 'recording':
        camera.recording = value is bool ? value : (value.toString().toLowerCase() == 'true');
        await FileLogger.log('Set camera[${camera.index}] recording to: ${camera.recording}', tag: 'CAMERA_PROP');
        break;

      // Codec bilgileri
      case 'recordcodec':
        camera.recordCodec = value.toString();
        await FileLogger.log('Set camera[${camera.index}] recordCodec to: ${camera.recordCodec}', tag: 'CAMERA_PROP');
        break;
      case 'subcodec':
        camera.subCodec = value.toString();
        await FileLogger.log('Set camera[${camera.index}] subCodec to: ${camera.subCodec}', tag: 'CAMERA_PROP');
        break;
        
      // Çözünürlük bilgileri - ana akış
      case 'recordwidth':
      case 'recordwith': // yazım hatası - sunucudan gelen mesajda böyle
        camera.recordWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
        await FileLogger.log('Set camera[${camera.index}] recordWidth (from ${propertyName}) to: ${camera.recordWidth}', tag: 'CAMERA_PROP');
        // Kamera nesnesinde doğrudan değeri kontrol edelim
        await FileLogger.log('After update camera recordWidth = ${camera.recordWidth}, recordHeight = ${camera.recordHeight}', tag: 'CAMERA_DEBUG');
        break;
        
      case 'recordheight':
        camera.recordHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
        await FileLogger.log('Set camera[${camera.index}] recordHeight to: ${camera.recordHeight}', tag: 'CAMERA_PROP');
        // Kamera nesnesinde doğrudan değeri kontrol edelim
        await FileLogger.log('After update camera recordWidth = ${camera.recordWidth}, recordHeight = ${camera.recordHeight}', tag: 'CAMERA_DEBUG');
        break;
        
      // Çözünürlük bilgileri - alt akış
      case 'subwidth':
        camera.subWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
        await FileLogger.log('Set camera[${camera.index}] subWidth to: ${camera.subWidth}', tag: 'CAMERA_PROP');
        // Alt çözünürlük bilgilerini kontrol et
        await FileLogger.log('After update camera subWidth = ${camera.subWidth}, subHeight = ${camera.subHeight}', tag: 'CAMERA_DEBUG');
        break;
      
      case 'subheight':
        camera.subHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
        await FileLogger.log('Set camera[${camera.index}] subHeight to: ${camera.subHeight}', tag: 'CAMERA_PROP');
        // Alt çözünürlük bilgilerini kontrol et
        await FileLogger.log('After update camera subWidth = ${camera.subWidth}, subHeight = ${camera.subHeight}', tag: 'CAMERA_DEBUG');
        break;
        
      // Ses kayıt bilgisi
      case 'soundrec':
        camera.soundRec = value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1');
        await FileLogger.log('Set camera[${camera.index}] soundRec to: ${camera.soundRec}', tag: 'CAMERA_PROP');
        break;
      
      // ONVIF adres bilgisi
      case 'xaddr':
        camera.xAddr = value.toString();
        await FileLogger.log('Set camera[${camera.index}] xAddr to: ${camera.xAddr}', tag: 'CAMERA_PROP');
        break;
        
      // Kamera durumu
      case 'connected':
        camera.connected = value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1');
        await FileLogger.log('Set camera[${camera.index}] connected to: ${camera.connected}', tag: 'CAMERA_PROP');
        break;
        
      // Diğer kamera özellikleri için
      default:
        await FileLogger.log('Unknown camera property: $propertyName with value: $value', tag: 'CAMERA_WARN');
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
  
  // Kamera-grup atama işleme - ecs_slaves.mac_address.cam[index].group = group_name
  // WebSocket'ten gelen grup atamalarnı işler
  Future<void> _processCameraGroupAssignment(CameraDevice device, String cameraIndex, String groupName) async {
    try {
      // Kamera indeksini parse et
      final int camIdx = int.tryParse(cameraIndex) ?? -1;
      if (camIdx < 0 || camIdx >= device.cameras.length) {
        await FileLogger.log('Geçersiz kamera indeksi: $cameraIndex', tag: 'GROUP_ERROR');
        return;
      }

      // Cihaz MAC adresini bul
      final String deviceMacKey = _devices.entries
          .firstWhere((entry) => entry.value == device, orElse: () => MapEntry('unknown', device))
          .key;

      // Kamera tanımlayıcısı oluştur (farklı formatlar için)
      final String cameraIdentifier = cameraIndex; // Basitçe indeks ("0", "1" vb.)
      final String camFormatIdentifier = "cam[$cameraIndex]"; // cam[index] formatı
      final String fullIdentifier = "$deviceMacKey.cam[$cameraIndex]"; // Tam format
      
      await FileLogger.log('WebSocket kamera grup ataması: Cihaz=${deviceMacKey}, Kamera=${camIdx}, Grup=${groupName}', tag: 'GROUP_INFO');

      // Grup boş mu? 
      if (groupName.isEmpty) {
        // Boş grup, kamerayı tüm gruplardan çıkar
        for (final group in _cameraGroups.values) {
          group.removeCamera(cameraIdentifier);
          group.removeCamera(camFormatIdentifier);
          group.removeCamera(fullIdentifier);
        }
        await FileLogger.log('Kamera tüm gruplardan çıkarıldı: MAC=${deviceMacKey}, Cam=${cameraIndex}', tag: 'GROUP_DEBUG');
        notifyListeners();
        return;
      }

      // Gerekirse grubu oluştur
      if (!_cameraGroups.containsKey(groupName)) {
        _cameraGroups[groupName] = CameraGroup(name: groupName);
        await FileLogger.log('WebSocket mesajından yeni grup oluşturuldu: $groupName', tag: 'GROUP_INFO');
      }

      // Önce tüm gruplardan çıkar
      for (final group in _cameraGroups.values) {
        group.removeCamera(cameraIdentifier);
        group.removeCamera(camFormatIdentifier);
        group.removeCamera(fullIdentifier);
      }
      
      // Yeni gruba ekle
      final group = _cameraGroups[groupName]!;
      group.addCamera(cameraIdentifier); // Basit indeks formatını ekle
      
      await FileLogger.log('Kamera gruba eklendi: $cameraIdentifier -> $groupName', tag: 'GROUP_INFO');
      await FileLogger.log('Grup içeriği: ${group.cameraMacs.join(", ")}', tag: 'GROUP_DEBUG');
      
      notifyListeners();
    } catch (e) {
      await FileLogger.log('Kamera grup atama hatası: $e', tag: 'GROUP_ERROR');
    }
  }
  
  // Grup tanımı işleme - ecs_slaves.mac_address.configuration.cameraGroups[index] = group_name
  Future<void> _processGroupDefinition(CameraDevice device, String groupIndex, String groupName) async {
    try {
      // Grup adı boş mu?
      if (groupName.isEmpty) {
        return;
      }
      
      await FileLogger.log('Grup tanımı: [$groupIndex] = $groupName', tag: 'GROUP_INFO');
      
      // Grup zaten var mı?
      if (!_cameraGroups.containsKey(groupName)) {
        _cameraGroups[groupName] = CameraGroup(name: groupName);
        await FileLogger.log('Yeni kamera grubu tanımlandı: $groupName', tag: 'GROUP_INFO');
      } else {
        await FileLogger.log('Mevcut grup: $groupName (kameralar: ${_cameraGroups[groupName]!.cameraMacs.length})', tag: 'GROUP_DEBUG');
      }
      
      notifyListeners();
    } catch (e) {
      await FileLogger.log('Error processing group definition: $e', tag: 'GROUP_ERROR');
    }
  }
}

// Mesaj kategorilerini tanımla
enum MessageCategory {
  camera,        // cam[INDEX].*
  cameraReport,  // camreports.*
  systemInfo,    // sysinfo.*
  configuration, // configuration.*
  basicProperty, // doğrudan cihaz özellikleri
  unknown,       // bilinmeyen mesaj tipi
  cameraGroupDefinition,  // Grup tanımı (configuration.cameraGroups[index])
  cameraGroupAssignment,   // Kamera-grup atama (cam[index].group)
}

// CameraDevicesProvider sınıfına yukarıdaki metod ve properties eklenecek
/* 
NOT: Bu kod parçası silinecek - metotlar sınıfın içine taşındı 
*/
