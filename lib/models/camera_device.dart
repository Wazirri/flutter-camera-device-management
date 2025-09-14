
enum DeviceStatus {
  online,
  offline,
  degraded,
  warning,
  error,
  unknown,
}

class CameraDevice {
  final String macAddress; // Original field
  final String macKey; // Original field, used as a unique key
  String ipv4;
  String lastSeenAt;
  bool connected;
  bool online; // WebSocket field: online
  String firstTime; // WebSocket field: firsttime
  String uptime;
  String deviceType; // Example: 'NVR', 'IPC' - might need to parse from other data
  String firmwareVersion; // WebSocket field: version
  String recordPath; // Usually from camera specific data, but can be a device default

  // Newly added fields from WebSocket data
  String? deviceName; // WebSocket field: name
  String? currentTime; // WebSocket field: current_time
  String? smartwebVersion; // WebSocket field: smartweb_version
  double cpuTemp; // WebSocket field: cpuTemp
  String? ipv6; // WebSocket field: ipv6
  bool? isMaster; // WebSocket field: isMaster or is_master
  String? lastTs; // WebSocket field: last_ts
  int camCount; // WebSocket field: cam_count

  // Fields for system information
  int totalRam;
  int freeRam;
  String? networkInfo;
  int totalConnections;
  int totalSessions;

  List<Camera> cameras;

  CameraDevice({
    required this.macAddress,
    required this.macKey,
    required this.ipv4,
    required this.lastSeenAt,
    required this.connected,
    required this.online,
    required this.firstTime,
    required this.uptime,
    required this.deviceType,
    required this.firmwareVersion,
    required this.recordPath,
    this.deviceName,
    this.currentTime,
    this.smartwebVersion,
    this.cpuTemp = 0.0,
    this.ipv6,
    this.isMaster,
    this.lastTs,
    this.camCount = 0,
    this.totalRam = 0,
    this.freeRam = 0,
    this.networkInfo,
    this.totalConnections = 0,
    this.totalSessions = 0,
    List<Camera>? cameras,
  }) : cameras = cameras ?? [];

  // Copy with method for immutable updates
  CameraDevice copyWith({
    String? macAddress,
    String? macKey,
    String? ipv4,
    String? lastSeenAt,
    bool? connected,
    bool? online,
    String? firstTime,
    String? uptime,
    String? deviceType,
    String? firmwareVersion,
    String? recordPath,
    List<Camera>? cameras,
    String? deviceName,
    String? currentTime,
    String? smartwebVersion,
    double? cpuTemp,
    String? ipv6,
    bool? isMaster,
    String? lastTs,
    int? camCount,
    int? totalRam,
    int? freeRam,
    String? networkInfo,
    int? totalConnections,
    int? totalSessions,
  }) {
    return CameraDevice(
      macAddress: macAddress ?? this.macAddress,
      macKey: macKey ?? this.macKey,
      ipv4: ipv4 ?? this.ipv4,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      connected: connected ?? this.connected,
      online: online ?? this.online,
      firstTime: firstTime ?? this.firstTime,
      uptime: uptime ?? this.uptime,
      deviceType: deviceType ?? this.deviceType,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      recordPath: recordPath ?? this.recordPath,
      cameras: cameras ?? this.cameras,
      deviceName: deviceName ?? this.deviceName,
      currentTime: currentTime ?? this.currentTime,
      smartwebVersion: smartwebVersion ?? this.smartwebVersion,
      cpuTemp: cpuTemp ?? this.cpuTemp,
      ipv6: ipv6 ?? this.ipv6,
      isMaster: isMaster ?? this.isMaster,
      lastTs: lastTs ?? this.lastTs,
      camCount: camCount ?? this.camCount,
      totalRam: totalRam ?? this.totalRam,
      freeRam: freeRam ?? this.freeRam,
      networkInfo: networkInfo ?? this.networkInfo,
      totalConnections: totalConnections ?? this.totalConnections,
      totalSessions: totalSessions ?? this.totalSessions,
    );
  }

  // Convert from JSON
  factory CameraDevice.fromJson(Map<String, dynamic> json) {
    var camerasList = <Camera>[];
    if (json['cameras'] != null) {
      camerasList = List<Camera>.from(
          json['cameras'].map((camJson) => Camera.fromJson(camJson as Map<String, dynamic>)));
    }

    return CameraDevice(
      macAddress: json['macAddress'] as String,
      macKey: json['macKey'] as String,
      ipv4: json['ipv4'] as String? ?? '',
      lastSeenAt: json['last_seen_at'] as String? ?? '',
      connected: json['connected'] as bool? ?? false,
      online: json['online'] as bool? ?? false,
      firstTime: json['firstTime'] as String? ?? '',
      uptime: json['uptime'] as String? ?? '',
      deviceType: json['deviceType'] as String? ?? '',
      firmwareVersion: json['firmwareVersion'] as String? ?? '', // Corresponds to 'version' in WS
      recordPath: json['recordPath'] as String? ?? '',
      
      deviceName: json['name'] as String?, // WebSocket 'name'
      currentTime: json['current_time'] as String?,
      smartwebVersion: json['smartweb_version'] as String?,
      cpuTemp: (json['cpuTemp'] as num?)?.toDouble() ?? 0.0,
      ipv6: json['ipv6'] as String?,
      isMaster: json['isMaster'] as bool?,
      lastTs: json['last_ts'] as String?,
      camCount: json['cam_count'] as int? ?? 0,
      cameras: camerasList,
      totalRam: json['totalRam'] as int? ?? 0,
      freeRam: json['freeRam'] as int? ?? 0,
      networkInfo: json['networkInfo'] as String?,
      totalConnections: json['totalConnections'] as int? ?? 0,
      totalSessions: json['totalSessions'] as int? ?? 0,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() => {
        'macAddress': macAddress,
        'macKey': macKey,
        'ipv4': ipv4,
        'lastSeenAt': lastSeenAt,
        'connected': connected,
        'online': online,
        'firstTime': firstTime,
        'uptime': uptime,
        'deviceType': deviceType,
        'firmwareVersion': firmwareVersion, // Corresponds to 'version' in WS
        'recordPath': recordPath,
        
        'name': deviceName, // WebSocket 'name'
        'current_time': currentTime,
        'smartweb_version': smartwebVersion,
        'cpuTemp': cpuTemp,
        'ipv6': ipv6,
        'isMaster': isMaster,
        'last_ts': lastTs,
        'cam_count': camCount,
        'cameras': cameras.map((camera) => camera.toJson()).toList(),
        'totalRam': totalRam,
        'freeRam': freeRam,
        'networkInfo': networkInfo,
        'totalConnections': totalConnections,
        'totalSessions': totalSessions,
      };

  // Get the device status
  DeviceStatus get status {
    print('CameraDevice status getter invoked for $macAddress');
    // MODIFIED: Primary check for offline status is now solely based on 'connected'.
    // 'online' (powered state) is secondary; if not connected, it's offline to the system.
    print('DeviceStatus: Evaluating status for device $macAddress. Device connected property: $connected, Device online property: $online');
    if (!connected) { 
      print('DeviceStatus: Device $macAddress determined as OFFLINE because device.connected is $connected.');
      return DeviceStatus.offline;
    }
    
    // If there are no cameras, and the device itself is connected, consider it online.
    if (cameras.isEmpty) {
      print('DeviceStatus: Device $macAddress has no cameras. Reporting as ONLINE because device.connected is true and no cameras to check.');
      return DeviceStatus.online;
    }

    bool hasWarning = false;
    // bool hasError = false; // This was previously unused. If error conditions for a device (not just camera) exist, logic to set this should be added.

    for (final camera in cameras) {
      print('DeviceStatus: Checking camera ${camera.name} (index ${camera.index}) for device $macAddress. Camera connected property: ${camera.connected}');
      if (!camera.connected) {
        hasWarning = true;
        print('DeviceStatus: Camera ${camera.name} for device $macAddress is disconnected. Setting hasWarning to true.');
        break; // Optimization: if one camera causes a warning, no need to check further.
      }
    }
    
    // if (hasError) { // This block is currently unreachable as hasError is never true.
    //   print('DeviceStatus: Device $macAddress has error. Returning DeviceStatus.error.');
    //   return DeviceStatus.error;
    // } else 
    if (hasWarning) {
      print('DeviceStatus: Device $macAddress determined as WARNING because device.connected is true, but one or more cameras are disconnected.');
      return DeviceStatus.warning;
    } else {
      print('DeviceStatus: Device $macAddress determined as ONLINE because device.connected is true and all cameras are connected.');
      return DeviceStatus.online;
    }
  }
  
  // Force status update - can be called when connected status changes
  void updateStatus() {
    // This method exists solely to make it clear when the status should be recalculated
    // The status is calculated on-demand via the getter
    print('Status updated for device $macAddress: ${connected ? "Online" : "Offline"}');
  }

  // Helper method to format uptime in a human-readable format
  String get formattedUptime {
    // Try parsing as seconds (numeric format)
    final int? seconds = int.tryParse(uptime);
    if (seconds != null) {
      final int days = seconds ~/ 86400;
      final int hours = (seconds % 86400) ~/ 3600;
      final int minutes = (seconds % 3600) ~/ 60;
      final int remainingSeconds = seconds % 60;
      
      if (days > 0) {
        return '${days}d ${hours}h ${minutes}m';
      } else if (hours > 0) {
        return '${hours}h ${minutes}m ${remainingSeconds}s';
      } else if (minutes > 0) {
        return '${minutes}m ${remainingSeconds}s';
      } else {
        return '${remainingSeconds}s';
      }
    }
    
    // If it's already formatted or can't be parsed, return as is
    return uptime;
  }
  
  @override
  String toString() {
    return 'CameraDevice(macAddress: $macAddress, macKey: $macKey, ipv4: $ipv4, connected: $connected, online: $online, firstTime: $firstTime, uptime: $uptime, deviceName: $deviceName, firmwareVersion: $firmwareVersion, currentTime: $currentTime, smartwebVersion: $smartwebVersion, cpuTemp: $cpuTemp, ipv6: $ipv6, isMaster: $isMaster, lastTs: $lastTs, camCount: $camCount, totalRam: $totalRam, freeRam: $freeRam, networkInfo: $networkInfo, totalConnections: $totalConnections, totalSessions: $totalSessions, cameras: ${cameras.length})';
  }
}

class Camera {
  String health;              // camreports için sağlık bilgisi (changed from final)
  double temperature;         // camreports için sıcaklık bilgisi (changed from final)
  String reportError;         // camreports.reported hatası (error: 1000 gibi)
  String lastRestartTime;     // camreports.last_restart_time
  String reportName;          // camreports için rapor adı (KAMERA1 gibi)
  int index;                  // Index of the camera in the device\'s cameras array
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
  
  // Additional properties for group management
  String mac;                       // Camera MAC address for group assignment (changed from final)
  final List<String> groups;        // Groups this camera belongs to

  // New fields from cameras_mac data
  String? macFirstSeen;
  String? macLastDetected;
  int? macPort;
  String? macReportedError;
  String? macStatus;

  // Field to store the MAC key of the parent device this camera is associated with
  String? parentDeviceMacKey;

  // Flag to indicate if this is a placeholder camera (no physical device)
  bool isPlaceholder;


  Camera({
    required this.index,
    this.health = '',
    this.temperature = 0.0,
    this.reportError = '',
    this.lastRestartTime = '',
    this.reportName = '',
    this.name = '',
    this.ip = '',
    this.rawIp = 0,
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
    this.mainSnapShot = '',
    this.subSnapShot = '',
    this.recordPath = '',
    this.recordCodec = '',
    this.recordWidth = 0,
    this.recordHeight = 0,
    this.subCodec = '',
    this.subWidth = 0,
    this.subHeight = 0,
    this.connected = false,
    this.disconnected = '-',
    this.lastSeenAt = '',
    this.recording = false,
    this.soundRec = false,
    this.xAddr = '',
    this.mac = '',
    List<String>? groups,
    this.macFirstSeen,
    this.macLastDetected,
    this.macPort,
    this.macReportedError,
    this.macStatus,
    this.parentDeviceMacKey,
    this.isPlaceholder = false,
  }) : groups = groups ?? [];
  
  // Added id getter to uniquely identify cameras
  // Using a combination of name and index as id
  String get id => "${name}_$index";
  
  // Copy with method for immutable updates
  Camera copyWith({
    int? index, // Added index to copyWith
    String? name,
    String? health,
    double? temperature,
    String? reportError,
    String? lastRestartTime,
    String? reportName,
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
    bool? soundRec,
    String? xAddr,
    String? mac,
    List<String>? groups,
    String? macFirstSeen,
    String? macLastDetected,
    int? macPort,
    String? macReportedError,
    String? macStatus,
    String? parentDeviceMacKey, // Added parentDeviceMacKey to copyWith
    bool? isPlaceholder,
  }) {
    return Camera(
      index: index ?? this.index, // Updated index in copyWith
      health: health ?? this.health,
      temperature: temperature ?? this.temperature,
      reportError: reportError ?? this.reportError,
      lastRestartTime: lastRestartTime ?? this.lastRestartTime,
      reportName: reportName ?? this.reportName,
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
      soundRec: soundRec ?? this.soundRec,
      xAddr: xAddr ?? this.xAddr,
      mac: mac ?? this.mac,
      groups: groups ?? List<String>.from(this.groups),
      macFirstSeen: macFirstSeen ?? this.macFirstSeen,
      macLastDetected: macLastDetected ?? this.macLastDetected,
      macPort: macPort ?? this.macPort,
      macReportedError: macReportedError ?? this.macReportedError,
      macStatus: macStatus ?? this.macStatus,
      parentDeviceMacKey: parentDeviceMacKey ?? this.parentDeviceMacKey, // Updated parentDeviceMacKey
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
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
      mac: json['mac'] ?? '',
      groups: (json['groups'] as List<dynamic>?)?.cast<String>() ?? [],
      macFirstSeen: json['macFirstSeen'] as String?,
      macLastDetected: json['macLastDetected'] as String?,
      macPort: json['macPort'] as int?,
      macReportedError: json['macReportedError'] as String?,
      macStatus: json['macStatus'] as String?,
      parentDeviceMacKey: json['parentDeviceMacKey'] as String?,
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
      'mac': mac,
      'groups': groups,
      'macFirstSeen': macFirstSeen,
      'macLastDetected': macLastDetected,
      'macPort': macPort,
      'macReportedError': macReportedError,
      'macStatus': macStatus,
      'parentDeviceMacKey': parentDeviceMacKey,
    };
  }
  
  // Get the appropriate RTSP URI for streaming
  String get rtspUri {
    try {
      String result = "";
      print('RTSP_URI_LOG: Camera $name ($ip) - Evaluating RTSP URI. subUri: "$subUri", mediaUri: "$mediaUri", remoteUri: "$remoteUri", recordUri: "$recordUri"');

      // Prefer subUri when available
      if (subUri.isNotEmpty) {
        result = _addCredentialsToUrl(subUri);
        print('RTSP_URI_LOG: Camera $name - Using subUri. Initial: "$subUri", Result with creds: "${_sanitizeUrlForLogging(result)}"');
      } else if (mediaUri.isNotEmpty) {
        result = _addCredentialsToUrl(mediaUri);
        print('RTSP_URI_LOG: Camera $name - Using mediaUri. Initial: "$mediaUri", Result with creds: "${_sanitizeUrlForLogging(result)}"');
      } else if (remoteUri.isNotEmpty) {
        result = _addCredentialsToUrl(remoteUri);
        print('RTSP_URI_LOG: Camera $name - Using remoteUri. Initial: "$remoteUri", Result with creds: "${_sanitizeUrlForLogging(result)}"');
      } else if (recordUri.isNotEmpty) {
        result = _addCredentialsToUrl(recordUri);
        print('RTSP_URI_LOG: Camera $name - Using recordUri. Initial: "$recordUri", Result with creds: "${_sanitizeUrlForLogging(result)}"');
      } else {
        print('RTSP_URI_LOG: Camera $name - No suitable URI found (all URI fields are empty).');
      }
      
      // Final validation to prevent empty or malformed URLs
      if (result.isEmpty) {
        print('RTSP_URI_LOG: Camera $name - Final RTSP URI is empty.');
        return "";
      }
      
      print('RTSP_URI_LOG: Camera $name - Final RTSP URI to be used: "${_sanitizeUrlForLogging(result)}"');
      return result;
    } catch (e) {
      print('RTSP_URI_LOG: Camera $name - Error getting RTSP URI: $e');
      return ""; // Return empty string on error
    }
  }
  
  // Sanitize URL for logging by hiding credentials
  String _sanitizeUrlForLogging(String url) {
    if (url.isEmpty) return "";
    try {
      if (url.contains('@')) {
        // Hide credentials in URL pattern rtsp://user:pass@host:port/path
        final parts = url.split('@');
        if (parts.length >= 2) {
          // Create URL with hidden credentials
          return "rtsp://[CREDENTIALS_HIDDEN]@${parts.sublist(1).join('@')}";
        }
      }
      return url;
    } catch (e) {
      return "[URL_PROCESSING_ERROR]";
    }
  }
  
  // Add username and password to RTSP URL
  String _addCredentialsToUrl(String url) {
    print('RTSP_URI_LOG: Camera $name - _addCredentialsToUrl called with URL: "$url"');
    // If URL is empty, return empty string to avoid null issues
    if (url.isEmpty) {
      print('RTSP_URI_LOG: Camera $name - _addCredentialsToUrl: Empty URL provided.');
      return "";
    }
    
    // If URL doesn\\'t start with rtsp://, return as is but log a warning
    if (!url.startsWith('rtsp://')) {
      print('RTSP_URI_LOG: Camera $name - _addCredentialsToUrl: Non-RTSP URL provided: "$url"');
      return url;
    }
    
    try {
      // If credentials are already in the URL, return as is
      if (url.contains('@')) {
        print('RTSP_URI_LOG: Camera $name - _addCredentialsToUrl: URL already contains credentials: "${_sanitizeUrlForLogging(url)}"');
        return url;
      }
      
      // If username or password is empty, return URL as is
      if (username.isEmpty || password.isEmpty) {
        print('RTSP_URI_LOG: Camera $name - _addCredentialsToUrl: Missing credentials (username: "$username", password: "${password.isNotEmpty ? "******" : ""}"). Returning original URL: "$url"');
        return url;
      }
      
      // Encode username and password to handle special characters
      final encodedUsername = Uri.encodeComponent(username);
      final encodedPassword = Uri.encodeComponent(password);
      
      // Extract protocol and rest of the URL
      final urlWithoutProtocol = url.substring(7);
      
      // Create URL with encoded credentials
      final resultUrl = 'rtsp://$encodedUsername:$encodedPassword@$urlWithoutProtocol';
      print('RTSP_URI_LOG: Camera $name - _addCredentialsToUrl: Successfully added credentials. Result: "${_sanitizeUrlForLogging(resultUrl)}"');
      return resultUrl;
    } catch (e) {
      print('RTSP_URI_LOG: Camera $name - _addCredentialsToUrl: Error formatting RTSP URL: $e, Original URL: "$url"');
      // Return original URL on error to prevent null values
      return url.isNotEmpty ? url : "";
    }
  }
  
  // Added getter for compatibility
  bool get isConnected => connected;
  
  // Setter for connected status to handle various input types
  void setConnectedStatus(dynamic value) {
    if (value is bool) {
      connected = value;
    } else if (value is num) {
      connected = value == 1;
    } else if (value is String) {
      final lowerValue = value.toLowerCase();
      connected = lowerValue == '1' || lowerValue == 'true';
    } else {
      // Default to false if type is unknown or null
      connected = false;
    }
  }
  
  // Added getter for compatibility
  bool get isRecording => recording;
  
  // Set connected status with proper type conversion
  set isConnected(dynamic value) {
    if (value is bool) {
      connected = value;
    } else {
      final valueStr = value.toString();
      connected = valueStr == '1' || valueStr.toLowerCase() == 'true';
    }
  }
  
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
