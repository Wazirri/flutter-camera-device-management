import 'dart:convert';

/// Represents a physical device which can have multiple cameras
class Device {
  final int id;
  final String macAddress;
  String name;
  String ip;
  bool connected;
  
  Device({
    required this.id,
    required this.macAddress,
    required this.name,
    required this.ip,
    required this.connected,
  });
  
  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int,
      macAddress: json['macAddress'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
      connected: json['connected'] as bool,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'macAddress': macAddress,
    'name': name,
    'ip': ip,
    'connected': connected,
  };
}

/// Represents a camera associated with a device
class Camera {
  final String id;        // Unique identifier for this camera
  final int index;        // Global index across all cameras
  final String macAddress; // MAC address of the parent device
  final int localIndex;   // Index within the parent device
  
  String name;
  String ip;
  bool connected;
  String rtspUri;
  String mediaUri;
  String mainSnapShot;
  String username;
  String password;
  
  Camera({
    required this.id,
    required this.index,
    required this.macAddress,
    required this.name,
    required this.localIndex,
    this.ip = '',
    this.connected = false,
    this.rtspUri = '',
    this.mediaUri = '',
    this.mainSnapShot = '',
    this.username = '',
    this.password = '',
  });
  
  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'] as String,
      index: json['index'] as int,
      macAddress: json['macAddress'] as String,
      name: json['name'] as String,
      localIndex: json['localIndex'] as int,
      ip: json['ip'] as String? ?? '',
      connected: json['connected'] as bool? ?? false,
      rtspUri: json['rtspUri'] as String? ?? '',
      mediaUri: json['mediaUri'] as String? ?? '',
      mainSnapShot: json['mainSnapShot'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'index': index,
    'macAddress': macAddress,
    'name': name,
    'localIndex': localIndex,
    'ip': ip,
    'connected': connected,
    'rtspUri': rtspUri,
    'mediaUri': mediaUri,
    'mainSnapShot': mainSnapShot,
    'username': username,
    'password': password,
  };
}