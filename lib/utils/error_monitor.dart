import 'dart:async';
import 'package:flutter/foundation.dart';
import 'file_logger_optimized.dart';

/// This class monitors for specific error conditions and takes appropriate actions
/// to prevent app crashes or performance issues.
class ErrorMonitor {
  static ErrorMonitor? _instance;
  static const int _tooManyFilesErrorCheckInterval = 5; // seconds
  Timer? _checkTimer;
  int _errorCount = 0;
  bool _isMonitoring = false;
  
  // Private constructor for singleton
  ErrorMonitor._();
  
  /// Get the singleton instance
  static ErrorMonitor get instance {
    _instance ??= ErrorMonitor._();
    return _instance!;
  }
  
  /// Start monitoring for errors
  void startMonitoring() {
    if (_isMonitoring) return;
    
    print('Starting error monitoring...');
    _isMonitoring = true;
    
    FlutterError.onError = _handleFlutterError;
    
    _checkTimer = Timer.periodic(
      const Duration(seconds: _tooManyFilesErrorCheckInterval), 
      (_) => _checkForTooManyFilesError()
    );
  }
  
  /// Stop monitoring
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _isMonitoring = false;
    
    // Reset Flutter error handler
    FlutterError.onError = FlutterError.presentError;
  }
  
  /// Handle Flutter errors
  void _handleFlutterError(FlutterErrorDetails details) {
    // Log the error
    print('Flutter error: ${details.exception}');
    
    // Check if it's a "too many open files" error
    final errorString = details.exception.toString().toLowerCase();
    if (errorString.contains('too many open files') || 
        errorString.contains('errno = 24')) {
      _handleTooManyFilesError();
    }
    
    // Forward to default handler
    FlutterError.presentError(details);
  }
  
  /// Check for the "too many open files" error in logs
  void _checkForTooManyFilesError() {
    PlatformDispatcher.instance.onError = (error, stack) {
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('too many open files') || 
          errorString.contains('errno = 24')) {
        _handleTooManyFilesError();
      }
      
      // Return false to allow Flutter to handle the error as well
      return false;
    };
  }
  
  /// Handle the "too many open files" error
  void _handleTooManyFilesError() {
    _errorCount++;
    
    // Take action if we've seen multiple errors
    if (_errorCount >= 2) {
      print('Too many open files error detected! Disabling file logging...');
      
      // Disable file logging
      FileLoggerOptimized.disableLogging();
      
      // Show the error only the first time
      if (_errorCount == 2) {
        // Display a friendly message
        print('Logları dosyaya yazma işini iptal edildi. (File logging has been disabled)');
      }
    }
  }
  
  /// Check a message for "too many open files" errors
  void checkMessage(String message) {
    final lowerCaseMessage = message.toLowerCase();
    if (lowerCaseMessage.contains('too many open files') || 
        lowerCaseMessage.contains('errno = 24')) {
      _handleTooManyFilesError();
    }
  }
}
