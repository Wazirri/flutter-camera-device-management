import 'device_status.dart';

// Top-level model representing a physical device that may have multiple cameras
class CameraDevice {
  final String id;      // Unique identifier for the device (MAC address)
  final String type;    // Type of device (e.g., DVR, NVR, IPC)
  DeviceStatus status;  // Current status of the device
  final List<Camera> cameras;  // List of cameras attached to this device
  
  // Additional device properties
  String firmwareVersion;
  String ipv4;
  String lastSeenAt;
  String recordPath;
  String uptime;
  String deviceType;
  bool connected;
  final String macKey;  // The MAC key extracted from device path
  
  
  // For backward compatibility with existing code
  String get macAddress => macKey;
  
CameraDevice({
    required this.id,
    required this.type,
    this.status = DeviceStatus.unknown,
    this.cameras = const [],
    this.firmwareVersion = '',
    this.ipv4 = '',
    this.lastSeenAt = '',
    this.recordPath = '',
    this.uptime = '',
    this.deviceType = '',
    this.connected = false,
    this.macKey = '',
  });
  
  // Factory constructor to create a CameraDevice from JSON
  factory CameraDevice.fromJson(Map<String, dynamic> json) {
    // Parse base properties
    String deviceId = json['id'] ?? '';
    String deviceType = json['type'] ?? '';
    DeviceStatus deviceStatus = DeviceStatus.unknown;
    
    // Extract MAC address (usually in id field after ecs.slave.)
    String macKey = '';
    if (deviceId.isNotEmpty && deviceId.contains('ecs.slave.')) {
      macKey = deviceId.split('ecs.slave.')[1];
      if (macKey.contains('.')) {
        macKey = macKey.split('.')[0]; // Get the first part which is the MAC
      }
    }
    
    // Parse cameras if available
    List<Camera> deviceCameras = [];
    var camerasJson = json['cameras'] as List<dynamic>?;
    if (camerasJson != null) {
      deviceCameras = camerasJson
        .map((cameraJson) => Camera.fromJson(cameraJson))
        .toList();
    }
    
    // Determine device status based on connectivity
    bool isConnected = json['connected'] ?? false;
    deviceStatus = isConnected ? DeviceStatus.online : DeviceStatus.offline;
    
    // Return a new CameraDevice instance
    return CameraDevice(
      id: deviceId,
      type: deviceType,
      status: deviceStatus,
      cameras: deviceCameras,
      firmwareVersion: json['firmwareVersion'] ?? '',
      ipv4: json['ipv4'] ?? '',
      lastSeenAt: json['lastSeenAt'] ?? '',
      recordPath: json['recordPath'] ?? '',
      uptime: json['uptime'] ?? '',
      deviceType: json['deviceType'] ?? '',
      connected: isConnected,
      macKey: macKey,
    );
  }
  
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
  String model;               // Camera model
  String mediaUri;            // RTSP URI for main stream
  String recordUri;           // URI for recording stream
  String remoteUri;           // Remote URI for external access
  String subUri;              // RTSP URI for sub stream (lower resolution)
  String xAddrs;              // Web services address
  int mediaHeight;            // Height of main stream resolution
  int mediaWidth;             // Width of main stream resolution
  int recordHeight;           // Height of recording resolution
  int recordWidth;            // Width of recording resolution
  int remoteHeight;           // Height of remote stream resolution
  int remoteWidth;            // Width of remote stream resolution
  int subHeight;              // Height of sub-stream resolution
  int subWidth;               // Width of sub-stream resolution
  String subCodec;            // Codec for sub-stream (e.g., H.264)
  String id;                  // Unique identifier for the camera
  
  // Camera status properties
  bool connected = false;     // Is camera currently connected
  bool recording = false;     // Is camera currently recording
  String lastSeenAt = '';     // When camera was last seen
  String country = '';     // Camera country location
  
  // Getter for the RTSP URI (using subUri by default as requested by the user)
  String get rtspUri => subUri;

  // Constructor for creating a Camera
  Camera({
    required this.index,
    required this.name,
    required this.ip,
    required this.rawIp,
    required this.username,
    required this.password,
    required this.brand,
    required this.hw,
    required this.manufacturer,
    required this.model,
    required this.mediaUri,
    required this.recordUri,
    required this.remoteUri,
    required this.subUri,
    required this.xAddrs,
    required this.mediaHeight,
    required this.mediaWidth,
    required this.recordHeight,
    required this.recordWidth,
    required this.remoteHeight,
    required this.remoteWidth,
    required this.subHeight,
    required this.subWidth,
    required this.subCodec,
    required this.id,
    this.connected = false,
    this.recording = false,
    this.lastSeenAt = '',
  });
  
  // Helper method to extract an integer from JSON
  static int getInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  // Factory constructor to create a Camera from JSON
  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      index: getInt(json['index']),
      name: json['name'] ?? '',
      ip: json['cameraIp'] ?? '',
      rawIp: getInt(json['cameraRawIp']),
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      brand: json['brand'] ?? '',
      hw: json['hw'] ?? '',
      manufacturer: json['manufacturer'] ?? '',
      model: json['model'] ?? '',
      mediaUri: json['mediaUri'] ?? '',
      recordUri: json['recordUri'] ?? '',
      remoteUri: json['remoteUri'] ?? '',
      subUri: json['subUri'] ?? '',
      xAddrs: json['xAddrs'] ?? '',
      mediaHeight: getInt(json['mediaHeight']),
      mediaWidth: getInt(json['mediaWidth']),
      recordHeight: getInt(json['recordHeight']),
      recordWidth: getInt(json['recordWidth']),
      remoteHeight: getInt(json['remoteHeight']),
      remoteWidth: getInt(json['remoteWidth']),
      subHeight: getInt(json['subHeight']),
      subWidth: getInt(json['subWidth']),
      subCodec: json['subCodec'] ?? 'H.264',
      id: json['cameraId'] ?? '',
      connected: json['connected'] ?? false,
      recording: json['recording'] ?? false,
      lastSeenAt: json['lastSeenAt'] ?? '',
    );
  }
  
  @override
  String toString() {
    return 'Camera { name: $name, ip: $ip, stream: $subUri, connected: $connected }';
  }
}
