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
  final int index;         // Camera index (0, 1, 2, etc. for the same MAC address)
  String ipv4 = '';
  String xAddrs = '';
  String username = '';
  String password = '';
  String manufacturer = '';
  String brand = '';
  String country = '';
  String mediaUri = '';
  String recordUri = '';
  String subUri = '';
  String remoteUri = '';
  String mainSnapShot = '';
  String subSnapShot = '';
  String cameraRawIp = '';
  String recordPath = '';
  bool isConnected = false;
  
  CameraDevice({
    required this.macAddress,
    required this.macKey,
    required this.index,
    this.ipv4 = '',
    this.xAddrs = '',
    this.username = '',
    this.password = '',
    this.manufacturer = '',
    this.brand = '',
    this.country = '',
    this.mediaUri = '',
    this.recordUri = '',
    this.subUri = '',
    this.remoteUri = '',
    this.mainSnapShot = '',
    this.subSnapShot = '',
    this.cameraRawIp = '',
    this.recordPath = '',
    this.isConnected = false,
  });
  
  // Copy with method for immutable updates
  CameraDevice copyWith({
    String? ipv4,
    String? xAddrs,
    String? username,
    String? password,
    String? manufacturer,
    String? brand,
    String? country,
    String? mediaUri,
    String? recordUri,
    String? subUri,
    String? remoteUri,
    String? mainSnapShot,
    String? subSnapShot,
    String? cameraRawIp,
    String? recordPath,
    bool? isConnected,
  }) {
    return CameraDevice(
      macAddress: this.macAddress,
      macKey: this.macKey,
      index: this.index,
      ipv4: ipv4 ?? this.ipv4,
      xAddrs: xAddrs ?? this.xAddrs,
      username: username ?? this.username,
      password: password ?? this.password,
      manufacturer: manufacturer ?? this.manufacturer,
      brand: brand ?? this.brand,
      country: country ?? this.country,
      mediaUri: mediaUri ?? this.mediaUri,
      recordUri: recordUri ?? this.recordUri,
      subUri: subUri ?? this.subUri,
      remoteUri: remoteUri ?? this.remoteUri,
      mainSnapShot: mainSnapShot ?? this.mainSnapShot,
      subSnapShot: subSnapShot ?? this.subSnapShot,
      cameraRawIp: cameraRawIp ?? this.cameraRawIp,
      recordPath: recordPath ?? this.recordPath,
      isConnected: isConnected ?? this.isConnected,
    );
  }
  
  // Convert from JSON
  factory CameraDevice.fromJson(Map<String, dynamic> json) {
    return CameraDevice(
      macAddress: json['macAddress'],
      macKey: json['macKey'],
      index: json['index'] ?? 0,
      ipv4: json['ipv4'] ?? '',
      xAddrs: json['xAddrs'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      manufacturer: json['manufacturer'] ?? '',
      brand: json['brand'] ?? '',
      country: json['country'] ?? '',
      mediaUri: json['mediaUri'] ?? '',
      recordUri: json['recordUri'] ?? '',
      subUri: json['subUri'] ?? '',
      remoteUri: json['remoteUri'] ?? '',
      mainSnapShot: json['mainSnapShot'] ?? '',
      subSnapShot: json['subSnapShot'] ?? '',
      cameraRawIp: json['cameraRawIp'] ?? '',
      recordPath: json['recordPath'] ?? '',
      isConnected: json['isConnected'] ?? false,
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'macAddress': macAddress,
      'macKey': macKey,
      'index': index,
      'ipv4': ipv4,
      'xAddrs': xAddrs,
      'username': username,
      'password': password,
      'manufacturer': manufacturer,
      'brand': brand,
      'country': country,
      'mediaUri': mediaUri,
      'recordUri': recordUri,
      'subUri': subUri,
      'remoteUri': remoteUri,
      'mainSnapShot': mainSnapShot,
      'subSnapShot': subSnapShot,
      'cameraRawIp': cameraRawIp,
      'recordPath': recordPath,
      'isConnected': isConnected,
    };
  }
  
  // Get the device status
  DeviceStatus get status {
    if (!isConnected) {
      return DeviceStatus.offline;
    } else {
      return DeviceStatus.online;
    }
  }

  @override
  String toString() {
    return 'CameraDevice{macAddress: $macAddress, index: $index, ipv4: $ipv4, isConnected: $isConnected}';
  }
}
