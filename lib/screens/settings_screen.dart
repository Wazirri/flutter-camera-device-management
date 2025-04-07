import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/custom_app_bar.dart';
import '../providers/websocket_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _emailAlertsEnabled = false;
  bool _autoUpdateEnabled = true;
  double _storageLimit = 70;
  String _videoQuality = 'High';
  String _retentionPeriod = '30 Days';
  
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
                      _buildGeneralSettingsSection(context),
                      const SizedBox(height: 16),
                      _buildStorageSection(context),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _buildNotificationSection(context),
                      const SizedBox(height: 16),
                      _buildSecuritySection(context),
                      const SizedBox(height: 16),
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
      _buildGeneralSettingsSection(context),
      const SizedBox(height: 16),
      _buildNotificationSection(context),
      const SizedBox(height: 16),
      _buildStorageSection(context),
      const SizedBox(height: 16),
      _buildSecuritySection(context),
      const SizedBox(height: 16),
      _buildSystemSection(context),
    ];
  }

  Widget _buildGeneralSettingsSection(BuildContext context) {
    return _buildSettingCard(
      title: 'General Settings',
      icon: Icons.settings,
      children: [
        _buildDropdownSetting(
          title: 'Video Quality',
          value: _videoQuality,
          options: const ['Low', 'Medium', 'High', 'Ultra'],
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _videoQuality = newValue;
              });
            }
          },
        ),
        const Divider(),
        _buildDropdownSetting(
          title: 'Retention Period',
          value: _retentionPeriod,
          options: const ['7 Days', '14 Days', '30 Days', '60 Days', '90 Days'],
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _retentionPeriod = newValue;
              });
            }
          },
        ),
        const Divider(),
        ListTile(
          title: const Text('Time Zone'),
          subtitle: const Text('UTC+00:00 (Auto)'),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // UI only
            },
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('Date Format'),
          subtitle: const Text('YYYY-MM-DD'),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // UI only
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSection(BuildContext context) {
    return _buildSettingCard(
      title: 'Notifications',
      icon: Icons.notifications_outlined,
      children: [
        SwitchListTile(
          title: const Text('Enable Notifications'),
          subtitle: const Text('Receive alerts for important events'),
          value: _notificationsEnabled,
          activeColor: AppTheme.accentColor,
          onChanged: (value) {
            setState(() {
              _notificationsEnabled = value;
            });
          },
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('Email Alerts'),
          subtitle: const Text('Receive alerts via email'),
          value: _emailAlertsEnabled,
          activeColor: AppTheme.accentColor,
          onChanged: (value) {
            setState(() {
              _emailAlertsEnabled = value;
            });
          },
        ),
        const Divider(),
        ExpansionTile(
          title: const Text('Notification Types'),
          children: [
            CheckboxListTile(
              title: const Text('Motion Detection'),
              value: true,
              onChanged: (bool? value) {
                // UI only
              },
              activeColor: AppTheme.accentColor,
            ),
            CheckboxListTile(
              title: const Text('Device Status Changes'),
              value: true,
              onChanged: (bool? value) {
                // UI only
              },
              activeColor: AppTheme.accentColor,
            ),
            CheckboxListTile(
              title: const Text('System Updates'),
              value: false,
              onChanged: (bool? value) {
                // UI only
              },
              activeColor: AppTheme.accentColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStorageSection(BuildContext context) {
    return _buildSettingCard(
      title: 'Storage',
      icon: Icons.storage_outlined,
      children: [
        ListTile(
          title: const Text('Storage Usage'),
          subtitle: Text('${_storageLimit.toInt()}% of available space'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: LinearProgressIndicator(
            value: _storageLimit / 100,
            backgroundColor: AppTheme.darkBackground,
            valueColor: AlwaysStoppedAnimation<Color>(
              _storageLimit > 90
                  ? AppTheme.errorColor
                  : _storageLimit > 70
                      ? AppTheme.warningColor
                      : AppTheme.accentColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        ListTile(
          title: const Text('Storage Limit'),
          subtitle: Text('${_storageLimit.toInt()}% of available space'),
          trailing: SizedBox(
            width: 120,
            child: Slider(
              value: _storageLimit,
              min: 10,
              max: 100,
              divisions: 9,
              label: '${_storageLimit.toInt()}%',
              onChanged: (double value) {
                setState(() {
                  _storageLimit = value;
                });
              },
              activeColor: AppTheme.accentColor,
            ),
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('Cleanup Old Recordings'),
          subtitle: const Text('Automatically delete recordings older than retention period'),
          trailing: ElevatedButton(
            onPressed: () {
              // UI only
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
            ),
            child: const Text('Clean Up'),
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection(BuildContext context) {
    return _buildSettingCard(
      title: 'Security',
      icon: Icons.security_outlined,
      children: [
        ListTile(
          title: const Text('Change Password'),
          leading: const Icon(Icons.lock_outline),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // UI only
          },
        ),
        const Divider(),
        ListTile(
          title: const Text('Two-Factor Authentication'),
          subtitle: const Text('Disabled'),
          leading: const Icon(Icons.phonelink_lock),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // UI only
          },
        ),
        const Divider(),
        ListTile(
          title: const Text('API Keys'),
          subtitle: const Text('Manage API access'),
          leading: const Icon(Icons.vpn_key_outlined),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // UI only
          },
        ),
        const Divider(),
        ListTile(
          title: const Text('Session Management'),
          subtitle: const Text('Manage active sessions'),
          leading: const Icon(Icons.devices_outlined),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // UI only
          },
        ),
      ],
    );
  }

  Widget _buildSystemSection(BuildContext context) {
    return _buildSettingCard(
      title: 'System',
      icon: Icons.system_update_outlined,
      children: [
        SwitchListTile(
          title: const Text('Automatic Updates'),
          subtitle: const Text('Keep system up to date automatically'),
          value: _autoUpdateEnabled,
          activeColor: AppTheme.accentColor,
          onChanged: (value) {
            setState(() {
              _autoUpdateEnabled = value;
            });
          },
        ),
        const Divider(),
        const ListTile(
          title: Text('Current Version'),
          subtitle: Text('v1.2.0'),
          trailing: Text('Up to date', style: TextStyle(color: AppTheme.online)),
        ),
        const Divider(),
        Consumer<WebSocketProvider>(
          builder: (context, provider, child) {
            final isConnected = provider.isConnected;
            return ListTile(
              title: const Text('WebSocket Logs'),
              subtitle: Text(isConnected 
                ? 'View WebSocket communication logs (Connected)'
                : 'View WebSocket communication logs (Disconnected)'
              ),
              leading: Icon(
                Icons.wifi_tethering,
                color: isConnected ? AppTheme.online : AppTheme.offline,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pushNamed(context, '/websocket-logs');
              },
            );
          },
        ),
        const Divider(),
        ListTile(
          title: const Text('System Logs'),
          subtitle: const Text('View system logs and diagnostic information'),
          trailing: IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () {
              // UI only
            },
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('Backup & Restore'),
          subtitle: const Text('Backup system settings or restore from backup'),
          trailing: IconButton(
            icon: const Icon(Icons.backup_outlined),
            onPressed: () {
              // UI only
            },
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('Factory Reset'),
          subtitle: const Text('Reset all settings to default values'),
          trailing: TextButton(
            onPressed: () {
              _showFactoryResetDialog();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
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
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDropdownSetting({
    required String title,
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        onChanged: onChanged,
        items: options.map<DropdownMenuItem<String>>((String option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
        dropdownColor: AppTheme.darkSurface,
        underline: Container(),
      ),
    );
  }

  void _showFactoryResetDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: const Text('Factory Reset'),
          content: const Text(
            'Are you sure you want to reset all settings to default values? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // UI only
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
}