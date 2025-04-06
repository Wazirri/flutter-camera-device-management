import 'camera.dart';

/// Model class representing a camera device with multiple cameras
class CameraDevice {
  final String mac;
  final List<Camera> cameras;
  final bool isConnected;
  final Map<String, dynamic>? additionalInfo;

  CameraDevice({
    required this.mac,
    required this.cameras,
    this.isConnected = false,
    this.additionalInfo,
  });

  /// Create a CameraDevice from a JSON map
  factory CameraDevice.fromJson(Map<String, dynamic> json) {
    final camerasList = (json['cameras'] as List?)
        ?.map((camera) => Camera.fromJson(camera))
        .toList() ?? 
        [];

    return CameraDevice(
      mac: json['mac'] ?? '',
      cameras: camerasList,
      isConnected: json['isConnected'] ?? false,
      additionalInfo: json['additionalInfo'],
    );
  }

  /// Convert the CameraDevice instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'mac': mac,
      'cameras': cameras.map((camera) => camera.toJson()).toList(),
      'isConnected': isConnected,
      'additionalInfo': additionalInfo,
    };
  }

  /// Create a copy of this CameraDevice with the specified properties updated
  CameraDevice copyWith({
    String? mac,
    List<Camera>? cameras,
    bool? isConnected,
    Map<String, dynamic>? additionalInfo,
  }) {
    return CameraDevice(
      mac: mac ?? this.mac,
      cameras: cameras ?? this.cameras,
      isConnected: isConnected ?? this.isConnected,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }

  @override
  String toString() {
    return 'CameraDevice{mac: $mac, cameras: ${cameras.length}, isConnected: $isConnected}';
  }
}
