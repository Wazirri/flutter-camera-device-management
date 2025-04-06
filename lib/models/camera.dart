import 'dart:convert';

/// Model class representing a camera with all its properties
class Camera {
  final String? id;
  final String? name;
  final String? mac;
  final String? cameraIp;
  final String? username;
  final String? password;
  final String? mediaUri;       // URI for main video stream
  final String? subUri;         // URI for secondary/sub video stream
  final String? recordUri;      // URI for recorded videos
  final String? remoteUri;      // URI for remote access
  final String? xAddrs;         // ONVIF device service address
  final bool? isConnected;
  final String? lastUpdate;
  final Map<String, dynamic>? additionalInfo;

  Camera({
    this.id,
    this.name,
    this.mac,
    this.cameraIp,
    this.username,
    this.password,
    this.mediaUri,
    this.subUri,
    this.recordUri,
    this.remoteUri,
    this.xAddrs,
    this.isConnected,
    this.lastUpdate,
    this.additionalInfo,
  });

  /// Create a Camera from a JSON map
  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'],
      name: json['name'],
      mac: json['mac'],
      cameraIp: json['cameraIp'],
      username: json['username'],
      password: json['password'],
      mediaUri: json['mediaUri'],
      subUri: json['subUri'],
      recordUri: json['recordUri'],
      remoteUri: json['remoteUri'],
      xAddrs: json['xAddrs'],
      isConnected: json['isConnected'] ?? false,
      lastUpdate: json['lastUpdate'],
      additionalInfo: json['additionalInfo'] != null
          ? json['additionalInfo'] is String
              ? jsonDecode(json['additionalInfo'])
              : json['additionalInfo']
          : null,
    );
  }

  /// Convert the Camera instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mac': mac,
      'cameraIp': cameraIp,
      'username': username,
      'password': password,
      'mediaUri': mediaUri,
      'subUri': subUri,
      'recordUri': recordUri,
      'remoteUri': remoteUri,
      'xAddrs': xAddrs,
      'isConnected': isConnected ?? false,
      'lastUpdate': lastUpdate,
      'additionalInfo': additionalInfo != null
          ? additionalInfo is String
              ? additionalInfo
              : jsonEncode(additionalInfo)
          : null,
    };
  }

  /// Create a copy of this Camera with the specified properties updated
  Camera copyWith({
    String? id,
    String? name,
    String? mac,
    String? cameraIp,
    String? username,
    String? password,
    String? mediaUri,
    String? subUri,
    String? recordUri,
    String? remoteUri,
    String? xAddrs,
    bool? isConnected,
    String? lastUpdate,
    Map<String, dynamic>? additionalInfo,
  }) {
    return Camera(
      id: id ?? this.id,
      name: name ?? this.name,
      mac: mac ?? this.mac,
      cameraIp: cameraIp ?? this.cameraIp,
      username: username ?? this.username,
      password: password ?? this.password,
      mediaUri: mediaUri ?? this.mediaUri,
      subUri: subUri ?? this.subUri,
      recordUri: recordUri ?? this.recordUri,
      remoteUri: remoteUri ?? this.remoteUri,
      xAddrs: xAddrs ?? this.xAddrs,
      isConnected: isConnected ?? this.isConnected,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }

  /// Generate a unique ID for this camera based on MAC address and IP
  String generateUniqueId() {
    if (mac != null && mac!.isNotEmpty) {
      return mac!;
    } else if (cameraIp != null && cameraIp!.isNotEmpty) {
      return cameraIp!;
    } else {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Get the preferred streaming URI based on user requirements
  /// According to user requirements, SubUri should be used for RTSP streaming
  String? get rtspUri {
    // Prioritize subUri as per requirements
    if (subUri != null && subUri!.isNotEmpty) {
      return subUri;
    } else if (mediaUri != null && mediaUri!.isNotEmpty) {
      return mediaUri;
    } else {
      return null;
    }
  }

  @override
  String toString() {
    return 'Camera{id: $id, name: $name, mac: $mac, cameraIp: $cameraIp}';
  }
}
