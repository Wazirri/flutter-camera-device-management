import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Represents a camera location within a layout
class CameraLocation {
  final int cameraCode;
  final int x1;
  final int y1;
  final int x2;
  final int y2;
  
  const CameraLocation({
    required this.cameraCode,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });
  
  // Factory method to create a CameraLocation from a map (typically JSON data)
  factory CameraLocation.fromMap(Map<String, dynamic> map) {
    return CameraLocation(
      cameraCode: map['cameraCode'],
      x1: map['x1'],
      y1: map['y1'],
      x2: map['x2'],
      y2: map['y2'],
    );
  }
  
  // Convert the CameraLocation to a Map object (useful for serializing to JSON)
  Map<String, dynamic> toMap() {
    return {
      'cameraCode': cameraCode,
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
    };
  }
  
  // Create a copy with updated values
  CameraLocation copyWith({
    int? cameraCode,
    int? x1,
    int? y1,
    int? x2,
    int? y2,
  }) {
    return CameraLocation(
      cameraCode: cameraCode ?? this.cameraCode,
      x1: x1 ?? this.x1,
      y1: y1 ?? this.y1,
      x2: x2 ?? this.x2,
      y2: y2 ?? this.y2,
    );
  }
  
  @override
  String toString() {
    return 'CameraLocation(cameraCode: $cameraCode, x1: $x1, y1: $y1, x2: $x2, y2: $y2)';
  }
}

/// Represents a camera view layout with multiple camera locations
class CameraLayout {
  final int layoutCode;
  final int maxCameraNumber;
  final List<CameraLocation> cameraLocations;
  
  const CameraLayout({
    required this.layoutCode,
    required this.maxCameraNumber,
    required this.cameraLocations,
  });
  
  // Factory method to create a CameraLayout from a map (typically JSON data)
  factory CameraLayout.fromMap(Map<String, dynamic> map) {
    return CameraLayout(
      layoutCode: map['layoutCode'],
      maxCameraNumber: map['maxCameraNumber'],
      cameraLocations: List<CameraLocation>.from(
        map['cameraLoc']?.map((x) => CameraLocation.fromMap(x)) ?? [],
      ),
    );
  }
  
  // Convert the CameraLayout to a Map object (useful for serializing to JSON)
  Map<String, dynamic> toMap() {
    return {
      'layoutCode': layoutCode,
      'maxCameraNumber': maxCameraNumber,
      'cameraLoc': cameraLocations.map((x) => x.toMap()).toList(),
    };
  }
  
  // Create a copy with updated values
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
  
  @override
  String toString() {
    return 'CameraLayout(layoutCode: $layoutCode, maxCameraNumber: $maxCameraNumber, cameraLocations: $cameraLocations)';
  }
}

/// Utility class to load and manage camera layouts
class CameraLayoutManager {
  static final CameraLayoutManager _instance = CameraLayoutManager._internal();
  
  // Singleton instance
  factory CameraLayoutManager() => _instance;
  
  CameraLayoutManager._internal();
  
  List<CameraLayout> _layouts = [];
  bool _isLoaded = false;
  
  // Get a list of all available layouts
  List<CameraLayout> get layouts => _layouts;
  
  // Check if layouts are loaded
  bool get isLoaded => _isLoaded;
  
  // Get a layout by its code
  CameraLayout? getLayoutByCode(int code) {
    return _layouts.firstWhere(
      (layout) => layout.layoutCode == code, 
      orElse: () => throw Exception('Layout with code $code not found'),
    );
  }
  
  // Get a layout based on camera count (returns optimal layout for specified number of cameras)
  CameraLayout getLayoutForCameraCount(int count) {
    // Sort layouts by their maximum camera number to find the closest match
    final sortedLayouts = [..._layouts];
    sortedLayouts.sort((a, b) => a.maxCameraNumber.compareTo(b.maxCameraNumber));
    
    // Find the first layout that can accommodate the requested number of cameras
    for (final layout in sortedLayouts) {
      if (layout.maxCameraNumber >= count) {
        return layout;
      }
    }
    
    // If no suitable layout found, return the layout with the maximum number of cameras
    return sortedLayouts.last;
  }
  
  // Load layouts from the JSON file
  Future<void> loadLayouts() async {
    if (_isLoaded) return;
    
    try {
      final String jsonString = await rootBundle.loadString('assets/layouts/combined_camera_layouts_1_to_36.json');
      final List<dynamic> layoutsJson = json.decode(jsonString);
      
      _layouts = layoutsJson.map((layout) => CameraLayout.fromMap(layout)).toList();
      _isLoaded = true;
    } catch (e) {
      print('Error loading camera layouts: $e');
      _isLoaded = false;
      rethrow;
    }
  }
}
