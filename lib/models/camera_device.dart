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
  String ipv4 = '';
  String lastSeenAt = '';
  bool connected = false;
  String uptime = '';
  String deviceType = '';
  String firmwareVersion = '';
  String recordPath = '';
  List<Camera> cameras = [];
  
  CameraDevice({
    required this.macAddress,
    required this.macKey,
    this.ipv4 = '',
    this.lastSeenAt = '',
    this.connected = false,
    this.uptime = '',
    this.deviceType = '',
    this.firmwareVersion = '',
    this.recordPath = '',
    List<Camera>? cameras,
  }) : this.cameras = cameras ?? [];
  
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
  final int index;            // Index of the camera in the device's cameras array
  String name;                // User-friendly name (e.g., KAMERA1)
  String ip;                  // IP address of the camera (cameraIp)
  String rawIp;               // Raw IP address (cameraRawIp)
  String username;            // Username for authentication
  String password;            // Password for authentication
  String brand;               // Camera brand
  String hw;                  // Hardware identifier
  String manufacturer;        // Camera manufacturer
  String country;             // Camera country
  String xAddrs;              // ONVIF device service address
  String mediaUri;            // Main RTSP URI for live view
  String recordUri;           // RTSP URI for recordings
  String subUri;              // RTSP URI for sub stream
  String remoteUri;           // Remote URI
  int mainWidth;              // Main stream width
  int mainHeight;             // Main stream height
  int subWidth;               // Sub stream width
  int subHeight;              // Sub stream height
  bool connected;             // Is the camera connected
  bool disconnected;          // Is the camera disconnected
  String mainSnapShot;        // Main snapshot URL
  String subSnapShot;         // Sub snapshot URL
  String lastSeenAt;          // Last seen timestamp
  bool recording;             // Is recording active
  bool motionDetected;        // Motion detected
  
  // Constructor
  Camera({
    required this.index,
    this.name = '',
    this.ip = '',
    this.rawIp = '',
    this.username = '',
    this.password = '',
    this.brand = '',
    this.hw = '',
    this.manufacturer = '',
    this.country = '',
    this.xAddrs = '',
    this.mediaUri = '',
    this.recordUri = '',
    this.subUri = '',
    this.remoteUri = '',
    this.mainWidth = 0,
    this.mainHeight = 0,
    this.subWidth = 0,
    this.subHeight = 0,
    this.connected = false,
    this.disconnected = false,
    this.mainSnapShot = '',
    this.subSnapShot = '',
    this.lastSeenAt = '',
    this.recording = false,
    this.motionDetected = false,
  });
  
  // Copy with method for immutable updates
  Camera copyWith({
    int? index,
    String? name,
    String? ip,
    String? rawIp,
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
    int? mainWidth,
    int? mainHeight,
    int? subWidth,
    int? subHeight,
    bool? connected,
    bool? disconnected,
    String? mainSnapShot,
    String? subSnapShot,
    String? lastSeenAt,
    bool? recording,
    bool? motionDetected,
  }) {
    return Camera(
      index: index ?? this.index,
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
      mainWidth: mainWidth ?? this.mainWidth,
      mainHeight: mainHeight ?? this.mainHeight,
      subWidth: subWidth ?? this.subWidth,
      subHeight: subHeight ?? this.subHeight,
      connected: connected ?? this.connected,
      disconnected: disconnected ?? this.disconnected,
      mainSnapShot: mainSnapShot ?? this.mainSnapShot,
      subSnapShot: subSnapShot ?? this.subSnapShot,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      recording: recording ?? this.recording,
      motionDetected: motionDetected ?? this.motionDetected,
    );
  }
  
  // From JSON conversion
  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      index: json['index'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      ip: json['ip'] as String? ?? '',
      rawIp: json['rawIp'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      hw: json['hw'] as String? ?? '',
      manufacturer: json['manufacturer'] as String? ?? '',
      country: json['country'] as String? ?? '',
      xAddrs: json['xAddrs'] as String? ?? '',
      mediaUri: json['mediaUri'] as String? ?? '',
      recordUri: json['recordUri'] as String? ?? '',
      subUri: json['subUri'] as String? ?? '',
      remoteUri: json['remoteUri'] as String? ?? '',
      mainWidth: json['mainWidth'] as int? ?? 0,
      mainHeight: json['mainHeight'] as int? ?? 0,
      subWidth: json['subWidth'] as int? ?? 0,
      subHeight: json['subHeight'] as int? ?? 0,
      connected: json['connected'] as bool? ?? false,
      disconnected: json['disconnected'] as bool? ?? false,
      mainSnapShot: json['mainSnapShot'] as String? ?? '',
      subSnapShot: json['subSnapShot'] as String? ?? '',
      lastSeenAt: json['lastSeenAt'] as String? ?? '',
      recording: json['recording'] as bool? ?? false,
      motionDetected: json['motionDetected'] as bool? ?? false,
    );
  }
  
  // To JSON conversion
  Map<String, dynamic> toJson() {
    return {
      'index': index,
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
      'mainWidth': mainWidth,
      'mainHeight': mainHeight,
      'subWidth': subWidth,
      'subHeight': subHeight,
      'connected': connected,
      'disconnected': disconnected,
      'mainSnapShot': mainSnapShot,
      'subSnapShot': subSnapShot,
      'lastSeenAt': lastSeenAt,
      'recording': recording,
      'motionDetected': motionDetected,
    };
  }
  
  // Get status as enum
  DeviceStatus get status {
    if (disconnected || !connected) {
      return DeviceStatus.offline;
    }
    
    if (motionDetected) {
      return DeviceStatus.warning;
    }
    
    return DeviceStatus.online;
  }
  
  @override
  String toString() {
    return 'Camera{index: $index, name: $name, connected: $connected}';
  }
}
