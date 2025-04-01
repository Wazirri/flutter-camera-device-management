import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'status_indicator.dart';

class DeviceListItem extends StatelessWidget {
  final String name;
  final String ip;
  final DeviceStatus status;
  final String? resolution;
  final List<String>? tags;
  final String? group;
  final VoidCallback? onTap;
  
  const DeviceListItem({
    Key? key,
    required this.name,
    required this.ip,
    required this.status,
    this.resolution,
    this.tags,
    this.group,
    this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusIndicator(
                    status: status,
                    showLabel: true,
                    size: 10.0,
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          ip,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16.0,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
              
              if (resolution != null || group != null || (tags != null && tags!.isNotEmpty)) ...[
                const SizedBox(height: 12.0),
                const Divider(height: 1.0),
                const SizedBox(height: 12.0),
                
                Row(
                  children: [
                    if (resolution != null) ...[
                      _buildInfoChip(
                        Icons.high_quality,
                        resolution!,
                      ),
                      const SizedBox(width: 8.0),
                    ],
                    
                    if (group != null) ...[
                      _buildInfoChip(
                        Icons.folder,
                        group!,
                      ),
                      const SizedBox(width: 8.0),
                    ],
                  ],
                ),
                
                if (tags != null && tags!.isNotEmpty) ...[
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 6.0,
                    children: tags!.map((tag) {
                      return Chip(
                        backgroundColor: AppTheme.darkCard,
                        label: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12.0,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14.0,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 4.0),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.0,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
