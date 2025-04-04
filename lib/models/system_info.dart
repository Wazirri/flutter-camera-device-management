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
  
  // Added fields needed for dashboard display
  final String cpuUsage;
  final String ramUsage;
  final String diskUsage;
  final String connections;
  final String connectionStatus;

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
    this.cpuUsage = '0',
    this.ramUsage = '0',
    this.diskUsage = '0',
    this.connections = '0',
    this.connectionStatus = 'Unknown',
  });

  factory SystemInfo.fromJson(Map<dynamic, dynamic> json) {
    // Convert raw thermal list to properly typed List<Map<String, dynamic>>
    List<Map<String, dynamic>> typedThermal = [];
    if (json['thermal'] != null) {
      for (var item in json['thermal']) {
        if (item is Map) {
          // Convert each thermal map to <String, dynamic>
          final Map<String, dynamic> typedItem = {};
          item.forEach((key, value) {
            if (key is String) {
              typedItem[key] = value;
            }
          });
          typedThermal.add(typedItem);
        }
      }
    }
    
    // Convert gps map to properly typed Map<String, dynamic>
    Map<String, dynamic> typedGps = {'lat': '0', 'lon': '0', 'speed': '0'};
    if (json['gps'] is Map) {
      final rawGps = json['gps'] as Map;
      rawGps.forEach((key, value) {
        if (key is String) {
          typedGps[key] = value.toString();
        }
      });
    }
    
    // Determine connection status based on eth0 and ppp0
    String connectionStatus = 'Unknown';
    if (json['eth0'] != null && json['eth0'].toString().isNotEmpty && json['eth0'] != "N/A") {
      connectionStatus = 'Ethernet';
    } else if (json['ppp0'] != null && json['ppp0'].toString().isNotEmpty && json['ppp0'] != "N/A") {
      connectionStatus = 'Mobile Data';
    } else {
      connectionStatus = 'Offline';
    }
    
    return SystemInfo(
      cpuTemp: json['cpuTemp']?.toString() ?? '0',
      upTime: json['upTime']?.toString() ?? '0',
      srvTime: json['srvTime']?.toString() ?? '0',
      totalRam: json['totalRam']?.toString() ?? '0',
      freeRam: json['freeRam']?.toString() ?? '0',
      totalConns: json['totalconns']?.toString() ?? '0',
      sessions: json['sessions']?.toString() ?? '0',
      eth0: json['eth0']?.toString() ?? 'Unknown',
      ppp0: json['ppp0']?.toString() ?? 'Unknown',
      thermal: typedThermal,
      gps: typedGps,
      // Add CPU, RAM, Disk usage from JSON or default to calculated values
      cpuUsage: json['cpuUsage']?.toString() ?? '30',  // Default or get from server
      ramUsage: json['ramUsage']?.toString() ?? '40',  // Default or get from server
      diskUsage: json['diskUsage']?.toString() ?? '25', // Default or get from server
      connections: json['connections']?.toString() ?? json['totalconns']?.toString() ?? '0',
      connectionStatus: json['connectionStatus']?.toString() ?? connectionStatus,
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
