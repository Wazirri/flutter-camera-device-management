import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/camera_layout.dart';

class MultiViewLayoutProvider with ChangeNotifier {
  // Store layouts for all pages
  List<CameraLayout> _layouts = [];
  
  // Store camera assignments for each page
  // Map: pageIndex -> Map(positionId -> cameraId)
  Map<int, Map<int, String>> _cameraAssignments = {};
  
  // Current active page index (0-4 for pages 1-5)
  int _currentPageIndex = 0;
  
  // Current active layout per page
  Map<int, int> _activeLayoutPerPage = {};
  
  // Maximum number of pages supported
  static const int maxPages = 5;
  
  // Getters
  List<CameraLayout> get layouts => _layouts;
  int get currentPageIndex => _currentPageIndex;
  
  CameraLayout? get currentLayout {
    if (_layouts.isEmpty) return null;
    
    final activeLayoutId = _activeLayoutPerPage[_currentPageIndex] ?? 0;
    return _layouts.firstWhere(
      (layout) => layout.id == activeLayoutId,
      orElse: () => _layouts.first,
    );
  }
  
  // Get camera assignments for the current page
  Map<int, String> get currentPageAssignments {
    return _cameraAssignments[_currentPageIndex] ?? {};
  }
  
  // Get camera assignments for a specific page
  Map<int, String> getCameraAssignmentsForPage(int pageIndex) {
    return _cameraAssignments[pageIndex] ?? {};
  }
  
  // Constructor - Initialize data
  MultiViewLayoutProvider() {
    _initializeLayouts();
  }
  
  // Initialize layouts data
  Future<void> _initializeLayouts() async {
    try {
      // Load layout data from JSON file
      final String jsonData = await rootBundle.loadString('assets/layouts/combined_camera_layouts_1_to_36.json');
      final List<dynamic> layoutsJson = jsonDecode(jsonData) as List<dynamic>;
      
      // Parse layouts
      _layouts = layoutsJson
          .map((layout) => CameraLayout.fromJson(layout as Map<String, dynamic>))
          .toList();
      
      // Initialize default assignments for all pages (empty)
      for (int i = 0; i < maxPages; i++) {
        _cameraAssignments[i] = {};
        
        // Set default layout for each page (using the first layout)
        if (_layouts.isNotEmpty) {
          _activeLayoutPerPage[i] = _layouts.first.id;
        }
      }
      
      debugPrint('Loaded ${_layouts.length} camera layouts');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading camera layouts: $e');
      
      // Create default layouts in case of error
      _createDefaultLayouts();
    }
  }
  
  // Create default layouts if JSON loading fails
  void _createDefaultLayouts() {
    // Create some basic layouts (1, 4, 9, 16, 25, 36 cameras)
    _layouts = [
      _createBasicLayout(1, "1 Camera"),
      _createBasicLayout(4, "4 Cameras (2x2)"),
      _createBasicLayout(9, "9 Cameras (3x3)"),
      _createBasicLayout(16, "16 Cameras (4x4)"),
      _createBasicLayout(25, "25 Cameras (5x5)"),
      _createBasicLayout(36, "36 Cameras (6x6)"),
    ];
    
    // Initialize default assignments (empty)
    for (int i = 0; i < maxPages; i++) {
      _cameraAssignments[i] = {};
      _activeLayoutPerPage[i] = _layouts.first.id;
    }
    
    notifyListeners();
  }
  
  // Helper to create basic grid layouts
  CameraLayout _createBasicLayout(int cameraCount, String name) {
    // Determine grid dimensions
    final int columns = cameraCount == 1 ? 1 : 
           cameraCount <= 4 ? 2 : 
           cameraCount <= 9 ? 3 : 
           cameraCount <= 16 ? 4 : 
           cameraCount <= 25 ? 5 : 6;
    
    final int rows = (cameraCount / columns).ceil();
    
    // Create positions
    final positions = <LayoutPosition>[];
    
    final double cellWidth = 1.0 / columns;
    final double cellHeight = 1.0 / rows;
    
    int positionId = 0;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        if (positionId >= cameraCount) break;
        
        positions.add(LayoutPosition(
          id: positionId,
          left: col * cellWidth,
          top: row * cellHeight,
          width: cellWidth,
          height: cellHeight,
          cameraId: null,
        ));
        
        positionId++;
      }
    }
    
    return CameraLayout(
      id: cameraCount, // Use camera count as ID for simplicity
      name: name,
      cameraCount: cameraCount,
      positions: positions,
    );
  }
  
  // Change current page
  void setCurrentPage(int pageIndex) {
    if (pageIndex >= 0 && pageIndex < maxPages) {
      _currentPageIndex = pageIndex;
      notifyListeners();
    }
  }
  
  // Change layout for current page
  void setLayoutForCurrentPage(int layoutId) {
    _activeLayoutPerPage[_currentPageIndex] = layoutId;
    
    // Clear camera assignments for this page that don't exist in the new layout
    final newLayout = _layouts.firstWhere(
      (layout) => layout.id == layoutId,
      orElse: () => _layouts.first,
    );
    
    final validPositionIds = newLayout.positions.map((pos) => pos.id).toSet();
    final currentAssignments = _cameraAssignments[_currentPageIndex] ?? {};
    
    _cameraAssignments[_currentPageIndex] = Map.fromEntries(
      currentAssignments.entries.where((entry) => validPositionIds.contains(entry.key))
    );
    
    notifyListeners();
  }
  
  // Assign camera to position on current page
  void assignCameraToPosition(int positionId, String cameraId) {
    // Initialize if needed
    _cameraAssignments[_currentPageIndex] ??= {};
    
    // Assign camera
    _cameraAssignments[_currentPageIndex]![positionId] = cameraId;
    notifyListeners();
  }
  
  // Remove camera from position on current page
  void removeCameraFromPosition(int positionId) {
    if (_cameraAssignments[_currentPageIndex]?.containsKey(positionId) ?? false) {
      _cameraAssignments[_currentPageIndex]!.remove(positionId);
      notifyListeners();
    }
  }
  
  // Clear all camera assignments for current page
  void clearCurrentPageAssignments() {
    _cameraAssignments[_currentPageIndex] = {};
    notifyListeners();
  }
  
  // Get the camera ID assigned to a specific position on current page
  String? getCameraForPosition(int positionId) {
    return _cameraAssignments[_currentPageIndex]?[positionId];
  }
  
  // Save layout configuration
  Future<void> saveConfiguration() async {
    // This would typically save to local storage or server
    // For now, just log that we would save
    debugPrint('Saving multi-view configuration:');
    debugPrint('Active layouts per page: $_activeLayoutPerPage');
    debugPrint('Camera assignments: $_cameraAssignments');
  }
  
  // Load configuration
  Future<void> loadConfiguration() async {
    // This would typically load from local storage or server
    // For now, we use the default initialization
    debugPrint('Loading multi-view configuration');
  }
}
