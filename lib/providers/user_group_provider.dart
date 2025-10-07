import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/camera_group.dart';

class UserGroupProvider with ChangeNotifier {
  final Map<String, User> _users = {};
  final Map<String, CameraGroup> _groups = {};
  String? _usersCreated;
  
  // Batch notifications to reduce UI rebuilds
  bool _needsNotification = false;
  Timer? _notificationDebounceTimer;
  final int _notificationBatchWindow = 100; // milliseconds
  
  // Getters
  Map<String, User> get users => Map.unmodifiable(_users);
  Map<String, CameraGroup> get groups => Map.unmodifiable(_groups);
  List<User> get usersList => _users.values.toList();
  List<CameraGroup> get groupsList => _groups.values.toList();
  String? get usersCreated => _usersCreated;

  // Process WebSocket messages
  void processWebSocketMessage(Map<String, dynamic> message) {
    try {
      final command = message['c'];
      final data = message['data'] as String?;
      final value = message['val'];

      if (command == 'changed' && data != null) {
        if (data.startsWith('users.')) {
          _processUserMessage(data, value);
        } else if (data.startsWith('groups.')) {
          _processGroupMessage(data, value);
        }
      } else if (command == 'changedone') {
        final name = message['name'] as String?;
        if (name == 'users') {
          print('UGP: Users data update completed');
          // Update group memberships based on user types
          updateUserGroupMembership();
          _batchNotifyListeners();
        } else if (name == 'groups') {
          print('UGP: Groups data update completed');
          _batchNotifyListeners();
        }
      }
    } catch (e) {
      print('UGP: Error processing WebSocket message: $e');
    }
  }

  // Process user messages
  void _processUserMessage(String data, dynamic value) {
    try {
      final parts = data.split('.');
      
      if (parts.length >= 2) {
        if (parts[1] == 'created') {
          _usersCreated = value?.toString();
          print('UGP: Users created timestamp: $_usersCreated');
          _batchNotifyListeners();
          return;
        }

        if (parts.length >= 3) {
          final username = parts[1];
          final property = parts[2];

          // Initialize user if doesn't exist
          if (!_users.containsKey(username)) {
            _users[username] = User(
              username: username,
              password: '',
              fullname: '',
              usertype: '',
              active: false,
              created: 0,
              lastlogin: 0,
            );
          }

          // Update user property
          final currentUser = _users[username]!;
          switch (property) {
            case 'username':
              _users[username] = currentUser.copyWith(username: value?.toString() ?? '');
              break;
            case 'password':
              _users[username] = currentUser.copyWith(password: value?.toString() ?? '');
              break;
            case 'fullname':
              _users[username] = currentUser.copyWith(fullname: value?.toString() ?? '');
              break;
            case 'usertype':
              _users[username] = currentUser.copyWith(usertype: value?.toString() ?? '');
              // Update group membership when usertype changes
              updateUserGroupMembership();
              break;
            case 'active':
              final isActive = (value == 1 || value == '1' || value == true);
              _users[username] = currentUser.copyWith(active: isActive);
              break;
            case 'created':
              final timestamp = value is int ? value : (int.tryParse(value?.toString() ?? '0') ?? 0);
              _users[username] = currentUser.copyWith(created: timestamp);
              break;
            case 'lastlogin':
              final timestamp = value is int ? value : (int.tryParse(value?.toString() ?? '0') ?? 0);
              _users[username] = currentUser.copyWith(lastlogin: timestamp);
              break;
          }

          print('UGP: Updated user $username.$property = $value');
          _batchNotifyListeners();
        }
      }
    } catch (e) {
      print('UGP: Error processing user message: $e');
    }
  }

  // Process group messages
  void _processGroupMessage(String data, dynamic value) {
    try {
      final parts = data.split('.');
      
      if (parts.length >= 3) {
        final groupName = parts[1];
        final property = parts[2];

        // Initialize group if doesn't exist
        if (!_groups.containsKey(groupName)) {
          _groups[groupName] = CameraGroup(
            name: groupName,
            cameraMacs: [],
            users: [],
            permissions: {},
          );
        }

        final currentGroup = _groups[groupName]!;

        // Handle different group properties
        if (property == 'cameras' && value is List) {
          // Full camera list update
          _groups[groupName] = CameraGroup(
            name: groupName,
            cameraMacs: List<String>.from(value),
            users: currentGroup.users,
            permissions: currentGroup.permissions,
          );
        } else if (property == 'users' && value is List) {
          // Full user list update
          _groups[groupName] = CameraGroup(
            name: groupName,
            cameraMacs: currentGroup.cameraMacs,
            users: List<String>.from(value),
            permissions: currentGroup.permissions,
          );
        } else if (property.startsWith('permission.')) {
          // Permission update
          final permissionKey = property.substring('permission.'.length);
          final newPermissions = Map<String, dynamic>.from(currentGroup.permissions);
          newPermissions[permissionKey] = value;
          
          _groups[groupName] = CameraGroup(
            name: groupName,
            cameraMacs: currentGroup.cameraMacs,
            users: currentGroup.users,
            permissions: newPermissions,
          );
        } else {
          // Generic property update stored in permissions
          final newPermissions = Map<String, dynamic>.from(currentGroup.permissions);
          newPermissions[property] = value;
          
          _groups[groupName] = CameraGroup(
            name: groupName,
            cameraMacs: currentGroup.cameraMacs,
            users: currentGroup.users,
            permissions: newPermissions,
          );
        }

        print('UGP: Updated group $groupName.$property = $value');
        _batchNotifyListeners();
      }
    } catch (e) {
      print('UGP: Error processing group message: $e');
    }
  }

  // Batch notify listeners to reduce UI rebuilds
  void _batchNotifyListeners() {
    _needsNotification = true;
    
    _notificationDebounceTimer?.cancel();
    _notificationDebounceTimer = Timer(Duration(milliseconds: _notificationBatchWindow), () {
      if (_needsNotification) {
        _needsNotification = false;
        notifyListeners();
      }
    });
  }

  // Get user by username
  User? getUser(String username) {
    return _users[username];
  }

  // Get group by name
  CameraGroup? getGroup(String groupName) {
    return _groups[groupName];
  }

  // Get users by type
  List<User> getUsersByType(String usertype) {
    return _users.values.where((user) => user.usertype == usertype).toList();
  }

  // Get active users
  List<User> getActiveUsers() {
    return _users.values.where((user) => user.active).toList();
  }

  // Process camera-to-group assignment from cameras_mac WebSocket messages
  void processCameraGroupAssignment(String cameraMac, List<String> groupNames) {
    try {
      // Remove this camera from all groups first
      for (var group in _groups.values) {
        group.removeCamera(cameraMac);
      }

      // Add camera to specified groups
      for (var groupName in groupNames) {
        if (!_groups.containsKey(groupName)) {
          // Create group if doesn't exist
          _groups[groupName] = CameraGroup(
            name: groupName,
            cameraMacs: [],
            users: [],
            permissions: {},
          );
        }
        _groups[groupName]!.addCamera(cameraMac);
        print('UGP: Added camera $cameraMac to group $groupName');
      }

      _batchNotifyListeners();
    } catch (e) {
      print('UGP: Error processing camera group assignment: $e');
    }
  }

  // Update user's group membership
  void updateUserGroupMembership() {
    try {
      // Clear all users from all groups first
      for (var group in _groups.values) {
        group.users.clear();
      }

      // Add users to their groups based on usertype
      for (var user in _users.values) {
        if (user.usertype.isNotEmpty) {
          if (!_groups.containsKey(user.usertype)) {
            // Create group if doesn't exist
            _groups[user.usertype] = CameraGroup(
              name: user.usertype,
              cameraMacs: [],
              users: [],
              permissions: {},
            );
          }
          _groups[user.usertype]!.addUser(user.username);
          print('UGP: Added user ${user.username} to group ${user.usertype}');
        }
      }

      _batchNotifyListeners();
    } catch (e) {
      print('UGP: Error updating user group membership: $e');
    }
  }

  // Sync camera assignments from camera groups (called from CameraDevicesProvider)
  void syncCameraGroupsFromProvider(Map<String, CameraGroup> cameraGroupsMap) {
    try {
      // Update camera assignments for groups that exist in CameraDevicesProvider
      for (var entry in cameraGroupsMap.entries) {
        final groupName = entry.key;
        final cameraGroup = entry.value;

        // Get or create group in UserGroupProvider if it doesn't exist
        if (!_groups.containsKey(groupName)) {
          _groups[groupName] = CameraGroup(
            name: groupName,
            cameraMacs: [],
            users: [],
            permissions: {},
          );
          print('UGP: Created new group from camera assignments: $groupName');
        }

        // Update ONLY camera assignments, keep users and permissions from WebSocket
        _groups[groupName] = CameraGroup(
          name: groupName,
          cameraMacs: List<String>.from(cameraGroup.cameraMacs),
          users: _groups[groupName]!.users, // Keep existing users from WebSocket
          permissions: _groups[groupName]!.permissions, // Keep existing permissions from WebSocket
        );
        print('UGP: Updated camera assignments for group "$groupName": ${cameraGroup.cameraMacs.length} cameras');
      }

      // Also clear camera assignments for groups that don't have any cameras in CameraDevicesProvider
      // but still exist in UserGroupProvider (permission groups without camera assignments)
      for (var groupName in _groups.keys) {
        if (!cameraGroupsMap.containsKey(groupName)) {
          // This group has no camera assignments, clear its cameraMacs list
          _groups[groupName] = CameraGroup(
            name: groupName,
            cameraMacs: [], // Clear camera assignments
            users: _groups[groupName]!.users,
            permissions: _groups[groupName]!.permissions,
          );
          print('UGP: Cleared camera assignments for group "$groupName" (no cameras assigned)');
        }
      }

      print('UGP: Synced camera assignments from CameraDevicesProvider. Total groups: ${_groups.length}, Groups with cameras: ${cameraGroupsMap.length}');
      _batchNotifyListeners();
    } catch (e) {
      print('UGP: Error syncing camera groups: $e');
    }
  }

  // Handle operation results (success/error messages)
  String? _lastOperationMessage;
  bool? _lastOperationSuccess;
  
  String? get lastOperationMessage => _lastOperationMessage;
  bool? get lastOperationSuccess => _lastOperationSuccess;
  
  void handleOperationResult({required bool success, required String message}) {
    _lastOperationSuccess = success;
    _lastOperationMessage = message;
    print('UGP: Operation result - Success: $success, Message: $message');
    notifyListeners();
  }
  
  void clearOperationResult() {
    _lastOperationSuccess = null;
    _lastOperationMessage = null;
  }

  // Clear all data
  void clear() {
    _users.clear();
    _groups.clear();
    _usersCreated = null;
    _lastOperationMessage = null;
    _lastOperationSuccess = null;
    _notificationDebounceTimer?.cancel();
    _needsNotification = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _notificationDebounceTimer?.cancel();
    super.dispose();
  }
}
