import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class FileLogger {
  static File? _logFile;
  static IOSink? _logSink;
  static bool _initialized = false;
  static const String _logFileName = 'camera_app_logs.txt';
  
  // Initialize the logger
  static Future<void> init() async {
    if (_initialized) return;
    
    try {
      // Use the app's temporary directory, which is accessible within sandbox
      final Directory tempDir = await getTemporaryDirectory();
      final String logFilePath = '${tempDir.path}/$_logFileName';
      
      _logFile = File(logFilePath);
      
      // Create file if it doesn't exist
      if (!await _logFile!.exists()) {
        await _logFile!.create();
      }
      
      // Open the file for writing
      _logSink = _logFile!.openWrite(mode: FileMode.append);
      
      // Log initialization
      String timestamp = _getTimestamp();
      _logSink!.writeln('[$timestamp] File logger initialized. Log path: $logFilePath');
      print('FILE LOGGER BAŞLATILDI. LOG DOSYASI: $logFilePath');
      
      _initialized = true;
    } catch (e) {
      print('Error initializing file logger: $e');
      // Set initialized to true anyway to prevent repeated init attempts
      _initialized = true;
    }
  }
  
  // Log a message to the file
  static Future<void> log(String message, {String tag = 'INFO'}) async {
    if (!_initialized) {
      await init();
    }
    
    try {
      if (_logSink != null) {
        String timestamp = _getTimestamp();
        _logSink!.writeln('[$timestamp] [$tag] $message');
        
        // Also print to console for debug purposes
        print('[$tag] $message');
      }
    } catch (e) {
      print('Error writing to log file: $e');
    }
  }
  
  // Log a WebSocket message with special formatting
  static Future<void> logWebSocketMessage(Map<String, dynamic> message, {String tag = 'WEBSOCKET'}) async {
    try {
      if (!_initialized) {
        await init();
      }
      
      if (_logSink != null) {
        String timestamp = _getTimestamp();
        String formattedJson = _formatJsonForLogging(message);
        _logSink!.writeln('[$timestamp] [$tag] Message:');
        _logSink!.writeln(formattedJson);
        _logSink!.writeln('-' * 80); // Separator for readability
      }
    } catch (e) {
      print('Error logging WebSocket message: $e');
    }
  }
  
  // Log camera device property updates with special formatting
  static Future<void> logCameraPropertyUpdate({
    required String macKey,
    required String property,
    required dynamic value,
    required String dataPath,
    String tag = 'CAMERA_UPDATE'
  }) async {
    try {
      if (!_initialized) {
        await init();
      }
      
      if (_logSink != null) {
        String timestamp = _getTimestamp();
        _logSink!.writeln('[$timestamp] [$tag]');
        _logSink!.writeln('  Data Path: $dataPath');
        _logSink!.writeln('  MAC Key: $macKey');
        _logSink!.writeln('  Property: $property');
        _logSink!.writeln('  Value: $value (${value.runtimeType})');
        _logSink!.writeln('-' * 80); // Separator for readability
      }
    } catch (e) {
      print('Error logging camera property update: $e');
    }
  }
  
  // Format the timestamp
  static String _getTimestamp() {
    return DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
  }
  
  // Format JSON for better readability in logs
  static String _formatJsonForLogging(Map<String, dynamic> json) {
    StringBuffer buffer = StringBuffer();
    json.forEach((key, value) {
      buffer.writeln('  "$key": ${_formatValue(value)}');
    });
    return buffer.toString();
  }
  
  static String _formatValue(dynamic value) {
    if (value is Map) {
      StringBuffer mapBuffer = StringBuffer();
      mapBuffer.writeln('{');
      value.forEach((k, v) {
        mapBuffer.writeln('    "$k": ${_formatValue(v)},');
      });
      mapBuffer.write('  }');
      return mapBuffer.toString();
    } else if (value is List) {
      return value.toString();
    } else if (value is String) {
      return '"$value"';
    } else {
      return value.toString();
    }
  }
  
  // Close the logger
  static Future<void> close() async {
    try {
      if (_logSink != null) {
        await _logSink!.flush();
        await _logSink!.close();
        _logSink = null;
      }
      _initialized = false;
    } catch (e) {
      print('Error closing file logger: $e');
    }
  }
}
