import 'package:flutter/material.dart';
import '../models/camera_device.dart';
import '../providers/multi_camera_view_provider.dart';
import '../theme/app_theme.dart';

class CameraSelectorPanel extends StatefulWidget {
  final int cameraPosition;
  final List<Camera> allCameras;
  final Map<int, int> currentAssignments;
  final MultiCameraViewProvider provider;
  final int selectedPageIndex;
  final ScrollController scrollController;

  const CameraSelectorPanel({
    Key? key,
    required this.cameraPosition,
    required this.allCameras,
    required this.currentAssignments,
    required this.provider,
    required this.selectedPageIndex,
    required this.scrollController,
  }) : super(key: key);

  @override
  State<CameraSelectorPanel> createState() => _CameraSelectorPanelState();
}

class _CameraSelectorPanelState extends State<CameraSelectorPanel> {
  late String searchText;
  late List<Camera> filteredCameras;
  late String selectedHardwareType;
  late String selectedResolution;
  late String selectedBrand;
  late bool showOnline;
  late bool showOffline;
  late final TextEditingController searchController;

  @override
  void initState() {
    super.initState();
    searchText = '';
    filteredCameras = widget.allCameras;
    selectedHardwareType = '';
    selectedResolution = '';
    selectedBrand = '';
    showOnline = true;
    showOffline = true;
    searchController = TextEditingController();
    
    // Apply initial filtering
    _applyFilters();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      // Start with all cameras
      List<Camera> tempFilteredCameras = widget.allCameras;
      
      // Filter by connection status
      if (!(showOnline && showOffline)) {
        if (showOnline && !showOffline) {
          tempFilteredCameras = tempFilteredCameras.where((camera) => camera.connected).toList();
        } else if (!showOnline && showOffline) {
          tempFilteredCameras = tempFilteredCameras.where((camera) => !camera.connected).toList();
        }
      }
      
      // Apply text search
      if (searchText.isNotEmpty) {
        tempFilteredCameras = tempFilteredCameras.where((camera) {
          return camera.name.toLowerCase().contains(searchText.toLowerCase()) ||
                camera.brand.toLowerCase().contains(searchText.toLowerCase()) ||
                camera.ip.toLowerCase().contains(searchText.toLowerCase());
        }).toList();
      }
      
      // Apply hardware type filter
      if (selectedHardwareType.isNotEmpty) {
        tempFilteredCameras = tempFilteredCameras.where((camera) => 
          camera.hw.toLowerCase() == selectedHardwareType.toLowerCase()).toList();
      }
      
      // Apply resolution filter
      if (selectedResolution.isNotEmpty) {
        tempFilteredCameras = tempFilteredCameras.where((camera) {
          String cameraResolution = '${camera.recordWidth}x${camera.recordHeight}';
          return cameraResolution == selectedResolution;
        }).toList();
      }
      
      // Apply brand filter
      if (selectedBrand.isNotEmpty) {
        tempFilteredCameras = tempFilteredCameras.where((camera) => 
          camera.brand.toLowerCase() == selectedBrand.toLowerCase()).toList();
      }
      
      filteredCameras = tempFilteredCameras;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentAssignment = widget.currentAssignments[widget.cameraPosition] ?? 0;
    
    // Get unique hardware types for filtering
    final List<String> uniqueHardwareTypes = widget.allCameras
        .map((camera) => camera.hw)
        .where((hw) => hw.isNotEmpty)
        .toSet()
        .toList();
    
    // Get unique resolutions for filtering
    final List<String> uniqueResolutions = widget.allCameras
        .map((camera) => '${camera.recordWidth}x${camera.recordHeight}')
        .where((res) => res != '0x0')
        .toSet()
        .toList();
    
    // Get unique brands for filtering
    final List<String> uniqueBrands = widget.allCameras
        .map((camera) => camera.brand)
        .where((brand) => brand.isNotEmpty)
        .toSet()
        .toList();
    
    return Column(
      children: [
        // Header with filtering options
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Camera for Position ${widget.cameraPosition}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Search box for filtering cameras
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search cameras...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchText.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              setState(() {
                                searchText = '';
                              });
                              _applyFilters();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchText = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              
              // Online/Offline filter chips
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Text('Status: ', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Online'),
                      selected: showOnline,
                      onSelected: (selected) {
                        setState(() {
                          showOnline = selected;
                          // If both would be false, keep the other one true
                          if (!selected && !showOffline) {
                            showOffline = true;
                          }
                        });
                        _applyFilters();
                      },
                      backgroundColor: Colors.grey.shade800,
                      selectedColor: Colors.green.withOpacity(0.2),
                      checkmarkColor: Colors.green,
                      avatar: Icon(Icons.check_circle, 
                        color: showOnline ? Colors.green : Colors.grey, 
                        size: 16
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Offline'),
                      selected: showOffline,
                      onSelected: (selected) {
                        setState(() {
                          showOffline = selected;
                          // If both would be false, keep the other one true
                          if (!selected && !showOnline) {
                            showOnline = true;
                          }
                        });
                        _applyFilters();
                      },
                      backgroundColor: Colors.grey.shade800,
                      selectedColor: Colors.red.withOpacity(0.2),
                      checkmarkColor: Colors.red,
                      avatar: Icon(Icons.cancel, 
                        color: showOffline ? Colors.red : Colors.grey, 
                        size: 16
                      ),
                    ),
                    const Spacer(),
                    // Results count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade700),
                      ),
                      child: Text(
                        '${filteredCameras.length} cameras',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Brand filters
              if (uniqueBrands.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Brand:', style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              label: const Text('All'),
                              selected: selectedBrand.isEmpty,
                              onSelected: (_) {
                                setState(() {
                                  selectedBrand = '';
                                });
                                _applyFilters();
                              },
                              backgroundColor: Colors.grey.shade800,
                              selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                            ),
                            const SizedBox(width: 8),
                            ...uniqueBrands.map((brand) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(brand),
                                selected: selectedBrand == brand,
                                onSelected: (_) {
                                  setState(() {
                                    selectedBrand = selectedBrand == brand ? '' : brand;
                                  });
                                  _applyFilters();
                                },
                                backgroundColor: Colors.grey.shade800,
                                selectedColor: Colors.amber.withOpacity(0.2),
                                checkmarkColor: Colors.amber,
                              ),
                            )).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Hardware type filters
              if (uniqueHardwareTypes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hardware Type:', style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              label: const Text('All'),
                              selected: selectedHardwareType.isEmpty,
                              onSelected: (_) {
                                setState(() {
                                  selectedHardwareType = '';
                                });
                                _applyFilters();
                              },
                              backgroundColor: Colors.grey.shade800,
                              selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                            ),
                            const SizedBox(width: 8),
                            ...uniqueHardwareTypes.map((hw) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(hw),
                                selected: selectedHardwareType == hw,
                                onSelected: (_) {
                                  setState(() {
                                    selectedHardwareType = selectedHardwareType == hw ? '' : hw;
                                  });
                                  _applyFilters();
                                },
                                backgroundColor: Colors.grey.shade800,
                                selectedColor: Colors.blue.withOpacity(0.2),
                                checkmarkColor: Colors.blue,
                              ),
                            )).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Resolution filters
              if (uniqueResolutions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Resolution:', style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              label: const Text('All'),
                              selected: selectedResolution.isEmpty,
                              onSelected: (_) {
                                setState(() {
                                  selectedResolution = '';
                                });
                                _applyFilters();
                              },
                              backgroundColor: Colors.grey.shade800,
                              selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                            ),
                            const SizedBox(width: 8),
                            ...uniqueResolutions.map((res) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(res),
                                selected: selectedResolution == res,
                                onSelected: (_) {
                                  setState(() {
                                    selectedResolution = selectedResolution == res ? '' : res;
                                  });
                                  _applyFilters();
                                },
                                backgroundColor: Colors.grey.shade800,
                                selectedColor: Colors.purple.withOpacity(0.2),
                                checkmarkColor: Colors.purple,
                              ),
                            )).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        
        // Camera list
        Expanded(
          child: filteredCameras.isEmpty && searchText.isEmpty && selectedBrand.isEmpty && 
                 selectedHardwareType.isEmpty && selectedResolution.isEmpty && showOnline && showOffline
              ? _buildNoCamerasView()
              : filteredCameras.isEmpty
                  ? _buildNoResultsView()
                  : ListView.builder(
                      controller: widget.scrollController,
                      itemCount: filteredCameras.length + 1, // +1 for "No Camera" option
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // "No Camera" option
                          return ListTile(
                            title: const Text('No Camera'),
                            leading: const Icon(Icons.videocam_off),
                            selected: currentAssignment == 0,
                            onTap: () {
                              // Update the assignment in the provider
                              final newAssignments = Map<int, int>.from(widget.currentAssignments);
                              newAssignments[widget.cameraPosition] = 0;
                              widget.provider.setCameraAssignments(widget.selectedPageIndex, newAssignments);
                              
                              // Close the bottom sheet
                              Navigator.pop(context);
                            },
                          );
                        } else {
                          // Camera option
                          final camera = filteredCameras[index - 1];
                          final cameraIndex = widget.allCameras.indexOf(camera) + 1; // 1-based index in the original list
                          
                          return ListTile(
                            title: Text(camera.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${camera.brand} • ${camera.ip}'),
                                if (camera.hw.isNotEmpty || camera.recordWidth > 0)
                                  Text(
                                    '${camera.hw.isNotEmpty ? camera.hw : ""} ${camera.recordWidth > 0 ? "• ${camera.recordWidth}x${camera.recordHeight}" : ""}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                  ),
                              ],
                            ),
                            isThreeLine: camera.hw.isNotEmpty || camera.recordWidth > 0,
                            leading: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.videocam,
                                  color: camera.connected ? Colors.green : Colors.red,
                                  size: 28,
                                ),
                                if (widget.currentAssignments.containsValue(cameraIndex))
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.black, width: 1),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            selected: currentAssignment == cameraIndex,
                            trailing: widget.currentAssignments.containsValue(cameraIndex) 
                              ? Text(
                                  'Pos ${widget.currentAssignments.entries.firstWhere((e) => e.value == cameraIndex).key}',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                            onTap: () {
                              // Update the assignment in the provider
                              final newAssignments = Map<int, int>.from(widget.currentAssignments);
                              newAssignments[widget.cameraPosition] = cameraIndex;
                              widget.provider.setCameraAssignments(widget.selectedPageIndex, newAssignments);
                              
                              // Close the bottom sheet
                              Navigator.pop(context);
                            },
                          );
                        }
                      },
                    ),
        ),
      ],
    );
  }
  
  Widget _buildNoCamerasView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off,
            size: 64,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 16),
          const Text(
            'No cameras available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please add cameras to your system first',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNoResultsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 16),
          const Text(
            'No cameras match your filters',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or filter criteria',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear All Filters'),
            onPressed: () {
              searchController.clear();
              setState(() {
                searchText = '';
                selectedBrand = '';
                selectedHardwareType = '';
                selectedResolution = '';
                showOnline = true;
                showOffline = true;
              });
              _applyFilters();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
