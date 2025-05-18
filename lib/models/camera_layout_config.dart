// JSON layout modeli - cameraLayout.json için özel model
// Bu model, assets/layouts/cameraLayout.json'daki formata özeldir

class CameraLayoutConfig {
  final int layoutCode;
  final int maxCameraNumber;
  final List<CameraLocationConfig> cameraLoc;

  CameraLayoutConfig({
    required this.layoutCode,
    required this.maxCameraNumber,
    required this.cameraLoc,
  });

  factory CameraLayoutConfig.fromJson(Map<String, dynamic> json) {
    var cameraLocations = <CameraLocationConfig>[];
    if (json['cameraLoc'] != null) {
      cameraLocations = List<CameraLocationConfig>.from(
        json['cameraLoc'].map((locJson) => CameraLocationConfig.fromJson(locJson)),
      );
    }

    return CameraLayoutConfig(
      layoutCode: json['layoutCode'] as int,
      maxCameraNumber: json['maxCameraNumber'] as int,
      cameraLoc: cameraLocations,
    );
  }

  Map<String, dynamic> toJson() => {
        'layoutCode': layoutCode,
        'maxCameraNumber': maxCameraNumber,
        'cameraLoc': cameraLoc.map((loc) => loc.toJson()).toList(),
      };
}

class CameraLocationConfig {
  final int cameraCode;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final int? rotation; // Bazı kamera konumlarında isteğe bağlı rotation değeri var

  CameraLocationConfig({
    required this.cameraCode,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.rotation,
  });

  factory CameraLocationConfig.fromJson(Map<String, dynamic> json) {
    return CameraLocationConfig(
      cameraCode: json['cameraCode'] as int,
      x1: (json['x1'] as num).toDouble(),
      y1: (json['y1'] as num).toDouble(),
      x2: (json['x2'] as num).toDouble(),
      y2: (json['y2'] as num).toDouble(),
      rotation: json['rotation'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'cameraCode': cameraCode,
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
        if (rotation != null) 'rotation': rotation,
      };
}
