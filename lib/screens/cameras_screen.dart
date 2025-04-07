import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_devices_provider.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import 'live_view_screen.dart';

class CamerasScreen extends StatefulWidget {
  const CamerasScreen({Key? key}) : super(key: key);

  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> with SingleTickerProviderStateMixin {
  Camera? selectedCamera;
  bool isDetailViewExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Animation controller for expanding/collapsing the detail panel
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access the camera devices provider
    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context);
    final allCameras = cameraDevicesProvider.getAllCameras();
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cameras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh camera list
              cameraDevicesProvider.refreshDevices();
            },
          ),
        ],
      ),
      body: allCameras.isEmpty 
          ? _buildEmptyState()
          : isDesktop
              ? _buildDesktopLayout(allCameras)
              : _buildMobileLayout(allCameras),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_off,
            size: 80,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            'No Cameras Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to devices to discover cameras',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            onPressed: () {
              // Refresh camera list
              Provider.of<CameraDevicesProvider>(context, listen: false)
                .refreshDevices();
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildDesktopLayout(List<Camera> cameras) {
    return Row(
      children: [
        // Camera list (1/3 of the screen width)
        SizedBox(
          width: 350,
          child: _buildCameraList(cameras),
        ),
        
        // Vertical divider
        VerticalDivider(
          width: 1,
          color: Colors.grey.shade800,
        ),
        
        // Detail view (2/3 of the screen width)
        Expanded(
          child: selectedCamera != null
              ? _buildCameraDetail(selectedCamera!)
              : _buildNoSelectionView(),
        ),
      ],
    );
  }
  
  Widget _buildMobileLayout(List<Camera> cameras) {
    // For mobile, we'll use a collapsible bottom sheet for details
    return Stack(
      children: [
        // Camera list
        _buildCameraList(cameras),
        
        // Animated detail panel from bottom
        if (selectedCamera != null) ...[
          // Semi-transparent overlay when panel is expanded
          if (isDetailViewExpanded)
            GestureDetector(
              onTap: _toggleDetailPanel,
              child: AnimatedOpacity(
                opacity: isDetailViewExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  color: Colors.black,
                ),
              ),
            ),
          
          // Bottom sheet with camera details
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                return Container(
                  height: isDetailViewExpanded
                      ? MediaQuery.of(context).size.height * 0.7 * _expandAnimation.value
                      : 72 + (8 * _expandAnimation.value),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16 * _expandAnimation.value),
                      topRight: Radius.circular(16 * _expandAnimation.value),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2 * _expandAnimation.value),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle for expanding/collapsing
                  GestureDetector(
                    onTap: _toggleDetailPanel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade700,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Camera name and view button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedCamera!.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('View'),
                          onPressed: () => _openLiveView(selectedCamera!),
                        ),
                      ],
                    ),
                  ),
                  
                  // Only show details if expanded
                  if (isDetailViewExpanded) ...[
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildCameraDetailContent(selectedCamera!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  void _toggleDetailPanel() {
    setState(() {
      isDetailViewExpanded = !isDetailViewExpanded;
      if (isDetailViewExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }
  
  Widget _buildCameraList(List<Camera> cameras) {
    return Column(
      children: [
        // Search and filter bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search cameras...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppTheme.darkInput,
            ),
            onChanged: (value) {
              // TODO: Implement search filtering
            },
          ),
        ),
        
        // Camera count indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${cameras.length} Cameras',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // TODO: Add filter button here if needed
            ],
          ),
        ),
        
        // Camera list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cameras.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final camera = cameras[index];
              return _buildCameraListItem(camera);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildCameraListItem(Camera camera) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            selectedCamera = camera;
            if (!isDetailViewExpanded && !ResponsiveHelper.isDesktop(context)) {
              _toggleDetailPanel();
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selectedCamera?.name == camera.name
                ? AppTheme.accentColor.withOpacity(0.1)
                : AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selectedCamera?.name == camera.name
                  ? AppTheme.accentColor
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Camera icon or thumbnail
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.videocam,
                  size: 30,
                  color: selectedCamera?.name == camera.name
                      ? AppTheme.accentColor
                      : Colors.grey,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Camera details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      camera.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: selectedCamera?.name == camera.name
                            ? AppTheme.accentColor
                            : Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IP: ${camera.ip}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Brand: ${camera.brand.isNotEmpty ? camera.brand : "Unknown"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // View button
              IconButton(
                icon: const Icon(Icons.play_circle_outline),
                color: AppTheme.accentColor,
                onPressed: () => _openLiveView(camera),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _openLiveView(Camera camera) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveViewScreen(camera: camera),
      ),
    );
  }
  
  Widget _buildNoSelectionView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam,
            size: 80,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 16),
          const Text(
            'Select a camera to view details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCameraDetail(Camera camera) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Camera header with name and actions
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(
                Icons.videocam,
                size: 36,
                color: AppTheme.accentColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      camera.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'IP: ${camera.ip}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('View Live'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: AppTheme.accentColor,
                ),
                onPressed: () => _openLiveView(camera),
              ),
            ],
          ),
        ),
        
        const Divider(height: 1),
        
        // Camera details in scrollable area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildCameraDetailContent(camera),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraDetailContent(Camera camera) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Camera information section
        _buildDetailSection(
          title: 'Camera Information',
          icon: Icons.info_outline,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Name', camera.name),
              _buildDetailRow('IP Address', camera.ip),
              _buildDetailRow('Brand', camera.brand.isNotEmpty ? camera.brand : 'Unknown'),
              _buildDetailRow('Model', camera.model.isNotEmpty ? camera.model : 'Unknown'),
              _buildDetailRow('Manufacturer', camera.manufacturer.isNotEmpty ? camera.manufacturer : 'Unknown'),
              _buildDetailRow('Hardware ID', camera.hw),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Stream details section
        _buildDetailSection(
          title: 'Stream Information',
          icon: Icons.stream,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Main Stream', camera.mediaUri),
              _buildDetailRow('Main Resolution', '${camera.mediaWidth}x${camera.mediaHeight}'),
              _buildDetailRow('Sub Stream', camera.subUri),
              _buildDetailRow('Sub Resolution', '${camera.subWidth}x${camera.subHeight}'),
              _buildDetailRow('Sub Codec', camera.subCodec),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Authentication details section
        _buildDetailSection(
          title: 'Authentication',
          icon: Icons.lock_outline,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Username', camera.username),
              _buildDetailRow('Password', '********'),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Additional information section
        _buildDetailSection(
          title: 'Additional Information',
          icon: Icons.more_horiz,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Web Services', camera.xAddrs),
              _buildDetailRow('Record URI', camera.recordUri),
              _buildDetailRow('Record Resolution', '${camera.recordWidth}x${camera.recordHeight}'),
              _buildDetailRow('Remote URI', camera.remoteUri),
              _buildDetailRow('Remote Resolution', '${camera.remoteWidth}x${camera.remoteHeight}'),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: AppTheme.accentColor,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Section content
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade800,
              width: 1,
            ),
          ),
          child: content,
        ),
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
