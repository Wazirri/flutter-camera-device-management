import 'package:flutter/material.dart';
import '../models/camera_layout.dart';
import '../models/camera_device.dart';

/// Manages the state and logic for multi-view camera layouts
class MultiViewLayoutProvider extends ChangeNotifier {
  // The camera layout manager instance
  final CameraLayoutManager _layoutManager = CameraLayoutManager();
  
  // The currently selected layout
  CameraLayout? _currentLayout;
  
  // Map to store camera assignments for each slot (cameraCode: cameraId)
  final Map<int, String> _cameraAssignments = {};
  
  // Current page for multi-camera view pagination
  int _currentPage = 0;

  // Maximum number of cameras per page
  final int _camerasPerPage = 20;
  
  // Flag to track loading state
  bool _isLoading = true;
  
  // Getters
  CameraLayoutManager get layoutManager => _layoutManager;
  CameraLayout? get currentLayout => _currentLayout;
  Map<int, String> get cameraAssignments => _cameraAssignments;
  int get currentPage => _currentPage;
  int get camerasPerPage => _camerasPerPage;
  bool get isLoading => _isLoading;
  
  // Initialize the provider
  MultiViewLayoutProvider() {
    _init();
  }
  
  // Initialization method
  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _layoutManager.loadLayouts();
      
      // Set default layout (4 cameras grid layout)
      _currentLayout = _layoutManager.getLayoutByCode(303);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error initializing MultiViewLayoutProvider: $e');
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Change the current layout
  void setLayout(int layoutCode) {
    try {
      final newLayout = _layoutManager.getLayoutByCode(layoutCode);
      
      if (newLayout != null) {
        _currentLayout = newLayout;
        
        // Clear camera assignments for slots that don't exist in the new layout
        _cameraAssignments.removeWhere((code, _) => 
          !newLayout.cameraLocations.any((loc) => loc.cameraCode == code)
        );
        
        notifyListeners();
      }
    } catch (e) {
      print('Error setting layout: $e');
    }
  }
  
  // Assign a camera to a slot
  void assignCamera(int slotCode, String cameraId) {
    if (_currentLayout == null) return;
    
    // Check if the slot exists in the current layout
    final slotExists = _currentLayout!.cameraLocations
        .any((loc) => loc.cameraCode == slotCode);
    
    if (slotExists) {
      // Remove camera if it's already assigned to another slot
      _cameraAssignments.removeWhere((_, id) => id == cameraId);
      
      // Assign the camera to the slot
      _cameraAssignments[slotCode] = cameraId;
      notifyListeners();
    }
  }
  
  // Remove a camera from a slot
  void removeCamera(int slotCode) {
    if (_cameraAssignments.containsKey(slotCode)) {
      _cameraAssignments.remove(slotCode);
      notifyListeners();
    }
  }
  
  // Clear all camera assignments
  void clearAllAssignments() {
    _cameraAssignments.clear();
    notifyListeners();
  }
  
  // Get camera assigned to a specific slot
  String? getCameraForSlot(int slotCode) {
    return _cameraAssignments[slotCode];
  }
  
  // Set the current page
  void setPage(int page) {
    if (page >= 0) {
      _currentPage = page;
      notifyListeners();
    }
  }
  
  // Get number of pages based on available cameras
  int getPageCount(List<CameraDevice> cameras) {
    return (cameras.length / _camerasPerPage).ceil();
  }
  
  // Get cameras for the current page
  List<CameraDevice> getCamerasForCurrentPage(List<CameraDevice> allCameras) {
    final startIndex = _currentPage * _camerasPerPage;
    final endIndex = startIndex + _camerasPerPage;
    
    if (startIndex >= allCameras.length) {
      return [];
    }
    
    return allCameras.sublist(
      startIndex,
      endIndex > allCameras.length ? allCameras.length : endIndex,
    );
  }
}
