import 'package:flutter/material.dart';
import '../models/camera_device.dart';
import '../models/device_status.dart';
import '../theme/app_theme.dart';
import 'status_indicator.dart';

class DeviceListItem extends StatelessWidget {
  final CameraDevice device;
  final bool isSelected;
  final VoidCallback onTap;
  final DeviceStatus status;

  const DeviceListItem({
    Key? key,
    required this.device,
    required this.isSelected,
    required this.onTap,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppTheme.accentColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected 
                  ? AppTheme.accentColor 
                  : Colors.grey.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Status indicator
              StatusIndicator(
                status: status,
                showLabel: false,
                size: 10,
              ),
              
              const SizedBox(width: 12),
              
              // Device details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Device name/type with truncation for long text
                    Text(
                      device.deviceType.isEmpty 
                          ? 'Unknown Device'
                          : device.deviceType,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected 
                            ? AppTheme.accentColor 
                            : AppTheme.darkTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Device MAC address
                    Text(
                      device.id.split('ecs.slave.').last,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Status row
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: device.connected 
                              ? AppTheme.successColor 
                              : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          device.connected ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Number of cameras
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam,
                      size: 14,
                      color: AppTheme.accentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${device.cameras.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Chevron indicator if selected
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.accentColor,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
