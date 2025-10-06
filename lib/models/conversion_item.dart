class ConversionItem {
  final String cameraName;
  final String createTime;
  final String endTime;
  final String filePath;
  final String format;
  final int id;
  final String startTime;
  final int volumeId;

  ConversionItem({
    required this.cameraName,
    required this.createTime,
    required this.endTime,
    required this.filePath,
    required this.format,
    required this.id,
    required this.startTime,
    required this.volumeId,
  });

  factory ConversionItem.fromJson(Map<String, dynamic> json) {
    return ConversionItem(
      cameraName: json['camera_name'] ?? '',
      createTime: json['create_time'] ?? '',
      endTime: json['end_time'] ?? '',
      filePath: json['file_path'] ?? '',
      format: json['format'] ?? '',
      id: json['id'] ?? 0,
      startTime: json['start_time'] ?? '',
      volumeId: json['volume_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'camera_name': cameraName,
      'create_time': createTime,
      'end_time': endTime,
      'file_path': filePath,
      'format': format,
      'id': id,
      'start_time': startTime,
      'volume_id': volumeId,
    };
  }
}

class ConversionsResponse {
  final String command;
  final int result;
  final Map<String, List<ConversionItem>?> data;
  final int successCount;
  final int totalCount;

  ConversionsResponse({
    required this.command,
    required this.result,
    required this.data,
    required this.successCount,
    required this.totalCount,
  });

  factory ConversionsResponse.fromJson(Map<String, dynamic> json) {
    final dataMap = <String, List<ConversionItem>?>{};
    
    if (json['data'] != null && json['data'] is Map) {
      final dataJson = json['data'] as Map<String, dynamic>;
      
      for (final entry in dataJson.entries) {
        final key = entry.key;
        final value = entry.value;
        
        if (value == null) {
          dataMap[key] = null;
        } else if (value is List) {
          dataMap[key] = value
              .map((item) => ConversionItem.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
    }
    
    return ConversionsResponse(
      command: json['c'] ?? '',
      result: json['result'] ?? 0,
      data: dataMap,
      successCount: json['success_count'] ?? 0,
      totalCount: json['total_count'] ?? 0,
    );
  }
}