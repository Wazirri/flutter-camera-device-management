import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum DeviceStatus {
  online,
  offline,
  warning,
  error,
}

class StatusIndicator extends StatelessWidget {
  final DeviceStatus status;
  final double size;
  final bool showLabel;
  final EdgeInsets padding;

  const StatusIndicator({
    Key? key,
    required this.status,
    this.size = 10.0,
    this.showLabel = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 8.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _getColorForStatus(status),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getColorForStatus(status).withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              _getLabelForStatus(status),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.darkTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getLabelForStatus(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.online:
        return 'Online';
      case DeviceStatus.offline:
        return 'Offline';
      case DeviceStatus.warning:
        return 'Warning';
      case DeviceStatus.error:
        return 'Error';
    }
  }

  Color _getColorForStatus(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.online:
        return AppTheme.online;
      case DeviceStatus.offline:
        return AppTheme.offline;
      case DeviceStatus.warning:
        return AppTheme.warning;
      case DeviceStatus.error:
        return AppTheme.error;
    }
  }
}