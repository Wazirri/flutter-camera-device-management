import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../providers/camera_devices_provider.dart';
import '../screens/live_view_screen.dart';
import '../theme/app_theme.dart';

class CameraGridItem extends StatelessWidget {
  final Camera camera;
  final int cameraIndex;
  final String deviceKey;
  
  const CameraGridItem({
    Key? key,
    required this.camera,
    required this.cameraIndex,
    required this.deviceKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final connected = camera.connected;
    final recording = camera.recording;
    
    // Status indicator color
    Color statusColor = connected 
        ? (recording ? AppTheme.primaryColor : AppTheme.successColor) 
        : Colors.grey;
    
    String statusText = connected 
        ? (recording ? 'Recording' : 'Connected') 
        : 'Disconnected';
    
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: InkWell(
        onTap: () {
          // Select the camera before navigating
          final cameraProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
          cameraProvider.selectDevice(deviceKey);
          cameraProvider.selectCamera(cameraIndex);
          
          // Navigate to live view
          Navigator.of(context).pushNamed(LiveViewScreen.routeName);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail or preview
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Either show the camera's thumbnail or a placeholder
                  camera.mainSnapShot.isNotEmpty
                      ? Image.network(
                          camera.mainSnapShot,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.black54,
                              child: Center(
                                child: Icon(
                                  Icons.videocam_off,
                                  color: Colors.white54,
                                  size: 40,
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.black54,
                          child: Center(
                            child: Icon(
                              Icons.videocam,
                              color: Colors.white54,
                              size: 40,
                            ),
                          ),
                        ),
                  
                  // Status indicator overlay
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Recording indicator
                  if (recording)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fiber_manual_record,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Camera information
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    camera.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    camera.ip,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
