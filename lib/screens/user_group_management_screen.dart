import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_group_provider.dart';
import '../providers/websocket_provider_optimized.dart';
import '../providers/camera_devices_provider_optimized.dart';
import '../models/user.dart';
import '../models/camera_group.dart';
import '../models/camera_device.dart';
import '../models/permissions.dart';
import '../theme/app_theme.dart';

class UserGroupManagementScreen extends StatefulWidget {
  const UserGroupManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserGroupManagementScreen> createState() => _UserGroupManagementScreenState();
}

class _UserGroupManagementScreenState extends State<UserGroupManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for operation results and show snackbar
    return Consumer<UserGroupProvider>(
      builder: (context, userGroupProvider, _) {
        // Show snackbar when there's an operation result
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (userGroupProvider.lastOperationMessage != null) {
            final message = userGroupProvider.lastOperationMessage!;
            final isSuccess = userGroupProvider.lastOperationSuccess ?? false;
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: isSuccess ? Colors.green : Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
            
            // Clear the message after showing
            userGroupProvider.clearOperationResult();
          }
        });
        
        return _buildScaffold(context);
      },
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Kullanıcı ve Grup Yönetimi'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryBlue,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(
              icon: Icon(Icons.people),
              text: 'Kullanıcılar',
            ),
            Tab(
              icon: Icon(Icons.shield),
              text: 'Yetki Grupları',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(),
          _buildGroupsTab(),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showCreateUserDialog,
              backgroundColor: AppTheme.primaryBlue,
              icon: const Icon(Icons.person_add),
              label: const Text('Kullanıcı Ekle'),
            )
          : FloatingActionButton.extended(
              onPressed: _showCreateGroupDialog,
              backgroundColor: AppTheme.primaryBlue,
              icon: const Icon(Icons.group_add),
              label: const Text('Yetki Grubu Ekle'),
            ),
    );
  }

  Widget _buildUsersTab() {
    return Consumer<UserGroupProvider>(
      builder: (context, provider, child) {
        final users = provider.usersList;
        
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'Henüz kullanıcı bilgisi yok',
                  style: TextStyle(fontSize: 18, color: Colors.grey[400]),
                ),
                const SizedBox(height: 8),
                Text(
                  'WebSocket bağlantısından kullanıcı verileri bekleniyor...',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            if (provider.usersCreated != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppTheme.primaryBlue.withOpacity(0.2),
                child: Text(
                  'Kullanıcılar oluşturulma tarihi: ${provider.usersCreated}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _buildUserCard(user);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: AppTheme.darkSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getUserTypeColor(user.usertype),
                  child: Icon(
                    _getUserTypeIcon(user.usertype),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            user.username,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: user.active ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              user.active ? 'AKTİF' : 'PASİF',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        user.fullname,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey[700]),
            const SizedBox(height: 8),
            _buildUserInfoRow('Kullanıcı Türü', user.usertype.toUpperCase()),
            _buildUserInfoRow(
              'Oluşturulma Tarihi',
              _formatTimestamp(user.created),
            ),
            _buildUserInfoRow(
              'Son Giriş',
              _formatTimestamp(user.lastlogin),
            ),
            if (user.usertype == 'admin') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings, 
                         color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Yönetici Yetkisi',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Kullanıcının gruplarını ve yetkilerini göster
            _buildUserGroupsAndPermissions(context, user),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showChangePasswordDialog(user),
                  icon: const Icon(Icons.lock_reset, size: 16),
                  label: const Text('Şifre Değiştir'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showDeleteUserDialog(user),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Sil'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsTab() {
    return Consumer<UserGroupProvider>(
      builder: (context, provider, child) {
        final groups = provider.groupsList;
        
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'Henüz yetki grubu yok',
                  style: TextStyle(fontSize: 18, color: Colors.grey[400]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sağ alttaki butona tıklayarak yeni yetki grubu oluşturun',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return _buildGroupCard(group);
          },
        );
      },
    );
  }

  Widget _buildGroupCard(CameraGroup group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: AppTheme.darkSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups, color: AppTheme.primaryBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGroupInfoSection('Kameralar', group.cameraMacs),
            const SizedBox(height: 12),
            _buildGroupInfoSection('Kullanıcılar', group.users),
            if (group.permissions.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPermissionsSection(group.permissions),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _navigateToCameraAssignment(group),
                  icon: const Icon(Icons.videocam, size: 16),
                  label: const Text('Kamera Eşleştir'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showModifyGroupDialog(group),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Düzenle'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showDeleteGroupDialog(group),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Sil'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupInfoSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            'Henüz $title eklenmemiş',
            style: TextStyle(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: items.map((item) => Chip(
              label: Text(
                item,
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.3),
              side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.5)),
            )).toList(),
          ),
      ],
    );
  }

  Widget _buildPermissionsSection(Map<String, dynamic> permissions) {
    // Parse permission string or number
    Set<Permission> grantedPermissions = {};
    if (permissions.containsKey('permissions')) {
      // New format: permissions directly (can be string or number like 1111100000000000)
      final permValue = permissions['permissions'];
      grantedPermissions = Permissions.parsePermissionString(permValue);
      print('✅ Parsed permissions from value: $permValue -> ${grantedPermissions.map((p) => p.code).toList()}');
    } else if (permissions.containsKey('permissionString')) {
      // Legacy format
      final permString = permissions['permissionString'].toString();
      grantedPermissions = Permissions.parsePermissionString(permString);
      print('✅ Parsed permissions from string: $permString -> ${grantedPermissions.map((p) => p.code).toList()}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Yetkiler',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 8),
        if (grantedPermissions.isEmpty)
          Text(
            'Yetki bulunamadı',
            style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: grantedPermissions.map((permission) {
              return Chip(
                avatar: Icon(
                  permission.icon,
                  color: Colors.white,
                  size: 16,
                ),
                label: Text(
                  permission.name,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
                backgroundColor: AppTheme.primaryBlue.withOpacity(0.7),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
      ],
    );
  }

  Color _getUserTypeColor(String userType) {
    switch (userType.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'guvenlik':
        return Colors.blue;
      case 'user':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getUserTypeIcon(String userType) {
    switch (userType.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'guvenlik':
        return Icons.security;
      case 'user':
        return Icons.person;
      default:
        return Icons.person_outline;
    }
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return 'Bilinmiyor';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      return DateFormat('dd.MM.yyyy HH:mm').format(date);
    } catch (e) {
      return 'Geçersiz tarih';
    }
  }

  Widget _buildUserGroupsAndPermissions(BuildContext context, User user) {
    final userGroupProvider = Provider.of<UserGroupProvider>(context, listen: false);
    
    // Bu kullanıcının ait olduğu grupları bul
    final userGroups = userGroupProvider.groupsList.where((group) => 
      group.users.contains(user.username)
    ).toList();
    
    if (userGroups.isEmpty) {
      return const SizedBox(height: 8);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Kullanıcı Grupları ve Yetkileri',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[400],
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        ...userGroups.map((group) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.groups, color: AppTheme.primaryBlue, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (group.permissions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    // Parse permissions
                    Set<Permission> grantedPerms = {};
                    if (group.permissions.containsKey('permissions')) {
                      grantedPerms = Permissions.parsePermissionString(group.permissions['permissions']);
                    } else if (group.permissions.containsKey('permissionString')) {
                      grantedPerms = Permissions.parsePermissionString(group.permissions['permissionString']);
                    }
                    
                    if (grantedPerms.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 24, top: 4),
                        child: Text(
                          'Yetki bulunamadı',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      );
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.only(left: 24, top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: grantedPerms.map((perm) => Chip(
                          avatar: Icon(perm.icon, color: Colors.white, size: 12),
                          label: Text(
                            perm.name,
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                          backgroundColor: Colors.green.withOpacity(0.7),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )).toList(),
                      ),
                    );
                  },
                ),
              ],
              if (group.cameraMacs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Row(
                    children: [
                      Icon(Icons.videocam, color: Colors.grey[400], size: 14),
                      const SizedBox(width: 8),
                      Text(
                        '${group.cameraMacs.length} kamera',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        )).toList(),
      ],
    );
  }

  // ============= USER DIALOGS =============

  void _showCreateUserDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    String? selectedGroup;

    final userGroupProvider = Provider.of<UserGroupProvider>(context, listen: false);
    final availableGroups = userGroupProvider.groupsList.map((g) => g.name).toList();

    // If no groups available, add some default options
    if (availableGroups.isEmpty) {
      availableGroups.addAll(['admin', 'operator', 'user', 'viewer']);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Yeni Kullanıcı Oluştur', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Tam Ad',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedGroup,
                dropdownColor: AppTheme.darkSurface,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Yetki Grubu',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                ),
                items: availableGroups.map((group) {
                  return DropdownMenuItem<String>(
                    value: group,
                    child: Text(group),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedGroup = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (usernameController.text.isEmpty ||
                  passwordController.text.isEmpty ||
                  nameController.text.isEmpty ||
                  selectedGroup == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tüm alanları doldurun')),
                );
                return;
              }

              final wsProvider = Provider.of<WebSocketProviderOptimized>(
                context,
                listen: false,
              );

              await wsProvider.sendCreateUser(
                usernameController.text,
                passwordController.text,
                nameController.text,
                selectedGroup!,
              );

              Navigator.pop(context);
              
              // Mesaj WebSocket'ten gelecek ve otomatik gösterilecek
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            child: const Text('Oluştur'),
          ),
        ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(User user) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(
          '${user.username} - Şifre Değiştir',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Yeni Şifre',
            labelStyle: TextStyle(color: Colors.grey[400]),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Şifre girmelisiniz')),
                );
                return;
              }

              final wsProvider = Provider.of<WebSocketProviderOptimized>(
                context,
                listen: false,
              );

              await wsProvider.sendChangePassword(
                user.username,
                passwordController.text,
              );

              Navigator.pop(context);
              
              // Mesaj WebSocket'ten gelecek ve otomatik gösterilecek
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            child: const Text('Değiştir'),
          ),
        ],
      ),
    );
  }

  void _showDeleteUserDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Kullanıcıyı Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '${user.username} kullanıcısını silmek istediğinizden emin misiniz?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final wsProvider = Provider.of<WebSocketProviderOptimized>(
                context,
                listen: false,
              );

              await wsProvider.sendDeleteUser(user.username);

              Navigator.pop(context);
              
              // Mesaj WebSocket'ten gelecek ve otomatik gösterilecek
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // ============= GROUP DIALOGS =============

  void _showCreateGroupDialog() {
    final groupNameController = TextEditingController();
    final descriptionController = TextEditingController();
    final selectedPermissions = <Permission>{};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Yeni Yetki Grubu Oluştur', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 500,
          height: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              TextField(
                controller: groupNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Grup Adı',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Açıklama',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Yetkiler:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: Permissions.all.length,
                  itemBuilder: (context, index) {
                    final permission = Permissions.all[index];
                    final isSelected = selectedPermissions.contains(permission);
                    
                    return CheckboxListTile(
                      title: Text(
                        permission.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        permission.description,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      value: isSelected,
                      activeColor: AppTheme.primaryBlue,
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            selectedPermissions.add(permission);
                          } else {
                            selectedPermissions.remove(permission);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          ), // SingleChildScrollView closing
        ), // SizedBox closing
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (groupNameController.text.isEmpty ||
                  descriptionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tüm alanları doldurun')),
                );
                return;
              }

              final wsProvider = Provider.of<WebSocketProviderOptimized>(
                context,
                listen: false,
              );

              // Convert permissions to string format
              final permissionString = Permissions.toPermissionString(selectedPermissions);
              print('Creating group with permission string: $permissionString');

              await wsProvider.sendCreateGroup(
                groupNameController.text,
                descriptionController.text,
                permissionString,
              );

              Navigator.pop(context);
              
              // Mesaj WebSocket'ten gelecek ve otomatik gösterilecek
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            child: const Text('Oluştur'),
          ),
        ],
        ),
      ),
    );
  }

  void _showModifyGroupDialog(CameraGroup group) {
    final descriptionController = TextEditingController();
    
    // Parse existing permissions from group
    Set<Permission> selectedPermissions = {};
    // Check if permissions contain the permission value (new format)
    if (group.permissions.containsKey('permissions')) {
      final permValue = group.permissions['permissions'];
      selectedPermissions = Permissions.parsePermissionString(permValue);
      print('🔧 Loaded permissions for ${group.name}: $permValue -> ${selectedPermissions.map((p) => p.code).toList()}');
    } else if (group.permissions.containsKey('permissionString')) {
      // Legacy format
      final permString = group.permissions['permissionString'].toString();
      selectedPermissions = Permissions.parsePermissionString(permString);
    } else if (group.permissions.isNotEmpty) {
      // Very old legacy: try to match permission names
      for (var entry in group.permissions.entries) {
        final perm = Permissions.getByCode(entry.key);
        if (perm != null && (entry.value == true || entry.value == 1 || entry.value == '1')) {
          selectedPermissions.add(perm);
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(
          '${group.name} - Yetki Grubu Düzenle',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 500,
          height: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            TextField(
              controller: descriptionController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Açıklama',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Yetkiler:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: Permissions.all.length,
                itemBuilder: (context, index) {
                  final permission = Permissions.all[index];
                  final isSelected = selectedPermissions.contains(permission);
                  
                  return CheckboxListTile(
                    title: Text(
                      permission.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      permission.description,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: isSelected,
                    activeColor: AppTheme.primaryBlue,
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          selectedPermissions.add(permission);
                        } else {
                          selectedPermissions.remove(permission);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
          ), // Column closing
          ), // SingleChildScrollView closing
        ), // SizedBox closing
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (descriptionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Açıklama alanını doldurun')),
                );
                return;
              }

              final wsProvider = Provider.of<WebSocketProviderOptimized>(
                context,
                listen: false,
              );

              // Convert permissions to string format
              final permissionString = Permissions.toPermissionString(selectedPermissions);
              print('Modifying group with permission string: $permissionString');

              await wsProvider.sendModifyGroup(
                group.name,
                descriptionController.text,
                permissionString,
              );

              Navigator.pop(context);
              
              // Mesaj WebSocket'ten gelecek ve otomatik gösterilecek
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            child: const Text('Güncelle'),
          ),
        ],
      ),
      ), // StatefulBuilder closing
    );
  }

  void _showDeleteGroupDialog(CameraGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Yetki Grubunu Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '${group.name} yetki grubunu silmek istediğinizden emin misiniz?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final wsProvider = Provider.of<WebSocketProviderOptimized>(
                context,
                listen: false,
              );

              await wsProvider.sendDeleteGroup(group.name);

              Navigator.pop(context);
              
              // Mesaj WebSocket'ten gelecek ve otomatik gösterilecek
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // ============= NAVIGATION =============

  // Show dialog to assign cameras to a group
  Future<void> _navigateToCameraAssignment(CameraGroup group) async {
    final cameraProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    
    // Get all available cameras
    final allCameras = cameraProvider.cameras.where((c) => c.mac.isNotEmpty && !c.mac.startsWith('m_')).toList();
    
    // Track selected cameras (initially select cameras already in the group)
    final selectedCameraMacs = Set<String>.from(group.cameraMacs);
    
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _CameraSelectionDialog(
        groupName: group.name,
        allCameras: allCameras,
        initialSelectedMacs: selectedCameraMacs,
      ),
    );
    
    if (result != null) {
      // Send camera assignments to server via WebSocket
      await _assignCamerasToGroup(group.name, result);
    }
  }

  // Assign cameras to group by sending WebSocket messages
  Future<void> _assignCamerasToGroup(String groupName, Set<String> selectedCameraMacs) async {
    try {
      final wsProvider = Provider.of<WebSocketProviderOptimized>(context, listen: false);
      
      print('UGM: Assigning ${selectedCameraMacs.length} cameras to group $groupName');
      
      // Send individual WebSocket messages for each camera
      int successCount = 0;
      int failCount = 0;
      
      for (final cameraMac in selectedCameraMacs) {
        try {
          // Send ADD_GROUP_TO_CAM command for each camera
          // Format: ADD_GROUP_TO_CAM <camera_mac> <group_name>
          // Example: ADD_GROUP_TO_CAM e8:b7:23:0c:11:b2 timko1
          final success = await wsProvider.sendAddGroupToCamera(cameraMac, groupName);
          
          if (success) {
            successCount++;
            print('UGM: ✅ Successfully assigned camera $cameraMac to group $groupName');
          } else {
            failCount++;
            print('UGM: ❌ Failed to assign camera $cameraMac to group $groupName');
          }
          
          // Small delay between messages to avoid overwhelming the server
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          failCount++;
          print('UGM: ❌ Error assigning camera $cameraMac: $e');
        }
      }
      
      // Show result
      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount kamera başarıyla $groupName grubuna atandı'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount başarılı, $failCount başarısız'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      setState(() {
        // Trigger refresh
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        // Refresh UI
      });
    }
  }
}

// Dialog for selecting cameras to assign to a group
class _CameraSelectionDialog extends StatefulWidget {
  final String groupName;
  final List<Camera> allCameras;
  final Set<String> initialSelectedMacs;

  const _CameraSelectionDialog({
    required this.groupName,
    required this.allCameras,
    required this.initialSelectedMacs,
  });

  @override
  _CameraSelectionDialogState createState() => _CameraSelectionDialogState();
}

class _CameraSelectionDialogState extends State<_CameraSelectionDialog> {
  late Set<String> _selectedMacs;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedMacs = Set<String>.from(widget.initialSelectedMacs);
  }

  @override
  Widget build(BuildContext context) {
    // Filter cameras by search query
    final filteredCameras = widget.allCameras.where((camera) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return camera.name.toLowerCase().contains(query) ||
          camera.ip.toLowerCase().contains(query) ||
          camera.mac.toLowerCase().contains(query);
    }).toList();

    return Dialog(
      backgroundColor: AppTheme.darkBackground,
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.video_library, color: AppTheme.primaryOrange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kamera Eşleştir',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Grup: ${widget.groupName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Kamera ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 12),

            // Selection info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.primaryOrange),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedMacs.length} kamera seçildi',
                    style: TextStyle(color: AppTheme.primaryOrange),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedMacs.clear();
                      });
                    },
                    child: const Text('Tümünü Temizle'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedMacs.addAll(filteredCameras.map((c) => c.mac));
                      });
                    },
                    child: const Text('Tümünü Seç'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Camera list
            Expanded(
              child: filteredCameras.isEmpty
                  ? const Center(
                      child: Text('Kamera bulunamadı'),
                    )
                  : ListView.builder(
                      itemCount: filteredCameras.length,
                      itemBuilder: (context, index) {
                        final camera = filteredCameras[index];
                        final isSelected = _selectedMacs.contains(camera.mac);

                        return Card(
                          color: isSelected
                              ? AppTheme.primaryOrange.withOpacity(0.1)
                              : Colors.grey[850],
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedMacs.add(camera.mac);
                                } else {
                                  _selectedMacs.remove(camera.mac);
                                }
                              });
                            },
                            title: Text(
                              camera.name.isEmpty ? 'Unknown Camera' : camera.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('MAC: ${camera.mac}'),
                                if (camera.ip.isNotEmpty) Text('IP: ${camera.ip}'),
                                if (camera.brand.isNotEmpty) Text('Brand: ${camera.brand}'),
                              ],
                            ),
                            secondary: Icon(
                              camera.connected ? Icons.videocam : Icons.videocam_off,
                              color: camera.connected ? Colors.green : Colors.grey,
                            ),
                            activeColor: AppTheme.primaryOrange,
                          ),
                        );
                      },
                    ),
            ),

            const Divider(),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(_selectedMacs);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
