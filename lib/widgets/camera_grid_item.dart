import 'package:flutter/material.dart';
import '../models/camera_device.dart';

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
                    // Show camera options
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Camera: ${camera.name}'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildDetailRow('IP', camera.ip),
                                _buildDetailRow('Brand', camera.brand),
                                _buildDetailRow('Status', camera.connected ? 'Connected' : 'Disconnected'),
                                if (camera.mediaUri.isNotEmpty) 
                                  _buildDetailRow('Media URI', camera.mediaUri),
                                if (camera.recordUri.isNotEmpty) 
                                  _buildDetailRow('Record URI', camera.recordUri),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              child: const Text('Close'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
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
