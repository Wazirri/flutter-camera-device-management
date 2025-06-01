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
                    color: Colors.black,
                    child: camera.mainSnapShot.isNotEmpty
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
                        ),
                  ),
                  
                  // Camera status overlay (top-left corner)
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
                ],
              ),
            ),
            
            // Camera details
            Container(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Camera name
                  Text(
                    camera.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Camera status
                  Row(
                    children: [
                      Icon(
                        camera.connected ? Icons.link : Icons.link_off,
                        size: 16.0,
                        color: camera.connected
                          ? Colors.green
                          : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        camera.connected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                          fontSize: 12.0,
                          color: camera.connected
                            ? Colors.green
                            : Colors.red,
                        ),
                      ),
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
                  icon: const Icon(Icons.videocam),
                  tooltip: 'Live View',
                  onPressed: onLiveView,
                ),
                IconButton(
                  icon: const Icon(Icons.video_library),
                  tooltip: 'Recordings',
                  onPressed: onPlayback,
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
}
