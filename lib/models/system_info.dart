class SystemInfo {
  final String cpuTemp;
  final String upTime;
  final String srvTime;
  final String totalRam;
  final String freeRam;
  final String totalConns;
  final String sessions;
  final String eth0;
  final String ppp0;
  final List<Map<String, dynamic>> thermal;
  final Map<String, dynamic> gps;

  SystemInfo({
    required this.cpuTemp,
    required this.upTime,
    required this.srvTime,
    required this.totalRam,
    required this.freeRam,
    required this.totalConns,
    required this.sessions,
    required this.eth0,
    required this.ppp0,
    required this.thermal,
    required this.gps,
  });

  factory SystemInfo.fromJson(Map<String, dynamic> json) {
    return SystemInfo(
      cpuTemp: json['cpuTemp'] ?? '0',
      upTime: json['upTime'] ?? '0',
      srvTime: json['srvTime'] ?? '0',
      totalRam: json['totalRam'] ?? '0',
      freeRam: json['freeRam'] ?? '0',
      totalConns: json['totalconns'] ?? '0',
      sessions: json['sessions'] ?? '0',
      eth0: json['eth0'] ?? 'Unknown',
      ppp0: json['ppp0'] ?? 'Unknown',
      thermal: List<Map<String, dynamic>>.from(json['thermal'] ?? []),
      gps: json['gps'] ?? {'lat': '0', 'lon': '0', 'speed': '0'},
    );
  }

  // Helper methods for formatted values
  String get formattedCpuTemp => '$cpuTemp°C';
  
  String get formattedUpTime {
    final int seconds = int.tryParse(upTime) ?? 0;
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${hours}h ${minutes}m ${remainingSeconds}s';
  }
  
  String get formattedSrvTime {
    final int seconds = int.tryParse(srvTime) ?? 0;
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${hours}h ${minutes}m ${remainingSeconds}s';
  }
  
  String get formattedTotalRam {
    final double mb = (int.tryParse(totalRam) ?? 0) / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }
  
  String get formattedFreeRam {
    final double mb = (int.tryParse(freeRam) ?? 0) / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }
  
  double get ramUsagePercentage {
    final int total = int.tryParse(totalRam) ?? 1;
    final int free = int.tryParse(freeRam) ?? 0;
    if (total <= 0) return 0;
    final double used = (total - free) / total;
    return used * 100;
  }
  
  String get socThermal {
    for (final item in thermal) {
      if (item.containsKey('soc-thermal')) {
        return '${item['soc-thermal']}°C';
      }
    }
    return 'N/A';
  }
  
  String get gpuThermal {
    for (final item in thermal) {
      if (item.containsKey('gpu-thermal')) {
        return '${item['gpu-thermal']}°C';
      }
    }
    return 'N/A';
  }
  
  String get gpsLocation {
    final lat = gps['lat'] ?? '0';
    final lon = gps['lon'] ?? '0';
    if (lat == '0.000000' && lon == '0.000000') {
      return 'No GPS Signal';
    }
    return 'Lat: $lat, Lon: $lon';
  }
  
  String get gpsSpeed {
    final speed = gps['speed'] ?? '0';
    if (speed == '0.000000') {
      return '0 km/h';
    }
    final double speedValue = double.tryParse(speed) ?? 0;
    return '${speedValue.toStringAsFixed(2)} km/h';
  }
}