import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_group_provider.dart';
import '../providers/websocket_provider_optimized.dart';
import '../models/user.dart';
import '../models/camera_group.dart';
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
        ...permissions.entries.map((entry) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(
                entry.value == true || entry.value == 1 || entry.value == '1'
                    ? Icons.check_circle
                    : Icons.info_outline,
                color: entry.value == true || entry.value == 1 || entry.value == '1'
                    ? Colors.green
                    : AppTheme.primaryBlue,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        )).toList(),
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

              final success = await wsProvider.sendCreateUser(
                usernameController.text,
                passwordController.text,
                nameController.text,
                selectedGroup!,
              );

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Kullanıcı oluşturuldu'
                        : 'Kullanıcı oluşturulamadı',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
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

              final success = await wsProvider.sendChangePassword(
                user.username,
                passwordController.text,
              );

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? 'Şifre değiştirildi' : 'Şifre değiştirilemedi',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
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

              final success = await wsProvider.sendDeleteUser(user.username);

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? 'Kullanıcı silindi' : 'Kullanıcı silinemedi',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
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
    final permissionsController = TextEditingController(text: 'view');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Yeni Yetki Grubu Oluştur', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
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
              TextField(
                controller: permissionsController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'İzinler',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                  hintText: 'view,record,user_management',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'İzin seçenekleri: view, record, user_management',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
              if (groupNameController.text.isEmpty ||
                  descriptionController.text.isEmpty ||
                  permissionsController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tüm alanları doldurun')),
                );
                return;
              }

              final wsProvider = Provider.of<WebSocketProviderOptimized>(
                context,
                listen: false,
              );

              final success = await wsProvider.sendCreateGroup(
                groupNameController.text,
                descriptionController.text,
                permissionsController.text,
              );

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? 'Grup oluşturuldu' : 'Grup oluşturulamadı',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  void _showModifyGroupDialog(CameraGroup group) {
    final descriptionController = TextEditingController();
    final permissionsController = TextEditingController(
      text: group.permissions.entries.map((e) => e.key).join(','),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(
          '${group.name} - Yetki Grubu Düzenle',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
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
            TextField(
              controller: permissionsController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'İzinler',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                hintText: 'view,record,user_management',
                hintStyle: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (descriptionController.text.isEmpty ||
                  permissionsController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tüm alanları doldurun')),
                );
                return;
              }

              final wsProvider = Provider.of<WebSocketProviderOptimized>(
                context,
                listen: false,
              );

              final success = await wsProvider.sendModifyGroup(
                group.name,
                descriptionController.text,
                permissionsController.text,
              );

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? 'Grup güncellendi' : 'Grup güncellenemedi',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            child: const Text('Güncelle'),
          ),
        ],
      ),
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

              final success = await wsProvider.sendDeleteGroup(group.name);

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? 'Grup silindi' : 'Grup silinemedi',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
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

  void _navigateToCameraAssignment(CameraGroup group) {
    Navigator.pushNamed(
      context,
      '/camera-groups',
      arguments: group.name, // Grup adını argüman olarak gönder
    );
  }
}
