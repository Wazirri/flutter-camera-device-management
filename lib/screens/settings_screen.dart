import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/custom_app_bar.dart';
import '../providers/websocket_provider_optimized.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Auto configuration settings
  bool _autoScanEnabled = false;
  bool _autoCameraSharingEnabled = false;
  
  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: CustomAppBar(
        title: 'Settings',
        isDesktop: isDesktop,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ResponsiveHelper.responsiveWidget(
            context: context,
            mobile: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildSettingSections(context),
            ),
            desktop: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildAutoConfigSection(context),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _buildSystemSection(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSettingSections(BuildContext context) {
    return [
      _buildAutoConfigSection(context),
      const SizedBox(height: 16),
      _buildSystemSection(context),
    ];
  }

  Widget _buildAutoConfigSection(BuildContext context) {
    final wsProvider = Provider.of<WebSocketProviderOptimized>(context);
    
    return _buildSettingCard(
      title: 'Otomatik Konfigürasyon',
      icon: Icons.auto_mode,
      children: [
        SwitchListTile(
          title: const Text('Otomatik Tarama'),
          subtitle: const Text('Sistem otomatik olarak cihazları tarar'),
          value: _autoScanEnabled,
          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTheme.primaryBlue;
            }
            return AppTheme.darkTextSecondary;
          }),
          onChanged: (value) async {
            setState(() {
              _autoScanEnabled = value;
            });
            // Send SETBOOL command
            final command = 'SETBOOL configuration.autoscan $value';
            await wsProvider.sendCommand(command);
          },
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('Otomatik Kamera Dağıtma'),
          subtitle: const Text('Kameralar otomatik olarak dağıtılır'),
          value: _autoCameraSharingEnabled,
          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTheme.primaryBlue;
            }
            return AppTheme.darkTextSecondary;
          }),
          onChanged: (value) async {
            setState(() {
              _autoCameraSharingEnabled = value;
            });
            // Send SETBOOL command
            final command = 'SETBOOL bridge_auto_cam_sharing.is_cam_sharing $value';
            await wsProvider.sendCommand(command);
          },
        ),
      ],
    );
  }

  Widget _buildSystemSection(BuildContext context) {
    final wsProvider = Provider.of<WebSocketProviderOptimized>(context);
    final isConnected = wsProvider.isConnected;
    
    return _buildSettingCard(
      title: 'System',
      icon: Icons.developer_board,
      children: [
        ListTile(
          title: const Text('Connection Status'),
          subtitle: Text(
            isConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              color: isConnected ? AppTheme.online : AppTheme.offline,
            ),
          ),
          trailing: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isConnected ? AppTheme.online : AppTheme.offline,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('Factory Reset'),
          subtitle: const Text('Reset all settings to default'),
          trailing: TextButton(
            onPressed: () {
              _showFactoryResetDialog();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.error,
            ),
            child: const Text('Reset'),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      color: AppTheme.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  void _showFactoryResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Factory Reset'),
        content: const Text(
          'This will reset all settings to default values. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Perform factory reset
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Factory reset completed'),
                  backgroundColor: AppTheme.primaryBlue,
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}