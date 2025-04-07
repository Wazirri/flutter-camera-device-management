import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../models/device_status.dart';
import '../providers/camera_devices_provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/device_list_item.dart';
import '../widgets/status_indicator.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({Key? key}) : super(key: key);

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  String _searchQuery = '';
  CameraDevice? _selectedDevice;
  String _sortBy = 'name'; // 'name', 'status', 'type'
  bool _showOfflineDevices = true;
  
  @override
  Widget build(BuildContext context) {
    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context);
    final devices = cameraDevicesProvider.devicesList;
    
    // Filter and sort devices
    List<CameraDevice> filteredDevices = _filterDevices(devices);
    _sortDevices(filteredDevices);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortingDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              cameraDevicesProvider.refreshDevices();
            },
          ),
        ],
      ),
      body: devices.isEmpty
          ? _buildEmptyState()
          : ResponsiveHelper.isDesktop(context)
              ? _buildDesktopLayout(filteredDevices)
              : _buildMobileLayout(filteredDevices),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.devices,
            size: 80,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            'No Devices Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to devices via WebSocket',
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
              Provider.of<CameraDevicesProvider>(context, listen: false)
                .refreshDevices();
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildDesktopLayout(List<CameraDevice> devices) {
    return Row(
      children: [
        // Left panel with device list
        Expanded(
          flex: 1,
          child: _buildDeviceList(devices),
        ),
        
        // Vertical divider
        VerticalDivider(
          width: 1,
          color: Colors.grey.shade800,
        ),
        
        // Right panel with device details
        Expanded(
          flex: 2,
          child: _selectedDevice != null
              ? _buildDeviceDetailPanel(_selectedDevice!)
              : _buildNoDeviceSelectedMessage(),
        ),
      ],
    );
  }
  
  Widget _buildMobileLayout(List<CameraDevice> devices) {
    return _buildDeviceList(devices);
  }
  
  Widget _buildDeviceList(List<CameraDevice> devices) {
    return Column(
      children: [
        // Filter controls
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                '${devices.length} Devices',
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // Filter toggle for offline devices
              Row(
                children: [
                  Text(
                    'Show Offline',
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 14,
                    ),
                  ),
                  Switch(
                    value: _showOfflineDevices,
                    activeColor: AppTheme.accentColor,
                    onChanged: (value) {
                      setState(() {
                        _showOfflineDevices = value;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Status filter pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildStatusFilterChip('All', null),
              const SizedBox(width: 8),
              _buildStatusFilterChip(
                'Online',
                DeviceStatus.online,
                icon: Icons.circle,
                color: AppTheme.successColor,
              ),
              const SizedBox(width: 8),
              _buildStatusFilterChip(
                'Offline',
                DeviceStatus.offline,
                icon: Icons.circle,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
              _buildStatusFilterChip(
                'Warning',
                DeviceStatus.warning,
                icon: Icons.warning,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              _buildStatusFilterChip(
                'Error',
                DeviceStatus.error,
                icon: Icons.error,
                color: AppTheme.errorColor,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        const Divider(height: 1),
        
        // Device list
        Expanded(
          child: devices.isEmpty
              ? Center(
                  child: Text(
                    'No devices match your filters',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: devices.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return _buildDeviceListItem(device);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildStatusFilterChip(
    String label,
    DeviceStatus? status, {
    IconData? icon,
    Color? color,
  }) {
    final isSelected = (status == null && _searchQuery.isEmpty) ||
        (_searchQuery == label.toLowerCase());
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 4),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _searchQuery = selected ? (status == null ? '' : label.toLowerCase()) : '';
        });
      },
      backgroundColor: AppTheme.darkSurface,
      selectedColor: AppTheme.accentColor,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
  
  Widget _buildDeviceListItem(CameraDevice device) {
    DeviceStatus status = device.connected 
          ? DeviceStatus.online 
          : DeviceStatus.offline;
    
    return DeviceListItem(
      device: device,
      status: status,
      isSelected: _selectedDevice?.id == device.id,
      onTap: () {
        setState(() {
          _selectedDevice = device;
        });
        
        // On mobile, navigate to detail screen
        if (!ResponsiveHelper.isDesktop(context)) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _buildDeviceDetailScreen(device),
            ),
          );
        }
      },
    );
  }
  
  Widget _buildDeviceDetailPanel(CameraDevice device) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device header
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.darkSurface,
                radius: 32,
                child: Icon(
                  Icons.devices,
                  size: 32,
                  color: device.connected
                      ? AppTheme.accentColor
                      : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device ${device.macKey}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type: ${device.deviceType.isNotEmpty ? device.deviceType : "Unknown Device"}',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        StatusIndicator(
                          status: device.connected
                              ? DeviceStatus.online
                              : DeviceStatus.offline,
                          showLabel: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Device info sections
          _buildInfoSection(
            title: 'Device Information',
            icon: Icons.info_outline,
            children: [
              _buildInfoRow('MAC Address', device.macKey),
              _buildInfoRow('IP Address', device.ipv4),
              _buildInfoRow('Last Seen', device.lastSeenAt),
              _buildInfoRow('Uptime', device.uptime),
              _buildInfoRow('Firmware', device.firmwareVersion),
              _buildInfoRow('Recording Path', device.recordPath),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Cameras section
          _buildInfoSection(
            title: 'Connected Cameras',
            icon: Icons.videocam,
            children: device.cameras.isEmpty
                ? [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No cameras found on this device'),
                      ),
                    ),
                  ]
                : device.cameras
                    .map((camera) => _buildCameraListItem(camera))
                    .toList(),
          ),
          
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Device'),
                  onPressed: () {
                    // Refresh this device
                    Provider.of<CameraDevicesProvider>(context, listen: false)
                      .refreshDevices();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    Icons.power_settings_new,
                    color: device.connected
                        ? Colors.red
                        : AppTheme.accentColor,
                  ),
                  label: Text(
                    device.connected ? 'Disconnect' : 'Connect',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: device.connected
                        ? Colors.red
                        : AppTheme.accentColor,
                  ),
                  onPressed: () {
                    // TODO: Implement connect/disconnect functionality
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildDeviceDetailScreen(CameraDevice device) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Device ${device.macKey}'),
      ),
      body: _buildDeviceDetailPanel(device),
    );
  }
  
  Widget _buildNoDeviceSelectedMessage() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.devices,
            size: 80,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Device Selected',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a device from the list to view details',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: AppTheme.accentColor,
              size: 20,
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
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade800,
              width: 1,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    // Don't show empty values
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Text(
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
  
  Widget _buildCameraListItem(Camera camera) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // TODO: Navigate to camera detail screen
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Camera thumbnail/icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: camera.connected
                        ? AppTheme.accentColor
                        : Colors.grey.shade800,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.videocam,
                    size: 30,
                    color: camera.connected
                        ? AppTheme.accentColor
                        : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Camera details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      camera.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IP: ${camera.ip}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StatusIndicator(
                          status: camera.connected
                              ? DeviceStatus.online
                              : DeviceStatus.offline,
                          size: 10,
                          showLabel: true,
                        ),
                        if (camera.recording) ...[
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fiber_manual_record,
                                size: 10,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Recording',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Action buttons
              IconButton(
                icon: const Icon(Icons.play_circle_outline),
                color: AppTheme.accentColor,
                onPressed: () {
                  // TODO: Navigate to live view
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        String query = _searchQuery;
        
        return AlertDialog(
          title: const Text('Search Devices'),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter device name, type, or IP...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppTheme.darkInput,
            ),
            onChanged: (value) {
              query = value.toLowerCase();
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Search'),
              onPressed: () {
                setState(() {
                  _searchQuery = query;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  
  void _showSortingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        String sortBy = _sortBy;
        
        return AlertDialog(
          title: const Text('Sort Devices'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSortOption(
                'Sort by Name',
                'name',
                sortBy,
                (value) {
                  sortBy = value;
                },
              ),
              _buildSortOption(
                'Sort by Status',
                'status',
                sortBy,
                (value) {
                  sortBy = value;
                },
              ),
              _buildSortOption(
                'Sort by Type',
                'type',
                sortBy,
                (value) {
                  sortBy = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Apply'),
              onPressed: () {
                setState(() {
                  _sortBy = sortBy;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildSortOption(
    String label,
    String value,
    String groupValue,
    Function(String) onChanged,
  ) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: groupValue,
      onChanged: (newValue) {
        if (newValue != null) {
          onChanged(newValue);
        }
      },
      activeColor: AppTheme.accentColor,
      dense: true,
    );
  }
  
  List<CameraDevice> _filterDevices(List<CameraDevice> devices) {
    return devices.where((device) {
      // Filter by status
      if (!_showOfflineDevices && !device.connected) {
        return false;
      }
      
      // Filter by search query
      if (_searchQuery.isEmpty) {
        return true;
      }
      
      // Filter by status keywords
      if (_searchQuery == 'online') {
        return device.connected;
      } else if (_searchQuery == 'offline') {
        return !device.connected;
      } else if (_searchQuery == 'warning') {
        return device.status == DeviceStatus.warning;
      } else if (_searchQuery == 'error') {
        return device.status == DeviceStatus.error;
      }
      
      // Filter by device properties
      return device.macKey.toLowerCase().contains(_searchQuery) ||
          device.deviceType.toLowerCase().contains(_searchQuery) ||
          device.ipv4.toLowerCase().contains(_searchQuery);
    }).toList();
  }
  
  void _sortDevices(List<CameraDevice> devices) {
    switch (_sortBy) {
      case 'name':
        devices.sort((a, b) => a.macKey.compareTo(b.macKey));
        break;
      case 'status':
        devices.sort((a, b) {
          if (a.connected && !b.connected) return -1;
          if (!a.connected && b.connected) return 1;
          return a.macKey.compareTo(b.macKey);
        });
        break;
      case 'type':
        devices.sort((a, b) {
          if (a.deviceType.isEmpty && b.deviceType.isNotEmpty) return 1;
          if (a.deviceType.isNotEmpty && b.deviceType.isEmpty) return -1;
          int typeCompare = a.deviceType.compareTo(b.deviceType);
          return typeCompare != 0 ? typeCompare : a.macKey.compareTo(b.macKey);
        });
        break;
    }
  }
}
