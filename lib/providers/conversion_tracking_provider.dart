import 'dart:async';
import 'package:flutter/material.dart';
import '../models/conversion_item.dart';
import 'websocket_provider.dart';

/// Represents a pending conversion being tracked
class PendingConversion {
  final String cameraName;
  final String targetSlaveMac;
  final String startTime;
  final String endTime;
  final String format;
  final DateTime createdAt;
  String status;
  int pollingAttempts;
  bool isComplete;
  String? filePath;

  PendingConversion({
    required this.cameraName,
    required this.targetSlaveMac,
    required this.startTime,
    required this.endTime,
    required this.format,
    this.status = 'Converting...',
    this.pollingAttempts = 0,
    this.isComplete = false,
    this.filePath,
  }) : createdAt = DateTime.now();

  String get displayName => cameraName;
  String get timeRange => '$startTime → $endTime';
}

/// Global provider for tracking conversion status across pages
class ConversionTrackingProvider extends ChangeNotifier {
  static const int _maxPollingAttempts = 120; // 120 * 5s = 10 minutes max
  static const Duration _pollingInterval = Duration(seconds: 5); // 5 saniyede bir kontrol

  Timer? _pollingTimer;
  WebSocketProviderOptimized? _webSocketProvider;
  
  final List<PendingConversion> _pendingConversions = [];
  ConversionsResponse? _conversionsData;
  bool _isPolling = false;
  
  // Callback for when a conversion completes
  void Function(PendingConversion)? onConversionComplete;
  void Function(PendingConversion, String)? onConversionError;

  List<PendingConversion> get pendingConversions => List.unmodifiable(_pendingConversions);
  bool get hasPendingConversions => _pendingConversions.any((c) => !c.isComplete);
  int get activePendingCount => _pendingConversions.where((c) => !c.isComplete).length;
  ConversionsResponse? get conversionsData => _conversionsData;

  /// Initialize with WebSocket provider reference
  void initialize(WebSocketProviderOptimized webSocketProvider) {
    _webSocketProvider = webSocketProvider;
  }

  /// Start tracking a new conversion
  void startTracking({
    required String cameraName,
    required String targetSlaveMac,
    required String startTime,
    required String endTime,
    required String format,
  }) {
    final pending = PendingConversion(
      cameraName: cameraName,
      targetSlaveMac: targetSlaveMac,
      startTime: startTime,
      endTime: endTime,
      format: format,
    );
    
    _pendingConversions.add(pending);
    notifyListeners();
    
    print('[ConversionTracking] Started tracking: $cameraName ($startTime - $endTime)');
    
    // Start polling if not already running
    _startPolling();
  }

  /// Stop tracking a specific conversion
  void stopTracking(PendingConversion conversion) {
    _pendingConversions.remove(conversion);
    notifyListeners();
    
    // Stop polling if no more pending conversions
    if (!hasPendingConversions) {
      _stopPolling();
    }
  }

  /// Clear all completed conversions
  void clearCompleted() {
    _pendingConversions.removeWhere((c) => c.isComplete);
    notifyListeners();
  }

  /// Mark a conversion as failed immediately (called when server returns error)
  void markAsError({
    required String cameraName,
    required String errorMessage,
  }) {
    print('[ConversionTracking] Marking as error: $cameraName - $errorMessage');
    
    // Find the most recent pending conversion for this camera
    final pending = _pendingConversions.where(
      (c) => c.cameraName == cameraName && !c.isComplete
    ).lastOrNull;
    
    if (pending != null) {
      pending.isComplete = true;
      pending.status = 'Hata: $errorMessage';
      print('[ConversionTracking] ❌ Conversion failed: $cameraName - $errorMessage');
      onConversionError?.call(pending, errorMessage);
      notifyListeners();
      
      // Stop polling if no more pending conversions
      if (!hasPendingConversions) {
        _stopPolling();
      }
    } else {
      print('[ConversionTracking] No pending conversion found for: $cameraName');
    }
  }

  /// Start the polling timer
  void _startPolling() {
    if (_isPolling) return;
    
    _isPolling = true;
    print('[ConversionTracking] Starting polling timer');
    
    _pollingTimer = Timer.periodic(_pollingInterval, (_) => _pollConversions());
  }

  /// Stop the polling timer
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    print('[ConversionTracking] Stopped polling timer');
  }

  /// Poll for conversion status
  Future<void> _pollConversions() async {
    if (_webSocketProvider == null) {
      print('[ConversionTracking] No WebSocket provider available');
      return;
    }

    try {
      // Request conversions list
      final success = await _webSocketProvider!.sendCommand('conversions');
      if (!success) {
        print('[ConversionTracking] Failed to send conversions request');
        return;
      }

      // Wait for response - reduced from 500ms
      await Future.delayed(const Duration(milliseconds: 200));

      // Get response
      final conversionsMessage = _webSocketProvider!.lastConversionsResponse;
      if (conversionsMessage == null) {
        print('[ConversionTracking] No conversions response received');
        return;
      }

      // Parse response
      try {
        _conversionsData = ConversionsResponse.fromJson(conversionsMessage);
      } catch (e) {
        print('[ConversionTracking] Error parsing response: $e');
        return;
      }

      // Check each pending conversion
      for (final pending in _pendingConversions.where((c) => !c.isComplete)) {
        pending.pollingAttempts++;
        pending.status = 'Converting... (attempt ${pending.pollingAttempts}/$_maxPollingAttempts)';
        
        // Check for timeout
        if (pending.pollingAttempts >= _maxPollingAttempts) {
          pending.status = 'Timeout - check manually';
          pending.isComplete = true;
          onConversionError?.call(pending, 'Conversion timeout after ${_maxPollingAttempts * 10 ~/ 60} minutes');
          continue;
        }

        // Check if file is ready
        if (_conversionsData != null) {
          _checkConversionStatus(pending);
        }
      }

      notifyListeners();

      // Stop polling if no more pending conversions
      if (!hasPendingConversions) {
        _stopPolling();
      }
    } catch (e) {
      print('[ConversionTracking] Polling error: $e');
    }
  }

  /// Check if a pending conversion is complete
  void _checkConversionStatus(PendingConversion pending) {
    print('[ConversionTracking] Checking status for: ${pending.cameraName}');
    print('[ConversionTracking] Looking for MAC: ${pending.targetSlaveMac}');
    print('[ConversionTracking] Request times: ${pending.startTime} - ${pending.endTime}');
    
    for (final entry in _conversionsData!.data.entries) {
      final deviceMac = entry.key;
      final conversions = entry.value;
      
      print('[ConversionTracking] Checking device: $deviceMac (match: ${deviceMac == pending.targetSlaveMac})');
      
      if (conversions == null) continue;
      
      for (final conversion in conversions) {
        print('[ConversionTracking] Found conversion: ${conversion.cameraName} (${conversion.startTime} - ${conversion.endTime})');
        print('[ConversionTracking] File path: "${conversion.filePath}"');
        
        // Match by camera name only first
        if (conversion.cameraName != pending.cameraName) continue;
        
        // Normalize times for comparison
        final serverStartNormalized = _normalizeTimeForComparison(conversion.startTime);
        final serverEndNormalized = _normalizeTimeForComparison(conversion.endTime);
        final requestStartNormalized = _normalizeTimeForComparison(pending.startTime);
        final requestEndNormalized = _normalizeTimeForComparison(pending.endTime);
        
        print('[ConversionTracking] Normalized - Server: $serverStartNormalized - $serverEndNormalized');
        print('[ConversionTracking] Normalized - Request: $requestStartNormalized - $requestEndNormalized');
        
        // Check if times match
        final timesMatch = serverStartNormalized == requestStartNormalized && 
                          serverEndNormalized == requestEndNormalized;
        
        print('[ConversionTracking] Times match: $timesMatch, FilePath empty: ${conversion.filePath.isEmpty}');
        
        if (timesMatch && conversion.filePath.isNotEmpty) {
          // File is ready!
          pending.isComplete = true;
          pending.filePath = conversion.filePath;
          pending.status = 'Complete ✓';
          
          print('[ConversionTracking] ✅ Conversion complete: ${pending.cameraName} -> ${conversion.filePath}');
          onConversionComplete?.call(pending);
          return;
        } else if (timesMatch && conversion.filePath.isEmpty) {
          // Still processing
          pending.status = 'İşleniyor... (${pending.pollingAttempts})';
          print('[ConversionTracking] ⏳ Still processing, file_path empty');
          return;
        }
      }
    }
    
    print('[ConversionTracking] ❌ No matching conversion found for ${pending.cameraName}');
  }

  /// Normalize time format for comparison - only compare hours and minutes
  String _normalizeTimeForComparison(String time) {
    // Extract just YYYY-MM-DD_HH-MM (without seconds)
    String normalized = time
        .replaceAll('T', '_')
        .replaceAll(':', '-')
        .split('+').first  // Remove timezone
        .split('.').first; // Remove milliseconds
    
    // Remove seconds if present (keep only YYYY-MM-DD_HH-MM)
    // Format: 2026-01-09_11-30-00 -> 2026-01-09_11-30
    final parts = normalized.split('-');
    if (parts.length >= 5) {
      // Join first 5 parts (year, month, day, hour, minute)
      normalized = parts.sublist(0, 5).join('-');
    }
    
    return normalized;
  }

  /// Force refresh conversions list
  Future<void> refreshConversions() async {
    await _pollConversions();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
