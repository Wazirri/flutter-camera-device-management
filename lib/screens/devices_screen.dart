import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/device_list_item.dart';
import '../widgets/status_indicator.dart';
import '../models/camera_device.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({Key? key}) : super(key: key);

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Online', 'Offline', 'Warning'];
  final List<String> _sortOptions = ['Name', 'Status', 'Last Active', 'Type'];
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
        title: 'Devices',
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
          _showAddDeviceDialog();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: _buildDevicesList(),
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
          hintText: 'Search devices',
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
          _buildFilterChip('Warning', _selectedFilter == 'Warning',
              leadingIcon: StatusIndicator(
                status: DeviceStatus.warning,
                size: 10,
                padding: EdgeInsets.zero,
              )),
          _buildFilterChip('Error', _selectedFilter == 'Error',
              leadingIcon: StatusIndicator(
                status: DeviceStatus.error,
                size: 10,
                padding: EdgeInsets.zero,
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

  Widget _buildDevicesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 12,
      itemBuilder: (context, index) {
        // Alternating statuses for demo
        DeviceStatus status = DeviceStatus.online;
        if (index % 5 == 0) {
          status = DeviceStatus.offline;
        } else if (index % 7 == 0) {
          status = DeviceStatus.warning;
        } else if (index % 11 == 0) {
          status = DeviceStatus.error;
        }
        
        return DeviceListItem(
          name: 'Device ${index + 1}',
          model: index % 3 == 0 ? 'IP Camera' : index % 3 == 1 ? 'NVR' : 'Gateway',
          ipAddress: '192.168.1.${10 + index}',
          status: status,
          lastActive: '${index % 24}h ago',
          onTap: () {
            _showDeviceDetails(index);
          },
          onActionPressed: () {
            _showDeviceOptions(context, index);
          },
        );
      },
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
                'Filter Devices',
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
      case 'Warning':
        return StatusIndicator(
          status: DeviceStatus.warning,
          size: 12,
          padding: EdgeInsets.zero,
        );
      case 'Error':
        return StatusIndicator(
          status: DeviceStatus.error,
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
                'Sort Devices',
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

  void _showDeviceOptions(BuildContext context, int deviceIndex) {
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.router_rounded,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device ${deviceIndex + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deviceIndex % 3 == 0 ? 'IP Camera' : deviceIndex % 3 == 1 ? 'NVR' : 'Gateway',
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
              leading: const Icon(Icons.info_outline),
              title: const Text('Device Info'),
              onTap: () {
                Navigator.pop(context);
                _showDeviceDetails(deviceIndex);
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
              title: const Text('Restart Device'),
              onTap: () {
                Navigator.pop(context);
                // UI only
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: AppTheme.error,
              ),
              title: const Text('Remove Device'),
              onTap: () {
                Navigator.pop(context);
                _showRemoveDeviceDialog(deviceIndex);
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void _showDeviceDetails(int deviceIndex) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: Text('Device ${deviceIndex + 1} Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Device Type', deviceIndex % 3 == 0 ? 'IP Camera' : deviceIndex % 3 == 1 ? 'NVR' : 'Gateway'),
              _buildDetailRow('IP Address', '192.168.1.${10 + deviceIndex}'),
              _buildDetailRow('MAC Address', '00:1A:2B:3C:4D:${deviceIndex.toString().padLeft(2, '0')}'),
              _buildDetailRow('Firmware', 'v2.${deviceIndex % 10}.0'),
              _buildDetailRow('Last Active', '${deviceIndex % 24}h ago'),
              _buildDetailRow('Status', 'Online'),
              _buildDetailRow('Uptime', '${(deviceIndex + 1) * 24} hours'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.darkTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDeviceDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: const Text('Add Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Device Type',
                ),
                items: const [
                  DropdownMenuItem(value: 'camera', child: Text('IP Camera')),
                  DropdownMenuItem(value: 'nvr', child: Text('NVR')),
                  DropdownMenuItem(value: 'gateway', child: Text('Gateway')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  // UI only
                },
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Device Name',
                  hintText: 'Enter device name',
                ),
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'IP Address',
                  hintText: 'Enter IP address',
                ),
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Username (Optional)',
                  hintText: 'Enter username',
                ),
              ),
              const SizedBox(height: 16),
              const TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password (Optional)',
                  hintText: 'Enter password',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // UI only
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: const Text('Add Device'),
            ),
          ],
        );
      },
    );
  }

  void _showRemoveDeviceDialog(int deviceIndex) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: const Text('Remove Device'),
          content: Text(
            'Are you sure you want to remove Device ${deviceIndex + 1}? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // UI only
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.error,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }
}