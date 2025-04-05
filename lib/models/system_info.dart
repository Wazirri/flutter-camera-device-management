class SystemInfo {
  final String? cpuTemp;
  final String? upTime;
  final String? freeRam;
  final String? totalRam;
  final String? usedRam;
  final String? cpuUsage;
  final String? diskFree;
  final String? diskTotal;
  final String? diskUsed;
  
  SystemInfo({
    this.cpuTemp,
    this.upTime,
    this.freeRam,
    this.totalRam,
    this.usedRam,
    this.cpuUsage,
    this.diskFree,
    this.diskTotal,
    this.diskUsed,
  });
  
  factory SystemInfo.fromJson(Map<String, dynamic> json) {
    return SystemInfo(
      cpuTemp: json['cpuTemp']?.toString(),
      upTime: json['upTime']?.toString(),
      freeRam: json['freeRam']?.toString(),
      totalRam: json['totalRam']?.toString(),
      usedRam: json['usedRam']?.toString(),
      cpuUsage: json['cpuUsage']?.toString(),
      diskFree: json['diskFree']?.toString(),
      diskTotal: json['diskTotal']?.toString(),
      diskUsed: json['diskUsed']?.toString(),
    );
  }
  
  // Helper methods to get numeric values
  double? getCpuTempValue() {
    return cpuTemp != null ? double.tryParse(cpuTemp!) : null;
  }
  
  int? getUpTimeValue() {
    return upTime != null ? int.tryParse(upTime!) : null;
  }
  
  double? getCpuUsageValue() {
    return cpuUsage != null ? double.tryParse(cpuUsage!) : null;
  }
  
  // Format uptime into human readable form
  String formatUptime() {
    int? seconds = getUpTimeValue();
    if (seconds == null) return "Unknown";
    
    int days = seconds ~/ 86400;
    seconds %= 86400;
    int hours = seconds ~/ 3600;
    seconds %= 3600;
    int minutes = seconds ~/ 60;
    seconds %= 60;
    
    if (days > 0) {
      return "${days}d ${hours}h ${minutes}m";
    } else if (hours > 0) {
      return "${hours}h ${minutes}m ${seconds}s";
    } else {
      return "${minutes}m ${seconds}s";
    }
  }
}
