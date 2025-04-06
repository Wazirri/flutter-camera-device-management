import 'dart:convert';

/// Represents a single camera position in a layout
class CameraPosition {
  final int cameraCode;  // Unique identifier for the slot within the layout
  final double x1;       // Top-left corner X coordinate (percentage)
  final double y1;       // Top-left corner Y coordinate (percentage)
  final double x2;       // Bottom-right corner X coordinate (percentage)
  final double y2;       // Bottom-right corner Y coordinate (percentage)

  const CameraPosition({
    required this.cameraCode,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  factory CameraPosition.fromJson(Map<String, dynamic> json) {
    return CameraPosition(
      cameraCode: json['cameraCode'] as int,
      x1: (json['x1'] as num).toDouble(),
      y1: (json['y1'] as num).toDouble(),
      x2: (json['x2'] as num).toDouble(),
      y2: (json['y2'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'cameraCode': cameraCode,
    'x1': x1,
    'y1': y1,
    'x2': x2,
    'y2': y2,
  };
}

/// Represents a complete layout template for arranging multiple cameras
class CameraLayout {
  final int layoutCode;          // Unique identifier for the layout
  final int maxCameraNumber;     // Maximum number of cameras this layout supports
  final List<CameraPosition> cameraLoc; // Camera locations within the layout

  const CameraLayout({
    required this.layoutCode,
    required this.maxCameraNumber,
    required this.cameraLoc,
  });

  factory CameraLayout.fromJson(Map<String, dynamic> json) {
    return CameraLayout(
      layoutCode: json['layoutCode'] as int,
      maxCameraNumber: json['maxCameraNumber'] as int,
      cameraLoc: (json['cameraLoc'] as List)
          .map((e) => CameraPosition.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'layoutCode': layoutCode,
    'maxCameraNumber': maxCameraNumber,
    'cameraLoc': cameraLoc.map((e) => e.toJson()).toList(),
  };
}

/// Represents a page configuration for multi-view
class MultiViewPageConfig {
  int layoutCode;
  List<int?> cameraAssignments; // Camera IDs assigned to each slot (null means empty)

  MultiViewPageConfig({
    required this.layoutCode,
    required this.cameraAssignments,
  });

  factory MultiViewPageConfig.empty(int layoutCode, int maxCameras) {
    return MultiViewPageConfig(
      layoutCode: layoutCode,
      cameraAssignments: List.filled(maxCameras, null),
    );
  }

  Map<String, dynamic> toJson() => {
    'layoutCode': layoutCode,
    'cameraAssignments': cameraAssignments,
  };

  factory MultiViewPageConfig.fromJson(Map<String, dynamic> json) {
    return MultiViewPageConfig(
      layoutCode: json['layoutCode'] as int,
      cameraAssignments: (json['cameraAssignments'] as List).map((e) => e as int?).toList(),
    );
  }
}