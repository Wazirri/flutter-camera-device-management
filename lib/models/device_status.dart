enum DeviceStatus {
  online,
  offline,
  warning,
  error,
  unknown,
}

// Utility extension for DeviceStatus
extension DeviceStatusExtension on DeviceStatus {
  String get label {
    switch (this) {
      case DeviceStatus.online:
        return 'Online';
      case DeviceStatus.offline:
        return 'Offline';
      case DeviceStatus.warning:
        return 'Warning';
      case DeviceStatus.error:
        return 'Error';
      case DeviceStatus.unknown:
      default:
        return 'Unknown';
    }
  }
  
  bool get isOnline => this == DeviceStatus.online;
  bool get isOffline => this == DeviceStatus.offline;
  bool get isWarning => this == DeviceStatus.warning;
  bool get isError => this == DeviceStatus.error;
}
