import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'status_indicator.dart';

class DeviceListItem extends StatelessWidget {
  final String name;
  final String model;
  final String ipAddress;
  final DeviceStatus status;
  final String lastActive;
  final VoidCallback onTap;
  final VoidCallback onActionPressed;

  const DeviceListItem({
    Key? key,
    required this.name,
    required this.model,
    required this.ipAddress,
    required this.status,
    required this.lastActive,
    required this.onTap,
    required this.onActionPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.router_rounded,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 16),
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
                                model,
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
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    color: AppTheme.darkTextSecondary,
                    onPressed: onActionPressed,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // IP Address
                  _buildInfoItem(
                    Icons.wifi,
                    ipAddress,
                  ),
                  // Status
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: AppTheme.darkTextSecondary,
                      ),
                      const SizedBox(width: 8),
                      StatusIndicator(
                        status: status,
                        showLabel: true,
                      ),
                    ],
                  ),
                  // Last Active
                  _buildInfoItem(
                    Icons.access_time,
                    lastActive,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.darkTextSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.darkTextSecondary,
          ),
        ),
      ],
    );
  }
}