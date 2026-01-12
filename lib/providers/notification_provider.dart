import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Notification types for different message categories
enum NotificationType {
  success,
  error,
  warning,
  info,
}

/// A notification message with metadata
class AppNotification {
  final String id;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final String? cameraName;
  final String? cameraMac;
  bool isRead;

  AppNotification({
    required this.id,
    required this.message,
    required this.type,
    required this.timestamp,
    this.cameraName,
    this.cameraMac,
    this.isRead = false,
  });

  /// Get icon based on notification type
  IconData get icon {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning_amber_rounded;
      case NotificationType.info:
        return Icons.info;
    }
  }

  /// Get color based on notification type
  Color get color {
    switch (type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.info:
        return Colors.blue;
    }
  }

  /// Format timestamp for display
  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s önce';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}dk önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}sa önce';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Provider to manage session notifications
class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  static const int maxNotifications = 100; // Keep last 100 notifications

  /// Get all notifications (newest first)
  List<AppNotification> get notifications => List.unmodifiable(_notifications.reversed.toList());

  /// Get unread notifications count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Check if there are any unread notifications
  bool get hasUnread => unreadCount > 0;

  /// Add a new notification
  void addNotification({
    required String message,
    required NotificationType type,
    String? cameraName,
    String? cameraMac,
  }) {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: type,
      timestamp: DateTime.now(),
      cameraName: cameraName,
      cameraMac: cameraMac,
    );

    _notifications.add(notification);

    // Remove oldest if exceeds max
    if (_notifications.length > maxNotifications) {
      _notifications.removeAt(0);
    }

    notifyListeners();
  }

  /// Helper methods for common notification types
  void addSuccess(String message, {String? cameraName, String? cameraMac}) {
    addNotification(
      message: message,
      type: NotificationType.success,
      cameraName: cameraName,
      cameraMac: cameraMac,
    );
  }

  void addError(String message, {String? cameraName, String? cameraMac}) {
    addNotification(
      message: message,
      type: NotificationType.error,
      cameraName: cameraName,
      cameraMac: cameraMac,
    );
  }

  void addWarning(String message, {String? cameraName, String? cameraMac}) {
    addNotification(
      message: message,
      type: NotificationType.warning,
      cameraName: cameraName,
      cameraMac: cameraMac,
    );
  }

  void addInfo(String message, {String? cameraName, String? cameraMac}) {
    addNotification(
      message: message,
      type: NotificationType.info,
      cameraName: cameraName,
      cameraMac: cameraMac,
    );
  }

  /// Mark a notification as read
  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  void markAllAsRead() {
    for (var notification in _notifications) {
      notification.isRead = true;
    }
    notifyListeners();
  }

  /// Clear all notifications
  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }

  /// Remove a specific notification
  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  /// Get notifications by type
  List<AppNotification> getByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList().reversed.toList();
  }

  /// Get notifications for a specific camera
  List<AppNotification> getByCameraMac(String mac) {
    return _notifications.where((n) => n.cameraMac == mac).toList().reversed.toList();
  }
}

/// Global helper class for showing SnackBars and logging to NotificationProvider
/// Usage: AppSnackBar.show(context, 'Message', type: NotificationType.success);
class AppSnackBar {
  /// Show a SnackBar and log it to NotificationProvider
  static void show(
    BuildContext context,
    String message, {
    NotificationType type = NotificationType.info,
    String? cameraName,
    String? cameraMac,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    // Get the notification provider and add the notification
    try {
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      notificationProvider.addNotification(
        message: message,
        type: type,
        cameraName: cameraName,
        cameraMac: cameraMac,
      );
    } catch (e) {
      // Provider not available, just show SnackBar
      debugPrint('NotificationProvider not available: $e');
    }

    // Get color based on type
    Color backgroundColor;
    switch (type) {
      case NotificationType.success:
        backgroundColor = Colors.green;
        break;
      case NotificationType.error:
        backgroundColor = Colors.red;
        break;
      case NotificationType.warning:
        backgroundColor = Colors.orange;
        break;
      case NotificationType.info:
        backgroundColor = Colors.blue;
        break;
    }

    // Show SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        action: action,
      ),
    );
  }

  /// Show a success SnackBar
  static void success(BuildContext context, String message, {String? cameraName, String? cameraMac}) {
    show(context, message, type: NotificationType.success, cameraName: cameraName, cameraMac: cameraMac);
  }

  /// Show an error SnackBar
  static void error(BuildContext context, String message, {String? cameraName, String? cameraMac}) {
    show(context, message, type: NotificationType.error, cameraName: cameraName, cameraMac: cameraMac);
  }

  /// Show a warning SnackBar
  static void warning(BuildContext context, String message, {String? cameraName, String? cameraMac}) {
    show(context, message, type: NotificationType.warning, cameraName: cameraName, cameraMac: cameraMac);
  }

  /// Show an info SnackBar
  static void info(BuildContext context, String message, {String? cameraName, String? cameraMac}) {
    show(context, message, type: NotificationType.info, cameraName: cameraName, cameraMac: cameraMac);
  }
}
