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
  final String version; // Versiyon bilgisi eklendi

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
    required this.version,
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
      version: json['version']?.toString() ?? 'Unknown',
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