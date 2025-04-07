import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers/camera_devices_provider.dart';
import '../providers/multi_view_layout_provider.dart';
import '../models/camera_device.dart';
import '../models/camera_layout.dart';
import '../theme/app_theme.dart';
import '../widgets/video_controls.dart';
import '../utils/responsive_helper.dart';
import 'dart:math' as math;

class MultiLiveViewScreen extends StatefulWidget {
  const MultiLiveViewScreen({Key? key}) : super(key: key);

  @override
  State<MultiLiveViewScreen> createState() => _MultiLiveViewScreenState();
}

class _MultiLiveViewScreenState extends State<MultiLiveViewScreen> {
  // Maximum number of cameras per page (requirement: 20 per page)
  static const int maxCamerasPerPage = 20;
  
  // State variables
  List<Camera> _availableCameras = [];
  final List<Camera?> _selectedCameras = List.filled(maxCamerasPerPage, null);
  final List<Player> _players = [];
  final List<VideoController> _controllers = [];
  final List<bool> _loadingStates = List.filled(maxCamerasPerPage, false);
  final List<bool> _errorStates = List.filled(maxCamerasPerPage, false);
  int _currentPage = 0;
  int _totalPages = 1;
  int _gridColumns = 4; // Default grid columns for desktop
  CameraLayout _currentLayout = CameraLayout(name: 'Default', id: 4, rows: 5, columns: 4, slots: 20, description: 'Default layout');
  
  @override
  void initState() {
    super.initState();
    _initializePlayers();
  }
  
  void _initializePlayers() {
    // Initialize players for all camera slots
    for (int i = 0; i < maxCamerasPerPage; i++) {
      final player = Player();
      final controller = VideoController(player);
      
      _players.add(player);
      _controllers.add(controller);
      
      // Set up error listeners
      player.stream.error.listen((error) {
        if (mounted) {
          setState(() {
            _errorStates[i] = true;
          });
          print('Player $i error: $error');
        }
      });
      
      // Set up buffering listeners
      player.stream.buffering.listen((buffering) {
        if (mounted) {
          setState(() {
            _loadingStates[i] = buffering;
          });
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get available cameras from provider
    final cameraProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    final cameras = cameraProvider.cameras;
    
    // Get layout from provider if available
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context, listen: false);
    if (layoutProvider.currentLayout != null) {
      _currentLayout = layoutProvider.currentLayout!;
      _gridColumns = _currentLayout.columns;
    }
    
    setState(() {
      _availableCameras = cameras;
      _totalPages = (cameras.length / maxCamerasPerPage).ceil();
      if (_totalPages == 0) _totalPages = 1; // Always have at least one page
      
      // Initialize slots with available cameras for the current page
      _loadCamerasForCurrentPage();
    });
    
    // Adjust grid columns based on screen size
    _updateGridColumnsBasedOnScreenSize();
  }
