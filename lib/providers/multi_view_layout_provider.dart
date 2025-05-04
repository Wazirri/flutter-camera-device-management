import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/camera_layout.dart';
import '../models/camera_device.dart';

class MultiViewLayoutProvider extends ChangeNotifier {
  // List of all available layouts
  List<CameraLayout> _availableLayouts = [];
  
  // Currently selected layout
  CameraLayout? _currentLayout;
  
  // Current page in multi-view
  int _currentPage = 0;

  // Track whether the layouts have been loaded
  bool _isLoaded = false;

  // Constructor
  MultiViewLayoutProvider() {
    loadLayouts();
  }

  // Getters
  List<CameraLayout> get availableLayouts => _availableLayouts;
  CameraLayout? get currentLayout => _currentLayout;
  int get currentPage => _currentPage;
  bool get isLoaded => _isLoaded;

  // Load layouts from asset file
  Future<void> loadLayouts() async {
    try {
      // Load layout configurations from asset file
      final String jsonData = await rootBundle.loadString('assets/layouts/combined_camera_layouts_1_to_36.json');
      _availableLayouts = CameraLayout.parseLayouts(jsonData);
      
      // Set default layout if available
      if (_availableLayouts.isNotEmpty) {
        _currentLayout = _availableLayouts.firstWhere(
          (layout) => layout.id == 4, // Layout with 4 columns and 5 rows (20 slots)
          orElse: () => _availableLayouts.first
        );
      } else {
        // Fallback to a basic layout if none are loaded
        _currentLayout = CameraLayout(
          name: 'Default',
          id: 4,
          rows: 5,
          columns: 4,
          slots: 20,
          description: 'Default layout'
        );
        _availableLayouts.add(_currentLayout!);
      }
      
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      print('Error loading camera layouts: $e');
      // Fallback to a basic layout if loading fails
      _currentLayout = CameraLayout(
        name: 'Default',
        id: 4,
        rows: 5,
        columns: 4,
        slots: 20,
        description: 'Default layout'
      );
      _availableLayouts = [_currentLayout!];
      _isLoaded = true;
      notifyListeners();
    }
  }

  // Set the current layout by ID
  void setCurrentLayoutById(int layoutId) {
    final layout = _availableLayouts.firstWhere(
      (l) => l.id == layoutId,
      orElse: () => _currentLayout!
    );
    
    _currentLayout = layout;
    notifyListeners();
  }

  // Set the current layout
  void setCurrentLayout(CameraLayout layout) {
    _currentLayout = layout;
    notifyListeners();
  }

  // Set current page
  void setCurrentPage(int page) {
    if (page >= 0) {
      _currentPage = page;
      notifyListeners();
    }
  }

  // Assign a camera to a slot in the current layout
  void assignCameraToSlot(Camera camera, int slotIndex) {
    if (_currentLayout != null) {
      _currentLayout!.assignCamera(camera.id, slotIndex);
      notifyListeners();
    }
  }

  // Remove a camera from the current layout
  void removeCameraFromLayout(String cameraId) {
    if (_currentLayout != null) {
      _currentLayout!.removeCamera(cameraId);
      notifyListeners();
    }
  }

  // Clear all camera assignments in the current layout
  void clearCurrentLayoutAssignments() {
    if (_currentLayout != null) {
      _currentLayout!.clearAssignments();
      notifyListeners();
    }
  }

  // Get the camera ID at a specific slot in the current layout
  String? getCameraIdAtSlot(int slotIndex) {
    return _currentLayout?.getCameraIdAtSlot(slotIndex);
  }

  // Save the current layout configuration
  Future<void> saveCurrentLayout() async {
    // Implementation would depend on how you want to persist the layouts
    // For example, you might want to save to shared preferences or a file
    notifyListeners();
  }
}
