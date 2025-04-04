import 'package:flutter/material.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';

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
    return Card(
      elevation: isSelected ? 4 : 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: AppTheme.primaryOrange, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Camera preview with status overlay
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Camera preview image or placeholder
                  Container(
                    color: Colors.black,
                    child: camera.mainSnapShot.isNotEmpty
                        ? Image.network(
                            camera.mainSnapShot,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.broken_image_outlined,
                                size: 48.0,
                                color: Colors.white54,
                              );
                            },
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.videocam_off,
                                size: 36.0,
                                color: Colors.white54,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No Preview',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                  ),

                  // Status indicator (Live / Offline)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: camera.connected
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fiber_manual_record,
                                  color: Colors.red,
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fiber_manual_record,
                                  color: Colors.grey,
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'OFFLINE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),

                  // Camera index number
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Quick action buttons
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Row(
                      children: [
                        // Live view button
                        Material(
                          color: AppTheme.primaryBlue.withOpacity(0.8),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            icon: const Icon(
                              Icons.videocam,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: onLiveView,
                            tooltip: 'Live View',
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            splashColor: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Playback button
                        Material(
                          color: AppTheme.primaryOrange.withOpacity(0.8),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            icon: const Icon(
                              Icons.video_library,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: onPlayback,
                            tooltip: 'Recordings',
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            splashColor: AppTheme.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Camera info footer
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Camera name
                  Text(
                    camera.name.isEmpty ? 'Camera ${index + 1}' : camera.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  // Camera status
                  Row(
                    children: [
                      Icon(
                        camera.connected ? Icons.link : Icons.link_off,
                        size: 14,
                        color: camera.connected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        camera.connected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                          fontSize: 12,
                          color: camera.connected ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  // Camera IP
                  if (camera.ip.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        camera.ip,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
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
