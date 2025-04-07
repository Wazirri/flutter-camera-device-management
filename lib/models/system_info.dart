import 'dart:convert';

class SystemInfo {
  // CPU info
  final String cpuTemp;
  final String cpuModel;
  final String cpuCores;
  
  // Memory info
  final String memTotal;
  final String memUsed;
  final String memFree;
  
  // Disk info
  final String diskTotal;
  final String diskUsed;
  final String diskFree;
  
  // System info
  final String upTime;
  final String version;
  final String hostname;
  
  // Additional stats
  final int cameraCount;
  final int recordingCount;

  SystemInfo({
    required this.cpuTemp,
    required this.cpuModel,
    required this.cpuCores,
    required this.memTotal,
    required this.memUsed,
    required this.memFree,
    required this.diskTotal,
    required this.diskUsed,
    required this.diskFree,
    required this.upTime,
    required this.version,
    required this.hostname,
    required this.cameraCount,
    required this.recordingCount,
  });
  
  factory SystemInfo.fromJson(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    
    return SystemInfo(
      // CPU information
      cpuTemp: json['cpuTemp'] ?? '0',
      cpuModel: json['cpuModel'] ?? 'Unknown CPU',
      cpuCores: json['cpuCores'] ?? '0',
      
      // Memory information (convert to MB if needed)
      memTotal: json['memTotal'] ?? '0',
      memUsed: json['memUsed'] ?? '0',
      memFree: json['memFree'] ?? '0',
      
      // Disk information (convert to GB if needed)
      diskTotal: json['diskTotal'] ?? '0',
      diskUsed: json['diskUsed'] ?? '0',
      diskFree: json['diskFree'] ?? '0',
      
      // System information
      upTime: json['upTime'] ?? '0',
      version: json['version'] ?? 'Unknown',
      hostname: json['hostname'] ?? 'Unknown',
      
      // Additional stats (mock data if not available)
      cameraCount: int.tryParse(json['cameraCount'] ?? '0') ?? 0,
      recordingCount: int.tryParse(json['recordingCount'] ?? '0') ?? 0,
    );
  }
}
