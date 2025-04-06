import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/camera_layout.dart';

/// Manager class for camera layouts
class CameraLayoutManager {
  final List<CameraLayout> _layouts = [];
  bool _isLoaded = false;

  List<CameraLayout> get layouts => _layouts;
  bool get isLoaded => _isLoaded;

  /// Load camera layouts from JSON file
  Future<void> loadLayouts() async {
    try {
      // Load the combined layout file with all layouts from 1 to 36 cameras
      final jsonString = await rootBundle.loadString('assets/layouts/combined_camera_layouts_1_to_36.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      
      // Parse the layouts data
      final layoutsData = jsonData['layouts'] as List<dynamic>;
      
      // Clear existing layouts
      _layouts.clear();
      
      // Add all layouts
      for (final layoutData in layoutsData) {
        _layouts.add(CameraLayout.fromJson(layoutData));
      }
      
      // Sort layouts by layoutCode
      _layouts.sort((a, b) => a.layoutCode.compareTo(b.layoutCode));
      
      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading camera layouts: $e');
      _isLoaded = false;
    }
  }

  /// Get a layout by its code
  CameraLayout? getLayoutByCode(int layoutCode) {
    try {
      return _layouts.firstWhere((layout) => layout.layoutCode == layoutCode);
    } catch (e) {
      return null;
    }
  }
}

/// Provider for managing the multi-view layout state
class MultiViewLayoutProvider extends ChangeNotifier {
  final CameraLayoutManager layoutManager = CameraLayoutManager();
  int _currentLayoutCode = 1; // Default to layout 1
  bool _isLoading = true;
  
  // Map of camera assignments: slot code -> camera ID
  final Map<int, String?> _cameraAssignments = {};
  
  MultiViewLayoutProvider() {
    _init();
  }
  
  /// Initialize the provider
  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    
    await layoutManager.loadLayouts();
    
    // If layouts were loaded successfully, set the current layout to the first one
    if (layoutManager.isLoaded && layoutManager.layouts.isNotEmpty) {
      _currentLayoutCode = layoutManager.layouts.first.layoutCode;
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  /// Get the current layout
  CameraLayout? get currentLayout => layoutManager.getLayoutByCode(_currentLayoutCode);
  
  /// Check if the provider is still loading data
  bool get isLoading => _isLoading;
  
  /// Set the current layout by code
  void setLayout(int layoutCode) {
    // Check if the layout exists
    final layout = layoutManager.getLayoutByCode(layoutCode);
    if (layout != null) {
      _currentLayoutCode = layoutCode;
      
      // Clear camera assignments for slots that don't exist in the new layout
      final validSlots = layout.cameraLocations.map((loc) => loc.cameraCode).toSet();
      _cameraAssignments.removeWhere((slotCode, _) => !validSlots.contains(slotCode));
      
      notifyListeners();
    }
  }
  
  /// Get the camera ID assigned to a slot, or null if no camera is assigned
  String? getCameraForSlot(int slotCode) {
    return _cameraAssignments[slotCode];
  }
  
  /// Assign a camera to a slot
  void setCameraForSlot(int slotCode, String? cameraId) {
    if (_cameraAssignments[slotCode] != cameraId) {
      _cameraAssignments[slotCode] = cameraId;
      notifyListeners();
    }
  }
  
  /// Swap cameras between two slots
  void swapCameras(int slotCode1, int slotCode2) {
    final cam1 = _cameraAssignments[slotCode1];
    final cam2 = _cameraAssignments[slotCode2];
    
    _cameraAssignments[slotCode1] = cam2;
    _cameraAssignments[slotCode2] = cam1;
    
    notifyListeners();
  }
  
  /// Get the number of slots that have cameras assigned
  int getAssignedCameraCount() {
    return _cameraAssignments.values.where((cameraId) => cameraId != null).length;
  }
  
  /// Clear all camera assignments
  void clearAllAssignments() {
    _cameraAssignments.clear();
    notifyListeners();
  }
}
