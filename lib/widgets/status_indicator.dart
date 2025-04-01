import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum DeviceStatus {
  online,
  offline,
  warning,
  error
}

class StatusIndicator extends StatelessWidget {
  final DeviceStatus status;
  final double size;
  final bool showLabel;
  
  const StatusIndicator({
    Key? key,
    required this.status,
    this.size = 12.0,
    this.showLabel = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    
    switch (status) {
      case DeviceStatus.online:
        color = AppTheme.blueAccent;
        label = 'Online';
        break;
      case DeviceStatus.offline:
        color = AppTheme.textSecondary;
        label = 'Offline';
        break;
      case DeviceStatus.warning:
        color = AppTheme.orangeAccent;
        label = 'Warning';
        break;
      case DeviceStatus.error:
        color = AppTheme.errorColor;
        label = 'Error';
        break;
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 4.0,
                spreadRadius: 1.0,
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8.0),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
