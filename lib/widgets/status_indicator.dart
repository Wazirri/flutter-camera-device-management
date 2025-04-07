import 'package:flutter/material.dart';
import '../models/device_status.dart';
import '../theme/app_theme.dart';

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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _getStatusColor(),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _getStatusColor().withOpacity(0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: _getStatusColor(),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
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
