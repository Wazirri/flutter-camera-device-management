import 'package:flutter/foundation.dart';
import '../utils/file_logger_optimized.dart';

/// This file provides a compatibility layer for existing code that uses FileLogger.
/// It forwards all calls to the optimized FileLoggerOptimized class.
class FileLogger {
  static bool _initialized = false;
  static bool _errorLogged = false;

  /// Forward to optimized init
  static Future<void> init() async {
    try {
      await FileLoggerOptimized.init();
      _initialized = true;
    } catch (e) {
      if (!_errorLogged) {
        print('Error initializing file logger: $e');
        _errorLogged = true;
      }
    }
  }
  
  /// Forward to optimized log
  static Future<void> log(String message, {String tag = 'INFO'}) async {
    try {
      await FileLoggerOptimized.log(message, tag: tag);
    } catch (e) {
      if (!_errorLogged) {
        print('Error writing to log file: $e');
        _errorLogged = true;
        
        // Disable logging to prevent further errors
        FileLoggerOptimized.disableLogging();
      }
    }
  }
  
  /// Forward to optimized logWebSocketMessage
  static Future<void> logWebSocketMessage(Map<String, dynamic> message, {String tag = 'WEBSOCKET'}) async {
    try {
      await FileLoggerOptimized.logWebSocketMessage(message, tag: tag);
    } catch (e) {
      if (!_errorLogged) {
        print('Error logging WebSocket message: $e');
        _errorLogged = true;
        
        // Disable logging to prevent further errors
        FileLoggerOptimized.disableLogging();
      }
    }
  }
  
  /// Forward to optimized logCameraPropertyUpdate
  static Future<void> logCameraPropertyUpdate({
    required String macKey,
    required String property,
    required dynamic value,
    required String dataPath,
    String tag = 'CAMERA_UPDATE'
  }) async {
    try {
      await FileLoggerOptimized.logCameraPropertyUpdate(
        macKey: macKey,
        property: property,
        value: value,
        dataPath: dataPath,
        tag: tag
      );
    } catch (e) {
      if (!_errorLogged) {
        print('Error logging camera property update: $e');
        _errorLogged = true;
        
        // Disable logging to prevent further errors
        FileLoggerOptimized.disableLogging();
      }
    }
  }
  
  /// Forward to optimized close
  static Future<void> close() async {
    try {
      await FileLoggerOptimized.close();
      _initialized = false;
    } catch (e) {
      print('Error closing file logger: $e');
    }
  }
  
  /// Disable logging completely
  static void disableLogging() {
    FileLoggerOptimized.disableLogging();
  }
}
