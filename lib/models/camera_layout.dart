class CameraLayout {
  final int id;
  final String name;
  final int cameraCount;
  final List<LayoutPosition> positions;

  CameraLayout({
    required this.id,
    required this.name,
    required this.cameraCount,
    required this.positions,
  });

  factory CameraLayout.fromJson(Map<String, dynamic> json) {
    return CameraLayout(
      id: json['id'] as int,
      name: json['name'] as String,
      cameraCount: json['cameraCount'] as int,
      positions: (json['positions'] as List<dynamic>)
          .map((position) => LayoutPosition.fromJson(position as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cameraCount': cameraCount,
      'positions': positions.map((position) => position.toJson()).toList(),
    };
  }
}

class LayoutPosition {
  final int id;
  final double left;
  final double top;
  final double width;
  final double height;
  String? cameraId; // This will be set dynamically when user assigns a camera

  LayoutPosition({
    required this.id,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.cameraId,
  });

  factory LayoutPosition.fromJson(Map<String, dynamic> json) {
    return LayoutPosition(
      id: json['id'] as int,
      left: json['left'] as double,
      top: json['top'] as double,
      width: json['width'] as double,
      height: json['height'] as double,
      cameraId: json['cameraId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'left': left,
      'top': top,
      'width': width,
      'height': height,
      'cameraId': cameraId,
    };
  }
}
