import 'file_logger_optimized.dart';

// This file now uses the optimized implementation directly.
// This allows us to keep backward compatibility with existing code without changing all references.
class FileLogger {
  static Future<void> init() async {
    await FileLoggerOptimized.init();
  }
  
  static Future<void> log(String message, {String tag = 'INFO'}) async {
    await FileLoggerOptimized.log(message, tag: tag);
  }
  
  static Future<void> logWebSocketMessage(Map<String, dynamic> message, {String tag = 'WEBSOCKET'}) async {
    await FileLoggerOptimized.logWebSocketMessage(message, tag: tag);
  }
  
  static Future<void> logCameraPropertyUpdate({
    required String macKey,
    required String property,
    required dynamic value,
    required String dataPath,
    String tag = 'CAMERA_UPDATE'
  }) async {
    await FileLoggerOptimized.logCameraPropertyUpdate(
      macKey: macKey,
      property: property,
      value: value,
      dataPath: dataPath,
      tag: tag
    );
  }
  
  static Future<void> close() async {
    await FileLoggerOptimized.close();
  }
  
  static void disableLogging() {
    FileLoggerOptimized.disableLogging();
  }
}
