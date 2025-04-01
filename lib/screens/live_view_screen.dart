import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/camera_grid_item.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/desktop_menu.dart';
import '../widgets/mobile_menu.dart';
import '../widgets/status_indicator.dart';

class LiveViewScreen extends StatefulWidget {
  const LiveViewScreen({Key? key}) : super(key: key);

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> {
  bool _isMenuExpanded = true;
  String _selectedView = 'Grid View';
  String _selectedGroup = 'All Cameras';
  int _selectedLayoutIndex = 2; // 4 cameras by default
  
  final List<String> _layoutOptions = ['1 Camera', '2x2 Grid', '3x3 Grid', '4x4 Grid'];
  final List<String> _viewOptions = ['Grid View', 'Single View', 'Custom View'];
  final List<String> _groupOptions = ['All Cameras', 'Front Entrance', 'Parking', 'Internal', 'Back Entrance'];
  
  void _toggleMenu() {
    setState(() {
      _isMenuExpanded = !_isMenuExpanded;
    });
  }
  
  void _navigate(String route) {
    Navigator.pushReplacementNamed(context, route);
  }
  
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Live View',
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: () {},
            tooltip: 'Fullscreen',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {},
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8.0),
        ],
      ),
      drawer: isMobile
          ? MobileDrawer(
              currentRoute: '/live_view',
              onNavigate: _navigate,
            )
          : null,
      bottomNavigationBar: isMobile
          ? MobileMenu(
              currentRoute: '/live_view',
              onNavigate: _navigate,
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            DesktopMenu(
              currentRoute: '/live_view',
              onNavigate: _navigate,
              isExpanded: _isMenuExpanded,
              onToggleExpand: _toggleMenu,
            ),
          Expanded(
            child: Column(
              children: [
                _buildControlBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildCameraGrid(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF333333),
            width: 1.0,
          ),
        ),
      ),
      child: ResponsiveHelper.isMobile(context)
          ? Column(
              children: [
                _buildDropdownRow(),
                const SizedBox(height: 16.0),
                _buildLayoutSelector(),
              ],
            )
          : Row(
              children: [
                _buildDropdownRow(),
                const Spacer(),
                _buildLayoutSelector(),
              ],
            ),
    );
  }
  
  Widget _buildDropdownRow() {
    return Wrap(
      spacing: 16.0,
      runSpacing: 16.0,
      children: [
        // View Type Dropdown
        DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: DropdownButton<String>(
              value: _selectedView,
              dropdownColor: AppTheme.darkSurface,
              icon: const Icon(Icons.arrow_drop_down),
              items: _viewOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedView = newValue;
                  });
                }
              },
            ),
          ),
        ),
        
        // Camera Group Dropdown
        DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: DropdownButton<String>(
              value: _selectedGroup,
              dropdownColor: AppTheme.darkSurface,
              icon: const Icon(Icons.arrow_drop_down),
              items: _groupOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedGroup = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildLayoutSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Layout:',
          style: TextStyle(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 12.0),
        ToggleButtons(
          borderRadius: BorderRadius.circular(8.0),
          selectedColor: Colors.white,
          fillColor: AppTheme.blueAccent,
          color: AppTheme.textSecondary,
          constraints: const BoxConstraints(minWidth: 44.0, minHeight: 36.0),
          isSelected: List.generate(
            _layoutOptions.length,
            (index) => index == _selectedLayoutIndex,
          ),
          onPressed: (index) {
            setState(() {
              _selectedLayoutIndex = index;
            });
          },
          children: const [
            Icon(Icons.fullscreen),
            Icon(Icons.grid_view),
            Icon(Icons.dashboard),
            Icon(Icons.apps),
          ],
        ),
      ],
    );
  }
  
  Widget _buildCameraGrid() {
    final crossAxisCount = _getCrossAxisCount();
    
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 16 / 10, // Approximate aspect ratio for cameras
      ),
      itemCount: _getCameraCount(),
      itemBuilder: (context, index) {
        // Alternate between different statuses for demo purposes
        final status = index % 3 == 0
            ? DeviceStatus.online
            : index % 3 == 1
                ? DeviceStatus.warning
                : DeviceStatus.offline;
                
        return CameraGridItem(
          name: 'Camera ${index + 1}',
          status: status,
          resolution: '1080p',
          isSelected: index == 0, // First camera is selected
          onTap: () {
            // Handle camera selection
          },
        );
      },
    );
  }
  
  int _getCrossAxisCount() {
    switch (_selectedLayoutIndex) {
      case 0: // Single camera
        return 1;
      case 1: // 2x2 grid
        return 2;
      case 2: // 3x3 grid
        return 3;
      case 3: // 4x4 grid
        return 4;
      default:
        return 2;
    }
  }
  
  int _getCameraCount() {
    switch (_selectedLayoutIndex) {
      case 0: // Single camera
        return 1;
      case 1: // 2x2 grid
        return 4;
      case 2: // 3x3 grid
        return 9;
      case 3: // 4x4 grid
        return 16;
      default:
        return 4;
    }
  }
}
