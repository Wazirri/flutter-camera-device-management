import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/desktop_menu.dart';
import '../widgets/device_list_item.dart';
import '../widgets/mobile_menu.dart';
import '../widgets/status_indicator.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({Key? key}) : super(key: key);

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  bool _isMenuExpanded = true;
  String _selectedFilter = 'All';
  String _selectedType = 'All Types';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  
  final List<String> _filterOptions = ['All', 'Online', 'Offline', 'Warning'];
  final List<String> _typeOptions = [
    'All Types', 'NVR', 'DVR', 'Server', 'Switch', 'Router'
  ];
  
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
        title: 'Devices',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
            tooltip: 'Add Device',
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
              currentRoute: '/devices',
              onNavigate: _navigate,
            )
          : null,
      bottomNavigationBar: isMobile
          ? MobileMenu(
              currentRoute: '/devices',
              onNavigate: _navigate,
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            DesktopMenu(
              currentRoute: '/devices',
              onNavigate: _navigate,
              isExpanded: _isMenuExpanded,
              onToggleExpand: _toggleMenu,
            ),
          Expanded(
            child: Column(
              children: [
                _buildFilterBar(),
                Expanded(
                  child: _buildDeviceList(),
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
                const SizedBox(height: 16.0),
                _buildTypeDropdown(),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSearchField()),
                    const SizedBox(width: 16.0),
                    _buildTypeDropdown(),
                  ],
                ),
                const SizedBox(height: 16.0),
                _buildFilterChips(),
              ],
            ),
    );
  }
  
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search devices...',
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
      runSpacing: 8.0,
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
  
  Widget _buildTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedType,
          dropdownColor: AppTheme.darkSurface,
          icon: const Icon(Icons.arrow_drop_down),
          items: _typeOptions.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedType = newValue;
              });
            }
          },
        ),
      ),
    );
  }
  
  Widget _buildDeviceList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: 15, // Sample data count
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
          
          // Sample device data
          final deviceType = _getDeviceType(index);
          
          // Filter based on device type
          if (_selectedType != 'All Types' && _selectedType != deviceType) {
            return const SizedBox.shrink();
          }
          
          final deviceName = '$deviceType ${index + 1}';
          final ipAddress = '192.168.1.${10 + index}';
          final tags = _getSampleTags(index);
          final group = _getSampleGroup(index);
          
          // Filter based on search query
          if (_searchQuery.isNotEmpty &&
              !deviceName.toLowerCase().contains(_searchQuery.toLowerCase()) &&
              !ipAddress.contains(_searchQuery) &&
              !group.toLowerCase().contains(_searchQuery.toLowerCase())) {
            return const SizedBox.shrink();
          }
          
          return DeviceListItem(
            name: deviceName,
            ip: ipAddress,
            status: status,
            tags: tags,
            group: group,
            onTap: () {
              // Handle device selection
            },
          );
        },
      ),
    );
  }
  
  String _getDeviceType(int index) {
    final List<String> types = ['NVR', 'DVR', 'Server', 'Switch', 'Router'];
    return types[index % types.length];
  }
  
  List<String> _getSampleTags(int index) {
    final List<String> allTags = [
      'Rack Mounted', 'POE', 'Cloud Backup', 'High Capacity',
      'Gigabit', 'RAID', 'Managed', 'Enterprise', 'Wireless'
    ];
    
    // Return 2-3 tags based on index
    final startIdx = index % (allTags.length - 2);
    final count = 2 + (index % 2);
    return allTags.sublist(startIdx, startIdx + count);
  }
  
  String _getSampleGroup(int index) {
    final List<String> groups = [
      'Core Infrastructure', 'Edge Devices', 'Storage',
      'Network', 'Security', 'Remote Access'
    ];
    return groups[index % groups.length];
  }
}
