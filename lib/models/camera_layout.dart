/// Model class representing a camera layout configuration
class CameraLayout {
  final int layoutCode;
  final int maxCameraNumber;
  final List<CameraLocation> cameraLocations;

  CameraLayout({
    required this.layoutCode,
    required this.maxCameraNumber,
    required this.cameraLocations,
  });

  /// Create a CameraLayout from a JSON map
  factory CameraLayout.fromJson(Map<String, dynamic> json) {
    final List<dynamic> locsList = json['cameraLoc'] ?? [];
    
    return CameraLayout(
      layoutCode: json['layoutCode'] ?? 0,
      maxCameraNumber: json['maxCameraNumber'] ?? 0,
      cameraLocations: locsList
          .map((loc) => CameraLocation.fromJson(loc))
          .toList(),
    );
  }

  /// Convert the CameraLayout instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'layoutCode': layoutCode,
      'maxCameraNumber': maxCameraNumber,
      'cameraLoc': cameraLocations.map((loc) => loc.toJson()).toList(),
    };
  }

  /// Create a copy of this CameraLayout with the specified properties updated
  CameraLayout copyWith({
    int? layoutCode,
    int? maxCameraNumber,
    List<CameraLocation>? cameraLocations,
  }) {
    return CameraLayout(
      layoutCode: layoutCode ?? this.layoutCode,
      maxCameraNumber: maxCameraNumber ?? this.maxCameraNumber,
      cameraLocations: cameraLocations ?? this.cameraLocations,
    );
  }
}

/// Model class representing a single camera location within a layout
class CameraLocation {
  final int cameraCode;
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  CameraLocation({
    required this.cameraCode,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  /// Create a CameraLocation from a JSON map
  factory CameraLocation.fromJson(Map<String, dynamic> json) {
    return CameraLocation(
      cameraCode: json['cameraCode'] ?? 0,
      x1: (json['x1'] ?? 0).toDouble(),
      y1: (json['y1'] ?? 0).toDouble(),
      x2: (json['x2'] ?? 0).toDouble(),
      y2: (json['y2'] ?? 0).toDouble(),
    );
  }

  /// Convert the CameraLocation instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'cameraCode': cameraCode,
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
    };
  }

  /// Create a copy of this CameraLocation with the specified properties updated
  CameraLocation copyWith({
    int? cameraCode,
    double? x1,
    double? y1,
    double? x2,
    double? y2,
  }) {
    return CameraLocation(
      cameraCode: cameraCode ?? this.cameraCode,
      x1: x1 ?? this.x1,
      y1: y1 ?? this.y1,
      x2: x2 ?? this.x2,
      y2: y2 ?? this.y2,
    );
  }
}
