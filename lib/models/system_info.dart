class SystemInfo {
  final String? cpuTemp;
  final String? upTime;
  final String? srvTime;
  final String? freeRam;
  final String? totalRam;
  final String? usedRam;
  final String? cpuUsage;
  final String? diskFree;
  final String? diskTotal;
  final String? diskUsed;
  final String? totalConns;
  final String? sessions;
  final String? socThermal;
  final String? gpuThermal;
  final Map<String, dynamic> gps;
  final Map<String, dynamic> eth0;
  final Map<String, dynamic> ppp0;
  
  SystemInfo({
    this.cpuTemp,
    this.upTime,
    this.srvTime,
    this.freeRam,
    this.totalRam,
    this.usedRam,
    this.cpuUsage,
    this.diskFree,
    this.diskTotal,
    this.diskUsed,
    this.totalConns,
    this.sessions,
    this.socThermal,
    this.gpuThermal,
    Map<String, dynamic>? gps,
    Map<String, dynamic>? eth0,
    Map<String, dynamic>? ppp0,
  }) : 
    this.gps = gps ?? {'lat': '0.000000', 'lon': '0.000000', 'alt': '0', 'speed': '0'},
    this.eth0 = eth0 ?? {'ip': 'N/A', 'mac': 'N/A', 'status': 'disconnected'},
    this.ppp0 = ppp0 ?? {'ip': 'N/A', 'status': 'disconnected'};
  
  factory SystemInfo.fromJson(Map<String, dynamic> json) {
    return SystemInfo(
      cpuTemp: json['cpuTemp']?.toString(),
      upTime: json['upTime']?.toString(),
      srvTime: json['srvTime']?.toString(),
      freeRam: json['freeRam']?.toString(),
      totalRam: json['totalRam']?.toString(),
      usedRam: json['usedRam']?.toString(),
      cpuUsage: json['cpuUsage']?.toString(),
      diskFree: json['diskFree']?.toString(),
      diskTotal: json['diskTotal']?.toString(),
      diskUsed: json['diskUsed']?.toString(),
      totalConns: json['totalConns']?.toString(),
      sessions: json['sessions']?.toString(),
      socThermal: json['socThermal']?.toString() ?? 'N/A',
      gpuThermal: json['gpuThermal']?.toString() ?? 'N/A',
      gps: json['gps'] is Map ? Map<String, dynamic>.from(json['gps']) : null,
      eth0: json['eth0'] is Map ? Map<String, dynamic>.from(json['eth0']) : null,
      ppp0: json['ppp0'] is Map ? Map<String, dynamic>.from(json['ppp0']) : null,
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
  
  // Formatted getters
  String get formattedCpuTemp {
    if (cpuTemp == null) return 'N/A';
    double? temp = double.tryParse(cpuTemp!);
    return temp != null ? '${temp.toStringAsFixed(1)}°C' : 'N/A';
  }
  
  String get formattedUpTime {
    return formatTime(upTime);
  }
  
  String get formattedSrvTime {
    return formatTime(srvTime);
  }
  
  String get formattedTotalRam {
    if (totalRam == null) return 'N/A';
    try {
      double ram = double.parse(totalRam!) / (1024 * 1024);
      return '${ram.toStringAsFixed(2)} MB';
    } catch (e) {
      return totalRam!;
    }
  }
  
  String get formattedFreeRam {
    if (freeRam == null) return 'N/A';
    try {
      double ram = double.parse(freeRam!) / (1024 * 1024);
      return '${ram.toStringAsFixed(2)} MB';
    } catch (e) {
      return freeRam!;
    }
  }
  
  double get ramUsagePercentage {
    if (totalRam == null || freeRam == null) return 0.0;
    try {
      double total = double.parse(totalRam!);
      double free = double.parse(freeRam!);
      if (total <= 0) return 0.0;
      return ((total - free) / total) * 100;
    } catch (e) {
      return 0.0;
    }
  }
  
  String get gpsLocation {
    try {
      String lat = gps['lat']?.toString() ?? '0.000000';
      String lon = gps['lon']?.toString() ?? '0.000000';
      
      if (lat == '0.000000' && lon == '0.000000') {
        return 'No GPS data';
      }
      
      return '$lat, $lon';
    } catch (e) {
      return 'GPS Error';
    }
  }
  
  String get gpsSpeed {
    try {
      String speed = gps['speed']?.toString() ?? '0';
      double? speedValue = double.tryParse(speed);
      
      if (speedValue == null || speedValue <= 0) {
        return '0 km/h';
      }
      
      return '${speedValue.toStringAsFixed(1)} km/h';
    } catch (e) {
      return '0 km/h';
    }
  }
  
  // Format time (uptime or srvTime) into human readable form
  String formatTime(String? timeStr) {
    int? seconds = timeStr != null ? int.tryParse(timeStr) : null;
    if (seconds == null) return "N/A";
    
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
