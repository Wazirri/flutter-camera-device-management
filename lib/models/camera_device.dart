// Device and camera models

// Device status enum
enum DeviceStatus {
  online,
  offline,
  warning,
  error,
  unknown
}

// Camera device model
class CameraDevice {
  final String macKey; // Key in format m_XX_XX_XX_XX_XX_XX
  final String macAddress; // Formatted MAC address
  String ipv4;
  DeviceStatus status;
  List<Camera> cameras;
  
  CameraDevice({
    required this.macKey,
    required this.macAddress,
    required this.ipv4,
    required this.status,
    required this.cameras,
  });
}

// Camera model
class Camera {
  final int index; // Index in the parent device
  int globalIndex; // Global index in the system
  String name;
  String ip;
  String username;
  String password;
  bool connected;
  bool recording;
  String mainSnapShot;
  String subSnapShot;
  String mediaUri;
  String recordUri;
  String remoteUri;
  String subUri;
  
  Camera({
    required this.index,
    required this.globalIndex,
    required this.name,
    required this.ip,
    required this.username,
    required this.password,
    required this.connected,
    required this.recording,
    required this.mainSnapShot,
    required this.subSnapShot,
    required this.mediaUri,
    required this.recordUri,
    required this.remoteUri,
    required this.subUri,
  });
}
