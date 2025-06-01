import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/custom_app_bar.dart';
import '../providers/websocket_provider_optimized.dart';
import '../providers/multi_camera_view_provider.dart';

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
                      _buildCameraLayoutSettingsSection(context),
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
      _buildCameraLayoutSettingsSection(context),
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
          activeThumbColor: AppTheme.primaryBlue,
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
          activeThumbColor: AppTheme.primaryBlue,
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
  
  // CAM_GROUP_ADD group_name komutu için dialog
  void _showAddCameraGroupDialog(BuildContext context, WebSocketProviderOptimized provider) {
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
                'This will execute: CAM_GROUP_ADD [group_name]',
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
                  final command = 'CAM_GROUP_ADD $groupName';
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
  void _showChangeWiFiDialog(BuildContext context, WebSocketProviderOptimized provider) {
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

  Widget _buildCameraLayoutSettingsSection(BuildContext context) {
    final multiCameraProvider = Provider.of<MultiCameraViewProvider>(context);
    
    return _buildSettingCard(
      title: 'Camera Layout Settings',
      icon: Icons.grid_view,
      children: [
        SwitchListTile(
          title: const Text('Auto-Assignment Mode'),
          subtitle: const Text('Automatically assign cameras in sequence'),
          value: multiCameraProvider.isAutoAssignmentMode,
          activeThumbColor: AppTheme.primaryBlue,
          onChanged: (value) {
            multiCameraProvider.toggleAssignmentMode();
          },
        ),
        const Divider(),
        ListTile(
          title: const Text('Default Layout'),
          subtitle: Text('Current layout: ${multiCameraProvider.pageLayouts.isNotEmpty ? multiCameraProvider.pageLayouts[multiCameraProvider.activePageIndex] : 5}'),
          trailing: ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/camera-layout-assignment');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            child: const Text('Edit'),
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('Manage Layout Presets'),
          subtitle: Text('${multiCameraProvider.presetNames.length} saved presets'),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showPresetManagerFromSettings(context, multiCameraProvider);
            },
          ),
        ),
        const Divider(),
        // Quick action buttons for layout management
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.autorenew, size: 16),
                label: const Text('Quick Setup'),
                onPressed: () => _showQuickSetupDialog(context, multiCameraProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('Reset Layouts'),
                onPressed: () => _showResetLayoutsDialog(context, multiCameraProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        ExpansionTile(
          title: const Text('Layout Customization'),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit Layouts'),
                    onPressed: () {
                      Navigator.pushNamed(context, '/camera-layout-assignment');
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add Page'),
                    onPressed: () {
                      multiCameraProvider.addPage();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('New page added'))
                      );
                    },
                  ),
                  if (multiCameraProvider.pageLayouts.length > 1)
                    ActionChip(
                      avatar: const Icon(Icons.remove_circle_outline, size: 18),
                      label: const Text('Remove Page'),
                      onPressed: () {
                        multiCameraProvider.removePage();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Page removed'))
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showDefaultLayoutDialog(BuildContext context, MultiCameraViewProvider provider) {
    // Mevcut düzeni gösteren bir dialog
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Default Layout'),
          backgroundColor: AppTheme.darkSurface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This is the current default layout for cameras.'),
              const SizedBox(height: 16),
              // Mevcut düzenin önizlemesi
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Layout ${provider.pageLayouts[provider.activePageIndex]}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'You can change the default layout in the Camera Layout Settings section.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showPresetManagerFromSettings(BuildContext context, MultiCameraViewProvider provider) {
    final TextEditingController presetNameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Camera Assignment Presets'),
              backgroundColor: AppTheme.darkSurface,
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Save new preset section
                    if (provider.presetNames.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'No saved presets yet',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),

                    if (provider.presetNames.isNotEmpty) ...[
                      const Text(
                        'Saved Presets:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: provider.presetNames.length,
                          itemBuilder: (context, index) {
                            final presetName = provider.presetNames[index];
                            return ListTile(
                              title: Text(presetName),
                              leading: const Icon(Icons.photo_library),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: () {
                                      provider.loadPreset(presetName);
                                      Navigator.pop(context);
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Preset "$presetName" loaded')),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: AppTheme.darkSurface,
                                          title: const Text('Delete Preset'),
                                          content: Text('Are you sure you want to delete "$presetName"?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                provider.deletePreset(presetName);
                                                Navigator.pop(context);
                                                setState(() {}); // Refresh the list
                                                
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Preset "$presetName" deleted')),
                                                );
                                              },
                                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                provider.loadPreset(presetName);
                                Navigator.pop(context);
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Preset "$presetName" loaded')),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    const Text(
                      'Save Current Layout:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: presetNameController,
                            decoration: const InputDecoration(
                              hintText: 'Enter preset name',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (presetNameController.text.isNotEmpty) {
                              provider.savePresetWithName(presetNameController.text);
                              presetNameController.clear();
                              setState(() {}); // Refresh the list
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Preset saved successfully')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a preset name')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                          ),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showEditPresetDialog(BuildContext context, MultiCameraViewProvider provider, String presetName) {
    final TextEditingController controller = TextEditingController(text: presetName);
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Layout Preset'),
          backgroundColor: AppTheme.darkSurface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Update the name of the layout preset:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Preset Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                ),
                autofocus: true,
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
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  // Ön ayarı güncelle
                  provider.updatePresetName(presetName, newName);
                  Navigator.pop(dialogContext);
                } else {
                  // Boş isim uyarısı
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Preset name cannot be empty'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: const Text('Update Preset'),
            ),
          ],
        );
      },
    );
  }

  void _showDeletePresetDialog(BuildContext context, MultiCameraViewProvider provider, String presetName) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Layout Preset'),
          backgroundColor: AppTheme.darkSurface,
          content: const Text('Are you sure you want to delete this layout preset? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Ön ayarı sil
                provider.deletePreset(presetName);
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
              ),
              child: const Text('Delete Preset'),
            ),
          ],
        );
      },
    );
  }

  void _showSavePresetDialog(BuildContext context, MultiCameraViewProvider provider) {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Save New Layout Preset'),
          backgroundColor: AppTheme.darkSurface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter a name for the new layout preset:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Preset Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.save),
                ),
                autofocus: true,
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
              onPressed: () {
                final presetName = controller.text.trim();
                if (presetName.isNotEmpty) {
                  // Yeni ön ayar kaydet
                  provider.savePreset(presetName);
                  Navigator.pop(dialogContext);
                } else {
                  // Boş isim uyarısı
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Preset name cannot be empty'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: const Text('Save Preset'),
            ),
          ],
        );
      },
    );
  }

  void _showQuickSetupDialog(BuildContext context, MultiCameraViewProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Quick Setup'),
          backgroundColor: AppTheme.darkSurface,
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('This will automatically set up the camera layout with optimal settings.'),
              SizedBox(height: 8),
              Text(
                'The system will:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Reset to the default layout (2x2 grid)'),
              Text('• Auto-assign cameras if automatic mode is enabled'),
              Text('• Clear any custom layouts'),
              SizedBox(height: 8),
              Text(
                'This operation cannot be undone.',
                style: TextStyle(color: Colors.amber),
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
              onPressed: () async {
                final success = await provider.sendCommand('DO SCRIPT quick_setup');
                
                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                        ? 'Camera layout configured successfully'
                        : 'Failed to configure camera layout',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: const Text('Apply Quick Setup'),
            ),
          ],
        );
      },
    );
  }

  void _showResetLayoutsDialog(BuildContext context, MultiCameraViewProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset Layouts'),
          backgroundColor: AppTheme.darkSurface,
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to reset all camera layouts to default?'),
              SizedBox(height: 8),
              Text(
                'This will:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Clear all custom layouts'),
              Text('• Reset to a single page with 2x2 grid'),
              Text('• Clear all camera assignments'),
              SizedBox(height: 8),
              Text(
                'This operation cannot be undone.',
                style: TextStyle(color: Colors.red),
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
              onPressed: () async {
                final success = await provider.sendCommand('DO SCRIPT reset_layouts');
                
                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                        ? 'Camera layouts reset successfully'
                        : 'Failed to reset camera layouts',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
              ),
              child: const Text('Reset Layouts'),
            ),
          ],
        );
      },
    );
  }

  // Add quick actions to the UI
  Widget _buildQuickActionButtons(BuildContext context, MultiCameraViewProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.autorenew),
          label: const Text('Quick Setup'),
          onPressed: () => _showQuickSetupDialog(context, provider),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.restore),
          label: const Text('Reset Layouts'),
          onPressed: () => _showResetLayoutsDialog(context, provider),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.error,
          ),
        ),
      ],
    );
  }
}