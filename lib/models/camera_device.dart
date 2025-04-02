import 'package:flutter/foundation.dart';

class CameraDevice {
  final String macAddress;
  final String name;
  final String cameraIp;
  final String rtspUri;
  final String snapshotUri;
  final int width;
  final int height;
  final String codec;
  final String brand;
  final String model;
  final bool isConnected;
  final bool isRecording;
  final String lastSeenAt;
  
  CameraDevice({
    required this.macAddress,
    required this.name,
    required this.cameraIp,
    required this.rtspUri,
    required this.snapshotUri, 
    required this.width,
    required this.height,
    required this.codec,
    required this.brand,
    required this.model,
    required this.isConnected,
    required this.isRecording,
    required this.lastSeenAt,
  });
  
  factory CameraDevice.fromJson(Map<String, dynamic> json, String macAddress) {
    return CameraDevice(
      macAddress: macAddress,
      name: json['name'] ?? 'Unknown Camera',
      cameraIp: json['cameraIp'] ?? '',
      rtspUri: json['mediaUri'] ?? json['recordUri'] ?? '',
      snapshotUri: json['mainSnapShot'] ?? '',
      width: json['recordwidth'] ?? 0,
      height: json['recordheight'] ?? 0,
      codec: json['recordcodec'] ?? '',
      brand: json['brand'] ?? '',
      model: json['hw'] ?? '',
      isConnected: false, // Will be updated from camreports
      isRecording: false, // Will be updated from camreports
      lastSeenAt: '', // Will be updated from camreports
    );
  }
  
  CameraDevice copyWith({
    String? name,
    String? cameraIp,
    String? rtspUri,
    String? snapshotUri,
    int? width,
    int? height,
    String? codec,
    String? brand,
    String? model,
    bool? isConnected,
    bool? isRecording,
    String? lastSeenAt,
  }) {
    return CameraDevice(
      macAddress: this.macAddress,
      name: name ?? this.name,
      cameraIp: cameraIp ?? this.cameraIp,
      rtspUri: rtspUri ?? this.rtspUri,
      snapshotUri: snapshotUri ?? this.snapshotUri,
      width: width ?? this.width,
      height: height ?? this.height,
      codec: codec ?? this.codec,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      isConnected: isConnected ?? this.isConnected,
      isRecording: isRecording ?? this.isRecording,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return 'CameraDevice{macAddress: $macAddress, name: $name, isConnected: $isConnected, isRecording: $isRecording}';
  }
}

class DeviceInfo {
  final String macAddress;
  final String ipv4;
  final String ipv6;
  final String firstSeen;
  final String lastSeen;
  final String uptime;
  final bool isConnected;
  final bool hasError;
  final String firmwareVersion;
  final String deviceType;
  final List<CameraDevice> cameras;
  
  DeviceInfo({
    required this.macAddress,
    required this.ipv4,
    required this.ipv6,
    required this.firstSeen,
    required this.lastSeen,
    required this.uptime,
    required this.isConnected,
    required this.hasError,
    required this.firmwareVersion,
    required this.deviceType,
    required this.cameras,
  });
  
  factory DeviceInfo.initial(String macAddress) {
    return DeviceInfo(
      macAddress: macAddress,
      ipv4: '',
      ipv6: '',
      firstSeen: '',
      lastSeen: '',
      uptime: '',
      isConnected: false,
      hasError: false,
      firmwareVersion: '',
      deviceType: '',
      cameras: [],
    );
  }
  
  DeviceInfo copyWith({
    String? ipv4,
    String? ipv6,
    String? firstSeen,
    String? lastSeen,
    String? uptime,
    bool? isConnected,
    bool? hasError,
    String? firmwareVersion,
    String? deviceType,
    List<CameraDevice>? cameras,
  }) {
    return DeviceInfo(
      macAddress: this.macAddress,
      ipv4: ipv4 ?? this.ipv4,
      ipv6: ipv6 ?? this.ipv6,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      uptime: uptime ?? this.uptime,
      isConnected: isConnected ?? this.isConnected,
      hasError: hasError ?? this.hasError,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      deviceType: deviceType ?? this.deviceType,
      cameras: cameras ?? this.cameras,
    );
  }
  
  @override
  String toString() {
    return 'DeviceInfo{macAddress: $macAddress, ipv4: $ipv4, isConnected: $isConnected, cameras: ${cameras.length}}';
  }
}