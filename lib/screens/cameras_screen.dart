import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/camera_grid_item.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/status_indicator.dart';

class CamerasScreen extends StatefulWidget {
  const CamerasScreen({Key? key}) : super(key: key);

  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Online', 'Offline', 'Issues'];
  final List<String> _sortOptions = ['Name', 'Status', 'Last Active', 'Location'];
  String _selectedSort = 'Name';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: CustomAppBar(
        title: 'Cameras',
        isDesktop: isDesktop,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        onPressed: () {
          // UI only
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: _buildCameraGrid(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search cameras',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppTheme.darkSurface,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', _selectedFilter == 'All'),
          _buildFilterChip('Online', _selectedFilter == 'Online',
              leadingIcon: StatusIndicator(
                status: DeviceStatus.online,
                size: 10,
                padding: EdgeInsets.zero,
              )),
          _buildFilterChip('Offline', _selectedFilter == 'Offline',
              leadingIcon: StatusIndicator(
                status: DeviceStatus.offline,
                size: 10,
                padding: EdgeInsets.zero,
              )),
          _buildFilterChip('Issues', _selectedFilter == 'Issues',
              leadingIcon: StatusIndicator(
                status: DeviceStatus.warning,
                size: 10,
                padding: EdgeInsets.zero,
              )),
          _buildFilterChip('Favorites', _selectedFilter == 'Favorites',
              leadingIcon: const Icon(
                Icons.star,
                size: 14,
                color: AppTheme.primaryOrange,
              )),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, {Widget? leadingIcon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        avatar: leadingIcon,
        label: Text(label),
        selected: isSelected,
        showCheckmark: false,
        selectedColor: AppTheme.primaryBlue.withOpacity(0.2),
        backgroundColor: AppTheme.darkSurface,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.darkTextPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (selected) {
          setState(() {
            _selectedFilter = label;
          });
        },
      ),
    );
  }

  Widget _buildCameraGrid(BuildContext context) {
    final crossAxisCount = ResponsiveHelper.getResponsiveGridCount(
      context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          // Alternating statuses for demo
          DeviceStatus status = DeviceStatus.online;
          if (index % 5 == 0) {
            status = DeviceStatus.offline;
          } else if (index % 7 == 0) {
            status = DeviceStatus.warning;
          }
          
          return CameraGridItem(
            name: 'Camera ${index + 1}',
            location: 'Location ${index + 1}',
            status: status,
            onTap: () {
              // UI only
            },
            onSettingsTap: () {
              _showCameraOptions(context, index);
            },
          );
        },
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: const Text(
                'Filter Cameras',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ListView.builder(
              shrinkWrap: true,
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final option = _filterOptions[index];
                return ListTile(
                  leading: _getFilterIcon(option),
                  title: Text(option),
                  selected: _selectedFilter == option,
                  selectedTileColor: AppTheme.primaryBlue.withOpacity(0.15),
                  trailing: _selectedFilter == option
                      ? const Icon(Icons.check, color: AppTheme.primaryBlue)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedFilter = option;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _getFilterIcon(String filter) {
    switch (filter) {
      case 'All':
        return const Icon(Icons.all_inclusive);
      case 'Online':
        return StatusIndicator(
          status: DeviceStatus.online,
          size: 12,
          padding: EdgeInsets.zero,
        );
      case 'Offline':
        return StatusIndicator(
          status: DeviceStatus.offline,
          size: 12,
          padding: EdgeInsets.zero,
        );
      case 'Issues':
        return StatusIndicator(
          status: DeviceStatus.warning,
          size: 12,
          padding: EdgeInsets.zero,
        );
      default:
        return const Icon(Icons.filter_list);
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: const Text(
                'Sort Cameras',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ListView.builder(
              shrinkWrap: true,
              itemCount: _sortOptions.length,
              itemBuilder: (context, index) {
                final option = _sortOptions[index];
                return ListTile(
                  title: Text(option),
                  selected: _selectedSort == option,
                  selectedTileColor: AppTheme.primaryBlue.withOpacity(0.15),
                  trailing: _selectedSort == option
                      ? const Icon(Icons.check, color: AppTheme.primaryBlue)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedSort = option;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showCameraOptions(BuildContext context, int cameraIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.black,
                    radius: 20,
                    child: Icon(
                      Icons.videocam,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Camera ${cameraIndex + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Location ${cameraIndex + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Live'),
              onTap: () {
                Navigator.pop(context);
                // UI only
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // UI only
              },
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Restart Camera'),
              onTap: () {
                Navigator.pop(context);
                // UI only
              },
            ),
            ListTile(
              leading: Icon(
                Icons.star_border,
                color: AppTheme.primaryOrange,
              ),
              title: const Text('Add to Favorites'),
              onTap: () {
                Navigator.pop(context);
                // UI only
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}