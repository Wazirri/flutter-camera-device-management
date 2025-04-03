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
  final int index;        // Index of the camera in the device's cameras array
  String name;            // User-friendly name (e.g., KAMERA1)
  String ip;              // IP address of the camera
  String username;        // Username for authentication
  String password;        // Password for authentication
  String brand;           // Camera brand
  String model;           // Camera hardware model
  String mediaUri;        // Main RTSP URI for live view
  String recordUri;       // RTSP URI for recording stream
  String subUri;          // RTSP URI for sub-stream (lower resolution)
  String remoteUri;       // RTSP URI for remote viewing
  String mainSnapShot;    // URL for main snapshot
  String subSnapShot;     // URL for sub-stream snapshot
  int recordWidth;        // Width of recording resolution
  int recordHeight;       // Height of recording resolution
  int subWidth;           // Width of sub-stream resolution
  int subHeight;          // Height of sub-stream resolution
  bool connected;         // Whether the camera is connected
  String lastSeenAt;      // When the camera was last seen
  bool recording;         // Whether the camera is currently recording
  
  Camera({
    required this.index,
    required this.name,
    required this.ip,
    required this.username,
    required this.password,
    required this.brand,
    required this.model,
    required this.mediaUri,
    required this.recordUri,
    required this.subUri,
    required this.remoteUri,
    required this.mainSnapShot,
    required this.subSnapShot,
    required this.recordWidth,
    required this.recordHeight,
    required this.subWidth,
    required this.subHeight,
    required this.connected,
    required this.lastSeenAt,
    required this.recording,
  });
  
  // Copy with method for immutable updates
  Camera copyWith({
    String? name,
    String? ip,
    String? username,
    String? password,
    String? brand,
    String? model,
    String? mediaUri,
    String? recordUri,
    String? subUri,
    String? remoteUri,
    String? mainSnapShot,
    String? subSnapShot,
    int? recordWidth,
    int? recordHeight,
    int? subWidth,
    int? subHeight,
    bool? connected,
    String? lastSeenAt,
    bool? recording,
  }) {
    return Camera(
      index: this.index,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      username: username ?? this.username,
      password: password ?? this.password,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      mediaUri: mediaUri ?? this.mediaUri,
      recordUri: recordUri ?? this.recordUri,
      subUri: subUri ?? this.subUri,
      remoteUri: remoteUri ?? this.remoteUri,
      mainSnapShot: mainSnapShot ?? this.mainSnapShot,
      subSnapShot: subSnapShot ?? this.subSnapShot,
      recordWidth: recordWidth ?? this.recordWidth,
      recordHeight: recordHeight ?? this.recordHeight,
      subWidth: subWidth ?? this.subWidth,
      subHeight: subHeight ?? this.subHeight,
      connected: connected ?? this.connected,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      recording: recording ?? this.recording,
    );
  }
  
  // Convert from JSON
  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      index: json['index'] ?? 0,
      name: json['name'] ?? '',
      ip: json['ip'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      mediaUri: json['mediaUri'] ?? '',
      recordUri: json['recordUri'] ?? '',
      subUri: json['subUri'] ?? '',
      remoteUri: json['remoteUri'] ?? '',
      mainSnapShot: json['mainSnapShot'] ?? '',
      subSnapShot: json['subSnapShot'] ?? '',
      recordWidth: json['recordWidth'] ?? 0,
      recordHeight: json['recordHeight'] ?? 0,
      subWidth: json['subWidth'] ?? 0,
      subHeight: json['subHeight'] ?? 0,
      connected: json['connected'] ?? false,
      lastSeenAt: json['lastSeenAt'] ?? '',
      recording: json['recording'] ?? false,
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'name': name,
      'ip': ip,
      'username': username,
      'password': password,
      'brand': brand,
      'model': model,
      'mediaUri': mediaUri,
      'recordUri': recordUri,
      'subUri': subUri,
      'remoteUri': remoteUri,
      'mainSnapShot': mainSnapShot,
      'subSnapShot': subSnapShot,
      'recordWidth': recordWidth,
      'recordHeight': recordHeight,
      'subWidth': subWidth,
      'subHeight': subHeight,
      'connected': connected,
      'lastSeenAt': lastSeenAt,
      'recording': recording,
    };
  }
  
  // Get the appropriate RTSP URI for streaming
  String get rtspUri {
    // First try to use mediaUri, if empty try other URIs in order of preference
    if (mediaUri.isNotEmpty) {
      return mediaUri;
    } else if (subUri.isNotEmpty) {
      return subUri;
    } else if (remoteUri.isNotEmpty) {
      return remoteUri;
    } else if (recordUri.isNotEmpty) {
      return recordUri;
    }
    return ""; // Return empty string if no URI is available
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