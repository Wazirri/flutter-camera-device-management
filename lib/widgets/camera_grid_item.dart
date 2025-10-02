import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../providers/camera_devices_provider_optimized.dart';

class CameraGridItem extends StatelessWidget {
  final Camera camera;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLiveView;
  final VoidCallback onPlayback;

  const CameraGridItem({
    Key? key,
    required this.camera,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onLiveView,
    required this.onPlayback,
  }) : super(key: key);

  // Helper method to check if camera has a real MAC address (not a temp placeholder ID)
  bool _hasMacAddress(Camera camera) {
    // MAC adresi gerçek MAC format'ında mı kontrol et (örn: me8_b7_23_0c_12_43)
    // Geçici ID'ler genelde "deviceKey_cam_index" formatında
    return camera.mac.isNotEmpty && 
           !camera.mac.contains('_cam_') && 
           !camera.mac.contains('_placeholder_');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: isSelected ? 8.0 : 3.0,
        margin: const EdgeInsets.all(8.0),
        color: isSelected 
          ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
          : Theme.of(context).cardColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Camera image or preview
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Camera image (placeholder or actual image)
                  Container(
                    color: camera.isPlaceholder ? Colors.grey[800] : Colors.black,
                    child: _hasMacAddress(camera)
                      ? camera.mainSnapShot.isNotEmpty
                          ? Image.network(
                              camera.mainSnapShot,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 48.0,
                                    color: Colors.white54,
                                  ),
                                );
                              },
                            )
                          : const Center(
                              child: Icon(
                                Icons.videocam_off,
                                size: 48.0,
                                color: Colors.white54,
                              ),
                            )
                      : const Center(
                          child: Icon(
                            Icons.videocam_off_outlined,
                            size: 48.0,
                            color: Colors.grey,
                          ),
                        ),
                  ),
                  
                  // Camera status overlay (top-left corner)
                  if (_hasMacAddress(camera))
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fiber_manual_record,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // No MAC address indicator (top-right corner)
                  if (!_hasMacAddress(camera))
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'NO MAC',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Camera details
            Container(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Camera name (shortened for better display)
                  Text(
                    _getCameraDisplayName(camera),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.0,
                      color: camera.isPlaceholder ? Colors.grey : null,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Current device assignment
                  if (camera.currentDevice != null)
                    Row(
                      children: [
                        Icon(
                          Icons.device_hub,
                          size: 14.0,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _getDeviceName(context, camera.currentDevice!.deviceMac),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.0,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 4),
                  
                  // Camera status
                  Row(
                    children: [
                      Icon(
                        camera.connected ? Icons.link : Icons.link_off,
                        size: 14.0,
                        color: camera.connected
                          ? Colors.green
                          : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          camera.connected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            fontSize: 11.0,
                            color: camera.connected
                              ? Colors.green
                              : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Resolution info
                  if (camera.recordWidth > 0 && camera.recordHeight > 0)
                    Row(
                      children: [
                        Icon(
                          Icons.high_quality,
                          size: 14.0,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${camera.recordWidth}x${camera.recordHeight}',
                          style: const TextStyle(
                            fontSize: 11.0,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 4),
                  
                  // History count and last seen
                  Row(
                    children: [
                      // History count
                      if (camera.deviceHistory.isNotEmpty) ...[
                        Icon(
                          Icons.history,
                          size: 14.0,
                          color: Colors.purple,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${camera.deviceHistory.length} history',
                          style: const TextStyle(
                            fontSize: 11.0,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      
                      // Last seen
                      if (camera.lastSeenAt.isNotEmpty) ...[
                        Icon(
                          Icons.access_time,
                          size: 14.0,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatLastSeen(camera.lastSeenAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.0,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Additional info row
                  Row(
                    children: [
                      // Recording status
                      if (camera.recording) ...[
                        Icon(
                          Icons.fiber_manual_record,
                          size: 14.0,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Recording',
                          style: const TextStyle(
                            fontSize: 11.0,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      
                      // Brand info
                      if (camera.brand.isNotEmpty) ...[
                        Icon(
                          Icons.business,
                          size: 14.0,
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            camera.brand,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.0,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.videocam,
                    color: camera.isPlaceholder ? Colors.grey : null,
                  ),
                  tooltip: !_hasMacAddress(camera) ? 'No MAC Address' : 'Live View',
                  onPressed: !_hasMacAddress(camera) ? null : onLiveView,
                ),
                IconButton(
                  icon: Icon(
                    Icons.video_library,
                    color: camera.isPlaceholder ? Colors.grey : null,
                  ),
                  tooltip: !_hasMacAddress(camera) ? 'No MAC Address' : 'Recordings',
                  onPressed: !_hasMacAddress(camera) ? null : onPlayback,
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'More Options',
                  onPressed: () {
                    // Show camera options with real-time updates
                    showDialog(
                      context: context,
                      builder: (dialogContext) {
                        // Parent device'ı bul (mac adresine göre)
                        String? macKey;
                        for (var entry in Provider.of<CameraDevicesProviderOptimized>(context, listen: false).devices.entries) {
                          if (entry.value.cameras.any((c) => c.index == camera.index)) {
                            macKey = entry.key;
                            break;
                          }
                        }
                        
                        // CameraDevicesProvider'dan gelen kamera güncellemelerini dinle
                        return Consumer<CameraDevicesProviderOptimized>(builder: (context, devicesProvider, child) {
                          // Kamera verilerini güncel olarak al
                          Camera updatedCamera = camera;
                          
                          // MAC adresi biliniyorsa güncel veri almaya çalış
                          if (macKey != null && devicesProvider.devices.containsKey(macKey)) {
                            final device = devicesProvider.devices[macKey]!;
                            final foundCamera = device.cameras.firstWhere(
                              (c) => c.index == camera.index, 
                              orElse: () => camera
                            );
                            updatedCamera = foundCamera;
                          }
                          
                          return AlertDialog(
                            title: Text('Camera: ${updatedCamera.name}'),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildDetailRow('IP', updatedCamera.ip),
                                  _buildDetailRow('Brand', updatedCamera.brand),
                                  _buildDetailRow('Status', updatedCamera.connected ? 'Connected' : 'Disconnected'),
                                  _buildDetailRow('Last Update', DateTime.now().toString().split('.')[0]),
                                  if (updatedCamera.mediaUri.isNotEmpty) 
                                    _buildDetailRow('Media URI', updatedCamera.mediaUri),
                                  if (updatedCamera.recordUri.isNotEmpty) 
                                    _buildDetailRow('Record URI', updatedCamera.recordUri),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                child: const Text('Close'),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                },
                              ),
                            ],
                          );
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Get shortened camera display name
  String _getCameraDisplayName(Camera camera) {
    if (camera.name.isNotEmpty) {
      // If camera name is too long, create a smart shortened version
      if (camera.name.length > 20) {
        // Try to find meaningful parts to keep
        final parts = camera.name.split('_');
        if (parts.length > 1) {
          // Take first and last part if multiple parts
          return '${parts.first}_${parts.last}';
        } else {
          // Just truncate
          return '${camera.name.substring(0, 17)}...';
        }
      }
      return camera.name;
    }
    return 'Camera ${camera.index + 1}';
  }

  // Get device name from MAC address
  String _getDeviceName(BuildContext context, String deviceMac) {
    try {
      final provider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
      
      // Use MAC address as-is, no formatting
      String normalizedMac = deviceMac;
      
      // Find device by MAC address
      for (var device in provider.devices.values) {
        if (device.macAddress == normalizedMac || device.macKey == deviceMac || provider.devices.containsKey(deviceMac)) {
          return device.deviceName?.isNotEmpty == true 
              ? device.deviceName! 
              : device.deviceType.isNotEmpty 
                  ? device.deviceType 
                  : device.macAddress.substring(0, 8) + '...';
        }
      }
      
      // If not found, return shortened MAC
      return deviceMac.length > 10 ? '${deviceMac.substring(0, 10)}...' : deviceMac;
    } catch (e) {
      return deviceMac.length > 10 ? '${deviceMac.substring(0, 10)}...' : deviceMac;
    }
  }

  // Format last seen time
  String _formatLastSeen(String lastSeen) {
    if (lastSeen.isEmpty) return 'Never';
    
    try {
      // Try to parse various date formats
      DateTime? dateTime;
      
      // Format: "2025-09-16 - 13:54:26"
      if (lastSeen.contains(' - ')) {
        final parts = lastSeen.split(' - ');
        if (parts.length == 2) {
          final dateStr = '${parts[0]} ${parts[1]}';
          dateTime = DateTime.tryParse(dateStr.replaceAll(' - ', ' '));
        }
      } else {
        // Try standard ISO format
        dateTime = DateTime.tryParse(lastSeen);
      }
      
      if (dateTime != null) {
        final now = DateTime.now();
        final difference = now.difference(dateTime);
        
        if (difference.inMinutes < 1) {
          return 'Just now';
        } else if (difference.inMinutes < 60) {
          return '${difference.inMinutes}m ago';
        } else if (difference.inHours < 24) {
          return '${difference.inHours}h ago';
        } else if (difference.inDays < 7) {
          return '${difference.inDays}d ago';
        } else {
          return '${dateTime.day}/${dateTime.month}';
        }
      }
      
      // If parsing fails, return truncated string
      return lastSeen.length > 12 ? '${lastSeen.substring(0, 12)}...' : lastSeen;
    } catch (e) {
      return lastSeen.length > 12 ? '${lastSeen.substring(0, 12)}...' : lastSeen;
    }
  }
}
