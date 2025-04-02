import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/camera_device.dart';
import 'status_indicator.dart';

class CameraGridItem extends StatelessWidget {
  final String name;
  final String location;
  final DeviceStatus status;
  final String? thumbnailUrl;
  final VoidCallback onTap;
  final VoidCallback onSettingsTap;

  const CameraGridItem({
    Key? key,
    required this.name,
    required this.location,
    required this.status,
    this.thumbnailUrl,
    required this.onTap,
    required this.onSettingsTap,
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
        elevation: 2,
        margin: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // Camera preview/thumbnail
                Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.black,
                  child: thumbnailUrl != null
                      ? Image.network(
                          thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
                // Status indicator
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: StatusIndicator(
                      status: status,
                      showLabel: true,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          location,
                          style: TextStyle(
                            color: AppTheme.darkTextSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    color: AppTheme.darkTextSecondary,
                    onPressed: onSettingsTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.darkBackground,
      child: Center(
        child: Icon(
          Icons.videocam_off,
          size: 48,
          color: AppTheme.darkTextSecondary,
        ),
      ),
    );
  }
}