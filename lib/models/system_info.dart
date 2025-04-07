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
  final int upTime;
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
  
  factory SystemInfo.fromJson(dynamic json) {
    // Handle both Map and String inputs
    Map<String, dynamic> jsonMap;
    if (json is String) {
      jsonMap = jsonDecode(json);
    } else if (json is Map<String, dynamic>) {
      jsonMap = json;
    } else {
      throw FormatException("Invalid JSON format for SystemInfo");
    }
    
    return SystemInfo(
      // CPU information
      cpuTemp: jsonMap['cpuTemp'] ?? '0',
      cpuModel: jsonMap['cpuModel'] ?? 'Unknown CPU',
      cpuCores: jsonMap['cpuCores'] ?? '0',
      
      // Memory information (convert to MB if needed)
      memTotal: jsonMap['memTotal'] ?? '0',
      memUsed: jsonMap['memUsed'] ?? '0',
      memFree: jsonMap['memFree'] ?? '0',
      
      // Disk information (convert to GB if needed)
      diskTotal: jsonMap['diskTotal'] ?? '0',
      diskUsed: jsonMap['diskUsed'] ?? '0',
      diskFree: jsonMap['diskFree'] ?? '0',
      
      // System information - convert upTime to int
      upTime: int.tryParse(jsonMap['upTime'] ?? '0') ?? 0,
      version: jsonMap['version'] ?? 'Unknown',
      hostname: jsonMap['hostname'] ?? 'Unknown',
      
      // Additional stats
      cameraCount: int.tryParse(jsonMap['cameraCount'] ?? '0') ?? 0,
      recordingCount: int.tryParse(jsonMap['recordingCount'] ?? '0') ?? 0,
    );
  }
}
