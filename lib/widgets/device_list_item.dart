import 'package:flutter/material.dart';
import '../models/camera_device.dart';
import '../models/device_status.dart';
import '../theme/app_theme.dart';
import 'status_indicator.dart';

class DeviceListItem extends StatelessWidget {
  final CameraDevice device;
  final DeviceStatus status;
  final bool isSelected;
  final VoidCallback onTap;
  
  const DeviceListItem({
    Key? key,
    required this.device,
    required this.status,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          width: isSelected ? 2 : 1,
          color: isSelected 
              ? AppTheme.accentColor 
              : Colors.transparent,
        ),
      ),
      child: Material(
        color: isSelected 
            ? AppTheme.accentColor.withOpacity(0.05)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status indicator with icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.devices,
                      color: _getStatusColor(),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Device info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            device.deviceType.isNotEmpty 
                                ? device.deviceType 
                                : 'Device ${device.macKey}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          StatusIndicator(
                            status: status,
                            showLabel: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'IP: ${device.ipv4}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.videocam,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Cameras: ${device.cameras.length}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow indicator
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getStatusColor() {
    switch (status) {
      case DeviceStatus.online:
        return AppTheme.successColor;
      case DeviceStatus.offline:
        return Colors.grey;
      case DeviceStatus.warning:
        return AppTheme.warningColor;
      case DeviceStatus.error:
        return AppTheme.errorColor;
      case DeviceStatus.unknown:
      default:
        return Colors.grey.shade500;
    }
  }
}
