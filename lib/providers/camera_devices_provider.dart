import 'dart:async';
import 'dart:convert'; // Import for jsonDecode
import 'dart:math';

import 'package:flutter/foundation.dart'; // Added for debugPrint and min

import '../models/camera_device.dart';
import '../models/camera_group.dart';

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
  
  // Get device MAC address for a camera
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
      return [];
    }
    
    final group = _cameraGroups[groupName]!;
    final List<Camera> camerasInGroup = [];
    
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
        }
      }
    }
    
    // Test amaçlı olarak cihazların tüm kameralarını görelim
    for (final deviceEntry in _devices.entries) {
      final deviceMac = deviceEntry.key;
      final device = deviceEntry.value;
      for (int i = 0; i < device.cameras.length; i++) {
        final camera = device.cameras[i];
      }
    }
    
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
  Future<void> processWebSocketMessage(String messageString) async {
    try {
      final Map<String, dynamic> message = jsonDecode(messageString);

      if (message['c'] != 'changed' || !message.containsKey('data') || !message.containsKey('val')) {
        debugPrint("CDP: Discarding message due to missing fields or incorrect command: $messageString");
        return;
      }
      
      final String dataPath = message['data'] as String;
      final dynamic value = message['val'];

      debugPrint("CDP: Processing dataPath: $dataPath, value: $value");

      if (!dataPath.startsWith('ecs_slaves.')) {
        debugPrint("CDP: Discarding message - dataPath does not start with ecs_slaves: $dataPath");
        return;
      }
      
      final parts = dataPath.split('.');
      if (parts.length < 2) {
        debugPrint("CDP: Discarding message - dataPath has too few parts: $dataPath");
        return;
      }
      
      final macKey = parts[1];
      final macAddress = macKey.startsWith('m_') ? macKey.substring(2).replaceAll('_', ':') : macKey;

      final device = _getOrCreateDevice(macKey, macAddress);
      
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
            if (parts.length > 3 && parts[2] == 'cam' && parts.length > 4 && parts[4] == 'group') {
              final cameraIndex = parts[3].replaceAll(RegExp(r'\\[|\\]'), '');
              await _processCameraGroupAssignment(device, cameraIndex, value.toString());
            }
            else if (parts.length > 3 && parts[2] == 'configuration' && parts[3].startsWith('cameraGroups')) {
              final groupIndex = parts[3].replaceAll('cameraGroups', '').replaceAll(RegExp(r'\\[|\\]'), '');
              await _processGroupDefinition(device, groupIndex, value.toString());
            } 
            else {
              debugPrint("CDP: Unknown message structure for category UNKNOWN: $dataPath");
            }
            break;
        }
        
        notifyListeners();
      }
    } catch (e, s) {
      debugPrint("CDP: Error processing WebSocket message: $e");
      debugPrint("CDP: Stacktrace: $s");
    }
  }
  
  // Mesaj kategorilerini belirle - WebSocket mesajı ne tür bir veri içeriyor?
  MessageCategory _categorizeMessage(String pathComponent, List<String> remainingPath) {
    // Önce log tut
    // Grup ilgili özel durumlar
    if (pathComponent == 'configuration' && remainingPath.isNotEmpty && 
        remainingPath[0].startsWith('cameraGroups')) {
      return MessageCategory.cameraGroupDefinition;
    }
    
    // Kamera grubu ataması
    if (pathComponent.startsWith('cam') && remainingPath.isNotEmpty && 
        remainingPath.contains('group')) {
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
        online: false, // ADDED
        firstTime: '', // ADDED
        uptime: '',
        deviceType: '',
        firmwareVersion: '',
        recordPath: '',
        cameras: [],
      );
    }
    return _devices[macKey]!;
  }

  // Kamera verilerini işle
  Future<void> _processCameraData(CameraDevice device, String camIndexPath, List<String> properties, dynamic value) async {
    // Kamera indeksini çıkar: cam[0] -> 0
    // String indexStr = camIndexPath.substring(4, camIndexPath.indexOf(']'));
    // int cameraIndex = int.tryParse(indexStr) ?? -1;

    int cameraIndex = -1;
    if (camIndexPath.startsWith('cam[') && camIndexPath.endsWith(']')) {
      // Ensure there's something between cam[ and ]
      if (camIndexPath.length > 5) { // "cam[]".length is 5
        String indexStr = camIndexPath.substring(4, camIndexPath.length - 1);
        cameraIndex = int.tryParse(indexStr) ?? -1;
      } else {
        debugPrint("CDP: _processCameraData: Invalid camIndexPath format (empty index): $camIndexPath");
      }
    } else {
      debugPrint("CDP: _processCameraData: Invalid camIndexPath format (missing brackets or prefix): $camIndexPath");
    }
    
    if (cameraIndex < 0) {
      debugPrint("CDP: _processCameraData: Could not parse valid camera index from $camIndexPath. Discarding update.");
      return;
    }
    
    // Özellik yolu boşsa işlemi atla
    if (properties.isEmpty) {
      return;
    }
    
    String propertyName = properties[0];
    
    // Kamera mevcut mu kontrol et
    bool cameraExists = cameraIndex < device.cameras.length;
    
    // Kamera mevcut değilse ve kritik bir özellikse kamera oluştur
    if (cameraIndex >= device.cameras.length) {
      // Sadece önemli özelliklerde kamera oluştur
      bool isEssential = _isEssentialCameraProperty(propertyName, value);
      
      if (!isEssential) {
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
      return;
    }
    
    // camreports.KAMERA1.property formatindaki veriyi isle
    String reportName = reportPath[0]; // Ornek: KAMERA1
    
    // Eger property kismi yoksa isleme
    if (reportPath.length < 2) {
      return;
    }
    
    // Rapor ozelligini al (ornek: connected, disconnected, last_seen_at vs.)
    String reportProperty = reportPath[1];
    
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
        break;
        
      case 'disconnected':
        camera.disconnected = value.toString();
        break;
        
      case 'last_seen_at':
        camera.lastSeenAt = value.toString();
        break;
        
      case 'recording':
        bool isRecording = value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1');
        camera.recording = isRecording;
        break;
        
      case 'last_restart_time':
        camera.lastRestartTime = value.toString();
        break;
        
      case 'reported':
        camera.reportError = value.toString();
        break;
        
      default:
        break;
    }
    
    // Rapor icin kamera adini kaydet
    camera.reportName = camera.name;
  }
  
  // Sistem bilgilerini işle
  Future<void> _processSystemInfo(CameraDevice device, List<String> infoPath, dynamic value) async {
    if (infoPath.isEmpty) {
      return;
    }
    
    String infoType = infoPath[0];
    
    // Her bir sistem bilgisi alanı için sadece o alanı güncelle
    try {
      switch (infoType) {
        case 'upTime':
          // Sadece uptime bilgisini güncelle, diğerlerini etkileme
          device.uptime = value.toString();
          break;
          
        case 'cpuTemp':
          // Sadece CPU sıcaklığını güncelle
          double temp = double.tryParse(value.toString()) ?? 0.0;
          device.cpuTemp = temp;
          break;
          
        case 'thermal[0]': // Alternatif sıcaklık bilgisi
          double temp = double.tryParse(value.toString()) ?? 0.0;
          // CPU sıcaklığı henüz ayarlanmamışsa veya bu değer daha yüksekse güncelle
          if (device.cpuTemp == 0.0 || temp > device.cpuTemp) {
            device.cpuTemp = temp;
          }
          break;
          
        case 'eth0':
          // Sadece ağ bilgisini güncelle
          device.networkInfo = value.toString();
          break;
          
        case 'freeRam':
          // Sadece boş RAM bilgisini güncelle
          int ram = int.tryParse(value.toString()) ?? 0;
          device.freeRam = ram;
          break;
          
        case 'totalRam':
          // Sadece toplam RAM bilgisini güncelle
          int ram = int.tryParse(value.toString()) ?? 0;
          device.totalRam = ram;
          break;
          
        case 'totalconns': // Toplam bağlantı sayısı
          // Sadece bağlantı sayısını güncelle
          int conns = int.tryParse(value.toString()) ?? 0;
          device.totalConnections = conns;
          break;
          
        case 'sessions': // Oturum sayısı
          // Sadece oturum sayısını güncelle
          int sessions = int.tryParse(value.toString()) ?? 0;
          device.totalSessions = sessions;
          break;
          
        // Diğer sistem bilgilerini işle ama zaten var olan değerleri değiştirme
        default:
          break;
      }
    } catch (e) {
      // Hata durumunda htanın hangi alanda oluştuğunu kaydet
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
      return;
    }
    
    String configType = configPath[0];
    List<String> configProps = configPath.length > 1 ? configPath.sublist(1) : [];
    
  }
  
  // Temel cihaz özelliklerini işle
  Future<void> _processBasicDeviceProperty(CameraDevice device, String propertyName, dynamic value) async {
    propertyName = propertyName.toLowerCase();

    switch (propertyName) {
      case 'ipv4':
        device.ipv4 = value.toString();
        break;
      case 'ipv6': // ADDED
        device.ipv6 = value.toString(); // ADDED
        break;
      case 'lastseenat':
      case 'last_seen_at':
        device.lastSeenAt = value.toString();
        break;
      case 'connected':
        device.connected = value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1'); // MODIFIED to handle '1'
        break;
      case 'online': 
        device.online = value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1'); 
        break;
      case 'firsttime': 
        device.firstTime = value.toString(); 
        break;
      case 'uptime':
        device.uptime = value.toString();
        break;
      case 'version': // This is firmware version
        device.firmwareVersion = value.toString();
        break;
      case 'name': // ADDED - This is deviceName
        device.deviceName = value.toString(); // ADDED
        break;
      case 'current_time': // ADDED
        device.currentTime = value.toString(); // ADDED
        break;
      case 'smartweb_version': // ADDED
        device.smartwebVersion = value.toString(); // ADDED
        break;
      case 'cputemp': // ADDED
        device.cpuTemp = double.tryParse(value.toString()) ?? 0.0; // ADDED
        break;
      case 'ismaster': // ADDED
      case 'is_master': // ADDED
        device.isMaster = value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1'); // ADDED
        break;
      case 'last_ts': // ADDED
        device.lastTs = value.toString(); // ADDED
        break;
      case 'cam_count': // ADDED
        device.camCount = int.tryParse(value.toString()) ?? 0; // ADDED
        break;
      // case 'online': // REMOVED from here as it's handled above
      case 'app_ready':
      case 'system_ready':
      case 'cam_ready':
      case 'configuration_ready':
      case 'camreports_ready':
      case 'movita_ready':
        break;
      default:
        break;
    }
  }
  
  // Kamera oluşturma (SADECE BELLİ BİR İNDEKS İÇİN)
  Future<void> _createCamera(CameraDevice device, int cameraIndex, String initialPropertyName, dynamic initialValue) async {
    // Mevcut kamera sayısı ile hedef indeks arasında boşluk var mı kontrol et
    if (device.cameras.length < cameraIndex) {
      return;
    }
    
    int indexDiff = cameraIndex - device.cameras.length;
    if (indexDiff > 0) {
      return;
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
    } else {
      // Mevcut bos kamerayi guncelle
      device.cameras[cameraIndex] = newCamera;
    }
    
    // Bos (DUMMY) kameralari temizle
    device.cameras.removeWhere((camera) => camera.name.startsWith('DUMMY_KAMERA_'));
    
    // Islem tamamlandi
  }
  
  // Kamera özelliği güncellemesi
  Future<void> _updateCameraProperty(Camera camera, String propertyName, dynamic value) async {
    // Özelliği güncelle
    switch (propertyName) {
      case 'name':
        String oldName = camera.name;
        camera.name = value.toString();
        break;
      case 'cameraIp':
        camera.ip = value.toString();
        break;
      case 'cameraRawIp':
        camera.rawIp = value is int ? value : int.tryParse(value.toString()) ?? 0;
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
      case 'xAddrs':
        camera.xAddrs = value.toString();
        break;
      case 'mediaUri':
        camera.mediaUri = value.toString();
        break;
      case 'recordUri':
        camera.recordUri = value.toString();
        break;
      case 'subUri':
        camera.subUri = value.toString();
        break;
      case 'remoteUri':
        camera.remoteUri = value.toString();
        break;
      case 'mainSnapShot':
        camera.mainSnapShot = value.toString();
        break;
      case 'subSnapShot':
        camera.subSnapShot = value.toString();
        break;
      case 'recordPath':
        camera.recordPath = value.toString();
        break;
        
      case 'disconnected':
        camera.disconnected = value.toString();
        break;
        
      case 'lastSeenAt':
        camera.lastSeenAt = value.toString();
        break;
        
      case 'recording':
        camera.recording = value is bool ? value : (value.toString().toLowerCase() == 'true');
        break;

      // Codec bilgileri
      case 'recordcodec':
        camera.recordCodec = value.toString();
        break;
      case 'subcodec':
        camera.subCodec = value.toString();
        break;
        
      // Çözünürlük bilgileri - ana akış
      case 'recordwidth':
      case 'recordwith': // yazım hatası - sunucudan gelen mesajda böyle
        camera.recordWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
        // Kamera nesnesinde doğrudan değeri kontrol edelim
        break;
        
      case 'recordheight':
        camera.recordHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
        // Kamera nesnesinde doğrudan değeri kontrol edelim
        break;
        
      // Çözünürlük bilgileri - alt akış
      case 'subwidth':
        camera.subWidth = value is int ? value : int.tryParse(value.toString()) ?? 0;
        // Alt çözünürlük bilgilerini kontrol et
        break;
      
      case 'subheight':
        camera.subHeight = value is int ? value : int.tryParse(value.toString()) ?? 0;
        // Alt çözünürlük bilgilerini kontrol et
        break;
        
      // Ses kayıt bilgisi
      case 'soundrec':
        camera.soundRec = value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1');
        break;
      
      // ONVIF adres bilgisi
      case 'xaddr':
        camera.xAddr = value.toString();
        break;
        
      // Kamera durumu
      case 'connected':
        // camera.connected = value is bool ? value : (value.toString().toLowerCase() == 'true' || value.toString() == '1'); // Old direct assignment
        camera.setConnectedStatus(value); // Use robust setter
        break;
        
      // Diğer kamera özellikleri için
      default:
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
      final int camIdx = int.tryParse(cameraIndex) ?? -1;
      if (camIdx < 0 || camIdx >= device.cameras.length) {
        debugPrint("CDP: Invalid camera index for group assignment: $cameraIndex");
        return;
      }

      final String deviceMacKey = _devices.entries
          .firstWhere((entry) => entry.value == device, orElse: () => MapEntry('unknown', device))
          .key;

      final String simpleCamIdentifier = cameraIndex; 
      final String camFormatIdentifier = "cam[$cameraIndex]"; 
      final String fullIdentifier = "$deviceMacKey.cam[$cameraIndex]"; 
      
      if (groupName.isEmpty) {
        for (final group in _cameraGroups.values) {
          group.removeCamera(simpleCamIdentifier);
          group.removeCamera(camFormatIdentifier);
          group.removeCamera(fullIdentifier);
        }
        debugPrint("CDP: Removed camera $simpleCamIdentifier from all groups.");
        notifyListeners();
        return;
      }

      if (!_cameraGroups.containsKey(groupName)) {
        _cameraGroups[groupName] = CameraGroup(name: groupName);
        debugPrint("CDP: Created new group: $groupName");
      }

      for (final group in _cameraGroups.values) {
        group.removeCamera(simpleCamIdentifier);
        group.removeCamera(camFormatIdentifier);
        group.removeCamera(fullIdentifier);
      }
      
      final group = _cameraGroups[groupName]!;
      group.addCamera(simpleCamIdentifier); 
      debugPrint("CDP: Assigned camera $simpleCamIdentifier to group: $groupName");
      
      notifyListeners();
    } catch (e, s) {
      debugPrint("CDP: Error in _processCameraGroupAssignment: $e");
      debugPrint("CDP: Stacktrace: $s");
    }
  }
  
  Future<void> _processGroupDefinition(CameraDevice device, String groupIndex, String groupName) async {
    try {
      if (groupName.isEmpty) {
        debugPrint("CDP: Ignoring empty group name for definition.");
        return;
      }
      
      if (!_cameraGroups.containsKey(groupName)) {
        _cameraGroups[groupName] = CameraGroup(name: groupName);
        debugPrint("CDP: Defined new group from configuration: $groupName");
      } else {
        debugPrint("CDP: Group $groupName already defined.");
      }
      
      notifyListeners();
    } catch (e, s) {
      debugPrint("CDP: Error in _processGroupDefinition: $e");
      debugPrint("CDP: Stacktrace: $s");
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
