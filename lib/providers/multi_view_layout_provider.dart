import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/camera_layout.dart';

class MultiViewLayoutProvider with ChangeNotifier {
  List<CameraLayout> _availableLayouts = [];
  Map<int, CameraLayout> _layoutsMap = {};
  
  // Store configuration for each page (up to 10 pages)
  final List<MultiViewPageConfig> _pageConfigs = [];
  int _maxPages = 10;  // Maximum number of pages
  int _currentPage = 0;  // Current active page

  // Default layout code to use
  int _defaultLayoutCode = 303;  // 4-camera layout

  // Getters
  List<CameraLayout> get availableLayouts => _availableLayouts;
  Map<int, CameraLayout> get layoutsMap => _layoutsMap;
  List<MultiViewPageConfig> get pageConfigs => _pageConfigs;
  int get maxPages => _maxPages;
  int get currentPage => _currentPage;
  int get defaultLayoutCode => _defaultLayoutCode;
  
  MultiViewPageConfig get currentPageConfig => 
      _pageConfigs.length > _currentPage ? _pageConfigs[_currentPage] : _createDefaultPageConfig();

  CameraLayout? getLayoutByCode(int layoutCode) => _layoutsMap[layoutCode];

  MultiViewLayoutProvider() {
    _initializeLayouts();
  }

  Future<void> _initializeLayouts() async {
    try {
      // Load layouts from the assets file
      final String jsonString = await rootBundle.loadString('assets/layouts/combined_camera_layouts_1_to_36.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      _availableLayouts = jsonList
          .map((json) => CameraLayout.fromJson(json))
          .toList();
      
      // Create a map for easier access by layout code
      _layoutsMap = {for (var layout in _availableLayouts) layout.layoutCode: layout};
      
      // Initialize default page configurations
      _initializePageConfigs();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading camera layouts: $e');
    }
  }

  void _initializePageConfigs() {
    _pageConfigs.clear();
    
    // Create default configuration for each page
    for (int i = 0; i < _maxPages; i++) {
      _pageConfigs.add(_createDefaultPageConfig());
    }
  }

  MultiViewPageConfig _createDefaultPageConfig() {
    final layout = _layoutsMap[_defaultLayoutCode] ?? 
        (_availableLayouts.isNotEmpty ? _availableLayouts.first : null);
    
    if (layout != null) {
      return MultiViewPageConfig.empty(layout.layoutCode, layout.maxCameraNumber);
    }
    
    // Fallback to a simple 4-camera layout if nothing is available
    return MultiViewPageConfig(
      layoutCode: 303,
      cameraAssignments: List.filled(4, null),
    );
  }

  // Set the current page
  void setCurrentPage(int page) {
    if (page >= 0 && page < _maxPages) {
      _currentPage = page;
      notifyListeners();
    }
  }

  // Change the layout for the current page
  void setCurrentPageLayout(int layoutCode) {
    final layout = _layoutsMap[layoutCode];
    if (layout != null) {
      // Create a new page configuration with the new layout
      final currentAssignments = currentPageConfig.cameraAssignments;
      final MultiViewPageConfig newConfig = MultiViewPageConfig(
        layoutCode: layoutCode,
        cameraAssignments: List.filled(layout.maxCameraNumber, null),
      );
      
      // Try to preserve existing camera assignments where possible
      for (int i = 0; i < newConfig.cameraAssignments.length && i < currentAssignments.length; i++) {
        newConfig.cameraAssignments[i] = currentAssignments[i];
      }
      
      // Update the current page's configuration
      _pageConfigs[_currentPage] = newConfig;
      notifyListeners();
    }
  }

  // Set the layout for a specific page
  void setPageLayout(int page, int layoutCode) {
    if (page >= 0 && page < _maxPages) {
      final layout = _layoutsMap[layoutCode];
      if (layout != null) {
        final currentConfig = _pageConfigs[page];
        // Create new config with the new layout
        final MultiViewPageConfig newConfig = MultiViewPageConfig(
          layoutCode: layoutCode,
          cameraAssignments: List.filled(layout.maxCameraNumber, null),
        );
        
        // Try to preserve existing camera assignments where possible
        for (int i = 0; i < newConfig.cameraAssignments.length && i < currentConfig.cameraAssignments.length; i++) {
          newConfig.cameraAssignments[i] = currentConfig.cameraAssignments[i];
        }
        
        _pageConfigs[page] = newConfig;
        notifyListeners();
      }
    }
  }

  // Set default layout code
  void setDefaultLayoutCode(int layoutCode) {
    if (_layoutsMap.containsKey(layoutCode)) {
      _defaultLayoutCode = layoutCode;
      notifyListeners();
    }
  }

  // Assign a camera to a slot in the current page
  void assignCameraToSlot(int slotIndex, int? cameraId) {
    if (slotIndex >= 0 && slotIndex < currentPageConfig.cameraAssignments.length) {
      currentPageConfig.cameraAssignments[slotIndex] = cameraId;
      notifyListeners();
    }
  }

  // Clear a slot in the current page
  void clearSlot(int slotIndex) {
    if (slotIndex >= 0 && slotIndex < currentPageConfig.cameraAssignments.length) {
      currentPageConfig.cameraAssignments[slotIndex] = null;
      notifyListeners();
    }
  }
}