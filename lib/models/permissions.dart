import 'package:flutter/material.dart';

/// Permission definitions for the system
/// Each permission has a position (0-15) in the permission string
class Permission {
  final int position;
  final String name;
  final String code;
  final String description;
  final IconData icon;

  const Permission({
    required this.position,
    required this.name,
    required this.code,
    required this.description,
    required this.icon,
  });
}

/// Global list of all permissions
class Permissions {
  static const List<Permission> all = [
    Permission(
      position: 0,
      name: 'VIEW',
      code: 'view',
      description: 'Kameraları görüntüleme',
      icon: Icons.visibility,
    ),
    Permission(
      position: 1,
      name: 'RECORD',
      code: 'record',
      description: 'Kayıt başlatma/durdurma',
      icon: Icons.fiber_manual_record,
    ),
    Permission(
      position: 2,
      name: 'USER',
      code: 'user',
      description: 'Kullanıcı yönetimi',
      icon: Icons.person,
    ),
    Permission(
      position: 3,
      name: 'GROUP',
      code: 'group',
      description: 'Grup yönetimi',
      icon: Icons.group,
    ),
    Permission(
      position: 4,
      name: 'ADMIN',
      code: 'admin',
      description: 'Sistem yönetimi',
      icon: Icons.admin_panel_settings,
    ),
    Permission(
      position: 5,
      name: 'CAMERA',
      code: 'camera',
      description: 'Kamera ayarları',
      icon: Icons.videocam,
    ),
    Permission(
      position: 6,
      name: 'PLAYBACK',
      code: 'playback',
      description: 'Kayıt oynatma',
      icon: Icons.play_circle,
    ),
    Permission(
      position: 7,
      name: 'EXPORT',
      code: 'export',
      description: 'Kayıt dışa aktarma',
      icon: Icons.file_download,
    ),
    Permission(
      position: 8,
      name: 'PTZ',
      code: 'ptz',
      description: 'PTZ kontrolü',
      icon: Icons.control_camera,
    ),
    Permission(
      position: 9,
      name: 'AUDIO',
      code: 'audio',
      description: 'Ses kontrolü',
      icon: Icons.volume_up,
    ),
    Permission(
      position: 10,
      name: 'SETTINGS',
      code: 'settings',
      description: 'Sistem ayarları',
      icon: Icons.settings,
    ),
    Permission(
      position: 11,
      name: 'LOGS',
      code: 'logs',
      description: 'Log görüntüleme',
      icon: Icons.description,
    ),
    Permission(
      position: 12,
      name: 'BACKUP',
      code: 'backup',
      description: 'Yedekleme işlemleri',
      icon: Icons.backup,
    ),
    Permission(
      position: 13,
      name: 'NETWORK',
      code: 'network',
      description: 'Ağ ayarları',
      icon: Icons.network_check,
    ),
    Permission(
      position: 14,
      name: 'ALERTS',
      code: 'alerts',
      description: 'Alarm yönetimi',
      icon: Icons.notifications_active,
    ),
    Permission(
      position: 15,
      name: 'REPORTS',
      code: 'reports',
      description: 'Rapor görüntüleme',
      icon: Icons.assessment,
    ),
  ];

  /// Parse permission string/number to get enabled permissions
  /// Example: "1100000000000000" or 1100000000000000 = VIEW and RECORD enabled
  static Set<Permission> parsePermissionString(dynamic permValue) {
    final enabled = <Permission>{};
    
    // Convert to string if it's a number
    String permString;
    if (permValue is int || permValue is num) {
      permString = permValue.toString();
    } else if (permValue is String) {
      permString = permValue;
    } else {
      print('Invalid permission value type: ${permValue.runtimeType}');
      return enabled;
    }
    
    // Normalize the string (remove spaces)
    final normalized = permString.replaceAll(' ', '');
    
    if (normalized.length != 16) {
      print('Invalid permission string length: ${normalized.length}');
      return enabled;
    }
    
    for (var perm in all) {
      if (perm.position < normalized.length) {
        if (normalized[perm.position] == '1') {
          enabled.add(perm);
        }
      }
    }
    
    return enabled;
  }

  /// Convert set of permissions to permission string
  /// Example: {VIEW, RECORD} = "1100000000000000"
  static String toPermissionString(Set<Permission> permissions) {
    final chars = List.filled(16, '0');
    
    for (var perm in permissions) {
      if (perm.position < 16) {
        chars[perm.position] = '1';
      }
    }
    
    return chars.join();
  }

  /// Check if a permission string has a specific permission
  static bool hasPermission(String permString, String permissionCode) {
    final enabled = parsePermissionString(permString);
    return enabled.any((p) => p.code == permissionCode);
  }

  /// Get permission by code
  static Permission? getByCode(String code) {
    try {
      return all.firstWhere((p) => p.code == code);
    } catch (e) {
      return null;
    }
  }

  /// Get permission by position
  static Permission? getByPosition(int position) {
    try {
      return all.firstWhere((p) => p.position == position);
    } catch (e) {
      return null;
    }
  }
}
