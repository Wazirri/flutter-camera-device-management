import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/desktop_menu.dart';
import '../widgets/device_list_item.dart';
import '../widgets/mobile_menu.dart';
import '../widgets/status_indicator.dart';

class CamerasScreen extends StatefulWidget {
  const CamerasScreen({Key? key}) : super(key: key);

  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  bool _isMenuExpanded = true;
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final List<String> _filterOptions = ['All', 'Online', 'Offline', 'Warning'];
  
  void _toggleMenu() {
    setState(() {
      _isMenuExpanded = !_isMenuExpanded;
    });
  }
  
  void _navigate(String route) {
    Navigator.pushReplacementNamed(context, route);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Cameras',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
            tooltip: 'Add Camera',
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
              currentRoute: '/cameras',
              onNavigate: _navigate,
            )
          : null,
      bottomNavigationBar: isMobile
          ? MobileMenu(
              currentRoute: '/cameras',
              onNavigate: _navigate,
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            DesktopMenu(
              currentRoute: '/cameras',
              onNavigate: _navigate,
              isExpanded: _isMenuExpanded,
              onToggleExpand: _toggleMenu,
            ),
          Expanded(
            child: Column(
              children: [
                _buildFilterBar(),
                Expanded(
                  child: _buildCameraList(),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: isMobile ? FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppTheme.blueAccent,
        child: const Icon(Icons.add),
      ) : null,
    );
  }
  
  Widget _buildFilterBar() {
    final isMobile = ResponsiveHelper.isMobile(context);
    
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
      child: isMobile
          ? Column(
              children: [
                _buildSearchField(),
                const SizedBox(height: 16.0),
                _buildFilterChips(),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildSearchField()),
                const SizedBox(width: 16.0),
                _buildFilterChips(),
              ],
            ),
    );
  }
  
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search cameras...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              )
            : null,
        filled: true,
        fillColor: AppTheme.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }
  
  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8.0,
      children: _filterOptions.map((filter) {
        final isSelected = _selectedFilter == filter;
        return ChoiceChip(
          label: Text(filter),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedFilter = filter;
              });
            }
          },
          selectedColor: AppTheme.blueAccent,
          backgroundColor: AppTheme.darkCard,
        );
      }).toList(),
    );
  }
  
  Widget _buildCameraList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: 12, // Sample data count
        itemBuilder: (context, index) {
          // Sample data with alternating statuses
          DeviceStatus status;
          if (index % 4 == 0) {
            status = DeviceStatus.online;
          } else if (index % 4 == 1) {
            status = DeviceStatus.offline;
          } else if (index % 4 == 2) {
            status = DeviceStatus.warning;
          } else {
            status = DeviceStatus.error;
          }
          
          // Filter based on selected filter
          if (_selectedFilter != 'All') {
            if (_selectedFilter == 'Online' && status != DeviceStatus.online) {
              return const SizedBox.shrink();
            }
            if (_selectedFilter == 'Offline' && status != DeviceStatus.offline) {
              return const SizedBox.shrink();
            }
            if (_selectedFilter == 'Warning' && status != DeviceStatus.warning) {
              return const SizedBox.shrink();
            }
          }
          
          // Sample camera data
          final cameraName = 'Camera ${index + 1}';
          final ipAddress = '192.168.1.${100 + index}';
          final resolution = index % 2 == 0 ? '1080p' : '4K';
          final tags = _getSampleTags(index);
          final group = _getSampleGroup(index);
          
          // Filter based on search query
          if (_searchQuery.isNotEmpty &&
              !cameraName.toLowerCase().contains(_searchQuery.toLowerCase()) &&
              !ipAddress.contains(_searchQuery) &&
              !group.toLowerCase().contains(_searchQuery.toLowerCase())) {
            return const SizedBox.shrink();
          }
          
          return DeviceListItem(
            name: cameraName,
            ip: ipAddress,
            status: status,
            resolution: resolution,
            tags: tags,
            group: group,
            onTap: () {
              // Handle camera selection
            },
          );
        },
      ),
    );
  }
  
  List<String> _getSampleTags(int index) {
    final List<String> allTags = [
      'Indoor', 'Outdoor', 'PTZ', 'Dome', 'Bullet',
      'Night Vision', 'Motion Sensor', 'HDR', 'Wide Angle'
    ];
    
    // Return 2-3 tags based on index
    final startIdx = index % (allTags.length - 2);
    final count = 2 + (index % 2);
    return allTags.sublist(startIdx, startIdx + count);
  }
  
  String _getSampleGroup(int index) {
    final List<String> groups = [
      'Front Entrance', 'Back Entrance', 'Parking Lot',
      'Office Area', 'Warehouse', 'Hallway'
    ];
    return groups[index % groups.length];
  }
}
