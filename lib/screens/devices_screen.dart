import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/device_list_item.dart';
import '../widgets/status_indicator.dart';
import '../models/camera_device.dart';
import '../providers/camera_devices_provider_optimized.dart';
import '../providers/websocket_provider_optimized.dart';

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
              leadingIcon: const StatusIndicator(
                status: DeviceStatus.online,
                size: 10,
                padding: EdgeInsets.zero,
              )),
          _buildFilterChip('Offline', _selectedFilter == 'Offline',
              leadingIcon: const StatusIndicator(
                status: DeviceStatus.offline,
                size: 10,
                padding: EdgeInsets.zero,
              )),
          _buildFilterChip('Warning', _selectedFilter == 'Warning',
              leadingIcon: const StatusIndicator(
                status: DeviceStatus.warning,
                size: 10,
                padding: EdgeInsets.zero,
              )),
          _buildFilterChip('Error', _selectedFilter == 'Error',
              leadingIcon: const StatusIndicator(
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
    final devicesProvider = Provider.of<CameraDevicesProviderOptimized>(context);
    final devicesByMac = devicesProvider.devicesByMacAddress;
    final devicesList = devicesByMac.values.toList();
    
    if (devicesList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: AppTheme.darkTextSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No devices found',
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.darkTextSecondary,
              ),
            ),
            SizedBox(height: 8),
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
        print('DevicesScreen: Building item for ${device.macAddress}. Connected: ${device.connected}, Status: $status');

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
        return const StatusIndicator(
          status: DeviceStatus.online,
          size: 12,
          padding: EdgeInsets.zero,
        );
      case 'Offline':
        return const StatusIndicator(
          status: DeviceStatus.offline,
          size: 12,
          padding: EdgeInsets.zero,
        );
      case 'Warning':
        return const StatusIndicator(
          status: DeviceStatus.warning,
          size: 12,
          padding: EdgeInsets.zero,
        );
      case 'Error':
        return const StatusIndicator(
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
                    child: const Icon(
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
                          style: const TextStyle(
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
                  final devicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
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
              leading: const Icon(
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

  // Ram miktarını insanların anlayabileceği formata çeviren yardımcı metot
  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}";
  }
  
  void _showDeviceDetails(int deviceIndex, CameraDevice device) {
    // Dialog\'u göster
    showDialog(
      context: context,
      builder: (dialogContext) {
        // CameraDevicesProviderOptimized'dan gelen güncellemeleri dinle
        return Consumer<CameraDevicesProviderOptimized>(
          builder: (context, devicesProvider, child) {
            // Cihazı güncel verilerle al
            final updatedDevice = devicesProvider.devicesByMacAddress[device.macKey] ?? device;
            final statusText = updatedDevice.connected ? 'Online' : 'Offline';
            print('DevicesScreen: DeviceDetailsDialog for ${updatedDevice.macAddress}. Connected: ${updatedDevice.connected}');

            return AlertDialog(
              backgroundColor: AppTheme.darkSurface,
              title: Text(updatedDevice.deviceType.isEmpty ? 'Device Details' : '${updatedDevice.deviceType} Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Temel Bilgiler
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Text(
                          'Temel Bilgiler',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('Device Type', updatedDevice.deviceType.isEmpty ? 'Unknown' : updatedDevice.deviceType),
                    _buildDetailRow('Device Name', updatedDevice.deviceName ?? 'Unknown'),
                    _buildDetailRow('IP Address (IPv4)', updatedDevice.ipv4.isEmpty ? 'Unknown' : updatedDevice.ipv4),
                    if (updatedDevice.ipv6 != null && updatedDevice.ipv6!.isNotEmpty)
                      _buildDetailRow('IP Address (IPv6)', updatedDevice.ipv6!),
                    _buildDetailRow('MAC Address', updatedDevice.macAddress),
                    _buildDetailRow('First Seen', updatedDevice.firstTime),
                    _buildDetailRow('Last Seen', updatedDevice.lastSeenAt.isEmpty ? 'Unknown' : updatedDevice.lastSeenAt),
                    _buildDetailRow('Current Time', updatedDevice.currentTime ?? 'Unknown'),
                    _buildDetailRow('Uptime', updatedDevice.formattedUptime),
                    _buildDetailRow('Firmware Version', updatedDevice.firmwareVersion.isEmpty ? 'Unknown' : updatedDevice.firmwareVersion),
                    if (updatedDevice.smartwebVersion != null && updatedDevice.smartwebVersion!.isNotEmpty)
                      _buildDetailRow('SmartWeb Version', updatedDevice.smartwebVersion!),
                    _buildDetailRow('Status', statusText),
                    _buildDetailRow('Cameras', '${updatedDevice.cameras.length}'),
                    _buildDetailRow('Master Status', updatedDevice.isMaster == true ? 'Master' : 'Slave'),
                    _buildDetailRow('Last Timestamp', updatedDevice.lastTs ?? 'Unknown'),
                    if (updatedDevice.recordPath.isNotEmpty)
                      _buildDetailRow('Recording Path', updatedDevice.recordPath),
                    
                    // Sistem Bilgileri (sysinfo)
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Text(
                          'Sistem Bilgileri',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('İşlemci Sıcaklığı', updatedDevice.cpuTemp > 0 ? '${updatedDevice.cpuTemp.toStringAsFixed(1)}°C' : 'Bilinmiyor'),
                    _buildDetailRow('Toplam RAM', updatedDevice.totalRam > 0 ? _formatBytes(updatedDevice.totalRam) : 'Bilinmiyor'),
                    _buildDetailRow('Boş RAM', updatedDevice.freeRam > 0 ? _formatBytes(updatedDevice.freeRam) : 'Bilinmiyor'),
                    _buildDetailRow('RAM Kullanımı', updatedDevice.totalRam > 0 && updatedDevice.freeRam > 0 ? 
                        '${((updatedDevice.totalRam - updatedDevice.freeRam) / updatedDevice.totalRam * 100).toStringAsFixed(1)}%' : 'Bilinmiyor'),
                    _buildDetailRow('Ağ Adresi', (updatedDevice.networkInfo != null && updatedDevice.networkInfo!.isNotEmpty) ? updatedDevice.networkInfo! : 'Bilinmiyor'),
                    _buildDetailRow('Cihaz Adı', updatedDevice.deviceName ?? 'Bilinmiyor'),
                    _buildDetailRow('Firmware Versiyonu', updatedDevice.firmwareVersion),
                    _buildDetailRow('Bağlantı Sayısı', updatedDevice.totalConnections > 0 ? updatedDevice.totalConnections.toString() : 'Bilinmiyor'),
                    _buildDetailRow('Oturum Sayısı', updatedDevice.totalSessions > 0 ? updatedDevice.totalSessions.toString() : 'Bilinmiyor'),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Close'),
                    ),
                    if (updatedDevice.cameras.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          final devicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
                          devicesProvider.setSelectedDevice(updatedDevice.macKey);
                          Navigator.pop(dialogContext);
                          Navigator.pushNamed(context, '/cameras');
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                        ),
                        child: const Text('View Cameras'),
                      ),
                    
                    // WiFi Ayarları Butonu
                    Consumer<WebSocketProviderOptimized>(
                      builder: (context, wsProvider, child) {
                        return TextButton.icon(
                          icon: const Icon(Icons.wifi),
                          label: const Text('WiFi Settings'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.amber,
                          ),
                          onPressed: () {
                            // WiFi ayarlarını değiştirme dialog'unu göster
                            _showChangeWifiDialog(dialogContext, updatedDevice, wsProvider);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: AppTheme.darkTextPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.darkTextSecondary,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
  
  // WiFi ayarlarını değiştirme dialog'u
  void _showChangeWifiDialog(BuildContext context, CameraDevice device, WebSocketProviderOptimized provider) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: const Text('Change WiFi Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change WiFi settings for ${device.deviceType.isEmpty ? "device ${device.macAddress}" : device.deviceType}',
                style: const TextStyle(color: AppTheme.darkTextSecondary),
              ),
              const SizedBox(height: 16),
              
              // WiFi adı giriş alanı
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'WiFi Name (SSID)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
              ),
              const SizedBox(height: 16),
              
              // WiFi şifresi giriş alanı
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'WiFi Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final password = passwordController.text.trim();
                
                if (name.isNotEmpty && password.isNotEmpty) {
                  final success = await provider.changeWifiSettings(name, password);
                  
                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);
                  
                  // Sonuç bildirimi göster
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                          ? 'WiFi settings updated successfully'
                          : 'Failed to update WiFi settings',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                } else {
                  // Boş alan uyarısı
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Update WiFi'),
            ),
          ],
        );
      },
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
            'Are you sure you want to remove ${device.deviceType.isEmpty ? 'Device ${device.macAddress}' : device.deviceType}? This action cannot be undone.',
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
                final devicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
                // In a real app, we would remove from the backend first
                // For now, just remove from the local state
                // devicesProvider.removeDevice(device.macKey);
                Navigator.pop(context);
                // UI only for now - show a snackbar to indicate action
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
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

  Widget _buildDeviceListItem(BuildContext context, CameraDevice device) {
    final textTheme = Theme.of(context).textTheme;
    
    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: () {
          // Device details or action
          _showDeviceDetails(0, device);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(device.deviceName ?? 'Unknown Device', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  StatusIndicator(
                    status: device.connected ? DeviceStatus.online : DeviceStatus.offline,
                    size: 12,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    device.connected ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: device.connected ? Colors.green : Colors.red,
                      fontSize: textTheme.bodySmall?.fontSize,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Powered: ${device.online == true ? "On" : "Off"}', style: TextStyle(color: device.online == true ? Colors.green : Colors.red, fontSize: textTheme.bodySmall?.fontSize)),
                  const SizedBox(width: 8),
                  Text('Connection: ${device.connected == true ? "Active" : "Inactive"}', style: TextStyle(color: device.connected == true ? Colors.green : Colors.red, fontSize: textTheme.bodySmall?.fontSize)),
                ],
              ),
              // Display additional fields
              if (device.firmwareVersion.isNotEmpty) Text('Version: ${device.firmwareVersion}', style: textTheme.bodySmall),
              if (device.smartwebVersion != null) Text('SmartWeb Version: ${device.smartwebVersion}', style: textTheme.bodySmall),
              Text('CPU Temp: ${device.cpuTemp}°C', style: textTheme.bodySmall),
              Text('IPv4: ${device.ipv4}', style: textTheme.bodySmall),
              if (device.ipv6 != null) Text('IPv6: ${device.ipv6}', style: textTheme.bodySmall),
              Text('Last Seen: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(device.lastSeenAt))}', style: textTheme.bodySmall),
              if (device.isMaster != null) Text('Master: ${device.isMaster! ? "Yes" : "No"}', style: textTheme.bodySmall),
              Text('Cameras: ${device.camCount}', style: textTheme.bodySmall),
              Text('Total RAM: ${device.totalRam} MB', style: textTheme.bodySmall),
              Text('Free RAM: ${device.freeRam} MB', style: textTheme.bodySmall),
              Text('Total Connections: ${device.totalConnections}', style: textTheme.bodySmall),
              Text('Total Sessions: ${device.totalSessions}', style: textTheme.bodySmall),
              if (device.networkInfo != null && device.networkInfo!.isNotEmpty) 
                Text('Network Info: ${device.networkInfo}', style: textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceGridItem(BuildContext context, CameraDevice device) {
    final textTheme = Theme.of(context).textTheme;
    
    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () {
          // Device details or action
          _showDeviceDetails(0, device);
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                device.deviceName ?? 'Unknown Device',
                style: textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              StatusIndicator(
                status: device.connected ? DeviceStatus.online : DeviceStatus.offline,
                size: 24,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              Text(
                device.connected ? 'Online' : 'Offline',
                style: TextStyle(
                  color: device.connected ? Colors.green : Colors.red,
                  fontSize: textTheme.bodySmall?.fontSize,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Powered: ${device.online == true ? "On" : "Off"}', style: TextStyle(color: device.online == true ? Colors.green : Colors.red, fontSize: textTheme.bodySmall?.fontSize)),
                  const SizedBox(width: 8),
                  Text('Connection: ${device.connected == true ? "Active" : "Inactive"}', style: TextStyle(color: device.connected == true ? Colors.green : Colors.red, fontSize: textTheme.bodySmall?.fontSize)),
                ],
              ),
              // Display additional fields
              if (device.firmwareVersion.isNotEmpty) Text('Ver: ${device.firmwareVersion}', style: textTheme.bodySmall, textAlign: TextAlign.center),
              if (device.smartwebVersion != null) Text('SW Ver: ${device.smartwebVersion}', style: textTheme.bodySmall, textAlign: TextAlign.center),
              Text('CPU: ${device.cpuTemp}°C', style: textTheme.bodySmall, textAlign: TextAlign.center),
              Text('IPv4: ${device.ipv4}', style: textTheme.bodySmall, textAlign: TextAlign.center),
              // Add more fields as needed, keeping in mind grid item size constraints
            ],
          ),
        ),
      ),
    );
  }
}