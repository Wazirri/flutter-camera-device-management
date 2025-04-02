import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/device_list_item.dart';
import '../widgets/status_indicator.dart';
import '../models/camera_device.dart';
import '../providers/camera_devices_provider.dart';

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
    final devicesProvider = Provider.of<CameraDevicesProvider>(context);
    final devicesByMac = devicesProvider.devicesByMacAddress;
    final devicesList = devicesByMac.values.toList();
    
    if (devicesList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: AppTheme.darkTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No devices found',
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to the server to discover devices',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.darkTextSecondary,
              ),
            ),
          ],
        ),
      );
    }
    
    // Filter the devices based on _selectedFilter
    List<CameraDevice> filteredDevices = devicesList;
    if (_selectedFilter != 'All') {
      filteredDevices = devicesList.where((device) {
        switch (_selectedFilter) {
          case 'Online':
            return device.connected;
          case 'Offline':
            return !device.connected;
          // For 'Warning' and 'Error', we'd need more sophisticated logic based on device status
          // For now, just showing all devices for these filters
          default:
            return true;
        }
      }).toList();
    }
    
    // Sort the devices based on _selectedSort
    filteredDevices.sort((a, b) {
      switch (_selectedSort) {
        case 'Name':
          return a.macAddress.compareTo(b.macAddress);
        case 'Status':
          return a.connected == b.connected ? 0 : (a.connected ? -1 : 1);
        case 'Last Active':
          return a.lastSeenAt.compareTo(b.lastSeenAt);
        case 'Type':
          return a.deviceType.compareTo(b.deviceType);
        default:
          return 0;
      }
    });
    
    // Apply search filter if there's text in the search field
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filteredDevices = filteredDevices.where((device) {
        return device.macAddress.toLowerCase().contains(searchQuery) ||
               device.ipv4.toLowerCase().contains(searchQuery) ||
               device.deviceType.toLowerCase().contains(searchQuery);
      }).toList();
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredDevices.length,
      itemBuilder: (context, index) {
        final device = filteredDevices[index];
        
        // Determine device status
        DeviceStatus status = device.connected 
          ? DeviceStatus.online 
          : DeviceStatus.offline;
        
        // For more sophisticated status logic, we could look at other device properties
        // such as warning conditions, errors, etc.
        
        return DeviceListItem(
          name: 'Device ${device.macAddress}',
          model: device.deviceType.isEmpty ? 'Unknown' : device.deviceType,
          ipAddress: device.ipv4,
          status: status,
          lastActive: device.lastSeenAt,
          onTap: () {
            _showDeviceDetails(index, device);
          },
          onActionPressed: () {
            _showDeviceOptions(context, index, device);
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

  void _showDeviceOptions(BuildContext context, int deviceIndex, CameraDevice device) {
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.deviceType.isEmpty ? 'Device ${device.macAddress}' : device.deviceType,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'MAC: ${device.macAddress}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkTextSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
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
                _showDeviceDetails(deviceIndex, device);
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
            if (device.cameras.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.videocam),
                title: Text('Cameras (${device.cameras.length})'),
                onTap: () {
                  final devicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
                  devicesProvider.setSelectedDevice(device.macKey);
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/cameras');
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
                _showRemoveDeviceDialog(deviceIndex, device);
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void _showDeviceDetails(int deviceIndex, CameraDevice device) {
    final statusText = device.connected ? 'Online' : 'Offline';
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: Text(device.deviceType.isEmpty ? 'Device Details' : '${device.deviceType} Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Device Type', device.deviceType.isEmpty ? 'Unknown' : device.deviceType),
                _buildDetailRow('IP Address', device.ipv4.isEmpty ? 'Unknown' : device.ipv4),
                _buildDetailRow('MAC Address', device.macAddress),
                _buildDetailRow('Firmware', device.firmwareVersion.isEmpty ? 'Unknown' : device.firmwareVersion),
                _buildDetailRow('Last Active', device.lastSeenAt.isEmpty ? 'Unknown' : device.lastSeenAt),
                _buildDetailRow('Status', statusText),
                _buildDetailRow('Uptime', device.uptime.isEmpty ? 'Unknown' : device.uptime),
                _buildDetailRow('Cameras', '${device.cameras.length}'),
                if (device.recordPath.isNotEmpty)
                  _buildDetailRow('Recording Path', device.recordPath),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
            if (device.cameras.isNotEmpty)
              TextButton(
                onPressed: () {
                  final devicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
                  devicesProvider.setSelectedDevice(device.macKey);
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/cameras');
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                ),
                child: const Text('View Cameras'),
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

  void _showRemoveDeviceDialog(int deviceIndex, CameraDevice device) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: const Text('Remove Device'),
          content: Text(
            'Are you sure you want to remove ${device.deviceType.isEmpty ? 'Device ' + device.macAddress : device.deviceType}? This action cannot be undone.',
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
                final devicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
                // In a real app, we would remove from the backend first
                // For now, just remove from the local state
                // devicesProvider.removeDevice(device.macKey);
                Navigator.pop(context);
                // UI only for now - show a snackbar to indicate action
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Device removal is disabled in this version'),
                    backgroundColor: AppTheme.primaryBlue,
                  ),
                );
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