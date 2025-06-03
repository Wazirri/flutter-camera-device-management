import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Optimized file logger that properly manages file handles
/// and uses a batched writing approach to reduce I/O operations
class FileLoggerOptimized {
  static File? _logFile;
  static IOSink? _logSink;
  static bool _initialized = false;
  static const String _logFileName = 'camera_app_logs.txt';
  
  // Batching variables
  static final List<String> _logQueue = [];
  static Timer? _batchTimer;
  static const Duration _batchInterval = Duration(milliseconds: 500);
  static const int _maxQueueSize = 100;
  
  // Disable file logging flag - can be toggled at runtime
  static bool loggingEnabled = true;
  
  // Initialize the logger
  static Future<void> init() async {
    if (_initialized) return;
    
    // Skip file logging on web platform
    if (kIsWeb) {
      _initialized = true;
      return;
    }
    
    try {
      // Use the app's temporary directory, which is accessible within sandbox
      final Directory tempDir = await getTemporaryDirectory();
      final String logFilePath = '${tempDir.path}/$_logFileName';
      
      _logFile = File(logFilePath);
      
      // Create file if it doesn't exist
      if (!await _logFile!.exists()) {
        await _logFile!.create();
      }
      
      // Clean up old log file if it's too large (over 5MB)
      if (await _logFile!.length() > 5 * 1024 * 1024) {
        await _logFile!.writeAsString('');  // Truncate file
      }
      
      // Open the file for writing
      _logSink = _logFile!.openWrite(mode: FileMode.append);
      _startBatchTimer();
      
      // Log initialization
      String timestamp = _getTimestamp();
      _queueLog('[$timestamp] File logger initialized. Log path: $logFilePath');
      print('FILE LOGGER BAŞLATILDI. LOG DOSYASI: $logFilePath');
      
      _initialized = true;
      
      // Register for app lifecycle events to properly close logs
      // This helps ensure we clean up resources properly
    } catch (e) {
      print('Error initializing file logger: $e');
      // Set initialized to true anyway to prevent repeated init attempts
      _initialized = true;
    }
  }
  
  // Log a message to the file
  static Future<void> log(String message, {String tag = 'INFO'}) async {
    if (!loggingEnabled) return;
    
    if (!_initialized) {
      await init();
    }
    
    try {
      String timestamp = _getTimestamp();
      _queueLog('[$timestamp] [$tag] $message');
      
      // Also print to console for debug purposes
      print('[$tag] $message');
    } catch (e) {
      print('Error queuing log message: $e');
    }
  }
  
  // Log a WebSocket message with special formatting
  static Future<void> logWebSocketMessage(Map<String, dynamic> message, {String tag = 'WEBSOCKET'}) async {
    if (!loggingEnabled) return;
    
    try {
      if (!_initialized) {
        await init();
      }
      
      String timestamp = _getTimestamp();
      String formattedJson = _formatJsonForLogging(message);
      _queueLog('[$timestamp] [$tag] Message:');
      _queueLog(formattedJson);
      _queueLog('-' * 80); // Separator for readability
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
    if (!loggingEnabled) return;
    
    try {
      if (!_initialized) {
        await init();
      }
      
      String timestamp = _getTimestamp();
      _queueLog('[$timestamp] [$tag]');
      _queueLog('  Data Path: $dataPath');
      _queueLog('  MAC Key: $macKey');
      _queueLog('  Property: $property');
      _queueLog('  Value: $value (${value.runtimeType})');
      _queueLog('-' * 80); // Separator for readability
    } catch (e) {
      print('Error logging camera property update: $e');
    }
  }
  
  // Queue log messages for batch writing
  static void _queueLog(String message) {
    _logQueue.add(message);
    
    // Flush immediately if queue is getting large
    if (_logQueue.length >= _maxQueueSize) {
      _flushLogs();
    }
  }
  
  // Start the batch timer to periodically flush logs
  static void _startBatchTimer() {
    _batchTimer ??= Timer.periodic(_batchInterval, (_) {
      _flushLogs();
    });
  }
  
  // Flush logs to file
  static Future<void> _flushLogs() async {
    if (_logQueue.isEmpty || _logSink == null) return;
    
    try {
      // Take the current queue and clear it
      final List<String> currentQueue = List.from(_logQueue);
      _logQueue.clear();
      
      // Write all logs in the queue
      for (String log in currentQueue) {
        _logSink!.writeln(log);
      }
      
      // Flush to disk
      await _logSink!.flush();
    } catch (e) {
      print('Error flushing logs: $e');
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
  
  // Close the logger - properly clean up resources
  static Future<void> close() async {
    try {
      // Cancel batch timer
      _batchTimer?.cancel();
      _batchTimer = null;
      
      // Flush any remaining logs
      await _flushLogs();
      
      // Close the sink
      if (_logSink != null) {
        await _logSink!.close();
        _logSink = null;
      }
      
      _initialized = false;
    } catch (e) {
      print('Error closing file logger: $e');
    }
  }
  
  // Disable logging - call this when you see "too many open files" error
  static void disableLogging() {
    loggingEnabled = false;
    close(); // Close any open files
    print('File logging has been disabled');
  }
}
