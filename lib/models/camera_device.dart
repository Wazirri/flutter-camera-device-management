import 'package:flutter/material.dart';
import 'dart:convert';

// CameraDevice Model for parsing camera devices from JSON
class CameraDevice {
  final String id;      // Unique identifier for the device (MAC address)
  final String type;    // Type of device (e.g., Onvif, RTSP)
  final String status;  // Connection status (e.g., Online, Offline)
  final List<Camera> cameras; // Cameras associated with this device
  final Map<String, dynamic> properties; // Raw device properties
  
  // Calculated fields
  final String name;    // User-friendly name derived from MAC
  final String macAddress; // MAC address
  
  CameraDevice({
    required this.id,
    required this.type,
    required this.status,
    required this.cameras,
    required this.properties,
    required this.name,
    required this.macAddress,
  });
  
  // Check if the device is currently connected
  bool get isConnected => status.toLowerCase() == 'online';
  
  // Check if device has any cameras
  bool get hasCameras => cameras.isNotEmpty;
  
  // Get a camera by its index
  Camera? getCamera(int index) {
    if (index >= 0 && index < cameras.length) {
      return cameras[index];
    }
    return null;
  }
  
  // Factory method to create CameraDevice from JSON
  static CameraDevice fromJson(Map<String, dynamic> json) {
    // Extract fields
    String deviceId = json['id'] ?? '';
    String deviceType = json['type'] ?? '';
    String deviceStatus = json['status'] ?? '';
    Map<String, dynamic> deviceProperties = json['properties'] ?? {};
    
    // Extract MAC address (usually in id field after ecs.slave.)
    String rawId = deviceId;
    String macAddress = '';
    String deviceName = '';
    
    if (rawId.contains('.')) {
      final parts = rawId.split('.');
      if (parts.length >= 3) {
        // For format like "ecs.slave.m_AA_BB_CC_DD_EE_FF"
        String lastPart = parts.last;
        if (lastPart.startsWith('m_')) {
          // Convert m_AA_BB_CC_DD_EE_FF to AA:BB:CC:DD:EE:FF
          macAddress = lastPart.substring(2).replaceAll('_', ':');
          deviceName = 'Device ${macAddress.split(':').last}'; // Use last part of MAC as name
        }
      }
    }
    
    // Create a list for all cameras associated with this device
    final List<Camera> deviceCameras = [];
    
    // Extract camera data from properties
    if (deviceProperties.containsKey('cameras') && deviceProperties['cameras'] is List) {
      final List<dynamic> camerasJson = deviceProperties['cameras'];
      
      for (int i = 0; i < camerasJson.length; i++) {
        if (camerasJson[i] is Map<String, dynamic>) {
          // Create Camera object and add to list
          final camera = Camera.fromJson(camerasJson[i], i, macAddress);
          deviceCameras.add(camera);
        }
      }
    }
    
    return CameraDevice(
      id: deviceId,
      type: deviceType,
      status: deviceStatus,
      cameras: deviceCameras,
      properties: deviceProperties,
      name: deviceName,
      macAddress: macAddress,
    );
  }
  
  // Create a string representation of the device
  @override
  String toString() {
    return 'CameraDevice { id: $id, type: $type, status: $status, cameras: ${cameras.length} }';
  }
}

// Camera Model representing an individual camera
class Camera {
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
    required this.subCodec,
    required this.subWidth,
    required this.subHeight,
    this.connected = false,
    this.disconnected = '',
    this.lastSeenAt = '',
    this.recording = false,
    this.soundRec = false,
    this.xAddr = '',
  });
  
  // Factory method to create a Camera from JSON
  factory Camera.fromJson(Map<String, dynamic> json, int index, String deviceMac) {
    // Helper function to safely get string value
    String getString(dynamic value) {
      return value != null ? value.toString() : '';
    }
    
    // Helper function to safely get int value
    int getInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      try {
        return int.parse(value.toString());
      } catch (e) {
        return 0;
      }
    }
    
    // Helper function to safely get bool value
    bool getBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      return false;
    }
    
    // Extract camera details from JSON
    return Camera(
      index: index,
      name: getString(json['name']),
      ip: getString(json['cameraIp']),
      rawIp: getInt(json['cameraRawIp']),
      username: getString(json['username']),
      password: getString(json['password']),
      brand: getString(json['brand']),
      hw: getString(json['hw']),
      manufacturer: getString(json['manufacturer']),
      country: getString(json['country']),
      xAddrs: getString(json['xAddrs']),
      mediaUri: getString(json['mediaUri']),
      recordUri: getString(json['recordUri']),
      subUri: getString(json['subUri']),
      remoteUri: getString(json['remoteUri']),
      mainSnapShot: getString(json['mainSnapShot']),
      subSnapShot: getString(json['subSnapShot']),
      recordPath: getString(json['recordPath']),
      recordCodec: getString(json['recordCodec']),
      recordWidth: getInt(json['recordWidth']),
      recordHeight: getInt(json['recordHeight']),
      subCodec: getString(json['subCodec']),
      subWidth: getInt(json['subWidth']),
      subHeight: getInt(json['subHeight']),
      connected: getBool(json['connected']),
      disconnected: getString(json['disconnected']),
      lastSeenAt: getString(json['lastSeenAt']),
      recording: getBool(json['recording']),
      soundRec: getBool(json['soundRec']),
      xAddr: getString(json['xAddr']),
    );
  }
  
  @override
  String toString() {
    return 'Camera{name: $name, connected: $connected, recording: $recording}';
  }
  
  // Get RTSP URI with credentials if available
  String get rtspUri {
    // Öncelikle sadece subUri'yi kullan (talep üzerine değiştirildi)
    if (subUri.isNotEmpty) {
      return _addCredentialsToUrl(subUri);
    } else if (mediaUri.isNotEmpty) {
      return _addCredentialsToUrl(mediaUri);
    } else if (remoteUri.isNotEmpty) {
      return _addCredentialsToUrl(remoteUri);
    }
    
    return ""; // Return empty string if no URI is available
  }
  
  // Get base URL for recordings HTTP access
  String get recordingsBaseUrl {
    return "http://${ip}:8080/Rec/${name}";
  }
  
  // Get URL for a specific recording day
  String getRecordingDayUrl(String formattedDate) {
    return "${recordingsBaseUrl}/${formattedDate}";
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
    
    // Add credentials to RTSP URL
    if (username.isNotEmpty && password.isNotEmpty) {
      final uri = Uri.parse(url);
      final userInfo = '$username:$password';
      final credentialsUri = Uri(
        scheme: uri.scheme,
        userInfo: userInfo,
        host: uri.host,
        port: uri.port,
        path: uri.path,
        query: uri.query,
      );
      return credentialsUri.toString();
    }
    
    return url;
  }
}
