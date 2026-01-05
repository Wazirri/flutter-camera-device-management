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
  bool _masterHasCams = false;
  int _imbalanceThreshold = 2;
  
  // Network settings controllers
  final _defaultIpController = TextEditingController();
  final _defaultGwController = TextEditingController();
  final _defaultNetmaskController = TextEditingController();
  final _defaultDnsController = TextEditingController();
  final _defaultIpStartController = TextEditingController();
  final _defaultIpEndController = TextEditingController();
  
  // ONVIF password controllers
  final _onvifUserController = TextEditingController();
  final _onvifPassController = TextEditingController();
  List<String> _onvifPasswords = [];
  
  @override
  void dispose() {
    _defaultIpController.dispose();
    _defaultGwController.dispose();
    _defaultNetmaskController.dispose();
    _defaultDnsController.dispose();
    _defaultIpStartController.dispose();
    _defaultIpEndController.dispose();
    _onvifUserController.dispose();
    _onvifPassController.dispose();
    super.dispose();
  }
  
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
                      const SizedBox(height: 16),
                      _buildMasterConfigSection(context),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _buildNetworkSection(context),
                      const SizedBox(height: 16),
                      _buildOnvifPasswordsSection(context),
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
      _buildMasterConfigSection(context),
      const SizedBox(height: 16),
      _buildNetworkSection(context),
      const SizedBox(height: 16),
      _buildOnvifPasswordsSection(context),
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

  Widget _buildMasterConfigSection(BuildContext context) {
    final wsProvider = Provider.of<WebSocketProviderOptimized>(context);
    
    return _buildSettingCard(
      title: 'Master Kamera Dağıtım',
      icon: Icons.share,
      children: [
        SwitchListTile(
          title: const Text('Master\'a Kamera Ver'),
          subtitle: const Text('Master cihazın kamera almasını sağlar'),
          value: _masterHasCams,
          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTheme.primaryBlue;
            }
            return AppTheme.darkTextSecondary;
          }),
          onChanged: (value) async {
            setState(() {
              _masterHasCams = value;
            });
            final command = 'SETINT ecs.bridge_auto_cam_sharing.masterhascams ${value ? 1 : 0}';
            await wsProvider.sendCommand(command);
          },
        ),
        const Divider(),
        ListTile(
          title: const Text('Threshold Eşiği'),
          subtitle: Text('Slave\'ler arası kamera sayısı farkı: $_imbalanceThreshold'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _imbalanceThreshold > 1 ? () async {
                  setState(() {
                    _imbalanceThreshold--;
                  });
                  final command = 'SETINT ecs.bridge_auto_cam_sharing.last_scan_imbalance $_imbalanceThreshold';
                  await wsProvider.sendCommand(command);
                } : null,
              ),
              Text('$_imbalanceThreshold', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _imbalanceThreshold < 10 ? () async {
                  setState(() {
                    _imbalanceThreshold++;
                  });
                  final command = 'SETINT ecs.bridge_auto_cam_sharing.last_scan_imbalance $_imbalanceThreshold';
                  await wsProvider.sendCommand(command);
                } : null,
              ),
            ],
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('Zorla Dağıt'),
          subtitle: const Text('Değişiklik beklemeden tüm kameraları dağıt'),
          trailing: ElevatedButton.icon(
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Dağıt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final command = 'SETINT ecs.bridge_auto_cam_sharing.share_force 1';
              await wsProvider.sendCommand(command);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kamera dağıtım komutu gönderildi'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkSection(BuildContext context) {
    final wsProvider = Provider.of<WebSocketProviderOptimized>(context);
    
    return _buildSettingCard(
      title: 'Network Ayarları',
      icon: Icons.wifi,
      children: [
        _buildNetworkField(
          controller: _defaultIpController,
          label: 'Varsayılan IP',
          hint: '192.168.1.100',
          onSave: () async {
            if (_defaultIpController.text.isNotEmpty) {
              final command = 'SETSTRING networking.default_ip ${_defaultIpController.text}';
              await wsProvider.sendCommand(command);
            }
          },
        ),
        const SizedBox(height: 8),
        _buildNetworkField(
          controller: _defaultGwController,
          label: 'Varsayılan Gateway',
          hint: '192.168.1.1',
          onSave: () async {
            if (_defaultGwController.text.isNotEmpty) {
              final command = 'SETSTRING networking.default_gw ${_defaultGwController.text}';
              await wsProvider.sendCommand(command);
            }
          },
        ),
        const SizedBox(height: 8),
        _buildNetworkField(
          controller: _defaultNetmaskController,
          label: 'Varsayılan Netmask',
          hint: '255.255.255.0',
          onSave: () async {
            if (_defaultNetmaskController.text.isNotEmpty) {
              final command = 'SETSTRING networking.default_netmask ${_defaultNetmaskController.text}';
              await wsProvider.sendCommand(command);
            }
          },
        ),
        const SizedBox(height: 8),
        _buildNetworkField(
          controller: _defaultDnsController,
          label: 'Varsayılan DNS',
          hint: '8.8.8.8',
          onSave: () async {
            if (_defaultDnsController.text.isNotEmpty) {
              final command = 'SETSTRING networking.default_dns ${_defaultDnsController.text}';
              await wsProvider.sendCommand(command);
            }
          },
        ),
        const Divider(height: 24),
        const Text('DHCP IP Aralığı', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkTextSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildNetworkField(
                controller: _defaultIpStartController,
                label: 'Başlangıç IP',
                hint: '192.168.1.100',
                onSave: () async {
                  if (_defaultIpStartController.text.isNotEmpty) {
                    final command = 'SETSTRING networking.default_ip_start ${_defaultIpStartController.text}';
                    await wsProvider.sendCommand(command);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildNetworkField(
                controller: _defaultIpEndController,
                label: 'Bitiş IP',
                hint: '192.168.1.200',
                onSave: () async {
                  if (_defaultIpEndController.text.isNotEmpty) {
                    final command = 'SETSTRING networking.default_ip_end ${_defaultIpEndController.text}';
                    await wsProvider.sendCommand(command);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNetworkField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required VoidCallback onSave,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppTheme.darkTextPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppTheme.darkTextSecondary),
        hintStyle: TextStyle(color: AppTheme.darkTextSecondary.withOpacity(0.5)),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primaryBlue),
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.save, color: AppTheme.primaryBlue),
          onPressed: onSave,
          tooltip: 'Kaydet',
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      onSubmitted: (_) => onSave(),
    );
  }

  Widget _buildOnvifPasswordsSection(BuildContext context) {
    final wsProvider = Provider.of<WebSocketProviderOptimized>(context);
    
    return _buildSettingCard(
      title: 'ONVIF Kullanıcı/Şifre',
      icon: Icons.password,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _onvifUserController,
                style: const TextStyle(color: AppTheme.darkTextPrimary),
                decoration: InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  hintText: 'admin',
                  labelStyle: const TextStyle(color: AppTheme.darkTextSecondary),
                  hintStyle: TextStyle(color: AppTheme.darkTextSecondary.withOpacity(0.5)),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _onvifPassController,
                style: const TextStyle(color: AppTheme.darkTextPrimary),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  hintText: '******',
                  labelStyle: const TextStyle(color: AppTheme.darkTextSecondary),
                  hintStyle: TextStyle(color: AppTheme.darkTextSecondary.withOpacity(0.5)),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onPressed: () async {
                final user = _onvifUserController.text.trim();
                final pass = _onvifPassController.text.trim();
                if (user.isNotEmpty && pass.isNotEmpty) {
                  final credential = '$user:$pass';
                  final command = 'ARRAYADD configuration.onvif.passwords $credential';
                  await wsProvider.sendCommand(command);
                  setState(() {
                    _onvifPasswords.add(credential);
                    _onvifUserController.clear();
                    _onvifPassController.clear();
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kullanıcı adı ve şifre gerekli'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
          ],
        ),
        if (_onvifPasswords.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Kayıtlı Kullanıcılar:', style: TextStyle(color: AppTheme.darkTextSecondary)),
          const SizedBox(height: 8),
          ..._onvifPasswords.asMap().entries.map((entry) {
            final index = entry.key;
            final credential = entry.value;
            final parts = credential.split(':');
            final user = parts.isNotEmpty ? parts[0] : '';
            
            return ListTile(
              dense: true,
              leading: const Icon(Icons.person, color: AppTheme.primaryBlue, size: 20),
              title: Text(user, style: const TextStyle(color: AppTheme.darkTextPrimary)),
              subtitle: Text('••••••', style: TextStyle(color: Colors.grey[600])),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () async {
                  final command = 'ARRAYDEL configuration.onvif.passwords $index';
                  await wsProvider.sendCommand(command);
                  setState(() {
                    _onvifPasswords.removeAt(index);
                  });
                },
              ),
            );
          }),
        ],
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