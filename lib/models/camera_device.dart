
enum DeviceStatus {
  online,
  offline,
  degraded,
  warning,
  error,
  unknown,
}

// Current device assignment for camera from cameras_mac.json
class CameraCurrentDevice {
  final String deviceMac;      // Device MAC address camera is currently assigned to
  final String deviceIp;      // Device IP address
  final String cameraIp;      // Camera IP address
  final String name;          // Camera name in current assignment
  final int startDate;        // Timestamp when assigned to this device

  CameraCurrentDevice({
    required this.deviceMac,
    required this.deviceIp,
    required this.cameraIp,
    required this.name,
    required this.startDate,
  });

  // Copy with method for immutable updates
  CameraCurrentDevice copyWith({
    String? deviceMac,
    String? deviceIp,
    String? cameraIp,
    String? name,
    int? startDate,
  }) {
    return CameraCurrentDevice(
      deviceMac: deviceMac ?? this.deviceMac,
      deviceIp: deviceIp ?? this.deviceIp,
      cameraIp: cameraIp ?? this.cameraIp,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
    );
  }

  factory CameraCurrentDevice.fromJson(Map<String, dynamic> json) {
    return CameraCurrentDevice(
      deviceMac: json['device_mac'] ?? '',
      deviceIp: json['device_ip'] ?? '',
      cameraIp: json['cameraIp'] ?? '',
      name: json['name'] ?? '',
      startDate: json['start_date'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_mac': deviceMac,
      'device_ip': deviceIp,
      'cameraIp': cameraIp,
      'name': name,
      'start_date': startDate,
    };
  }

  @override
  String toString() {
    return 'CameraCurrentDevice(deviceMac: $deviceMac, deviceIp: $deviceIp, cameraIp: $cameraIp, name: $name, startDate: $startDate)';
  }
}

// Historical device assignment for camera from cameras_mac.json
class CameraHistoryDevice {
  final String deviceMac;      // Device MAC address camera was previously assigned to
  final String deviceIp;      // Device IP address
  final String cameraIp;      // Camera IP address  
  final String name;          // Camera name in this historical assignment
  final int startDate;        // Timestamp when assigned to this device
  final int endDate;          // Timestamp when assignment ended

  CameraHistoryDevice({
    required this.deviceMac,
    required this.deviceIp,
    required this.cameraIp,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  // Copy with method for immutable updates
  CameraHistoryDevice copyWith({
    String? deviceMac,
    String? deviceIp,
    String? cameraIp,
    String? name,
    int? startDate,
    int? endDate,
  }) {
    return CameraHistoryDevice(
      deviceMac: deviceMac ?? this.deviceMac,
      deviceIp: deviceIp ?? this.deviceIp,
      cameraIp: cameraIp ?? this.cameraIp,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  factory CameraHistoryDevice.fromJson(Map<String, dynamic> json) {
    return CameraHistoryDevice(
      deviceMac: json['device_mac'] ?? '',
      deviceIp: json['device_ip'] ?? '',
      cameraIp: json['cameraIp'] ?? '',
      name: json['name'] ?? '',
      startDate: json['start_date'] ?? 0,
      endDate: json['end_date'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_mac': deviceMac,
      'device_ip': deviceIp,
      'cameraIp': cameraIp,
      'name': name,
      'start_date': startDate,
      'end_date': endDate,
    };
  }

  @override
  String toString() {
    return 'CameraHistoryDevice(deviceMac: $deviceMac, deviceIp: $deviceIp, cameraIp: $cameraIp, name: $name, startDate: $startDate, endDate: $endDate)';
  }
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

  // Ready states
  bool appReady;
  bool systemReady;
  bool programsReady;
  bool camReady;
  bool configurationReady;
  bool camreportsReady;
  bool movitaReady;

  // Device status fields
  bool registered;
  int appVersion;
  int systemCount;
  int camreportsCount;
  int programsCount;
  bool isClosedByMaster;
  
  // Heartbeat and connection
  int lastHeartbeatTs;
  int offlineSince;

  // System information
  String? systemMac;
  String? gateway;
  bool gpsOk;
  bool ignition;
  bool internetExists;
  String? systemIp;
  int bootCount;
  String? diskFree;
  String? diskRunning;
  int emptySize;
  int recordSize;
  int recording;
  bool shmcReady;
  bool timeset;
  bool uykumodu; // sleep mode
  
  // App configuration
  String? appDeviceType;
  String? firmwareDate;
  String? appFirmwareVersion;
  bool gpsDataFlowStatus;
  int group;
  bool intConnection;
  String? isai;
  String? libPath;
  String? logPath;
  String? macAddressPath;
  int maxRecordDuration;
  int minSpaceInMBytes;
  String? movitabinPath;
  String? movitarecPath;
  String? netdev;
  String? pinCode;
  bool ppp;
  bool recordOverTcp;
  String? appRecordPath;
  bool appRecording;
  int recordingCameras;
  int restartPlayerTimeout;
  String? rp2040version;
  
  // Test information
  String? testUptime;
  int testConnectionCount;
  String? testConnectionLastUpdate;
  int testConnectionError;
  bool testIsError;
  int testKameraBaglantiCount;
  String? testKameraBaglantiLastUpdate;
  int testKameraBaglantiError;
  int testProgramCount;
  String? testProgramLastUpdate;
  int testProgramError;

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
    
    // Ready states with defaults
    this.appReady = false,
    this.systemReady = false,
    this.programsReady = false,
    this.camReady = false,
    this.configurationReady = false,
    this.camreportsReady = false,
    this.movitaReady = false,
    
    // Device status fields with defaults
    this.registered = false,
    this.appVersion = 0,
    this.systemCount = 0,
    this.camreportsCount = 0,
    this.programsCount = 0,
    this.isClosedByMaster = false,
    
    // Heartbeat and connection with defaults
    this.lastHeartbeatTs = 0,
    this.offlineSince = 0,
    
    // System information with defaults
    this.systemMac,
    this.gateway,
    this.gpsOk = false,
    this.ignition = false,
    this.internetExists = false,
    this.systemIp,
    this.bootCount = 0,
    this.diskFree,
    this.diskRunning,
    this.emptySize = 0,
    this.recordSize = 0,
    this.recording = 0,
    this.shmcReady = false,
    this.timeset = false,
    this.uykumodu = false,
    
    // App configuration with defaults
    this.appDeviceType,
    this.firmwareDate,
    this.appFirmwareVersion,
    this.gpsDataFlowStatus = false,
    this.group = 0,
    this.intConnection = false,
    this.isai,
    this.libPath,
    this.logPath,
    this.macAddressPath,
    this.maxRecordDuration = 0,
    this.minSpaceInMBytes = 0,
    this.movitabinPath,
    this.movitarecPath,
    this.netdev,
    this.pinCode,
    this.ppp = false,
    this.recordOverTcp = false,
    this.appRecordPath,
    this.appRecording = false,
    this.recordingCameras = 0,
    this.restartPlayerTimeout = 0,
    this.rp2040version,
    
    // Test information with defaults
    this.testUptime,
    this.testConnectionCount = 0,
    this.testConnectionLastUpdate,
    this.testConnectionError = 0,
    this.testIsError = false,
    this.testKameraBaglantiCount = 0,
    this.testKameraBaglantiLastUpdate,
    this.testKameraBaglantiError = 0,
    this.testProgramCount = 0,
    this.testProgramLastUpdate,
    this.testProgramError = 0,
    
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
    
    // Ready states
    bool? appReady,
    bool? systemReady,
    bool? programsReady,
    bool? camReady,
    bool? configurationReady,
    bool? camreportsReady,
    bool? movitaReady,
    
    // Device status fields
    bool? registered,
    int? appVersion,
    int? systemCount,
    int? camreportsCount,
    int? programsCount,
    bool? isClosedByMaster,
    
    // Heartbeat and connection
    int? lastHeartbeatTs,
    int? offlineSince,
    
    // System information
    String? systemMac,
    String? gateway,
    bool? gpsOk,
    bool? ignition,
    bool? internetExists,
    String? systemIp,
    int? bootCount,
    String? diskFree,
    String? diskRunning,
    int? emptySize,
    int? recordSize,
    int? recording,
    bool? shmcReady,
    bool? timeset,
    bool? uykumodu,
    
    // App configuration
    String? appDeviceType,
    String? firmwareDate,
    String? appFirmwareVersion,
    bool? gpsDataFlowStatus,
    int? group,
    bool? intConnection,
    String? isai,
    String? libPath,
    String? logPath,
    String? macAddressPath,
    int? maxRecordDuration,
    int? minSpaceInMBytes,
    String? movitabinPath,
    String? movitarecPath,
    String? netdev,
    String? pinCode,
    bool? ppp,
    bool? recordOverTcp,
    String? appRecordPath,
    bool? appRecording,
    int? recordingCameras,
    int? restartPlayerTimeout,
    String? rp2040version,
    
    // Test information
    String? testUptime,
    int? testConnectionCount,
    String? testConnectionLastUpdate,
    int? testConnectionError,
    bool? testIsError,
    int? testKameraBaglantiCount,
    String? testKameraBaglantiLastUpdate,
    int? testKameraBaglantiError,
    int? testProgramCount,
    String? testProgramLastUpdate,
    int? testProgramError,
    
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
      
      // Ready states
      appReady: appReady ?? this.appReady,
      systemReady: systemReady ?? this.systemReady,
      programsReady: programsReady ?? this.programsReady,
      camReady: camReady ?? this.camReady,
      configurationReady: configurationReady ?? this.configurationReady,
      camreportsReady: camreportsReady ?? this.camreportsReady,
      movitaReady: movitaReady ?? this.movitaReady,
      
      // Device status fields
      registered: registered ?? this.registered,
      appVersion: appVersion ?? this.appVersion,
      systemCount: systemCount ?? this.systemCount,
      camreportsCount: camreportsCount ?? this.camreportsCount,
      programsCount: programsCount ?? this.programsCount,
      isClosedByMaster: isClosedByMaster ?? this.isClosedByMaster,
      
      // Heartbeat and connection
      lastHeartbeatTs: lastHeartbeatTs ?? this.lastHeartbeatTs,
      offlineSince: offlineSince ?? this.offlineSince,
      
      // System information
      systemMac: systemMac ?? this.systemMac,
      gateway: gateway ?? this.gateway,
      gpsOk: gpsOk ?? this.gpsOk,
      ignition: ignition ?? this.ignition,
      internetExists: internetExists ?? this.internetExists,
      systemIp: systemIp ?? this.systemIp,
      bootCount: bootCount ?? this.bootCount,
      diskFree: diskFree ?? this.diskFree,
      diskRunning: diskRunning ?? this.diskRunning,
      emptySize: emptySize ?? this.emptySize,
      recordSize: recordSize ?? this.recordSize,
      recording: recording ?? this.recording,
      shmcReady: shmcReady ?? this.shmcReady,
      timeset: timeset ?? this.timeset,
      uykumodu: uykumodu ?? this.uykumodu,
      
      // App configuration
      appDeviceType: appDeviceType ?? this.appDeviceType,
      firmwareDate: firmwareDate ?? this.firmwareDate,
      appFirmwareVersion: appFirmwareVersion ?? this.appFirmwareVersion,
      gpsDataFlowStatus: gpsDataFlowStatus ?? this.gpsDataFlowStatus,
      group: group ?? this.group,
      intConnection: intConnection ?? this.intConnection,
      isai: isai ?? this.isai,
      libPath: libPath ?? this.libPath,
      logPath: logPath ?? this.logPath,
      macAddressPath: macAddressPath ?? this.macAddressPath,
      maxRecordDuration: maxRecordDuration ?? this.maxRecordDuration,
      minSpaceInMBytes: minSpaceInMBytes ?? this.minSpaceInMBytes,
      movitabinPath: movitabinPath ?? this.movitabinPath,
      movitarecPath: movitarecPath ?? this.movitarecPath,
      netdev: netdev ?? this.netdev,
      pinCode: pinCode ?? this.pinCode,
      ppp: ppp ?? this.ppp,
      recordOverTcp: recordOverTcp ?? this.recordOverTcp,
      appRecordPath: appRecordPath ?? this.appRecordPath,
      appRecording: appRecording ?? this.appRecording,
      recordingCameras: recordingCameras ?? this.recordingCameras,
      restartPlayerTimeout: restartPlayerTimeout ?? this.restartPlayerTimeout,
      rp2040version: rp2040version ?? this.rp2040version,
      
      // Test information
      testUptime: testUptime ?? this.testUptime,
      testConnectionCount: testConnectionCount ?? this.testConnectionCount,
      testConnectionLastUpdate: testConnectionLastUpdate ?? this.testConnectionLastUpdate,
      testConnectionError: testConnectionError ?? this.testConnectionError,
      testIsError: testIsError ?? this.testIsError,
      testKameraBaglantiCount: testKameraBaglantiCount ?? this.testKameraBaglantiCount,
      testKameraBaglantiLastUpdate: testKameraBaglantiLastUpdate ?? this.testKameraBaglantiLastUpdate,
      testKameraBaglantiError: testKameraBaglantiError ?? this.testKameraBaglantiError,
      testProgramCount: testProgramCount ?? this.testProgramCount,
      testProgramLastUpdate: testProgramLastUpdate ?? this.testProgramLastUpdate,
      testProgramError: testProgramError ?? this.testProgramError,
      
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
      firstTime: json['firstTime'] as String? ?? json['firsttime'] as String? ?? '',
      uptime: json['uptime'] as String? ?? '',
      deviceType: json['deviceType'] as String? ?? '',
      firmwareVersion: json['firmwareVersion'] as String? ?? json['version']?.toString() ?? '',
      recordPath: json['recordPath'] as String? ?? '',
      
      // Basic device info from WebSocket
      deviceName: json['name'] as String?,
      currentTime: json['current_time'] as String?,
      smartwebVersion: json['smartweb_version'] as String?,
      cpuTemp: (json['cpuTemp'] is String) 
          ? double.tryParse(json['cpuTemp'] as String) ?? 0.0
          : (json['cpuTemp'] as num?)?.toDouble() ?? 0.0,
      ipv6: json['ipv6'] as String?,
      isMaster: json['isMaster'] as bool?,
      lastTs: json['last_ts']?.toString(),
      camCount: json['cam_count'] as int? ?? 0,
      
      // Ready states from WebSocket
      appReady: json['app_ready'] as bool? ?? false,
      systemReady: json['system_ready'] as bool? ?? false,
      programsReady: json['programs_ready'] as bool? ?? false,
      camReady: json['cam_ready'] as bool? ?? false,
      configurationReady: json['configuration_ready'] as bool? ?? false,
      camreportsReady: json['camreports_ready'] as bool? ?? false,
      movitaReady: json['movita_ready'] as bool? ?? false,
      
      // Device status fields from WebSocket
      registered: json['registered'] as bool? ?? false,
      appVersion: json['app_version'] as int? ?? json['version'] as int? ?? 0,
      systemCount: json['system_count'] as int? ?? 0,
      camreportsCount: json['camreports_count'] as int? ?? 0,
      programsCount: json['programs_count'] as int? ?? 0,
      isClosedByMaster: json['is_closed_by_master'] as bool? ?? false,
      
      // Heartbeat and connection from WebSocket
      lastHeartbeatTs: json['last_heartbeat_ts'] as int? ?? 0,
      offlineSince: json['offline_since'] as int? ?? 0,
      
      // System information from WebSocket system.* fields
      systemMac: json['system']?['mac'] as String?,
      gateway: json['system']?['gateway'] as String?,
      gpsOk: json['system']?['gpsOk'] as bool? ?? false,
      ignition: json['system']?['ignition'] as bool? ?? false,
      internetExists: json['system']?['internetExists'] as bool? ?? false,
      systemIp: json['system']?['ip'] as String?,
      bootCount: json['system']?['bootcount'] as int? ?? 0,
      diskFree: json['system']?['diskfree'] as String?,
      diskRunning: json['system']?['diskrunning'] as String?,
      emptySize: json['system']?['emptySize'] as int? ?? 0,
      recordSize: json['system']?['recordSize'] as int? ?? 0,
      recording: json['system']?['recording'] as int? ?? 0,
      shmcReady: json['system']?['shmc_ready'] as bool? ?? false,
      timeset: json['system']?['timeset'] as bool? ?? false,
      uykumodu: json['system']?['uykumodu'] as bool? ?? false,
      
      // App configuration from WebSocket app.* fields
      appDeviceType: json['app']?['deviceType'] as String?,
      firmwareDate: json['app']?['firmwareDate'] as String?,
      appFirmwareVersion: json['app']?['firmwareVersion'] as String?,
      gpsDataFlowStatus: json['app']?['gpsDataFlowStatus'] as bool? ?? false,
      group: json['app']?['group'] as int? ?? 0,
      intConnection: json['app']?['intConnection'] as bool? ?? false,
      isai: json['app']?['isai'] as String? ?? json['app']?['useai'] as String?,
      libPath: json['app']?['libPath'] as String?,
      logPath: json['app']?['logPath'] as String?,
      macAddressPath: json['app']?['macAddressPath'] as String?,
      maxRecordDuration: json['app']?['maxRecordDuration'] as int? ?? 0,
      minSpaceInMBytes: json['app']?['minSpaceInMBytes'] as int? ?? 0,
      movitabinPath: json['app']?['movitabinPath'] as String?,
      movitarecPath: json['app']?['movitarecPath'] as String?,
      netdev: json['app']?['netdev'] as String?,
      pinCode: json['app']?['pinCode'] as String?,
      ppp: json['app']?['ppp'] as bool? ?? false,
      recordOverTcp: json['app']?['recordOverTcp'] as bool? ?? false,
      appRecordPath: json['app']?['recordPath'] as String?,
      appRecording: json['app']?['recording'] as bool? ?? false,
      recordingCameras: json['app']?['recordingCameras'] as int? ?? 0,
      restartPlayerTimeout: json['app']?['restartPlayerTimeout'] as int? ?? 0,
      rp2040version: json['app']?['rp2040version'] as String?,
      
      // Test information from WebSocket test.* fields
      testUptime: json['test']?['uptime'] as String?,
      testConnectionCount: json['test']?['connection']?['count'] as int? ?? 0,
      testConnectionLastUpdate: json['test']?['connection']?['last_update'] as String?,
      testConnectionError: json['test']?['connection']?['error'] as int? ?? 0,
      testIsError: json['test']?['is_error'] as bool? ?? false,
      testKameraBaglantiCount: json['test']?['kamera_baglanti']?['count'] as int? ?? 0,
      testKameraBaglantiLastUpdate: json['test']?['kamera_baglanti']?['last_update'] as String?,
      testKameraBaglantiError: json['test']?['kamera_baglanti']?['error'] as int? ?? 0,
      testProgramCount: json['test']?['program']?['count'] as int? ?? 0,
      testProgramLastUpdate: json['test']?['program']?['last_update'] as String?,
      testProgramError: json['test']?['program']?['error'] as int? ?? 0,
      
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
        'firmwareVersion': firmwareVersion,
        'recordPath': recordPath,
        
        // Basic device info
        'name': deviceName,
        'current_time': currentTime,
        'smartweb_version': smartwebVersion,
        'cpuTemp': cpuTemp,
        'ipv6': ipv6,
        'isMaster': isMaster,
        'last_ts': lastTs,
        'cam_count': camCount,
        
        // Ready states
        'app_ready': appReady,
        'system_ready': systemReady,
        'programs_ready': programsReady,
        'cam_ready': camReady,
        'configuration_ready': configurationReady,
        'camreports_ready': camreportsReady,
        'movita_ready': movitaReady,
        
        // Device status fields
        'registered': registered,
        'app_version': appVersion,
        'system_count': systemCount,
        'camreports_count': camreportsCount,
        'programs_count': programsCount,
        'is_closed_by_master': isClosedByMaster,
        
        // Heartbeat and connection
        'last_heartbeat_ts': lastHeartbeatTs,
        'offline_since': offlineSince,
        
        // System information
        'system': {
          'mac': systemMac,
          'gateway': gateway,
          'gpsOk': gpsOk,
          'ignition': ignition,
          'internetExists': internetExists,
          'ip': systemIp,
          'bootcount': bootCount,
          'diskfree': diskFree,
          'diskrunning': diskRunning,
          'emptySize': emptySize,
          'recordSize': recordSize,
          'recording': recording,
          'shmc_ready': shmcReady,
          'timeset': timeset,
          'uykumodu': uykumodu,
        },
        
        // App configuration
        'app': {
          'deviceType': appDeviceType,
          'firmwareDate': firmwareDate,
          'firmwareVersion': appFirmwareVersion,
          'gpsDataFlowStatus': gpsDataFlowStatus,
          'group': group,
          'intConnection': intConnection,
          'isai': isai,
          'libPath': libPath,
          'logPath': logPath,
          'macAddressPath': macAddressPath,
          'maxRecordDuration': maxRecordDuration,
          'minSpaceInMBytes': minSpaceInMBytes,
          'movitabinPath': movitabinPath,
          'movitarecPath': movitarecPath,
          'netdev': netdev,
          'pinCode': pinCode,
          'ppp': ppp,
          'recordOverTcp': recordOverTcp,
          'recordPath': appRecordPath,
          'recording': appRecording,
          'recordingCameras': recordingCameras,
          'restartPlayerTimeout': restartPlayerTimeout,
          'rp2040version': rp2040version,
        },
        
        // Test information
        'test': {
          'uptime': testUptime,
          'connection': {
            'count': testConnectionCount,
            'last_update': testConnectionLastUpdate,
            'error': testConnectionError,
          },
          'is_error': testIsError,
          'kamera_baglanti': {
            'count': testKameraBaglantiCount,
            'last_update': testKameraBaglantiLastUpdate,
            'error': testKameraBaglantiError,
          },
          'program': {
            'count': testProgramCount,
            'last_update': testProgramLastUpdate,
            'error': testProgramError,
          },
        },
        
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
  
  // Recording per device - key: deviceMac, value: isRecording
  // A camera can record on multiple devices simultaneously
  final Map<String, bool> recordingDevices;
  
  // Computed property - true if recording on any device
  bool get recording => recordingDevices.values.any((r) => r);
  
  // How many devices are recording this camera
  int get recordingCount => recordingDevices.values.where((r) => r).length;
  
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

  // Sharing active flag - indicates if the camera is being shared
  bool sharingActive;

  // Current device assignments from cameras_mac.json - Map<DeviceMac, CameraCurrentDevice>
  // A camera can be on multiple devices at the same time
  Map<String, CameraCurrentDevice> currentDevices;
  
  // Legacy getter for backward compatibility - returns first current device or null
  CameraCurrentDevice? get currentDevice => currentDevices.isNotEmpty ? currentDevices.values.first : null;
  
  // Legacy setter for backward compatibility
  set currentDevice(CameraCurrentDevice? value) {
    if (value != null && value.deviceMac.isNotEmpty) {
      currentDevices[value.deviceMac] = value;
    }
  }

  // History of device assignments from cameras_mac.json  
  List<CameraHistoryDevice> deviceHistory;


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
    Map<String, bool>? recordingDevices,
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
    this.sharingActive = false,
    CameraCurrentDevice? currentDevice,
    Map<String, CameraCurrentDevice>? currentDevices,
    List<CameraHistoryDevice>? deviceHistory,
  }) : groups = groups ?? [], 
       deviceHistory = deviceHistory ?? [],
       recordingDevices = recordingDevices ?? {},
       currentDevices = currentDevices ?? (currentDevice != null && currentDevice.deviceMac.isNotEmpty 
           ? {currentDevice.deviceMac: currentDevice} 
           : {});
  
  // Added id getter to uniquely identify cameras
  // Using MAC address as primary ID, fallback to name_index for cameras without MAC
  String get id => mac.isNotEmpty ? mac : "${parentDeviceMacKey}_${name}_$index";
  
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
    Map<String, bool>? recordingDevices,
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
    bool? sharingActive,
    Map<String, CameraCurrentDevice>? currentDevices,
    List<CameraHistoryDevice>? deviceHistory,
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
      recordingDevices: recordingDevices ?? Map<String, bool>.from(this.recordingDevices),
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
      sharingActive: sharingActive ?? this.sharingActive,
      currentDevices: currentDevices ?? Map<String, CameraCurrentDevice>.from(this.currentDevices),
      deviceHistory: deviceHistory ?? List<CameraHistoryDevice>.from(this.deviceHistory),
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
      recordingDevices: (json['recordingDevices'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, value as bool),
      ) ?? {},
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
      currentDevices: (json['currentDevices'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, CameraCurrentDevice.fromJson(value as Map<String, dynamic>)),
      ) ?? (json['currentDevice'] != null 
          ? {(json['currentDevice']['device_mac'] ?? ''): CameraCurrentDevice.fromJson(json['currentDevice'] as Map<String, dynamic>)}
          : {}),
      deviceHistory: (json['deviceHistory'] as List<dynamic>?)
          ?.map((e) => CameraHistoryDevice.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
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
      'recordingDevices': recordingDevices,
      'recordingCount': recordingCount,
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
      'currentDevices': currentDevices.map((key, value) => MapEntry(key, value.toJson())),
      'deviceHistory': deviceHistory.map((e) => e.toJson()).toList(),
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
  
  // Override equality based on MAC address for proper Map/Set usage
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Camera) return false;
    // Use MAC address as unique identifier
    return mac == other.mac;
  }

  @override
  int get hashCode => mac.hashCode;
  
  @override
  String toString() {
    return 'Camera{name: $name, ip: $ip, connected: $connected, recording: $recording}';
  }
}
