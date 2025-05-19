import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../models/camera_layout_config.dart';
import '../providers/multi_camera_view_provider.dart';
import '../providers/camera_devices_provider.dart';
import '../theme/app_theme.dart';
import 'camera_selector_panel.dart';

class CameraLayoutAssignmentScreen extends StatefulWidget {
  const CameraLayoutAssignmentScreen({Key? key}) : super(key: key);

  @override
  State<CameraLayoutAssignmentScreen> createState() => _CameraLayoutAssignmentScreenState();
}

class _CameraLayoutAssignmentScreenState extends State<CameraLayoutAssignmentScreen> {
  int _selectedLayoutCode = 5; // Default to 2x2 layout (code 5)
  int _selectedPageIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<MultiCameraViewProvider>(context, listen: false);
      setState(() {
        _selectedLayoutCode = provider.pageLayouts[provider.activePageIndex];
        _selectedPageIndex = provider.activePageIndex;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Layout Assignment'),
        backgroundColor: AppTheme.darkBackground,
        actions: [
          // Presets button
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Manage Presets',
            onPressed: () {
              final provider = Provider.of<MultiCameraViewProvider>(context, listen: false);
              _showPresetManager(context, provider);
            },
          ),
          // Save button
          TextButton.icon(
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
            onPressed: () {
              final provider = Provider.of<MultiCameraViewProvider>(context, listen: false);
              
              // Apply changes to the provider
              provider.setActivePageLayout(_selectedLayoutCode);
              
              // Return to previous screen
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Layout assignments saved')),
              );
            },
          ),
        ],
      ),
      body: Consumer2<MultiCameraViewProvider, CameraDevicesProvider>(
        builder: (context, layoutProvider, cameraProvider, child) {
          final allCameras = cameraProvider.cameras;
          
          // Update the selectedCameras list to have the same length as the layout
          final selectedLayout = layoutProvider.layouts.firstWhere(
            (layout) => layout.layoutCode == _selectedLayoutCode,
            orElse: () => layoutProvider.layouts.first,
          );
          
          final Map<int, int> currentAssignments = Map.from(
            _selectedPageIndex < layoutProvider.pageLayouts.length 
              ? layoutProvider.cameraAssignments(_selectedPageIndex) 
              : {}
          );
          
          return Column(
            children: [
              // Layout selection
              _buildLayoutSelector(layoutProvider.layouts, _selectedLayoutCode),
              
              // Page selection
              _buildPageSelector(layoutProvider.pageLayouts.length, _selectedPageIndex),
              
              // Preview and Assignment area
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Layout preview
                    Expanded(
                      flex: 3,
                      child: _buildLayoutPreview(
                        selectedLayout, 
                        allCameras, 
                        currentAssignments,
                      ),
                    ),
                    
                    // Assignment controls
                    Expanded(
                      flex: 2,
                      child: _buildAssignmentControls(
                        selectedLayout,
                        allCameras,
                        currentAssignments,
                        layoutProvider,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildLayoutSelector(List<CameraLayoutConfig> layouts, int selectedCode) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.grid_view, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Select Layout:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              // Add count indicator to show how many layouts are available
              Text(
                '${layouts.length} layouts available',
                style: TextStyle(
                  fontSize: 12, 
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 110, // Slightly increased fixed height to prevent overflow
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: layouts.length,
              itemBuilder: (context, index) {
                final layout = layouts[index];
                final isSelected = selectedCode == layout.layoutCode;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedLayoutCode = layout.layoutCode;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 90, // Slightly reduced width for better fit
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey.shade600,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        // Add a light background highlighting for selected layout
                        color: isSelected 
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : null,
                        // Add subtle shadow for selected layout
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Layout preview
                          Expanded(
                            child: _buildLayoutPreviewGrid(layout),
                          ),
                          const SizedBox(height: 6),
                          // Layout name
                          Text(
                            'Layout ${layout.layoutCode}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          // Camera count
                          Text(
                            '${layout.maxCameraNumber} cameras',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPageSelector(int pageCount, int selectedIndex) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.view_carousel, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Select Page:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              // Add count indicator to show how many pages are available
              Text(
                '$pageCount pages available',
                style: TextStyle(
                  fontSize: 12, 
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60, // Fixed height for consistent layout
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: pageCount,
              itemBuilder: (context, index) {
                final provider = Provider.of<MultiCameraViewProvider>(context, listen: false);
                final isSelected = selectedIndex == index;
                int? layoutCode = index < provider.pageLayouts.length ? provider.pageLayouts[index] : null;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPageIndex = index;
                        
                        // Update the selected layout when changing pages
                        if (index < provider.pageLayouts.length) {
                          _selectedLayoutCode = provider.pageLayouts[index];
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey.shade800,
                        // Add subtle shadow for selected page
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                )
                              ]
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Page number
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey,
                            ),
                          ),
                          
                          // Layout code indicator (small badge)
                          if (layoutCode != null)
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white 
                                      : AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : Colors.white,
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$layoutCode',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLayoutPreview(
    CameraLayoutConfig layout, 
    List<Camera> allCameras, 
    Map<int, int> assignments
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: AppTheme.primaryColor, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            
            return Stack(
              children: [
                // Background gradient for better appearance
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Colors.black.withOpacity(0.3),
                        AppTheme.darkBackground.withOpacity(0.9),
                      ],
                      radius: 1.0,
                      center: Alignment.center,
                    ),
                  ),
                ),
                
                // Positions
                ...layout.cameraLoc.map((location) {
                  final cameraPosition = location.cameraCode;
                  final cameraIndex = assignments[cameraPosition] ?? 0;
                  
                  // Get the assigned camera if any
                  Camera? camera;
                  if (cameraIndex > 0 && cameraIndex <= allCameras.length) {
                    camera = allCameras[cameraIndex - 1];
                  }
                  
                  // Calculate position and size
                  final double left = location.x1 * width / 100;
                  final double top = location.y1 * height / 100;
                  final double right = location.x2 * width / 100;
                  final double bottom = location.y2 * height / 100;
                  
                  return Positioned(
                    left: left,
                    top: top,
                    width: right - left,
                    height: bottom - top,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: camera != null ? AppTheme.primaryColor : Colors.white30, 
                          width: 1.5
                        ),
                        color: camera != null 
                            ? Colors.black87
                            : Colors.black54,
                      ),
                      child: Stack(
                        children: [
                          // Position indicator with size percentages
                          Positioned(
                            left: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white30),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Position $cameraPosition',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${(location.x2 - location.x1).toStringAsFixed(0)}% × ${(location.y2 - location.y1).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Camera info or empty placeholder
                          Center(
                            child: camera != null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: camera.connected ? Colors.green : Colors.red,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.videocam,
                                          color: camera.connected ? Colors.green : Colors.red,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white24),
                                        ),
                                        child: Text(
                                          camera.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: camera.connected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: camera.connected ? Colors.green : Colors.red,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          camera.connected ? 'Online' : 'Offline',
                                          style: TextStyle(
                                            color: camera.connected ? Colors.green : Colors.red,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.black38,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.grey.shade700),
                                        ),
                                        child: const Icon(
                                          Icons.videocam_off,
                                          color: Colors.grey,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.black38,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade800),
                                        ),
                                        child: const Text(
                                          'No Camera Assigned',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                
                // Layout information overlay
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Layout ${layout.layoutCode}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Max ${layout.maxCameraNumber} cameras',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildLayoutPreviewGrid(CameraLayoutConfig layout) {
    final isSelected = _selectedLayoutCode == layout.layoutCode;
    
    return Container(
      width: 60,
      height: 55,
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? AppTheme.primaryColor
              : Colors.grey.shade700,
          width: isSelected ? 2 : 1,
        ),
        // Add subtle shadow for depth
        boxShadow: isSelected 
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                )
              ] 
            : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          
          return Stack(
            children: [
              // Draw the grid layout based on camera positions
              ...layout.cameraLoc.map((location) {
                final double left = location.x1 * width / 100;
                final double top = location.y1 * height / 100;
                final double right = location.x2 * width / 100;
                final double bottom = location.y2 * height / 100;
                
                return Positioned(
                  left: left,
                  top: top,
                  width: right - left,
                  height: bottom - top,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey.shade500,
                        width: 0.7, // Slightly thicker for better visibility
                      ),
                      // Add subtle fill color for better visualization
                      color: isSelected
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : Colors.black.withOpacity(0.2),
                    ),
                    // Add camera position number
                    child: Center(
                      child: Text(
                        '${location.cameraCode}',
                        style: TextStyle(
                          fontSize: 8,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey.shade400,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildAssignmentControls(
    CameraLayoutConfig layout,
    List<Camera> allCameras,
    Map<int, int> currentAssignments,
    MultiCameraViewProvider provider
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade800),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with camera count
          Row(
            children: [
              Icon(Icons.settings_input_component, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Camera Assignments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${currentAssignments.values.where((v) => v > 0).length} of ${layout.maxCameraNumber} positions filled',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Page ${_selectedPageIndex + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Auto-assign toggle with explanation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: provider.isAutoAssignmentMode
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: provider.isAutoAssignmentMode
                    ? AppTheme.primaryColor.withOpacity(0.5)
                    : Colors.grey.shade700,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Switch(
                      value: provider.isAutoAssignmentMode,
                      onChanged: (value) {
                        provider.toggleAssignmentMode();
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.isAutoAssignmentMode
                                ? 'Auto Assignment Mode'
                                : 'Manual Assignment Mode',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            provider.isAutoAssignmentMode
                                ? 'Cameras are automatically assigned in order'
                                : 'You can manually assign cameras to positions',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
          
          // Quick tools section
          if (!provider.isAutoAssignmentMode) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Auto Fill'),
                    onPressed: () {
                      // Create a map with automated assignments based on camera order
                      final Map<int, int> autoAssignments = {};
                      
                      int cameraIndex = 1;
                      for (final loc in layout.cameraLoc) {
                        if (cameraIndex <= allCameras.length) {
                          autoAssignments[loc.cameraCode] = cameraIndex;
                          cameraIndex++;
                        } else {
                          autoAssignments[loc.cameraCode] = 0;
                        }
                      }
                      
                      provider.setCameraAssignments(_selectedPageIndex, autoAssignments);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cameras automatically assigned')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear All'),
                    onPressed: () {
                      // Create a map with all positions set to 0 (no camera)
                      final Map<int, int> emptyAssignments = {};
                      for (final loc in layout.cameraLoc) {
                        emptyAssignments[loc.cameraCode] = 0;
                      }
                      
                      provider.setCameraAssignments(_selectedPageIndex, emptyAssignments);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All camera assignments cleared')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Sorting options for automatic assignment
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sort Cameras By:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            provider.autoAssignCamerasBySorting('name');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cameras sorted by name')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Name', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            provider.autoAssignCamerasBySorting('status');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cameras sorted by status')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade800,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Status', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            provider.autoAssignCamerasBySorting('ip');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cameras sorted by IP')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade800,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('IP', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          // Section title for list
          Row(
            children: [
              const Icon(Icons.videocam, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                'Position Assignments',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                'Tap to edit',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Assignment list
          Expanded(
            child: ListView.builder(
              itemCount: layout.cameraLoc.length,
              itemBuilder: (context, index) {
                final location = layout.cameraLoc[index];
                final cameraPosition = location.cameraCode;
                final cameraIndex = currentAssignments[cameraPosition] ?? 0;
                
                // Determine if there's a camera assigned
                bool hasCameraAssigned = cameraIndex > 0 && cameraIndex <= allCameras.length;
                
                // Get camera details if assigned
                Camera? camera;
                if (hasCameraAssigned) {
                  camera = allCameras[cameraIndex - 1];
                }
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: hasCameraAssigned 
                      ? AppTheme.darkBackground 
                      : Colors.grey.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: hasCameraAssigned 
                          ? AppTheme.primaryColor.withOpacity(0.5) 
                          : Colors.grey.shade800,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    title: Text(
                      hasCameraAssigned ? camera!.name : 'No Camera Assigned',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hasCameraAssigned ? Colors.white : Colors.grey,
                      ),
                    ),
                    subtitle: hasCameraAssigned
                        ? Text(
                            '${camera!.brand} • ${camera.connected ? 'Online' : 'Offline'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: camera.connected ? Colors.green : Colors.red,
                            ),
                          )
                        : null,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasCameraAssigned
                            ? (camera!.connected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2))
                            : Colors.grey.withOpacity(0.2),
                        border: Border.all(
                          color: hasCameraAssigned
                              ? (camera!.connected ? Colors.green : Colors.red)
                              : Colors.grey,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$cameraPosition',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: hasCameraAssigned
                                ? (camera!.connected ? Colors.green : Colors.red)
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    trailing: provider.isAutoAssignmentMode
                        ? const Icon(Icons.auto_fix_high, color: Colors.grey)
                        : IconButton(
                            icon: Icon(Icons.edit, color: AppTheme.primaryColor),
                            tooltip: 'Change Camera',
                            onPressed: () {
                              _showCameraSelector(
                                context, 
                                cameraPosition, 
                                allCameras, 
                                currentAssignments,
                                provider,
                              );
                            },
                          ),
                    enabled: !provider.isAutoAssignmentMode,
                    onTap: provider.isAutoAssignmentMode
                        ? null
                        : () {
                            _showCameraSelector(
                              context, 
                              cameraPosition, 
                              allCameras, 
                              currentAssignments,
                              provider,
                            );
                          },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  void _showCameraSelector(
    BuildContext context, 
    int cameraPosition, 
    List<Camera> allCameras,
    Map<int, int> currentAssignments,
    MultiCameraViewProvider provider
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return CameraSelectorPanel(
              cameraPosition: cameraPosition,
              allCameras: allCameras,
              currentAssignments: currentAssignments,
              provider: provider,
              selectedPageIndex: _selectedPageIndex,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }
  
  void _showPresetManager(BuildContext context, MultiCameraViewProvider provider) {
    final TextEditingController presetNameController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      const Icon(Icons.save_alt),
                      const SizedBox(width: 8),
                      const Text(
                        'Camera Assignment Presets',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  
                  // Save new preset section
                  const Text(
                    'Save Current Layout',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: presetNameController,
                          decoration: const InputDecoration(
                            hintText: 'Enter preset name',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          if (presetNameController.text.isNotEmpty) {
                            provider.savePresetWithName(presetNameController.text);
                            presetNameController.clear();
                            setState(() {}); // Refresh the list
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Preset saved successfully')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a preset name')),
                            );
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  
                  // Saved presets list
                  const Text(
                    'Saved Presets',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  provider.presetNames.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No saved presets yet',
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 200,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: provider.presetNames.length,
                            itemBuilder: (context, index) {
                              final presetName = provider.presetNames[index];
                              return ListTile(
                                title: Text(presetName),
                                leading: const Icon(Icons.photo_library),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.play_arrow),
                                      onPressed: () {
                                        provider.loadPreset(presetName);
                                        Navigator.pop(context);
                                        
                                        // Update the UI
                                        setState(() {
                                          _selectedPageIndex = provider.activePageIndex;
                                          _selectedLayoutCode = provider.pageLayouts[provider.activePageIndex];
                                        });
                                        
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Preset "$presetName" loaded')),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Preset'),
                                            content: Text('Are you sure you want to delete "$presetName"?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  provider.deletePreset(presetName);
                                                  Navigator.pop(context);
                                                  setState(() {}); // Refresh the list
                                                  
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Preset "$presetName" deleted')),
                                                  );
                                                },
                                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  provider.loadPreset(presetName);
                                  Navigator.pop(context);
                                  
                                  // Update the UI
                                  setState(() {
                                    _selectedPageIndex = provider.activePageIndex;
                                    _selectedLayoutCode = provider.pageLayouts[provider.activePageIndex];
                                  });
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Preset "$presetName" loaded')),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
