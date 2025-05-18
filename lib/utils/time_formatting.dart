
/// Extension methods for formatting time values
extension UptimeFormatting on String {
  /// Formats a seconds-based uptime string to a human-readable format
  String formatUptime() {
    // Try parsing as seconds (numeric format)
    final int? seconds = int.tryParse(this);
    if (seconds != null) {
      final int days = seconds ~/ 86400;
      final int hours = (seconds % 86400) ~/ 3600;
      final int minutes = (seconds % 3600) ~/ 60;
      final int remainingSeconds = seconds % 60;
      
      if (days > 0) {
        return '${days}d ${hours}h ${minutes}m';
      } else if (hours > 0) {
        return '${hours}h ${minutes}m ${remainingSeconds}s';
      } else if (minutes > 0) {
        return '${minutes}m ${remainingSeconds}s';
      } else {
        return '${remainingSeconds}s';
      }
    }
    
    // If it's already formatted or can't be parsed, return as is
    return this;
  }
}
