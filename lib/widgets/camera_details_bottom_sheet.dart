import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';
import '../providers/websocket_provider_optimized.dart';
import '../providers/camera_devices_provider_optimized.dart';

class CameraDetailsBottomSheet extends StatelessWidget {
  final Camera camera;
  final ScrollController scrollController;

  const CameraDetailsBottomSheet({
    Key? key,
    required this.camera,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle ve Başlık
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.videocam,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      camera.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: camera.connected ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          camera.connected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            fontSize: 14,
                            color: camera.connected ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          
          // Detaylar (Scrollable Area)
          Expanded(
            child: ListView(
              controller: scrollController, // This ListView will scroll
              children: [
                _buildDetailGroup(
                  context: context,
                  title: 'Basic Information',
                  details: [
                    DetailItem(name: 'Name', value: camera.name),
                    DetailItem(name: 'IP Address', value: camera.ip),
                    DetailItem(name: 'MAC Address', value: camera.mac), // Changed from camera.macKey to camera.mac
                    DetailItem(name: 'Username', value: camera.username),
                    DetailItem(name: 'Password', value: camera.password),
                    DetailItem(name: 'Connected', value: camera.connected ? 'Yes' : 'No'),
                    DetailItem(name: 'Recording', value: camera.recording ? 'Yes' : 'No'),
                    DetailItem(name: 'Last Seen', value: camera.lastSeenAt),
                  ],
                ),
                _buildDetailGroup(
                  context: context,
                  title: 'Device Information',
                  details: [
                    DetailItem(name: 'Hardware', value: camera.hw),
                    DetailItem(name: 'Brand', value: camera.brand),
                    DetailItem(name: 'Manufacturer', value: camera.manufacturer),
                    DetailItem(name: 'Country', value: camera.country),
                    // Display sound recording status
                    DetailItem(name: 'Sound Recording', value: camera.soundRec ? 'Enabled' : 'Disabled'),
                  ],
                ),
                _buildDetailGroup(
                  context: context,
                  title: 'Connection URLs',
                  details: [
                    DetailItem(name: 'xAddrs', value: camera.xAddrs),
                    // Display xAddr value
                    DetailItem(name: 'xAddr', value: camera.xAddr),
                    DetailItem(name: 'Media URI', value: camera.mediaUri),
                    DetailItem(name: 'Record URI', value: camera.recordUri),
                    DetailItem(name: 'Sub URI', value: camera.subUri),
                    DetailItem(name: 'Remote URI', value: camera.remoteUri),
                    DetailItem(name: 'Main Snapshot', value: camera.mainSnapShot),
                    DetailItem(name: 'Sub Snapshot', value: camera.subSnapShot),
                  ],
                ),
                _buildDetailGroup(
                  context: context,
                  title: 'Camera Reports',
                  details: [
                    DetailItem(name: 'Health Status', value: camera.health),
                    DetailItem(name: 'Temperature', value: camera.temperature.toString() + (camera.temperature > 0 ? '°C' : '')),
                    DetailItem(name: 'Last Restart', value: camera.lastRestartTime),
                    DetailItem(name: 'Report Error', value: camera.reportError),
                    DetailItem(name: 'Report Name', value: camera.reportName),
                    DetailItem(name: 'Connected', value: camera.connected ? 'Yes' : 'No'),
                    DetailItem(name: 'Disconnected At', value: camera.disconnected),
                    DetailItem(name: 'Last Seen At', value: camera.lastSeenAt),
                    DetailItem(name: 'Recording', value: camera.recording ? 'Yes' : 'No'),
                  ],
                ),
                // _buildDetailGroup for Recording Information
                _buildDetailGroup(
                  context: context,
                  title: 'Recording Information',
                  details: [
                    DetailItem(name: 'Record Path', value: camera.recordPath),
                    DetailItem(name: 'Record Codec', value: camera.recordCodec),
                    DetailItem(name: 'Record Resolution', value: '${camera.recordWidth}x${camera.recordHeight}'),
                    DetailItem(name: 'Sub Codec', value: camera.subCodec),
                    DetailItem(name: 'Sub Resolution', value: '${camera.subWidth}x${camera.subHeight}'),
                  ],
                ),
                // Current Device Assignment
                if (camera.currentDevice != null)
                  _buildDetailGroup(
                    context: context,
                    title: 'Current Device Assignment',
                    details: [
                      DetailItem(name: 'Device MAC', value: camera.currentDevice!.deviceMac),
                      DetailItem(name: 'Device IP', value: camera.currentDevice!.deviceIp),
                      DetailItem(name: 'Camera IP', value: camera.currentDevice!.cameraIp),
                      DetailItem(name: 'Name in Device', value: camera.currentDevice!.name),
                      DetailItem(name: 'Assignment Date', value: _formatTimestamp(camera.currentDevice!.startDate)),
                    ],
                  ),
                // Device History
                if (camera.deviceHistory.isNotEmpty)
                  _buildDeviceHistorySection(context),
                // MAC Address Information
                _buildDetailGroup(
                  context: context,
                  title: 'MAC Address Information',
                  details: [
                    if (camera.macFirstSeen != null)
                      DetailItem(name: 'First Seen', value: camera.macFirstSeen!),
                    if (camera.macLastDetected != null)
                      DetailItem(name: 'Last Detected', value: camera.macLastDetected!),
                    if (camera.macPort != null)
                      DetailItem(name: 'Port', value: camera.macPort.toString()),
                    if (camera.macReportedError != null)
                      DetailItem(name: 'Reported Error', value: camera.macReportedError!),
                    if (camera.macStatus != null)
                      DetailItem(name: 'Status', value: camera.macStatus!),
                  ],
                ),
                // SizedBox to provide some spacing before the non-scrolling buttons if needed,
                // but generally, the buttons will be outside this Expanded ListView.
                // const SizedBox(height: 16), 
              ], // End of children for ListView
            ), // End of Expanded ListView for scrollable details
          ),

          // Sabit Butonlar (Non-Scrollable Area)
          // These buttons will be at the bottom and will not scroll with the ListView above.
          const SizedBox(height: 16), // Spacing before buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Live View'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    // Live view sayfasına git (mevcut implemenatasyonunuza göre düzenleyin)
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('Recordings'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    // Recordings sayfasına git (mevcut implemenatasyonunuza göre düzenleyin)
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12), // Spacing between button rows
          const Text(
            'Advanced Commands',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Consumer<WebSocketProviderOptimized>(
            builder: (context, websocketProvider, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.group_add),
                    label: const Text('Add Group to Camera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      _showAddGroupDialog(context, camera, websocketProvider);
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Move Camera to Device'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      _showMoveCameraDialog(context, camera, websocketProvider);
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16), // Bottom padding after buttons
        ],
      ),
    );
  }

  // Her bir detay grubu için widget oluşturma
  Widget _buildDetailGroup({
    required BuildContext context,
    required String title,
    required List<DetailItem> details,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryOrange,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: AppTheme.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: details.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final detail = details[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          detail.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.darkTextSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          detail.value.isEmpty ? '-' : detail.value,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.darkTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // Build device history section with proper formatting
  Widget _buildDeviceHistorySection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.history,
                  color: AppTheme.primaryBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Device Assignment History (${camera.deviceHistory.length} entries)',
                style: const TextStyle(
                  color: AppTheme.darkTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // History entries
          ...camera.deviceHistory.asMap().entries.map((entry) {
            int index = entry.key;
            var history = entry.value;
            bool isLast = index == camera.deviceHistory.length - 1;
            
            return Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.darkBorder.withOpacity(0.5), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with entry number
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Entry ${index + 1}',
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (history.endDate > 0)
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        )
                      else
                        Icon(
                          Icons.access_time,
                          color: Colors.orange,
                          size: 16,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Device information
                  _buildHistoryDetailRow('Device MAC', history.deviceMac),
                  _buildHistoryDetailRow('Device IP', history.deviceIp),
                  _buildHistoryDetailRow('Camera IP', history.cameraIp),
                  _buildHistoryDetailRow('Camera Name', history.name),
                  
                  const SizedBox(height: 8),
                  Divider(height: 1, color: AppTheme.darkBorder),
                  const SizedBox(height: 8),
                  
                  // Time information
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Start Date',
                              style: TextStyle(
                                color: AppTheme.darkTextSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(history.startDate),
                              style: const TextStyle(
                                color: AppTheme.darkTextPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'End Date',
                              style: TextStyle(
                                color: AppTheme.darkTextSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              history.endDate > 0 ? _formatTimestamp(history.endDate) : 'Active',
                              style: TextStyle(
                                color: history.endDate > 0 ? AppTheme.darkTextPrimary : Colors.green,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Duration calculation
                  if (history.endDate > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Duration: ${_formatDuration(history.endDate - history.startDate)}',
                          style: const TextStyle(
                            color: AppTheme.darkTextSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Build history detail row
  Widget _buildHistoryDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(
              color: AppTheme.darkTextSecondary,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: const TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Kameraya grup ekleme dialog'u
void _showAddGroupDialog(BuildContext context, Camera camera, WebSocketProviderOptimized wsProvider) {
  // Mevcut grupları almak için CameraDevicesProvider kullan
  final devicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
  final existingGroups = devicesProvider.cameraGroupsList; // veya groupsList, hangisi uygunsa
  String? selectedGroupName;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder( // Dropdown değişikliğini yansıtmak için StatefulBuilder
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: AppTheme.darkSurface,
            title: const Text('Add Camera to Group'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add camera ${camera.name} to an existing group:',
                  style: const TextStyle(color: AppTheme.darkTextSecondary),
                ),
                const SizedBox(height: 24),
                if (existingGroups.isEmpty)
                  const Text('No groups available. Create a group first.', style: TextStyle(color: Colors.orangeAccent))
                else
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Group',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('Choose a group'),
                    value: selectedGroupName,
                    onChanged: (value) {
                      setStateDialog(() { // Dialog state'ini güncelle
                        selectedGroupName = value;
                      });
                    },
                    items: existingGroups.map((group) {
                      return DropdownMenuItem<String>(
                        value: group.name, // Grup adını değer olarak kullan
                        child: Text(group.name),
                      );
                    }).toList(),
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
                  backgroundColor: AppTheme.primaryBlue,
                ),
                // Grup seçilmediyse veya grup yoksa butonu devre dışı bırak
                onPressed: selectedGroupName == null || existingGroups.isEmpty
                  ? null 
                  : () async {
                      // Kamera MAC'i burada camera.mac'ten alınmalı.
                      // WebSocket komutunun beklediği format "ADD_GROUP_TO_CAM <camera_mac> <group_name>"
                      // camera.mac zaten doğru formatta olmalı (örn: "00:11:22:33:44:55_cam0")
                      // Eğer değilse, burada wsProvider.sendAddGroupToCamera göndermeden önce formatlamanız gerekir.
                      // Şimdilik camera.mac'in doğru olduğunu varsayıyoruz.
                      final String cameraIdentifier = camera.mac; // Doğrudan camera.mac kullanılıyor
                      
                      if (cameraIdentifier.isEmpty) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Camera MAC address is missing.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final success = await wsProvider.sendAddGroupToCamera(cameraIdentifier, selectedGroupName!);
                      
                      if (!context.mounted) return;
                      Navigator.pop(dialogContext);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                              ? 'Camera ${camera.name} added to group $selectedGroupName'
                              : 'Failed to add camera ${camera.name} to group $selectedGroupName',
                          ),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    },
                child: const Text('Add to Group'),
              ),
            ],
          );
        },
      );
    }
  );
}

// Kamerayı cihaza taşıma dialog'u
void _showMoveCameraDialog(BuildContext context, Camera camera, WebSocketProviderOptimized provider) {
  // Tüm cihazları almak için CameraDevicesProvider kullan
  final devicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
  final devices = devicesProvider.devicesList;
  String? selectedDeviceMac;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.darkSurface,
            title: const Text('Move Camera to Device'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Move camera ${camera.name} to another device',
                  style: const TextStyle(color: AppTheme.darkTextSecondary),
                ),
                const SizedBox(height: 16),
                const Text('Select Target Device:'),
                const SizedBox(height: 8),
                
                // Cihaz seçimi için dropdown
                if (devices.isEmpty)
                  const Text('No devices available', style: TextStyle(color: Colors.red))
                else
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('Select a device'),
                    value: selectedDeviceMac,
                    onChanged: (value) {
                      setState(() {
                        selectedDeviceMac = value;
                      });
                    },
                    items: devices.map((device) {
                      return DropdownMenuItem<String>(
                        value: device.macKey,
                        child: Text(
                          device.deviceType.isEmpty 
                            ? device.macKey 
                            : '${device.deviceType} (${device.macKey})'
                        ),
                      );
                    }).toList(),
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
                  backgroundColor: AppTheme.primaryBlue,
                ),
                onPressed: selectedDeviceMac == null
                  ? null // Cihaz seçilmediyse butonu devre dışı bırak
                  : () async {
                      final success = await provider.moveCamera(
                        selectedDeviceMac!, 
                        'me${camera.ip.replaceAll('.', '_')}' // Bu format örnek - gerçek format değişebilir
                      );
                      
                      if (!context.mounted) return;
                      Navigator.pop(dialogContext);
                      
                      // Sonuç bildirimi göster
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                              ? 'Camera ${camera.name} moved to selected device'
                              : 'Failed to move camera to device',
                          ),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    },
                child: const Text('Move Camera'),
              ),
            ],
          );
        },
      );
    }
  );
}

// Detayları temsil eden helper sınıf
class DetailItem {
  final String name;
  final String value;

  DetailItem({required this.name, required this.value});
}

// Helper method to format timestamp
String _formatTimestamp(int timestamp) {
  if (timestamp == 0) return 'N/A';
  
  try {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  } catch (e) {
    return timestamp.toString();
  }
}

// Helper method to format duration in seconds
String _formatDuration(int durationSeconds) {
  if (durationSeconds <= 0) return 'N/A';
  
  final days = durationSeconds ~/ 86400;
  final hours = (durationSeconds % 86400) ~/ 3600;
  final minutes = (durationSeconds % 3600) ~/ 60;
  
  List<String> parts = [];
  if (days > 0) parts.add('${days}d');
  if (hours > 0) parts.add('${hours}h');
  if (minutes > 0) parts.add('${minutes}m');
  
  return parts.isEmpty ? '< 1m' : parts.join(' ');
}
