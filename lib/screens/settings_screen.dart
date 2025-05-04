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
  double _storageLimit = 70;
  String _videoQuality = 'High';
  String _retentionPeriod = '30 Days';
  
  // Kamera grubu için text controller
  final TextEditingController _groupNameController = TextEditingController();
  
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
          activeColor: AppTheme.primaryBlue,
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
          activeColor: AppTheme.primaryBlue,
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
              activeColor: AppTheme.primaryBlue,
            ),
            CheckboxListTile(
              title: const Text('Device Status Changes'),
              value: true,
              onChanged: (bool? value) {
                // UI only
              },
              activeColor: AppTheme.primaryBlue,
            ),
            CheckboxListTile(
              title: const Text('System Updates'),
              value: false,
              onChanged: (bool? value) {
                // UI only
              },
              activeColor: AppTheme.primaryBlue,
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
                  ? AppTheme.error
                  : _storageLimit > 70
                      ? AppTheme.warning
                      : AppTheme.primaryBlue,
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
              activeColor: AppTheme.primaryBlue,
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
              backgroundColor: AppTheme.primaryBlue,
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
    final wsProvider = Provider.of<WebSocketProvider>(context);
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
          trailing: Icon(
            isConnected ? Icons.check_circle : Icons.error_outline,
            color: isConnected ? AppTheme.online : AppTheme.offline,
          ),
          onTap: () {
            Navigator.pushNamed(context, '/websocket-logs');
          },
        ),
        const Divider(),
        ListTile(
          title: const Text('WebSocket Logs'),
          subtitle: Text(
            isConnected ? 'Connected to ${wsProvider.serverIp}' : 'Not connected',
            style: TextStyle(
              color: isConnected ? AppTheme.online : AppTheme.offline,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pushNamed(context, '/websocket-logs');
          },
        ),
        const Divider(),
        ListTile(
          title: const Text('Add Camera Group'),
          subtitle: const Text('Create a new camera group via script command'),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: isConnected ? () {
              _showAddCameraGroupDialog(context, wsProvider);
            } : null,
          ),
          enabled: isConnected,
        ),
        const Divider(),
        ListTile(
          title: const Text('Change WiFi Settings'),
          subtitle: const Text('Change WiFi name and password via script'),
          trailing: IconButton(
            icon: const Icon(Icons.wifi),
            onPressed: isConnected ? () {
              _showChangeWiFiDialog(context, wsProvider);
            } : null,
          ),
          enabled: isConnected,
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
                  color: AppTheme.primaryBlue,
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
                foregroundColor: AppTheme.error,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
  
  // DO SCRIPT add_camera_group "grup1" komutu için dialog
  void _showAddCameraGroupDialog(BuildContext context, WebSocketProvider provider) {
    _groupNameController.clear(); // Her seferinde text field'i temizle
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Camera Group'),
          backgroundColor: AppTheme.darkSurface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the name for the new camera group:'),
              const SizedBox(height: 16),
              TextField(
                controller: _groupNameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group_work),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              const Text(
                'This will execute: DO SCRIPT add_camera_group "[group_name]"',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              onPressed: () async {
                final groupName = _groupNameController.text.trim();
                if (groupName.isNotEmpty) {
                  // WebSocket üzerinden komutu gönder
                  final command = 'DO SCRIPT add_camera_group "$groupName"';
                  final success = await provider.sendCommand(command);
                  
                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);
                  
                  // Başarı durumunu bildir
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                          ? 'Camera group "$groupName" added successfully'
                          : 'Failed to add camera group',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                } else {
                  // Boş grup adı uyarısı
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a group name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Add Group'),
            ),
          ],
        );
      },
    );
  }

  // DO SCRIPT "wifichange" "new_name" "new_pw" komutu için dialog
  void _showChangeWiFiDialog(BuildContext context, WebSocketProvider provider) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Change WiFi Settings'),
          backgroundColor: AppTheme.darkSurface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter new WiFi credentials:'),
              const SizedBox(height: 16),
              
              // WiFi adı giriş alanı
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'WiFi Name (SSID)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
              ),
              const SizedBox(height: 16),
              
              // WiFi şifresi giriş alanı
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'WiFi Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will execute: DO SCRIPT "wifichange" "[name]" "[password]"',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final password = passwordController.text.trim();
                
                if (name.isNotEmpty && password.isNotEmpty) {
                  // WebSocket üzerinden komutu gönder
                  final command = 'DO SCRIPT "wifichange" "$name" "$password"';
                  final success = await provider.sendCommand(command);
                  
                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);
                  
                  // Sonuç bildirimi göster
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                          ? 'WiFi settings updated successfully'
                          : 'Failed to update WiFi settings',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                } else {
                  // Boş alan uyarısı
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Update WiFi'),
            ),
          ],
        );
      },
    );
  }
}