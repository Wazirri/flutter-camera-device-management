import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/device_status.dart';

class StatusIndicator extends StatelessWidget {
  final DeviceStatus status;
  final double size;
  final bool showLabel;
  final bool animatePulse;

  const StatusIndicator({
    super.key,
    required this.status,
    this.size = 12.0,
    this.showLabel = false,
    this.animatePulse = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated indicator
        _buildIndicator(),
        
        // Optional status label
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            _getLabelForStatus(status),
            style: TextStyle(
              fontSize: size * 1.1,
              color: _getColorForStatus(status),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIndicator() {
    return animatePulse && status == DeviceStatus.online
        ? _buildPulsingIndicator()
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _getColorForStatus(status),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getColorForStatus(status).withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
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
      case DeviceStatus.unknown:
      default:
        return 'Unknown';
    }
  }

  Color _getColorForStatus(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.online:
        return AppTheme.successColor; // Green
      case DeviceStatus.offline:
        return Colors.grey;
      case DeviceStatus.warning:
        return AppTheme.primaryColor; // Orange/Amber
      case DeviceStatus.error:
        return AppTheme.errorColor; // Red
      case DeviceStatus.unknown:
      default:
        return Colors.grey.shade500;
    }
  }

  Widget _buildPulsingIndicator() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.5, end: 1.0),
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _getColorForStatus(status),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _getColorForStatus(status).withOpacity(0.6 * value),
                blurRadius: 8 * value,
                spreadRadius: 2 * value,
              ),
            ],
          ),
        );
      },
      // Reset animation when complete
      onEnd: () {
        // This forces a rebuild when animation ends
        if (animatePulse) {
          (context as Element).markNeedsBuild();
        }
      },
    );
  }
}
