import 'dart:convert';

enum DeviceStatus {
  online,
  offline,
  degraded,
  warning,
  error,
  unknown,
}

class CameraDevice {
  final String macAddress; // The actual MAC address in standard format (e.g., 26:C1:7A:0B:1F:19)
  final String macKey;     // The key used in the WebSocket messages (e.g., m_26_C1_7A_0B_1F_19)
  String ipv4;
  String lastSeenAt;
  bool connected;
  String uptime;
  String deviceType;
  String firmwareVersion;
  String recordPath;
  List<Camera> cameras;
  
  CameraDevice({
    required this.macAddress,
    required this.macKey,
    required this.ipv4,
    required this.lastSeenAt,
    required this.connected,
    required this.uptime,
    required this.deviceType,
    required this.firmwareVersion,
    required this.recordPath,
    required this.cameras,
  });
  
  // Copy with method for immutable updates
  CameraDevice copyWith({
    String? ipv4,
    String? lastSeenAt,
    bool? connected,
    String? uptime,
    String? deviceType,
    String? firmwareVersion,
    String? recordPath,
    List<Camera>? cameras,
  }) {
    return CameraDevice(
      macAddress: this.macAddress,
      macKey: this.macKey,
      ipv4: ipv4 ?? this.ipv4,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      connected: connected ?? this.connected,
      uptime: uptime ?? this.uptime,
      deviceType: deviceType ?? this.deviceType,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      recordPath: recordPath ?? this.recordPath,
      cameras: cameras ?? this.cameras,
    );
  }
  
  // Convert from JSON
  factory CameraDevice.fromJson(Map<String, dynamic> json) {
    return CameraDevice(
      macAddress: json['macAddress'],
      macKey: json['macKey'],
      ipv4: json['ipv4'] ?? '',
      lastSeenAt: json['lastSeenAt'] ?? '',
      connected: json['connected'] ?? false,
      uptime: json['uptime'] ?? '',
      deviceType: json['deviceType'] ?? '',
      firmwareVersion: json['firmwareVersion'] ?? '',
      recordPath: json['recordPath'] ?? '',
      cameras: (json['cameras'] as List<dynamic>?)
          ?.map((e) => Camera.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'macAddress': macAddress,
      'macKey': macKey,
      'ipv4': ipv4,
      'lastSeenAt': lastSeenAt,
      'connected': connected,
      'uptime': uptime,
      'deviceType': deviceType,
      'firmwareVersion': firmwareVersion,
      'recordPath': recordPath,
      'cameras': cameras.map((e) => e.toJson()).toList(),
    };
  }
  
  // Get the device status
  DeviceStatus get status {
    if (!connected) {
      return DeviceStatus.offline;
    }
    
    // Check if any cameras have issues
    bool hasWarning = false;
    bool hasError = false;
    
    for (final camera in cameras) {
      if (!camera.connected) {
        hasWarning = true;
      }
    }
    
    if (hasError) {
      return DeviceStatus.error;
    } else if (hasWarning) {
      return DeviceStatus.warning;
    } else {
      return DeviceStatus.online;
    }
  }

  @override
  String toString() {
    return 'CameraDevice{macAddress: $macAddress, ipv4: $ipv4, connected: $connected, cameras: ${cameras.length}}';
  }
}

class Camera {
  // ... mevcut alanlar ...
  String health; // camreports için sağlık bilgisi
  double temperature; // camreports için sıcaklık bilgisi
  final int index;            // Index of the camera in the device's cameras array
  String name;                // User-friendly name (e.g., KAMERA1)
  String ip;                  // IP address of the camera (cameraIp)
  int rawIp;                  // Raw IP address integer (cameraRawIp)
  String username;            // Username for authentication
  String password;            // Password for authentication
  String brand;               // Camera brand
  String hw;                  // Hardware identifier
  String manufacturer;        // Camera manufacturer
  String country;             // Camera country
  String xAddrs;              // ONVIF device service address
  String mediaUri;            // Main RTSP URI for live view
  String recordUri;           // RTSP URI for recording stream
  String subUri;              // RTSP URI for sub-stream (lower resolution)
  String remoteUri;           // RTSP URI for remote viewing
  String mainSnapShot;        // URL for main snapshot
  String subSnapShot;         // URL for sub-stream snapshot
  String recordPath;          // Recording path
  String recordCodec;         // Recording codec (e.g., H264)
  int recordWidth;            // Width of recording resolution
  int recordHeight;           // Height of recording resolution
  String subCodec;            // Sub-stream codec (e.g., H264)
  int subWidth;               // Width of sub-stream resolution
  int subHeight;              // Height of sub-stream resolution
  bool connected;             // Whether the camera is connected
  String disconnected;        // Disconnection info
  String lastSeenAt;          // When the camera was last seen
  bool recording;             // Whether the camera is currently recording
  
  bool soundRec;
  String xAddr;
  
  Camera({
    required this.index,
    this.health = '',
    this.temperature = 0.0,
    required this.name,
    required this.ip,
    this.rawIp = 0,
    required this.username,
    required this.password,
    required this.brand,
    this.hw = '',
    this.manufacturer = '',
    this.country = '',
    this.xAddrs = '',
    required this.mediaUri,
    required this.recordUri,
    required this.subUri,
    required this.remoteUri,
    required this.mainSnapShot,
    required this.subSnapShot,
    this.recordPath = '',
    this.recordCodec = '',
    required this.recordWidth,
    required this.recordHeight,
    this.subCodec = '',
    required this.subWidth,
    required this.subHeight,
    required this.connected,
    this.disconnected = '-',
    required this.lastSeenAt,
    required this.recording,
    this.soundRec = false,
    this.xAddr = '',
  });
  
  // Added id getter to uniquely identify cameras
  // Using a combination of name and index as id
  String get id => "${name}_$index";
  
  // Copy with method for immutable updates
  Camera copyWith({
    String? name,
    String? health,
    double? temperature,
    String? ip,
    int? rawIp,
    String? username,
    String? password,
    String? brand,
    String? hw,
    String? manufacturer,
    String? country,
    String? xAddrs,
    String? mediaUri,
    String? recordUri,
    String? subUri,
    String? remoteUri,
    String? mainSnapShot,
    String? subSnapShot,
    String? recordPath,
    String? recordCodec,
    int? recordWidth,
    int? recordHeight,
    String? subCodec,
    int? subWidth,
    int? subHeight,
    bool? connected,
    String? disconnected,
    String? lastSeenAt,
    bool? recording,
  }) {
    return Camera(
      index: this.index,
      health: health ?? this.health,
      temperature: temperature ?? this.temperature,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      rawIp: rawIp ?? this.rawIp,
      username: username ?? this.username,
      password: password ?? this.password,
      brand: brand ?? this.brand,
      hw: hw ?? this.hw,
      manufacturer: manufacturer ?? this.manufacturer,
      country: country ?? this.country,
      xAddrs: xAddrs ?? this.xAddrs,
      mediaUri: mediaUri ?? this.mediaUri,
      recordUri: recordUri ?? this.recordUri,
      subUri: subUri ?? this.subUri,
      remoteUri: remoteUri ?? this.remoteUri,
      mainSnapShot: mainSnapShot ?? this.mainSnapShot,
      subSnapShot: subSnapShot ?? this.subSnapShot,
      recordPath: recordPath ?? this.recordPath,
      recordCodec: recordCodec ?? this.recordCodec,
      recordWidth: recordWidth ?? this.recordWidth,
      recordHeight: recordHeight ?? this.recordHeight,
      subCodec: subCodec ?? this.subCodec,
      subWidth: subWidth ?? this.subWidth,
      subHeight: subHeight ?? this.subHeight,
      connected: connected ?? this.connected,
      disconnected: disconnected ?? this.disconnected,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      recording: recording ?? this.recording,
      soundRec: this.soundRec,
      xAddr: this.xAddr,
    );
  }
  
  // Convert from JSON
  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      index: json['index'] ?? 0,
      name: json['name'] ?? '',
      ip: json['ip'] ?? '',
      rawIp: json['rawIp'] ?? 0,
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      brand: json['brand'] ?? '',
      hw: json['hw'] ?? '',
      manufacturer: json['manufacturer'] ?? '',
      country: json['country'] ?? '',
      xAddrs: json['xAddrs'] ?? '',
      mediaUri: json['mediaUri'] ?? '',
      recordUri: json['recordUri'] ?? '',
      subUri: json['subUri'] ?? '',
      remoteUri: json['remoteUri'] ?? '',
      mainSnapShot: json['mainSnapShot'] ?? '',
      subSnapShot: json['subSnapShot'] ?? '',
      recordPath: json['recordPath'] ?? '',
      recordCodec: json['recordCodec'] ?? '',
      recordWidth: json['recordWidth'] ?? 0,
      recordHeight: json['recordHeight'] ?? 0,
      subCodec: json['subCodec'] ?? '',
      subWidth: json['subWidth'] ?? 0,
      subHeight: json['subHeight'] ?? 0,
      connected: json['connected'] ?? false,
      disconnected: json['disconnected'] ?? '',
      lastSeenAt: json['lastSeenAt'] ?? '',
      recording: json['recording'] ?? false,
      soundRec: json['soundRec'] ?? false,
      xAddr: json['xAddr'] ?? '',
      health: json['health'] ?? '',
      temperature: (json['temperature'] is num) ? (json['temperature'] as num).toDouble() : double.tryParse(json['temperature']?.toString() ?? '') ?? 0.0,
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'health': health,
      'temperature': temperature,
      'name': name,
      'ip': ip,
      'rawIp': rawIp,
      'username': username,
      'password': password,
      'brand': brand,
      'hw': hw,
      'manufacturer': manufacturer,
      'country': country,
      'xAddrs': xAddrs,
      'mediaUri': mediaUri,
      'recordUri': recordUri,
      'subUri': subUri,
      'remoteUri': remoteUri,
      'mainSnapShot': mainSnapShot,
      'subSnapShot': subSnapShot,
      'recordPath': recordPath,
      'recordCodec': recordCodec,
      'recordWidth': recordWidth,
      'recordHeight': recordHeight,
      'subCodec': subCodec,
      'subWidth': subWidth,
      'subHeight': subHeight,
      'connected': connected,
      'disconnected': disconnected,
      'lastSeenAt': lastSeenAt,
      'recording': recording,
      'soundRec': soundRec,
      'xAddr': xAddr,
    };
  }
  
  // Get the appropriate RTSP URI for streaming
  String get rtspUri {
    // Öncelikle sadece subUri'yi kullan (talep üzerine değiştirildi)
    if (subUri.isNotEmpty) {
      return _addCredentialsToUrl(subUri);
    } else if (mediaUri.isNotEmpty) {
      return _addCredentialsToUrl(mediaUri);
    } else if (remoteUri.isNotEmpty) {
      return _addCredentialsToUrl(remoteUri);
    } else if (recordUri.isNotEmpty) {
      return _addCredentialsToUrl(recordUri);
    }
    return ""; // Return empty string if no URI is available
  }
  
  // Add username and password to RTSP URL
  String _addCredentialsToUrl(String url) {
    if (url.isEmpty || !url.startsWith('rtsp://')) {
      return url;
    }
    
    // Eğer zaten kimlik bilgileri varsa, URL'i olduğu gibi döndür
    if (url.contains('@')) {
      return url;
    }
    
    // Kullanıcı adı veya şifre boşsa, URL'i olduğu gibi döndür
    if (username.isEmpty || password.isEmpty) {
      return url;
    }
    
    // rtsp:// kısmını çıkar
    final urlWithoutProtocol = url.substring(7);
    
    // Kullanıcı adı ve şifreyi URL'e ekle
    return 'rtsp://$username:$password@$urlWithoutProtocol';
  }
  
  // Added getter for compatibility
  bool get isConnected => connected;
  
  // Added getter for compatibility
  bool get isRecording => recording;
  
  // Get the camera status
  DeviceStatus get status {
    if (!connected) {
      return DeviceStatus.offline;
    }
    return DeviceStatus.online;
  }
  
  @override
  String toString() {
    return 'Camera{name: $name, ip: $ip, connected: $connected, recording: $recording}';
  }
}
