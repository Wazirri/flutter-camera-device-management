import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers/camera_devices_provider.dart';
import '../providers/multi_view_layout_provider.dart';
import '../models/camera_device.dart';
import '../models/camera_layout.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;

class MultiLiveViewScreen extends StatefulWidget {
  const MultiLiveViewScreen({Key? key}) : super(key: key);

  @override
  State<MultiLiveViewScreen> createState() => _MultiLiveViewScreenState();
}

class _MultiLiveViewScreenState extends State<MultiLiveViewScreen>
    with AutomaticKeepAliveClientMixin {
  // Maximum number of cameras per page
  static const int maxCamerasPerPage = 20;

  // State variables
  List<Camera> _availableCameras = [];
  final List<Camera?> _selectedCameras = List.filled(maxCamerasPerPage, null);
  final List<Player> _players = [];
  final List<VideoController> _controllers = [];
  final List<bool> _loadingStates = List.filled(maxCamerasPerPage, false);
  final List<bool> _errorStates = List.filled(maxCamerasPerPage, false);
  final List<String> _errorMessages =
      List.filled(maxCamerasPerPage, ''); // Error messages per slot
  int _gridColumns = 4; // Default grid columns
  CameraLayout _currentLayout = CameraLayout(
      name: 'Default',
      id: 4,
      rows: 5,
      columns: 4,
      slots: 20,
      description: 'Default layout');
  bool _initialized = false;

  // Search and filter state
  String _searchQuery = '';
  String _selectedDeviceFilter =
      'all'; // 'all', 'distributed', 'not_distributed', or device MAC
  bool _showCameraSelector = false;

  @override
  bool get wantKeepAlive =>
      true; // Keep this widget alive when it's not visible

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
            _errorMessages[i] = 'Stream hatası: $error';
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

    // Only run this once to prevent reloading when dependencies change
    if (!_initialized) {
      _initialized = true;

      // Get available cameras from provider
      final cameraProvider =
          Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
      final cameras = cameraProvider.cameras;

      // Get layout from provider if available
      final layoutProvider =
          Provider.of<MultiViewLayoutProvider>(context, listen: false);
      if (layoutProvider.currentLayout != null) {
        _currentLayout = layoutProvider.currentLayout!;
        _gridColumns = _currentLayout.columns;
      }

      setState(() {
        _availableCameras = cameras;

        // Initialize slots with available cameras
        _loadCamerasForCurrentPage();
      });

      // Adjust grid columns based on screen size
      _updateGridColumnsBasedOnScreenSize();
    }
  }

  // Update grid columns based on screen size
  void _updateGridColumnsBasedOnScreenSize() {
    final size = MediaQuery.of(context).size;

    if (size.width < 600) {
      // Mobile: 2 columns
      _gridColumns = 2;
    } else if (size.width < 900) {
      // Small tablet: 3 columns
      _gridColumns = 3;
    } else {
      // Use layout provider columns or default to 4
      _gridColumns = _currentLayout.columns;
    }
  }

  // Load cameras for the current page
  void _loadCamerasForCurrentPage() {
    // Clear all slots first
    for (int i = 0; i < maxCamerasPerPage; i++) {
      _selectedCameras[i] = null;

      // Stop any existing players
      if (_players.isNotEmpty && i < _players.length) {
        _players[i].stop();
      }
    }

    // Only load cameras if we have any
    if (_availableCameras.isNotEmpty) {
      int maxToLoad = math.min(maxCamerasPerPage, _availableCameras.length);

      for (int i = 0; i < maxToLoad; i++) {
        final camera = _availableCameras[i];
        _selectedCameras[i] = camera;

        // Start streaming for all cameras, not just connected ones
        if (_players.isNotEmpty && i < _players.length) {
          _streamCamera(i, camera);
        }
      }
    }
  }

  // Stream camera at a specific slot
  void _streamCamera(int slotIndex, Camera camera) {
    if (!mounted) return;

    setState(() {
      _errorStates[slotIndex] = false; // Reset error state
      _errorMessages[slotIndex] = ''; // Reset error message
      _loadingStates[slotIndex] = true; // Set loading state
    });

    if (slotIndex < _players.length) {
      final player = _players[slotIndex];

      // Check if camera has RTSP URL
      if (camera.rtspUri.isNotEmpty) {
        print(
            '[MultiLiveView] Slot $slotIndex: Loading RTSP stream: ${camera.rtspUri}');
        try {
          // Only open if player is not already playing something or has a different URL
          if (player.state.playlist.medias.isEmpty ||
              (player.state.playlist.medias.isNotEmpty &&
                  player.state.playlist.medias.first.uri != camera.rtspUri)) {
            // Stop previous stream before loading new one
            player.stop();
            // Open new stream
            player.open(Media(camera.rtspUri));
            print(
                '[MultiLiveView] Slot $slotIndex: Stream opened successfully');
          }
        } catch (e) {
          print(
              '[MultiLiveView] Slot $slotIndex: Error opening stream for camera ${camera.name}: $e');
          if (mounted) {
            setState(() {
              _errorStates[slotIndex] = true;
              _errorMessages[slotIndex] = 'Bağlantı hatası: $e';
              _loadingStates[slotIndex] = false;
            });
          }
        }
      } else {
        // Handle no URL available
        print(
            '[MultiLiveView] Slot $slotIndex: No RTSP URL for camera ${camera.name}');
        if (mounted) {
          setState(() {
            _errorStates[slotIndex] = true;
            _errorMessages[slotIndex] = 'RTSP URL bulunamadı';
            _loadingStates[slotIndex] = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    // Dispose all players
    for (final player in _players) {
      player.dispose();
    }

    super.dispose();
  }

  // Get filtered cameras based on search and filter
  List<Camera> _getFilteredCameras() {
    var filtered = _availableCameras.where((camera) {
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = camera.name.toLowerCase().contains(query);
        final matchesMac = camera.mac.toLowerCase().contains(query);
        final matchesIp = camera.ip.toLowerCase().contains(query);
        if (!matchesName && !matchesMac && !matchesIp) {
          return false;
        }
      }

      // Apply device/distribute filter
      if (_selectedDeviceFilter == 'distributed') {
        return camera.distribute;
      } else if (_selectedDeviceFilter == 'not_distributed') {
        return !camera.distribute;
      } else if (_selectedDeviceFilter != 'all') {
        // Filter by specific device MAC
        return camera.currentDevices.containsKey(_selectedDeviceFilter);
      }

      return true;
    }).toList();

    return filtered;
  }

  // Get unique device MACs from all cameras
  Set<String> _getUniqueDeviceMacs() {
    final deviceMacs = <String>{};
    for (final camera in _availableCameras) {
      for (final deviceMac in camera.currentDevices.keys) {
        if (deviceMac.isNotEmpty) {
          deviceMacs.add(deviceMac);
        }
      }
    }
    return deviceMacs;
  }

  // Group cameras by camera groups (like cameras screen by group view)
  Map<String, List<Camera>> _groupCamerasByCameraGroup(List<Camera> cameras) {
    final cameraProvider =
        Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    final cameraGroups = cameraProvider.cameraGroupsList;
    final grouped = <String, List<Camera>>{};
    final assignedCameraIds = <String>{};

    // Group by camera groups
    if (cameraGroups.isNotEmpty) {
      for (final group in cameraGroups) {
        final camerasInGroup = cameraProvider.getCamerasInGroup(group.name);
        // Filter by the cameras list passed in
        final filteredCameras = camerasInGroup
            .where((camera) => cameras.any((c) => c.mac == camera.mac))
            .toList();

        if (filteredCameras.isNotEmpty) {
          grouped[group.name] = filteredCameras;
          for (final camera in filteredCameras) {
            assignedCameraIds.add(camera.id);
          }
        }
      }
    }

    // Find ungrouped cameras
    final ungroupedCameras =
        cameras.where((camera) => !assignedCameraIds.contains(camera.id)).toList();
    if (ungroupedCameras.isNotEmpty) {
      grouped['Grupsuz Kameralar'] = ungroupedCameras;
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final theme = Theme.of(context);
    final cameraProvider = Provider.of<CameraDevicesProviderOptimized>(context);
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context);

    // Watch for layout changes (but don't update in didChangeDependencies)
    if (layoutProvider.currentLayout != null &&
        layoutProvider.currentLayout!.id != _currentLayout.id) {
      _currentLayout = layoutProvider.currentLayout!;
      _gridColumns = _currentLayout.columns;
      _updateGridColumnsBasedOnScreenSize();
    }

    // Check for new cameras (but don't reload existing ones)
    if (_availableCameras.isEmpty && cameraProvider.cameras.isNotEmpty) {
      _availableCameras = cameraProvider.cameras;
      _loadCamerasForCurrentPage();
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Çoklu Canlı İzleme', style: theme.textTheme.headlineSmall),
        backgroundColor: theme.appBarTheme.backgroundColor,
        actions: [
          IconButton(
            icon: Icon(_showCameraSelector ? Icons.grid_view : Icons.list),
            tooltip: _showCameraSelector ? 'Grid Görünümü' : 'Kamera Listesi',
            onPressed: () {
              setState(() {
                _showCameraSelector = !_showCameraSelector;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: () {
              _loadCamerasForCurrentPage();
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Camera selector panel
          if (_showCameraSelector)
            Container(
              width: 320,
              color: AppTheme.darkSurface,
              child: _buildCameraSelectorPanel(),
            ),
          // Main video grid
          Expanded(
            child: Container(
              color: Colors.black,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double availableWidth = constraints.maxWidth;
                  final double availableHeight = constraints.maxHeight;

                  // Calculate how many rows we need based on columns
                  final int rows = (maxCamerasPerPage / _gridColumns).ceil();

                  // Calculate item size to fill the available space exactly
                  final double itemWidth = availableWidth / _gridColumns;
                  final double itemHeight = availableHeight / rows;

                  // Print slot coordinates (x1,y1,x2,y2) for each slot
                  for (int i = 0; i < maxCamerasPerPage; i++) {
                    // Calculate the grid position (row, column)
                    final int row = i ~/ _gridColumns;
                    final int column = i % _gridColumns;

                    // Calculate coordinates based on layout - sağ alt köşe (0,0) kabul edilerek
                    // Bu durumda sol üst köşe (width, height) olur ve değerler negatif olur

                    // Sağ alt köşeden (0,0) hesaplanan koordinatlar
                    final double rightBottomX1 =
                        ((_gridColumns - column - 1) * itemWidth);
                    final double rightBottomY1 =
                        ((rows - row - 1) * itemHeight);
                    final double rightBottomX2 = rightBottomX1 - itemWidth;
                    final double rightBottomY2 = rightBottomY1 - itemHeight;

                    // Ekranda gerçek piksel koordinatları (sol üst köşe)
                    final double x1 = column * itemWidth;
                    final double y1 = row * itemHeight;
                    final double x2 = x1 + itemWidth;
                    final double y2 = y1 + itemHeight;

                    // Print sağ alt köşeye göre hesaplanan koordinatlar
                    print(
                        'FSAAAA FSAAAA FSAAAA FSAAAA  Slot ${i + 1} (index $i):');
                    print(
                        '  Sağ alt köşeden (0,0) koordinatlar: x1=$rightBottomX1, y1=$rightBottomY1, x2=$rightBottomX2, y2=$rightBottomY2');
                    print(
                        '  Karşılaştırma için Sol üst köşeden koordinatlar: x1=$x1, y1=$y1, x2=$x2, y2=$y2');
                  }

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridColumns,
                      childAspectRatio: itemWidth / itemHeight,
                      crossAxisSpacing: 0,
                      mainAxisSpacing: 0,
                    ),
                    itemCount: maxCamerasPerPage,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final camera = index < _selectedCameras.length
                          ? _selectedCameras[index]
                          : null;

                      if (camera != null) {
                        // Tüm kameraları göster, bağlantı durumuna bakılmaksızın
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // Video player - no controls for live RTSP stream
                            ClipRect(
                              child: index < _controllers.length
                                  ? RepaintBoundary(
                                      child: Video(
                                        controller: _controllers[index],
                                        fit: BoxFit.cover,
                                        controls:
                                            null, // No controls for live RTSP
                                      ),
                                    )
                                  : const Center(
                                      child: Text('No player available')),
                            ),

                            // Loading indicator
                            if (_loadingStates[index])
                              const Center(
                                child: CircularProgressIndicator(),
                              ),

                            // Error indicator with message
                            if (_errorStates[index])
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.videocam_off,
                                          color: Colors.red, size: 32),
                                      const SizedBox(height: 8),
                                      Text(
                                        _errorMessages[index].isNotEmpty
                                            ? _errorMessages[index]
                                            : 'Stream Hatası',
                                        style: const TextStyle(
                                            color: Colors.red, fontSize: 11),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Camera name overlay
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  camera.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),

                            // Camera status overlay
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (camera.recording)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.fiber_manual_record,
                                              color: Colors.white, size: 8),
                                          SizedBox(width: 2),
                                          Text(
                                            'REC',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'LIVE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Make the entire cell tappable
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/live-view',
                                    arguments: camera,
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Show empty slot
                        return Container(
                          color: Colors.black38,
                          child: const Center(
                            child: Text(
                              'Kamera Yok',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSelectorPanel() {
    final filteredCameras = _getFilteredCameras();
    final groupedCameras = _groupCamerasByCameraGroup(filteredCameras);
    final deviceMacs = _getUniqueDeviceMacs();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Kamera ara...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.grey.shade800,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 14),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _buildFilterChip('Tümü', 'all'),
              const SizedBox(width: 4),
              _buildFilterChip('Dağıtılan', 'distributed', icon: Icons.share),
              const SizedBox(width: 4),
              _buildFilterChip('Dağıtılmayan', 'not_distributed',
                  icon: Icons.block),
              const SizedBox(width: 4),
              ...deviceMacs.map((mac) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _buildFilterChip(
                      mac.substring(mac.length - 5), // Show last 5 chars of MAC
                      mac,
                      icon: Icons.router,
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Camera count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                '${filteredCameras.length} kamera',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${_selectedCameras.where((c) => c != null).length}/$maxCamerasPerPage seçili',
                style: TextStyle(color: AppTheme.primaryOrange, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Camera list grouped by camera groups
        Expanded(
          child: ListView.builder(
            itemCount: groupedCameras.length,
            itemBuilder: (context, groupIndex) {
              final groupName = groupedCameras.keys.elementAt(groupIndex);
              final cameras = groupedCameras[groupName]!;

              return ExpansionTile(
                title: Row(
                  children: [
                    Icon(
                      groupName == 'Grupsuz Kameralar'
                          ? Icons.videocam_off_outlined
                          : Icons.group_work,
                      size: 18,
                      color: groupName == 'Grupsuz Kameralar'
                          ? Colors.grey
                          : AppTheme.primaryOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        groupName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${cameras.length}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                initiallyExpanded: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                childrenPadding: EdgeInsets.zero,
                children: cameras
                    .map((camera) => _buildCameraListItem(camera))
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, {IconData? icon}) {
    final isSelected = _selectedDeviceFilter == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 14, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.white : Colors.grey.shade300)),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedDeviceFilter = selected ? value : 'all';
        });
      },
      selectedColor: AppTheme.primaryOrange,
      backgroundColor: Colors.grey.shade800,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildCameraListItem(Camera camera) {
    final isSelected = _selectedCameras.contains(camera);
    final slotIndex = _selectedCameras.indexOf(camera);
    final deviceInfo = camera.currentDevices.isNotEmpty
        ? camera.currentDevices.values.first
        : null;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryOrange.withOpacity(0.2)
              : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppTheme.primaryOrange, width: 2)
              : null,
        ),
        child: Center(
          child: isSelected
              ? Text(
                  '${slotIndex + 1}',
                  style: const TextStyle(
                    color: AppTheme.primaryOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                )
              : Icon(
                  Icons.videocam,
                  color: camera.connected ? Colors.green : Colors.grey,
                  size: 20,
                ),
        ),
      ),
      title: Text(
        camera.displayName,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            camera.ip.isNotEmpty ? camera.ip : camera.mac,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          Row(
            children: [
              // Recording badge
              if (camera.recording)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text('REC',
                      style: TextStyle(fontSize: 9, color: Colors.white)),
                ),
              // Distribute badge
              if (camera.distribute)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.share, size: 9, color: Colors.white),
                      SizedBox(width: 2),
                      Text('DAĞ',
                          style: TextStyle(fontSize: 9, color: Colors.white)),
                    ],
                  ),
                ),
              // Device info
              if (deviceInfo != null)
                Expanded(
                  child: Text(
                    deviceInfo.deviceIp,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Connection status
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: camera.connected ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          // Add/Remove button
          IconButton(
            icon: Icon(
              isSelected ? Icons.remove_circle : Icons.add_circle,
              color: isSelected ? Colors.red : Colors.green,
              size: 24,
            ),
            onPressed: () {
              setState(() {
                if (isSelected) {
                  // Remove from slot
                  final index = _selectedCameras.indexOf(camera);
                  if (index != -1) {
                    _selectedCameras[index] = null;
                    _players[index].stop();
                    _errorStates[index] = false;
                    _errorMessages[index] = '';
                  }
                } else {
                  // Find first empty slot
                  final emptyIndex = _selectedCameras.indexOf(null);
                  if (emptyIndex != -1) {
                    _selectedCameras[emptyIndex] = camera;
                    _streamCamera(emptyIndex, camera);
                  }
                }
              });
            },
          ),
        ],
      ),
      onTap: () {
        // Toggle selection on tap
        setState(() {
          if (isSelected) {
            final index = _selectedCameras.indexOf(camera);
            if (index != -1) {
              _selectedCameras[index] = null;
              _players[index].stop();
              _errorStates[index] = false;
              _errorMessages[index] = '';
            }
          } else {
            final emptyIndex = _selectedCameras.indexOf(null);
            if (emptyIndex != -1) {
              _selectedCameras[emptyIndex] = camera;
              _streamCamera(emptyIndex, camera);
            }
          }
        });
      },
    );
  }
}
