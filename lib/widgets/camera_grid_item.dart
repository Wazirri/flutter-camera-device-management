import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'status_indicator.dart';

class CameraGridItem extends StatelessWidget {
  final String name;
  final DeviceStatus status;
  final String? resolution;
  final bool isSelected;
  final VoidCallback? onTap;
  
  const CameraGridItem({
    Key? key,
    required this.name,
    required this.status,
    this.resolution,
    this.isSelected = false,
    this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: isSelected ? 4.0 : 2.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: isSelected
              ? const BorderSide(color: AppTheme.blueAccent, width: 2.0)
              : BorderSide.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Camera preview area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8.0),
                    topRight: Radius.circular(8.0),
                  ),
                ),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam_off,
                      color: AppTheme.textSecondary,
                      size: 48.0,
                    ),
                    SizedBox(height: 8.0),
                    Text(
                      'No Live Feed',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Camera information
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StatusIndicator(status: status),
                    ],
                  ),
                  if (resolution != null) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      resolution!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
